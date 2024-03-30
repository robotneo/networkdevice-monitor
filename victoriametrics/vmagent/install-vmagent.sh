#!/bin/bash
set -e
apt update && apt install -y curl wget net-tools jq

# 创建vmagent配置文件目录
mkdir -p /etc/victoriametrics/vmagent
# 创建vmagent临时数据缓存目录
mkdir -p /var/lib/vmagent-remotewrite-data

if ! getent passwd victoriametrics >/dev/null 2>&1; then
  adduser --system --home /var/lib/vmagent-remotewrite-data --group victoriametrics
fi

chown -R victoriametrics:victoriametrics /var/lib/vmagent-remotewrite-data

VM_VERSION=`curl -sg "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | jq -r '.[0].name'`

wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/vmutils-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/vmutils.tar.gz

cd /tmp && tar -xzvf /tmp/vmutils.tar.gz vmagent-prod
mv /tmp/vmagent-prod /usr/bin
chmod +x /usr/bin/vmagent-prod
chown root:root /usr/bin/vmagent-prod

cat> /etc/systemd/system/vmagent.service <<EOF
[Unit]
Description=vmagent is a tiny agent which helps you collect metrics from various sources and store them in VictoriaMetrics.
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
WorkingDirectory=/var/lib/vmagent-remotewrite-data
ReadWritePaths=/var/lib/vmagent-remotewrite-data
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/victoriametrics/vmagent/vmagent.conf
ExecStart=/usr/bin/vmagent-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=vmagent
PrivateTmp=yes
ProtectHome=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=yes

[Install]
WantedBy=multi-user.target
EOF

cat> /etc/victoriametrics/vmagent/vmagent.conf <<EOF
ARGS="-promscrape.config=/etc/victoriametrics/vmagent/scrape.yml -remoteWrite.url=http://172.17.40.139:8428/api/v1/write -remoteWrite.tmpDataPath=/var/lib/vmagent-remotewrite-data -promscrape.suppressScrapeErrors"
EOF

cat> /etc/victoriametrics/vmagent/scrape.yml <<EOF
global:
  scrape_interval: 10s
  scrape_timeout: 30s

scrape_configs:
  - job_name: 'vmagent'
    static_configs:
      - targets: ['172.17.40.139:8429']
  - job_name: victoriametrics
    static_configs:
      - targets:
        - http://172.17.40.139:8428/metrics
EOF

chown -R victoriametrics:victoriametrics /var/lib/vmagent-remotewrite-data
chown -R victoriametrics:victoriametrics /etc/victoriametrics/vmagent

systemctl enable vmagent.service
systemctl restart vmagent.service
ps aux | grep vmagent
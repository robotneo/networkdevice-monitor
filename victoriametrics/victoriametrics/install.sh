#!/bin/bash
set -e
apt update && apt install -y curl wget net-tools jq

# 创建vmagent配置文件目录
mkdir -p /etc/victoriametrics/single
# 创建vmagent临时数据缓存目录
mkdir -p /var/lib/victoria-metrics-data

if ! getent passwd victoriametrics >/dev/null 2>&1; then
  adduser --system --home /var/lib/victoria-metrics-data --group victoriametrics
fi

chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-data

VM_VERSION=`curl -sg "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | jq -r '.[0].name'`

wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/victoria-metrics-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/victoria-metrics.tar.gz

cd /tmp && tar -xzvf /tmp/victoria-metrics.tar.gz victoria-metrics-prod
mv /tmp/victoria-metrics-prod /usr/bin
chmod +x /usr/bin/victoria-metrics-prod
chown root:root /usr/bin/victoria-metrics-prod

cat> /etc/systemd/system/victoria-metrics.service <<EOF
[Unit]
Description=VictoriaMetrics is a fast, cost-effective and scalable monitoring solution and time series database.
# https://docs.victoriametrics.com
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
WorkingDirectory=/var/lib/victoria-metrics-data
ReadWritePaths=/var/lib/victoria-metrics-data
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=5
EnvironmentFile=-/etc/victoriametrics/single/vmsingle.conf
ExecStart=/usr/bin/victoria-metrics-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
# See docs https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#tuning
ProtectSystem=full
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=vmsingle
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

cat> /etc/victoriametrics/single/vmsingle.conf <<EOF
ARGS="-storageDataPath=/var/lib/victoria-metrics-data -retentionPeriod=90d -httpListenAddr=:8428"
EOF

chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-data
chown -R victoriametrics:victoriametrics /etc/victoriametrics/single

systemctl enable victoria-metrics.service
systemctl restart victoria-metrics.service
ps aux | grep victoria-metrics
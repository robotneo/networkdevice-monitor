#!/bin/bash
set -e

# 函数：安装依赖工具
install_dependencies() {
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update && apt-get install -y curl wget net-tools
    elif [ "$OS" == "centos" ]; then
        yum update && yum install -y curl wget net-tools
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# 函数：设置系统服务和用户
setup_system() {
    # 创建vmagent配置文件目录
    mkdir -p /etc/victoriametrics/vmagent
    # 创建vmagent临时数据缓存目录
    mkdir -p /var/lib/vmagent-remotewrite-data

    # 检查victoriametrics组是否存在，不存在则创建
    if ! getent group victoriametrics > /dev/null 2>&1; then
        groupadd --system victoriametrics
    fi

    # 检查victoriametrics用户是否存在，不存在则创建
    if ! id -u victoriametrics > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/vmagent-remotewrite-data --no-create-home --gid victoriametrics victoriametrics
    fi

    chown -R victoriametrics:victoriametrics /var/lib/vmagent-remotewrite-data
}

# 确定操作系统类型
OS="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 安装依赖工具
install_dependencies

# 设置系统服务和用户
setup_system

# 获取vmagent最新版本
VM_VERSION=$(curl -s "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags"  | grep '"name":' | head -n 1 | awk -F '"' '{print $4}')

# 下载并安装vmagent
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/vmutils-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/vmutils.tar.gz

cd /tmp && tar -xzvf /tmp/vmutils.tar.gz vmagent-prod
mv /tmp/vmagent-prod /usr/bin
chmod +x /usr/bin/vmagent-prod

cat> /etc/systemd/system/vmagent.service <<EOF
[Unit]
Description=vmagent is a tiny but mighty agent which helps you collect metrics from various sources and store them in VictoriaMetrics or any other Prometheus-compatible storage systems that support the remote_write protocol.
# https://docs.victoriametrics.com/vmagent.html
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/victoriametrics/vmagent/vmagent.conf
ExecStart=/usr/bin/vmagent-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
# See docs https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#tuning
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
WorkingDirectory=/var/lib/vmagent-remotewrite-data
ReadWritePaths=/var/lib/vmagent-remotewrite-data
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
ARGS="-promscrape.config=/etc/victoriametrics/vmagent/scrape.yml -remoteWrite.url=http://127.0.0.1:8428/api/v1/write -remoteWrite.tmpDataPath=/var/lib/vmagent-remotewrite-data -promscrape.suppressScrapeErrors"
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
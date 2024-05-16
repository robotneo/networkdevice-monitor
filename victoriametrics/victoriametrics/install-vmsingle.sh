#!/bin/bash
set -e

# 函数：安装依赖工具
install_dependencies() {
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update && apt-get install -y curl wget net-tools jq
    elif [ "$OS" == "centos" ]; then
        yum update && yum install -y curl wget net-tools jq
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# 函数：设置系统服务和用户
setup_system() {
    # 创建victoriametrics配置文件目录
    mkdir -p /etc/victoriametrics/single
    # 创建victoriametrics数据保存目录
    mkdir -p /var/lib/victoria-metrics-data

    # 检查victoriametrics组是否存在，不存在则创建
    if ! getent group victoriametrics > /dev/null 2>&1; then
        groupadd --system victoriametrics
    fi

    # 检查victoriametrics用户是否存在，不存在则创建
    if ! id -u victoriametrics > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/victoria-metrics-data --no-create-home --gid victoriametrics victoriametrics
    fi

    chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-data
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

# 获取VictoriaMetrics最新版本
VM_VERSION=$(curl -s "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | jq -r '.[0].name')

# 下载并安装VictoriaMetrics
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/victoria-metrics-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/victoria-metrics.tar.gz

tar -xzvf /tmp/victoria-metrics.tar.gz -C /tmp
mv /tmp/victoria-metrics*/victoria-metrics-prod /usr/bin/
chmod +x /usr/local/bin/victoria-metrics-prod

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
ARGS="-storageDataPath=/var/lib/victoria-metrics-data -retentionPeriod=90d -httpListenAddr=:8428 -vmui.defaultTimezone=Local"
EOF

chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-data
chown -R victoriametrics:victoriametrics /etc/victoriametrics/single

systemctl enable victoria-metrics.service
systemctl restart victoria-metrics.service
ps aux | grep victoria-metrics

echo "VictoriaMetrics installation and service setup complete."
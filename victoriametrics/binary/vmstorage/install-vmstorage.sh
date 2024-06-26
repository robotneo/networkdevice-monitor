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
    # 创建vmstorage配置文件目录
    mkdir -p /etc/victoriametrics/vmstorage
    # 创建victoriametrics集群数据保存目录
    mkdir -p /var/lib/victoria-metrics-cluster-data

    # 检查victoriametrics组是否存在，不存在则创建
    if ! getent group victoriametrics > /dev/null 2>&1; then
        groupadd --system victoriametrics
    fi

    # 检查victoriametrics用户是否存在，不存在则创建
    if ! id -u victoriametrics > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/victoriametrics --no-create-home --gid victoriametrics victoriametrics
    fi

    chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-cluster-data
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

# 获取VictoriaMetrics集群最新版本
VM_VERSION=$(curl -s "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | grep '"name":' | head -n 1 | awk -F '"' '{print $4}')
# 下载并安装VictoriaMetrics集群
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/victoria-metrics-linux-amd64-${VM_VERSION}-cluster.tar.gz -O /tmp/vmcluster.tar.gz

cd /tmp && tar -xzvf /tmp/vmcluster.tar.gz vmstorage-prod
mv /tmp/vmstorage-prod /usr/bin
chmod +x /usr/bin/vmstorage-prod

cat> /etc/systemd/system/vmstorage.service <<EOF
[Unit]
Description=vmstorage - stores the raw data and returns the queried data on the given time range for the given label filters
# https://docs.victoriametrics.com/Cluster-VictoriaMetrics.html
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/victoriametrics/vmstorage/vmstorage.conf
ExecStart=/usr/bin/vmstorage-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
# See docs https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#tuning
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=vmstorage
WorkingDirectory=/var/lib/victoria-metrics-cluster-data
ReadWritePaths=/var/lib/victoria-metrics-cluster-data
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

cat> /etc/victoriametrics/vmstorage/vmstorage.conf <<EOF
ARGS="-storageDataPath=/var/lib/victoria-metrics-cluster-data -retentionPeriod=30d"
EOF

chown -R victoriametrics:victoriametrics /etc/victoriametrics/vmstorage
chown -R victoriametrics:victoriametrics /var/lib/victoria-metrics-cluster-data

systemctl enable vmstorage.service
systemctl restart vmstorage.service
ps aux | grep vmstorage

echo "vmstorage installation and service setup complete."

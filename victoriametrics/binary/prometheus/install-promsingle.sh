#!/bin/bash
set -e

# 函数：安装依赖工具
install_dependencies() {
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update && apt-get install -y curl wget net-tools
    elif [ "$OS" == "centos" ] || [ "$OS" == "rocky" ]; then
        dnf update -y && dnf install -y curl wget net-tools
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# 函数：设置系统服务和用户
setup_system() {
    # 创建Prometheus配置文件目录
    mkdir -p /etc/prometheus/single
    # 创建Prometheus数据保存目录
    mkdir -p /var/lib/prometheus

    # 检查Prometheus组是否存在，不存在则创建
    if ! getent group prometheus > /dev/null 2>&1; then
        groupadd --system prometheus
    fi

    # 检查Prometheus用户是否存在，不存在则创建
    if ! id -u prometheus > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/prometheus --no-create-home --gid prometheus prometheus
    fi

    chown -R prometheus:prometheus /var/lib/prometheus
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

# 获取Prometheus最新版本
PROM_VERSION=$(curl -s "https://api.github.com/repos/prometheus/prometheus/tags" | grep '"name":' | head -n 1 | awk -F '"' '{print $4}' | sed 's/^v//')

# 下载并安装Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz

# 解压Prometheus文件
tar -xzvf /tmp/prometheus.tar.gz -C /tmp

# 移动Prometheus可执行文件到/usr/bin目录
mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/bin/
mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/bin/
chmod +x /usr/bin/prometheus /usr/bin/promtool

# 将解压后的 prometheus.yml 配置文件复制到 /etc/prometheus/single 目录
cp /tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/single/

# 将 consoles 和 console_libraries 目录复制到 /var/lib/prometheus
cp -r /tmp/prometheus-${PROM_VERSION}.linux-amd64/consoles /var/lib/prometheus/
cp -r /tmp/prometheus-${PROM_VERSION}.linux-amd64/console_libraries /var/lib/prometheus/

# 清理临时文件
rm -rf /tmp/prometheus-${PROM_VERSION}.linux-amd64
rm /tmp/prometheus.tar.gz

# 设置systemd服务
cat> /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring System and Time Series Database
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
WorkingDirectory=/var/lib/prometheus
ReadWritePaths=/var/lib/prometheus
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=5
EnvironmentFile=-/etc/prometheus/single/prometheus.conf
ExecStart=/usr/bin/prometheus \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
ProtectSystem=full
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=prometheus
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

# 创建prometheus.conf文件，包含启动参数
cat> /etc/prometheus/single/prometheus.conf <<EOF
ARGS="--web.listen-address=0.0.0.0:9090 --config.file=/etc/prometheus/single/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/data --storage.tsdb.retention=90d --web.enable-lifecycle --web.enable-admin-api --web.enable-remote-write-receiver --web.console.templates=/var/lib/prometheus/consoles --web.console.libraries=/var/lib/prometheus/console_libraries"
EOF

# 设置权限
chown -R prometheus:prometheus /var/lib/prometheus
chown -R prometheus:prometheus /etc/prometheus/single

# 重新加载systemd配置并启动服务
sudo systemctl daemon-reload
sudo systemctl enable prometheus.service
sudo systemctl restart prometheus.service

# 验证Prometheus是否运行
ps aux | grep prometheus

echo "Prometheus installation and service setup complete."

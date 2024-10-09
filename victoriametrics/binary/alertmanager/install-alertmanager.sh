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
    # 创建 alertmanager 配置文件目录
    mkdir -p /etc/alertmanager
    # 创建 alertmanager 临时数据缓存目录
    mkdir -p /var/lib/alertmanager

    # 检查 alertmanager 组是否存在，不存在则创建
    if ! getent group alertmanager > /dev/null 2>&1; then
        groupadd --system alertmanager
    fi

    # 检查 alertmanager 用户是否存在，不存在则创建
    if ! id -u alertmanager > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/alertmanager --no-create-home --gid alertmanager alertmanager
    fi

    chown -R alertmanager:alertmanager /var/lib/alertmanager
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

# 获取 Alertmanager 最新版本
AM_VERSION=$(curl -s "https://api.github.com/repos/prometheus/alertmanager/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

# 下载并解压 Alertmanager
wget "https://github.com/prometheus/alertmanager/releases/download/v${AM_VERSION}/alertmanager-${AM_VERSION}.linux-amd64.tar.gz" -O /tmp/alertmanager.tar.gz

# 解压文件
tar -xzvf /tmp/alertmanager.tar.gz -C /tmp

# 复制解压的 alertmanager.yml 文件到 /etc/alertmanager
cp /tmp/alertmanager-${AM_VERSION}.linux-amd64/alertmanager.yml /etc/alertmanager/

# 移动可执行文件到 /usr/bin
mv /tmp/alertmanager-${AM_VERSION}.linux-amd64/alertmanager /usr/bin/
mv /tmp/alertmanager-${AM_VERSION}.linux-amd64/amtool /usr/bin/

# 清理临时文件
rm -rf /tmp/alertmanager-${AM_VERSION}.linux-amd64
rm /tmp/alertmanager.tar.gz

# 确保配置文件权限正确
chown -R alertmanager:alertmanager /etc/alertmanager

# 创建 systemd 单元文件
cat > /etc/systemd/system/alertmanager.service <<EOF
[Unit]
Description=Alertmanager for Prometheus
After=network.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/alertmanager/alertmanager.conf
ExecStart=/usr/bin/alertmanager \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
WorkingDirectory=/var/lib/alertmanager
ReadWritePaths=/var/lib/alertmanager
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=alertmanager
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

# 创建 alertmanager.conf 文件
cat > /etc/alertmanager/alertmanager.conf <<EOF
ARGS="--web.listen-address=0.0.0.0:9093 --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/var/lib/alertmanager"
EOF

# 重新加载 systemd 配置并启动服务
systemctl daemon-reload
systemctl enable alertmanager.service
systemctl start alertmanager.service

echo "Alertmanager installation and service setup complete."
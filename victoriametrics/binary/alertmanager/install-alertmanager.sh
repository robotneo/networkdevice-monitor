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
    # 创建alertmanager配置文件目录
    mkdir -p /etc/alertmanager
    # 创建alertmanager临时数据缓存目录
    mkdir -p /var/lib/alertmanager-data

    # 检查alertmanager组是否存在，不存在则创建
    if ! getent group alertmanager > /dev/null 2>&1; then
        groupadd --system alertmanager
    fi

    # 检查alertmanager用户是否存在，不存在则创建
    if ! id -u alertmanager > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/alertmanager-data --no-create-home --gid alertmanager alertmanager
    fi

    chown -R alertmanager:alertmanager /var/lib/alertmanager-data
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

# 获取Alertmanager最新版本
AM_VERSION=$(curl -s "https://api.github.com/repos/prometheus/alertmanager/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')

# 下载并解压Alertmanager
wget "https://github.com/prometheus/alertmanager/releases/download/v${AM_VERSION}/alertmanager-${AM_VERSION}.linux-amd64.tar.gz" -O /tmp/alertmanager.tar.gz

cd /tmp && tar -xzvf /tmp/alertmanager.tar.gz alertmanager-${AM_VERSION}.linux-amd64/
mv /tmp/alertmanager-${AM_VERSION}.linux-amd64/alertmanager /usr/local/bin/
mv /tmp/alertmanager-${AM_VERSION}.linux-amd64/amtool /usr/local/bin/

# 清理文件
rm -rf "/tmp/alertmanager-${AM_VERSION}.linux-amd64"

# 创建配置文件
cat <<EOF > /etc/alertmanager/alertmanager.yml
route:
  receiver: blackhole

receivers:
  - name: blackhole
EOF
chown -R alertmanager:alertmanager /etc/alertmanager

# 创建 systemd 单元文件
cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager for prometheus

[Service]
User=alertmanager
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/var/lib/alertmanager-data

ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF

# 运行服务
systemctl daemon-reload
systemctl enable alertmanager.service
systemctl start alertmanager.service

echo "Alertmanager 安装完成！"
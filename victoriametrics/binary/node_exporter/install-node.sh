#!/bin/bash
set -e

# 函数：安装依赖工具
install_dependencies() {
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update && apt-get install -y curl wget tar net-tools
    elif [ "$OS" == "centos" ] || [ "$OS" == "rocky" ]; then
        dnf update -y && dnf install -y curl wget tar net-tools
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# 函数：设置系统服务和用户
setup_system() {
    # 检查node_exporter组是否存在，不存在则创建
    if ! getent group node_exporter > /dev/null 2>&1; then
        groupadd --system node_exporter
    fi

    # 检查node_exporter用户是否存在，不存在则创建
    if ! id -u node_exporter > /dev/null 2>&1; then
        useradd --system --no-create-home --shell /sbin/nologin --gid node_exporter node_exporter
    fi

    # 创建textfile_collector目录并设置权限
    mkdir -p /var/lib/node_exporter/textfile_collector
    chown -R node_exporter:node_exporter /var/lib/node_exporter
}

# 函数：确定操作系统类型
setup_config_path() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            CONFIG_PATH="/etc/default/node_exporter"
        elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rocky" ]]; then
            CONFIG_PATH="/etc/sysconfig/node_exporter"
        else
            echo "Unsupported operating system."
            exit 1
        fi
    else
        echo "Cannot detect the operating system."
        exit 1
    fi
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

# 获取 node_exporter 最新版本
NE_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

# 下载并安装 node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
tar -xzvf /tmp/node_exporter.tar.gz -C /tmp
mv /tmp/node_exporter-${NE_VERSION}.linux-amd64/node_exporter /usr/sbin/
chmod +x /usr/sbin/node_exporter

# 写入配置文件
setup_config_path
cat > "$CONFIG_PATH" <<EOF
# Node Exporter configuration
OPTIONS="--collector.textfile.directory=/var/lib/node_exporter/textfile_collector"
EOF

# 创建 systemd 服务文件
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Requires=node_exporter.socket
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
EnvironmentFile=/etc/default/node_exporter
ExecStart=/usr/sbin/node_exporter --web.systemd-socket \$OPTIONS
WorkingDirectory=/var/lib/node_exporter
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 创建 systemd socket 文件
cat > /etc/systemd/system/node_exporter.socket <<EOF
[Unit]
Description=Node Exporter

[Socket]
ListenStream=9100

[Install]
WantedBy=sockets.target
EOF

# 创建 /var/lib/node_exporter/textfile_collector 目录并设置权限
mkdir -p /var/lib/node_exporter/textfile_collector
chown -R node_exporter:node_exporter /var/lib/node_exporter/textfile_collector

# 启用并启动服务
systemctl daemon-reload
systemctl enable node_exporter.service
systemctl enable node_exporter.socket
systemctl start node_exporter.socket
systemctl start node_exporter.service

# 清理临时文件
rm -rf /tmp/node_exporter*

echo "Node Exporter installation and service setup complete."
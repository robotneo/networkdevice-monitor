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

# 函数：设置系统服务和目录
setup_system() {
    # 创建 /opt/blackbox_exporter 目录
    mkdir -p /opt/blackbox_exporter
}

# 函数：获取最新版本
get_latest_version() {
    curl -s "https://api.github.com/repos/prometheus/blackbox_exporter/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
}

# 确定操作系统类型
OS="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 安装依赖工具
install_dependencies

# 设置系统服务和目录
setup_system

# 获取 blackbox_exporter 最新版本
BB_VERSION=$(get_latest_version)
echo "Downloading blackbox_exporter v${BB_VERSION}..."

# 下载 blackbox_exporter 二进制文件
wget https://github.com/prometheus/blackbox_exporter/releases/download/v${BB_VERSION}/blackbox_exporter-${BB_VERSION}.linux-amd64.tar.gz -O /tmp/blackbox_exporter.tar.gz

# 解压缩并将二进制文件和配置文件移动到 /opt/blackbox_exporter 目录
tar -xzvf /tmp/blackbox_exporter.tar.gz -C /tmp/
mv /tmp/blackbox_exporter-${BB_VERSION}.linux-amd64/blackbox_exporter /opt/blackbox_exporter/
mv /tmp/blackbox_exporter-${BB_VERSION}.linux-amd64/blackbox.yml /opt/blackbox_exporter/

# 添加执行权限
chmod +x /opt/blackbox_exporter/blackbox_exporter

# 删除临时文件
rm -rf /tmp/blackbox_exporter.tar.gz /tmp/blackbox_exporter-${BB_VERSION}.linux-amd64

# 创建 systemd 单元文件
cat > /etc/systemd/system/blackbox_exporter.service <<EOF
[Unit]
Description=Blackbox Exporter Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/blackbox_exporter/blackbox_exporter --config.file=/opt/blackbox_exporter/blackbox.yml
WorkingDirectory=/opt/blackbox_exporter
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
sudo systemctl daemon-reload
sudo systemctl enable blackbox_exporter.service
sudo systemctl start blackbox_exporter.service

echo "blackbox_exporter installation and service setup complete."
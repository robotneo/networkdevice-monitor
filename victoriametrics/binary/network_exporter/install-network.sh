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
    # 创建 /opt/network_exporter 目录
    mkdir -p /opt/network_exporter
}

# 函数：获取最新版本
get_latest_version() {
    curl -s "https://api.github.com/repos/syepes/network_exporter/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
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

# 获取 network_exporter 最新版本
NE_VERSION=$(get_latest_version)
echo "Downloading network_exporter v${NE_VERSION}..."

# 下载 network_exporter 二进制文件
wget https://github.com/syepes/network_exporter/releases/download/${NE_VERSION}/network_exporter_${NE_VERSION}.Linux_x86_64.tar.gz -O /tmp/network_exporter.tar.gz

# 解压并仅保留需要的文件
tar -xzvf /tmp/network_exporter.tar.gz -C /opt/network_exporter/

# 添加执行权限
chmod +x /opt/network_exporter/network_exporter

# 删除临时文件
rm -rf /tmp/network_exporter.tar.gz /tmp/network_exporter_${NE_VERSION}.Linux_x86_64

# 创建 systemd 单元文件
cat > /etc/systemd/system/network_exporter.service <<EOF
[Unit]
Description=Network Exporter Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/network_exporter/network_exporter --web.listen-address=:9427 --config.file=/opt/network_exporter/network_exporter.yml --log.level=info
WorkingDirectory=/opt/network_exporter
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
sudo systemctl daemon-reload
sudo systemctl enable network_exporter.service
sudo systemctl start network_exporter.service

echo "network_exporter installation and service setup complete."
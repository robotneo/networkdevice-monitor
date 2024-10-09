#!/bin/bash
set -e

# 函数：安装依赖工具
install_dependencies() {
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        apt-get update && apt-get install -y curl wget unzip net-tools
    elif [ "$OS" == "centos" ] || [ "$OS" == "rocky" ]; then
        dnf update -y && dnf install -y curl wget unzip net-tools
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# 函数：设置系统服务和用户
setup_system() {
    # 创建 PrometheusAlert 安装目录
    mkdir -p /opt/PrometheusAlert

    # 检查 prometheusalert 组是否存在，不存在则创建
    if ! getent group prometheusalert > /dev/null 2>&1; then
        groupadd --system prometheusalert
    fi

    # 检查 prometheusalert 用户是否存在，不存在则创建
    if ! id -u prometheusalert > /dev/null 2>&1; then
        useradd --system --home-dir /opt/PrometheusAlert --no-create-home --gid prometheusalert prometheusalert
    fi

    chown -R prometheusalert:prometheusalert /opt/PrometheusAlert
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

# 获取 PrometheusAlert 最新版本
PA_VERSION=$(curl -s "https://api.github.com/repos/feiyu563/PrometheusAlert/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

# 下载 PrometheusAlert 二进制文件
echo "Downloading PrometheusAlert v${PA_VERSION}..."
wget https://github.com/feiyu563/PrometheusAlert/releases/download/v${PA_VERSION}/linux.zip -O /tmp/prometheusalert.zip

# 如果下载速度慢，提示用户科学上网
if [ $? -ne 0 ]; then
    echo "Download failed or too slow. Consider using a VPN or proxy to download faster."
    exit 1
fi

# 解压到 /tmp
unzip /tmp/prometheusalert.zip -d /tmp

# 拷贝 linux 目录中的所有文件到 /opt/PrometheusAlert
cp -r /tmp/linux/* /opt/PrometheusAlert/

# 添加执行权限
chmod +x /opt/PrometheusAlert/PrometheusAlert

# 删除临时文件
rm -rf /tmp/prometheusalert.zip /tmp/linux

# 检查并加载配置文件
if [ -f /opt/PrometheusAlert/conf/app.conf ]; then
    echo "Configuration file found in /opt/PrometheusAlert/conf/app.conf"
else
    echo "Configuration file not found in /opt/PrometheusAlert/conf/. Please check."
    exit 1
fi

# 确保配置文件权限正确
chown -R prometheusalert:prometheusalert /opt/PrometheusAlert

# 创建 systemd 单元文件
cat > /etc/systemd/system/prometheusalert.service <<EOF
[Unit]
Description=PrometheusAlert Service
After=network.target

[Service]
Type=simple
User=prometheusalert
Group=prometheusalert
ExecStart=/opt/PrometheusAlert/PrometheusAlert
WorkingDirectory=/opt/PrometheusAlert
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
systemctl daemon-reload
systemctl enable prometheusalert.service
systemctl start prometheusalert.service

echo "PrometheusAlert installation and service setup complete."
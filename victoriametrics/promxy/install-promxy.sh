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
    # 创建promxy配置文件目录
    mkdir -p /etc/promxy
    # 创建promxy数据保存目录
    mkdir -p /var/lib/promxy

    # 检查promxy组是否存在，不存在则创建
    if ! getent group promxy > /dev/null 2>&1; then
        groupadd --system promxy
    fi

    # 检查promxy用户是否存在，不存在则创建
    if ! id -u promxy > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/promxy --no-create-home --gid promxy promxy
    fi

    chown -R promxy:promxy /var/lib/promxy
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

# 获取Promxy最新版本
PROMXY_VERSION=$(curl -s "https://api.github.com/repos/jacksontj/promxy/tags" | jq -r '.[0].name')

# 下载并安装Promxy
wget https://github.com/jacksontj/promxy/releases/download/${PROMXY_VERSION}/promxy-${PROMXY_VERSION}-linux-amd64 -O /usr/local/promxy
chmod +x /usr/local/promxy

cat> /etc/systemd/system/promxy.service <<EOF
[Unit]
Description=promxy is a Prometheus proxy server
After=network.target

[Service]
Type=simple
User=promxy
Group=promxy
WorkingDirectory=/var/lib/promxy
ReadWritePaths=/var/lib/promxy
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/promxy --bind-addr=:8082 --config=/etc/promxy/config.yaml
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
ProtectSystem=full
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=promxy
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

cat> /etc/promxy/config.yaml <<EOF
promxy:
  server_groups:
    - static_configs:
        - targets:
          - 192.168.1.102:8428 # 如果涉及多个VM节点，继续下面追加即可
      path_prefix: /prometheus # 追加请求前缀
EOF

chown -R promxy:promxy /var/lib/promxy
chown -R promxy:promxy /etc/promxy

systemctl enable promxy.service
systemctl restart promxy.service
ps aux | grep promxy

echo "promxy installation and service setup complete."

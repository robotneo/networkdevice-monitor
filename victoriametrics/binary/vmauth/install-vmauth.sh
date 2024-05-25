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
    # 创建vmauth配置文件目录
    mkdir -p /etc/victoriametrics/vmauth

    # 检查victoriametrics组是否存在，不存在则创建
    if ! getent group victoriametrics > /dev/null 2>&1; then
        groupadd --system victoriametrics
    fi

    # 检查victoriametrics用户是否存在，不存在则创建
    if ! id -u victoriametrics > /dev/null 2>&1; then
        useradd --system --home-dir /var/lib/victoriametrics --no-create-home --gid victoriametrics victoriametrics
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

# 获取vmauth最新版本
VM_VERSION=$(curl -s "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | grep '"name":' | head -n 1 | awk -F '"' '{print $4}')

# 下载并安装vmauth
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/vmutils-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/vmutils.tar.gz

cd /tmp && tar -xzvf /tmp/vmutils.tar.gz vmauth-prod
mv /tmp/vmauth-prod /usr/bin
chmod +x /usr/bin/vmauth-prod

cat> /etc/systemd/system/vmauth.service <<EOF
[Unit]
Description=vmauth is used for authenticating and authorizing incoming requests.
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/victoriametrics/vmauth/vmauth.conf
ExecStart=/usr/bin/vmauth-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=vmauth

[Install]
WantedBy=multi-user.target
EOF

cat> /etc/victoriametrics/vmauth/vmauth.conf <<EOF
ARGS="-auth.config=/etc/victoriametrics/vmauth/config.yml"
EOF

cat> /etc/victoriametrics/vmauth/config.yml <<EOF
# balance load among vmselects
# see https://docs.victoriametrics.com/vmauth/#load-balancing
unauthorized_user:
  # 数据传入负载
  url_map:
  - src_paths:
    - "/insert/.+"
    url_prefix:
    # - "http://vminsert-1:8480/insert/0/prometheus"
    - "http://vminsert-1:8480/"
    - "http://vminsert-2:8480/"
    - "http://vminsert-3:8480/"
  - src_paths:
    - "/select/.+"
    url_prefix:
    - "http://vmselect-1:8481/"
    - "http://vmselect-2:8481/"
    - "http://vmselect-3:8481/"
    retry_status_codes: [500, 502, 503]
    load_balancing_policy: first_available
EOF

chown -R victoriametrics:victoriametrics /etc/victoriametrics/vmauth

systemctl enable vmauth.service
systemctl restart vmauth.service
ps aux | grep vmauth

echo "vmauth installation and service setup complete."
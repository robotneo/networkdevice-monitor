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
    # 创建vmalert配置文件目录
    mkdir -p /etc/victoriametrics/vmalert

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

# 获取vmalert最新版本
VM_VERSION=$(curl -s "https://api.github.com/repos/VictoriaMetrics/VictoriaMetrics/tags" | grep '"name":' | head -n 1 | awk -F '"' '{print $4}')

# 下载并安装vmalert
wget https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/${VM_VERSION}/vmutils-linux-amd64-${VM_VERSION}.tar.gz -O /tmp/vmutils.tar.gz

cd /tmp && tar -xzvf /tmp/vmutils.tar.gz vmalert-prod
mv /tmp/vmalert-prod /usr/bin
chmod +x /usr/bin/vmalert-prod

# 清理 /tmp 目录中的压缩文件和解压后的临时文件
rm -rf /tmp/vmutils.tar.gz /tmp/vmalert-prod*

cat> /etc/systemd/system/vmalert.service <<EOF
[Unit]
Description=vmalert executes a list of the given alerting or recording rules against configured address. It is heavily inspired by Prometheus implementation and aims to be compatible with its syntax.
# https://docs.victoriametrics.com/vmalert.html
After=network.target

[Service]
Type=simple
User=victoriametrics
Group=victoriametrics
StartLimitBurst=5
StartLimitInterval=0
Restart=on-failure
RestartSec=1
EnvironmentFile=-/etc/victoriametrics/vmalert/vmalert.conf
ExecStart=/usr/bin/vmalert-prod \$ARGS
ExecStop=/bin/kill -s SIGTERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
# See docs https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#tuning
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
StandardOutput=syslog
StandardError=syslog
# StandardOutput=journal
# StandardError=journal
SyslogIdentifier=vmalert

[Install]
WantedBy=multi-user.target
EOF

cat> /etc/victoriametrics/vmalert/vmalert.conf <<EOF
ARGS="-rule=/etc/victoriametrics/vmalert/alerts.yml -datasource.url=http://127.0.0.1:8428 -notifier.url=http://127.0.0.1:9093 -remoteWrite.url=http://127.0.0.1:8428 -remoteRead.url=http://127.0.0.1:8428"
EOF

chown -R victoriametrics:victoriametrics /etc/victoriametrics/vmalert

systemctl enable vmalert.service
systemctl restart vmalert.service
ps aux | grep vmalert

echo "vmalert installation and service setup complete."
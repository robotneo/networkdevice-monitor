## 二进制部署 alertmanager 组件

### 创建用户
```bash
useradd --no-create-home --shell /bin/false alertmanager
```

### 下载并解压
```bash
VM_VERSION=$(curl -s "https://api.github.com/repos/prometheus/alertmanager/tags" | grep '"name":' | head -n 1 | awk -F '"' '{print $4}' | sed 's/v//')
wget https://github.com/prometheus/alertmanager/releases/download/{$VM_VERSION}/alertmanager-{$VM_VERSION}.linux-amd64.tar.gz
tar -xvf alertmanager-{$VM_VERSION}.linux-amd64.tar.gz
mv alertmanager-{$VM_VERSION}.linux-amd64/alertmanager /usr/local/bin/
mv alertmanager-{$VM_VERSION}.linux-amd64/amtool /usr/local/bin/

chown alertmanager:alertmanager /usr/local/bin/alertmanager
chown alertmanager:alertmanager /usr/local/bin/amtool
```

### 清理文件
```bash
rm -rf alertmanager-{$VM_VERSION}*
```

### 创建配置文件
```bash
mkdir /etc/alertmanager
mkdir /var/lib/alertmanager-data
vim /etc/alertmanager/alertmanager.yml

### 配置
--------------------------------
route:
  receiver: blackhole

receivers:
  - name: blackhole
--------------------------------
```

### 改变所有者
```bash
chown alertmanager:alertmanager -R /etc/alertmanager
```

### 创建 systemd 单元文件
```bash
sudo vim /etc/systemd/system/alertmanager.service
--------------------------------
[Unit]
Description=Alertmanager for prometheus

[Service]
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
          --config.file=/etc/alertmanager/alertmanager.yml \
          --storage.path=/var/lib/alertmanager-data

ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
--------------------------------
```

### 运行服务
```bash
sudo systemctl daemon-reload
sudo systemctl enable alertmanager.service
sudo systemctl start alertmanager.service
```
### 关于企业级无线产品的监控和告警（基于Prometheus + SNMP Exporter + Grafana）

- 适配品牌：华为、华三、锐捷，后续持续更新其他品牌，欢迎有相关品牌的无线产品资源的联系我
- snmp_exporter版本：0.24.1

#### 目录介绍

- wireless_monitor顶级目录，下面是各品牌的英文名称，如：h3c、huawei、ruijie等
- 品牌名称下就是mibs文件夹，放置了相关品牌的mib库文件
- 品牌目录下的info.txt是说明信息，generator.yml文件是已经适配对应品牌并测试好的常规SNMP导出配置生成器，里面的指标都是常用无线数据指标：AC的CPU使用率、内存使用率、温度、启动时间等，AP的内存使用率、CPU使用率、温度、状态、上线时间、承载用户数、型号、名称、IP、MAC等指标数据，详情指标直接到generator.yml中查看。

> 如果generator.yml文件中的指标不满足你的监控需求，可自定义编写，添加自定义指标，满足自身监控需求，也可以反馈issue中，如果我觉得合适会添加适配。

#### 使用配置

##### 前提

- Prometheus搭建好，这里我不提供搭建教程，如有需要可到我知乎和微信公众号查看：网络小斐。
- AC配置好SNMP Agent，推荐使用v2c版本，如果对安全需求很大可开启v3版本。
- 准备好一台单独的Linux服务器，系统推荐CentOS 7.9，用来单独部署SNMP Exporter。

##### 搭建

Linux首先需要部署git，当然你也可以直接从github下载源码包，上传到服务器中，这里默认用git拉snmp_exporter源码包到服务器本地。

```bash
Ubuntu下载依赖包：
sudo apt-get install unzip build-essential libsnmp-dev

CentOS下载依赖包：
sudo yum install gcc gcc-g++ make net-snmp net-snmp-utils net-snmp-libs net-snmp-devel
```

这里用CentOS 7.9作为演示：

```bash
# 下载git
sudo yum install -y git curl wget
# curl 更新
yum -y install epel-release 
wget http://mirror.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-3-9.rhel7.noarch.rpm
rpm -ivh city-fan.org-release-3-9.rhel7.noarch.rpm

vim /etc/yum.repos.d/city-fan.org.repo
[city-fan.org]
name=city-fan.org repository for Red Hat Enterprise Linux (and clones) $releasever ($basearch)
#baseurl=http://mirror.city-fan.org/ftp/contrib/yum-repo/rhel$releasever/$basearch
mirrorlist=http://mirror.city-fan.org/ftp/contrib/yum-repo/mirrorlist-rhel$releasever
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-city-fan.org

yum update curl --enablerepo=city-fan.org -y
curl --version

# 安装golang 1.20.x https://golang.google.cn/dl/
wget https://golang.google.cn/dl/go1.20.8.linux-amd64.tar.gz
# 解压安装
tar -zxvf go1.20.8.linux-amd64.tar.gz -C /usr/local
# 将go添加到环境变量
vim /etc/profile

if [ -n "${BASH_VERSION-}" ] ; then
        if [ -f /etc/bashrc ] ; then
                # Bash login shells run only /etc/profile
                # Bash non-login shells run only /etc/bashrc
                # Check for double sourcing is done in /etc/bashrc.
                . /etc/bashrc
       fi
fi
#go 环境变量
export GO111MODULE=on
export GOPROXY=https://goproxy.cn,direct
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# 应用环境变量
source /etc/profile

# 拉取snmp_exporter
git clone https://github.com/prometheus/snmp_exporter.git
# 进入目录snmp_exporter
cd snmp_exporter/
# 构建snmp_exporter二进制可执行文件
go build
# 查看生成的二进制可执行文件
ls -lsh  snmp_exporter

# 进入生成器目录构建二进制可执行文件
cd snmp_exporter/generator/
# 国内网络下载mib公共库报错 忽略即可 make: *** [mibs/apc-powernet-mib] 错误 22
make generator mibs

# mibs文件夹中放入对应品牌的无线设备mib库文件即可
# 把对应的generator.yml文件放入 ../snmp_exporter/generator/ 目录下
export MIBDIRS=/root/snmp_exporter/generator/mibs
./generator generate

mv snmp.yml ../

# 重启snmp_exporter
systemctl restart snmp_exporter
```
##### ./generator generate 案例
![generate](image.png)

##### Prometheus.yml如何添加Job

查看目录中prometheus.yml文件中配置案例

grafana.json只是根据案例中的指标写出的json模版，适配每个环境下的监控需要做一定的修改.
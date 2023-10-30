# 关于对物理机器和网络设备信息采集，针对Prometheus侧采集配置文件

关于Prometheus搭建完成之后，应该如何配置服务发现，目录中的配置文件是我的最佳实践，可以开箱即用，配置好相应的配置就能采集到对象指标

主要是关于prometheus.yml中的 `scrape_configs` 配置

- SNMP协议采集是通过文件服务发现模式 `file_sd_configs` 实现对配置文件的自动加载，如果需要添加对象只需要修改指定路径下文件对象，主要是labels和target。

如：
```
# /root/monitor/prometheus/targets/目录下有个network-switch.yml文件，在Prometheus中可以通过通配符匹配对应文件
/root/monitor/prometheus/targets/network-*.yml

# network-switch.yml文件示例

# Prometheus通过文件发现机制定义的采集目标
- labels:
    module: huawei_common,huawei_core   # generator.yml中定义的指标模块名称，如果有多个可以写多个模块名
    auth: public_v2     # generator.yml中定义的认证模块名
    brand: Huawei       # 可删除可自定义
    hostname: XX-XXXX-CORE  # 可删除可自定义
    model: S12700E-4        # 可删除可自定义
  targets:
    - 172.17.14.1   # 核心  # 需要采集的交换机管理IP
- labels:
    module: HUAWEI
    auth: public_v2
    brand: Huawei
    hostname: XXXX-XXX-XX-AG
    model: S5720-36C-EI-AC
  targets:
    - 172.17.14.2   # 汇聚
```

- node_exporter和blackbox_exporter都是通过consul_sd_configs服务发现机制，结合 [https://github.com/starsliao/TenSunS](https://github.com/starsliao/TenSunS) 实现WEB UI界面对采集对象的管理


更多问题可直接咨询我
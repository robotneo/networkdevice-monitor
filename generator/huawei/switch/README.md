# 华为交换机通过SNMP协议配置OID信息，采集对应OID指标信息生成器的配置文件

## 模块说明

generator-demo.yml中的文件就是配置生成器配置文件，如果需要自定义采集指标，请自行查阅官方MIB库信息，根据对应的OID拿到自己需要的指标信息。

华为官方MIB信息查询：https://info.support.huawei.com/info-finder/tool/zh/enterprise/mib

- huawei_common 这对华为通用交换机的常规指标采集
- huawei_core 针对华为核心交换机的指标采集 基于CloudEngine S12700E-4

## MIB库文件

- MIB_V200R022C00SPC500.zip 压缩包基于CloudEngine S12700E-4版本的MIB库文件，文件解压缩有一个文件说明该MIB库支持的交换机固件版本列表
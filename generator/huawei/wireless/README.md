本目录中generator.yml是适配了华为无线AC6000系列的无线控制器。
已完成测试：AC6003、AC6005、AC6508、AC6605，其他型号未做测试，理论上讲AC6000系列通用。

华为无线产品mib库下载链接：
根据对应的版本下载对应的MIB，如：AC6605 V200R019C00SPC500

下载路径：技术支持 > 无线局域网 > AC > AC6000 > 软件 > 选择版本过滤

链接：https://support.huawei.com/enterprise/zh/software/250730566-ESW2000205621


华为无线产品mib OID信息参考链接：
根据对应的版本做参考，如：WLAN AC V200R019C10 MIB参考
链接：https://support.huawei.com/enterprise/zh/doc/EDOC1100156646

mibs文件夹中，我已经提前下载好对应两个比较推荐的版本的mib库文件，需要自行解压得到mib后缀的文件。

推荐版本1(V200R019C00SPC500)：MIB_WLAN_V200R019C00SPC500.zip
推荐版本2(V200R022C00SPC100)：MIB_WLAN_V200R022C00SPC100.zip

至于下载那个版本的，需要查看你AC中目前的对应什么版本号。
由于我测试的AC6005、AC6508、AC6605都升级到V200R019C00SPC500版本，
故都是使用MIB_WLAN_V200R019C00SPC500.zip中的库文件。
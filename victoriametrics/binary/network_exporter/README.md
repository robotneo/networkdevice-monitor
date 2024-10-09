## 二进制部署单节点 network_exporter 脚本

安装完成后，关于启动参数和配置文件说明：

network_exporter 二进制文件放置在新创建目录：`/opt/network_exporter` 目录中

network_exporter 的配置参数文件在：`/opt/network_exporter/network_exporter.yml` 文件中，如果需要配置探测目标，以及自定义 network_exporter 目标，可直接修该文件。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status network_exporter.service
- 停止：sudo systemctl stop network_exporter.service
- 启动：sudo systemctl start network_exporter.service
- 重启：sudo systemctl restart network_exporter.service
- 开机自启：sudo systemctl enable network_exporter.service

更多关于 network_exporter 的教程请查看官方文档：[network_exporter文档](https://github.com/syepes/network_exporter)
## 二进制部署单节点 node_exporter 脚本

安装完成后，关于启动参数和配置文件说明：

blackbox_exporter 二进制文件放置在新创建目录：`/opt/blackbox_exporter` 目录中

blackbox_exporter 的模块配置参数文件在：`/opt/blackbox_exporter/blackbox.yml` 文件中，如果需要修改模块配置，可直接修改该文件。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status blackbox_exporter.service
- 停止：sudo systemctl stop blackbox_exporter.service
- 启动：sudo systemctl start blackbox_exporter.service
- 重启：sudo systemctl restart blackbox_exporter.service
- 开机自启：sudo systemctl enable blackbox_exporter.service

更多关于 blackbox_exporter 的教程请查看官方文档：[blackbox_exporter文档](https://github.com/prometheus/blackbox_exporter)
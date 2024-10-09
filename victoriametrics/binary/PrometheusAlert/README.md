## 二进制部署单节点 PrometheusAlert 脚本

安装完成后，关于启动参数和配置文件说明：

PrometheusAlert 二进制文件放置在新创建目录：`/opt/PrometheusAlert` 目录中

PrometheusAlert 的配置参数文件在：`/opt/PrometheusAlert/conf/app.conf` 文件中，如果需要开启飞书、钉钉、企业微信等 webhook 配置可直接修该文件。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status prometheusalert.service
- 停止：sudo systemctl stop prometheusalert.service
- 启动：sudo systemctl start prometheusalert.service
- 重启：sudo systemctl restart prometheusalert.service
- 开机自启：sudo systemctl enable prometheusalert.service

更多关于 PrometheusAlert 的教程请查看官方文档：[PrometheusAlert文档](https://feiyu563.gitbook.io/)
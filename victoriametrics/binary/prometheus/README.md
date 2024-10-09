## 二进制部署单节点 Prometheus 脚本

安装完成后，关于启动参数和配置文件说明：

prometheus 和 promtool 二进制文件分别放置在系统目录：`/usr/bin` 目录中

环境变量启动参数在：`/etc/prometheus/single/prometheus.conf` 文件中，如果需要修改 prometheus 的启动参数，可直接把参数放在这个文件中的固定格式，然后重启 prometheus 进程即可。

prometheus 的配置参数文件在：`/etc/prometheus/single/prometheus.yml` 文件中，如果需要配置抓取任务、告警规则文件、以及 Alertmanager 地址和全局标签可在这个文件中修改冲重加载即可。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status prometheus.service
- 停止：sudo systemctl stop prometheus.service
- 启动：sudo systemctl start prometheus.service
- 重启：sudo systemctl restart prometheus.service
- 开机自启：sudo systemctl enable prometheus.service
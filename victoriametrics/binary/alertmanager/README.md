## 二进制部署单节点 alertmanager 脚本

安装完成后，关于启动参数和配置文件说明：

alertmanager 和 amtool 二进制文件分别放置在系统目录：`/usr/bin` 目录中

环境变量启动参数在：`/etc/alertmanager/alertmanager.conf` 文件中，如果需要修改 alertmanager 的启动参数，可直接把参数放在这个文件中的固定格式，然后重启 alertmanager 进程即可。

alertmanager 的配置参数文件在：`/etc/alertmanager/alertmanager.yml` 文件中，如果需要配置告警分组、告警路由、告警抑制可通过修改这个文件。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status alertmanager.service
- 停止：sudo systemctl stop alertmanager.service
- 启动：sudo systemctl start alertmanager.service
- 重启：sudo systemctl restart alertmanager.service
- 开机自启：sudo systemctl enable alertmanager.service
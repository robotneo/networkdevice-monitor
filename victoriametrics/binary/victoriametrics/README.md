## 二进制部署单节点 VictoriaMetrics 脚本

安装完成后，关于启动参数和配置文件说明：

victoria-metrics-prod 二进制文件放置在系统目录：`/usr/bin` 目录中

环境变量启动参数在：`/etc/victoriametrics/single/vmsingle.conf` 文件中，如果需要修改 VictoriaMetrics 的启动参数，可直接把参数放在这个文件中的固定格式，然后重启 VictoriaMetrics 进程即可。

时序库数据保存的文件路径：`/var/lib/victoria-metrics-data` 目录中。

VictoriaMetrics 单节点支持抓取任务，标签重置等功能，只需要在环境变量启动参数中添加：`-promscrape.config=scrape.yaml` 参数即可实现主动 `pull` 抓取目标指标数据。

一般建议把文件：`/etc/victoriametrics/single/scrape.yaml` 放在和 `/etc/victoriametrics/single/vmsingle.conf` 文件同目录下，如何写 `scrape.yaml` 可以直接查看文档：[抓取配置](https://docs.victoriametrics.com/scrape_config_examples/) 但是由于我们的架构是使用 `vmagent` 故在这里VictoriaMetrics 就是很纯粹的当作时序库存储数据即可，其他抓取任务配置、标签重置、聚合等都交给 `vmagent` ，而告警规则配置交给 `vmalert` 即可，从而 VictoriaMetrics 解放双手，纯粹做单一事务。

二进制文件启动都使用 systemd 管理进程，可直接执行下面的命令查看prometheus进程状态：

- 状态：sudo systemctl status victoria-metrics.service
- 停止：sudo systemctl stop victoria-metrics.service
- 启动：sudo systemctl start victoria-metrics.service
- 重启：sudo systemctl restart victoria-metrics.service
- 开机自启：sudo systemctl enable victoria-metrics.service
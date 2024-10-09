## docker compose 部署单节点Prometheus

使用 Grafana + Prometheus + alertmanager 组合。

使用前请修改Grafana配置文件中密码，当前admin密码为admin

使用外部配置文件挂载到容器内部

文件结构：

```bash
docker-prometheus/
├── alertmanager
│   └── config.yml
├── docker-compose.yml
├── grafana
│   ├── config.monitoring
│   └── provisioning
└── prometheus
    ├── alert.yml
    └── prometheus.yml
```
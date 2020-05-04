# Prometheus Swarm

`Swarmprom` is a starter kit for Docker Swarm monitoring with [Prometheus](https://prometheus.io/),
[Grafana](http://grafana.org/),
[cAdvisor](https://github.com/google/cadvisor),
[Node Exporter](https://github.com/prometheus/node_exporter),
[Alert Manager](https://github.com/prometheus/alertmanager)
and [Unsee](https://github.com/cloudflare/unsee).

The full source / instructions are from: https://github.com/stefanprodan/swarmprom.git. 

To start this stack just run the following command from this directory. Be sure that the machine you run it on is in the same swarm as your main project and then call docker stack deploy:

```
cd GITLAB_REPO_NAME/Docker/prometheus-swarm
docker stack deploy -c docker-compose.yml prometheus
```
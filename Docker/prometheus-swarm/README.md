# Prometheus Swarm

`Swarmprom` is a starter kit for Docker Swarm monitoring with [Prometheus](https://prometheus.io/),
[Grafana](http://grafana.org/),
[cAdvisor](https://github.com/google/cadvisor),
[Node Exporter](https://github.com/prometheus/node_exporter),
[Alert Manager](https://github.com/prometheus/alertmanager)
and [Unsee](https://github.com/cloudflare/unsee).

The full source / instructions are from: https://github.com/stefanprodan/swarmprom.git

This is a minimalized version with a custom docker-compose suited just for SWARM_NAME. You can launch it locally when testing swarm stuff in development by:

1. Be sure you turned off https stuff in SWARM_NAME swarm (flagged by HTTPS_SWITCH)

2. Deploying the stack
    cd GITLAB_REPO_NAME/Docker/prometheus-swarm
    docker stack deploy -c docker-compose.yml prometheus_swarm

3. Visit grafana.localhost

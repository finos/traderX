---
title: AWS EC2 Compose Prerequisites (AL2023)
---

# AWS EC2 Compose Prerequisites (AL2023)

This runbook captures the validated EC2 host setup for deploying TraderX generated state branches with the `aws-ec2-compose` deployment bundle.

Use this for host preparation and operational baseline. Use each generated state's `runtime/deploy/aws-ec2-compose/README.md` for state-specific deploy variables and commands.

## 1) Environment Coordinates

Add environment coordinates to `~/.bashrc`:

```bash
# Optional PAT used for authenticated clone
# export GITHUB_PAT="..."

# 004 demo
# export FQDN_NAME="demo.traderx.finos.org"
# export STATE_BRANCH="code/generated-state-004-containerized-compose-runtime"

# 009 advanced demo
# export FQDN_NAME="demo-advanced.traderx.finos.org"
# export STATE_BRANCH="code/generated-state-009-order-management-matcher"
```

Reload shell config:

```bash
source ~/.bashrc
```

## 2) Docker + Compose + Buildx

Install Docker and Git:

```bash
sudo yum install -y docker git
sudo usermod -a -G docker ec2-user
id ec2-user
newgrp docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
```

Install Docker Compose plugin binary:

```bash
sudo mkdir -p /usr/libexec/docker/cli-plugins/
sudo curl -SL \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
  -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
sudo systemctl restart docker
```

Validate CLI plugins:

```bash
docker compose version
docker buildx version
```

Important: `docker compose up --build` requires Buildx. If deploy fails with `compose build requires buildx 0.17.0 or later`, update/install Buildx before retry.

## 3) Cron Baseline

```bash
sudo yum install -y cronie
sudo systemctl enable crond.service
sudo systemctl start crond.service
crontab -e
```

Example entries:

```cron
0 5 * * * /home/ec2-user/traderx/runtime/deploy/aws-ec2-compose/deploy.sh
0 6 * * * sudo /sbin/shutdown -r +5
0 0,12 * * * /usr/bin/python3 -c 'import random,time; time.sleep(random.random() * 3600)' && sudo certbot renew -q
```

## 4) NGINX + Certbot

```bash
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo rpm -ihv --nodeps ./epel-release-latest-8.noarch.rpm
sudo yum install -y pip nginx
sudo systemctl enable nginx.service
pip3 install certbot certbot-nginx
```

Set `server_name` in nginx to `${FQDN_NAME}` and ensure at minimum:

```nginx
location / {
    proxy_pass http://localhost:8080/;
}
```

State `009` requires NATS websocket passthrough:

```nginx
location /nats-ws {
    proxy_pass http://localhost:8080/nats-ws;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400;
}
```

Issue certificate:

```bash
sudo certbot --nginx -d "${FQDN_NAME}" --agree-tos -m infra@finos.org
sudo nginx -t
sudo systemctl reload nginx
```

## 5) Disk Pressure Cleanup

Use when EC2 host reports `no space left on device`:

```bash
docker system prune -af
docker system prune --volumes -f
docker builder prune -af
```

## 6) Utility Scripts (Optional)

`~/redeploy.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd ~
rm -rf traderx
git clone "https://${GITHUB_PAT}@github.com/finos/traderx.git"
cd traderx
git checkout "$STATE_BRANCH"
./runtime/deploy/aws-ec2-compose/cleanup.sh
./runtime/deploy/aws-ec2-compose/deploy.sh
```

`~/cleanup.sh`:

```bash
#!/bin/bash
set -euo pipefail

sudo rm -rf /var/log/journal/*
docker system prune -a -f
docker system prune --volumes -f
docker builder prune -af
docker rm -v $(sudo docker ps -a -q -f status=exited)
docker rmi -f $(sudo docker images -f "dangling=true" -q)
docker volume ls -qf dangling=true | xargs -r docker volume rm
```

Make executable:

```bash
chmod +x ~/redeploy.sh ~/cleanup.sh
```

---
title: Demo 009 Cutover Checklist
---

# Demo 009 Cutover Checklist

This checklist is for deploying state `009-order-management-matcher` to `demo-advanced.traderx.finos.org`.

## Preconditions

- EC2 host prepared using `/docs/spec-kit/aws-ec2-compose-prerequisites`.
- DNS for `demo-advanced.traderx.finos.org` points to the target instance.
- TLS certificate issued and nginx active.
- Security group allows inbound `80` and `443`.
- Repository has `runtime/deploy/aws-ec2-compose/*` in the selected generated-state branch.

## Environment Setup

```bash
export FQDN_NAME="demo-advanced.traderx.finos.org"
export STATE_BRANCH="code/generated-state-009-order-management-matcher"
```

## NGINX Requirement for 009

State `009` requires websocket proxying for `/nats-ws`. Ensure the TLS server block includes:

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

Then validate and reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Dry Run Validation

```bash
cd ~/traderx
git fetch --all --prune
git checkout "${STATE_BRANCH}"
git reset --hard "origin/${STATE_BRANCH}"
TRADERX_FQDN="${FQDN_NAME}" ./runtime/deploy/aws-ec2-compose/deploy.sh --dry-run
```

Expected:

- branch resolves successfully
- compose file path is valid
- rendered deploy command includes `docker compose ... up -d --build`

## Deploy

```bash
TRADERX_FQDN="${FQDN_NAME}" ./runtime/deploy/aws-ec2-compose/cleanup.sh
TRADERX_FQDN="${FQDN_NAME}" ./runtime/deploy/aws-ec2-compose/deploy.sh
```

If build fails with Buildx version errors:

```bash
docker buildx version
```

Update Buildx per prerequisites runbook, then rerun deploy.

## Post-Deploy Smoke

```bash
docker ps
curl -fsS "http://localhost:8080/health"
curl -I "https://${FQDN_NAME}"
```

009-specific checks:

- open app and validate order ticket + order blotter behavior
- confirm browser console has no recurring NATS websocket errors
- in browser Network, verify websocket reaches `wss://${FQDN_NAME}/nats-ws`

## Rollback

Keep a previous known-good generated branch value:

```bash
export ROLLBACK_BRANCH="<previous-generated-branch>"
TRADERX_BRANCH="${ROLLBACK_BRANCH}" TRADERX_FQDN="${FQDN_NAME}" ./runtime/deploy/aws-ec2-compose/deploy.sh
```

If rollback branch is unknown, use repository history to pick prior successful snapshot SHA and deploy from that ref.

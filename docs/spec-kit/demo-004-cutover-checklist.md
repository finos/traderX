---
title: Demo 004 Cutover Checklist
---

# Demo 004 Cutover Checklist

This checklist is for replacing `demo.traderx.finos.org` with state `004-containerized-compose-runtime` on EC2.

## Preconditions

- EC2 host prepared using `/docs/spec-kit/aws-ec2-compose-prerequisites`.
- DNS for `demo.traderx.finos.org` points to the target instance.
- TLS certificate issued and nginx active.
- Security group allows inbound `80` and `443`.
- Repository has `runtime/deploy/aws-ec2-compose/*` in the selected generated-state branch.

## Environment Setup

```bash
export FQDN_NAME="demo.traderx.finos.org"
export STATE_BRANCH="code/generated-state-004-containerized-compose-runtime"
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

Optional app-level checks:

- load `/` in browser
- verify trades/positions update flow
- verify websocket-backed endpoints (`/socket.io/`, `/trade-feed/`) work through nginx

## Rollback

Keep a previous known-good generated branch value:

```bash
export ROLLBACK_BRANCH="<previous-generated-branch>"
TRADERX_BRANCH="${ROLLBACK_BRANCH}" TRADERX_FQDN="${FQDN_NAME}" ./runtime/deploy/aws-ec2-compose/deploy.sh
```

If rollback branch is unknown, use repository history to pick prior successful snapshot SHA and deploy from that ref.

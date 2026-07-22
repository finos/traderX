# AWS EC2 Compose Deploy Bundle (009-order-management-matcher)

This bundle is generated for state `009-order-management-matcher` and is intended for compose-based demo rollout.

## Defaults

- Branch: `code/generated-state-009-order-management-matcher`
- Environment label: `demo-advanced`
- Domain/FQDN hint: `demo-advanced.traderx.finos.org`
- Compose file: `order-management-matcher/docker-compose.yml`

## Required runtime inputs

- `TRADERX_FQDN` (if no default domain was generated for this state)

## Optional runtime inputs

- `TRADERX_REPO_URL` (default: `https://github.com/finos/traderX.git`)
- `TRADERX_BRANCH` (default: generated-state branch for this state)
- `TRADERX_WORKDIR` (default: `$HOME/traderx`)
- `TRADERX_COMPOSE_PATH_REL` (default: `order-management-matcher/docker-compose.yml`)
- `TRADERX_GHCR_COMPOSE_PATH_REL` (default: `runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml`)
- `TRADERX_COMPOSE_PROJECT_NAME` (default: `traderx-009-order-management-matcher`)
- `TRADERX_DEPLOY_ENV` (default: `demo-advanced`)
- `TRADERX_IMAGE_TAG` (default: `latest`)
- `TRADERX_CORS_ALLOWED_ORIGINS` (default: `https://$TRADERX_FQDN,http://$TRADERX_FQDN,http://localhost:8080`)
- `TRADERX_PRUNE_DOCKER` (`1` enables aggressive prune in `cleanup.sh`)
- `TRADERX_RUN_CLEANUP` (`1` runs cleanup before `upgrade.sh`)

## Dry-run examples

```bash
./runtime/deploy/aws-ec2-compose/deploy.sh --dry-run
./runtime/deploy/aws-ec2-compose/deploy.sh --use-ghcr --dry-run
./runtime/deploy/aws-ec2-compose/upgrade.sh --dry-run
./runtime/deploy/aws-ec2-compose/cleanup.sh --dry-run
```

## Front Proxy Note

If you run an external NGINX in front of TraderX, include
`runtime/deploy/aws-ec2-compose/nginx.reverse-proxy.snippet.conf` in that front-proxy
server block. This generated snippet is state-aware and includes websocket routes
that match the emitted runtime ingress transport for this state.

## Host Setup

Before running deploy/upgrade, verify host prerequisites:

```bash
./runtime/deploy/aws-ec2-compose/host-setup-check.sh
```

Install missing prerequisites (or preview with dry-run):

```bash
./runtime/deploy/aws-ec2-compose/host-setup-install.sh --dry-run
./runtime/deploy/aws-ec2-compose/host-setup-install.sh
```

Canonical host prerequisites guidance:

- https://github.com/finos/traderX/blob/main/docs/spec-kit/aws-ec2-compose-prerequisites.md

## Public Repo Clone Default

Generated-state branches in `finos/traderX` are public. Default deploy flow uses:

```bash
git clone https://github.com/finos/traderX.git
```

Use token-authenticated clone URLs only when deploying from private forks/overlays.

---
title: AWS EC2 Compose Host Prerequisites
---

# AWS EC2 Compose Host Prerequisites

This guide documents host-level prerequisites for running generated TraderX deploy bundles on an EC2 host with an external NGINX reverse proxy.

## Scope

- Applies to generated deployment bundles under `runtime/deploy/aws-ec2-compose/`.
- Intended for containerized states that opt in to deploy bundles.
- For Kubernetes runtime profile planning, see `/docs/spec-kit/aws-ec2-kubernetes-prerequisites`.

## Required Host Tools

- `git`
- `docker` engine
- Docker Compose v2 plugin (`docker compose`)
- `jq`
- `curl`
- `nginx`

Recommended for TLS/public domains:

- `certbot` (+ nginx plugin package)

## Generated Host Setup Scripts

Every generated `aws-ec2-compose` deploy bundle should include:

- `host-setup-check.sh`: verifies required host prerequisites and reports missing tools.
- `host-setup-install.sh`: installs missing prerequisites using the host package manager (`apt-get`, `dnf`, or `yum`).

Run check-only:

```bash
./runtime/deploy/aws-ec2-compose/host-setup-check.sh
```

Dry-run install plan:

```bash
./runtime/deploy/aws-ec2-compose/host-setup-install.sh --dry-run
```

Install prerequisites:

```bash
./runtime/deploy/aws-ec2-compose/host-setup-install.sh
```

## Reverse Proxy

For environments with an external NGINX in front of TraderX, use the generated snippet:

- `runtime/deploy/aws-ec2-compose/nginx.reverse-proxy.snippet.conf`

The snippet is state-aware and includes websocket mappings required by the emitted runtime transport for that state.

## Public Branch Clone Guidance

Generated-state branches are public in the FINOS repository. Default deploy flow should clone without a GitHub token:

```bash
git clone https://github.com/finos/traderX.git
```

Use authenticated clone URLs only for private forks/overlays that actually require credentials.

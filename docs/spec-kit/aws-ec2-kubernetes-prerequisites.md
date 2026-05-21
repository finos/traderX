---
title: AWS EC2 Kubernetes Host Prerequisites
---

# AWS EC2 Kubernetes Host Prerequisites

This document defines the host and cluster prerequisites for a future `aws-ec2-k8s` deployment profile.

Status:

- Profile contract defined in specs/docs.
- Generation support not yet enabled.

## Scope

- Intended for Kubernetes runtime lineage (`010+`) when deployment bundles are enabled for those states.
- Complements `aws-ec2-compose` guidance and does not replace it.

## Required Host Tooling

- `git`
- `docker` (for local build/cache workflows where needed)
- `kubectl`
- `helm`
- `jq`
- `curl`
- `nginx` (if using host-level edge TLS/termination)

## Required Cluster Capabilities

- Kubernetes cluster reachable from host (single-node or multi-node).
- Ingress controller installed and active.
- Storage class available for stateful workloads.
- Image pull path configured for emitted runtime images (local load, registry pull, or mirror).

## Planned Deploy Bundle Assets (`aws-ec2-k8s`)

When this profile is enabled, generated bundles should include:

- `runtime/deploy/aws-ec2-k8s/README.md`
- `runtime/deploy/aws-ec2-k8s/deploy.sh`
- `runtime/deploy/aws-ec2-k8s/upgrade.sh`
- `runtime/deploy/aws-ec2-k8s/cleanup.sh`
- `runtime/deploy/aws-ec2-k8s/host-setup-check.sh`
- `runtime/deploy/aws-ec2-k8s/host-setup-install.sh`
- `runtime/deploy/aws-ec2-k8s/ingress.values.yaml` (or equivalent)
- `runtime/deploy/aws-ec2-k8s/smoke-test.sh`

## Enablement Rule

Do not set Kubernetes state `deploy.enabled=true` with profile `aws-ec2-k8s` until:

1. Generator emits the profile assets above.
2. Generated deploy scripts support `--dry-run`.
3. Smoke tests validate ingress/API/UI/WebSocket behavior for the emitted state.

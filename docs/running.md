---
id: running
title: "Build & Run Guide"
sidebar_label: Build & Run
---

# Build & Run Guide

There are several ways to run TraderX locally. Choose the method you're most comfortable with.

## Quick Start (Docker Compose)

The easiest way to run the entire system:

```bash
git clone https://github.com/finos/traderX.git
cd traderX
docker compose up
```

Once everything starts, the WebUI is accessible at http://localhost:8080.

---

## Run Options

- [Docker Compose](#docker-compose) - Easiest, recommended for most users
- [Kubernetes with Tilt](#kubernetes-with-tilt) - For K8s-native development
- [Manual Run](#manual-run) - Run each service individually
- [Corporate Environments](#corporate-environments) - Custom artifact repositories

---

## Docker Compose

Docker Compose works on your local machine (tested on Mac Silicon) and in GitHub Codespaces.

### GitHub Codespaces

For Codespaces, select an **8-core machine with 32GB RAM**:

1. Click the green **Code** button at the top of the repo
2. Select the **Codespaces** tab, click `...` → **New with options...**
3. Change machine type to **8-core** and click **Create codespace**

> Personal GitHub accounts receive 120 free core hours per month. [Details](https://docs.github.com/en/billing/managing-billing-for-github-codespaces/about-billing-for-github-codespaces#monthly-included-storage-and-core-hours-for-personal-accounts)

### Running

```bash
docker compose up
```

On first run, this builds all containers from project-specific Dockerfiles and starts them in sequence. Containers connect via a shared virtual network.

**WebUI**: http://localhost:8080 (works with Codespaces too—localhost is mapped through).

---

## Kubernetes with Tilt

Use [tilt.dev](https://tilt.dev) to deploy to a local Kubernetes cluster with hot-reload for local development.

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or similar
- A Kubernetes distribution:
  - [K8s with Docker Desktop](https://docs.docker.com/desktop/kubernetes/)
  - [Kind](https://kind.sigs.k8s.io/)
  - [Minikube](https://minikube.sigs.k8s.io/docs/start/)
  - [k3s](https://k3s.io/)
- [Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/) matching your K8s distribution
- [tilt.dev](https://tilt.dev)

### Preflight Check

```bash
kubectl get pods
```

You should see kube system pods and your ingress controller:

```
NAMESPACE       NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx   ingress-nginx-controller-7d4db76476-7wfl2   1/1     Running     0          38s
kube-system     coredns-7db6d8ff4d-ntdcr                    1/1     Running     0          4h8m
...
```

### Start Tilt

```bash
cd ./gitops/local/
tilt up
```

Press **space** to open the Tilt web UI at http://localhost:10350/

> **Troubleshooting**: If you get `template engine not found for: up`, your OS may be running a Ruby library instead. Check the [tilt.dev installation instructions](https://docs.tilt.dev/install.html).

### Local Development with Tilt

To build and deploy a service locally instead of using pre-built images, edit [gitops/local/Tiltfile](../gitops/local/Tiltfile) and uncomment the relevant line:

```python
# Uncomment lines to use locally built version
# docker_build('ghcr.io/finos/traderx/database', './../../database/.')
# docker_build('ghcr.io/finos/traderx/account-service', './../../account-service/.')
docker_build('ghcr.io/finos/traderx/position-service', './../../position-service/.')  # ← uncommented
# ...
```

### Clean Up

```bash
tilt down
```

---

## Manual Run

Run each service individually for maximum control.

### Environment Variables

Export these port variables (or add to your shell profile):

```bash
export DATABASE_TCP_PORT=18082
export DATABASE_PG_PORT=18083
export DATABASE_WEB_PORT=18084
export REFERENCE_DATA_SERVICE_PORT=18085
export TRADE_FEED_PORT=18086
export ACCOUNT_SERVICE_PORT=18088
export PEOPLE_SERVICE_PORT=18089
export POSITION_SERVICE_PORT=18090
export TRADE_PROCESSOR_SERVICE_PORT=18091
export TRADING_SERVICE_PORT=18092
export WEB_SERVICE_ANGULAR_PORT=18093
export WEB_SERVICE_REACT_PORT=18094
```

### Startup Sequence

Start services in this order so dependencies are available:

1. `database`
2. `reference-data`
3. `trade-feed`
4. `people-service`
5. `account-service`
6. `position-service`
7. `trade-processor`
8. `trade-service`
9. `web-front-end`

Each service has its own README with specific run instructions.

---

## Corporate Environments

If you're behind a corporate artifact repository and need to override settings like `mavenCentral()` in Gradle:

### Local Gradle Override

Create a `.corp` directory (git-ignored) with custom build scripts:

```bash
mkdir .corp
touch .corp/settings.gradle
```

Add to `.corp/settings.gradle`:

```groovy
// Add your corporate repository overrides here

rootProject.name = 'finos-traderX'
includeFlat 'database'
includeFlat 'account-service'
includeFlat 'position-service'
includeFlat 'trade-service'
includeFlat 'trade-processor'
```

### Build and Run

```bash
# From traderX root
gradle --settings-file .corp/settings.gradle build
gradle --settings-file .corp/settings.gradle account-service:bootRun

# Or from inside .corp directory
cd .corp
./gradlew build
./gradlew account-service:bootRun
```

You can also store a custom Gradle wrapper here if your `distributionUrl` differs from the public one.

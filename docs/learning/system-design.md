# System Design

State: `004-kubernetes-runtime`

## Design Intent

State 004 preserves state 003 browser/API routing behavior while running all services on a local Kubernetes cluster.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 004-kubernetes-runtime

Parent state: `003-containerized-compose-runtime`

State `004` preserves state `003` route semantics while moving runtime orchestration to Kubernetes.

## Entrypoints

- Browser/UI/API entrypoint: `http://localhost:8080`
- Edge health: `http://localhost:8080/health`
- Edge service model: Kubernetes `NodePort` service (`30080`) mapped via Kind extra port mapping.

## Components

- Namespace: `traderx`
- Edge:
  - `edge-proxy` deployment (NGINX)
  - `edge-proxy` service (`NodePort`)
  - `edge-proxy-config` ConfigMap generated from `system/nginx-edge.conf`
- Core services (Deployments + Services):
  - `database`
  - `reference-data`
  - `trade-feed`
  - `people-service`
  - `account-service`
  - `position-service`
  - `trade-processor`
  - `trade-service`
  - `web-front-end-angular`

## Networking

- Browser traffic enters through `edge-proxy` only.
- Edge routes preserve existing prefixes:
  - `/reference-data/*`
  - `/account-service/*`
  - `/position-service/*`
  - `/people-service/*`
  - `/trade-service/*`
  - `/trade-processor/*`
  - `/trade-feed/*`
  - `/socket.io/*`
  - `/db-web/*`
  - `/` (web app)
- Inter-service traffic uses Kubernetes service DNS names.

## Startup / Health Order

- Generation first produces all components + Kubernetes manifests.
- Runtime start sequence:
  1. Ensure target local cluster exists (Kind default; optional Minikube profile).
  2. Build/load service images into the target local cluster runtime.
  3. Apply generated manifests.
  4. Wait for deployment availability.
  5. Probe edge health and UI routes.

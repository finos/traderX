# Runtime Topology: 010-kubernetes-runtime

Parent state: `009-order-management-matcher`

State `010` preserves parent-state functional behavior while moving runtime orchestration to Kubernetes.

## Entrypoints

- Browser/UI/API entrypoint: `http://localhost:8080`
- Edge health: `http://localhost:8080/health`
- Edge service model: Kubernetes `NodePort` service mapped by local cluster provider settings.

## Components

- Namespace: `traderx`
- Edge:
  - `edge-proxy` deployment (NGINX)
  - `edge-proxy` service (`NodePort`)
  - `edge-proxy-config` ConfigMap generated from `system/nginx-edge.conf`
- Core services and supporting components are inherited from state `009` and rendered as Kubernetes Deployments/Services.
- Observability stack inherited from state `009` is rendered as Kubernetes Deployments/Services:
  - `grafana`, `prometheus`, `loki`, `tempo`, `otel-collector`, `blackbox-exporter`

## Networking

- Browser traffic enters through `edge-proxy` only.
- Path prefixes remain stable across inherited API routes and websocket routes.
- Observability entrypoints remain available through edge routes:
  - `/grafana`
  - `/prometheus`
- Inter-service traffic uses Kubernetes service DNS names.

## Startup / Health Order

1. Ensure target local cluster exists (Kind default; optional Minikube).
2. Build/load state images for the selected provider.
3. Apply generated manifests.
4. Wait for deployment availability.
5. Probe edge health and UI routes.

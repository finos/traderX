# Contract Delta: 004-kubernetes-runtime

Parent state: `003-containerized-compose-runtime`

State `004` introduces no API payload/schema deltas. Contract compatibility is preserved while runtime moves to Kubernetes.

## OpenAPI Changes

- No endpoint, request schema, or response schema changes are introduced.
- Existing service path prefixes remain unchanged behind the edge proxy.

## Event Contract Changes

- Trade-feed websocket/event semantics are unchanged.
- Trade processing publish/subscribe contract remains compatible with state `003`.

## Compatibility Notes

- Client-side behavior is intentionally compatible with state `003`.
- Operational migration changes:
  - Service discovery changes from Compose DNS to Kubernetes service DNS.
  - Runtime lifecycle changes from `docker compose up` to `kubectl apply` on generated manifests.

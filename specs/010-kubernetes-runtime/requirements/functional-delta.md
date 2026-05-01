# Functional Delta: 010-kubernetes-runtime

Parent state: `009-order-management-matcher`

State `010` intentionally introduces no business-functional deltas. This transition is runtime/topology-focused.

## Added

- No new user-facing domain functionality.

## Changed

- Runtime substrate changes from Docker Compose to Kubernetes.
- Browser/API entry remains single-origin (`http://localhost:8080`) through an NGINX edge proxy service.

## Removed

- No functional endpoints removed.

## Flow Impact

- F1 Place Trade: unchanged behavior; routed through Kubernetes edge proxy.
- F2 View Positions: unchanged behavior; data path unchanged.
- F3 Account/User lookups: unchanged behavior; cross-service validation unchanged.
- F4 Reference Data lookup: unchanged behavior; ticker validation unchanged.
- F5 Messaging/pub-sub: unchanged behavior; websocket route preserved at `/nats-ws` and realtime blotter push-subscription model remains required.
- F6 UI browsing and navigation: unchanged behavior; single-origin path retained.
- Price-aware UI bootstrap semantics from state `008` remain unchanged (REST snapshot + stream continuation with server-time freshness ordering).

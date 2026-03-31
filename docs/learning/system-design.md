# System Design

State: `005-radius-kubernetes-platform`

## Design Intent

State 005 preserves state 004 Kubernetes runtime while adding Radius application/resource abstractions.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 005-radius-kubernetes-platform

Parent state: `004-kubernetes-runtime`

State `005` reuses Kubernetes runtime topology from state `004` and introduces Radius as platform control/model layer.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080` (inherited).
- Platform operations entrypoints are Radius control artifacts (app/environment definitions).

## Components

- Core TraderX services remain the same as state `004`.
- Added platform layer:
  - Radius application definition
  - Radius environment/resource declarations

## Networking

- Service-to-service network paths remain Kubernetes service DNS based.
- Route semantics and path prefixes remain unchanged from state `004`.

## Startup / Health Order

- Baseline service startup/health remains as in state `004`.
- Radius-driven deployment orchestration defines resource/application ordering declaratively.

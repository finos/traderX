# Runtime Topology: 012-radius-kubernetes-platform

Parent state: `009-kubernetes-runtime`

State `012` reuses Kubernetes runtime topology from state `009` and introduces Radius as platform control/model layer.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080` (inherited).
- Platform operations entrypoints are Radius control artifacts (app/environment definitions).

## Components

- Core TraderX services remain the same as state `009`.
- Added platform layer:
  - Radius application definition
  - Radius environment/resource declarations

## Networking

- Service-to-service network paths remain Kubernetes service DNS based.
- Route semantics and path prefixes remain unchanged from state `009`.

## Startup / Health Order

- Baseline service startup/health remains as in state `009`.
- Radius-driven deployment orchestration defines resource/application ordering declaratively.

# Runtime Topology: 006-tilt-kubernetes-dev-loop

Parent state: `004-kubernetes-runtime`

State `006` reuses runtime topology from state `004` and adds Tilt as local orchestration/dev loop.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080` (inherited).
- Developer control entrypoint is Tilt (`tilt up`) for local iteration.

## Components

- Core TraderX services remain the same as state `004`.
- Added dev tooling layer:
  - Tiltfile and related local k8s orchestration metadata.

## Networking

- Service routes and path prefixes remain unchanged from state `004`.
- Local developer workflow may use Tilt-managed forwards/log streaming, without changing service contracts.

## Startup / Health Order

- Baseline deployment readiness model remains Kubernetes-native.
- Tilt automates build/deploy/reload sequencing for iterative local development.

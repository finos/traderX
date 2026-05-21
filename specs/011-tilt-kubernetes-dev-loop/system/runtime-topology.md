# Runtime Topology: 011-tilt-kubernetes-dev-loop

Parent state: `010-kubernetes-runtime`

State `011` reuses runtime topology from state `010` and adds Tilt as local orchestration/dev loop.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080` (inherited).
- Developer control entrypoint is Tilt (`tilt up`) for local iteration.

## Components

- Core TraderX services remain the same as state `010`.
- Added dev tooling layer:
  - Tiltfile and related local Kubernetes orchestration metadata.

## Networking

- Service routes and path prefixes remain unchanged from state `010`.
- Local developer workflow can use Tilt-managed forwards/log streaming without changing service contracts.

## Startup / Health Order

- Baseline deployment readiness model remains Kubernetes-native.
- Tilt automates build/deploy/reload sequencing for iterative local development.

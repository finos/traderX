# Feature Pack 002: Edge Proxy Uncontainerized

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/supported/green?icon=windows)

Status: Implemented (pending release tag)

This pack defines the first post-baseline state transition from `001-baseline-uncontainerized-parity`.

Primary intent:

- introduce an edge proxy/routing boundary for browser-origin traffic,
- reduce direct browser calls to multiple backend service ports,
- keep runtime uncontainerized for this state,
- preserve functional parity unless explicitly changed.

Implemented artifacts:

- `system/edge-routing.json`
- `system/architecture.model.json` + generated `system/architecture.md`
- `system/runtime-topology.md`
- `components/edge-proxy.md`
- `pipeline/generate-state.sh` (state `002` entrypoint)
- `pipeline/generate-state-002-edge-proxy-uncontainerized.sh`
- `specs/002-edge-proxy-uncontainerized/generation/patches/*.patch`
- `scripts/start-state-002-edge-proxy-generated.sh`
- `scripts/start-state-002-edge-proxy-generated.ps1`
- `scripts/test-state-002-edge-proxy.sh`
- `scripts/test-state-002-edge-proxy.ps1`
- `tests/smoke/README.md`

Runtime lifecycle:

- first run/build: `./scripts/start-state-002-edge-proxy-generated.sh --build-only`
- start after build: `./scripts/start-state-002-edge-proxy-generated.sh`
- first run/build (PowerShell): `./scripts/start-state-002-edge-proxy-generated.ps1 -BuildOnly`
- start after build (PowerShell): `./scripts/start-state-002-edge-proxy-generated.ps1`

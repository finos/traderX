# Implementation Plan: 003 Containerized Compose Runtime

## Scope

- Define container runtime model for all baseline components.
- Define compose topology, dependencies, and health/readiness gates.
- Define NGINX ingress routing model for browser/API/WebSocket entry.
- Define generated deployment bundle contract for live demo environments from generated-state branches.
- Keep functional parity with prior state unless explicitly changed.

## Technical Approach

1. Add runtime NFR and topology artifacts for containerized execution.
2. Define service container specs and compose wiring from component manifests.
3. Define NGINX ingress template and container packaging from spec artifacts.
4. Add generation outputs for compose files and container runtime scripts.
5. Add deployment bundle generation under `runtime/deploy/` for demo-ready containerized snapshots (tracked by issue `#351`).
6. Regenerate impacted runtime assets from spec inputs.
7. Run validation suite in containerized mode and capture evidence.

## Validation

- State-specific container runtime smoke tests.
- Conformance packs for affected components.
- Deployment bundle dry-run checks (no secrets committed, explicit env var contract, dry-run support).
- Docs build and traceability checks.

## Publishing hardening (#466)

Implement scanner deadlines and result classification in a shared Python runner called by the prepublish gate. Generate build/test CI and per-image digest evidence; verify current-attempt push runs against the requested generated SHA before demo deployment. Consume immutable images with no local builds, retain deployment evidence, and preserve snapshot ancestry. Validate offline timeout/cancellation/resource isolation, check matching, image evidence matching and successful deployment recording, plus generated CI regression tests.

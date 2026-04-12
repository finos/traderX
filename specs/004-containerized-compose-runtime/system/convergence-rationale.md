# Convergence Rationale (C0)

State `004-containerized-compose-runtime` is the C0 convergence baseline.

Rationale:

- It is the first containerized, reproducible runtime that all later tracks can inherit from.
- It preserves the baseline functional behavior while introducing a stable deployment substrate.
- It provides the cleanest handoff point for architecture, functional, and platform deltas.
- As the convergence baseline, it establishes the `C0+` CI policy: convergence states publish container images via build/publish workflow plus GHCR run-bundle artifacts.

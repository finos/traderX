# Convergence Rationale (C0)

State `004-containerized-compose-runtime` is the C0 convergence baseline.

Rationale:

- It is the first containerized, reproducible runtime that all later tracks can inherit from.
- It preserves the baseline functional behavior while introducing a stable deployment substrate.
- It provides the cleanest handoff point for architecture, functional, and platform deltas.
- As the convergence baseline, it establishes the `C0+` CI policy: convergence states publish container images via build/publish workflow plus GHCR run-bundle artifacts.
- It keeps generated patchsets aligned with current dependency security targets so descendant convergence states inherit a clean runtime baseline.

- Issue #465 upgrades the inherited Java baseline to public Spring Boot 4.0.8, Spring Framework 7.0.9, Data JPA 4.0.7, and Tomcat 11.0.26. Jackson 3 and Springdoc 3 compatibility changes preserve the existing HTTP and messaging contracts without adding security suppressions.

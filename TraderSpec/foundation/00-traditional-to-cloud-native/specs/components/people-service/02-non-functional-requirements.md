# People-Service Non-Functional Requirements

## Runtime

- NFR-PS-001: Default listen port shall be `18089` in baseline local mode.
- NFR-PS-002: Service startup time should be under 20 seconds on a warm local environment.
- NFR-PS-003: Service shall fail fast with clear logs when .NET runtime requirements are missing.

## Platform Compatibility

- NFR-PS-004: Generated implementation shall target `net9.0` and require both `Microsoft.NETCore.App 9.x` and `Microsoft.AspNetCore.App 9.x`.
- NFR-PS-005: Startup configuration shall support explicit runtime port override via `PEOPLE_SERVICE_PORT`.

## API Reliability

- NFR-PS-006: Person identity lookup (`GetPerson`) should complete within 150 ms p95 in local baseline mode.
- NFR-PS-007: Match lookup (`GetMatchingPeople`) should complete within 200 ms p95 in local baseline mode.
- NFR-PS-008: Error responses for invalid requests and not-found paths shall be stable and non-2xx.

## Compatibility

- NFR-PS-009: API behavior must remain compatible with account-service and Angular UI user lookup flows.
- NFR-PS-010: In pre-ingress local runtime, CORS must allow cross-origin browser calls from other localhost ports.
- NFR-PS-011: Endpoint paths and query parameter names must remain backward compatible (`/People/*`, `LogonId`, `EmployeeId`, `SearchText`, `Take`).

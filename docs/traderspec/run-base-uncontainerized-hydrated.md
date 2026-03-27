---
title: Run Base Uncontainerized State (Hydrated)
---

# Run Base Uncontainerized State (Hydrated)

This runs the official base state as local processes (no containers), from TraderSpec-generated locations.
Legacy root component sources are retired for the 9 base-case components.

## Prerequisites

- Java/Gradle wrapper support (for Java services)
- Node.js + npm (for reference-data, trade-feed, Angular UI)
- .NET runtime compatible with your CPU architecture (for people-service)
- `nc` (netcat) for readiness checks

## Dry Run (show startup commands/order)

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run
```

## Start

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh
```

## Start With Generated Reference-Data Overlay

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated
```

## Start With Generated Database + Reference-Data Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated
```

## Start With Generated Database + Reference-Data + People-Service Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated
```

## Start With Generated Database + Reference-Data + People-Service + Account-Service Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated
```

## Start With Generated Database + Reference-Data + People-Service + Account-Service + Position-Service Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated
```

## Start With Generated Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated
```

## Start With Generated Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed + Trade-Processor Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated
```

## Start With Generated Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed + Trade-Processor + Trade-Service Overlays

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated
```

## Start With Full Generated Base Case (Including Angular UI Overlay)

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

Equivalent explicit pure-generated mode:

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --pure-generated-base --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Status

```bash
./TraderSpec/codebase/scripts/status-base-uncontainerized-hydrated.sh
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```

## Source Specs

- `TraderSpec/foundation/00-traditional-to-cloud-native/specs/10-base-uncontainerized-state.md`
- `TraderSpec/catalog/base-uncontainerized-processes.csv`

## Cross-Origin Note

The base pre-ingress state requires CORS-enabled APIs for cross-port browser access.
For generated `reference-data`, use `CORS_ALLOWED_ORIGINS` (default `*`).

## Common Blockers

- If startup fails with `bad CPU type in executable: dotnet`, install a native dotnet runtime for your architecture (or enable x64 compatibility tooling) and retry.
- If `people-service` fails at launch with missing `Microsoft.AspNetCore.App 9.0.0`, install **ASP.NET Core Runtime 9 (arm64)**.
- If startup fails with a Gradle network preflight error, ensure outbound HTTPS access to:
  - `https://services.gradle.org/distributions/`
  - `https://repo.maven.apache.org/maven2/`
- If dependencies are already cached and you want to bypass network preflight checks:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh
```

- Verify runtimes with:

```bash
dotnet --list-runtimes
```

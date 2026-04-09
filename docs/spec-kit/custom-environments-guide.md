---
title: Custom Environments Guide
---

# Custom Environments Guide

This guide defines implementation norms for custom TraderX overlays that run in controlled or non-default operating environments.

## Package Management Norms

Define package management norms before implementing overlay-specific state changes. The first validation target is the initial known-good upstream baseline generated state. If baseline build does not pass under your norms, do not proceed to custom states yet.

### Upfront decisions

Choose and document one consistent approach per package manager:

- internal artifact proxy/repository manager
- local pre-populated package cache
- setup script that writes registry and credential files
- a combination of the above

There is no single required approach, but one approach must be selected, documented, and enforced consistently.

### Java (Gradle)

- Decide whether to use each component's `gradlew` wrapper or an externally provided Gradle runtime.
- If wrappers are used, ensure `gradle/wrapper/gradle-wrapper.properties` distribution URL is reachable in your environment.
- If your environment injects repository config through `settings.gradle`, explicitly set `dependencyResolutionManagement` to `PREFER_SETTINGS` when needed so project-level repository declarations do not silently override settings-level policy.
- Decide whether a setup script must write credentials or init files (for example `.gradle/gradle.properties`, `.gradle/init.gradle`, `.m2/settings.xml`) and document this requirement prominently.

### Node.js (npm/yarn)

- Define the registry endpoint.
- Define authentication mechanism and when tokens are injected.
- Ensure `.npmrc` (or equivalent) is written before install commands run.
- Decide whether this is done by setup script, CI injection, or component transform.

### .NET (NuGet)

- Define the feed endpoint (v3 feed URL).
- If suppressing public feeds, include `<clear/>` in `NuGet.Config` under `<packageSources>` before declaring internal sources.
- Decide whether config is setup-script generated or transform-injected.

### Credential isolation

Credential files should be written under an isolated home directory for generated runtime sessions, not the user's primary home directory.

Recommended pattern:

- set `HOME` to a run-local tool cache path before package commands execute
- create credential files in that isolated path
- avoid cross-run credential bleed

### Future scope: container and binary package management

When custom states add containerized components, extend package norms to container image sourcing and binary package installers used inside image builds.

### Required pre-overlay checklist

- [ ] Chosen package management approach documented (proxy, cache, setup script, or other)
- [ ] Gradle wrapper URL verified reachable or re-pointed to reachable mirror
- [ ] Gradle repository resolution mode confirmed (`PREFER_SETTINGS` where required)
- [ ] npm registry and auth mechanism defined and tested
- [ ] NuGet feed and `<clear/>` requirement confirmed
- [ ] Credential isolation approach defined (isolated `HOME` or equivalent)
- [ ] Baseline upstream state confirmed to build cleanly under these norms

## Runtime Version Management

Do not assume runtime tools are pre-installed in the expected versions. Define runtime provisioning before writing transforms, start scripts, or smoke tests.

### Questions to answer first

- How do developers get the required Java version on `PATH`?
- How do developers get the required Node.js version on `PATH`?
- How do developers get the required .NET SDK version on `PATH`?
- How are auxiliary tools (`python`, `jq`, etc.) provided?
- Is provisioning done through login profile, sourced script, module loader, container runtime, or manual install?

### Env-loader contract

Create one shared loader file (for example `overlay/runtime/env-loader.sh`) and source it from every start, stop, smoke-test, and pipeline script.

The loader must:

- be idempotent
- export runtime tool paths to child processes
- pin specific versions rather than floating defaults
- print active runtime versions for troubleshooting

If a required non-default tool is missing, fail early with a clear error. Avoid hidden failures from missing utilities.

### Future scope: container runtime management

If custom states add containerization, define container runtime and orchestration requirements with the same upfront discipline (runtime, version, and activation mechanism).

## Pub/Sub Replacement

When replacing Socket.IO + trade-feed with another messaging approach, define behavior at architecture/spec level before wiring application code.

### Connection Lifecycle

Determine whether the client connection model is synchronous or asynchronous.

If asynchronous:

- register connection/disconnection listeners before connect
- subscribe or publish only in connected callback
- reset subscription state on disconnect so reconnect can re-subscribe

If client behavior is unclear, build a minimal publisher/subscriber test first.

Reference pattern:

```text
client.onConnected(() -> {
    client.subscribe(topic, messageHandler);
});

client.onDisconnected(() -> {
    subscriptionActive = false;
});

client.connect();
```

### Message Delivery Semantics

Determine subscription behavior before implementing loops:

- does subscribe block for messages, or return after subscription acknowledgement?
- are messages push callback, poll/pull, or blocking read?
- what acknowledgement mode is required?
- who owns reconnect and re-subscription behavior, client or application?

For callback-driven clients, subscribe once and process via handler callback. Do not subscribe in a loop.

### Payload Format Strategy

Define payload formats per path:

- backend-to-backend format
- backend-to-browser format
- any translation boundary if formats differ

JSON remains the lowest-friction browser format, but backend messaging format may differ if documented and consistently implemented.

### Internal Library Dependency Completeness

Libraries from internal repositories may omit transitive runtime dependencies. If runtime class/module errors appear from library internals, inspect client-library documentation/examples and add explicit dependencies to your build.

### Browser Connectivity Strategy

Choose one strategy before implementation:

- native WebSocket endpoint exposed by chosen messaging system
- dedicated WebSocket gateway translating browser traffic to broker protocol

If a gateway is required, model it as a first-class component with explicit port, start command, and health checks.

Frontend service APIs should remain stable to callers where possible (for example, preserve `subscribe`/`unsubscribe` service contracts while changing internals).

### Port Allocation

Replacement messaging systems may require multiple ports.

For each custom state, explicitly catalog:

- broker listener ports
- browser/WebSocket listener ports
- management/admin ports

Update smoke tests for each required endpoint.

## Smoke Test Health Hint Guidance

Health endpoints vary by component and implementation. Do not assume `/health` or `/actuator/health` is universally available.

Use `catalog/component-spec.csv` `health_hint` as canonical guidance:

- HTTP services can be checked via documented data or API docs endpoints.
- TCP-only services should use TCP reachability checks (`nc -z` or equivalent), not HTTP probes.

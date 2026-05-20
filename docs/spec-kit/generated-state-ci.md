---
title: Generated State CI Policy
---

# Generated State CI Policy

This document defines the CI contract for generated TraderX code branches.

## Scope

- Security and license CI is required for all generated states from `002+`.
- States `001-003` are pre-container states and should not carry Docker/Compose artifacts in published generated snapshots.
- Container image build validation CI starts at state `004+` for states that include buildable container images.
- Container image build/publish CI is required only for convergence states from `C0+`.

## Required CI For States `002+`

Each generated `code/generated-state-*` branch must include CI workflows for dependency security and license scanning:

- `.github/workflows/security.yml`
- `.github/workflows/license-scanning-node.yml` (required when the state contains Node.js components)

These workflows must cover every applicable component in the generated state:

- Java/Gradle components in Gradle scan jobs
- .NET components in .NET scan jobs
- Node.js components in Node scan and license jobs
- containerized components in container vulnerability scan jobs

Coverage must be derived from generated component manifests/catalog data, not a manually maintained static list.

## Node License Requirement

All generated Node.js projects must declare:

```json
"license": "Apache-2.0"
```

Policy:

- Any new Node.js project introduced by a state transition must include this license field in its generated `package.json`.
- License scanning workflows should fail when a generated Node.js project omits this declaration.

## Node Lockfile Generation Policy

Node lockfiles are source-controlled generated artifacts and part of state lineage.

Policy:

- Generated Node projects must include a `package-lock.json`.
- Lockfiles must be refreshed only when the corresponding `package.json` changes, or when lockfiles are missing/invalid.
- State patchsets should include lockfile deltas when state changes affect Node manifests.
- Generated-branch publish is blocked if Node manifests and lockfiles are inconsistent.

## Hermetic Default Test Policy

Default build/test CI must not depend on external runtime services.

Policy:

- Generated branch default build/test jobs must run hermetically on CI runners without requiring external databases, brokers, or network endpoints.
- Database-backed tests in default suites must use in-memory/embedded engines (or equivalent isolated local test engines).
- External runtime validation (for example real PostgreSQL or broker integration) must run in explicitly named integration profiles/jobs separate from default build/test gates.
- State deltas introducing new database-backed modules must include test profile/config updates that preserve this policy.

## CVE Suppression Contract

Generated branches must carry the CVE suppression files used by security scanning:

- `.github/gradle-cve-ignore-list.xml`
- `.github/node-cve-ignore-list.xml`
- `.github/dotnet-cve-ignore-list.xml`

Policy:

- Keep a baseline suppression set shared across generated states.
- Allow state-specific suppression deltas when dependency sets diverge.
- When a state changes dependencies, update scanner coverage and suppression files in the same change.

## Dependency Source-Of-Truth Contract

Version policy changes must be landed in generator sources, not as ad-hoc generated-output edits.

- Baseline runtime/dependency versions belong in `templates/**`.
- State-specific version deltas belong in `specs/<state>/generation/patches/*.patch`.
- Post-generation mutation scripts are not allowed in steady-state; generation must be reproducible directly from templates and state patchsets.

## Messaging Subject Map Contract

Messaging states must keep a canonical subject registry in-state.

Policy:

- States `006+` must include `system/messaging-subject-map.md`.
- The file must be cumulative for that state (all active subject families).
- Subject-map format requirements are defined in `docs/spec-kit/messaging-subject-map-standard.md`.
- Generated-state contract validation must fail when order-matcher states omit required order subjects.

## External Dependency Pin Contract (Sail / State 014)

State `014-fdc3-intent-interoperability` depends on a local Sail sidecar and must use explicit pin governance.

Policy:

- Sail pin metadata is state-owned in `specs/014-fdc3-intent-interoperability/generation/sail-pin.env`.
- Pin metadata must include repo URL, tracking ref, pinned commit SHA, and updated-on date.
- Generated state `014` artifacts must consume that pin (`sail/bootstrap/sail-pin.env` + bootstrap defaults).
- Root quality gates must validate pin-manifest contract (`bash pipeline/validate-sail-pin-contract.sh`).
- Maintenance workflows must run drift detection (`bash pipeline/check-sail-pin-drift.sh --fail-on-drift`) before repinning.

## Jump-Point Overlay Parity Contract

When a state first materializes full runtime files that no longer point directly at `templates/**` (for example, root-level module `build.gradle` files in a convergence jump-point), that state must preserve inherited base-template policy unless an explicit state requirement overrides it.

Policy:

- Generic dependency/security/runtime controls remain owned by base templates.
- Jump-point state patchsets must not silently drop inherited template controls (dependency pins, exclusion blocks, plugin/runtime version guards).
- If a base template policy changes, maintainers must re-evaluate the nearest jump-point state patchset and propagate required parity updates.
- Any intentional divergence must be explicitly documented in the state FR/NFR deltas.

## Gradle Wrapper Ownership Policy

Gradle wrapper assets are baseline template artifacts, not state patch artifacts.

Policy:

- Canonical wrapper files live in `templates/gradle-wrapper/`:
  - `gradlew`
  - `gradlew.bat`
  - `gradle/wrapper/gradle-wrapper.jar`
  - `gradle/wrapper/gradle-wrapper.properties`
- Generated Gradle modules must receive wrapper assets from this canonical baseline during generation.
- State patchsets must not carry wrapper binary/script/properties diffs; wrapper version updates are made once in templates and inherited by all states.

## Patch Hygiene Ownership Policy

State patchsets must contain authored state deltas only, not local build byproducts.

Policy:

- Do not include compiled/restored output directories in state patch payloads:
  - `.gradle/**`
  - `build/**`
  - `target/**`
  - `bin/**`
  - `obj/**`
  - `dist/**`
  - `coverage/**`
  - `node_modules/**`
- Keep dependency lockfiles consistent with their manifests; include lockfile deltas in patchsets when manifests change.
- Build/restored artifacts must be produced by generation/runtime/build commands, never maintained by state patch files.

Preflight gates:

```bash
bash pipeline/validate-template-version-consistency.sh
bash pipeline/validate-generated-dependency-targets.sh generated/code/components generated/code/target-generated

# verifies dependency key versions are consistent across generated state branches
bash pipeline/validate-generated-branch-dependency-consistency.sh
```

## Convergence CI For `C0+`

Each convergence state from `C0+` must include:

- `.github/workflows/build-and-publish.yml`

The workflow must build and publish all containerized components present in that convergence state to GHCR.

## Non-Convergence Container CI

For non-convergence states that include containerized components, generated branches must include:

- `.github/workflows/build-container-images.yml`

Policy:

- Build all detected container images for validation.
- Do **not** publish images to GHCR.
- Do not generate GHCR runtime bundles for non-convergence states.
- This policy applies from state `004+` onward; pre-container states (`001-003`) must not emit container build workflows.

## GHCR Namespace Policy For Convergence States

Use convergence-level namespaces (not numeric state ids):

- `C0`: `ghcr.io/finos/traderx-c0/<component>`
- `C1`: `ghcr.io/finos/traderx-c1/<component>`
- `C2`: `ghcr.io/finos/traderx-c2/<component>`
- `C3`: `ghcr.io/finos/traderx-c3/<component>`

Each image publish must include:

- immutable tag: commit SHA
- moving tag: `latest`

## State Run Bundle Requirement For `C0+`

Each convergence state from `C0+` must publish a generated run bundle for consuming GHCR images without local source builds.

Minimum bundle artifacts:

- runtime manifest(s) that reference published GHCR images
- `.env.example` or equivalent runtime config template
- state run README with copyable startup commands

## Deployment Bundle Contract For Containerized Demo States

Generated snapshots may include deployment bundles only for containerized states that explicitly opt in via state catalog metadata.

Policy:

- Pre-container states (`001-003`) MUST NOT emit deployment bundles.
- Deployment bundle assets, when enabled, live under `runtime/deploy/<profile>/`.
- Initial profile contract is `aws-ec2-compose` for compose-based demo rollout.
- Deployment scripts MUST support `--dry-run` and use env vars for environment-specific values (for example target branch, domain/FQDN, image tag).
- Deployment scripts MUST NOT contain embedded credentials/tokens/secrets.
- Deployment bundle generation must come from canonical templates/generator logic, not manual edits on generated-state branches.

Recommended minimum deployment bundle assets:

- `runtime/deploy/<profile>/README.md`
- `runtime/deploy/<profile>/deploy.sh`
- `runtime/deploy/<profile>/upgrade.sh`
- `runtime/deploy/<profile>/cleanup.sh`
- `runtime/deploy/<profile>/nginx.reverse-proxy.snippet.conf`

Reverse-proxy snippet contract:

- Must include websocket upgrade headers (`Upgrade`, `Connection`, HTTP/1.1) for websocket routes.
- Must include websocket path mappings required by runtime messaging transport for the emitted state (for example `/nats-ws` for NATS-enabled state lineage), and avoid transport-specific stale routes that are no longer active for that state.

## Local CI Preflight Before Publish

Generated branch publish runs a prepublish CI-parity gate by default via
`pipeline/publish-generated-state-branch.sh`.

Run the same gate manually when validating outside publish flow:

```bash
bash pipeline/prepublish-generated-state-gate.sh <state-id>
```

The gate enforces:

- generated-state contract validation
- compile preflight for Node/Gradle/.NET modules
- dependency target/version propagation checks
- UI status metadata + lineage invariants
- Node license scanning
- container image buildability checks
- dependency CVE scanning with suppression rules

Emergency override remains explicit and operator-invoked:

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --skip-prepublish-gate
```

## Publish Gate

Generated branch publish is blocked unless:

- required CI workflows are present for the target state,
- scanner/build matrices include all applicable components,
- required suppression files are present and valid,
- prepublish CI-parity gate checks pass.

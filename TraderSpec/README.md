# TraderSpec

TraderSpec is the spec-driven redesign workspace for TraderX.

It defines how to rebuild a full codebase from explicit specifications while staying tightly aligned to how TraderX works today.

## Project Mission

Bring TraderX into the agentic AI era by making specifications, contracts, and state overlays the primary artifact, so full runnable implementations are generated from spec history instead of maintained manually as hand-authored source trees.

## Design Rules

1. Start from `00-traditional-to-cloud-native` (pre-Docker baseline).
2. Keep a single baseline functional requirements spec for core trading behavior.
3. Add non-functional overlays per learning-path step.
4. Add new functional requirements only on the Functional track.
5. Generate implementation artifacts from specs, then verify against contracts.

## Structure

- `foundation/00-traditional-to-cloud-native/` - baseline functional model and current-system capture
- `tracks/` - DevEx, Non-Functional, and Functional step specs
- `prompts/` - agent prompt pack for generation, validation, and migration
- `catalog/` - machine-readable graph of nodes and transitions
- `templates/` - GitHub spec-kit style templates
- `graphs/` - Mermaid source files
- `pipeline/` - scripts to verify and orchestrate spec-to-code flow
- `codebase/` - target area for generated implementation

## End Goal

`codebase/target-generated/` becomes the full implementation produced from these specs, validated against requirements and contracts.

## Baseline vs Parity

- **Baseline** = the requirement model and technical specification set.
- **Parity snapshot** = copied reference implementation used only for comparison.

Use parity to validate behavior, not as generation input.

## Migration Program

Track the full multi-phase migration plan in:

- `TraderSpec/migration-todo.md`
- `TraderSpec/migration-blog.md`

## Spec-First Generation Commands

```bash
# Validate spec completeness for regeneration
./TraderSpec/pipeline/validate-regeneration-readiness.sh

# Generate spec-first component scaffold (no source copy)
./TraderSpec/pipeline/generate-from-spec.sh
```

## Mixed-Mode Cutover Command

```bash
# Run hydrated stack but overlay generated reference-data component
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated
```

## Regenerate Generated-Only Reference-Data

```bash
bash ./TraderSpec/pipeline/generate-reference-data-specfirst.sh
```

## Regenerate Generated-Only Database

```bash
bash ./TraderSpec/pipeline/generate-database-specfirst.sh
```

## Regenerate Generated-Only People-Service

```bash
bash ./TraderSpec/pipeline/generate-people-service-specfirst.sh
```

## Regenerate Generated-Only Account-Service

```bash
bash ./TraderSpec/pipeline/generate-account-service-specfirst.sh
```

## Regenerate Generated-Only Position-Service

```bash
bash ./TraderSpec/pipeline/generate-position-service-specfirst.sh
```

## Regenerate Generated-Only Trade-Feed

```bash
bash ./TraderSpec/pipeline/generate-trade-feed-specfirst.sh
```

## Regenerate Generated-Only Trade-Processor

```bash
bash ./TraderSpec/pipeline/generate-trade-processor-specfirst.sh
```

## Regenerate Generated-Only Trade-Service

```bash
bash ./TraderSpec/pipeline/generate-trade-service-specfirst.sh
```

## Regenerate Generated-Only Web Frontend Angular

```bash
bash ./TraderSpec/pipeline/generate-web-front-end-angular-specfirst.sh
```

## Reference-Data Smoke Test

```bash
./TraderSpec/codebase/scripts/test-reference-data-overlay.sh
```

## Database + Reference-Data Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated
```

## Database + Reference-Data + People-Service Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated
```

## People-Service Smoke Test

```bash
./TraderSpec/codebase/scripts/test-people-service-overlay.sh
```

## Database + Reference-Data + People-Service + Account-Service Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated
```

## Account-Service Smoke Test

```bash
./TraderSpec/codebase/scripts/test-account-service-overlay.sh
```

## Database + Reference-Data + People-Service + Account-Service + Position-Service Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated
```

## Position-Service Smoke Test

```bash
./TraderSpec/codebase/scripts/test-position-service-overlay.sh
```

## Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated
```

## Trade-Feed Smoke Test

```bash
./TraderSpec/codebase/scripts/test-trade-feed-overlay.sh
```

## Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed + Trade-Processor Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated
```

## Trade-Processor Smoke Test

```bash
./TraderSpec/codebase/scripts/test-trade-processor-overlay.sh
```

## Database + Reference-Data + People-Service + Account-Service + Position-Service + Trade-Feed + Trade-Processor + Trade-Service Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated
```

## Trade-Service Smoke Test

```bash
./TraderSpec/codebase/scripts/test-trade-service-overlay.sh
```

## Full Generated Base-Case Mixed Mode (Includes Angular UI)

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Web Frontend Angular Smoke Test

```bash
./TraderSpec/codebase/scripts/test-web-angular-overlay.sh
```

## Gradle Network Preflight

Startup now verifies Gradle network endpoints before launching Java services:

- `https://services.gradle.org/distributions/`
- `https://repo.maven.apache.org/maven2/`

If dependencies are fully cached, bypass with:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh
```

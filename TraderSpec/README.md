# TraderSpec

TraderSpec is the requirements-first redesign workspace for TraderX.

It defines how to rebuild and evolve the codebase from explicit specifications while staying tightly aligned to TraderX behavior.

## Project Mission

Move TraderX from legacy spec scaffolding to a GitHub Spec Kit operating model where:

- requirements, user stories, and acceptance criteria are the primary source of truth
- contracts and traceability are enforced before generation
- generated code is validated against parity and smoke checks
- legacy source-first assumptions are phased out

## Design Rules

1. Start from `00-traditional-to-cloud-native` (pre-Docker baseline).
2. Keep a single baseline functional requirements spec for core trading behavior.
3. Add non-functional overlays per learning-path step.
4. Add new functional requirements only on the Functional track.
5. Generate implementation artifacts from Spec Kit requirements, then verify against contracts and parity checks.

## Current Approach (Spec Kit First)

- Canonical root Spec Kit source is now `/.specify` + `/specs/**`.
- `TraderSpec/speckit/**` is transitional migration-era material and will be retired as root feature packs fully replace it.
- `TraderSpec Specs` docs route is focused on Spec Kit artifacts.
- Component generators are gated by Spec Kit readiness and traceability checks.
- Baseline component generation now uses manifest-driven synthesis (compiled manifest + component templates).
- End-to-end parity validation is required to prove generated output matches expected baseline behavior.
- Pipeline default root feature pack: `specs/001-baseline-uncontainerized-parity` (override with `SPECKIT_FEATURE_ID=<id>` when needed).

## Structure

- `foundation/00-traditional-to-cloud-native/` - baseline functional model and current-system capture
- `speckit/` - transitional Spec Kit-era artifacts pending root feature-pack consolidation
- `tracks/` - DevEx, Non-Functional, and Functional step specs
- `prompts/` - agent prompt pack for generation, validation, and migration
- `catalog/` - machine-readable graph of nodes and transitions
- `templates/` - reusable code and prompt templates
- `graphs/` - Mermaid source files
- `pipeline/` - scripts to verify and orchestrate spec-to-code flow
- `codebase/` - target area for generated implementation

## End Goal

`codebase/target-generated/` becomes the full implementation produced from Spec Kit requirements and validated by expressiveness, contract, and runtime parity checks.

## Baseline vs Parity

- **Baseline** = the Spec Kit requirement model and technical constraints for the current state.
- **Parity** = behavioral equivalence checks between generated output and expected runtime flows/contracts.

Use parity as a validation gate, not as generation input.

## Migration Program

Track the full multi-phase migration plan in:

- `TraderSpec/migration-todo.md`
- `TraderSpec/migration-blog.md`

## Spec-First Generation Commands

```bash
# Validate spec completeness for regeneration
./TraderSpec/pipeline/validate-regeneration-readiness.sh

# Validate Spec Kit requirements/user-story traceability
./TraderSpec/pipeline/speckit/validate-speckit-readiness.sh

# Validate Spec Kit expressiveness and requirement mapping coverage
./TraderSpec/pipeline/speckit/verify-spec-expressiveness.sh

# Compile normalized generation manifests from Spec Kit artifacts
bash TraderSpec/pipeline/speckit/compile-all-component-manifests.sh

# Generate spec-first component scaffold (no source copy)
./TraderSpec/pipeline/generate-from-spec.sh
```

## Full Parity Gate

```bash
bash TraderSpec/pipeline/speckit/run-full-parity-validation.sh
```

## Conformance Packs (Phase 7.9)

```bash
# Regenerate all per-component conformance pack docs
bash TraderSpec/pipeline/speckit/sync-conformance-packs.sh

# Validate all conformance packs (stories, FR/NFR mappings, contracts, verification refs)
bash TraderSpec/pipeline/speckit/run-all-conformance-packs.sh
```

## Semantic Generation Compare Harness (Phase 7.10)

```bash
# Compare one component output against a legacy ref
bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service HEAD --allow-differences

# Compare all generated components and print semantic diff categories
bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
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

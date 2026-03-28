---
title: GitHub Spec Kit Workflow
---

# GitHub Spec Kit Workflow

TraderX baseline generation now follows a root-canonical GitHub Spec Kit flow.

## Canonical Locations

- `.specify/**` for constitution and templates
- `specs/001-baseline-uncontainerized-parity/**` for baseline requirements, stories, plan, tasks, and contracts
- `TraderSpec/pipeline/**` for generation and validation orchestration

Browse in docs:

- `/traderspec-specs/specs/baseline-uncontainerized-parity/README`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/system-requirements`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/user-stories`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/acceptance-criteria`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/requirements-traceability`
- `/traderspec-specs/api`
- `/traderspec-specs/specify`

## Input Evidence For Requirements

- `docs/overview.md`
- `docs/flows.md`
- `docs/README.md`
- `README.md`

## Baseline Generation Flow

1. Validate Spec Kit readiness and requirement coverage.
2. Compile component manifests from Spec Kit artifacts.
3. Synthesize generated components from manifest + templates.
4. Start generated overlays and run smoke tests/parity checks.

## Validation Commands

```bash
./TraderSpec/pipeline/speckit/validate-speckit-readiness.sh
./TraderSpec/pipeline/speckit/verify-spec-expressiveness.sh
bash TraderSpec/pipeline/speckit/compile-all-component-manifests.sh
./TraderSpec/pipeline/validate-regeneration-readiness.sh
./TraderSpec/pipeline/verify-spec-coverage.sh
```

## Generation Commands

Regenerate baseline components:

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-people-service-specfirst.sh
bash TraderSpec/pipeline/generate-account-service-specfirst.sh
bash TraderSpec/pipeline/generate-position-service-specfirst.sh
bash TraderSpec/pipeline/generate-trade-feed-specfirst.sh
bash TraderSpec/pipeline/generate-trade-processor-specfirst.sh
bash TraderSpec/pipeline/generate-trade-service-specfirst.sh
bash TraderSpec/pipeline/generate-web-front-end-angular-specfirst.sh
```

Run generated overlays in base-state order:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh \
  --overlay-reference-generated \
  --overlay-database-generated \
  --overlay-people-generated \
  --overlay-account-generated \
  --overlay-position-generated \
  --overlay-trade-feed-generated \
  --overlay-trade-processor-generated \
  --overlay-trade-service-generated \
  --overlay-web-angular-generated
```

## Full Parity Gate

Run end-to-end parity validation (generation + startup + all baseline smoke tests):

```bash
bash TraderSpec/pipeline/speckit/run-full-parity-validation.sh
```

## API Explorer

Generate interactive OpenAPI docs from canonical contracts:

```bash
npm --prefix website run gen:api-docs
```

## Compare Generation Output

To compare a single component generated output between a legacy script revision and current Spec Kit-driven generation:

```bash
bash TraderSpec/pipeline/speckit/compare-component-generation.sh <component-id> <legacy-ref>
```

Example:

```bash
bash TraderSpec/pipeline/speckit/compare-component-generation.sh reference-data HEAD
```

## Iterating Learning-Path States

After baseline parity is green:

1. add FR/NFR deltas in the next feature pack under `specs/NNN-*`
2. update contracts if interfaces change
3. regenerate affected components
4. rerun conformance + parity gates

This keeps each learning-path state reproducible from requirements instead of from copied source.

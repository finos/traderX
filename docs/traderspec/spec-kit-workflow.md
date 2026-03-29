---
title: GitHub Spec Kit Workflow
---

# GitHub Spec Kit Workflow

TraderX baseline generation now follows a root-canonical GitHub Spec Kit flow.

## Canonical Locations

- `.specify/**` for constitution and templates
- `specs/001-baseline-uncontainerized-parity/**` for baseline requirements, stories, plan, tasks, and contracts
- `pipeline/**` for generation and validation orchestration

Browse in docs:

- `/specs/baseline-uncontainerized-parity/README`
- `/specs/baseline-uncontainerized-parity/system/system-requirements`
- `/specs/baseline-uncontainerized-parity/system/user-stories`
- `/specs/baseline-uncontainerized-parity/system/acceptance-criteria`
- `/specs/baseline-uncontainerized-parity/system/requirements-traceability`
- `/api`
- `/specify`

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
./pipeline/speckit/validate-speckit-readiness.sh
./pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/speckit/compile-all-component-manifests.sh
./pipeline/validate-regeneration-readiness.sh
./pipeline/verify-spec-coverage.sh
```

## Generation Commands

Regenerate baseline components:

```bash
bash pipeline/generate-reference-data-specfirst.sh
bash pipeline/generate-database-specfirst.sh
bash pipeline/generate-people-service-specfirst.sh
bash pipeline/generate-account-service-specfirst.sh
bash pipeline/generate-position-service-specfirst.sh
bash pipeline/generate-trade-feed-specfirst.sh
bash pipeline/generate-trade-processor-specfirst.sh
bash pipeline/generate-trade-service-specfirst.sh
bash pipeline/generate-web-front-end-angular-specfirst.sh
```

Run generated baseline stack:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Full Parity Gate

Run end-to-end parity validation (generation + startup + all baseline smoke tests):

```bash
bash pipeline/speckit/run-full-parity-validation.sh
```

## API Explorer

`npm --prefix website run start` and `npm --prefix website run build` now generate OpenAPI docs on demand.

To regenerate explicitly:

```bash
npm --prefix website run gen:api-docs
```

## Compare Generation Output

To compare a single component generated output between a legacy script revision and current Spec Kit-driven generation:

```bash
bash pipeline/speckit/compare-component-generation.sh <component-id> <legacy-ref>
```

Example:

```bash
bash pipeline/speckit/compare-component-generation.sh reference-data HEAD
```

## Iterating Learning-Path States

After baseline parity is green:

1. add FR/NFR deltas in the next feature pack under `specs/NNN-*`
2. update contracts if interfaces change
3. regenerate affected components
4. rerun conformance + parity gates

This keeps each learning-path state reproducible from requirements instead of from copied source.

# TraderSpec

`TraderSpec/` is now a legacy transition folder slated for removal after Phase C cleanup.

Operational orchestration is root-canonical:

- `pipeline/**`
- `scripts/**`
- `templates/**`
- `catalog/**`
- `foundation/**`
- `tracks/**`

## Canonical Sources

- SpecKit scaffold: `/.specify/**`
- Baseline feature pack: `/specs/001-baseline-uncontainerized-parity/**`
- Runtime orchestration: `/pipeline/**` and `/scripts/**`

## Core Runtime Commands

```bash
./scripts/start-base-uncontainerized-generated.sh
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

## Generate Baseline Components

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

Start full generated baseline:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Smoke Tests

```bash
./scripts/test-reference-data-overlay.sh
./scripts/test-database-overlay.sh
./scripts/test-people-service-overlay.sh
./scripts/test-account-service-overlay.sh
./scripts/test-position-service-overlay.sh
./scripts/test-trade-feed-overlay.sh
./scripts/test-trade-processor-overlay.sh
./scripts/test-trade-service-overlay.sh
./scripts/test-web-angular-overlay.sh
```

## SpecKit Gates

```bash
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/verify-spec-coverage.sh
bash pipeline/speckit/run-all-conformance-packs.sh
bash pipeline/speckit/run-full-parity-validation.sh
```

## Generated Artifact Policy

These paths are ephemeral and intentionally not source-controlled:

- `generated/code/components/`
- `generated/manifests/`
- `generated/code/target-generated/`
- `generated/api-docs/`

Recreate them by running generation commands; do not commit them.

## Documentation Entry Points

- `/docs/traderspec/spec-kit-portal`
- `/docs/traderspec/spec-kit-workflow`
- `/docs/traderspec/spec-kit-generation-guide`
- `/docs/traderspec/run-generated-overlays`
- `/docs/learning-paths`
- `/foundation`
- `/specs`
- `/specify`
- `/migration/migration-todo`
- `/migration/migration-blog`

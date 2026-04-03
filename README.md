[![FINOS Hosted Platform - TraderX demo](https://img.shields.io/badge/FINOS%20Hosted%20Platform-TraderX%20Demo-blue)](https://demo.traderx.finos.org/)
[![FINOS - Incubating](https://cdn.jsdelivr.net/gh/finos/contrib-toolbox@master/images/badge-incubating.svg)](https://finosfoundation.atlassian.net/wiki/display/FINOS/Incubating)

# FINOS | TraderX (SpecKit-First Baseline)

TraderX is now organized as a root-canonical GitHub SpecKit project.  
The baseline implementation is generated and validated from requirements, stories, acceptance criteria, contracts, and conformance gates.

## Canonical Project Layout

- `.specify/` - SpecKit constitution and templates
- `specs/001-baseline-uncontainerized-parity/` - baseline feature pack
- `pipeline/` + `scripts/` - generation, runtime, conformance, and parity orchestration
- `templates/` + `catalog/` - synthesis inputs and component/process catalogs
- `generated/` - generated runtime/code/docs artifacts workspace (ephemeral outputs)
- `docs/` + `website/` - documentation portal and API explorer
- `docs/learning/**` - developer-focused per-state learning guides for generated code snapshots

## Quickstart (Generated Baseline Runtime)

Generate baseline components:

```bash
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
```

Start/stop/status:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh

./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

Run smoke tests:

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

## Validation Gates

```bash
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/verify-spec-coverage.sh
bash pipeline/speckit/run-all-conformance-packs.sh
bash pipeline/speckit/run-full-parity-validation.sh
```

## Documentation

- SpecKit overview: `docs/spec-kit/index.md`
- Learning guides: `docs/learning/index.md`
- Learning paths: `docs/learning-paths/index.md`
- SpecKit portal: `docs/spec-kit/spec-kit-portal.md`
- Workflow: `docs/spec-kit/spec-kit-workflow.md`
- Runbook: `docs/spec-kit/spec-kit-generation-guide.md`
- Legacy migration-era docs were retired from active tree; recover via git history if needed.

## Learning Doc Enrichment Plugin

This repo uses the GitHub SpecKit ecosystem with optional community extension support for richer learning material workflows.

- Community extension used for learning-focused authoring experiments: `learn`
- Install command:

```bash
specify extension add learn --from https://github.com/imviancagrace/spec-kit-learn/archive/refs/tags/v1.1.0.zip
```

- Canonical committed learning docs stay under `docs/learning/**` and state feature packs under `specs/**`.

Live routes (Docusaurus):

- `/docs/spec-kit`
- `/docs/learning-paths`
- `/specs`
- `/specify`
- `/api`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright 2023 UBS, FINOS, Morgan Stanley.

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

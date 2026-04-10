---
title: GitHub Spec Kit Workflow
---

# GitHub Spec Kit Workflow

TraderX baseline generation now follows a root-canonical GitHub Spec Kit flow.

## Canonical Locations

- `.specify/**` for constitution and templates
- `specs/001-baseline-uncontainerized-parity/**` for baseline requirements, stories, plan, tasks, and contracts
- `pipeline/**` for generation and validation orchestration

Each state pack under `specs/NNN-*` must include:

- `research.md`
- `data-model.md`
- `quickstart.md`

Convergence states must also include:

- `system/convergence-rationale.md`

Browse in docs:

- `/specs/baseline-uncontainerized-parity`
- `/specs/baseline-uncontainerized-parity/system/system-requirements`
- `/specs/baseline-uncontainerized-parity/system/user-stories`
- `/specs/baseline-uncontainerized-parity/system/acceptance-criteria`
- `/specs/baseline-uncontainerized-parity/system/requirements-traceability`
- `/specs/baseline-uncontainerized-parity/system/end-to-end-flows`
- `/specs/baseline-uncontainerized-parity/system/architecture`
- `/docs/spec-kit/state-docs`
- `/docs/learning`
- `/api`
- `/specify`

## Input Evidence For Requirements

- `specs/001-baseline-uncontainerized-parity/system/architecture.model.json`
- `specs/001-baseline-uncontainerized-parity/system/end-to-end-flows.md`
- `specs/001-baseline-uncontainerized-parity/system/system-requirements.md`
- `docs/README.md`
- `README.md`

## Baseline Generation Flow

1. Validate Spec Kit readiness and requirement coverage.
2. Compile component manifests from Spec Kit artifacts.
3. Synthesize generated components from manifest + templates.
4. Start generated overlays and run smoke tests/parity checks.

## Derived-State Generation Flow

For states `002+`, generation follows:

1. Generate parent state output.
2. Apply ordered patch set from `specs/<state>/generation/patches/*.patch`.
3. Regenerate architecture docs and run state smoke checks.

## Convergence-State Policy

- Prefer new state proposals from the nearest suitable convergence state (`C0/C1/C2/C3`).
- Keep `previous` single-parent for publish lineage.
- Use `dottedParents` only for convergence states.
- If convergence-state metadata/content changes, update that state's `system/convergence-rationale.md`.
- Reference: [`/docs/spec-kit/convergence-states`](/docs/spec-kit/convergence-states)

## LLM Feature-Add Implementation Contract

When implementing a new state delta with an LLM:

1. Generate the parent state (`bash pipeline/generate-state.sh <parent-state-id>`).
2. Make only the intended child-state edits against generated output.
3. Capture patch set (`bash pipeline/create-state-patchset.sh <state-id> <parent-state-id> [target-path]`).
4. Keep state hook as parent-generation + `apply-state-patchset.sh` only.
5. Update `specs/<state>/generation/generation-hook.md` with parent, patch path, and refresh commands.
6. Do not introduce or keep large file-payload heredoc generators for derived states.

## Validation Commands

```bash
bash pipeline/refresh-state-docs.sh --check
bash pipeline/validate-state-pack-artifacts.sh
./pipeline/speckit/validate-speckit-readiness.sh
./pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/speckit/compile-all-component-manifests.sh
./pipeline/validate-regeneration-readiness.sh
./pipeline/verify-spec-coverage.sh
```

## Docusaurus CI Compatibility

When changing Docusaurus, docs plugins, or website build configuration:

1. Keep `website/package-lock.json` committed and updated with the dependency change.
2. Use `npm --prefix website ci --no-audit --no-fund` (not `npm install`) for CI parity.
3. Validate docs build with GitHub Pages settings:

```bash
DOCUSAURUS_URL=https://finos.github.io \
DOCUSAURUS_BASE_URL=/traderX/ \
TRADERX_SITE_ROOT=/traderX \
bash pipeline/refresh-state-docs.sh

DOCUSAURUS_URL=https://finos.github.io \
DOCUSAURUS_BASE_URL=/traderX/ \
npm --prefix website run clear

DOCUSAURUS_URL=https://finos.github.io \
DOCUSAURUS_BASE_URL=/traderX/ \
npm --prefix website run build
```

`TRADERX_SITE_ROOT` is used when regenerating `/docs/learning-paths` Mermaid click links so GitHub Pages artifacts resolve under `/traderX/...` instead of root-relative `/...`.

4. If dependency changes alter transitive Webpack behavior, pin and re-lock before merge.

5. Run AFDocs checks for agent-friendliness:

```bash
# local preview (while docusaurus start runs)
npx afdocs check http://localhost:3000 --format scorecard
npx afdocs check http://localhost:3000 --format json --score

# published docs URL
npx afdocs check https://finos.github.io/traderX/ --format scorecard
```

Use AFDocs scorecards to prioritize high-impact fixes. Prefer improvements via docs build/pipeline/plugins (for example llms outputs) before broad manual content rewrites.

Learning-path catalog policy:

- `catalog/state-catalog.json` is the source for state lineage.
- Derived artifacts are regenerated together by:
  - `bash pipeline/refresh-state-docs.sh`
- Derived artifacts include:
  - `catalog/learning-paths.yaml`
  - `catalog/learning-paths.md`
  - `/docs/learning-paths`
  - `/docs/spec-kit/state-docs`
  - `/docs/learning/index`
  - `/docs/learning/state-*.md`

## Generation Commands

Generate any state:

```bash
bash pipeline/generate-state.sh <state-id>
```

These commands also regenerate state architecture docs from `specs/*/system/architecture.model.json`.
State docs (`/docs/spec-kit/state-docs`) are generated from `catalog/state-catalog.json`.

Scaffold a new planned state pack:

```bash
bash pipeline/scaffold-state-pack.sh <NNN-state-name> --title "<Title>" --previous <prior-state-id> --track <prelude|baseline|architecture|nonfunctional|functional|devex>
```

Run the state-change playbook (refresh docs -> gates -> generate -> optional publish/push):

```bash
bash pipeline/state-playbook.sh --state <state-id> --publish-neighborhood --push-generated
```

Generated outputs:

- `generated/code/components/*-specfirst`
- `generated/manifests/*.manifest.json`
- `generated/code/target-generated/**` (assembled at startup)

Run generated baseline stack:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

Run generated containerized stack (state `003`):

```bash
./scripts/start-state-003-containerized-generated.sh
./scripts/status-state-003-containerized-generated.sh
./scripts/test-state-003-containerized.sh
./scripts/stop-state-003-containerized-generated.sh
```

Ingress endpoint: `http://localhost:8080`

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
3. update and capture state patch set:

```bash
bash pipeline/create-state-patchset.sh <state-id> <parent-state-id> [target-path]
```

4. rerun conformance + parity gates

This keeps each learning-path state reproducible from requirements instead of from copied source.

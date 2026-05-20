---
title: Generated State Branches
---

# Generated State Branches

TraderX keeps the canonical source of truth in `specs/**` + `.specify/**`, and publishes code-only snapshots in dedicated `code/generated-state-*` branches.

## Canonical State Definitions

Each state is defined in two places:

1. SpecKit feature pack: `specs/NNN-<state-name>/`
2. State catalog entry: `catalog/state-catalog.json`

The state catalog is the publish contract for generated snapshots:

- state id/title/status
- predecessor states (`previous`)
- convergence metadata (`isConvergence`, `convergenceLevel`, `dottedParents`, `primaryLineageRole`)
- generation readiness (`generation.mode`)
- default generated-state branch name
- release tag hint
- optional deployment-bundle metadata (`deploy.enabled`, `deploy.profile`, environment labels/domain hints)

## State Independence + Lineage

Each state must be buildable from its own feature pack without requiring branch-local edits.

Publish lineage is explicit through `previous` in `catalog/state-catalog.json`.
Dotted-line parents are documentation lineage only and are not used for branch ancestry.

Generated branches include metadata files so consumers can always see provenance:

- `STATE.md`
- `.traderx-state/state.json`
- `LEARNING.md`
- `FUNCTIONAL_TESTING.md`
- `docs/learning/*` generated learning artifacts (component list, system design, architecture, diagram)
- optional `runtime/deploy/*` deployment bundle artifacts for containerized states that explicitly opt in

Deployment runbooks:

- host prerequisites: `/docs/spec-kit/aws-ec2-compose-prerequisites`
- 004 cutover checklist: `/docs/spec-kit/demo-004-cutover-checklist`
- 009 cutover checklist: `/docs/spec-kit/demo-009-cutover-checklist`

These files record:

- current state id/title
- prior states and known next states
- source branch/commit used to generate snapshot
- generation timestamp
- state-oriented learning links back to canonical docs/specs
- plain-English functional behavior expectations plus smoke-test entrypoints for that snapshot

Canonical portal learning guides live at:

- `/docs/learning`

## Publish The Baseline Generated Branch

From a clean working tree:

```bash
bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
```

By default, publish now runs a prepublish CI-parity gate before commit/push
(`pipeline/prepublish-generated-state-gate.sh`) against generated outputs.
Use `--skip-prepublish-gate` only for explicit operator override cases.

When adding or updating a state, publish the lineage neighborhood so adjacent
branches get refreshed lineage/compare links:

```bash
bash pipeline/publish-generated-state-neighborhood.sh <state-id> --push
```

Default branch target for baseline:

- `code/generated-state-001-baseline-uncontainerized-parity`

State `002-edge-proxy-uncontainerized` now uses:

- generation: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- runtime (first run/build): `./scripts/start-state-002-edge-proxy-generated.sh --build-only`
- runtime (start after build): `./scripts/start-state-002-edge-proxy-generated.sh`
- publish branch: `code/generated-state-002-edge-proxy-uncontainerized`

Publish branch snapshot:

```bash
bash pipeline/publish-generated-state-branch.sh 002-edge-proxy-uncontainerized --push
```

State `004-containerized-compose-runtime` now uses:

- generation: `bash pipeline/generate-state.sh 004-containerized-compose-runtime`
- runtime (default build + start): `./scripts/start-state-004-containerized-generated.sh` (NGINX ingress on `http://localhost:8080`)
- runtime (restart without image rebuild): `./scripts/start-state-004-containerized-generated.sh --skip-build`
- publish branch: `code/generated-state-004-containerized-compose-runtime`

Publish branch snapshot:

```bash
bash pipeline/publish-generated-state-branch.sh 004-containerized-compose-runtime --push
```

Current published generated branches:

- `code/generated-state-001-baseline-uncontainerized-parity`
- `code/generated-state-002-edge-proxy-uncontainerized`
- `code/generated-state-004-containerized-compose-runtime`

## Branch Invariant -- One Commit Per State

Every `code/generated-state-<id>` branch, in both upstream and any custom overlay, must contain exactly one content commit on top of its base branch.

How this works:

1. The publish script always starts from the base branch (the previous state's branch, or the root anchor), not from the existing generated branch tip.
2. The publish script creates or resets the generated branch to the base tip using `git checkout -B`.
3. The full generated snapshot is applied as a single commit.
4. The publish script force-pushes that branch (`git push --force`) to replace the prior snapshot commit.

Why this matters:

- `git diff code/generated-state-A code/generated-state-B` stays a clean state-to-state diff.
- Lineage is expressed through branch ancestry (the base branch), not through cumulative commit depth.
- History remains readable and reproducible for both humans and automation.

Custom overlay pipelines must enforce the same invariant. Using `--force-with-lease` on a branch that accumulates commits does not satisfy this model.

## Behavior Invariant -- Inherit Unless Explicitly Replaced

Across upstream and custom overlays, each state must preserve parent behavior by default.

Required rule:

1. Downstream states inherit all prior behavior from `previous` lineage unless the state spec explicitly declares a conflict, replacement, or deprecation.
2. Runtime migrations (for example Compose to Kubernetes) must carry inherited capabilities forward unless an explicit requirement says otherwise.
3. Smoke tests for downstream states should include inherited capability checks so regressions are detected during publish.

## CI Invariant -- Required Generated Workflows

Generated-state branches must carry CI workflows that match the state's technology surface.

- States `002+` must include security and license scanning workflows.
- Coverage must include all applicable generated components (Java/.NET/Node/containerized).
- CVE suppression files used by the scans must be present and versioned with the generated state.

Convergence states `C0+` must also include container image build/publish workflows and a generated run bundle that references published images.

Canonical policy and local preflight guidance:

- `/docs/spec-kit/generated-state-ci`

## Template Invariant -- Source Of Truth Lives In Templates/Patchsets

Dependency/runtime version changes must be maintained in canonical generator sources, not as post-generation edits.

Required rule:

1. Baseline component defaults are maintained in `templates/**` (for example Java `build.gradle`, Gradle wrapper, and shared runtime/library versions).
2. Derived state deviations are maintained in state patchsets under `specs/<state>/generation/patches/*.patch`.
3. Post-generation mutation scripts are not allowed in steady-state generation; canonical templates and patchsets must fully define output content.
4. Version targets are declared in `catalog/dependency-version-targets.json` and must pass before publish:

```bash
bash pipeline/validate-template-version-consistency.sh
bash pipeline/validate-generated-dependency-targets.sh generated/code/components generated/code/target-generated
bash pipeline/validate-generated-branch-dependency-consistency.sh
```

## How To Add A New State

1. Scaffold the feature pack:

```bash
bash pipeline/scaffold-state-pack.sh <NNN-state-name> --title "<Title>" --previous <prior-state-id> --track <prelude|baseline|architecture|nonfunctional|functional|devex>
```

2. Add/update requirements, plan, tasks, contracts, and traceability for the new state.
3. Confirm state entry in `catalog/state-catalog.json` with:
   - `previous` lineage
   - publish branch/tag conventions
   - `generation.mode=planned` until implemented
4. Implement state generation pipeline and change `generation.mode` to `implemented`.
5. Publish generated branch + tag with validation evidence.

Recommended publish sequence after implementing a new state:

1. `bash pipeline/publish-generated-state-neighborhood.sh <state-id> --push`
2. `bash pipeline/publish-generated-state-tree.sh --push` (optional full refresh)

This keeps specification and generated code distribution clearly separated while preserving state-to-state continuity.

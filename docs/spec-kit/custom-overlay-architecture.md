---
title: Custom Overlay Architecture
---

# Custom Overlay Architecture

This document defines the upstream reference contract for implementing a custom TraderX overlay repository without modifying upstream TraderX state definitions or generated-state publishing behavior.

## Goals

- Keep upstream TraderX canonical and unchanged.
- Allow environment-specific extensions in a separate repository.
- Preserve reproducible generation and clean state lineage.
- Keep publish semantics aligned with upstream generated-state contracts.

## Canonical Overlay Repository Structure

```text
traderx-overlay/
  upstream/traderX/                # upstream as git submodule
  overlay/
    profiles/                      # policy YAMLs (state selection)
    states/custom-<id>/            # per-state: scripts/, catalog/, src/
    transforms/                    # named transform scripts
    runtime/                       # shared env loaders, setup helpers
  catalog/
    state-catalog.json             # overlay state catalog
  pipeline/
    generate-state.sh              # mirrors upstream pipeline/generate-state.sh
    publish-state-branch.sh        # mirrors upstream publish script
  specs/                           # overlay spec packs (one per custom state)
  docs/                            # overlay documentation
```

## Overlay State Catalog Contract

Overlay state catalogs should keep state ids explicit, preserve lineage, and declare generation/publish metadata as first-class fields.

Required fields per state entry:

- `id`
- `title`
- `previous`
- `generation.mode`
- `publish.branch`
- `featurePack`
- `overlayState`

Example:

```json
{
  "id": "custom-001-example",
  "title": "Custom State 001 - Example",
  "previous": ["004-containerized-compose-runtime"],
  "generation": {
    "mode": "implemented"
  },
  "publish": {
    "branch": "code/generated-state-custom-001-example"
  },
  "featurePack": "specs/custom-001-example",
  "overlayState": {
    "kind": "custom",
    "extends": "004-containerized-compose-runtime"
  }
}
```

Expected semantics:

- `previous` expresses branch ancestry and overlay lineage.
- `overlayState.extends` identifies the upstream or overlay state being extended.
- `publish.branch` follows the same generated-state branch naming convention used upstream.

## Pipeline Responsibilities

`pipeline/generate-state.sh` in an overlay should:

1. Load runtime/tooling environment.
2. Resolve the requested overlay state from overlay catalog metadata.
3. Generate upstream base output into an overlay-controlled output root.
4. Apply overlay transforms after layout copy.
5. Run optional validation/smoke checks.

`pipeline/publish-state-branch.sh` in an overlay should:

1. Resolve base branch from `previous`.
2. Reset target generated-state branch to base with `git checkout -B`.
3. Commit full generated snapshot once.
4. Force-push (`git push --force`) to preserve one-commit invariant.

## Transform Script Contract

Transform scripts must follow this contract:

- Naming: `apply-<feature>.sh <target-dir>`
- Input: first positional argument is target generated directory.
- Idempotence: safe to run repeatedly against the same target directory.
- Failure behavior: exit non-zero on any failure.
- Ordering: transforms must run after layout copy (never before).

### Critical Ordering Rule

The layout function (`prepare_generated_base_layout` or equivalent) performs a destructive copy of base components into the target tree. Any transform output applied before that copy will be overwritten.

Correct order:

```bash
# Step 1: copy base components into target layout (destructive)
prepare_generated_base_layout

# Step 2: re-apply overlay transforms after layout
bash "${OVERLAY_ROOT}/overlay/transforms/apply-<feature>.sh" "${TARGET}"
```

If transforms run before layout copy, the system can start successfully but run unmodified upstream code.

## `--dry-run` Contract For Start Scripts

Custom start scripts used by generation must support `--dry-run`.

Behavior requirements:

- Build target layout fully (copy/sync all required components and runtime files).
- Apply all transforms and generated overlays.
- Exit without starting service processes.
- Return non-zero if layout preparation fails.

Generation pipelines rely on this mode to produce clean publishable snapshots.

## Runtime Version Management

Before implementing transforms or start scripts, define and document how required tools become available in your environment.

Required questions:

- How is Java made available on `PATH`, at a pinned version?
- How is Node.js made available on `PATH`, at a pinned version?
- How is .NET SDK made available on `PATH`, at a pinned version?
- How are additional tools (for example Python, `jq`) made available?
- Is tool activation provided by login profile, sourced script, module loader, containers, or another mechanism?

Implement a single shared loader, typically `overlay/runtime/env-loader.sh`, and source it from every start/stop script, smoke test, and pipeline entrypoint.

The loader must:

- Be idempotent (safe to source multiple times).
- Export runtime tool paths for child processes.
- Pin explicit versions.
- Emit active version diagnostics for debugging.

If a required tool is not globally installed, the loader must provide it through the chosen environment mechanism and fail clearly if not available.

Future containerized states should apply the same pattern to container runtime and orchestration tool initialization.

## Working Directory Anchor Rule

Any start/generate script that deletes and recreates directories must anchor current working directory to a safe location before destructive operations.

```bash
# Anchor CWD to overlay root before destructive operations
cd "${OVERLAY_ROOT}"
prepare_generated_base_layout
```

If the shell is currently inside a directory being deleted, subsequent runtime commands can fail with misleading errors.

## `TRADERX_GENERATED_ROOT` Convention

Overlay pipelines should use `TRADERX_GENERATED_ROOT` to direct upstream generation output into the overlay repository.

Example:

```bash
TRADERX_GENERATED_ROOT="${OVERLAY_ROOT}/generated" \
  bash "${OVERLAY_ROOT}/upstream/traderX/pipeline/generate-state.sh" 004-containerized-compose-runtime
```

Default behavior remains unchanged when `TRADERX_GENERATED_ROOT` is unset (`upstream/traderX/generated`).

## LLM-Friendly Docs Output (Optional)

If your overlay publishes a docs portal, optionally add an llms output generator plugin to your Docusaurus build so `/llms.txt` and related LLM-friendly artifacts are generated automatically.

Implementation guidance:

1. Add a maintained Docusaurus llms plugin in website dependencies.
2. Configure plugin output paths and URL handling to match your site base path.
3. Regenerate docs and run AFDocs checks (`scorecard` and JSON score output).
4. Keep this as a build-time concern in docs pipeline/configuration rather than manual per-page edits.

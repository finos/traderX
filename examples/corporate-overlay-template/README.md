# TraderX Corporate Overlay Bootstrap Template

This directory is a bootstrap starter for enterprise teams extending TraderX privately.

## What This Is

- A reference template for creating a separate corporate overlay repository.
- A policy-and-transform pattern for private state/runtime constraints.
- A starter model for an internal docs portal that shows sanctioned learning states.

## What This Is Not

- Not a production-ready corporate implementation.
- Not a generated code distribution branch.
- Not a fork target for day-to-day corporate development.

Do not fork TraderX to carry corporate-only deltas.
Create a separate `traderx-corporate-overlay` repository and treat upstream TraderX as a pinned dependency.

## Quick Start

Create a new external repo and copy this template into it:

```bash
mkdir traderx-corporate-overlay
cd traderx-corporate-overlay
git init

# copy this template directory from your TraderX clone
rsync -a /path/to/traderX/examples/corporate-overlay-template/ ./
```

Add upstream TraderX as a pinned submodule:

```bash
git submodule add -b feature/agentic-renovation https://github.com/finos/traderX.git upstream/traderX
git submodule update --init --recursive
```

Generate the internal sanctioned-state graph:

```bash
./scripts/render-internal-learning-graph.sh
```

Run a demo generation + corporate transform pass:

```bash
./scripts/demo-generate-corp-overlay.sh 003-containerized-compose-runtime
```

The demo script calls upstream generation with `TRADERX_GENERATED_ROOT` so output is written directly into the overlay repository (`./generated`) instead of the upstream submodule path.

## Example Corporate Rules Included

- `RULE-IMG-001`: public container images are blocked; corporate registry mirror required.
- `RULE-DB-001`: containerized PostgreSQL is not allowed in sanctioned runtime; use managed endpoint + cert auth.
- `RULE-DOCS-001`: internal docs must show a red internal-distribution banner and corporate branding.

## Internal Docs Portal Model

The internal portal should publish:

- only sanctioned states and branches
- a corporate learning graph that builds on the public lineage model
- explicit visual warning that the portal is internal and policy-constrained

See:

- `corporate/docs/internal-learning-graph.md`
- `corporate/docs/internal-docs-portal.md`

## Suggested Repository Layout

```text
traderx-corporate-overlay/
  upstream/traderX/
  corporate/profiles/
  corporate/catalog/
  corporate/states/
  corporate/transforms/
  corporate/docs/
  generated/
  scripts/
```

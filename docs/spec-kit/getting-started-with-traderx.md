---
title: Getting Started with TraderX
---

# Getting Started with TraderX

TraderX has multiple generated codebases representing different learning states, from a simple pre-container baseline to a more feature-rich platform with pricing, order management, and platform tooling.

## Where To Find The Code

- Search generated branches directly: [code/generated-state-* branches](https://github.com/finos/traderX/branches/all?query=code%2Fgenerated-state-)
- See full state mapping and links: [State Docs](/docs/spec-kit/state-docs)
- See the progression and visual graph: [Learning Paths](/docs/learning-paths)
- For private overlay customization: [Customizing TraderX](/docs/spec-kit/customizing-traderx)
- Canonical overlay starter template: `examples/custom-overlay-template/`
- Optional policy/demo scenario pack: `examples/corporate-overlay-template/`

If you want to run demos quickly, use the generated state branches listed below.

## Generated Codebase States

- [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity)
- [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized)
- [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime)
- [code/generated-state-004-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-004-postgres-database-replacement)
- [code/generated-state-005-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-005-messaging-nats-replacement)
- [code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-006-observability-lgtm-compose)
- [code/generated-state-007-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-007-pricing-awareness-market-data)
- [code/generated-state-008-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-008-order-management-matcher)
- [code/generated-state-009-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-009-kubernetes-runtime)
- [code/generated-state-010-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-010-tilt-kubernetes-dev-loop)
- [code/generated-state-011-platform-convergence-c3](https://github.com/finos/traderX/tree/code/generated-state-011-platform-convergence-c3)
- [code/generated-state-012-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-012-radius-kubernetes-platform)

## Why This Works

These codebases are generated from specifications using GitHub Spec Kit.  
Specs, templates, and generation logic are the maintained source of truth; generated code branches are the runnable outputs.

## Contribution Workflow

If you want to contribute new states:

1. Clone the main TraderX repository on macOS or Linux.
2. Use your preferred agentic coding assistant (for example Amp, Claude Code, or Codex).
3. Choose the parent state from the [Learning Paths](/docs/learning-paths).
4. Define the new state in specs (requirements, plan, tasks, architecture, contracts, and generator changes).
5. Implement and validate in the spec/source branch.
6. Commit spec/docs/generator changes, then publish the generated state branch.

Example contribution themes:

- Service mesh adoption.
- Multi-temporal data support and related UI updates.
- Swapping messaging or database implementations.

## Corporate Internal Extension Point

If your organization needs private runtime constraints, internal-only states, or private generated branches:

1. Start with the canonical overlay starter under `examples/custom-overlay-template/`.
2. Create a separate corporate overlay repository (do not fork TraderX for corporate-only deltas).
3. Add TraderX as a pinned submodule dependency.
4. Optionally layer selected scenario assets from `examples/corporate-overlay-template/` (policy/demo examples).
5. Publish an internal docs portal that includes only your sanctioned internal learning graph branches.

---
title: Customizing TraderX
---

# Customizing TraderX

Use this page as the single entrypoint for building and operating a private overlay on top of upstream TraderX.

## Which Document Does What

1. [Corporate Environments Guide](/docs/spec-kit/corporate-environments-guide)
   - Strategy overview and decision model.
   - Explains when to use an external overlay repository and why upstream stays canonical.
2. [Custom Overlay Architecture](/docs/spec-kit/custom-overlay-architecture)
   - Repository layout, state catalog contract, transform ordering, `--dry-run`, working-directory anchor rules, and `TRADERX_GENERATED_ROOT`.
3. [Custom Environments Guide](/docs/spec-kit/custom-environments-guide)
   - Environment integration norms: package management, runtime/toolchain loading, pub/sub replacement, and health-check guidance.

## Recommended Implementation Order

1. Confirm the overlay model and governance decisions in the strategy guide.
2. Create a separate overlay repository and pin upstream TraderX as a submodule.
3. Define runtime/toolchain loading (`env-loader`) and package management norms up front.
4. Generate the first upstream baseline state into overlay output (`TRADERX_GENERATED_ROOT`).
5. Confirm baseline builds successfully under your environment constraints.
6. Implement idempotent overlay transforms and apply them after layout copy.
7. Add overlay-specific states and publish generated-state branches using the one-commit invariant.
8. Maintain alignment by regularly syncing upstream pin, regenerating, and validating.
9. Run AFDocs checks against local and published docs URLs to keep the portal agent-friendly.

## Templates

- Canonical starter template: `examples/custom-overlay-template/`

Recommended usage:

1. Start from `examples/custom-overlay-template/`.
2. Tailor the included profile, transform, and internal-docs examples for your environment policy.

## Compatibility Note

`/docs/spec-kit/corporate-environments-guide` remains a valid URL and should be treated as the high-level overview, while the two `custom-*` guides are the detailed implementation references.

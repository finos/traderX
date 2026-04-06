# SpecKit Learning Path Strategy

TraderX uses a convergence-first state model on top of GitHub Spec Kit artifacts in `specs/` and `.specify/`.

## Canonical Progression

- Prelude onboarding: `001 -> 002`
- `C0`: `003`
- Architecture to `C1`: `004 -> 005 -> 006`
- Functional to `C2`: `007 -> 008`
- Platform to `C3`: `009 -> 010 -> 011`
- Optional side branch: `012` off `009`

Convergence checkpoints:

- `C0`: `003-containerized-compose-runtime`
- `C1`: `006-observability-lgtm-compose`
- `C2`: `008-order-management-matcher`
- `C3`: `011-platform-convergence-c3`

## Lineage Rules

- `previous` is the single publish lineage parent (max length 1).
- `dottedParents` is documentation lineage only and allowed only on convergence states.
- `primaryLineageRole` is one of `prelude`, `canonical`, `optional`.

## Authoring Guidance

1. Start new work from the nearest suitable convergence state by default.
2. Create one feature pack per transition.
3. Add FR deltas only when behavior changes.
4. Add NFR deltas for runtime/platform/ops objectives.
5. Keep contract changes scoped and explicit.
6. If changing a convergence state, update `system/convergence-rationale.md`.

## Required Artifacts Per Transition

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/**` (requirements, flows, architecture, topology)
- `generation/generation-hook.md`
- `generation/patches/*.patch` for derived-state implementation deltas
- `tests/smoke/README.md`

## Validation and Promotion Loop

1. Update spec artifacts.
2. Regenerate state outputs.
3. Refresh catalog-derived docs.
4. Run gates and state smoke tests.
5. Publish generated code branch when green.

Commands:

```bash
bash pipeline/refresh-state-docs.sh
bash pipeline/verify-spec-coverage.sh
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```

## References

- State catalog: `catalog/state-catalog.json`
- Visual graph: `/docs/learning-paths`
- Convergence policy: `/docs/spec-kit/convergence-states`

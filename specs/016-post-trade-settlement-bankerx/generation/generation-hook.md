# Generation Hook: 016-post-trade-settlement-bankerx

- Feature pack: `specs/016-post-trade-settlement-bankerx`
- Parent state: `014-fdc3-intent-interoperability` (child state — 014 stays the pristine FDC3 baseline)
- Model: ADR-002 generated-state branching + `docs/spec-kit/state-transition-generation-plan.md` explicit inheritance policy

## Scope Resolution (maintainer review, PR #470)

The payment-intent handoff and the post-trade settlement lifecycle are separate
lessons. 014 keeps the FDC3 baseline untouched; 016 owns the settlement-specific
changes in its own overlay, so a generated 014 → 016 comparison shows exactly one
new lesson.

## Overlay Model

016's frontend overlay is applied ON TOP of the generated 014 output:

- `generation/frontend-overrides/web-front-end/angular/**` — full-file overrides
  copied over the generated angular tree (same mechanism as 014), carrying:
  - `fdc3-interop.service.ts` — 014 baseline + `StartPayment` dispatch,
    `findIntent` payment-receiver discovery, UETR dispatch tracking,
    `synaptic.settlementStatus` correlation listener.
  - `trade-blotter/trade-blotter.component.ts` — 014 baseline + the SETTLE
    action column, gated on `findIntent('StartPayment')` resolution so base
    TraderX shows no action button; settlement status flips rows
    (`SETTLING…` → `SETTLED` / `REJECTED`); duplicate dispatch suppressed.
- `generation/mock-receiver/**` — the local mock receiver (default receiver
  variant) + its app-directory fragment + the provider-neutral lifecycle module.
  The BankerX settlement terminal is the opt-in reference adapter (both
  variants ship with the pack).

## Future State-ification Steps (when 016 becomes a runnable state)

1. Generate parent state `014-fdc3-intent-interoperability`.
2. Copy `generation/frontend-overrides/**` over the generated angular tree.
3. Serve `generation/mock-receiver/` and merge its appd fragment into the Sail
   app-directory seed so `findIntent('StartPayment')` resolves in the demo profile.
4. Regenerate architecture docs from the pack's `system/**`.
5. Run state smoke tests (014 suite + `tests/smoke/`).
6. Publish `code/generated-state-016-post-trade-settlement-bankerx` and add the
   catalog entry (feature-pack precedent of 015 applies until then).
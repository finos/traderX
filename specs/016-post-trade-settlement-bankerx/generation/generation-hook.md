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
## Overlay Completeness (templates are upstream-pristine — 2026-10-12)

The shared `templates/web-front-end/angular` tree is the speckit generation
base. It carries NO 016 settlement code: everything above is provided by this
pack's overlay, and `package.json` / `tsconfig.json` are unchanged from the
upstream merge commit. The overlay now also carries:

- `model/account.model.ts` (`name?:` desk identifier) and
  `model/trade.model.ts` (`price?:` fill price) — type extensions the settle
  flow reads.
- `service/position.service.ts` — the settlement-registry client
  (`getSettlements` / `postSettlements` against
  `/position-service/trades/settlements/`, served by the adapter at port 8415
  in the demo estate).

Two template-tree files predate this rule and stay where they are, documented
as estate-build sources only (`angular-deploy/PATCH-NOTE.md`): the
`TradeTicket` company-name normalization block (the 2026-09-30 hand-patch
port) — the generated trees are governed by 014's `trade-ticket` override, so
none of it reaches a generated baseline.

### The 014 → 016 purity proof

`tests/smoke/generated-tree-purity.test.mjs` replays the generation
composition statically and asserts, in four gates: (Q0) no state pack other
than 016 ships settlement vocabulary; (Q1) the upstream `bbd6408` web base
composed with 014's frontend-overrides is settlement-free; (Q2) composing
TODAY's templates tree with 014's overrides is byte-identical under `main/app`
to the upstream composition (no 016 delta survives into generated 014);
(Q3) adding this pack's overlay puts the settlement surface back exactly where
the overlay says. Run it with `node
tests/smoke/generated-tree-purity.test.mjs` from the pack directory.

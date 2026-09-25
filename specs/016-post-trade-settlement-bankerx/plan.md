# Implementation Plan: 016-post-trade-settlement-bankerx

## Scope

- Transition from `014-fdc3-intent-interoperability` to `016-post-trade-settlement-bankerx`.
- Track focus: `functional`.
- Complete the post-trade leg of the trading lifecycle: bridge TraderX front-office execution to BankerX (post-trade clearing & settlement) through FINOS FDC3 3.0 intents.
- Frontend-led integration: TraderX UI raises `StartPayment` with `fdc3.paymentContext`; no backend service contract changes.

## Deliverables

1. Requirements and constraints finalized in:
   - `requirements/functional-delta.md`
   - `requirements/nonfunctional-delta.md`
   - `contracts/contract-delta.md`
2. Supporting design artifacts:
   - `research.md`
   - `data-model.md`
   - `system/architecture.md`
3. Frontend settlement adapter (Angular, generated state overlay):
   - `SETTLE (BANKERX)` action on confirmed Trade Blotter rows
   - `fdc3.paymentContext` builder (amount, currency, pair, rate, debtor, creditor, networkRouting, UUIDv4 `uetr`)
   - `fdc3.raiseIntent("StartPayment", paymentContext)` dispatch with FDC3 3.0 agent detection
   - graceful fallback to direct web dispatch (`https://terminal.synapticchain.xyz`) when no Desktop Agent is present
   - inbound `pacs.002` (`Acsc`) settlement-status handling that marks blotter rows `SETTLED`
4. BankerX side reference (external reference flow, commit `c80566f`):
   - BankerX DvP settlement adapter and ISO 20022 pacs.008/pacs.002 reference flow
   - Trilateral Settlement Powerhouse routing (Solana Token-2022 / XRPL Altnet / SynapticChain L1 SMR)
5. Automated verification:
   - unit tests for context building and intent dispatch
   - integration tests with a mocked DesktopAgent
   - degraded-mode tests proving baseline blotter behavior when FDC3 is unavailable

## Phased Execution

1. Phase A: Finalize the `fdc3.paymentContext` schema deltas (requirements + contracts) against FINOS PR #2204.
2. Phase B: Implement the settlement adapter primitives (context builder, agent detection, fallback dispatch).
3. Phase C: Wire the `SETTLE (BANKERX)` control into the Trade Blotter and row-selection state.
4. Phase D: Implement inbound settlement-status listeners (pacs.002 `Acsc`) and blotter row settlement marking.
5. Phase E: Add mocked integration tests, degraded-mode regressions, and diagnostic logging (FR-01604).
6. Phase F: Run quality gates (validate-frontmatter, Spec Kit gates, spec coverage) and update downstream docs.

## Exit Criteria

- Spec, plan, and tasks are complete and reviewed.
- Every confirmed blotter row can raise a standards-conformant `StartPayment` intent without re-keying data.
- FDC3-unavailable environments keep the full TraderX experience (fallback toast + direct dispatch link).
- Settlement confirmations (`pacs.002` / `Acsc`) flip blotter rows to `SETTLED` in mocked integration tests.
- Quality gates (Spec Kit readiness, expressiveness, spec coverage) pass on the feature branch.
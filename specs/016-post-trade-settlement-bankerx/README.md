# Feature Pack 016: FDC3 Post-Trade Settlement Interoperability

## Overview

This pack defines the **post-trade settlement lifecycle** as a child state of
`014-fdc3-intent-interoperability` (014 stays the pristine FDC3 baseline; 016
owns the settlement-specific changes in its own overlay, per ADR-002 and the
state-transition generation plan).

It bridges **TraderX** (Front-Office Execution) with a post-trade settlement
receiver using **FINOS FDC3 3.0** experimental intent/context (`StartPayment`,
`fdc3.payment` — the exact context type proposed in [FDC3 PR #2204](https://github.com/finos/FDC3/pull/2204))
and ISO 20022 `pacs.008` / `pacs.002` messaging.

**Provider-neutral by design:** three deployment & receiver variants ship with the pack:

- **Local mock receiver (default)** — `generation/mock-receiver/`, dependency-free
  and offline-reproducible; the demo and tests never require an external service.
- **BankerX reference adapter (opt-in)** — the live settlement terminal
  ([terminal.synapticchain.xyz](https://terminal.synapticchain.xyz), labeled
  XRPL TESTNET (altnet) / Solana DEVNET), swapped in via an app-directory URL change.
- **Standalone Web Blotter Reference** — `generation/traderx-blotter-web/`,
  live at [traderx.synapticchain.xyz](https://traderx.synapticchain.xyz) with
  FDC3 App Directory at `/appd.json` and direct on-chain Solana consensus verification.

## The new lesson (014 → 016)

- Mapping an execution to valid payment instructions, currencies, and counterparties.
- UETR-keyed correlation of trade ↔ payment request ↔ settlement status report.
- Preventing duplicate settlement requests.
- Handling rejection, timeout, and uncertain outcomes honestly.
- Settlement status taught as a concept distinct from trade status.

### The rock-solid operational lesson (v15 → v20, 2026-09-30/10-01)

One sentence: **settlement truth must outlive the page that witnessed it.**

Concretely, 016 now teaches the full invariant set, each one learned from a
real defect and fixed in source (see `generation/traderx-blotter-web/angular-deploy/PATCH-NOTE.md` v15–v20):

1. **Durable, UETR-keyed registry beat localStorage.** A per-browser ledger
   (`v17`) means settled rows reset the moment a second browser opens. Truth
   moved to the adapter's file-backed registry (v20), with one-way ISO 20022
   ordering (`Pndg → Acsc/Rjct`) enforced server-side.
2. **Adoption must be fingerprint-guarded.** A registry entry may only stamp
   a row under (a) an own-UETR match or (b) a full trade-fingerprint match
   (security, quantity, side, created). Without the `created` guard, a
   re-seeded trade after an adapter restart inherits a stale settlement —
   demonstrated live, then proven non-adopting.
3. **Chain-truth belongs at the reconciliation seam.** The on-chain
   settlement memo (UETR inside the transfer memo) cures rows whose only
   witness page missed the live status broadcast — the desk settles only
   after its WOTS+ attestation passes, so a chain memo IS the settlement.
4. **Intent availability gates the UI by construction.** The SETTLE action
   renders only when `findIntent('StartPayment')` resolves — no config flag.
5. **One desk, many settlements.** Desk-reuse (v19): SETTLE reuses/focuses
   the open desk window instead of spawning duplicates.
6. **Compliance failure shares the pipeline.** Rejection surfaces as
   `RejectedByEnclave:SANCTIONS_POLICY_VIOLATION` on the same code path —
   no separate demo path.
7. **Build-source alignment is a gate, not an assumption.** The angular
   bundle builds from the `templates/` copy — the 016 overlay must be
   `cp`'d over it before every build; literal-marker greps between old and
   new bundles catch a silently stale build (v20 lesson).
8. **Counts and bytes are logged honestly per run** — mocha-retry FINAL
   STATS overcount (DOM is the truth); served md5 == disk md5 checked
   per URL-bust (Cloudflare caches JS per full URL).

## Intent-availability gating

The `SETTLE (BANKERX)` blotter action column is rendered only when
`fdc3.findIntent('StartPayment')` resolves to at least one workspace
participant. Base TraderX (no post-trade participant) shows the pristine 014
blotter; the button appears the moment the mock receiver or BankerX joins the
workspace — capability discovery by construction, no configuration flag.

## Key Links

- **FDC3 Standard PR**: [FINOS FDC3 PR #2204 (Payment Context & StartPayment Intent)](https://github.com/finos/FDC3/pull/2204)
- **FDC3 Standard Issue**: [FINOS FDC3 Issue #444](https://github.com/finos/FDC3/issues/444)
- **Reference settlement engine (BankerX)**: [terminal.synapticchain.xyz](https://terminal.synapticchain.xyz)
- **Generation overlay + lifecycle tests**: `generation/` and `tests/smoke/`

![](https://badgen.net/badge/linux%2Fmac/ready/green) ![](https://badgen.net/badge/windows/tested/blue)
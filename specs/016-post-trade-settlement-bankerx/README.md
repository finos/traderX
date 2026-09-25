# Feature Pack 016: FDC3 Post-Trade Settlement Interoperability

## Overview

This pack defines the **post-trade settlement lifecycle** as a child state of
`014-fdc3-intent-interoperability` (014 stays the pristine FDC3 baseline; 016
owns the settlement-specific changes in its own overlay, per ADR-002 and the
state-transition generation plan).

It bridges **TraderX** (Front-Office Execution) with a post-trade settlement
receiver using **FINOS FDC3 3.0** experimental intent/context (`StartPayment`,
`fdc3.paymentContext`, [FDC3 PR #2204](https://github.com/finos/FDC3/pull/2204))
and ISO 20022 `pacs.008` / `pacs.002` messaging.

**Provider-neutral by design:** two receiver variants ship with the pack:

- **Local mock receiver (default)** — `generation/mock-receiver/`, dependency-free
  and offline-reproducible; the demo and tests never require an external service.
- **BankerX reference adapter (opt-in)** — the live settlement terminal
  ([terminal.synapticchain.xyz](https://terminal.synapticchain.xyz), labeled
  XRPL TESTNET (altnet) / Solana DEVNET), swapped in via an app-directory URL change.

## The new lesson (014 → 016)

- Mapping an execution to valid payment instructions, currencies, and counterparties.
- UETR-keyed correlation of trade ↔ payment request ↔ settlement status report.
- Preventing duplicate settlement requests.
- Handling rejection, timeout, and uncertain outcomes honestly.
- Settlement status taught as a concept distinct from trade status.

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
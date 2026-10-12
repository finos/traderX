# Feature Specification: FDC3 Post-Trade Cash-Leg Payment Transfer (TraderX ↔ BankerX)

**Feature Branch**: `016-post-trade-settlement-bankerx`  
**Created**: 2026-09-24  
**Status**: Specification Complete & Reference Implemented  
**State Model**: Child state of `014-fdc3-intent-interoperability` (014 stays the pristine FDC3 baseline; 016 owns the settlement-specific changes in its own overlay per ADR-002)  
**Receiver Variants**: Local mock receiver (default, offline-reproducible) + BankerX reference adapter (opt-in)  
**Standards Alignment**: FINOS FDC3 3.0 (PR #2204, Issue #444), ISO 20022 CBPR+ (pacs.008, pacs.002), RFC 4122 (UUIDv4 UETR)  
**Input**: Transition delta from `014-fdc3-intent-interoperability`  

---

## 0. Terminology — what this state actually demonstrates

Per the maintainer review (finos/traderX #470, Sept 29): the example
demonstrates a **currency payment transfer — the cash leg of an already
executed trade**. TraderX sends the settled currency amount owed on the trade
to the counterparty over the settlement rail. It does **not** demonstrate
securities delivery-versus-payment (no security leg is delivered in this
state — the DvP security leg is out of scope) and it does **not** demonstrate
payment-versus-payment (no simultaneous second-currency leg is exchanged).
The UETR keys the payment back to the original trade; the blotter row's
status reflects only that the trade's cash obligation settled.

---

## 0b. Evidence classification — what an `Acsc` actually proves here

Per the acceptance review (PR #470): a settlement claim must be matched to
the evidence behind it. Statuses reach the blotter over three channels with
three different evidence strengths, and the state classifies them honestly
instead of presenting all three as on-chain proof:

| Channel | Evidence behind the `Acsc` | How the UI classifies it |
|---|---|---|
| Solana devnet ledger (Estate rail legs) | **On-chain proof.** The desk's settlement memo (carrying the row's UETR) exists on an actual devnet transaction to the creditor token account; the blotter's memo watcher (`checkOnChainSettlement`) reads the ledger itself, records the `txSignature`, and the desk's own WOTS+ re-derivation verdict rides along (`alcoveVerified`). | Receipt modal shows the TX SIGNATURE and `VERIFICATION: pacs.008 memo verified from the Solana ledger`; log lines say ON-CHAIN SETTLED. |
| Settlement registry adapter (`synaptic-traderx-adapter`, demo port 8415) | **Counterparty/peer broadcast persisted by a demo adapter.** Entries are published and reconciled across browsers (fingerprint + UETR adoption guards prevent wrong-row stamps), but the adapter is file-backed and unauthenticated — it is demo-estate infrastructure, not a source of cryptographic proof. | Row-level state only; treated the same as a broadcast (no tx evidence shown). |
| Mock receiver / reference adapter broadcast (`synaptic.settlementStatus`) | **The receiver's own word.** In the offline acceptance flow the mock receiver settles on a *demo rail* and returns no tx hash; validation of asset/amount/counterparties happened at dispatch (`validatePaymentContext`: ISO 4217 currency, canonical pair+rate, complete debtor/creditor, UUIDv4 UETR) and the receiver page echoes those fields for operator review — but there is no cryptographic attestation behind the acceptance. | Receipt modal VERIFICATION row reads `counterparty Acsc — no tx evidence (mock/demo boundary)`; the blotter log states the broadcast carried no tx evidence; the mock receiver badge marks the settlement `simulated settlement — no tx evidence (demo rail)`. |

**Trust boundary, stated plainly:** in this state only the Solana-memo/ledger
path verifies transaction success; the adapter and mock-receiver paths carry
unauthenticated counterparty claims, which is acceptable for a demo estate
because the same channels cannot be used to forge money movement — only to
mislabel a row. Production settlement would close this boundary with a signed
pacs.002 from the settling desk (or the ADR-555 enclave attestation the
Estate rail already runs) and amount/counterparty correlation inside the
signed envelope; that hardening is out of scope for the reference
implementation and is deliberately documented rather than faked.

---

## 1. Executive Summary

While **TraderX** provides institutional-grade pricing awareness, order matching, and trade execution blotters, enterprise capital markets currently suffer from a **T+2 settlement latency gap**. Trades executed in milliseconds must wait 48 hours to clear across legacy correspondent banking networks due to disconnected post-trade clearing systems.

This specification completes the financial trading lifecycle by bridging **TraderX** (Front-Office Execution) with **BankerX** (Post-Trade Clearing & Settlement):
* When an FX trade execution occurs in the TraderX blotter, the trader can raise the standardized FINOS FDC3 3.0 intent:
  `fdc3.raiseIntent("StartPayment", paymentContext)`
* The intent routes into **BankerX** (`synaptic-fx-terminal`), carrying the standardized `fdc3.payment` context (per FINOS PR #2204).
* BankerX executes pre-flight compliance via the **ADR-555 Alcove Runtime Guardian** (sub-8ms), screen sanctions via in-memory Bloom filters (zero wire leakage), verifies solvency (Δ ≡ 0), and triggers atomic settlement across the **Trilateral Settlement Powerhouse** (Solana Token-2022 `RequiredMemoTransfers` + XRPL Altnet DENSE-16 SHAMap + SynapticChain L1 SMR) within **400 milliseconds**.
* Canonical ISO 20022 `pacs.008` (Credit Transfer Initiation) and `pacs.002` (Payment Status Report / Receipt with `Acsc` confirmation) XML receipts are generated and bound to the RFC 4122 UUIDv4 SWIFT UETR.

---

## 2. User Stories

* **As a spot FX trader**, I want to click "Settle Trade" directly from my TraderX execution blotter so that settlement instructions are immediately dispatched to the clearing desk without re-keying amounts, accounts, or currencies.
* **As a clearing operations officer**, I want BankerX to receive FDC3 payment intents from TraderX, validate them against ISO 20022 CBPR+ schema rules, and screen counterparty identities locally in `sub-8ms` without leaking order book data over external network wires.
* **As an enterprise compliance auditor**, I want every trade settlement to emit immutable ISO 20022 `pacs.002.001.10` settlement confirmation receipts that cryptographically bind the SWIFT UETR to on-chain transaction hashes.
* **As a system maintainer**, I want the TraderX desktop experience to remain fully operational and graceful if no FDC3 Desktop Agent or post-trade settlement receiver is active.
* **As a learner moving from 014 to 016**, I want a reproducible request-to-outcome demonstration (offline, via the local mock receiver) so I can understand the settlement lifecycle — correlation, duplicate prevention, rejection/timeout handling, and settlement status as a concept distinct from trade status — without any external service or testnet dependency.

---

## 3. Functional Requirements

* **FR-01601**: TraderX Trade Blotter SHALL provide an action button labelled `SETTLE (BANKERX)` on trade rows **only when `fdc3.findIntent("StartPayment")` resolves to at least one workspace participant**. Base TraderX with no post-trade participant (no mock receiver, no BankerX) SHALL render the pristine 014 blotter with no action column; the button appears dynamically when a participant declaring `StartPayment` support joins the workspace.
* **FR-01602**: Clicking `SETTLE (BANKERX)` SHALL raise standard FDC3 3.0 intent `StartPayment` with a fully formed `fdc3.payment` payload per FINOS PR #2204.
* **FR-01603**: The `fdc3.payment` payload SHALL carry the trade's **cash obligation**, mapped from the trade by the settlement-instruction module (`generation/payment-instruction.mjs`; Angular mirror in the trade-blotter overlay) — never the traded instrument verbatim:
  - `type`: `"fdc3.payment"` (PR #2204; receivers accept legacy `"fdc3.paymentContext"` for backward compatibility)
  - `amount`: the cash amount in `currency`'s minor units. FX pair trade: the traded base-currency quantity. Equity trade: `quantity × fill price` rounded to minor units (float drift such as `14020.964999999998` MUST NOT reach the wire).
  - `currency`: an active ISO 4217 code — the base leg of an FX pair security, or the venue quote currency (`KES`) for an equity trade. An instrument symbol (`BAC`) is never a `currency`; the blotter refuses to dispatch, and the receiver validator rejects, any code outside the ISO 4217 set.
  - `pair` + `rate`: a coupled OPTIONAL frame, present only on FX cash legs (`pair` = the traded pair, `rate` = the execution fill price). Equity settlements are same-currency transfers and carry neither — the blotter holds no FX data for them and none is invented. A lone `pair` or a lone `rate` is an invalid instruction.
  - `debtor` / `creditor`: party names and settlement accounts following the trade side — the buyer owes the cash (debtor = executing desk on Buys, counterparty desk on Sells).
  - `networkRouting`: Declared routing preference (`Trilateral Powerhouse`, `Solana Token-2022`, or `XRPL Altnet`) and RFC 4122 UUIDv4 `uetr`
* **FR-01604**: If the FDC3 Desktop Agent returns an `IntentResolution`, TraderX SHALL log the target application ID and resolution status in structured diagnostic logs.
* **FR-01605**: If FDC3 is unavailable, the blotter SHALL remain fully functional (014 baseline behavior; no action column is rendered because intent discovery cannot resolve). If a dispatched `StartPayment` intent fails to raise, TraderX SHALL display a non-blocking toast notification: `"FDC3 Desktop Agent unavailable — launching BankerX via direct web dispatch"` and provide a fallback URI link to `https://terminal.synapticchain.xyz`.
* **FR-01606**: TraderX SHALL listen for settlement status broadcasts (`synaptic.settlementStatus`, carrying the ISO 20022 `pacs.002` status: `Acsc`, `Rjct`, `Pndg`) and flip the dispatched blotter row through `SETTLING…` → `SETTLED` / `REJECTED`, correlated strictly by matching UETR. Unmatched status reports SHALL be logged, never applied.
* **FR-01607**: TraderX SHALL prevent duplicate settlement requests per trade row: a row with a settlement in flight (`Pndg`) or settled (`Acsc`) SHALL suppress further dispatches with an explanatory status message; a failed dispatch SHALL revert the row cleanly.
* **FR-01608**: The generated 016 runtime SHALL include the local mock receiver (`generation/mock-receiver/`) as the DEFAULT settlement receiver so the request-to-outcome demonstration and tests are reproducible offline. The BankerX settlement terminal SHALL be supported as an opt-in reference adapter via an app-directory URL swap (provider-neutral; no TraderX change).
* **FR-01609**: Settlement dispatch state in TraderX SHALL be session-scoped only (UETR, row correlation, status). No server-side persistence, no schema or migration changes.

---

## 4. Architectural Diagram: The Two-Tier Adapter Pattern

Receiver variants behind the same FDC3 boundary (provider-neutral):

- `Tier 2a — Local mock receiver (default)`: `generation/mock-receiver/`, dependency-free, offline-reproducible; emits `synaptic.settlementStatus` (`Acsc`/`Rjct`/`Pndg`).
- `Tier 2b — BankerX reference adapter (opt-in)`: the live settlement terminal below.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TIER 1: FRONT-OFFICE EXECUTION (TraderX Angular Client)                     │
│   • Trade Blotter: Row click -> Settle (BankerX) [findIntent-gated]         │
│   • Dispatches: fdc3.raiseIntent("StartPayment", paymentContext)            │
│   • Runtime: Pure web / FDC3 3.0 container (sub-2ms dispatch, zero crypto)    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                  Standard FDC3 Intent Bus / OpenFin / Sail
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│ TIER 2: POST-TRADE SETTLEMENT ENGINE (BankerX / synaptic-fx-terminal)       │
│   • FDC3 Intent Listener captures "StartPayment" context                    │
│   • Auto-populates PaymentPanel with Debtor, Creditor, Amount, Pair, UETR  │
│   • Triggers Tier 2 ADR-555 Local Enclave Preflight:                        │
│       1. ISO 20022 pacs.008 Schema Validation (0.25 ms)                     │
│       2. In-Memory Merkle Bloom Filter Sanctions Check (0.68 ms)             │
│       3. Mantis Invariant 9 Solvency Gate: Gross == Net + TSA Fee (1.85 ms)  │
│       4. ADR-062 256-Lane Rendezvous Hash Partitioning (0.75 ms)             │
│       5. ADR-062 Gap-Tolerant 256-Bit Sliding Window Nonce (0.40 ms)        │
│       6. Dual Ed25519 + 67-Chain WOTS+ Post-Quantum Signing (2.10 ms)       │
│   • Total Enclave Pre-flight Latency: ~6.03 ms (< 8.00 ms Budget)           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                 Dispatches Atomic Settlement to Ledger Rails
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│ TIER 3: TRILATERAL SETTLEMENT POWERHOUSE                                    │
│   ├─ Rail 1: Solana Token-2022 (RequiredMemoTransfers, Error 0x24 on bypass)│
│   ├─ Rail 2: XRPL Altnet (DENSE-16 SHAMap Native Proof + pacs.002 receipt)  │
│   └─ Rail 3: SynapticChain L1 (256-Lane SCBFT Consensus & 150M TSA Reserve) │
│                                                                             │
│ Output: Canonical ISO 20022 pacs.002.001.10 Settlement Receipt (Acsc)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Non-Functional Requirements & Performance SLAs

* **NFR-01601 (Standard Purity)**: TraderX client codebase MUST NOT import blockchain SDKs (e.g. `@solana/web3.js`, `xrpl`). All ledger logic is strictly encapsulated within the BankerX Tier-2 Enclave.
* **NFR-01602 (Pre-Flight SLA)**: Local compliance validation in BankerX must execute in `< 8.00 ms` before any payload leaves the host machine.
* **NFR-01603 (Settlement SLA)**: On-chain settlement confirmation must complete in `< 500 ms` on Solana Token-2022.
* **NFR-01604 (Auditability)**: Every settlement must generate a 14-point CBPR+ compliant `pacs.008` initiation document and a signed `pacs.002` settlement receipt.

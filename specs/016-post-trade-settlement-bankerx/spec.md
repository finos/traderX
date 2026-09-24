# Feature Specification: FDC3 Post-Trade DvP Settlement Interoperability (TraderX ↔ BankerX)

**Feature Branch**: `016-post-trade-settlement-bankerx`  
**Created**: 2026-09-24  
**Status**: Specification Complete & Reference Implemented  
**Standards Alignment**: FINOS FDC3 3.0 (PR #2204, Issue #444), ISO 20022 CBPR+ (pacs.008, pacs.002), RFC 4122 (UUIDv4 UETR)  
**Input**: Transition delta from `014-fdc3-intent-interoperability`  

---

## 1. Executive Summary

While **TraderX** provides institutional-grade pricing awareness, order matching, and trade execution blotters, enterprise capital markets currently suffer from a **T+2 settlement latency gap**. Trades executed in milliseconds must wait 48 hours to clear across legacy correspondent banking networks due to disconnected post-trade clearing systems.

This specification completes the financial trading lifecycle by bridging **TraderX** (Front-Office Execution) with **BankerX** (Post-Trade Clearing & Settlement):
* When an FX trade execution occurs in the TraderX blotter, the trader can raise the standardized FINOS FDC3 3.0 intent:
  $$\text{fdc3.raiseIntent("StartPayment", paymentContext)}$$
* The intent routes into **BankerX** (`synaptic-fx-terminal`), carrying the standardized `fdc3.paymentContext`.
* BankerX executes pre-flight compliance via the **ADR-555 Alcove Runtime Guardian** (`<8ms`), screen sanctions via in-memory Bloom filters (zero wire leakage), verifies solvency ($\Delta \equiv 0$), and triggers atomic settlement across the **Trilateral Settlement Powerhouse** (Solana Token-2022 `RequiredMemoTransfers` + XRPL Altnet DENSE-16 SHAMap + SynapticChain L1 SMR) within **400 milliseconds**.
* Canonical ISO 20022 `pacs.008` (Credit Transfer Initiation) and `pacs.002` (Payment Status Report / Receipt with `Acsc` confirmation) XML receipts are generated and bound to the RFC 4122 UUIDv4 SWIFT UETR.

---

## 2. User Stories

* **As a spot FX trader**, I want to click "Settle Trade" directly from my TraderX execution blotter so that settlement instructions are immediately dispatched to the clearing desk without re-keying amounts, accounts, or currencies.
* **As a clearing operations officer**, I want BankerX to receive FDC3 payment intents from TraderX, validate them against ISO 20022 CBPR+ schema rules, and screen counterparty identities locally in `<8ms` without leaking order book data over external network wires.
* **As an enterprise compliance auditor**, I want every trade settlement to emit immutable ISO 20022 `pacs.002.001.10` settlement confirmation receipts that cryptographically bind the SWIFT UETR to on-chain transaction hashes.
* **As a system maintainer**, I want the TraderX desktop experience to remain fully operational and graceful if no FDC3 Desktop Agent or BankerX settlement listener is active.

---

## 3. Functional Requirements

* **FR-01601**: TraderX Trade Blotter SHALL provide an explicit action button labelled `SETTLE (BANKERX)` on each confirmed trade row.
* **FR-01602**: Clicking `SETTLE (BANKERX)` SHALL raise standard FDC3 3.0 intent `StartPayment` with a fully formed `fdc3.paymentContext` payload conforming to FINOS PR #2204.
* **FR-01603**: The `fdc3.paymentContext` payload SHALL include:
  - `type`: `"fdc3.paymentContext"`
  - `amount`: Gross executed notional quantity
  - `currency`: Base currency of the traded instrument (e.g. `USD`)
  - `pair`: Canonical currency pair (e.g. `USD/KES`, `USD/ZMW`, `EUR/USD`)
  - `rate`: Execution fill price
  - `debtor`: Trade buyer entity name and settlement account
  - `creditor`: Trade seller entity name and settlement account
  - `networkRouting`: Declared routing preference (`Trilateral Powerhouse`, `Solana Token-2022`, or `XRPL Altnet`) and RFC 4122 UUIDv4 `uetr`
* **FR-01604**: If the FDC3 Desktop Agent returns an `IntentResolution`, TraderX SHALL log the target application ID and resolution status in structured diagnostic logs.
* **FR-01605**: If FDC3 is unavailable, clicking `SETTLE (BANKERX)` SHALL gracefully display a non-blocking toast notification: `"FDC3 Desktop Agent unavailable — launching BankerX via direct web dispatch"` and provide a fallback URI link to `https://terminal.synapticchain.xyz`.
* **FR-01606**: TraderX SHALL listen for settlement confirmation callbacks or channel broadcast updates containing ISO 20022 `pacs.002` settlement status (`Acsc`) to mark blotter rows as `SETTLED`.

---

## 4. Architectural Diagram: The Two-Tier Adapter Pattern

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TIER 1: FRONT-OFFICE EXECUTION (TraderX Angular Client)                     │
│   • Trade Blotter: Row click -> Settle (BankerX)                            │
│   • Dispatches: fdc3.raiseIntent("StartPayment", paymentContext)            │
│   • Runtime: Pure web / FDC3 3.0 container (<2ms dispatch, zero crypto)    │
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

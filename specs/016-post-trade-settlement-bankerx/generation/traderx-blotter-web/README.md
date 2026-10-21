# TraderX Spec 016 Standalone Web Execution Blotter

> **Live Reference Implementation:** [https://traderx.synapticchain.xyz](https://traderx.synapticchain.xyz)  
> **Standards:** FINOS FDC3 3.0 (PR #2204), TraderX Spec 016 (PR #470), Solana Token-2022 (RequiredMemoTransfers)

---

## Overview

This directory provides the standalone, dependency-free **TraderX Spec 016 Web Blotter**. It serves as the primary visual and operational demonstration of the **FINOS TraderX ↔ BankerX Post-Trade cash-leg settlement flow** without requiring a heavyweight Angular build or local Kind Kubernetes cluster.

### Capabilities & Key Features

1. **FINOS FDC3 3.0 Intent Dispatch:**
   - Raises standard `StartPayment` intent with full `fdc3.payment` payloads carrying RFC 4122 UUIDv4 SWIFT UETRs, currency pairs, notional amounts, execution rates, and debtor/creditor metadata.
   - Dispatches seamlessly via desktop agent or cross-window `postMessage` to the BankerX clearinghouse ([terminal.synapticchain.xyz](https://terminal.synapticchain.xyz)).

2. **FR-01601 Intent Discovery Gating:**
   - Dynamically gates the `SETTLE (BANKERX)` action in the order blotter until the BankerX clearinghouse is detected in the workspace.

3. **FR-01607 Session-Scoped Duplicate Dispatch Guard:**
   - Tracks dispatched UETRs in session memory to strictly prevent duplicate settlement dispatches.

4. **Direct On-Chain Solana Sealevel Verification:**
   - Bypasses local synthetic timers by polling the Solana Devnet validator RPC (`https://api.devnet.solana.com`) directly for the creditor account (`BnuCTFWFLLXnSPv2Frs42royiTAYG87WP7p1zRLB4ksG`).
   - Automatically detects the consensus-included `spl-memo` instruction containing the trade's UUIDv4 UETR and flips the row to `ACSC ✓` with a direct link to the Solana Explorer.

5. **FINOS FDC3 App Directory (AppD):**
   - Manifest provided at `appd.json` declaring both TraderX and BankerX applications with `CORS *` support for OpenFin, Finsemble, and Sail container integration.

---

## File Layout

| File | Purpose |
| :--- | :--- |
| `index.html` | High-density institutional trading blotter and FDC3 event log UI. |
| `payment-lifecycle.mjs` | Canonical provider-neutral CBPR+ validation and duplicate prevention module. |
| `appd.json` | FDC3 3.0 App Directory manifest for workspace application discovery. |

---

## Live Deployment

The blotter is deployed on the canonical institutional mesh:
- Web App: `https://traderx.synapticchain.xyz`
- App Directory: `https://traderx.synapticchain.xyz/appd.json`
- Well-Known App Directory: `https://traderx.synapticchain.xyz/.well-known/appd.json`

# Spec 016: FDC3 Post-Trade Settlement Interoperability (TraderX ↔ BankerX)

## Overview
This specification bridges **TraderX** (Front-Office Execution) with **BankerX** (Post-Trade DvP Settlement) using **FINOS FDC3 3.0** standard intents (`StartPayment`) and ISO 20022 `pacs.008` / `pacs.002` messaging.

## Key Links
* **FDC3 Standard PR**: [FINOS FDC3 PR #2204 (Payment Context & StartPayment Intent)](https://github.com/finos/FDC3/pull/2204)
* **FDC3 Standard Issue**: [FINOS FDC3 Issue #444](https://github.com/finos/FDC3/issues/444)
* **Live Reference Settlement Engine (BankerX)**: [https://terminal.synapticchain.xyz](https://terminal.synapticchain.xyz)
* **Reference Implementation**: `synaptic-fx-terminal`

## Architecture: Two-Tier Adapter Pattern
1. **Tier 1 (TraderX)**: Raises pure, zero-crypto `fdc3.raiseIntent("StartPayment", paymentContext)`.
2. **Tier 2 (BankerX & ADR-555 Enclave)**: Evaluates preflight compliance (in-memory Bloom sanctions filter, Mantis Invariant 9 solvency $\Delta=0$, 67-chain WOTS+ post-quantum signature) in `<8ms`.
3. **Tier 3 (Multi-Rail SMR)**: Settles atomically across Solana Token-2022 (`RequiredMemoTransfers`), XRPL Altnet DENSE-16 SHAMap, and SynapticChain L1 256-lane SMR.

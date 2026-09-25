# Quickstart: FDC3 Post-Trade DvP Settlement (TraderX ↔ BankerX)

## 1) Generate Baseline C3 Runtime

```bash
bash pipeline/generate-state.sh 012-platform-convergence-c3
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind --skip-build
```

## 2) Start the State-016 Runtime (Settlement Adapter)

```bash
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --provider kind
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --provider kind --skip-build
```

Expected UI endpoint:

- TraderX: `http://localhost:8080` (Trade Blotter at `/trade`)

Settlement note for this state:

- Each confirmed blotter row carries a `SETTLE (BANKERX)` action.
- With an FDC3 Desktop Agent present, the action raises `StartPayment` with a complete `fdc3.paymentContext` (UETR-keyed).
- Without a Desktop Agent, TraderX shows a non-blocking toast and links to `https://terminal.synapticchain.xyz` for direct web dispatch (FR-01605).

## 3) Operator Demo Script

1. Open the Trade Blotter and confirm a trade row (buyer/seller/currency pair populated).
2. Click `SETTLE (BANKERX)`.
3. With a Desktop Agent: confirm the `StartPayment` resolution is logged with the target application and status (FR-01604), and the BankerX terminal receives the payment context with the UUIDv4 `uetr`.
4. Observe the settlement pipeline on the BankerX terminal: ISO 20022 pacs.008 generated, compliance pre-flight, atomic settlement on the declared rail, pacs.002 (`Acsc`) emitted.
5. In TraderX, confirm the blotter row flips to `SETTLED` when the matching-UETR `Acsc` confirmation arrives (FR-01606).
6. Kill the Desktop Agent and repeat step 2 to verify the graceful fallback toast and direct-dispatch link (FR-01605).

## 4) Stop Runtime

```bash
./scripts/stop-state-016-post-trade-settlement-bankerx-generated.sh --provider kind
```

## 5) Verification

- Mocked DesktopAgent integration tests cover the `raiseIntent` → settlement-confirmation round-trip.
- Degraded-mode tests prove the baseline blotter behavior is unchanged when FDC3 is absent.
# Quickstart: FDC3 Post-Trade Cash-Leg Settlement (TraderX ↔ BankerX)

## 1) Generate Baseline C3 Runtime

```bash
bash pipeline/generate-state.sh 012-platform-convergence-c3
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind --skip-build
```

## 2) Start the State-016 Runtime (Settlement Adapter)

The default runtime for this state is the **offline acceptance flow** (FR-01608, Tier 2a — no cluster, no external services):

```bash
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --static
# serve + open automatically:
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --serve
```

Full walkthrough with gates: [acceptance/README.md](acceptance/README.md) ·
reviewer script: [acceptance-demo.md](acceptance-demo.md).

Cluster variant (014 generated baseline + Sail sidecar, mock-receiver record merged into the Sail app directory):

```bash
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --provider kind
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --provider kind --skip-build
```

Expected UI endpoints:

- Static acceptance: `http://localhost:8090` (blotter at
  `/generation/traderx-blotter-web/index.html`; mock receiver at
  `/generation/mock-receiver/index.html`)
- Cluster variant: TraderX `http://localhost:8080` (Trade Blotter at `/trade`), Sail `http://localhost:8090`

Settlement note for this state:

- Each confirmed blotter row carries a `SETTLE (BANKERX)` action.
- With an FDC3 Desktop Agent present, the action raises `StartPayment` with a complete `fdc3.payment` context (UETR-keyed, per FINOS PR #2204).
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
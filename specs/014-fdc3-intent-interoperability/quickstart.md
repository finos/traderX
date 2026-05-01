# Quickstart: FDC3 Intent Interoperability on C3

## 1) Generate Baseline C3 Runtime

```bash
bash pipeline/generate-state.sh 012-platform-convergence-c3
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind --skip-build
```

## 2) Start Local Sail Sidecar (State 014 Target Behavior)

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail --skip-build
```

Expected UI endpoints:

- TraderX: `http://localhost:8080`
- Sail: `http://localhost:8090`

Interop note for this state:

- TraderX publishes canonical `fdc3.instrument.id.ticker` (bare symbol).
- Sail-side TradingView override patchwork performs widget-specific exchange qualification for demo compatibility.

## 3) Run Interop Smoke Tests

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```

## 4) Stop Runtime

```bash
./scripts/stop-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail
```

## 5) Operator Demo Script (Two Tabs)

1. Open Sail at `http://localhost:8090/html/` and confirm two tabs are present:
   - `One`: chart/pricing/traderx-intent-launcher controls
   - `Two`: news app.
2. In tab `One`, click `Create Order Ticket` or `Create Trade Ticket` in `traderx-intent-launcher`.
3. Confirm TraderX (`http://localhost:8080/trade`) opens the corresponding ticket with the selected ticker prefilled.
4. Switch to tab `Two` and confirm news app context stays aligned to the active ticker.
5. From TraderX, change selected blotter row ticker and verify Sail chart/news apps update through `fdc3.instrument` context.

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
- Mini TraderX: `http://localhost:8080/mini-traderx`
- Sail: `http://localhost:8090`
- TraderX Intent Launcher: `http://localhost:4040`
- TradingView Chart: `http://localhost:4023/?mode=chart`
- Pricer: `http://localhost:4020`
- TraderX App Directory: TraderX ingress-hosted FDC3 App Directory source using `/v2/apps`

Interop note for this state:

- TraderX publishes canonical `fdc3.instrument.id.ticker` (bare symbol).
- TraderX owns the App Directory records for core TraderX, Mini TraderX, and TraderX Intent Launcher.
- Sail v3 beta bootstrap patching currently injects equivalent app records, ports the frameable TradingView/Pricer demos from FDC3-Sail `main`, restores FINOS conformance apps, and aligns generated packages to FDC3 `3.0.0-alpha.2`.
- Target Sail behavior is multiple App Directory sources, configured at startup for repeatable demos and editable through a Sail GUI during a session.

## 3) Run Interop Smoke Tests

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```

## 4) Stop Runtime

```bash
./scripts/stop-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail
```

## 5) Operator Demo Script

1. Open Sail at `http://localhost:8090/` and confirm the Sail v3 workspace is present:
2. Confirm the TraderX, Mini TraderX, TraderX Intent Launcher, TradingView, Pricer, and FINOS conformance app directory entries are available in Sail.
3. Launch TraderX from Sail and confirm it connects through FDC3 v3 `getAgent()`.
4. Confirm Mini TraderX is present in the Sail workspace and follows the same account and instrument context as the main TraderX view.
5. Launch TraderX Intent Launcher from Sail and use it to raise `TraderX.CreateTradeTicket` or `TraderX.CreateOrderTicket` for the current `fdc3.instrument` ticker.
6. Launch Trading View Chart or Pricer from Sail, then from TraderX change selected blotter row ticker and verify Sail-hosted apps update through `fdc3.instrument` context or intent routing.

# State 014 FDC3 Intent Interoperability Artifacts

Generated from:

- `specs/014-fdc3-intent-interoperability/**`
- inherited runtime from `generated/code/target-generated/tilt-kubernetes-dev-loop`

State intent:

- preserve state 012 runtime behavior,
- add a local Sail sidecar with seeded TraderX AppD metadata for FDC3 demo flows.

Artifacts:

- Sail sidecar compose: `sail/docker-compose.yml`
- Sail bootstrap scripts: `sail/bootstrap/*.sh`
- Sail pin manifest: `sail/bootstrap/sail-pin.env`
- Sail TradingView widget override: `sail/bootstrap/overrides/tradingview/TradingViewWidget.tsx`
- Sail TradingView mode overrides: `sail/bootstrap/overrides/tradingview/modes/*.ts`
- Sail Polygon news widget override: `sail/bootstrap/overrides/polygon/PolygonWidget.tsx`
- Sail TraderX intents launcher override app: `sail/bootstrap/overrides/traderx-intent-launcher/**`
- Sail default client-state snapshot: `sail/bootstrap/overrides/web/default-client-state.json`
- Sail web client bootstrap override: `sail/bootstrap/overrides/web/src/client/index.tsx`
- TraderX app directory overlay: `sail/appd/traderx.appd.v2.json`
- Sail runtime cache root: `sail/runtime-cache/`

Run baseline C3 runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --without-sail
```

Run C3 + Sail demo runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```

Demo script (two-tab profile):

1. Open Sail at `http://localhost:8090/html/` and verify two tabs:
   - `One`: chart + pricing + `traderx-intent-launcher` controls
   - `Two`: news app.
2. In tab `One`, use `Create Trade Ticket` and `Create Order Ticket`.
3. Confirm TraderX (`http://localhost:8080/trade`) opens the matching ticket with ticker prefilled.
4. Switch to tab `Two` and confirm news remains aligned to the active ticker context.
5. Change selected ticker in TraderX blotters and verify Sail apps update via `fdc3.instrument`.

Known demo workarounds / technical debt:

- TraderX publishes canonical bare ticker payloads only (`fdc3.instrument.id.ticker`).
- TraderX may use a bounded active-channel context-sync fallback to compensate for inconsistent demo-agent callback delivery; remove when robust Sail event delivery is available.

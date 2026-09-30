# Angular bundle hand-patch — RETIRED 2026-09-30

## v16 G8-fix (2026-09-30, later the same day; commit `e10ad26`)

The ×2 batch on v15 bytes failed exactly one gate, `G8` (the SETTLED badge),
twice — while the run log showed the status fully landing
(`[fdc3] settlement status received {uetr …, status: Acsc}`, i.e.
`receiveSettlementStatus` passed its type + dispatched-UETR gates and
`settlementStatus$.next` fired). Root cause is not in the status chain at all:
`refreshSettlementCells()` reset rowData with the **same trade object
references** (`[...this.trades]` copies the array, not its items), and with
`getRowId` set ag-Grid treats row data as immutable — a rowData reset alone
does not re-run cell renderers, so the already-updated `settlementByRow` map
never got re-painted. The estate (root-index) surface is unaffected because it
full-renders the blotter after the same mutation. Fixed in source
(`fdc3… trade-blotter.component.ts`): `gridApi.refreshCells()` after the
rowData reset. Proved ×2 on the deployed v16 bytes
(`main-L3LD77TD.js` `26361d9b…`, index `c557f372…`).

## v15 flow-fix (2026-09-30, later the same day; commit `d9179ee`)

The source-rebuilt bundle exposed a dead SETTLE gate: the state as served
showed no SETTLE column because (a) nothing on the blotter view initialized
the FDC3 interop service, and (b) the StartPayment availability probe read
`resolution.apps`/`resolution.appIntents` off a response the estate DA
delivers in the FDC3 wire shape `{appIntent:{intent,apps}}`. Both fixed in
source (`fdc3-interop.service.ts`, `trade-blotter.component.ts`), plus the
separate-window desk launch (`estate-agent.ts open()` popup features) and the
mobile-fluid blotter containers (`trade.component.scss`, terminal already
page-fluid at 390/620 — no terminal bytes changed).

Honest caveat: the archived hand-patched bundle below is **not** a byte-exact
record of what was served this morning — the live bundle that passed the
14:24–14:25 E2E runs evidently carried additional estate deltas in the
availability region (it rendered the SETTLE column; the archive's parse
could not). Fingerprint parity on markers stays true; behavioral code parity
of the pre-v15 bundle does not. The v15 source fixes supersede and close the
question — the current bytes (`main-WFYOIDOI.js`) ship the fixed logic in
real TypeScript.

## The source-rebuilt bundle (retired again 2026-09-30 by the v15 flow-fix)

The hand-patch described below is **no longer served**. The pair-mapping
logic now lives in real TypeScript source and the deployed bundle is a clean
rebuild from it:

- Source: `templates/web-front-end/angular/main/app/trade/trade-ticket/trade-ticket.component.ts`
  — `onCreate()` normalizes the selected company label to `USD/KES` /
  `EUR/USD` (via `includes`) and otherwise passes the selected company through
  `Fdc3TickerCompatibilityBridgeService.normalizeTicker` (single canonical
  normalization location).
- Deployed: `main-ZMJ5JEK4.js` (md5 `eca76fccac04c67f69aff428179aa73a`),
  built `ng build --configuration production --base-href /angular/` from the
  tree with the 016 frontend overrides applied (per `../generation-hook.md`).
- Fidelity proof: rebuilt bundle fingerprint-matches the previously served
  bundle on every estate marker (`settlementByRow` 8, `StartPayment` 11,
  `getAgent` 8, `UETR` 6, `Pndg` 6, desk strings, `runtimeMetadataUrl` 2…);
  the only intended deltas are the onCreate normalization port and the
  resolveAgent fast-path made explicit. Byte diffs elsewhere are minified
  identifier renames.
- Source-side extras needed to reproduce the deployed build tree (all
  committed here): 016 `fdc3-interop.service.ts` (incl. the estate
  resolveAgent fast-path), `Account.name?`, `Trade.price?`,
  `@robmoffat/fdc3-get-agent` dependency, `skipLibCheck`.
- Superseded bundle archived: `evidence/main-SZ7POL5E.js.hand-patched.bak`
  (md5 `73fbb1c9571202a3fba214acea1ea02b`) — the previously served
  hand-patched copy (retired from the web root same day).
- Pristine upstream evidence unchanged: `evidence/main-SZ7POL5E.js.bak`
  (pristine, 1,663,875 bytes) and `evidence/index.html.bak`.

## The retired patch (historical record)

`main-SZ7POL5E.js` (served at `/angular/main-SZ7POL5E.js` until 2026-09-30
carried one hand-written injection vs the pristine upstream build
(`evidence/main-SZ7POL5E.js.bak` — pristine copy, moved out of the web root
2026-09-30 so the served directory carries no trail):

- **Location:** TradeTicket component `onCreate` (byte ~435010).
- **Size:** +633 bytes.
- **Behavior:** after the Create-Ticket form submits, the selected company
  string is normalized to a currency pair: `contains("KES") || contains("USD/KES")`
  → `USD/KES`, `contains("EUR") || contains("EUR/USD")` → `EUR/USD`,
  otherwise the selected company passes through unchanged. Without it the
  grid rows would carry raw company names and the post-trade settle flow
  (which builds `fdc3.payment` from the row's `security` pair) would have
  no pair to settle against.
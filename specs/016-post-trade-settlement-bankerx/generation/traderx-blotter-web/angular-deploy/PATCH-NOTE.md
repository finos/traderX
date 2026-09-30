# Angular bundle hand-patch — RETIRED 2026-09-30

## v18 (2026-09-30 evening): UETR in the state column + pacs.002 ordering guard

Clean source rebuild (same recipe as v15/v16/v17). Two additions to
`trade-blotter.component.ts`, both driven by the operator's Oct-1 flow
requests:

1. **UETR under the badge** — `settlementCellHtml` appends `uetrLine(uetr)`
   to every non-button state: the truncated UETR (`first8…last4`,
   9px monospace, muted) with the FULL UETR on the `title` attribute. The
   UETR is the pacs.008 ↔ pacs.002 correlation ID; judges can now trace a
   row into the desk receipt modal / explorer without opening anything.
   Lifecycle stays one-way: `SETTLING…` → `SETTLED` (~15s trilateral round
   trip live-traced; see receipt).
2. **ISO 20022 status ordering guard** — `applySettlementStatus` now refuses
   to move a row backwards: pacs.002 terminal statuses (`Acsc`/`Rjct`) are
   one-way; a late or re-relayed non-terminal report on the same UETR is
   logged and dropped (`ignored non-forward status report`). Today no estate
   path emits `Pndg` post-dispatch; the guard makes the invariant structural
   ahead of any future mid-flight status. No fabricated status is ever sent
   to exercise the negative path (no-fabrication principle).

Deployed bytes: `main-I5PEKJGD.js` (`b694f8c7…`) + angular `index.html`
(`3c8e4f66…`, bundle ref `?v=18`); agent `?v=15`, bridge `?v=13`, root
index unchanged. Verified served==disk per URL-bust; preflight re-pointed to
v18 → 25/0 DEMO-READY. Suites on the new bytes: angular conf ×2 (131/1 then
**132/0**), angular E2E ×2 all-gates green (`G8 SETTLED cell Trade-6`),
blotter probe ×1 with the added p6 `uetrShown` gate (all six gates green) —
`ops/FDC3-CONFORMANCE-RECEIPT-2026-09-28.md` §"v18".

## v17 blotter-fix (2026-09-30, after the v16 batch)

NOT a hand-patch — a clean source rebuild. Two user-facing blotter defects,
both root-caused in source:

1. **Ticket-create not visible without window refresh.** Root cause: the
   estate Synaptic adapter (`synaptic-traderx-adapter`, :8415) implements the
   trade-feed Socket.IO path as a handshake mock — a fake sid with no engine
   connection, so no `createTradeTicket` notification ever reaches the
   blotter's feed subscription. Fix (source, `trade-blotter.component.ts`):
   poll the real REST snapshot (`GET /trades`) every 3s and merge in only NEW
   trades (`mergeSnapshot`) — existing rows keep object identity, ag-Grid
   `getRowId` contract untouched.
2. **Settled rows reset to SETTLE after reload.** Root cause: the settlement
   map (`settlementByRow`) was component-scoped in-memory state; nothing
   restored it and the status correlator can only match UETRs already in the
   map. Fix (same file): persist the ledger — real dispatched facts only —
   to `localStorage["traderx_settlement_ledger_v1"]`, restore at
   construction, persist again on every status transition (Pndg → Acsc/Rjct)
   and on the honest dispatch-failure rollback.

Deployed bytes: `main-V6THKHFV.js` (`707039fa…`) + `index.html` (`c8191c56…`),
agent `?v=15` / bridge `?v=13` untouched; preflight updated to assert v17
(`ops/oct1-fdc3-demo-preflight.sh`). The 016 frontend-overrides copies of
`trade-blotter.component.ts` + `fdc3-interop.service.ts` were re-synced to the
applied source (they had drifted behind the v15/v16 fixes).

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
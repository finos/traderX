# Angular bundle hand-patch — RETIRED 2026-09-30

## v20 (2026-10-01): durable settlement ledger — settled state survives refresh, a second browser, and an adapter restart

Operator report on angular: opening another browser reset rows to SETTLE
buttons for trades already settled, and some rows stayed on SETTLING… after
BankerX settled them. Root cause verified in code: the settlement ledger
lived ONLY in `localStorage`(`traderx_settlement_ledger_v1`, per-browser)
and the adapter served every trade with its in-memory lifecycle state while
holding no settlement status at all — so the ONLY place settlement truth
existed was a single browser's localStorage. The desk-reuse v19 work landed
first; v20 is this fix.

Fix (three pieces, minimal delta):

1. **Adapter durable registry** (`synaptic-traderx-adapter/server.mjs`,
   :8415) — file-backed JSON (`settlements.json` next to server.mjs)
   keyed by UETR. `GET /trade-service/trade/trades/settlements/` returns the
   map; `POST` the same path publishes `{entries:[{uetr,status,tradeId,
   security,quantity,side,created,txSignature?}]}`. One-way ISO 20022
   ordering (`Pndg → Acsc/Rjct`, never backwards) is enforced SERVER-side.
   Routes sit before the `/trade`/`/trades` substring checks (the
   trade-service prefix itself contains `/trade`). Verified: Pndg→Rjct merge
   accepted, later Pndg merge ignored; registry survives `pm2 restart`.
2. **Blotter publish + reconcile** — `persistSettlementLedger()` now also
   publishes the ledger (entries carry the trade fingerprint: security,
   quantity, side, created) fire-and-forget; a new
   `reconcileFromRegistry()` (constructor, every 3s alongside the snapshot
   poll, and once whenever `mergeSnapshot` lands new rows) adopts entries
   under two guarded paths: (a) a UETR the browser already tracks — its own
   stuck rows cure themselves; (b) a fingerprint-matched tradeId for rows
   dispatched in a DIFFERENT browser. A registry entry can never stamp
   SETTLED onto an unrelated row: incomplete fingerprints block fingerprint
   adoption, and the same tradeId regenerated after an adapter restart
   (which re-seeds in-memory TRADES with a new `created`) fails the
   fingerprint and is correctly NOT adopted (demonstrated live: B did not
   adopt a pre-restart entry after the adapter restarted).
3. **Solana memo watcher port** — the root blotter's
   `checkOnChainSettlement` logic now runs in the angular blotter too (2.5s
   beat, `getSignaturesForAddress` on the creditor token account, memo
   contains the row's UETR ⇒ authoritative Acsc, because the desk settles
   only after its WOTS+ re-derivation passes and a failed attestation
   creates no settlement). Resolved rows publish to the registry with their
   tx signature so every other browser reconciles within a tick. This is
   what cures rows that stayed SETTLING because the page that missed the
   desk's live status broadcast was the only witness.

Deployed bytes: bundle `main-FDMPPVWA.js` (`ca10adb4…`) + angular index
`5143aad4…`, bundle ref `?v=20`; agent stays `?v=19` (`dcfc8cb4…`, desk
reuse), bridge `?v=13`, root pages unchanged. Served==disk verified per
URL-bust. Preflight 25/0 DEMO-READY (FROZEN_C/D re-frozen to v20).

Verification with real settles (operator directive: verify live):

- Probe 1 (drain, USD/KES seed row): browser A settled (`tx 62akSM7R…`); a
  FRESH second browser context — zero shared storage — showed the row
  SETTLED on fresh load and STILL SETTLED after reload.
- Probe 2 (drain, same row again): A settled again (`tx hkie33K9…`),
  registry held both entries across an adapter `pm2 restart`.
- The adapter registry was then cleared (`{}`) at the operator's
  clean-slate directive; probe artifacts are recorded here, not in the
  live registry.

Operator Q&A (restart / clean slate): the traderX root and angular pages
are nginx-served STATIC files — there is no process to restart, and none
was needed; the only pm2 component in the flow is `synaptic-traderx-adapter`
(:8415), which was restarted with the new server. To reset the slate:
empty `settlements.json` + `pm2 restart synaptic-traderx-adapter` (trade
seeds re-materialize with fresh identities; old ledger rows can never
collide because of the `created` fingerprint).

## v19 (2026-10-01): UETR in the STATE column after settlement

Operator correction after v18: the UETR was never supposed to land solely in
the ACTION badge — the STATE column kept showing the adapter trade-lifecycle
text ("Pending") on every row, including long-settled ones, which reads as
wrong on the desk. v19 changes exactly one thing plus one repaint fix:

1. **STATE column shows the UETR once the settlement is known** — a new
   `settlementStateCellHtml` STATE-column renderer emits `uetrLine(uetr)`
   (truncated `first8…last4`, full value on hover) for rows present in the
   settlement ledger, and keeps the raw trade state for rows with no
   dispatch. The ACTION column is UNCHANGED from v18 (SETTLE button →
   SETTLING…/SETTLED/REJECTED badge + UETR); a v19 interim build that moved
   the badge into STATE never shipped verification and was replaced the
   same hour.
2. **`refreshCells({ force: true })`** — a plain `refreshCells()` only
   re-renders cells whose value changed; the STATE field (e.g. "Pending")
   never changes, so the new content only painted after a reload. force
   makes the STATE UETR paint live on the dispatch round trip.

Deployed bytes: `main-7E7PBSO6.js` (`add329e9…`) + angular index
`29b46e1c…`, bundle ref `?v=19`; agent `?v=15`, bridge `?v=13`, root index
unchanged. Verified served==disk per URL-bust. Suites on these bytes:
angular conf ×2 (131/1 both — sole failure the disclosed Resolve1 churn),
probe ×1 all gates green incl. p6 uetr-shown-in-state and p0 pre-settle
plain state. Preflight 25/0 DEMO-READY.

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
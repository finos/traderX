# Angular deploy-only assets — source of record

These files deploy to `/var/www/traderx/angular/` (nginx, local hosting —
NOT Vercel) and are loaded by the Angular app. They are deploy-only glue:
not part of the Angular build; the canonical app bundle (`main-*.js`) is
built from `templates/web-front-end/angular/` — see `PATCH-NOTE.md` for the
2026-09-30 rebuild recipe that made the bundle fully source-derived.

| file | served as | 2026-09-30 (v18 UETR+guard) md5 | 2026-09-30 (v17 blotter-fix) md5 |
|------|-----------|----------------|----------------|
| `bankerx-bridge.js` | `bankerx-bridge.js?v=13` | 35eb71880e4ff6186f2fc619f51764c2 (unchanged) | 35eb71880e4ff6186f2fc619f51764c2 |
| `../fdc3-agent-v12.js` (agent) | `fdc3-agent.js?v=15` | b600a533d33be3c7686a581d6928bd48 (unchanged) | b600a533d33be3c7686a581d6928bd48 |
| `conf.angular.html` | `conf.html` | 25da0a4bbf0ddbc18b341ca82c722676 (unchanged, agent ref `?v=15`) | 25da0a4bbf0ddbc18b341ca82c722676 |
| (app bundle) | `main-I5PEKJGD.js` | b694f8c72580eddddb9b17e5e65506eb | (v17 `main-V6THKHFV.js` `707039fa…` retired same day) |
| (app index + glue tags) | `index.html` | 3c8e4f665c2891cc1fce5fef90b76f46 (bundle ref `?v=18`) | c8191c569e71f219d6b66eb09a3f3668 |
| (root estate index, agent ref `?v=15`) | `/index.html` | 24fd0d7a23432db871fa8e2fb06747ee (unchanged) | 24fd0d7a23432db871fa8e2fb06747ee |

v18 (2026-09-30 evening, commit on `feature/016-post-trade-settlement-bankerx`):
`settlementCellHtml` renders the truncated UETR (full value on hover) under
every settlement badge, and `applySettlementStatus` enforces the ISO 20022
one-way lifecycle (Pndg → Acsc | Rjct; terminal statuses never move
backwards). Suites on these bytes: angular conf ×2 (131/1 then 132/0),
angular E2E ×2 all-gates green, blotter probe ×1 with the new p6 uetrShown
gate — preflight re-pointed to v18, 25/0 DEMO-READY.

v17 blotter-fix (2026-09-30, same-day later rebuild): two source fixes in
`trade-blotter.component.ts`, built from the tree with the 016 overrides
applied:
1. **Live ticket refresh** — the estate adapter's trade-feed Socket.IO
   channel is a handshake mock (no live event stream), so a newly created
   ticket appeared only after a full window refresh. The blotter now polls
   the real REST snapshot every 3s and merges in only NEW trades
   (`mergeSnapshot`), preserving row-object identity for ag-Grid's
   `getRowId` contract.
2. **Settlement ledger persistence** — `settlementByRow` was in-memory
   per mount, so a reload reset every settled row to a fresh SETTLE button.
   The ledger (real dispatched facts only: entries written after a true
   dispatch, deleted again on dispatch failure) is persisted to
   `localStorage["traderx_settlement_ledger_v1"]` and restored at
   construction. Applied status reports persist on update. The 016
   frontend-overrides copies of the blotter + interop service were re-synced
   to the applied source in the same commit.

v16 G8-fix (commit `e10ad26`): `refreshSettlementCells()` now calls
`gridApi.refreshCells()` — with `getRowId`, ag-Grid treats row data as
immutable, so a rowData reset alone never re-ran the settlement cell renderer
and an applied status never painted its badge (G8 root cause, fixed in
source and proved ×2 on these bytes).

v15 flow-fix changes (commit `d9179ee`): `findIntent` parse covers the wire
shape `{appIntent:{intent,apps}}`; blotter mounts call
`interop.initialize()`; desk opens as a separate popup window (not a tab);
blotter containers fluid at phone widths.

Deploying: copy to /var/www/traderx/angular/, bump the `?v=` query in the
deployed `index.html`, then verify served md5 == disk md5 (Cloudflare
caches JS assets — a plain URL may serve a stale copy).

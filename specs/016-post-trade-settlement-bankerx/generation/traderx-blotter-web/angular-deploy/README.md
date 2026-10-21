# Angular deploy-only assets — source of record

These files deploy to `/var/www/traderx/angular/` (nginx, local hosting —
NOT Vercel) and are loaded by the Angular app. They are deploy-only glue:
not part of the Angular build; the canonical app bundle (`main-*.js`) is
built from `templates/web-front-end/angular/` — see `PATCH-NOTE.md` for the
2026-09-30 rebuild recipe that made the bundle fully source-derived.

| file | served as | 2026-10-05 (agent v20 — F-8A keyed-attestation plumbing) md5 | 2026-10-01 (v20 durable settlement ledger) md5 |
|------|-----------|----------------|----------------|
| `bankerx-bridge.js` | `bankerx-bridge.js?v=13` | 35eb71880e4ff6186f2fc619f51764c2 (unchanged) | 35eb71880e4ff6186f2fc619f51764c2 (unchanged) |
| agent (DEPLOYED copy) | `fdc3-agent.js?v=12` (root) / `fdc3-agent.js?v=20` (angular) | bdc3a82b5e11fdff2aa09bfc7c1f9207 (v20 F-8A keyed-attestation plumbing + awaited instanceId trace) | dcfc8cb4257029c0d5cd46eb753bda00 (v19 desk-reuse) |
| `conf.angular.html` | `conf.html` | 25da0a4bbf0ddbc18b341ca82c722676 (unchanged) | 25da0a4bbf0ddbc18b341ca82c722676 (unchanged) |
| (app bundle) | `main-FDMPPVWA.js?v=20` | ca10adb401a324240e3d618822fccc88 | (v19 `main-7E7PBSO6.js` `add329e9…` retired same day) |
| (app index + glue tags, agent ref `?v=20`) | `index.html` | 76e6662e1cd5957ac5121bbf89effd15 (deployed 2026-10-05) | 5143aad4ba93282c0a3bfba4e26ee6ab (bundle ref `?v=20`, pre-agent-bump) |
| (root estate index, agent ref `?v=12`, deployed-variant record: desk-reuse guard, no-tab settle, syn1 party accounts) | `/index.html` | 1dc8bd86f94a4686c22bb2b81d9f6dea | 35c80fd57daf96a14127e3c652b99071 |


v20 (2026-10-01, commit `b5cc268`): durable settlement ledger — the adapter
(:8415) now owns a file-backed settlement registry keyed by UETR
(`settlements.json`), the blotter publishes every lifecycle transition into
it and reconciles from it in any browser / after any refresh, and the Solana
memo watcher (ported from the root blotter) resolves rows whose only witness
was a page that missed the desk's broadcast. One-way ISO 20022 ordering is
enforced server-side AND in the blotter; adoption is fingerprint-guarded so
a re-seeded trade can never inherit an old settlement. Real-settle probes:
browser A settles → fresh browser B shows SETTLED fresh-load AND after
reload; registry survives `pm2 restart`. See `PATCH-NOTE.md` "v20" for the
full record (root cause, endpoint paths, probe tx signatures).

v19 (2026-10-01, commit `d7afe56`): the STATE column now shows the UETR
(`first8…last4`, full value on hover) once a row's settlement is known,
instead of the adapter's trade-lifecycle text ("Pending"). ACTION column is
unchanged from v18. Also fixed the live repaint: `refreshCells({force:true})`
(ag-Grid skips unchanged-value cells without it, so the STATE cell only
painted after reload). Suites: angular conf ×2 131/1 (Resolve1 churn),
probe ×1 all gates; preflight 25/0 DEMO-READY.

v18 (2026-09-30 evening, commit on `feature/016-post-trade-settlement-bankerx`):
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

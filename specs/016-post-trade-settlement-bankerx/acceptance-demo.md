# Acceptance Demo — FDC3 Post-Trade Cash-Leg Payment Transfer (TraderX ↔ BankerX)

State 016 · TraderX PR #470 · written 2026-09-30 (maintainer-review follow-up:
the agreed acceptance-demo script and the clean-checkout proof).

Per spec.md §0 (terminology, fixed after the maintainer review): the example
demonstrates a **currency cash-leg payment transfer** — the cash leg of an
already-executed trade, keyed by a RFC 4122 UUIDv4 UETR. It is **not**
securities delivery-versus-payment (no security leg is delivered) and **not**
payment-versus-payment (no simultaneous second-currency leg).

## The one script (what a reviewer follows)

1. From a clean checkout of the repository (no other setup):
   ```bash
   python3 -m http.server 8090 --directory specs/016-post-trade-settlement-bankerx
   ```
   Open `http://localhost:8090/generation/traderx-blotter-web/index.html?launcher=1&directory=http%3A%2F%2Flocalhost%3A8090%2Facceptance%2Fappd.json`.
2. Click `LAUNCH BANKERX` → the FDC3 desktop agent opens the clearing receiver
   in a second window through the App Directory record and the FINOS Web
   Connection Protocol handshake completes (receiver console: `WCP agent
   connected via getAgent()`; blotter log: instance id).
3. Create/locate a trade row, click `SETTLE (BANKERX)` → the standard intent
   `fdc3.raiseIntent("StartPayment", fdc3.payment)` is raised with a
   machine-built context (amount, pair, rate, debtor/creditor, UETR).
4. The receiver validates the context and returns its verdict; the
   `synaptic.settlementStatus` outcome (UETR-keyed) reaches the blotter by the
   same workspace plumbing and the row flips `SETTLING… → SETTLED`; the
   receipt modal opens.
5. Re-click `SETTLE (BANKERX)` on the same row → suppressed with an
   explanatory message (FR-01607).
6. Send an invalid payment (malformed UETR / non-canonical pair, in-page
   receiver path documented in `acceptance/README.md`) → the receiver returns
   `Rjct` with the exact validation reason; nothing is settled.

Full details, gate list, and the real-vs-simulated boundary:
[`acceptance/README.md`](acceptance/README.md).

Automated proof: the same flow was driven headless twice from a clean
checkout (fresh `git clone`, no build steps beyond the documented generation
command) with the pack E2E harness — 8/8 gates both runs (see the state
notes for the run logs).

## Clean-checkout proof (the second agreed deliverable)

Performed 2026-09-30 from a pristine clone (HEAD = the state's tip commit):

- `git clone <traderX>` → `pipeline/generate-state.sh 014-fdc3-intent-interoperability`
  → exit 0; the full generated runtime tree renders
  (`generated/code/target-generated/fdc3-intent-interoperability/` with the
  Sail sidecar tree, bootstrap scripts, app directory and runtime caches).
- `scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail --dry-run`
  → the documented `--dry-run` contract completes end to end (generation
  artifacts validated, 012 baseline validated, Sail compose action printed)
  without a cluster.
- `scripts/start-state-016-post-trade-settlement-bankerx-generated.sh --provider kind --dry-run`
  → the same contract for this state (pack artifacts validated, Sail receiver
  overlay merge action printed, 012 baseline delegated).
- The offline acceptance flow itself (the `python3 -m http.server` script
  above) runs with zero additional installs from the clean checkout.

Known environment limit (disclosed, not a gap in the assets): a full cluster
boot needs `kind` (or minikube) which was not part of the proof host — every
script honours the documented `--dry-run` contract, and the offline acceptance
flow requires no cluster at all.

## Integration with the existing TraderX application

Per the maintainer review, the standalone web blotter is **supporting
material; the integration with the existing TraderX application is the
demonstration that matters**. The equivalent flow in the actual TraderX
Angular application (upstream sample app) is delivered through the upstream
service layer: `fdc3-interop.service.ts` resolves the desktop agent
(getAgent/WCP), gates `StartPayment` availability on directory resolution,
and raises `StartPayment` with the `fdc3.payment` context from the blotter
row — the same intent, context and correlation semantics this offline pack
demonstrates. The estate deployment of the source-built Angular application
is the reference for that tier (see the estate conformance/E2E receipts).

## Receiver variants (provider-neutral tiers, FR-01608)

| Tier | Receiver | Where | Role |
|---|---|---|---|
| 2a (default) | Mock receiver | `generation/mock-receiver/` (this pack) | Offline acceptance + tests; proves the FDC3 loop, not the rail |
| 2b (opt-in)  | BankerX terminal | App Directory URL swap → `synaptic-fx-terminal` | Settlement rail reference adapter; live estate receipts are its evidence |

No TraderX code change is needed to switch receivers — it is an App Directory
record swap (`acceptance/appd.json` vs the terminal's appd endpoint).
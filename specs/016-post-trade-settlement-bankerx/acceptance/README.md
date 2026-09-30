# State 016 — Offline Acceptance Flow

Reproducible request-to-outcome demonstration of the FDC3 post-trade cash-leg
payment transfer (TraderX → clearing receiver → correlated outcome), served
entirely from a checkout of this repository — no Kubernetes cluster, no
external estate, no testnet. This is the **acceptance script** the maintainer
review (finos/traderX PR #470) asked for as one of the two next steps.

> Scope note (per spec.md §0): the flow demonstrates a **currency cash-leg
> payment transfer** — the cash leg of an executed trade keyed by UETR. It is
> not securities DvP and not PvP.

## Run it (two commands)

```bash
# 1. Serve the spec pack (from the repository root):
python3 -m http.server 8090 --directory specs/016-post-trade-settlement-bankerx

# 2. Open the blotter with the acceptance app directory:
#    http://localhost:8090/generation/traderx-blotter-web/index.html?launcher=1&directory=http%3A%2F%2Flocalhost%3A8090%2Facceptance%2Fappd.json
```

Both apps run from the pack on one origin: `finos-traderx-desk` (the web
blotter) and `bankerx-clearing-desk` (the mock receiver,
`generation/mock-receiver/`). The desktop agent boots in the blotter page
(`fdc3-agent.js`, the same in-page DA the FINOS conformance surfaces use) and
resolves intents against `acceptance/appd.json`.

## The flow (what a reviewer should do)

1. **Connect the desk** — click `LAUNCH BANKERX`. The agent opens the
   `bankerx-clearing-desk` record in a separate window (popup) and the two
   windows complete the FINOS Web Connection Protocol handshake
   (WCP1Hello → WCP3Handshake → MessageChannel). The receiver console logs the
   getAgent() connection; the blotter logs the instance id.
2. **Raise the intent** — click `SETTLE (BANKERX)` on a blotter row. The
   blotter raises the standard intent `fdc3.raiseIntent("StartPayment",
   fdc3.payment)` — machine-built `fdc3.payment` context (amount, pair, rate,
   debtor/creditor, RFC 4122 UUIDv4 UETR), never hand-typed (FR-01602/01603).
3. **Receiver processes** — the mock receiver validates the context
   (`payment-lifecycle.mjs`: RFC 4122 UETR, ISO 4217 currency, canonical pair,
   party completeness) and renders the verdict badge: `Acsc — SETTLED` on a
   valid context (or `Rjct — REJECTED` with an honest reason on an invalid
   one).
4. **Correlated outcome** — the receiver relays `synaptic.settlementStatus`
   (`Acsc`, UETR-keyed) back to the blotter; the originating row flips
   `SETTLING… → SETTLED` with zero further clicks (FR-01606), and the receipt
   modal opens.
5. **Duplicate suppression** — a second `SETTLE (BANKERX)` on the same row is
   suppressed (FR-01607): the blotter refuses with an explanatory message, and
   the receiver's duplicate-record side replays the first outcome, never a
   second settlement.
6. **Honest rejection** — dispatch a payment the receiver must refuse (e.g. a
   malformed UETR via the in-page stub agent or a non-canonical pair): the
   receiver renders `Rjct — REJECTED` with the specific validation reason and
   nothing is settled (FR-01606's `Rjct` leg, spec.md user story 5).

## Gates (what the E2E harness checks, run twice from a clean checkout)

| Gate | Assert |
|---|---|
| `realFdc3`        | blotter DA ready (`[EstateDA] Desktop agent ready`) |
| `deskOpen`        | receiver window opened through the agent's directory record (tracked instance) |
| `wcpConnected`    | receiver logged the getAgent() WCP connection |
| `intentReceived`  | receiver processed the raised `fdc3.payment` (UETR match) |
| `acsc`            | receiver verdict `Acsc` and blotter row `SETTLED` |
| `receiptModal`    | pacs.002-style receipt modal visible on Acsc |
| `dupSuppressed`   | second SETTLE on the same row refused; no duplicate dispatch |
| `rejectHonest`    | invalid context → `Rjct` with the validation reason, no settlement |

## Files

| File | Purpose |
|---|---|
| `appd.json` | Local two-record App Directory (blotter + mock receiver as `bankerx-clearing-desk`). |
| `sail-receiver-overlay.appd.json` | Applications-wrapped fragment for merging the receiver record into the Sail runtime directory (`sail/bootstrap/merge-traderx-appd.sh`) when running the generated 014/016 Sail runtime. |

The state start script lives at the repository root:
`scripts/start-state-016-post-trade-settlement-bankerx-generated.sh` (static
mode implements this flow; Sail runtime mode carries the documented
`--dry-run` contract).

## What is real vs. simulated (read this before any claim)

- **Real:** the FDC3 intent lifecycle — DA boot, directory resolution,
  `fdc3.open`, the WCP handshake, `raiseIntent("StartPayment", fdc3.payment)`
  delivery, intent registration via `getAgent()`, UETR correlation, duplicate
  suppression, and the honest `Rjct` validation path. All bytes come from this
  checkout (no estate dependency).
- **Simulated:** the *settlement rail* behind the receiver's `Acsc` verdict.
  The mock receiver is the DEFAULT offline receiver by design (FR-01608) — it
  proves the interop loop, not the settlement rail. The live terminal
  (`terminal.synapticchain.xyz`) and the estate E2E suite are the settlement
  rail's evidence; the acceptance flow's blotter-wired BankerX terminal
  variant is the opt-in reference adapter (App Directory URL swap, no TraderX
  change). Never present the offline `Acsc` as an on-chain settlement.

## Relationship to the generated Sail runtime

`python3 -m http.server` above is the *static* path. The generated runtime
path (state 014 baseline + this pack's overlay, Sail on :8090, TraderX
cluster on :8080) is covered by
`scripts/start-state-016-post-trade-settlement-bankerx-generated.sh` — see the
state quickstart §2. The full cluster boot needs kind/minikube; the script
honours the documented `--dry-run` contract so the wiring is verifiable from a
clean checkout without a cluster.
# Local Mock Receiver (016, child of 014)

The default settlement receiver for the generated 016 runtime: a dependency-free,
static FDC3 participant that makes the request-to-outcome demonstration and tests
reproducible **without any external service**. The BankerX settlement terminal
(`synaptic-fx-terminal`) remains the opt-in **reference adapter** — both variants
ship with the pack.

## Files

| File | Purpose |
|---|---|
| `index.html` | Self-contained receiver UI: renders the `fdc3.paymentContext`, shows the lifecycle outcome, broadcasts `synaptic.settlementStatus` on the user channel |
| `payment-lifecycle.mjs` | Provider-neutral lifecycle module: payload validation, duplicate-dispatch prevention, status transitions (`Pndg` → `Acsc` / `Rjct`), shared by the page AND the smoke tests |
| `appd/mock-receiver.appd.json` | App-directory record declaring `StartPayment` support — the receiver-registration reference |

## Why a mock receiver is the default

- Generated 016 state and its smoke tests must be reproducible offline (no external service, no testnet dependency in the learning path).
- The 014 → 016 generated diff must show exactly one new lesson (post-trade settlement), not a new dependency.
- BankerX stays a reference adapter: swap the receiving app in the workspace and the same intent resolves there — that is the provider-neutral point of FDC3.

## Receiver registration — the intent-declaration contract

A workspace participant is only reachable by intent if it registers like this:

1. **App record declares the intent** (`interop.intents.listensFor.StartPayment` with `fdc3.paymentContext` in its contexts) — an app record without the intent declaration is invisible to `findIntent`, and a raised `StartPayment` never routes to it. This is the failure mode of a guest app "not declaring a name".
2. **The app name/title is set in its app-directory record** — intent routing surfaces this name in the resolution UI.
3. **The runtime registers an intent listener** (`fdc3.addIntentListener('StartPayment', ...)`) — the appd record advertises capability; the listener implements it.

The TraderX blotter's `SETTLE (BANKERX)` action column appears only when
`fdc3.findIntent('StartPayment')` resolves to at least one app — so base TraderX
(no post-trade participant in the workspace) shows no action button, and the
button appears the moment the mock receiver or BankerX joins the workspace.

## Using BankerX instead (reference adapter)

Point the workspace's post-trade participant at the BankerX settlement terminal
instead of the mock receiver (the FDC3 app-directory URL swap — no TraderX change).
The intent, context, and status correlation contract is identical; BankerX adds
the real multi-rail settlement engine behind the FDC3 boundary, labeled testnet
(XRPL TESTNET (altnet) / Solana DEVNET).
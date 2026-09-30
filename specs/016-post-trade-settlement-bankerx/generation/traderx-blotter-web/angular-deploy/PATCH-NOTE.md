# Angular bundle hand-patch — disclosed (2026-09-30)

## The patch (still LIVE in the served bundle)

`main-SZ7POL5E.js` (served at `/angular/main-SZ7POL5E.js`) carries one
hand-written injection vs the pristine upstream build
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

## Why it is a seam, not a fix

This is the **ticker-as-currency / clean-checkout hazard DovOps flagged**:
the patch exists only in the served minified bundle. A clean rebuild of the
Angular app from source silently loses it, and the mapping logic belongs in
real TypeScript source (proper fix: normalize in the app's ticker service —
the same service whose `normalizeTicker` the desk-side review flagged).

**Proper fix owner:** the Angular app source (built off-seat). One rebuild
that moves both this mapping and the ticker normalization into real source
removes this entire note.

## Evidence

- `evidence/index.html.bak` — pre-script-tag index.
- `evidence/main-SZ7POL5E.js.bak` — pristine upstream bundle
  (1,663,875 bytes); served bundle is 1,664,508 bytes.
- Settlement logic (`settleTrade`, `settlementByRow`, anti-spoof guard) is
  present in BOTH files — i.e., upstream sample code; the hand patch adds
  ONLY the pair mapping above.
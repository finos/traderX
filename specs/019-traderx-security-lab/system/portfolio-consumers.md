# Scoped portfolio snapshot contract

This Phase 1 consumer correction extends the browser broker-session contract.
The position blotter owns the selected account scope and its summary. The trade
screen uses that summary directly, including when **All Accounts** is selected;
it must not independently fetch or value a second global position cache.

- Position and quote snapshots refresh every two seconds with one request in
  flight per source, a five-second timeout and cancellation on scope change or
  disposal. Settlement notifications and reconnect additionally invalidate the
  position snapshot. Responses are filtered to the captured authorized account
  IDs; notification metadata never supplies position values or permissions.
- Missing, failed, nonpositive, malformed, future-dated or older-than-60-second
  quotes make market value and P&L unavailable. Cost basis is not a substitute
  market quote. An empty authorized position response has a valid zero balance;
  a denied or failed response is unavailable and clears previously visible rows.
- Switching account or destroying the component clears the displayed summary
  and cancels old position/quote responses. Session expiry/logout destroys the
  session-gated application using the existing browser-session contract.
- The screen explains that the totals cover the selected scope, with unavailable
  text instead of displaying missing values as zero. This is bounded HTTP
  refresh, not a claim of streaming market-data delivery.

Acceptance uses the actual Angular consumer classes to check scoped filtering,
settlement/reconnect refresh, quote changes/staleness, all-account aggregation,
denial, old-scope cancellation and disposal. Hosted browser/integration tests
remain distinct from deterministic renderer and local Python checks.

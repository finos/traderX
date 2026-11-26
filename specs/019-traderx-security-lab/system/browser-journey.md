# Real Angular browser journey candidate

S019-04e joins the production Angular bundle to the actual Keycloak, browser
session, account, position, matcher, processor, PostgreSQL and TLS NATS candidates.
It is a separate hosted acceptance campaign; the 47-check authenticated trading
campaign continues independently.

## Acceptance contract

- BJ-01: Chromium loads the actual generated assets over verified HTTPS and logs
  in through the real Keycloak authorization-code/PKCE UI. A temporary localhost
  CA is installed under a unique owned nickname in the dedicated hosted runner's
  NSS database, then removed. The runner HOME stays unchanged; Chromium uses an
  owned temporary profile.
  Certificate-error flags, ignored HTTPS errors and disabled TLS verification are
  forbidden. Passwords travel in an owned mode-0600 driver configuration.
- BJ-02: The Angular account selector obtains the permitted account from the
  actual account API. A learner-style limit-order ticket creates a real matcher
  order with the accepted subject/issuer observed independently in PostgreSQL.
- BJ-03: An explicit synthetic market-price stimulus reaches the authenticated
  matcher subscription. Its real confidential grant and HTTPS processor commit
  one settlement, one trade, the expected position delta and two outbox rows.
- BJ-04: Actual supervised publisher and account-scoped consumer processes drain
  those committed events. The browser notification adapter observes metadata
  invalidations and Angular refreshes authoritative position/history snapshots.
  A submitted second nonmatching order can be canceled through the UI.
- BJ-05: Missing CSRF, cross-account access, read-only mutations and retired
  sessions are rejected. Independent database counts establish that these
  negative attempts do not create a second settlement or trade.
  Trader and reader use separate Chromium browser contexts. The trader's local
  sign-out and retired-cookie rejection are verified before that context closes;
  the reader then completes a fresh provider login in its own context. Provider
  SSO/global logout is intentionally not claimed or changed by this exercise.
- BJ-06: The evidence records input/artifact hashes, fixed check names and
  nonsecret order/execution identities. Private config, credentials, bearer
  tokens, raw provider responses and private service logs are never exported.

## Explicit fixture boundaries

Reference-symbol and display-price HTTP peers are small synthetic fixtures behind
the same authenticated proxy, over verified localhost HTTPS. They do not replace
account, order, position, trade, provider or broker implementations. The price tick
is synthetic market data, not an exploit or the complete market-data application.

PostgreSQL remains an explicit loopback-only fixture transport. These results do
not establish Kubernetes, ingress/WAF, network policy or image admission in the
same running environment. All containers, processes, NSS data and private files
are owned and removed by the campaign; only the owned certificate is removed from
the NSS database. Heavy execution runs only on hosted CI;
no local Docker, Java, npm installation or screen access is needed for source work.

The pinned AG Grid Alpine theme embeds icon fonts in its compiled CSS. The public
asset policy permits `data:` for fonts, as described in [AG Grid's CSP guidance](https://www.ag-grid.com/javascript-data-grid/security/).
Scripts and API connections remain same-origin; script evaluation, external font
CDNs and certificate-error bypasses are not enabled by this compatibility setting.

## Driver coordination

The Python orchestrator launches the Node driver with an absolute private config
path. Bounded JSON-lines on stdout request `ready_for_price` and
`ready_for_delivery`, carrying the created order ID. Python validates that ID and
the independent SQL state before replying with `{ "ok": true }` on stdin.
The final result contains fixed checks and the canceled order ID; protocol output
is validated and never forwarded verbatim. Unexpected stages, oversized messages,
early exit and deadlines fail the campaign and terminate only owned processes.

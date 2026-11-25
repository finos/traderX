# Browser session and application API boundary

This opt-in candidate advances S019-04c. It does not publish State 019 or replace
the running local lab. Browser code receives an opaque, Secure, HttpOnly session
cookie and a CSRF value; access and ID tokens remain on the session server.

## Requirements

- BAPI-01: Use the existing authorization-code/PKCE and nonce/state checks against
  the pinned TLS Keycloak fixture. Revalidate the access token and finite signing
  key snapshot on protected requests; expired sessions fail closed.
- BAPI-02: Forward only enumerated account, position/history and order routes to
  explicitly configured backends. Never accept a caller-selected destination or
  forward caller authorization, role, account, cookie or forwarding headers.
- BAPI-03: Require the exact browser Origin and session CSRF token on mutations.
  Reject ambiguous paths, queries, request framing and duplicate JSON keys.
  Limit request bodies to 16 KiB and upstream responses to 2 MiB; do not follow
  redirects. Upstream errors must not disclose private responses or credentials.
- BAPI-04: Require verified HTTPS to backends, except an explicitly selected
  literal-loopback HTTP integration fixture. This exception is not deployment TLS.
- BAPI-05: Business authorization remains in each API. The browser session is not
  an account entitlement. Independently check same-account reads, cross-account
  denials, operator empty scope, direct unauthenticated backend denial and
  unchanged business tables against real PostgreSQL.
- BAPI-06: Keep existing account-only session behavior available. Candidate routes
  must be explicitly enabled; no wildcard proxy, operator/actuator routes, legacy
  booking endpoints or NATS credentials are exposed.
- BAPI-07: The generated Angular candidate waits for `/session`, maps application
  HTTP calls to the same-origin boundary and attaches the session CSRF value only
  to same-origin mutations. Sign-out, API 401 and the server-provided expiry clear
  the view and cancel outstanding application reads. No silent token refresh is
  implied. Until scoped broker access is integrated, this candidate must not open
  the inherited anonymous NATS WebSocket; display that limitation to the learner.

## Acceptance sequence

1. Boundary tests exercise destination/path restrictions, TLS errors, redirects,
   bounded input/output and server-selected credentials against recording peers.
2. Hosted Linux runs real Keycloak login, the HTTPS session server, the generated
   Spring position/history API and scoped PostgreSQL login. Check all three
   subjects, CSRF rejection, logout/replayed cookies and database effects.
3. Connect the generated Angular session/CSRF client, then validate authenticated
   order submission, cancellation and settlement with application consumers.
4. Add scoped broker issuance/mediation, expiry and reconnect/revocation checks.
   Anonymous browser NATS is not an accepted substitute.

The first two gates prove session-to-read-API integration. They do not prove
browser UI navigation, live order execution, provider key rotation, refresh,
deployment supervision or complete cumulative trading. The development provider
is disposable; learner deployment and production issuer requirements remain
separate. Hosted fixtures run sequentially with bounded memory and owned cleanup;
no screen sharing, local image pulls or changes to Citrix are required.

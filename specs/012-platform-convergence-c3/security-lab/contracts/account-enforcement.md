# Account-service authorization implementation slice

Opt-in generation derives an account-service candidate from the pinned C3 snapshot,
then applies canonical profile overlays. Earlier state templates/images stay unchanged.
This generated candidate always requires identity configuration; there is no permissive
runtime switch or missing-config fallback. It runs in the minimal development environment.

## Policy

- Accept only RS256 bearer access tokens validated by Spring Security/Nimbus against a
  configured RSA public key, exact HTTPS issuer, expected audience, required subject,
  issued-at and expiry. Require unexpired tokens and no future issued-at/not-before,
  with zero configured clock skew. The configured trust snapshot has a required expiry.
- Identity and entitlements come from server-owned configuration. For this single issuer,
  `subject=role:account,account` entries define read-only/trader/operator roles and exact
  account scope. Duplicate/malformed entries fail startup. Token role/account claims,
  username headers and URL parameters cannot grant scope. Operator has no implicit scope.
- GET account and accountuser lists are filtered by account scope. Detail checks happen
  before lookup; unauthorized IDs return 403 without exposing existence/content. The
  accountuser ID is the account ID, and the existing first-membership semantics remain.
  Unknown valid-token subjects receive 403, including on empty lists.
- POST/PUT and other methods are denied at the request policy before controller code,
  including membership writes and operator attempts. No provisioning endpoint is added.
- Only the exact health path is unauthenticated; other unlisted routes are denied.
  Sessions, form login, Basic Auth and cookie-based authorization are disabled. Browser
  cross-origin access is disabled for this development slice. CSRF is disabled only for
  this stateless bearer API; browser session integration requires its own CSRF design.

## Trust and evidence boundary

The first executable regression campaign uses an ephemeral test signing key, never
mounted in the application, with a public key and entitlement file mounted read-only.
This proves real API validation/authorization, not a live Keycloak login-to-API flow.
Local HTTP is bound to loopback; deployment TLS/gateway integration remains required.
Public-key/entitlement updates require process replacement. Dynamic key rotation,
issuer outage behavior, revocation, browser sessions, other services and trading
user-context propagation remain unaccepted. A compromised authorized process retains
its database role's legitimate grants; that is the later residual-authority exercise.

Tests pair allowed account/member reads with cross-account denials; filter both lists;
reject forged identity headers, unsigned/tampered/expired/wrong-issuer/wrong-audience
and wrong-algorithm tokens; reject writes for every role. Compare database accounts,
memberships and sequence state before/after denied actions through an independent
bootstrap observer. Reset synthetic state and repeat. Record sanitized outcomes and
source/JAR hashes, never signing secrets or bearer tokens. Full C3 trading stays a
separate integration gate before cutover.

## Reproduction

With C3 stopped and development/build preflight passing, use the lab Python
virtual environment (including the locked identity-fixture dependencies):

```bash
python scripts/security-lab/build_account_security.py
python scripts/security-lab/verify_account_authorization.py
```

The builder renders the pinned source into a private build directory, checks source
hashes, runs Java tests and produces a bootJar. The verification command replaces
only the owned `traderx-account-dev` composition, creates fresh public trust and
synthetic credentials, then runs two retained-container reset cycles. Its endpoint
is loopback port 18488 and is not exposed through the console tunnel. Private
signers and previous development inputs stay outside the repository. Evidence is
written to the runtime directory's `evidence/account-authorization.json`.

The older `account_dev.py verify` / `verify-reset` commands test the unprotected
baseline's write behavior and must not be used as acceptance for this protected
candidate. Use the authorization campaign instead. Stop the three containers when
finished with `account_dev.py down` before starting a full-C3 acceptance session.

For learners: predict which valid-token requests succeed, then compare filtered
lists and 403 responses with the independent database fingerprint. Explain why
these checks protect against an unauthorized caller but cannot constrain a fully
compromised process that already holds the service's SQL credentials.

## Real-provider integration and explicit key replacement

Run the existing TLS/PKCE identity fixture with `--sequential --account-api` twice,
using distinct private output directories. Full clusters must already be stopped.
The account candidate and its synthetic database remain in the lightweight composition.
The first run installs the verified provider public key with a one-hour trust expiry,
restarts the account process, and tests actual access tokens against the API. The
second disposable provider has a new signing key: replace trust explicitly, prove
an otherwise unexpired retired-key token is rejected, and accept new-provider tokens.
For this rotation experiment only, fixture access tokens last 15 minutes so rejection
can be attributed to the changed key rather than expiry. A retained token/public-key
pair is private runtime input; it must never enter repository evidence.

Stop the provider and demonstrate the documented offline-verification behavior:
already issued, unexpired access tokens continue to work within the trust window.
This is not immediate logout/revocation, automatic JWKS refresh, durable provider
rotation or a browser-session implementation. Check database state independently
before/after the HTTP campaign. Record these limitations with every result.

Example (lab Python environment, existing protected candidate required):

```bash
python scripts/security-lab/verify_identity.py --sequential --account-api \
  --output-dir /private/tmp/traderx-security-runtime/evidence/account-oidc-first
python scripts/security-lab/verify_identity.py --sequential --account-api \
  --output-dir /private/tmp/traderx-security-runtime/evidence/account-oidc-rotation
```

Run the two passes within 15 minutes; an expired retained token intentionally
fails the rotation proof. For a new campaign after expiry, archive the private
`identity-fixture/previous-account-token.json` outside the repository before the
first pass. The final provider is removed; its public trust remains in the local
candidate with finite expiry. Rerun the campaign to create fresh test identities.

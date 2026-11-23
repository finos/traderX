# Local browser session checkpoint

Implement a loopback HTTPS backend-for-frontend at `https://localhost:18447` for
this account-only learning slice. It is separate from the experiment-console login
and the inherited Angular trading frontend. Only the existing protected account
API is proxied; full C3/browser trading integration remains a later gate.

Use authorization code plus S256 PKCE, random one-use state, browser-bound pending
transaction cookie and nonce. Validate signed access and ID tokens against the
TLS-verified provider key snapshot, exact issuer/audiences, expiry, nonce and matching
subject. Never expose tokens, verifier, client secrets or provider passwords to page
JavaScript. Keep credentials in bounded in-memory stores; process restart invalidates
sessions. No refresh token storage: require fresh sign-in at access-token expiry or
five minutes, whichever occurs first. Pending login expires after two minutes.

Use `__Host-` Secure, HttpOnly, SameSite=Lax cookies with Path=/ and no Domain.
Rotate session identifiers on sign-in. GET does not mutate application data or log
out. POST logout requires the exact HTTPS Origin plus a per-session CSRF value;
expire the cookie and delete server state before responding. Logout is local only:
provider SSO and copied bearer tokens may remain valid. Validate exact Host, disable
CORS, prohibit framing and caching, and omit request URLs/tokens from logs.

The page explains current principal/account scope, offers account and membership
reads, and allows testing another synthetic account through the same API. The API
remains the authorization authority; the proxy must not substitute caller headers
or account choices for the signed token. Do not expose this fixture through ngrok.

Acceptance: complete real login through the backend callback, verify cookie flags,
filtered reads and cross-account denial; reject unsolicited/state-mismatched/replayed
callbacks and cross-origin/missing-CSRF logout; prove logout invalidates the prior
session, and unit-test expiry. Independently compare SQL state and remove the
provider/session server on completion. Protocol-level browser-cookie tests do not
claim manual Chrome usability or integration into the Angular trading frontend.

Run the protocol campaign with the lab Python environment and protected candidate:

```bash
python scripts/security-lab/verify_identity.py --sequential --account-api \
  --browser-session --output-dir /private/tmp/traderx-security-runtime/evidence/browser-session
```

The runner starts the HTTPS session server only while verifying the real provider
and removes it afterward. The same ephemeral localhost certificate is explicitly
trusted by the test client; system/browser trust is not modified. A persistent,
user-accessible deployment and certificate provisioning remain separate work.

Each role's protocol test uses a fresh browser cookie jar. The initial mixed-role
run completed reader checks but did not complete the next user's callback with
retained provider cookies. Account switching in a shared SSO browser profile is
therefore not accepted by this checkpoint. Local logout deliberately does not clear
cookies owned by the provider; the UI makes that limit visible.

## Persistent local browser runner

`browser_lab.py serve` keeps the pinned provider and HTTPS page alive beyond a test
campaign, for a bounded four-hour session by default (maximum eight). The runner
holds the lab operation lock so full-C3/build/fixture experiments cannot overlap.
It uses the existing three-container candidate and one 640 MiB provider; both full
clusters must be stopped. `browser_lab.py stop` verifies the recorded process
identity before graceful cleanup. Credentials are generated into a private runtime
file, never committed or injected into browser JavaScript.

The provider certificate is local and self-signed. Do not modify system trust or
silently disable TLS verification. Protocol clients trust only that certificate;
Chrome may require a per-site localhost certificate exception. No public tunnel is
added. The candidate's public-key snapshot lasts only for the bounded runner;
provider key material must remain unchanged. Refresh the browser verifier's same-key
snapshot over verified TLS; reject key drift rather than silently changing API trust.

Add a distinct CSRF-protected POST `/switch`: invalidate the local session, then
return a fixed Keycloak logout URL with `client_id` and the exact registered
`post_logout_redirect_uri`. No ID token goes into the URL. The user confirms logout
at the provider, then signs in as another synthetic user. This follows Keycloak's
[RP-initiated logout contract](https://www.keycloak.org/docs/latest/server_admin/index.html).
Local logout remains available separately and keeps its existing limited meaning.

Persistent runner commands (lab Python environment):

```bash
python scripts/security-lab/browser_lab.py serve --hours 4
python scripts/security-lab/browser_lab.py status
python scripts/security-lab/browser_lab.py stop
python scripts/security-lab/verify_browser_switch.py
```

`serve` stays in the foreground; keep it in a terminal/session. Its private status
file points to per-run synthetic credentials. The TLS key/certificate are retained
under the private `browser-tls` directory, so ordinary restarts preserve the certificate.
New certificates last seven days; an expired/soon-expiring certificate is an explicit
startup failure requiring renewal, never a silent trust change. `stop` removes the
owned provider and closes the HTTPS listener, leaving account development available.
No credentials are included in public evidence. Same-profile protocol verification
now passes with provider-confirmed switching; Chrome remains separately assessed.

# Isolated identity compatibility checkpoint

Scope: real Keycloak sign-in and a representative Python token verifier. This is
not account-service enforcement, browser session integration, or the live C3 issuer.

The bounded fixture runs Keycloak 26.8.2 pinned by manifest digest, with verified
localhost TLS and only loopback port 18446. It imports a disposable realm with
read-only, trader and operator users, independent random passwords and stable
synthetic subjects. Public client `security-lab-browser` permits only authorization
code with S256 PKCE and one exact callback. Password grant, implicit flow, service
accounts and user registration are disabled. No bootstrap administrator is created.

Acceptance: all three users complete the actual login form/code exchange; signature,
RS256, exact issuer, API audience, subject and required time claims are verified.
Reject missing/wrong PKCE, code reuse, alternate redirect, password grant and bad
password. Separately exercise cryptographically valid negative token claims using an
ephemeral test signing key: this tests the verifier, not provider compromise. Never
infer issuer or key URLs from an untrusted token. Bounded key snapshots expire and
unknown keys fail closed; provider rotation integration remains a later gate.

Account entitlements are a separate server-side issuer/subject mapping. Roles or
account IDs supplied in request headers, login names or token attributes cannot add
accounts. Operator has no implicit account grant. This fixture demonstrates the
mapping contract only; real list/detail/membership routes must still enforce it.

The provider uses development mode and disposable embedded storage for this
compatibility experiment. Its writable container layer is an explicit fixture
exception; no production issuer durability or hardened deployment is claimed.
Container is non-root, capability-free, limited to 640 MiB without swap (256 MiB Java heap), PID bounded and on a dedicated Docker
network. The fixture owns its container/network and removes them in finally, and
uses a nonblocking lock shared with the experiment console. It never exposes the
provider through ngrok or changes Kubernetes resources. Passwords, keys, sessions and
tokens stay in memory/private temporary files; evidence contains case outcomes and
image/source hashes only. A failed run cannot retain an earlier passed result.

Sources: [Keycloak container/import configuration](https://www.keycloak.org/server/containers),
[OIDC endpoints](https://www.keycloak.org/securing-apps/oidc-layers),
[PyJWT verification API](https://pyjwt.readthedocs.io/en/stable/api.html).

## Local capacity and recovery

On the current 6 GB Docker host, concurrent C3/provider startup exhausted available
headroom and did not reach the login tests. The second attempt left the daemon
unresponsive and required restart/manual fixture cleanup. These attempts are failed
setup evidence, not security outcomes. State 014 remains stopped with automatic
restart disabled.

The supported local invocation requires `--sequential`. While holding the shared
experiment lock, it verifies the exact kind container label, stops only the running
security-lab control plane, runs the disposable provider, removes that fixture and
restarts the control plane in finally. Application availability is interrupted for
this checkpoint. Data stays on the existing PVCs; the harness never reapplies the
reference manifests. A separate readiness/trading check is required after restart.
Concurrent operation and the final live identity deployment still need resource
sizing and combined acceptance; this mode makes no such claim.

Docker 28 internal networks did not expose the loopback-published port on this host. The fixture uses a dedicated ordinary bridge with only its HTTPS port published on loopback. It does not claim outbound network enforcement; C3 is stopped during the run.

## Recorded result

[2026-11-23 evidence](../evidence/2026-11-23-identity-provider.json): all 18 protocol/provider cases passed in sequential mode, followed by fixture cleanup and control-plane restart. Five verifier unit tests cover valid signed wrong issuer/audience/time claims, missing claims, unknown keys, unsigned/wrong-algorithm tokens, signature failures, bounded key snapshots and server-owned entitlements. Recovery readiness/trading is recorded separately.

[Recovery evidence](../evidence/2026-11-23-identity-recovery.json) confirms all 19 deployments ready and the complete inherited C3 trading smoke passed. The console and remote login page returned HTTP 200. No live account authorization or combined issuer deployment is implied.

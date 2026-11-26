# Packaged browser session runtime

This runtime serves the generated Angular candidate and the server-side session
boundary from one HTTPS origin. It is source packaging for the deployment
candidate, not proof of Kubernetes, gateway/WAF or cumulative trading acceptance.

## Configuration contract

Launch `python /app/scripts/security-lab/browser_runtime.py --config
/run/private/config/config.json`. The version-1 JSON file must be a regular,
non-symlink file owned by the runtime UID, with exactly mode 0600. The deployment
materializer copies projected Secrets into a private emptyDir before this command.

Required keys are `version`, `origin`, `issuer`, `client_id`, `audience`,
`listen_host`, `listen_port`, `certificate`, `key`, `ca_file`, `static_root`, and
`backends`. `origin` is a canonical HTTPS origin; `issuer` is an HTTPS Keycloak
realm URL. The listener is explicitly `127.0.0.1` or `0.0.0.0`, with a numbered
port. Certificate, key, CA and asset paths are absolute. Backend names and HTTPS
origins with explicit ports follow the API proxy's fixed allowlist; loopback HTTP exceptions are not
available in this command. No caller-selected upstream URL or anonymous prototype
account shortcut is exposed.

Optional `broker` contains `endpoint`, `ca_file`, `grants` and `identities`.
`grants` maps trusted subjects to arrays of numeric account IDs; `identities` maps
string account IDs to distinct `{user,password}` credentials. The existing
`BrokerEvents` adapter enforces bounded scopes and only supplies invalidations.
Its credentials stay inside the private configuration, never in static assets or
browser responses. Without broker configuration the notification endpoint fails
closed rather than falling back to anonymous NATS.

## Trust, serving and lifecycle

- JWKS comes only from the configured realm's fixed
  `/protocol/openid-connect/certs` endpoint over verified HTTPS. The initial
  approved signing-key set is pinned in memory. Periodic refresh may renew that
  same set's finite trust window; signing-key drift invalidates sessions and
  remains failed closed until restart. Transport failure does not extend trust.
- The server validates Host and CSRF Origin against its configured public origin;
  forwarded headers cannot override them. Its OIDC issuer, client, callback and
  audiences are instance configuration, not mutable module globals.
- Static files are preloaded under bounded file/count/total limits. Only generated
  bundles, public images/fonts, favicon, `assets/state-ui.json` and index/license
  assets are registered. Unknown paths, source maps, secret/config files, encoded
  paths, traversal and symlink assets are never served. SPA fallback is limited
  to the known TraderX routes.
- CSP permits scripts and connections only from the same origin. Inline scripts,
  event handlers and `unsafe-eval` are not allowed. Inline styles are explicitly
  permitted because Angular and AG Grid use dynamic style attributes; this style
  exception grants no inline-script permission. Production generation disables
  critical-CSS event handlers and uses root base href.
- Minimal `/health/live` and `/health/ready` endpoints expose only status. Readiness
  includes finite key trust and configured broker availability. SIGTERM/SIGINT
  close the HTTPS listener and broker adapter without printing private config,
  bearer tokens or provider responses.
- Accept raw sockets before starting TLS in one of at most 32 connection workers.
  TLS/HTTP idle reads time out after five seconds. Idle clients must not block the
  listener; shutdown closes tracked connections. Provider/backend calls and client
  writes occur outside the global session lock, so one slow upstream cannot hold
  health, session checks or logout behind it. Authorization and revocation remain
  atomic. A request authorized before logout may finish within its existing
  network timeout; subsequent requests must observe the revoked session.

Deployment probes must send the Host header from the public origin, including its
port when present. Health probes cannot override the normal Host boundary.

The original localhost account prototype remains the default `BrowserServer`
mode for existing fixtures. Configured deployment mode is explicit and disables
its hardcoded account backend. Local tests use temporary certificates and small
static fixtures; they do not start Docker or require screen sharing.

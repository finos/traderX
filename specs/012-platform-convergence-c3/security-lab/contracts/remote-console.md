# Temporary remote console access

User-authorized on 2026-11-22 for testing away from the desk. This overrides the
console's loopback-only access scope, not the prohibition on repository publication.

- Keep the console bound to 127.0.0.1:18081. Expose only the authenticated gateway
  on 127.0.0.1:18082 through ngrok HTTPS.
- Authenticate every console route at the local gateway using a unique temporary
  access code and server-side sessions. Store credentials privately, never in source,
  process arguments, evidence or logs. Disable ngrok request inspection.
- Explicitly configure one exact HTTPS public origin. Preserve local access and
  fail closed for any other Host or Origin, including spoofed forwarded headers.
  Remote POST requires exact public Origin and the existing per-process CSRF token.
- Keep the fixed action catalog, serial runner, evidence allowlist and bounded inputs.
  The reference TraderX link is local-only; do not proxy operator/application routes.
- Verify unauthenticated/wrong-password access fails, authenticated assets/state work,
  cross-origin and missing-CSRF submissions fail, and a real remote experiment passes.
- Record local process identifiers and shutdown instructions. Access lasts only while
  the Mac, console and tunnel run; there is no production availability claim.

## Browser sign-in revision

Repeated Chrome Basic Auth prompts were reported despite successful authenticated
HTTP probes. Replace browser Basic Auth with a dedicated loopback gateway on 18082:
password form, eight-hour opaque server-side sessions, Secure/HttpOnly/SameSite=Strict
host-only cookie, exact Host/Origin checks and bounded/rate-limited login requests.
Only authenticated requests are forwarded to console 18081. No WWW-Authenticate
challenge, password in URLs or persistent browser storage. Tests must verify the
cookie boundary and wrong/missing credentials before removing edge Basic Auth.
Keep request inspection disabled. This changes the console access mechanism, not
application OIDC or business authorization claims.

The sign-in form uses Referrer-Policy same-origin so browser form POSTs retain the
required Origin. Cross-origin and null-Origin login requests are rejected.

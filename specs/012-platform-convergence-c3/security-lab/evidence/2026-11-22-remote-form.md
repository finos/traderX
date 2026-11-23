# Remote form sign-in

Browser Basic Auth was replaced after the user reported repeated Chrome prompts;
passing HTTP-client Basic Auth checks did not establish browser usability.

Actual browser sign-in to the HTTPS /login form succeeded and the telemetry
experiment dfa19ac2-8abb-41a0-a5da-88d7d81fa838 passed in that signed-in session.
Screenshot: private runtime remote-browser-passed.png. No username is required.

The gateway on loopback 18082 enforces an opaque eight-hour server-side session
before forwarding to console 18081. Cookies are Secure, HttpOnly, SameSite=Strict
and host-only. Wrong/missing credentials, wrong Host/Origin and excess login attempts
are rejected; the console additionally checks CSRF. ngrok request inspection remains
disabled. No credentials appear in source, URLs, artifacts or gateway logs.

Browser testing found that no-referrer turns a form POST Origin into null. The
sign-in page uses same-origin referrer policy while still rejecting null or foreign
Origin. See [MDN Referrer-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy).

Temporary single-user lab access only; restarting the gateway clears sessions.
This sign-in does not implement TraderX application OIDC or business permissions.

Remote SQL experiment `c104a508-6853-4fd1-8c34-b42abc9a7db4` also passed through form-cookie authentication; evidence download, anonymous/wrong-code rejection and CSRF/Origin denials were verified.

# Learner onboarding and HTTPS

Status: unified local commands are implemented for the current macOS arm64 / Python
3.14 environment. Existing-workspace validation is tracked below; fresh-machine and
additional-platform acceptance remain open. Hosted deployment remains planned.

## Two audiences

For contributors running this lab locally, provide a guided, one-time development
certificate setup followed by one start command, one browser URL and an explicit
stop/reset workflow. Prefer a machine-local development CA such as
[mkcert](https://github.com/FiloSottile/mkcert), or an organization-approved equivalent.
Explain that installing a development CA changes trust beyond a single certificate;
ask explicitly before doing so. Do not describe a normal mkcert root as restricted
to localhost. Generate leaf certificates for localhost/loopback only. Never share,
commit or put CA private keys into containers, evidence or workshop downloads.
Mount only the necessary server leaf certificate/key. Keep TLS verification enabled
for backend clients and provide their explicit CA trust configuration.

For workshop attendees who only want to try exercises, prefer a hosted URL with a
publicly trusted certificate and ordinary sign-in. No participant certificate
installation should be required. Provide isolated synthetic data/evidence and
bounded experiment execution per learner; establish quotas, cleanup and exposure
controls before allowing assumed-compromise/CVE scenarios. The current local fixture
must not be made public merely by changing its bind address or opening a tunnel.
Corporate devices that prohibit local trust installation should use this hosted
path or an organization-approved development environment.

## Proposed local experience

1. Setup checks Docker availability, available memory, port conflicts and existing
   labs. Default to the small account/identity profile; full C3 is an explicit mode.
2. Explain and request the one-time trust change. Detect an existing approved CA;
   generate/reuse leaf certificates, and verify both browser and backend TLS trust.
3. Start the pinned bounded profile; wait for readiness and open one URL. Provide
   synthetic credentials privately and explain reader, trader and operator roles.
4. Show prerequisites and verified active controls for each experiment. Pair allowed
   actions with denials, reset the synthetic state and download sanitized evidence.
5. Stop releases lab resources. Reset replaces only owned synthetic data. A separate
   uninstall explains removal of lab-specific trust; never remove another project's
   shared CA automatically.

Acceptance requires a clean-machine contributor walkthrough on supported platforms,
a usable Chrome login/switch/logout flow, accurate memory estimates, clear recovery
for expired certificates/occupied ports, and no browser security-warning bypass.
Certificate renewal reuses the approved local CA rather than repeatedly asking users
to approve unrelated self-signed leaf certificates. Production/shared deployment
uses a separately reviewed TLS and identity configuration, not development trust.

## Current Mac compatibility finding

The current self-signed lab certificate was explicitly approved by the user.
macOS SSL trust with `policyString=localhost` verifies in the native verifier, but
Chrome rejects it: Chromium skips hostname-constrained macOS trust entries.
[Chromium implementation](https://chromium.googlesource.com/chromium/src/+/refs/tags/130.0.6723.16/net/cert/internal/trust_store_mac.cc).
Normal SSL trust for the exact approved certificate is a different configuration;
record it accurately instead of claiming a browser-enforced hostname trust scope.
This illustrates why one-off manual certificate acceptance is not the proposed
learner onboarding experience.


## Current unified commands

From the repository root:

```bash
scripts/security-lab/traderx-lab doctor
scripts/security-lab/traderx-lab setup
scripts/security-lab/traderx-lab start
scripts/security-lab/traderx-lab status
scripts/security-lab/traderx-lab stop
scripts/security-lab/traderx-lab reset --confirm-reset
```

Setup creates a user-cache virtual environment and installs hash-locked identity
harness dependencies. `TRADERX_LAB_VENV` can select an existing verified environment.
Current support is deliberately limited to macOS arm64 with Python 3.14, Java 21,
Docker Desktop and the pinned generated C3 Git snapshot available locally. Doctor
reports missing prerequisites/capacity rather than claiming compatibility elsewhere.

Existing trusted certificates are preserved. With mkcert installed, explicit
`setup --install-ca` permits its development-CA trust change; plain setup does not
install a CA. Only the CA public certificate is copied into runtime trust inputs.
An organization may instead provision approved `cert.pem`, `key.pem` and `ca.pem`.
The current machine continues using its already approved self-signed certificate;
no additional CA was installed to test the launcher.

Setup builds the canonical candidate and runs the local authorization campaign when
those artifacts do not exist. Existing artifacts must match their source/JAR/input
hashes. Start waits for readiness, returns one URL and the private synthetic-credential
file location, and keeps the bounded runner alive in the background. A running owned
instance is reused. Stop shuts down the provider/session server and stops the three
owned account containers; restart resets tmpfs data. Reset explicitly discards owned
synthetic data and restarts with new provider credentials, preserving TLS and evidence.
Runtime-directory collisions and reused process IDs are rejected.

This is an initial workflow, not clean-machine release acceptance. The mkcert branch,
first-time candidate build from a fresh clone, dependency bootstrap, other platforms,
certificate renewal/uninstall and full-C3 mode still need their acceptance campaigns.
Use state-readiness.md for the publication gates rather than treating launcher success
on the development machine as a release verdict.

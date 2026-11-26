# Runnable Python application image checkpoint

S019-06a3a packages the browser/session and two event-delivery roles. It is a
bounded step toward the integrated eight-role deployment. Java read/trading APIs,
the operator .NET API, dependency provisioning, signed provenance and complete
State 019 acceptance remain separate requirements.

## Requirements

- RIMG-01: Resolve and pin the actual Python base manifest and distribution wheel
  hashes. Hosted image builds install dependencies offline from verified wheels.
  No floating image, package version or invented application digest is accepted.
- RIMG-02: Build contexts contain only explicit runtime source files, selected
  hashed wheels and approved compiled public Angular assets. Do not copy a whole
  checkout, local credentials, tests, development orchestration or node_modules.
- RIMG-03: Run as UID/GID 10001 with the existing private materializer, exact
  per-role Secret-key inventory and an explicit role launcher. Application
  configuration stays outside the image and Docker build arguments/environment.
- RIMG-04: Browser configuration requires a reachable HTTPS listener, fixed
  trusted origins and immutable static root. Delivery roles require their exact
  worker mode and verified TLS database/broker connections. The loopback database
  fixture exception is prohibited by the container launcher.
- RIMG-05: Verify exported OCI bytes using the integrated compiler before emitting
  a workload fragment. Declaration labels bind the same source manifest and
  private interface; they do not establish signature trust or runtime behavior.
- RIMG-06: Hosted runtime smoke must exercise a real image under tokenless,
  non-root, dropped-capability, read-only-root constraints with only bounded
  writable temporary/config mounts. Report actual checks and omissions. An image
  build or `--help` response alone is not application acceptance.

## Boundaries

Only Linux AMD64 CPython 3.14 is supported by this first packaging contract.
The base and wheels are pinned in `runtime-images.lock.json` from official Docker
registry and PyPI release metadata. The browser contains the built Angular output
from the protected consumer generator, not the original anonymous C3 frontend.
Its optional broker configuration remains optional for the bounded HTTPS/static
startup smoke; cumulative deployment requires configured authenticated broker
subscriptions and a live readiness result including that dependency.

Gateway-to-identity routes, browser-reachable issuer naming, price-publisher
broker credentials, verified HTTPS reference/pricing services and the remaining
five application image adapters are unaccepted composition gaps. No image is
published and no cluster is activated by the packaging compiler.

## Build and inspection interface

The hosted job first generates, tests and builds the protected Angular consumer
using `render_application_consumers.py` and its normal frontend build. It then
fetches only the reviewed dependency wheels:

```bash
TRADERX_LAB_ISOLATED_LINUX=1 python scripts/security-lab/runtime_images.py fetch-wheels \
  --output "$RUNNER_TEMP/runtime-wheels"
python scripts/security-lab/runtime_images.py prepare \
  --role browser-session --wheelhouse "$RUNNER_TEMP/runtime-wheels" \
  --frontend-root "$RUNNER_TEMP/security-frontend" \
  --source-commit "$GITHUB_SHA" --output "$RUNNER_TEMP/browser-context"
```

For `event-publisher` and `event-consumer`, omit `--frontend-root` and use distinct
context directories. The compiler validates generated frontend source hashes and
copies only the `PublicAssets` registry from `dist/main-application/browser`.
This ties inputs to the current generator; signed builder provenance remains a
separate requirement. Unrecognized assets, source maps, local configuration,
source trees and build dependencies are not copied into the final image.

Each context contains its exact Dockerfile, source allowlist, dependencies and
`image-build.json` hash inventory. The metadata inventory itself is excluded from
Docker's context by `.dockerignore`. Do not add arbitrary files or change the
Dockerfile after preparation. Dependencies install using `--no-index`,
`--require-hashes`, `--no-deps` and a fixed wheel inventory. The final stage copies
installed packages, not wheel archives. Application source/static file modes are
explicitly readable by UID 10001 even if the host uses umask 077.

The parent CI job creates a uniquely named docker-container BuildKit builder with
`buildkit.reference` from the lock, without changing the default builder. Build
one role at a time with `--platform linux/amd64 --network none --provenance=false`
and two local exports: `type=oci,dest=<role>.oci.tar` and
`type=docker,dest=<role>.docker.tar`. The registry pull of the digest-pinned Python
base happens on that hosted runner; build-step networking remains disabled.
BuildKit is separately privileged build infrastructure, never an application
workload or a namespace-policy exception. The owned builder is removed afterward.

After extracting the OCI archive safely into a fresh directory, verify it:

```bash
python scripts/security-lab/runtime_images.py inspect \
  --role browser-session --layout "$RUNNER_TEMP/browser-oci" \
  --image-name traderx-local/browser-session --source-commit "$GITHUB_SHA"
```

The resulting workload fragment includes the actual single-platform OCI manifest
digest, verified local layout and fixed private Secret-key inventory. OCI
config/layer descriptors are checked by `integrated_deployment.image`; the
packaged command must additionally match `runtime_images.argv(role)` exactly.
The Docker archive loaded for runtime smoke must have the same image config
digest as that verified OCI export. A local reference is not a published image.
The complete deployment compiler still refuses a three-role contract: all eight
verified protected application roles are required before staging that bundle.

## Private startup contract

| Role | Projected keys | Launcher restriction |
| --- | --- | --- |
| `browser-session` | `ca.pem`, `config.json`, `tls.crt`, `tls.key` | `0.0.0.0:18447`; `/app/static`; exactly account/position/matcher/reference/pricing backend origins |
| `event-publisher` | `broker-ca.pem`, `config.json`, `database-ca.pem` | `mode=publisher`, `database_transport=verify-full` |
| `event-consumer` | `broker-ca.pem`, `config.json`, `database-ca.pem` | `mode=reference-consumer`, `database_transport=verify-full` |

The immutable image entrypoint invokes `/opt/traderx/private_materializer.py`,
copies those keys from `/run/projected` to `/run/private/config`, then runs
`/opt/traderx/runtime_launcher.py --role <role> --config
/run/private/config/config.json`. The launcher requires UID and GID 10001 and
refuses alternate config/TLS/static paths. Existing browser and delivery parsers
validate the complete private configuration before their services start. Browser
broker trust, when configured, uses the materialized `ca.pem`. All API origins
are HTTPS with explicit ports; the exact service names are `account-service`,
`position-service`, `order-matcher`, `reference-data` and `price-publisher`.

Configurations and TLS private keys are injected at runtime; no private byte is
included in a build command, build argument, image environment or public evidence.
Projected files are root-owned or workload-owned and group-readable at most.
Materialized copies are same-UID regular 0600 files inside a 0700 directory.
Secret changes require a fresh private volume/Pod as defined by the materializer.

The hosted smoke supplies an isolated synthetic TLS/JWKS provider, proves actual
verified HTTPS readiness and static serving from the built browser image, and
checks boundary rejections. Worker image startup checks prove private config and
role restrictions only. Live broker/SQL delivery from these packaged worker images
remains an additional gate; source-process delivery tests do not establish it.

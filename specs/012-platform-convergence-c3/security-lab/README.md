# TraderX Security Lab (experimental C3 profile)

This is an experimental foundation with live platform checks, **not a hardened C3 deployment or a compliance claim**. See [specification](spec.md), [plan](plan.md), [tasks](tasks.md), [trust boundaries](system/trust-boundaries.md) and [research](research.md).

From the repository root:

```sh
python3 -m venv /tmp/traderx-security-lab-venv
/tmp/traderx-security-lab-venv/bin/pip install -r scripts/security-lab/requirements.txt
git fetch origin code/generated-state-012-platform-convergence-c3
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/lab.py inventory --output /tmp/security-lab-inventory.json
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/lab.py render-network --output /tmp/security-lab-network.json
/tmp/traderx-security-lab-venv/bin/python -m unittest discover -s scripts/security-lab -p 'test_*.py' -v
```

Commands are anchored to the script's repository, independent of the caller's working directory. Inventory reads the locked Git object, not the current generated branch tip. Network output targets `traderx-security-lab` only and is a review candidate. It does not include deployments, gateway access, telemetry allowances, or CNI installation; applying it to arbitrary C3 workloads can interrupt traffic. There is deliberately no automatic apply command.

Validate externally collected scenario results with `lab.py validate-evidence --input result.json`. See [evidence contract](contracts/evidence.md). Passing structural validation proves only that evidence fields are consistent, not that observations are genuine or a control is effective.

The snapshot source (`ca0f6642`) predates the fresh main checkout (`83cc57b6`). Preserve both pins; regenerating from fresh main is a different baseline and requires a new inventory and lock. All 20 workload image digests are now recorded in `runtime-images.lock.json`. Published application images are AMD64; this ARM64 host uses emulation. Do not generalize its performance or runtime-hook results to a native AMD64 deployment.

## Isolated runtime preparation

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/prepare_runtime.py --output-dir /tmp/traderx-security-runtime
kind create cluster --name traderx-security-lab \
  --config specs/012-platform-convergence-c3/security-lab/system/kind.yaml \
  --kubeconfig /tmp/traderx-security-runtime/kubeconfig
helm upgrade --install cilium cilium/cilium --version 1.20.5 \
  --namespace kube-system --kubeconfig /tmp/traderx-security-runtime/kubeconfig \
  --set ipam.mode=kubernetes --set operator.replicas=1 \
  --set kubeProxyReplacement=false --wait --timeout 180s
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_platform.py \
  --kubeconfig /tmp/traderx-security-runtime/kubeconfig \
  --output-dir /tmp/traderx-security-runtime/evidence
```

Install Helm from its official release and configure `helm repo add cilium https://helm.cilium.io` first. The lab uses localhost port 18080, its own kubeconfig and a pinned kind node. Do not create a second cluster with the same name. The platform verifier requires that exact lab context/node and uses only its `security-platform-check` namespace. It resets its own network policies, runs positive/negative traffic checks, and submits an unsafe pod only as an admission server dry-run. Probe pods remain available for inspection.

`prepare_runtime.py` reads canonical manifests from the pinned Git object and applies isolated namespace (including the Vector log selector), local-port CORS origin and image-reference transformations. Outputs retain reference C3 demonstration credentials and must stay outside source control; these are not hardened manifests. It reuses committed image pins instead of moving tags. The resulting `reference.json` has not itself passed the full C3 acceptance suite until recorded in run evidence.

For the verified reference deployment, use `bash scripts/security-lab/start-reference.sh` followed by `bash scripts/security-lab/test-reference.sh`. Set `TRADERX_SECURITY_HELM` to an installed Helm binary if it is not on PATH. Optional `TRADERX_SECURITY_RUNTIME` and `TRADERX_SECURITY_PYTHON` override the private runtime directory and Python virtual environment. The starter creates/reuses only the named lab cluster, installs the pinned CNI, preloads images with explicit platforms, and applies reference manifests. The test wrapper supplies the snapshot layout to the canonical C3 smoke suite and records its log. These scripts do not stop other clusters automatically.

## WAF compatibility fixture

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/prepare_waf.py --runtime-dir /tmp/traderx-security-runtime
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_waf.py --runtime-dir /tmp/traderx-security-runtime
```

This ARM64 Docker Desktop fixture builds from the pinned Envoy base and hash-verified Coraza release. A harmless Python backend runs on an internal network; only the proxy binds localhost port 18443. A short-lived local test certificate is verified by the client, never installed into system trust. The harness changes only WAF mode, checks query/JSON rejection and backend receipt, and removes its labelled test containers afterward. Certificates expire after two days; use a fresh runtime directory for a later run. It does not route or harden C3 traffic and proves no application exploit. See [live results and limitations](evidence/2026-11-22-live-baseline.md).

## Local experiment interface

Start from the worktree root with:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/console.py
```

Open http://127.0.0.1:18081. The console runs the ten implemented bounded checks, preserves run history and exports evidence. WAF preparation automatically rebuilds its pinned local image if needed. Only one experiment runs at a time. The reference deployment remains at http://127.0.0.1:18080.

The interface reuses the docs portal's canonical TraderX horizontal SVG and favicon directly. It clearly labels the deployment as a reference profile with hardening in progress. See [console contract](contracts/console.md) and [verification](evidence/2026-11-22-console.md).

## Staged business-service hardening

The opt-in workload profile targets eight business services. It leaves the reference
manifest and database deployment intact. Apply it only to the dedicated lab:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/apply-workloads.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_workloads.py --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

The apply command shares the console's experiment lock and waits for application
HTTP readiness between deployments. Expect brief per-service downtime; no extra
replicas are started. `--rollback` removes this slice's named admission policy and
restores only its eight reference Deployments. Dedicated accounts remain inert.
Do not use the full reference starter as a rollback: admission intentionally rejects
unrestricted updates to protected deployment names.

The console's **Inspect live service restrictions** experiment verifies the active
profile without redeploying it. Its evidence includes live process restrictions,
Kubernetes permission denials, unsafe-update admission denials and filesystem
outcomes. Passing this check does not establish full namespace or database/broker
security. See [workload contract](contracts/workloads.md).

## Supporting-service profile

Apply the next slice with:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/apply-workloads.py --profile support
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_workloads.py --profile support --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

This hardens the gateway, static frontend, API docs, NATS, blackbox exporter and
OpenTelemetry collector. It also installs direct-Pod/debug admission for protected
business/support labels or service accounts. Both-label-and-identity renaming is
outside this incremental scope; namespace-wide admission remains open.

`--profile support --rollback` removes only this slice's admission policies and
restores its six reference Deployments plus the API-docs Service target port. It
removes the direct-Pod policies for both groups while preserving the earlier
business Deployment policy. Rolling back business separately also removes its
Pod policy so restoration is possible. No database/stateful deployment is touched.

The **Inspect gateway, UI & broker restrictions** console experiment runs the
bounded verifier without applying or rolling back resources. Non-root NATS does
not establish broker authentication/authorization; that remains a separate task.

## PostgreSQL migration and recovery check

The reference database uses emptyDir. Do not replace that Pod to harden it without
first preserving its data. The migration command stops business writers, verifies
and retains a private backup, migrates to a local PVC, restores all tables, tests
Pod-restart persistence, and returns each business service to its prior replica count:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/migrate-database.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_workloads.py --profile database --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

Migration causes temporary application downtime and shares the console's experiment
lock. Its private dump and phase record live in the runtime's `database-migration/`
directory, outside source control. If interrupted, inspect the recorded phase and
correct the cause before invoking `--resume`; a verified backup is never overwritten.
Do not manually resume business writers when restoration has not been verified.
A completed migration is a no-op when invoked again. The console's database
experiment is verification-only: it does not trigger migration, restore or restart.

The PVC survives Pod replacement, not kind-cluster deletion or host loss. Keep the
private backup. Reverting to the reference emptyDir manifest is not a safe rollback.
Current SQL identities still retain their reference privileges; least-privilege
roles and credential rotation are a separate milestone.

## Collector exception and namespace admission

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/isolate-collector.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_collector.py --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

Cutover first verifies existing log delivery and archives the old collector's
checkpoint directory privately. It starts the pinned collector in
`traderx-security-infra`, stops the old collector, then requires a fresh log marker
in Loki before removing the old identity binding and labeling the application
namespace Baseline v1.35. The new collector starts fresh offsets; duplicate replay
can occur. Loki and other data stores are not restarted. An already recorded
complete cutover is a no-op; use the verifier to assess current state. An incomplete
cutover requires inspecting its retained phase and correcting the cause; it is not
an automated rollback/restore exercise. If the post-cutover log probe fails, the
script restores the old DaemonSet before any Baseline namespace label is applied.

The infrastructure namespace permits only the pinned collector configuration under
fail-closed custom Pod admission. Root, a read-only host log mount and an explicit
short-lived API token are deliberate exceptions. Pod/node/namespace API reads are
read-only but include Pod specifications, not merely metadata. The host log mount
contains other node Pod logs too; the application-namespace filter is collection
scope, not a confidentiality boundary against a compromised collector.

The console's **Inspect namespace & collector boundary** experiment verifies
namespace admission, collector restrictions, identity permissions and fresh Loki
receipt. After the following storage migration, it checks twelve Restricted
rejections, including unrelated-name root Pods. Old Baseline results remain labelled
as historical. Restricted alone does not mandate read-only roots, resource bounds
or token suppression; our named-workload policies additionally enforce those.

The lab smoke wrapper directs the inherited collector readiness check to the new
namespace. Other states retain their original collector-namespace default.

## Observability preservation and Restricted admission

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/migrate-observability.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/enforce-restricted.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_workloads.py --profile observability --output-dir /tmp/traderx-security-runtime/evidence
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_collector.py --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

See [the storage contract](contracts/observability-storage.md). Each store is briefly
paused for a private checkpoint, stopped, restored onto its own 2Gi PVC, verified
file-by-file, then started as UID/GID 10001 with an explicitly mounted data directory
and read-only root. The ARM64 helper uses the pinned platform-fixture image. The
checkpoint is local and crash-consistent; ingestion gaps and replay may occur.
Grafana dashboard UIDs, a fixed-time Prometheus vector, an existing Loki marker and
Tempo trace span IDs are checked after cutover. Backups stay outside the repository.

An interrupted run requires inspecting `observability-migration/state.json` and
passing `--resume`. Never delete or reset that ledger to retry. Phases preserve
verified copies; once a service has started on its PVC, resumption never restores an
older checkpoint over it. An ambiguous captured-but-not-quiesced state requires
manual review. Completed migration is a no-op. Local PVCs survive Pod replacement,
not cluster deletion or host loss.

`enforce-restricted.py` verifies all nineteen reviewed Deployment templates and
readiness, checks namespace admission dry-run warnings, then enables Restricted
v1.35. The infrastructure collector remains separately constrained. The console's
**Inspect telemetry storage & restrictions** experiment verifies current processes,
bound PVCs, admission and the historical cutover record without restarting stores.
SQL/NATS authorization, full network segmentation, gateway integration, image trust
and runtime protection remain separate roadmap work.

## Temporary remote testing

The user-authorized ngrok endpoint exposes an authenticated loopback gateway on
18082, forwarding signed-in sessions to console 18081. The new `/login` form needs
an access code only, with no browser Basic Auth prompt. Eight-hour sessions use
Secure, HttpOnly, SameSite=Strict host-only cookies; restart the gateway to revoke
all sessions. Login attempts are bounded/rate-limited; exact Host/Origin and console
CSRF checks remain in force. The console still accepts only its configured public
origin. All ten console experiments use this one URL; TraderX itself stays local.

Private runtime `remote-console/form-credential.json` stores the access code.
Never commit it or include it in evidence. Start the gateway before the tunnel:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/remote_gateway.py --origin https://<assigned-host> --credential-file /private/tmp/traderx-security-runtime/remote-console/form-credential.json
ngrok http http://127.0.0.1:18082 --url https://<assigned-host> --inspect=false
```

Private `remote-console/processes.json` records the current process IDs. Stop its
ngrok process to close remote access. Restart the console without `--public-origin`
to remove the public origin allowlist. Idle-sleep inhibition is tied to the tunnel
PID; closing the Mac lid, network loss or stopping Docker can interrupt tests.
Basic Auth is superseded: previous CLI HTTP checks passed, but the user reported
repeated Chrome challenges. The replacement was verified through actual browser
sign-in and a successful experiment, not only an HTTP client.

## Scoped SQL identities

See [database-permissions.md](contracts/database-permissions.md). Canonical commands:

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/migrate-database-permissions.py
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_database_permissions.py --output-dir /tmp/traderx-security-runtime/evidence
bash scripts/security-lab/test-reference.sh
```

The migration acquires the experiment lock, records private configuration/grants and
a logical checkpoint, creates four restricted roles, applies Secret-backed runtime
credentials and rolls out one service at a time. Matcher runtime DDL is disabled.
It rotates the known bootstrap password, moves it into a database-only Secret and
restarts that workload on its existing PVC. Exact environment/credential admission
then protects Deployments and protected Pods. Resume an incomplete run only after
inspecting `database-permissions/state.json`, using `--resume`; never restore the
checkpoint over newer trades as a retry. Completed migration is a no-op.

The ninth experiment uses real TCP SQL logins, checks all table privileges, runs
allowed rollback-only synthetic operations, verifies SQLSTATE 42501 failures and
actual JDBC roles, and rejects credential/DDL regressions in admission. Account
sequence allocation is not transactional and advances once per run. Service grants
do not establish initiating-user account authorization. Position-service runtime credential rotation and bootstrap password retirement are
separately verified; other runtime identities were not rotated in this exercise.

## Runtime credential rotation

```sh
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/rotate-database-credential.py
```

This serialized exercise targets position-service only. It records original Pod and
JDBC backend identities, changes the role password, rejects a fresh login using the
retired password, updates its Secret and replaces the Pod. Established connections
can survive a password change: the recorded run observed ten old JDBC sessions,
then verified all ten drained after the rollout. A no-surge restart can briefly
interrupt position reads. Full SQL and trading suites run before completion.

Interrupted runs preserve mode-0600 `database-rotation/private-state.json` and require
review plus `--resume`; the recorded new credential is reused. Completed rotation is
a no-op. The console SQL experiment displays historical rotation evidence and
rechecks retired-password rejection without rotating again. Only explicitly
allowlisted fields enter `rotation-result.json`; private passwords never enter the
console or repository. The data is local evidence, not an immutable audit record.

Next NATS work is specified in [nats-authorization.md](contracts/nats-authorization.md),
including the slash-versus-dot subject compatibility boundary. It is not yet applied
to the C3 broker.

## Learning and follow-on state

See [learning objectives and assessments](learning-objectives.md) and the [planned CVE/OSERA patch-analysis exercise](contracts/cve-patch-analysis.md). CALM is a separate follow-on state that compares bolt-on and model-first workflows using the same security checks.

## Isolated NATS authorization experiment

Install the protocol client into the console environment:

```bash
/tmp/traderx-security-lab-venv/bin/pip install --require-hashes -r scripts/security-lab/requirements-nats.txt
```

Choose **Test messaging permission boundaries**. Its 28 checks compare TLS and WSS delivery, authentication, publish/subscribe permissions and reconnects. Download evidence for exact outcomes, pinned broker image and limitations. The synthetic identities are not real user login; live C3 broker authentication remains pending. CLI and console fixture invocations share an exclusive fixture lock. Disposable credentials/certificates and the owned broker/network are removed after each run.

### Price-publisher credential compatibility (staged)

The canonical price-publisher template supports opt-in Secret-file credentials.
Set `NATS_SECURITY_REQUIRED=true`, `NATS_ADDRESS=tls://<broker>:4222`, and absolute
paths for `NATS_USER_FILE`, `NATS_PASSWORD_FILE`, `NATS_CA_FILE`. Partial settings,
URL credentials and plaintext secure-mode addresses fail before connection. The
CA must verify the broker hostname. Credentials load at startup; rotate via rollout.
With no security settings, the existing anonymous reference configuration remains.

Before image rebuild/cutover, prepare a private copy of the canonical
`templates/state-010-pricing-awareness-market-data-overlay/price-publisher` tree,
install its locked dependencies with `npm ci --ignore-scripts`, and run `npm test`.
Then run the isolated real-client compatibility check:

```bash
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_nats.py \
  --node-publisher-dir /absolute/path/to/prepared-price-publisher \
  --output-dir /private/tmp/traderx-security-runtime/evidence/nats-node-client
```

The harness rejects source/lock drift, verifies actual price delivery, and checks
wrong-password and untrusted-CA startup rejection. It also reruns the 28 protocol
cases. This does not rebuild or deploy application images, add Java client hooks,
issue browser credentials, or authenticate the live C3 broker.

### Java client credential compatibility (staged)

The State 006/009 renderers now install the shared canonical Java security helper
into trade-service, trade-processor and order-matcher. All five Java connection
sites accept the same Secret-file variables as the price publisher. Set the
service's effective `nats.address` to its verified TLS broker hostname. Startup
reads credentials; a Secret update alone does not rotate an existing connection.

Run the real JNATS compatibility checks against the isolated fixture using the
pinned `jnats-2.20.5.jar` and Java 21 installation:

```bash
/tmp/traderx-security-lab-venv/bin/python scripts/security-lab/verify_nats.py \
  --java-client-jar /absolute/path/to/jnats-2.20.5.jar \
  --java-home /absolute/path/to/java-21-home \
  --output-dir /private/tmp/traderx-security-runtime/evidence/nats-java-client
```

The harness compiles the helper/probe, tests six publish/subscribe flows and three
negative connection cases, then runs the 28 broker checks. A trusted certificate
for the wrong hostname must fail during TLS. Evidence hashes the JNATS artifact
and helper/probe sources. All three service source trees have also passed
`compileJava` against the pinned C3 snapshot in private build directories. These
are compatibility results, not proof of application reconnect, credential rotation,
settlement or a completed live broker rollout.


### Publisher reconnect, rotation and local image

The `--node-publisher-dir` check now also restarts the isolated broker, verifies a
fresh price from the same application process, rotates its password, checks explicit
retired-login denial, updates the private credential file and replaces the publisher.
It verifies a fresh price and health after replacement. It deliberately disconnects
all broker sessions; it does not establish password reload behavior on existing
sessions or uninterrupted market-data delivery.

Build the local candidate with `scripts/security-lab/build_nats_publisher.py` using
the lab Python environment. This is a complete locked-dependency build from the
pinned Node base in `generation/price-publisher.Dockerfile`, since canonical
package dependencies differ from the reference C3 snapshot. Build output is private
runtime `evidence/nats-publisher-image.json`; the local image config ID is not a
registry manifest digest. No image is pushed or deployed by this command.

Pass that config ID to `verify_nats.py --node-image sha256:<local-config-id>
--output-dir <private-evidence-dir>` to verify the container against the isolated
broker. The candidate shares only that fixture's network namespace, mounts only
its own credential and CA files, and runs read-only without capabilities. Live
trading, signed image admission and Java application lifecycle remain separate gates.

### Actual Java adapter lifecycle and candidates

Prepare private service trees from the pinned C3 snapshot, apply the canonical
State 006/009 runtime overrides and shared NatsSecurity.java helper, then run each
service's Gradle wrapper with Java 21:

```bash
./gradlew -I /absolute/path/to/scripts/security-lab/java-lifecycle.init.gradle \
  labLifecycleClasspath bootJar --offline --no-daemon
```

The init script writes each build's resolved test runtime classpath without changing
its canonical build file. `verify_nats.py --java-service-builds <private-parent>
--java-home <java21-home> --output-dir <evidence-dir>` tests the three real publisher
classes and two subscriber classes. The matcher uses a mocked domain callback;
no synthetic trade reaches a real database. Each adapter must deliver a unique
marker after reconnect and after credential-file update/process replacement.
Disconnected-status regression probes run for publishers and the processor
subscriber. The corrected status checks compare exact enum names.

`build_java_candidates.py` consumes the passing five-case lifecycle evidence at
private runtime `evidence/java-adapter-lifecycle/nats-result.json`, rejects source
or bytecode drift and packages the three bootJars using the pinned JRE recipe.
Candidate config IDs and JAR/source hashes go to `evidence/java-candidate-images.json`.
Non-root/read-only container checks verify JAR hashes and Java runtime startup.
This does not start full Spring contexts, push images, change admission, or roll out
the services. Database-backed settlement and user/browser identity are still gates
before a live broker cutover.

### Candidate compatibility rollout in the existing lab

`rollout_candidates.py` imports the verified Java/Node candidates into the named
kind node, checks each imported manifest's config digest, and applies an image-only
update sequentially to trade-service, trade-processor, order-matcher and
price-publisher. It serializes against console experiments and saves private
before-images/pull policies under `candidate-rollout/`. It preserves every other
Deployment setting, waits for readiness, verifies workload and SQL restrictions and runs
the full inherited C3 trading smoke suite. Failure triggers reverse-order image
rollback with readiness checks. Existing rollout state must be reviewed before a
second run; the script does not silently overwrite recovery evidence.

The active candidate manifest pins are a separate runtime overlay used by workload
verification and reapplication. The pinned reference snapshot remains unchanged.
A successful compatibility rollout does not enable live NATS authentication or TLS:
those settings remain unchanged until identity, subject migration and broker cutover
gates pass. Local image pins do not establish signatures, admission trust or
registry availability on another cluster.

Next identity work is specified in [identity-authorization.md](contracts/identity-authorization.md):
strict token/session validation, server-side account entitlements, role enforcement
and short-lived browser messaging credentials. Console access-code login is a
separate boundary and cannot substitute for those controls.

## Explore the staged progression

Start with the [Mermaid learning map](progression.md). It shows which checkpoints are verified, which are isolated fixtures and what remains planned. [Residual-risk experiments](contracts/residual-risk.md) ask what can still happen within legitimate permissions; their outcomes have not yet been measured. CALM is a separate follow-on state.

## Isolated identity compatibility

[Identity fixture contract](contracts/identity-fixture.md) separates provider/token
compatibility from live account enforcement. Install the hash-locked
`scripts/security-lab/requirements-identity.txt` in a private Python environment
(current wheel lock targets macOS arm64 / CPython 3.14), then run:

```bash
python scripts/security-lab/verify_identity.py --sequential --output-dir /private/tmp/traderx-security-runtime/evidence/identity-provider
python -m unittest discover -s scripts/security-lab -p test_identity_fixture.py
```

The harness uses the dedicated Docker client, shared experiment lock, fixed loopback
TLS port 18446 and a disposable provider/network. No password grant is used for
testing: all three users submit the provider login form and exchange a code with
S256 PKCE. Tests are protocol-level, not a browser usability assessment. Sanitized
evidence records image/source hashes and individual cases; temporary credentials
and container storage are removed. The PyJWT verifier establishes the fixture
contract only; actual Spring resource-server enforcement is implemented separately in the opt-in account candidate.

On this 6 GB host the identity test temporarily stops C3 and restarts it in finally. It serializes against console experiments; verify readiness and normal trading afterward. Simultaneous provider/C3 acceptance remains pending.

The [recorded identity run](evidence/2026-11-23-identity-provider.json) passed all 18 cases. This provider fixture has not secured the C3 endpoints. The opt-in account candidate tests actual controller enforcement separately.

## Resource-aware operation

Run `python scripts/security-lab/resource_preflight.py --mode acceptance` for a read-only capacity report. See [operating modes and current enforcement scope](contracts/resource-modes.md). The identity fixture gates startup on this check; its previously recorded 18-case result predates this guard, which has unit and read-only verification only.

## Lightweight account development

Use [the minimal account development workflow](contracts/account-development.md) to
work on account authorization with three bounded containers instead of full C3.
`account_dev.py verify-reset` verifies two fresh synthetic cycles and leaves a clean
dataset. Candidate bootJars can be copied and hashed at render time with `--jar`.

Console scenarios now declare their resource mode and record capacity rejection as
`blocked` before execution. The three lab image builders and account bootJar builder take the same lock and run
build preflight. These changes do not automatically stop/start C3 from the browser.

## Protected account candidate

The [account enforcement contract](contracts/account-enforcement.md) now has a
working opt-in Spring candidate. [Recorded evidence](evidence/2026-11-23-account-authorization.json)
shows 59 real HTTP cases passing in each of two reset cycles: filtered reads,
cross-account denials, strict token validation and rejected writes for every role.
Independent SQL fingerprints remained unchanged after the requests. The post-test
container working-set sample was about 486 MiB, excluding VM overhead and peaks.

Run `build_account_security.py` followed by `verify_account_authorization.py`
using the lab Python environment. This uses an isolated test signer and loopback
port 18488; it does not enable browser sign-in or protect the deployed C3 services.
Real-provider integration is tracked in the checkpoint below. Browser behavior,
automated key lifecycle and full-C3 trading acceptance remain separate gates.

## Real-provider account checkpoint

The protected API now passes actual Keycloak login/PKCE tokens: [49 initial
checks](evidence/2026-11-23-account-oidc-first.json) and [50 checks after explicit key
replacement](evidence/2026-11-23-account-oidc-rotation.json). Reader, trader and operator
scopes, denied writes, ID-token rejection and independent unchanged SQL state were
verified. The retired-key token was still unexpired when the API rejected it.

Stopping the provider did **not** revoke an existing valid access token: offline
verification continues within token/trust expiry. This is an explicit learning
outcome. The provider is removed after each campaign; the candidate retains its
finite public trust configuration. A four-container sample was about 902 MiB,
excluding Docker VM overhead and startup peaks. Both full clusters remain stopped.

Remaining identity work includes browser/session integration, automatic key
lifecycle and revocation decisions, other APIs and trading user-context propagation,
then full-C3 acceptance. Live broker authorization, integrated gateway/network/image
trust, residual-authority experiments, CVE/OSERA, runtime comparison and CCC evidence
also remain open. The complete hardened learning release is not yet accepted.

## Local browser-session checkpoint

The [account-only session page and backend](contracts/browser-session.md) implement
real code/PKCE login with tokens retained only in server memory, secure HttpOnly
cookies, bounded sessions and CSRF-protected local logout. The
[protocol campaign](evidence/2026-11-23-browser-session.json) passed 88 checks,
including the inherited provider/API checks and 39 browser-session checks.
All three roles used fresh browser profiles. Callback replay/state mismatch,
cross-account requests and invalid logout attempts were rejected; logged-out
session cookies lost API access and SQL state remained unchanged. Session expiry
is unit-tested, not a wall-clock browser acceptance result.

The runner removes the session server and provider after verification. This is
not a persistent remotely accessible site, manual Chrome usability acceptance or
Angular trading integration. Same-browser SSO account switching remains unaccepted.
Local logout deliberately does not revoke provider SSO or independently held
bearer tokens. Both full clusters remain stopped.

## Persistent local browser runner

`browser_lab.py serve --hours 4` keeps the account page and pinned provider running
under the exclusive lab operation lock; `status` reports readiness and the private
credential-file directory, and `stop` performs verified graceful shutdown. The page
reuses the documentation portal's TraderX logo. TLS certificates are retained across
restarts. It is local-only at `https://localhost:18447`, with no ngrok mapping.

[Lifecycle and protocol evidence](evidence/2026-11-23-browser-persistent.json) records
63 passing checks, including 24 same-cookie-jar account-switch checks, unchanged SQL
state, stop/closed ports, same-certificate restart and blocked concurrent heavy work.
The four-container working-set sample was about 969 MiB (excluding VM overhead and
startup peaks). Same-profile switching now uses a distinct CSRF-protected action and
Keycloak logout confirmation, while ordinary local logout retains its limited scope.

Chrome reached the localhost certificate-validation boundary and reported
`ERR_CERT_AUTHORITY_INVALID`. Actual Chrome UI acceptance remains incomplete pending
the user's decision on scoped localhost certificate trust. No warning bypass or
system trust change was performed. Angular/C3 integration also remains open.

Learner onboarding should follow [the local-versus-hosted design](contracts/learner-onboarding.md):
contributors approve development trust once, then start the lab through one workflow;
workshop attendees use a hosted trusted-HTTPS URL. The unified onboarding tooling and
hosted environment remain planned, not available features.


Chrome follow-up: the user approved trusting the exact local lab certificate.
Standard SSL trust in the login keychain resolved the Chrome incompatibility;
no browser warning was bypassed. [Actual Chrome evidence](evidence/2026-11-23-chrome-browser.json)
now verifies reader/trader sign-in, permitted account lists, a cross-account 403,
provider-confirmed account switching and a 401 after local logout. This supersedes
the earlier Chrome certificate blocker. The console logo has 5px margin and 5px
inner padding on all sides, verified using Chrome's computed styles.

## Becoming a TraderX state

This profile is intended to become a first-class learning state derived from C3.
It is not yet registered or publishable as that state. The
[state-readiness audit](state-readiness.md) separates implemented local evidence from
integrated control, generation, learning and reproducibility gates. The
[community introduction blueprint](community-introduction.md) defines how the docs
portal and experiments portal work together, including the canonical Mermaid map,
a small annotated screenshot walkthrough and an unpublished announcement draft.
CALM remains a separate follow-on state.

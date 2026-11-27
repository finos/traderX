# Isolated Linux HTTP integration runner

The Linux workflow exercises the existing candidate campaign, not a deployment
or security acceptance. It fetches the immutable baseline, renders, builds and
tests the three trading candidates and position/history candidate sequentially, then runs the verified
processor jar against a disposable PostgreSQL fixture. Denied synthetic
identities and invalid requests must leave all fixture tables unchanged;
concurrent duplicate requests and processor/database restarts are checked.
The same job runs the event outbox, cancellation/adversarial SQL campaigns, and authenticated JetStream/reference-consumer campaign sequentially. The offline job checks the CCC mapping. Component Java builds run once in the Linux job, avoiding a duplicate three-service build in the offline workflow.

It also runs the supervised-worker component tests and independent delivery
adversarial campaign. That second broker campaign checks canonical payload
tampering, malformed wire messages, stale claims and acknowledgment boundaries
against authoritative database state. It uses fresh fixtures after the first
campaign has cleaned up; neither campaign launches the supervisor as a separate
process. Actual worker process recovery remains unverified by these checks.

Loopback HTTP and synthetic signed tokens do not establish deployment TLS,
live Keycloak, matcher dispatch, broker delivery or production readiness.

Use only a dedicated, disposable Linux runner and local Docker daemon. Explicit
`TRADERX_LAB_ISOLATED_LINUX=1` opts in to `unix:///var/run/docker.sock`; other
Docker hosts are refused. The preflight requires observable Linux available memory
and memory pressure, sufficient provisional headroom, and no running containers;
it permits only build and fixture modes. This is a snapshot, not a reservation.
The runner operator is responsible for exclusive ownership of the daemon and
host, including stopped containers and other workloads. It is not safe for a
shared workstation or a remote Docker daemon. The macOS default retains its
original Docker socket and pressure checks without the opt-in.

The database is resource-limited, non-privileged, and publishes only to
127.0.0.1. The application runs as a bounded local process, with no Docker
socket mount. Fixture containers and persistent volumes carry unique ownership
labels and are removed after success or failure; Docker outages or forced runner
termination can prevent cleanup. Inspect only resources bearing the fixture
label if manual cleanup is necessary. A disposable CI host provides the final
boundary for forced termination. Private logs, credentials and evidence stay in
the temporary runtime and are not uploaded.

For a dedicated Linux host with Python, Docker, Java 21 and Gradle network
access, from the repository root:

```bash
python3 -m pip install -r scripts/security-lab/requirements.txt
python3 -m pip install 'cryptography==50.0.2' 'PyJWT==2.15.1'
python3 -m pip install --require-hashes -r scripts/security-lab/requirements-delivery.txt
python3 scripts/security-lab/checkpoint.py fetch-baseline
export JAVA_HOME=/path/to/java-21
export TRADERX_LAB_ISOLATED_LINUX=1
umask 077
runtime="$(mktemp -d)"
trap 'rm -rf "$runtime"' EXIT
mkdir "$runtime/evidence"
python3 scripts/security-lab/build_trading_security.py --runtime-dir "$runtime" --java-home "$JAVA_HOME"
python3 scripts/security-lab/verify_execution_http.py --runtime-dir "$runtime" --output "$runtime/evidence/http.json"
python3 scripts/security-lab/verify_event_delivery.py --runtime-dir "$runtime" --output "$runtime/evidence/broker-delivery.json"
```

Use a private runtime directory and remove it after inspecting any needed local
evidence, including on failure. On a guarded Mac, omit the Linux opt-in, set
`JAVA_HOME` to Java 21 and use the same commands with the existing Mac Docker
socket and preflight; do not substitute the Linux isolation assumptions.
The Linux GitHub Actions workflow runs on a fresh hosted runner without
repository secrets and removes its temporary runtime on exit. A workflow run
must actually succeed before claiming live integration validation.

## Protected position image

The independent `position-image` job builds the canonical protected position
bootJar, verifies its Java authorization test results, and exports/inspects an
actual immutable OCI image. Its private launcher and TLS acceptance follow
[java-runtime.md](java-runtime.md). It exercises actual scoped position/history
reads, identity denials, HTTPS and PostgreSQL certificate verification, restricted
execution and owned cleanup. Only sanitized JSON is uploaded; no image is
published. This gate does not activate Kubernetes or close cumulative acceptance.

For a packaging-specific failure, dispatch the workflow with `campaign=position-image`
to run that job alone; `all` is the default. Focused diagnostics do not substitute
for the complete regression run before accepting a checkpoint. This avoids
repeated unrelated Java/Angular downloads while debugging startup.

## Account and processor image campaigns

The `java-core-images` matrix follows [core-java-images.md](core-java-images.md).
Separate account and processor runners reuse the verified Java image builder and
instance-scoped test fixture, with distinct ports, audiences and projected-file
inventories. No generation target or credential is shared. `campaign=java-core-images`
selects these jobs for diagnosis; the default full run also preserves all existing
position, Python image, browser, delivery and admission checks. Only sanitized
`security-account-service-image` and `security-trade-processor-image` JSON artifacts
are retained. A processor outbox commit is not proof of later broker delivery.

## Matcher image and complete source regression

The `matcher-image` job follows [matcher-image.md](matcher-image.md). It builds
processor and matcher Java artifacts sequentially before starting BuildKit: the
resource preflight correctly refuses a second Java build while a builder
container is running. Both immutable images are then inspected and loaded into
the same owned, disposable network. `campaign=matcher-image` selects this job for
focused diagnostics; full regression is still required for acceptance.

The campaign uses verified PostgreSQL/NATS TLS and an owned synthetic HTTPS
client-credentials peer. It checks broker trust/credential rejection, scoped user
requests, failed service credentials without settlement, recovery of the same
pending reservation, exact settlement/outbox effects, duplicate suppression,
cancellation and independently observed account-scoped order updates. The
synthetic issuer does not establish real Keycloak provisioning. The outbox result
does not claim broker delivery of the settlement events; that is a separate
worker campaign. Only sanitized `security-matcher-image` JSON is retained.

The independent `source-tests` job fetches the pinned baseline and runs the full
Python test discovery, including the pinned WebSocket client dependency. This
keeps the complete lightweight regression reproducible on hosted Linux without
requiring a maintained local virtual environment. The people-authorization job
also checks the preparatory .NET packaging tooling; its existing source-built
operator campaign does not accept the proposed .NET OCI image or native-library
composition.

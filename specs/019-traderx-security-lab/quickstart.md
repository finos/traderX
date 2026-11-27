# State 019 prototype quickstart

**The generated State 019 runtime is not available yet.** The current prototype uses a pinned C3 snapshot and local fixtures. Do not interpret these as a complete hardened trading deployment.

Follow the [learner onboarding contract](../012-platform-convergence-c3/security-lab/contracts/learner-onboarding.md) for supported host prerequisites, certificate trust and the existing lightweight account experiment:

```bash
scripts/security-lab/traderx-lab doctor
scripts/security-lab/traderx-lab setup
scripts/security-lab/traderx-lab start
scripts/security-lab/traderx-lab status
scripts/security-lab/traderx-lab stop
```

Setup may require building the pinned candidate and explicit local CA installation; it is not a universal one-command installer. Keep credentials in the private runtime location printed by the launcher. Run one cluster at a time. Use the [learning progression](../012-platform-convergence-c3/security-lab/progression.md) to distinguish verified checkpoints from planned exercises. Fresh-machine reproduction remains a release gate.

## Reproduce the offline checkpoint

This lighter contributor exercise generates artifacts only; it starts no containers and requires no certificate trust. Use Python with `scripts/security-lab/requirements.txt` installed in an isolated virtual environment:

```bash
python3 -m venv .venv-security-checkpoint
.venv-security-checkpoint/bin/python -m pip install -r scripts/security-lab/requirements.txt
.venv-security-checkpoint/bin/python scripts/security-lab/checkpoint.py fetch-baseline
.venv-security-checkpoint/bin/python scripts/security-lab/checkpoint.py generate --output /tmp/traderx-019-checkpoint-review
.venv-security-checkpoint/bin/python scripts/security-lab/checkpoint.py verify --output /tmp/traderx-019-checkpoint-review
.venv-security-checkpoint/bin/python scripts/security-lab/checkpoint.py plan --output /tmp/traderx-019-checkpoint-review
TRADERX_SECURITY_PYTHON="$PWD/.venv-security-checkpoint/bin/python" bash scripts/test-state-019-checkpoint.sh
```

Choose a new output directory for another run; existing output is never overwritten. Only `fetch-baseline` needs network access after installing prerequisites. Read the [checkpoint contract](system/checkpoint-generation.md) before interpreting its artifacts. The baseline remains deliberately distinct from the fully hardened state.

## Verify fresh database initialization

The [database bootstrap contract](system/fresh-database-bootstrap.md) documents a separate bounded live exercise: two fresh 256 MiB PostgreSQL fixtures, sequentially, with no host ports. It checks scoped SQL operations, transaction rollback and refusal to overwrite initialized data. Resource and operation-lock preflight apply; this is not a generated full-state start command.

## Cumulative runtime candidate

The [telemetry and cumulative lifecycle contract](system/telemetry-lifecycle.md) describes the explicit contributor start/stop/test commands. These operate on an owned cluster and private identities, preserve PVCs, and check host pressure; they are not the published generated-state launcher or completed hardened-state acceptance.

## Unified contributor commands

Use the [verified contributor entrypoint](system/contributor-entrypoint.md) for fresh-checkout artifact generation and guarded candidate start/test/stop. Runtime arguments are explicit; the wrapper does not provision a cluster or imply full security acceptance. Recovery stop remains available when artifacts have drifted.

Before a full candidate run, invoke `state_candidate.py doctor` with the checkpoint and explicit runtime arguments. A blocked result while the lightweight lab is running is expected; it does not stop that lab or resume Kubernetes. See the contributor contract for readiness checks and provisioning limitations.

## Hosted browser and image validation

Contributors can use the **Security Lab Linux Integration** workflow on their reviewed branch for the heavier checks. Its independent disposable runners build the real Angular/Java candidates, drive Chromium through login and trading, and build the Python and protected Java runtime images. No local cluster, laptop certificate installation or image download is needed to inspect these results.

The `browser-journey` job follows the [browser acceptance contract](system/browser-journey.md). The `runtime-images` job follows the [packaging contract](system/runtime-images.md), builds each role sequentially and exports local OCI artifacts without publishing images. That same job then runs the [packaged-worker TLS/recovery campaign](system/worker-image-delivery.md) against the inspected immutable images and attaches `security-worker-image-delivery` only on success. Successful jobs attach small JSON evidence reports; the workflow never uploads credentials, private configuration or raw service logs. Match a report to the workflow's source commit before reusing it.

The `position-image` job exercises verified HTTPS, scoped read APIs and database
TLS. The independent `account-service-image` and `trade-processor-image` jobs
follow the [core Java image contract](system/core-java-images.md): account read
isolation and write rejection; processor service identity, settlement/outbox
outcomes and duplicate/restart behavior. Each job owns its database and private
materials on a separate runner. Passing one job does not establish the combined
application's network or gateway controls.

For focused diagnostics on your reviewed feature branch:

```bash
gh workflow run security-lab-integration-linux.yml --ref YOUR_FEATURE_BRANCH -f campaign=java-core-images
```

Use `campaign=all` for full regression acceptance, or `position-image` for the
existing position checkpoint. Select the matching source revision and inspect
the sanitized JSON artifacts; a queued job or a passing source test is not a
runtime result.

These are contributor verification jobs, not a remotely hosted experiment portal. Browser trading still uses explicitly synthetic market peers and a loopback database fixture. The separate worker-image campaign now verifies packaged PostgreSQL/NATS TLS delivery and recovery; image startup checks alone establish neither that behavior nor the remaining Java/.NET adapters. A cumulative cluster with the gateway, enforced network controls and signed-image policy remains a separate acceptance gate.

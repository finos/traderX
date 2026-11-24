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

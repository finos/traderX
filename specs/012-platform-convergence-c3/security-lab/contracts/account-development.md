# Minimal account-service development environment

Purpose: develop account authorization without running nineteen C3 deployments.
This is a local development composition, not the hardened C3 acceptance environment.

## Canonical inputs and boundary

`account_dev.py` renders a fixed three-service Compose project from the profile's
baseline image pins and `generation/account-dev/{schema.sql,people-stub.js}`:

- Real account-service image, with an optional copied/hash-recorded local account
  Spring bootJar mounted over `/opt/app/app.jar` for development iterations.
- PostgreSQL with a fresh two-account synthetic dataset in tmpfs. A distinct
  `lab_account` runtime role has SELECT/INSERT/UPDATE on Accounts, SELECT/INSERT
  on AccountUsers and sequence USAGE, with no ownership or administrative grants.
- Fixed People stub accepting only reader/trader/operator. It is not the actual
  People service and cannot establish identity or end-to-end service parity.

Only account HTTP is exposed, at `http://127.0.0.1:18488`. No ngrok registration,
Kubernetes resources, C3 Secrets, database volumes, trading consumers, messaging,
OIDC provider, WAF or observability stack is included. It is unauthenticated
baseline application behavior until the separate authorization change is implemented.
All three containers are non-root, capability-free and read-only except explicit
tmpfs. Provisional limits: account 512 MiB (192 MiB Java heap), database 256 MiB,
stub 96 MiB; swap disabled. Combined container ceilings are 864 MiB, excluding
Docker/kernel overhead. Current account/database images are AMD64 and emulated.
Do not describe these limits as measured minimum requirements or complete peak budgets.

Credentials are generated only into a private runtime directory (0700), with separate
bootstrap and application mounts. Ordinary Compose environment/config contains file
paths, not passwords. Runtime input hashes reject silent drift; rendering refuses
an existing directory to avoid silently rotating credentials or replacing a candidate.
The fixed project ownership label is checked before lifecycle operations. Cleanup
remains available under memory pressure and takes the shared runner lock.

## Workflow

Stop the named C3 lab explicitly before starting development mode; keep State 014
stopped. The console never stops clusters on a learner's behalf. Do not run builds
or mode changes while a console experiment owns `console-run.lock`.

```bash
python scripts/security-lab/account_dev.py render
# Alternatively render with --jar /absolute/path/to/account-service-boot.jar
python scripts/security-lab/account_dev.py up
python scripts/security-lab/account_dev.py verify
# Or reset and verify two cycles, then leave a fresh seed:
python scripts/security-lab/account_dev.py verify-reset
python scripts/security-lab/account_dev.py down
```

Inputs live under `/private/tmp/traderx-security-runtime/account-dev`. `up` and
`verify` require development preflight; `down` does not require spare capacity.
Stop/reset discards synthetic data. For repeatable reset checks, `verify-reset` stops/starts the existing containers,
clearing tmpfs while retaining image references. `down` removes the containers; a
subsequent `up` explicitly pulls pinned images. No database volume deletion is necessary. Verification intentionally mutates synthetic data and
requires fresh seed data. The local jar option checks the account application class,
copies the artifact and records its hash; it does not prove source provenance, test
success, signatures or image admission. Edit canonical source/profile overlays and
build a candidate; do not treat private generated copies as the persistent solution.

## Acceptance

Verify two fresh cycles: seeded account and membership reads, account create/update,
known-person membership insertion, unknown-person rejection with no membership
created, and missing-account handling. Independently verify container users, resource
limits, loopback exposure and lack of C3 mounts. Record sampled memory by container;
it is not continuous peak telemetry. After the second cycle, reset to clean data for
development. Full C3 trading remains a separate acceptance gate after integration.

The actual accountuser detail method resolves an account ID and returns the first
membership sorted by username. The earlier row-ID interpretation was incorrect and
has been corrected in the route inventory. Membership mutation authorization is now implemented in the opt-in protected
candidate; see [account enforcement](account-enforcement.md). The baseline verification
above still describes the inherited unprotected application.

A startup failure exposed image-cache churn: Docker recorded image deletions after container removal and Compose reported a missing Node image. Retained-container stop/start resets avoid depending on unused-image retention. Docker event evidence does not identify the actor responsible for removal. Failed Compose output is retained privately; failed reset results must not be reported as passing.

## Verified local result

[2026-11-23 evidence](../evidence/2026-11-23-account-development.json) records two
eight-check cycles, a final clean seed, actual workload restrictions and an observed
`lab_account` database connection. Combined container working-set samples were about
476–489 MiB. This excludes Docker VM overhead and does not establish startup peaks
or performance under load. C3 and State 014 were left stopped; the three-container
development environment remains running on loopback port 18488.

The protected candidate uses `verify_account_authorization.py` instead of the
baseline write smoke. Initial startup now pulls/creates each service sequentially
before starting the composition, retaining image references across later pulls.

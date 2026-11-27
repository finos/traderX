# Fresh synthetic database bootstrap

S019-03c1 implements the database component of the planned startup lifecycle. It does not start the application or apply the Kubernetes control candidate.

## Contract

`bootstrap_database.py` reads the immutable C3 seed through the verified reference renderer. It requires the reviewed seed structure, removes its historical DROP preamble, and replaces seed timestamps with a fixed synthetic timestamp so independent fresh databases contain identical data. It refuses unexpected reset/transaction commands.

Initialization runs as one transaction: acquire an advisory transaction lock, require database `traderx`, reject existing public objects, other user schemas or runtime roles, create the schema and synthetic dataset, then create the four scoped service roles and apply the canonical grants. All steps commit together. A failure rolls back schema, seed and roles. Repeating the operation on an initialized database fails before changing either data or passwords; it is not an automatic reset, migration or rotation mechanism.

Runtime credentials are newly generated at execution. Each role has a distinct random password, no administrative role flags and only its reviewed table/sequence permissions. The generated checkpoint contains a seed hash and role contract in `bootstrap-contract.json`, never generated credentials. The SQL renderer returns private execution material to its caller; do not log or publish it.

## Persistent private identities

S019-03c2 adds `credential_store.py` for the forthcoming lifecycle. Create an owner-only directory outside the checkout and generated bundle, then explicitly create the store once:

```bash
mkdir -m 700 /private/tmp/traderx-sql-private
.venv-security-checkpoint/bin/python scripts/security-lab/credential_store.py create \
  --store /private/tmp/traderx-sql-private/identities
.venv-security-checkpoint/bin/python scripts/security-lab/credential_store.py verify \
  --store /private/tmp/traderx-sql-private/identities
```

For durable deployments, choose persistent private storage rather than `/private/tmp`; back it up as sensitive material. This is a local POSIX file store, not encrypted storage or a cloud secret manager. Run under a trusted host account and trusted ancestor directories. The immediate parent and store require current-user ownership and mode 0700; the identity file requires 0600, regular-file type and a single hard link. Final directory/file symlinks are refused. Credentials never appear in command output or generated checkpoints.

Creation reserves a new directory atomically and flushes the file and directories to disk. A duplicate or interrupted creation is refused; preserve incomplete material for explicit recovery rather than retrying with new passwords against an existing database. Loading verifies completeness, checksum, identity shape and a versioned binding to the pinned baseline and reviewed grants. A changed binding requires reviewed migration, not automatic replacement. The checksum detects accidental corruption, not modification by a malicious owner who can rewrite both data and checksum.

`credential_store.bootstrap_sql(path)` verifies and reuses the stored service identities to produce the existing transactional bootstrap SQL in memory. The stored bootstrap administrator identity is separately available to the database startup adapter. Neither interface executes SQL, creates Kubernetes Secrets, rotates credentials or resets data. File-store tests cover reuse/refusal, damage, contract mismatch, incomplete state, permissions, links and redacted CLI output. Database restart and Kubernetes integration are covered by the later [live lifecycle campaign](live-kubernetes-lifecycle.md); full-state acceptance remains pending.

## Bounded live verification

On the currently supported macOS Docker Desktop fixture environment, after preparing the pinned snapshot and Python dependencies:

```bash
.venv-security-checkpoint/bin/python scripts/security-lab/verify_bootstrap.py \
  --runtime-dir /private/tmp/traderx-security-runtime \
  --output /private/tmp/traderx-security-runtime/evidence/bootstrap-new-run.json
```

Choose a new evidence filename. The runtime directory must have the Docker client configuration expected by the existing lab tooling. The verifier acquires the shared operation lock and runs the resource preflight; it refuses when another full cluster is running or capacity cannot be verified. It does not stop unrelated containers to make room.

Two fresh PostgreSQL instances run sequentially, each with a 256 MiB memory limit, one CPU, restricted process settings, tmpfs data and no network access beyond its own loopback. No host ports are published. It uses the pinned C3 database image, mounts only its private bootstrap-password file, and sends SQL-login credentials over stdin. Container logs suppress SQL statement/error text. Cleanup verifies the run's ownership label before removing its temporary container.

The campaign checks:

- Existing user-schema canary data causes refusal and remains unchanged.
- An injected failure after schema/role creation rolls the transaction back; a subsequent clean bootstrap succeeds.
- Both instances contain seven accounts, eighteen account memberships, four positions, four trades and an empty order book, with identical row fingerprints.
- Real service logins have the exact table grant matrix, no administrative role flags, no schema-create or temporary-table authority, and can perform rollback-only positive operations.
- Role administration, schema changes and prohibited deletes fail with PostgreSQL insufficient-privilege errors.
- A second bootstrap using new credentials is refused; original credentials still authenticate and all seed fingerprints remain unchanged.

## Database lifecycle candidate and restart evidence

S019-03c3 adds `database_lifecycle.py`, a database-only Kubernetes adapter, and a bounded persistent-database restart campaign. The adapter now has a separate [live Kubernetes acceptance campaign](live-kubernetes-lifecycle.md). It is not the generated State 019 start command and does not roll out trading services.

Startup requires an explicit kubeconfig, context and expected `kube-system` namespace UID, the shared operation lock and the full-lab resource preflight. It will not start a cluster itself. It creates a Restricted namespace only if absent and refuses to adopt an existing namespace or resource without the credential-derived ownership label. Five immutable Secrets are sent through stdin; passwords never enter command arguments or public artifacts. The database PVC, service account and seed-suppressing ConfigMap precede the database deployment. Existing resources must retain reviewed fields; API-defaulted dictionary fields are tolerated. This is not a complete admission-policy or drift-detection boundary.

The deployment starts with zero replicas. After resources pass verification, startup scales the owned database to one replica and waits for rollout before running the guarded transaction. A private lifecycle binding commits in the same transaction as the schema, seed and roles. Subsequent startup verifies that binding and authenticates all four runtime identities without reseeding. A lost PVC beneath an existing deployment requires explicit recovery; it is never silently replaced. An initialization failure scales the database back to zero and retains storage for inspection. A rollout timeout retains resources for inspection and explicit stop.

Stop verifies cluster/namespace/deployment ownership, uses UID and resource-version preconditions to scale down, and waits for owned database pods to disappear. It retains Secrets, PVCs, data and namespace, and does not shut down unrelated applications or clusters. Stop takes the operation lock but remains available under resource pressure. Concurrent cluster-administrator mutation is outside this lab's threat model.

The live restart campaign uses a single 256 MiB PostgreSQL container with a disposable, ownership-labelled Docker volume, no host ports and no external networking:

```bash
.venv-security-checkpoint/bin/python scripts/security-lab/verify_database_restart.py \
  --runtime-dir /private/tmp/traderx-security-runtime \
  --output /private/tmp/traderx-security-runtime/evidence/restart-new-run.json
```

It creates private identities, initializes once, commits a synthetic canary, then stops and starts PostgreSQL twice. Each restart reloads the same credential file, authenticates the four service identities, verifies identical seed fingerprints and confirms the committed canary remains. A mismatched binding fails. Cleanup checks ownership before deleting only this campaign's temporary container and volume. This proves database persistence and resume semantics; it does not prove Kubernetes PVC provisioning, admission, rollout or normal trading.

## Remaining lifecycle work

The database verifier owns disposable fixtures only. The later [cumulative lifecycle](telemetry-lifecycle.md) integrates fresh telemetry initialization, all nineteen application Deployments and the isolated collector, with guarded start/stop/test commands. Existing-data migration, generated-state packaging, clean-machine reproduction and remaining security controls are separate gates. Do not directly apply the offline bundle. Current grants constrain service authority; they do not implement end-user account authorization.

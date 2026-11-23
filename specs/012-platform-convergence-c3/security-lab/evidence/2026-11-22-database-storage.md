# PostgreSQL preservation and restrictions — 22 November 2026

SL-T07d is complete. PostgreSQL now uses a 2Gi local PVC instead of emptyDir,
with non-root UID/GID 70, restricted capabilities/seccomp, read-only root and a
dedicated token-free identity. Fifteen of twenty C3 workloads now have verified
process restrictions. SQL least privilege and namespace-wide admission remain open.

## Preservation proof

All eight business services were stopped before backup. Row counts and ordered
content fingerprints matched before and after the custom-format pg_dump. A fresh
restricted PostgreSQL Pod initialized with seed scripts suppressed, and pg_restore
restored the backup in one transaction. Every table matched. The migrated Pod was
then replaced; all fingerprints matched again before business replicas returned.

Preserved rows by table: `{"accounts": 7, "accountusers": 18, "orderbook": 7, "positions": 9, "trades": 18}`.

Backup SHA-256: `098c5a10ede4b6fdd53f1ad5f113969b313913b897d75b1c76b5591bb595303a`.
Pre-restart Pod UID: `57c8fe27-ac3e-4f64-85d1-fe34a846b71b`.
Post-restart Pod UID: `756897da-25f6-4866-8ded-d514ce1ab9cd`.
Migration completed: `2026-11-22T14:19:49.139861+00:00`.

The private dump and phase ledger remain in the runtime's `database-migration/`
directory (directory 0700, files 0600), outside source control. Completed-migration
`--resume` was tested as a no-op. Recovery from an injected mid-migration failure
has not been tested; the implemented phase/resume mechanism is not a claimed
failure-injection result.

## Runtime and admission results

Console run `50bd5a8f-42f7-427b-9fb6-f897064e4159` passed. The evidence artifact hash
was checked against its JSON payload. Observations include actual process UID,
zero capabilities, no-new-privileges, seccomp mode 2, read-only root, absence of
API token, RBAC denials, bound PVC and the expected PGDATA path. /tmp write/remove
succeeded; a root write failed with `Read-only file system`.

Fourteen unsafe Deployment updates were rejected by the named policy, including
an alternate PVC, disposable PGDATA and parallel database replicas. Four direct-Pod
or ephemeral-container changes were denied; a compliant Pod dry-run passed. No
unsafe Pod or debug container was launched. The verifier was extended for the
database's exec-based readiness probe after its initial HTTP-only assumption failed.

Both prior workload groups passed again: eight business processes and six support
processes, with their admission checks. The full inherited C3 trading/settlement,
API, UI and observability smoke passed after migration. Thirty-five automated tests
and all four repository gates passed. The sixth console experiment distinguishes
current PVC/process checks from the recorded historical restart-recovery proof.

## Limitations

Local PVC durability is Pod replacement only, not cluster deletion or host loss.
Backup and ledger are local mutable evidence, not an external authoritative audit
store. Existing application SQL superuser credentials are unchanged; scoped roles
and rotation remain SL-T09. The five remaining telemetry/observability workloads
and namespace-wide admission remain SL-T07b. CALM remains deferred.

[Structured runtime evidence](2026-11-22-database-workload-result.json).
Trading log: `/private/tmp/traderx-security-runtime/evidence/database-trading.log`.
Trading log SHA-256: `956536f759fa388661b19d500fc1e9e83e7e0651d61589a0bb26bb58d600f08d`.

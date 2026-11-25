# Supervised delivery worker contract

This candidate wraps the existing State 019 delivery adapters. It does not
bootstrap schema, create broker streams or consumers, provision permissions,
or cut over an application consumer. The consumer is only the existing
same-database reference projection described in `event-delivery.md`.

## Configuration and trust

Run `python scripts/security-lab/delivery_worker.py --config /absolute/private/worker.json`.
The JSON file must be a regular, non-symlink file owned by the process user and
inaccessible to group and other users. It contains credentials and must never
be committed. All fields are required; unknown and duplicate fields are
rejected. Paths are absolute. Example structure (replace placeholders locally):

```json
{
  "mode": "publisher",
  "broker_endpoint": "tls://broker.example:4222",
  "broker_user": "publisher",
  "broker_password": "replace-locally",
  "broker_ca": "/private/broker-ca.pem",
  "database_host": "database.example",
  "database_port": 5432,
  "database_name": "traderx",
  "database_user": "publisher",
  "database_password": "replace-locally",
  "database_transport": "verify-full",
  "database_ca": "/private/database-ca.pem",
  "batch_size": 8,
  "lease_seconds": 30,
  "poll_seconds": 1,
  "operation_timeout_seconds": 10,
  "retry_attempts": 5,
  "retry_base_seconds": 1,
  "retry_cap_seconds": 30,
  "shutdown_seconds": 15
}
```

For `reference-consumer` mode additionally provide `account_id` (positive
integer) and `durable` (pre-provisioned broker durable name). The worker binds
that existing durable and rejects messages outside the exact trade and position
subjects for the configured account before invoking the adapter. Broker
permissions and the database allowlist remain the authorization boundaries;
the local scope check does not provision or replace either.

For example, prepare a separate private configuration with `"mode":
"reference-consumer"`, `"account_id": 22214`, and `"durable": "ACCOUNT_A"`,
and its own scoped database and broker credentials. Start it with the same
`--config` command. Configure the durable to filter both account subjects;
the worker cannot inspect its server-side filters with the restricted fixture
permissions. Protect the file with `chmod 600` and make its parent directory
accessible only to the intended service user.

The only plaintext SQL mode is `fixture-loopback`, restricted to literal
`127.0.0.1` or `::1`, with `database_ca` set to null. All other SQL connections
require `verify-full` and an explicit CA file. DNS names such as `localhost`
are not accepted as proof of loopback. The broker always uses the existing
hostname-verified TLS adapter. Configuration must not contain connection
strings or user-supplied libpq options.
Any inherited `PG*` environment variable is rejected to prevent libpq
environment defaults from overriding the explicit connection. CA paths must
refer to operator-controlled trust files.

## Runtime and supervision

The worker claims or fetches bounded batches, processing each item through the
existing adapters. A stop request prevents subsequent claims/fetches and
remaining batch items from starting; a current operation gets a bounded grace
period. Unfinished claims expire and unacknowledged messages redeliver under
the existing at-least-once contract. The worker never removes shared resources.
Positive broker acceptance precedes SQL acknowledgement; consumer SQL commit
precedes broker acknowledgement. A failed operation is not business success.

Transient connection/operation errors close the worker's own connections and
retry with bounded exponential backoff and jitter; authentication, invalid
configuration and invalid messages stop rather than retry indefinitely.
Consecutive failures exhaust the configured retry count; successful work or an
empty poll resets it. Structured JSON status/counters contain no credentials,
payloads, DSNs or server exception text and do not assert downstream business
success. Exit 0 means an orderly signal stop, 1 means retry exhaustion or
runtime failure, and 2 means invalid configuration or terminal authentication.
Each connection attempt and each complete batch is bounded by the configured
operation timeout (plus the polling interval for a batch). Choose a batch size,
lease and timeout suitable for the deployment; a timed-out batch may be replayed.
A forced shutdown timeout exits 1 after cancellation and bounded connection
cleanup, not a claim that in-flight work succeeded.
Supervisors should restart failures only under their own bounded policy and
alert on exhaustion; startup alone is not delivery health.

Provision schema, broker stream, account-scoped durable and least-privilege
identities separately. Operators must provide private credentials and trusted
CA files, rotate them through controlled process restart, and implement
backlog monitoring, poison-event recovery, retention and deployment controls.
The unit tests use injected adapters and do not prove process-crash recovery.
The separate real 41-check campaign and its resource guard/cleanup are
documented in `event-delivery.md`; it is not a deployment acceptance test.

With the existing delivery and lab requirements installed in a Python 3.14
virtual environment, run the focused adapter and worker checks from the
repository root:

```bash
cd scripts/security-lab
python -m unittest -v test_delivery_worker test_event_delivery
```

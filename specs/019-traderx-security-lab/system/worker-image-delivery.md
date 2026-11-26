# Packaged worker delivery acceptance

S019-06a3c follows the accepted [Python image smoke](runtime-images-smoke.md).
It closes the gap between a worker image rejecting invalid configuration and
that same packaged worker completing its intended work under restricted execution.
The [26 November hosted checkpoint](../evidence/2026-11-26-worker-image-delivery.json)
passes all 43 checks at source `1b40c4cc`. This accepts the packaged-worker
Docker campaign; it does not close cumulative Kubernetes deployment acceptance.

## Inputs and execution boundary

Reuse the three-image build's inspected OCI manifest and loaded immutable image
identities. Revalidate bytes, source labels and launcher configuration before
launching the publisher or consumer. Record the same image identities on restart;
do not rebuild or substitute a host Python process during the campaign.

Use a dedicated hosted Linux runner and an owned internal Docker network with
PostgreSQL and NATS peers. Certificates must contain the actual network DNS
names in their SANs. Clients must verify the chain and hostname; workers require
PostgreSQL `verify-full` and verified broker TLS. The existing loopback fixtures
remain unchanged and cannot supply this transport proof. Observe encrypted
worker SQL sessions independently through `pg_stat_ssl`.

Give each worker only its scoped database role and broker subjects. Preserve
UID/GID 10001, read-only root, dropped capabilities, no privilege escalation,
bounded resources and private tmpfs materialization from read-only projected
files. Fixture administration and authoritative evidence stay outside workers.

## Required observations

| Scenario | Independent evidence |
| --- | --- |
| Positive delivery | Two committed outbox rows reach the scoped durable broker and consumer; two inbox rows produce one trade and one position projection |
| Publisher interruption | Interrupt at the SQL acknowledgment boundary; restart the same image and drain pending work without losing an event |
| Consumer interruption | Interrupt after an effect is committed but before broker acknowledgment; restart and observe no duplicate projection |
| Replay | Replay beyond the broker deduplication window; persisted consumer deduplication prevents another effect |
| Business integrity | Delivery and replay do not create another authoritative settlement, trade or position change |
| Credential rejection | Wrong database and broker credentials prevent delivery without private values appearing in output |
| TLS rejection | Untrusted issuer and mismatched hostname cases fail without delivery or consumer effects |
| Cleanup | All owned containers, network and private files are removed on success and failure; cleanup failure prevents a passing result |

Use the existing process-recovery campaign's acknowledgment gates and SQL
assertions as a starting point. Add a separate container fixture and verifier;
do not reinterpret its host-process, loopback-database results as image evidence.
For the consumer post-commit case, the fixture may temporarily deny only that
consumer's broker acknowledgment subjects. Observe committed SQL effects and
the durable's unacknowledged delivery independently, then kill the still-running
container. Restore and verify the normal broker permissions before restarting
the identical image. Record this as an injected broker-permission failure, not
network loss or host power loss. A container that exits before the controlled
kill does not satisfy this interruption case. The packaged worker must not gain
a test-only pause, acknowledgment bypass or special fixture mode.
Export only fixed check identifiers, immutable image/source identities, bounded
counts and nonsecret event identities. Never upload private configuration,
credentials, raw container logs or database connection strings.

## Implementation sequence and limits

1. Add the owned TLS database/broker fixture and unit checks for certificate,
   configuration, ownership and failure cleanup boundaries.
2. Run the packaged positive path against the existing inspected image manifest.
3. Add interruption, replay, credential and TLS negative cases using those same
   image identities; require final SQL and consumer effects before acceptance.
4. Attach sanitized evidence to the hosted image workflow and record exact
   source, image and run identifiers before checking S019-06a3c complete.

This campaign does not establish Kubernetes networking, gateway/WAF enforcement,
image signatures, a separate consumer-database trust boundary or cumulative
deployment acceptance. Java/.NET packaging and support-service composition remain
S019-06a3b. The full [integrated acceptance](integrated-acceptance.md) still applies.

## Recorded result

The campaign retained two outbox rows and produced three broker messages because
one event was deliberately replayed beyond broker deduplication. Consumer storage
contained exactly two inbox rows, one trade projection and one position projection.
The authoritative settlement receipt remained singular and business-table
fingerprints did not change during delivery/recovery. Both worker roles rejected
all six credential/CA/hostname variants before causing any delivery effect.

Actual SQL sessions were observed encrypted, and actual process/mount probes
verified non-root execution, read-only roots and private materialization. The
same inspected image IDs were reused on each replacement. The external ACK gate
was independently observed both denied and restored before consumer recovery.
Private fixtures and all owned containers, volume and network were removed.

The first hosted attempts exposed fixture compatibility bugs: null Docker IPAM
configuration and protocol-1 NATS INFO updates. Focused regression tests cover
both; acceptance comes from the succeeding hosted run, not those unit tests alone.

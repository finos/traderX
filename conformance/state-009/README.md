# State-009 durable-order conformance — version 1

This pack implements the state-owned regression obligation in NFR-01322 and
NFR-01323 / SC-01318. The guarantee follows the capability into descendants and
corporate overlays, whether they copy, transform, or independently implement it.
The assertions must not be replaced by a simulation or a check for matching code.

## What it proves

The shared runner executes both `fresh` and `legacy` scenarios against the real
order HTTP API. In the legacy scenario it verifies that an existing partially
filled order retains its ID, account, security, side, quantities, price, status,
timestamps and last execution fields, with its previously absent type backfilled
to LIMIT. In both scenarios it verifies:

- a MARKET order without `limitPrice` is persisted and queues while no price exists;
- force-fill returns HTTP 400, leaves the queued order unchanged, and submits no trade;
- restart preserves that order (and the legacy order) without resetting the store;
- omitted `orderType` still creates a LIMIT order after restart.

Timestamp representations are compared semantically and unrelated response
metadata is ignored. The pack does not prescribe a language, physical schema,
migration tool, container platform, or file layout. It does not cover every
state-009 requirement: matcher fills, migration rollback/error paths, UI behavior,
and broader operational guarantees still need their own implementation tests.

## Reference run

After generation, with Java 21, Docker and Python 3 available:

```bash
bash scripts/test-order-matcher-regression.sh
```

This runs the Java/PostgreSQL tests, builds the actual executable matcher JAR,
and invokes this pack with `reference_adapter.py`. The adapter uses disposable
PostgreSQL containers, the generated production initialization SQL exported as
`fresh-init.sql` (retained when Kubernetes descendants remove Compose assets), the pre-MARKET
fixture in `legacy-orderbook.sql`, and an HTTP observation stub for the real
outgoing trade-service boundary. No application volume is mounted or removed.

From a standalone generated snapshot, the exported pack can also run directly:

```bash
(cd order-matcher && bash ./gradlew bootJar)
python3 conformance/state-009/run.py \
  --adapter python3 conformance/state-009/reference_adapter.py --target-root .
```

## Run against a corporate/overlay implementation

```bash
python3 specs/009-order-management-matcher/tests/conformance/run.py \
  --adapter python3 /path/to/corporate/state009_adapter.py --profile isolated-test
```

The command after `--adapter` is executed directly, without a shell. Generated
snapshots export the same pack and the state NFRs to `conformance/state-009/`.
Pin the upstream revision/contract version and retain the runner's exit status
and output with the adaptation's validation evidence. Run against the final
adapted implementation before publishing it, not an untouched reference copy.

The adapter can map transports/field representations but must not implement or
simulate the business behavior being tested. It must exercise the implementation's
real persistence, upgrade/startup path, order endpoints and outgoing trade boundary.
A different persistence engine may use its own legacy fixture with equivalent
order data and its own migration mechanism. Do not run this destructive fixture
setup against a live or shared application database.

## Adapter protocol

The runner keeps one adapter process alive and sends one JSON object per stdin
line. The adapter returns one JSON object per stdout line; diagnostics go to stderr.
The protocol version is `1`. Unsupported operations/versions, failed setup and
missing observations must fail, never silently skip. A response containing
`{"error":"description"}` fails the run. Each operation has a 120-second limit.

| Operation | Input | Required effect / response |
| --- | --- | --- |
| `prepare` | `baseline`: `fresh` or `legacy`; `legacy_order`: the fixture object or null | Create/reset an **isolated** test environment. For `legacy`, seed the given order into the implementation's pre-MARKET persistence representation, with no order type. For `fresh`, use its real fresh-install path. Disable seed/demo orders and all price inputs. Install observation of actual outgoing trade requests, with count zero. Do not perform a test-only migration. Return `{"contract_version":1}`. |
| `start` | none | Start the candidate implementation through its real upgrade/startup lifecycle and wait until usable. Return `{"base_url":"http://...","trade_probe_url":"http://..."}`. Initialization errors must fail this operation. |
| `restart` | none | Stop/restart the candidate through the same lifecycle, retaining the same data and trade observations. Do not reseed, clear or repair the store. Return current endpoint URLs as for `start`. |
| `cleanup` | none | Stop and remove only adapter-owned test resources. Be safe to repeat. Return `{}`. Also clean up on stdin EOF. |

`base_url` exposes the state contract: `POST /orders` (201),
`GET /orders/{orderId}` (200), and `POST /orders/{orderId}/force-fill` (400 for
queued MARKET orders). Corporate gateways can provide equivalent contract routes.
All price inputs must remain absent during these scenarios so the queued orders
are stable. `GET trade_probe_url` returns HTTP 200 with `{"count":N}`, counting
actual trade submissions since `prepare`, including submissions rejected downstream.
A constant/fabricated count is not conformant evidence. The reference stub accepts
submissions so an accidental call cannot be concealed by downstream unavailability.

Do not implement `restart` as merely returning the original endpoints: durability
and migration repeatability require a real process/runtime restart. Lifecycle
operations and resources are implementation-owned; test expectations stay here in
state 009. An explicitly incompatible replacement must document its divergence
instead of claiming this conformance result.

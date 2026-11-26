# Authenticated trading integration candidate

This Phase 1 campaign joins existing authorization and execution components. It
does not establish the Phase 2 Kubernetes/gateway/admission deployment.

## Requirements and acceptance

- ATR-01: Real Keycloak authorization-code/PKCE sessions submit and cancel orders
  through the explicit browser API boundary. Read-only users, operators without
  trading grants and cross-account requests cannot mutate business tables.
- ATR-02: The matcher consumes a synthetic market-price tick through authenticated,
  verified TLS NATS. Its existing scheduling/price callback performs the match;
  there is no privileged HTTP test hook or direct reservation shortcut.
- ATR-03: The matcher obtains its own real Keycloak client-credentials token with
  the dedicated execution audience. The processor requires its exact service
  subject and verified HTTPS. Browser/user tokens cannot invoke execution.
- ATR-04: Accepted user authority survives browser logout and matcher restart.
  A stopped processor leaves one unresolved reservation; restarting matcher and
  processor retries that same execution identifier and settles once.
- ATR-05: Independent PostgreSQL observations must show the expected order,
  position, trade, receipt and transactional event snapshots. Repeated price
  notifications cannot book a second effect for an already filled order.
- ATR-06: Runtime database identities retain scoped grants; bootstrap alone owns
  migrations. Disable runtime schema auto-update and inherited seed creation.
- ATR-07: Candidate matcher broker connections require an explicit TLS endpoint,
  private credential file, platform chain trust and hostname verification. Do not
  embed credentials in URLs. Remove the inherited global `/orders` broadcast;
  publishing remains scoped by broker subject permissions.

## Fixture boundaries

The isolated hosted runner uses one disposable TLS Keycloak, one bounded
PostgreSQL and one bounded TLS NATS container, plus two Java services. HTTPS
certificates and credentials are private, ephemeral and never exported. Java
uses a fixture PKCS12 truststore; no insecure TLS switch is permitted. PostgreSQL
is an explicitly loopback-only transport exception in this campaign.

The price producer is a synthetic scoped fixture, not the full C3 market-data
application. Order notifications are best effort; settlement events are checked
in the transactional outbox here. Durable event delivery, browser consumption,
revocation and full deployed trading are cumulative acceptance gates and must not
be inferred from an HTTP status or from this candidate alone.

The campaign must preserve the earlier C3 branch, clean up only owned processes
and containers, and run separately from an occupied browser lab. Heavy validation
runs in hosted CI; source/unit work does not interrupt Citrix or use screen sharing.

## Candidate invocation

After the existing sequential Java candidate build, run:

```bash
python scripts/security-lab/verify_authenticated_trading.py --runtime-dir "$runtime" --output "$runtime/evidence/authenticated-trading.json"
```

The campaign requires the configurable provider fixture and additive broker-user
fixture hooks. The matcher broker identity can subscribe to `pricing.*` and
publish only `/accounts/62654/orders`; the synthetic price identity can publish
only `pricing.IBM` and explicitly denies subscription. Empty NATS allow lists are
not used as a denial policy.

An initially invalid service credential leaves a pending reservation and no
settlement. A private-file replacement permits the existing token client to
recover. The separate outage/restart case waits beyond the initiating access
token's actual expiry before restoring the processor; the accepted order settles
under the service identity and currently loaded acceptance policy. This does not
claim live policy revocation. Operator observation uses a fixture-held token
inside server memory; no browser response contains that bearer.

The inherited trade-service `/trade/` path still has a different payload and
legacy broker handoff. This campaign tests the explicit matcher limit-order
workflow. The generated UI must use that workflow with a learner-entered limit
price, or leave the legacy ticket unavailable; changing a URL without changing
the payload does not establish full browser trading.

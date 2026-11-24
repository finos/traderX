# Trading authorization integration

Status: direct-API candidates built and HTTP/H2 tested; runtime cutover pending. This contract refines FR-019-02 and S019-04; an API candidate is not deployed State 019 acceptance.

## Trusted identity and roles

Every protected API verifies RS256 signature, exact HTTPS issuer, configured audience, subject, issued-at/expiry and a bounded public-key trust snapshot. The private server-side subject map supplies role and account grants. Caller role/account headers, JWT role claims and browser account selections never grant privileges. One configured issuer binds the subject namespace. Unknown subjects fail closed. Operator is not a trader.

## Direct HTTP routes

| Owner | Method/path | Required decision |
| --- | --- | --- |
| trade-service | POST `/trade/` | Trader role and submitted account scope before reference/account/price calls or publication |
| order-matcher | GET `/orders` | Known principal; explicit account filter must be entitled; omitted filter returns only entitled accounts |
| order-matcher | GET `/orders/{id}` | Entitlement to account loaded from stored order |
| order-matcher | POST `/orders` | Trader role and requested account scope before creation/publication |
| order-matcher | POST `/orders/{id}/cancel` | Trader role, then entitlement to persisted order account; caller account fields cannot override ownership |
| order-matcher | POST `/orders/{id}/force-fill` | Deny for every ordinary identity in this candidate; separate audited operator action is not implemented |
| both | GET `/system/health`, `/metrics`, `/actuator/prometheus`; matcher also `/health`, `/healthz`, `/orders/open-count` | Explicit operator role; no account/trade authority implied |
| both | GET `/actuator/health` | Minimal unauthenticated liveness only |
| both | All other routes/methods | Deny by default, including documentation and legacy aliases |

Cancellation authorizes the persisted account before mutation. The current API cannot change an order's account; any future transfer/update route requires authorization under the same mutation lock. Order identifiers are not authority. Denied mutations must not call publication or mutation methods. Tests exercise real HTTP security filters and controller decisions, not merely string inspection of generated code.

Trade validation forwards the already verified initiating bearer token only to the configured account API. It must not attach that token to reference-data or pricing calls. This maintains the account API boundary rather than allowing an anonymous internal bypass.

## Integration dependencies and cutover gates

1. Inventory and protect direct trade/order routes; build deterministic overlays from the pinned C3 snapshot and verify allowed/denied behavior. Keep reference C3 unchanged.
2. Specify and implement durable authorization for background matching. A scheduler has no initiating HTTP token; do not store reusable user tokens in order rows, invent caller headers, grant the matcher arbitrary trader identity, or expose an anonymous execution endpoint. Persist accepted-order authority and authenticate the execution path, including replay/idempotency and account binding. Automatic fill must be tested after user token expiry.
3. Protect position/trade-history and people/account read routes; propagate only necessary verified context. Close alternate direct routes.
4. Integrate the Angular trading experience with the existing same-origin PKCE/session boundary. Mutation cookies require CSRF protection. UI visibility alone is never authorization.
5. Move kubelet readiness checks to the minimal `/actuator/health` endpoint before making detailed `/health` routes operator-only. Deploy pinned candidate images and identity configuration together. Existing anonymous NATS remains a separate S019-05 gate; HTTP tests do not prove messaging isolation.
6. In one deployment verify reader/trader/operator and cross-account cases, independently unchanged SQL/message outcomes after denied actions, normal settlement/cancellation, expiry/logout, operator visibility and recovery.

## Learning and evidence

An ordinary-looking request can be forbidden because of its principal, account or action. Credit application authorization for that decision, not the WAF or database grants. Record candidate versus integrated scope, test method, expected/observed layer and resulting effects. No credentials or bearer tokens enter evidence. A compiled overlay or mocked collaborator test does not establish live database settlement, browser acceptance or background-execution protection.

## Reproduction and observed scope

`render_trading_security.py` extracts each owning service from the immutable C3 commit and applies the canonical security sources. It refuses source-shape drift and existing output directories; source/input/output hashes are recorded. It does not edit reference C3 or change runtime image pins.

Run the guarded sequential Java build with the lightweight lab stopped:

```bash
python scripts/security-lab/build_trading_security.py --runtime-dir /absolute/private/runtime
```

The runtime directory is private and excluded from version control. A changed input requires rendering into a fresh build directory; existing build output is never silently patched. The CI job performs the same render and Java tests sequentially on its isolated runner.

Tests use actual RSA-signed JWTs and the Spring Security HTTP filter chain. Controller collaborator checks prove that denials cannot call publication/mutation operations. A separate full Spring Boot/H2 matcher test observes stored rows before/after denied create/cancel attempts and an allowed cancellation. This is database-backed component verification, not independent PostgreSQL or live NATS settlement evidence. Real Keycloak/browser integration and background execution remain separate gates; the deployed candidate images are unchanged.

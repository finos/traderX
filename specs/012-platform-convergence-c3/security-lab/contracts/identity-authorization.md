# Identity and business authorization

Status: real provider/token and account-API authorization are verified in the lightweight
local candidate. Browser-session work follows [browser-session.md](browser-session.md);
Angular and deployed C3 identity acceptance remain open. This
contract is independent of the console access-code gateway, which authenticates an
operator to bounded experiments and is not TraderX end-user identity.

## Learning objective

Demonstrate that a syntactically valid request may be forbidden by business policy.
Attribute the decision to application authorization, and prove that gateway login,
WAF inspection and a scoped SQL role do not themselves establish account ownership.

## Roles and trusted context

Use distinct synthetic read-only, trader and operator principals. Account entitlement
is a server-side mapping from stable issuer/subject identity to permitted synthetic
accounts. Do not treat a UI account selection, request header, URL account ID or
caller-supplied role as an entitlement. Operator access is explicit and does not
implicitly grant trading privileges; fixture reset is a separately audited action.

| Operation | Read-only | Trader | Operator |
| --- | --- | --- | --- |
| Read account, positions, trades and account order events | Assigned accounts | Assigned accounts | Only explicitly granted account scope |
| Submit/cancel orders or trades | Deny | Assigned accounts and allowed business transitions | Deny unless separately granted trader role |
| Observe operator health/metrics/global order feed | Deny | Deny | Allow approved operator routes |
| Provision/reset synthetic fixtures | Deny | Deny | Separate fixed lab action, never general SQL/shell access |

Before implementation, inventory every REST/stream route and owner service against
C3 contracts; map list, detail, create, update and cancellation operations as well as
nested IDs. List endpoints must filter unauthorized accounts and detail endpoints
must not leak their content. Match cancellation target ownership using persisted
order data, not the account ID supplied in the cancellation request.

## Token and session acceptance gates

Keycloak 26.8.2 is pinned and verified for the [isolated compatibility fixture](identity-fixture.md). Its production deployment/session integration remains a separate gate. Browser authentication uses authorization-code flow with PKCE and
explicit redirect URIs. Confidential client secrets never enter browser bundles.
APIs validate signature, allowed algorithm, exact issuer/audience and expiry before
using identity. Reject malformed, expired, wrong-audience, wrong-issuer and unsigned
tokens; do not trust identity headers from an unauthenticated upstream. Signing-key
rotation and provider outage behavior need explicit tests; avoid insecure fallback.

Evaluate a same-origin backend session for browser credentials. If cookies authorize
mutations, enforce CSRF and secure cookie properties. If bearer tokens are used,
specify storage, refresh and logout behavior before implementing them. Record only
stable principal IDs, request/run IDs and policy decisions in evidence, never tokens.

Services validate the initiating user where business authorization is required;
service identity alone cannot authorize arbitrary user-account operations. Define
and verify how signed user context crosses HTTP/NATS processing boundaries. A
fully compromised process may misuse its own legitimate database grants; this
remains the separate assumed-compromise exercise, not a claim solved by login.

## Browser-to-NATS dependency

Do not ship static service credentials to the browser. A dedicated credential issuer
must derive broker grants from verified user identity and server-side entitlements,
with no publish rights for ordinary account subscribers. Evaluate a broker-supported
short-lived credential mechanism, including expiration on established connections,
revocation, reconnect and entitlement changes; unsupported behavior blocks the live
cutover rather than becoming an undocumented exception. Native JWT credentials or
auth callout are candidates for a compatibility exercise, not implemented controls.

Map dynamic account subjects under the NATS contract before issuing grants. Ordinary
users cannot request global order subscriptions. Issuer signing material and service
credentials are separately scoped; compromised application workloads cannot simply
mint arbitrary broker users. The issuer's own compromise is an explicit trust limit.

## Sequencing and acceptance

1. Inventory routes and entitlements; specify ownership storage and migration for
   synthetic users/accounts while preserving prior states.
2. Prove provider/token/session compatibility and strict negative cases in isolation.
3. Add opt-in authorization to each owning service and test direct-backend access,
   object-level and list filtering, trading/cancellation rules and positive workflows.
4. Add scoped browser messaging credentials and the coordinated subject migration;
   verify expiry/revocation on both new and established connections.
5. Cut over only after ordinary trading, operator routes, reconnect, recovery and all
   denial cases pass together. Keep the existing console gateway separately protected.

Every denied scenario has a valid permitted counterpart and verifies no database or
message-processing effect. Test spoofed role/account headers, cross-account IDs,
expired credentials, wrong audiences, global subscriptions, reconnect after logout,
and operation replay where applicable. Record expected layer, actual policy decision,
settled effect and limitation. Missing provider/issuer evidence is inconclusive.

## First account-service integration slice

[Eight inventoried account and membership routes](account-authorization-routes.json) are the first enforcement target. Membership mutations are part of the authorization boundary: ordinary users must not grant themselves access through accountuser writes. The current accountuser detail route resolves an account ID and returns its first membership; authorize that account before returning the membership. Bind legacy usernames to verified issuer/subject identities through a trusted mapping. The route inventory is complete only for these two controllers. Local candidate enforcement
is verified; deployed C3 enforcement remains unaccepted.

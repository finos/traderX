# Read API authorization candidates

Status: position/history candidate implemented; validation status is recorded
separately below. People-service is inventoried, not yet hardened. No deployed
State 019 acceptance or Angular/session cutover is implied.

## Pinned route inventory and decisions

| Service | Route | Candidate decision |
| --- | --- | --- |
| position-service | GET `/positions/{accountId}` | Require account entitlement before repository access |
| position-service | GET `/positions/` | Query only explicitly entitled accounts; never use global list for user reads |
| position-service | GET `/trades/{accountId}` | Require account entitlement before repository access |
| position-service | GET `/trades/` | Query only explicitly entitled accounts; never use global history for user reads |
| position-service | GET `/health/ready`, `/health/alive`, `/metrics`, `/actuator/prometheus` | Explicit operator role |
| position-service | GET `/actuator/health` | Minimal public liveness |
| position-service | Other routes/methods | Deny, including mutation methods, documentation, slashless aliases and direct `/error` |
| people-service | GET `/People/GetPerson` | Existing directory lookup by logon ID or employee ID; authorization not implemented |
| people-service | GET `/People/GetMatchingPeople` | Existing directory-wide text search; authorization not implemented |
| people-service | GET `/People/ValidatePerson` | Existing directory existence check; authorization not implemented |

The position/history candidate reuses the canonical RS256 resource-server
validation and immutable server-side subject-to-role/accounts mapping. It requires
exact configured issuer, audience, valid timestamps, subject and bounded key
trust. JWT role/account claims and caller headers do not grant rights. Operator
role alone grants no account data; an operator with no account grants gets empty
user-data collections and cannot retrieve an account detail.

Every returned row must match the account being queried. This defends the
response boundary even if a downstream implementation accidentally returns a
foreign-account row. Collection reads make per-entitled-account repository calls,
which also avoid loading unrelated rows before filtering. A large production
entitlement set may require a bounded bulk query; this candidate prioritizes
explicit, testable scopes for the lab.

The inherited catch-all controller exception handler no longer turns access
denials into HTTP 500 or exposes database exception text. Access denials return
403; other read failures return a fixed generic message. Internal error dispatch
is permitted so normal HTTP status codes survive container error handling; an
external request to `/error` remains denied.

## People-service dependency

People-service is .NET 9, with a JSON directory and three unauthenticated read
routes plus wildcard CORS/Swagger in the pinned source. A directory identity is
not automatically an OIDC subject or an account entitlement. Before implementing
its overlay, specify a trusted subject-to-person binding and which co-account
members each user may discover, or explicitly restrict directory lookup/search
to operators. Do not infer those grants from query parameters, displayed names,
JWT role claims or an unsigned header from account-service.

The existing account candidate permits read routes only, so its people-backed
membership mutations are not enabled. Enabling those mutations or the Angular
person picker must be coupled to people authorization and context propagation.
Until that integration is validated, the old people-service is not part of a
claim that all direct read backends are protected.

## Reproduction and test boundaries

```bash
python scripts/security-lab/render_read_security.py --output-dir /absolute/private/position-candidate
python -m unittest discover -s scripts/security-lab -p test_read_security.py
```

The renderer extracts only position-service from the immutable C3 snapshot,
refuses an existing output directory/source-shape drift, removes wildcard CORS,
and records source/input/output hashes. It leaves prior TraderX states and
runtime image pins unchanged. Build the rendered service sequentially with
Java 21 and its pinned Gradle wrapper after acquiring the normal lab resource
window; it adds no second Kubernetes cluster.

Prepared Java tests use real RSA-signed tokens through Spring's HTTP filters.
They check rejected identities and cross-account requests before service calls,
scoped list queries, forged headers/claims, wrong downstream rows, operator
separation, disabled routes and error redaction. A separate full Spring Boot/H2
case reads both own/foreign stored rows and verifies data is unchanged. H2 and
mocked collaborators do not establish PostgreSQL, live Keycloak, browser or
full-deployment acceptance.

## Observed component validation (25 November 2026)

The constrained Java 21/Gradle build and bootJar pass: ten signed-token HTTP tests
and one full Boot/H2 stored-data isolation test, with zero failures or skipped
tests. Two Python tests verify deterministic generation, hashes, source-shape
refusal and protection of existing output directories. The integration owner
retains the private generation/build evidence and will record the consolidated
state result. No people, live Keycloak, PostgreSQL, UI or deployed acceptance is
claimed by these results.

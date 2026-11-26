# Operator-only directory boundary

Phase-one decision: the directory is an operator capability. An account grant is
not a grant to search the people directory. Ordinary reader/trader identities may
trade and read their own accounts without enumerating people. Account membership
mutations/person-picker workflows remain disabled until a separately specified
trusted subject/person binding exists.

- PEO-01: Validate RS256 signature, exact HTTPS issuer/audience, subject, issued-at,
  expiry and a finite trusted public-key snapshot on every directory request.
- PEO-02: Derive operator access from a private server-owned subject/role map.
  JWT role claims, caller account/role headers and query parameters grant nothing.
- PEO-03: Permit only GET on the three inherited directory endpoints for that
  operator. Remove wildcard CORS and Swagger; reject other routes and methods.
  Expose only a minimal anonymous `/health/alive` response.
- PEO-04: Bound lookup/search parameters and result counts, redact directory
  error logs, and return generic failures. No directory data in denial responses.
- PEO-05: Keep changes in a deterministic opt-in generator over the pinned C3
  snapshot. Earlier states and deployed images remain unchanged until acceptance.

The candidate uses Microsoft's supported JWT bearer middleware API, pinned to
the .NET 9 line for this inherited service. Signature/issuer/audience/lifetime
validation follows the [Microsoft configuration guidance](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication?view=aspnetcore-9.0)
and [versioned package](https://www.nuget.org/packages/Microsoft.AspNetCore.Authentication.JwtBearer/9.0.23).
This is a compatibility pin, not a claim that the entire dependency graph or
platform lifecycle has passed release review.

Acceptance runs the actual generated .NET service with real Keycloak tokens,
checking all three subjects, wrong signatures, audience/issuer rejection,
unavailable operator routes, bounded searches, expired trust and unchanged
directory bytes. The fixture's API loopback HTTP is explicit; deployment needs
gateway/backend TLS and direct-backend policy together. The API remains outside
the public browser route allowlist.

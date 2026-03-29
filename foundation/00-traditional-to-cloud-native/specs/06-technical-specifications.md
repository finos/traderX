# 06 Technical Specifications for Regeneration

This spec captures concrete technical constraints required to regenerate an implementation close to current TraderX behavior.

## Technology Constraints

- Java services: Spring Boot + Gradle
- Reference data: NestJS + npm
- People service: ASP.NET Core + dotnet
- Trade feed: Node.js + Socket.IO
- Primary frontend: Angular
- Edge: Nginx
- Data store: H2 server style runtime (current baseline)

## Runtime Port Contract

- ingress: `8080`
- database: `18082` (`+ 18083, 18084`)
- reference-data: `18085`
- trade-feed: `18086`
- account-service: `18088`
- people-service: `18089`
- position-service: `18090`
- trade-processor: `18091`
- trade-service: `18092`
- web-front-end-angular: `18093`

## Service Dependency Contract

- trade-service -> account-service, reference-data, people-service, trade-feed
- trade-processor -> database, trade-feed
- account-service -> database, people-service
- position-service -> database
- web-front-end-angular -> account/trade/position/reference/people/trade-feed
- ingress -> ui + backend services

## Cross-Origin Runtime Policy (Pre-Ingress)

- In baseline local mode (before ingress), browser-facing service APIs must permit cross-origin requests from local UI origins on different ports.
- CORS policy must be explicitly configured in service runtime bootstrap (not assumed from proxy behavior).

## API Contract Sources

- `account-service/openapi.yaml`
- `trade-service/openapi.yaml`
- `position-service/openapi.yaml`
- `trade-processor/openapi.yaml`
- `reference-data/openapi.yaml`
- `people-service/openapi.yaml`

## Event Topic Contract

- inbound trade order topic: `/trades`
- account trade updates: `/accounts/{accountId}/trades`
- account position updates: `/accounts/{accountId}/positions`

## Known Divergence to Resolve in Spec-Generated Target

- React frontend exists in the historical codebase but is excluded from the active spec-first target for now.

# 10 Base State: Uncontainerized Process Runtime

This document defines the official Level-0 operational base case for TraderSpec:

- no containers
- local processes
- known startup order
- fixed default ports
- explicit dependency wiring via host/port env

## Default Port Contract

- database tcp: `18082`
- database pg: `18083`
- database web: `18084`
- reference-data: `18085`
- trade-feed: `18086`
- account-service: `18088`
- people-service: `18089`
- position-service: `18090`
- trade-processor: `18091`
- trade-service: `18092`
- web-front-end-angular: `18093`

## Startup Order

1. `database`
2. `reference-data`
3. `trade-feed`
4. `people-service`
5. `account-service`
6. `position-service`
7. `trade-processor`
8. `trade-service`
9. `web-front-end/angular`

## Environment Wiring

All inter-service hostnames resolve to `localhost` in this base state:

- `DATABASE_TCP_HOST=localhost`
- `PEOPLE_SERVICE_HOST=localhost`
- `ACCOUNT_SERVICE_HOST=localhost`
- `REFERENCE_DATA_HOST=localhost`
- `TRADE_FEED_HOST=localhost`

## Cross-Origin Requirement (Base State)

Because services and UI run on separate localhost ports in this state, service HTTP endpoints must support CORS for local cross-origin calls until ingress/proxy-based routing is introduced in later states.

## Health/Readiness Signals

- database: tcp port `18082` open
- reference-data: HTTP port `18085` open
- trade-feed: HTTP port `18086` open
- people-service: HTTP port `18089` open
- account-service: HTTP port `18088` open
- position-service: HTTP port `18090` open
- trade-processor: HTTP port `18091` open
- trade-service: HTTP port `18092` open
- angular ui: HTTP port `18093` open

## Scope Note

This base state runs from generated component outputs assembled into `generated/code/target-generated`.

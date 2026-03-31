---
title: "State 003: Containerized Compose Runtime (NGINX Ingress)"
---

# State 003 Learning Guide

## Position In Learning Graph

- Previous state(s): [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized)
- Next state(s): [004-kubernetes-runtime](/docs/learning/state-004-kubernetes-runtime), [007-messaging-nats-replacement](/docs/learning/state-007-messaging-nats-replacement), [009-postgres-database-replacement](/docs/learning/state-009-postgres-database-replacement)

## Rendered Code

- Generated branch: [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `002-edge-proxy-uncontainerized`: [code/generated-state-002-edge-proxy-uncontainerized...code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-containerized-compose-runtime)

## Plain-English Code Delta

- **Code focus:** Adds Dockerfiles and Compose assembly for all baseline services.
- **Runtime behavior:** Keeps behavior from state 002 but moves orchestration to containers.
- **Learning takeaway:** Establishes the containerized baseline that other architecture branches build from.

## Run This State

```bash
./scripts/start-state-003-containerized-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime)
- Architecture: [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture)
- Flows / topology: [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology)


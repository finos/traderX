# 03 Current System Moving Parts (Observed in Repository)

This inventory anchors redesign work to current TraderX behavior.

## Service Modules

- `account-service` (Java/Spring)
- `trade-service` (Java/Spring)
- `position-service` (Java/Spring)
- `trade-processor` (Java/Spring)
- `reference-data` (Node/NestJS)
- `people-service` (.NET)
- `trade-feed` (Node)
- `database` (schema and runtime service)
- `ingress` (nginx templates)
- `web-front-end/angular`
- `web-front-end/react` (legacy/optional; excluded from current spec-first target scope)

## Supporting Assets

- `docker-compose.yml` orchestration
- `gitops/` manifests and local overlays
- `openapi.yaml` per service modules
- Docs under `docs/` and Docusaurus site under `website/`

## High-Level Runtime Interaction

1. Frontend calls account, trade, position, people, and reference APIs.
2. Trade lifecycle flows through trade capture, processing, and position updates.
3. Trade feed and messaging components support event-style updates.
4. Database holds persistent state for service workflows.

## Redesign Constraint

Any generated codebase in `generated/code/target-generated` must preserve these core workflows unless a spec intentionally changes them.

# Reference-Data Technical Specification

## Component Identity

- Component ID: `reference-data`
- Type: service
- Baseline language/framework: TypeScript + NestJS
- Build/run tool: npm
- Default port: `18085`
- Contract file: `reference-data/openapi.yaml`

## Dependency Model

- Upstream dependency: none required at runtime for stock lookup.
- Downstream consumers: `trade-service`, `web-front-end-angular`.

## Required Endpoints

- `GET /stocks`
- `GET /stocks/{ticker}`
- `GET /health`

## API Contract Rules

- Response media type: `application/json`.
- Stock payload field names must match existing consumer expectations:
  - `ticker`
  - `companyName`

## Runtime Configuration

- `REFERENCE_DATA_SERVICE_PORT` (default `18085`).
- `CORS_ALLOWED_ORIGINS` (default `*`; comma-separated allowlist supported).
- Baseline data file: `data/s-and-p-500-companies.csv` (`Symbol`, `Security` columns used for API payload mapping).

## Build And Run Behavior

- Install: `npm install`
- Start: `npm run start`
- Health probe: `http://localhost:18085/health`
- CORS: enabled in bootstrap for pre-ingress local cross-origin calls.

## Source Layout Target (Generated)

- Target path: `generated/code/components/reference-data-specfirst`
- Required artifacts:
  - NestJS app bootstrap
  - controller/service for stocks endpoints
  - CSV data-loader for baseline stock universe
  - baseline CSV data file (`s-and-p-500-companies.csv`)
  - health endpoint implementation
  - OpenAPI definition aligned with runtime behavior

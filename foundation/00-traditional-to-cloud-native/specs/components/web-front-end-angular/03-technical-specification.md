# Web-Front-End (Angular) Technical Specification

## Component Identity

- Component ID: `web-front-end-angular`
- Type: UI
- Baseline language/runtime: TypeScript + Node.js
- Framework/libraries: Angular + Socket.IO client
- Build/run tool: npm (`npm run start`)
- Default port: `18093`

## Runtime Configuration

- Environment API base URLs shall map to baseline local ports:
  - account-service `:18088`
  - reference-data `:18085`
  - trade-service `:18092`
  - position-service `:18090`
  - trade-feed `:18086`

## Module/Feature Scope

- Trade page module and components:
  - trade ticket entry
  - trade blotter
  - position blotter
- Service layer:
  - account lookup client
  - symbols/reference-data client
  - trade submit client
  - position/trade blotter client
  - trade-feed socket subscription client

## Integration Contracts

- HTTP APIs:
  - `GET /account/`, `GET /account/{id}` from account-service
  - `GET /stocks` from reference-data
  - `POST /trade/` from trade-service
  - `GET /trades/{accountId}`, `GET /positions/{accountId}` from position-service
- WebSocket topics:
  - `/accounts/{accountId}/trades`
  - `/accounts/{accountId}/positions`

## Build And Run Behavior

- Install: `npm install` (or `npm ci`)
- Run: `npm run start`
- Readiness: TCP probe on `localhost:18093`

## Source Layout Target (Generated)

- Target path: `TraderSpec/codebase/generated-components/web-front-end-angular-specfirst`
- Required generated artifacts:
  - Angular app source with route/component/service wiring for the baseline trade flow
  - npm manifests and run scripts
  - Environment configuration mapping for baseline local ports

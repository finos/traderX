# Trade-Feed Technical Specification

## Component Identity

- Component ID: `trade-feed`
- Type: service
- Baseline language/runtime: JavaScript + Node.js
- Framework/libraries: Express + Socket.IO
- Build/run tool: npm (`npm run start`)
- Default port: `18086`

## Runtime Configuration

- `TRADE_FEED_PORT` (default `18086`)
- `CORS_ALLOWED_ORIGINS` (default `*`)

## Command Contract

- Inbound socket commands:
  - `subscribe` (topic string)
  - `unsubscribe` (topic string)
  - `unusbscribe` (legacy typo compatibility)
  - `publish` (object with `topic`, `payload`, optional `type`)
- Outbound socket command:
  - `publish` (wrapped message envelope)

## Message Envelope

- `type` (default `message` when omitted)
- `from` (sender id/system)
- `topic` (string)
- `date` (unix epoch milliseconds)
- `payload` (object)

## HTTP Contract

- `GET /` returns local inspector HTML page.

## Build And Run Behavior

- Install: `npm install` (or `npm ci`)
- Run: `npm run start`
- Readiness: TCP probe on `localhost:18086`

## Source Layout Target (Generated)

- Target path: `generated/code/components/trade-feed-specfirst`
- Required generated artifacts:
  - `index.js` broker implementation
  - runtime package manifest with start command
  - inspector HTML page for local diagnostics

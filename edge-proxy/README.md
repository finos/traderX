# Edge Proxy (Spec-First Generated)

This component is generated from:

- state pack: `specs/002-edge-proxy-uncontainerized`
- routing spec: `specs/002-edge-proxy-uncontainerized/system/edge-routing.json`

## Run

```bash
npm install
npm run start
```

## Runtime Contract

- listen port: `18080` (env override: `EDGE_PROXY_PORT`)
- web upstream: `http://localhost:18093` (env override: `EDGE_PROXY_WEB_TARGET`)
- configured API routes: `6`

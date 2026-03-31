# State 010 Pricing Awareness and Market Data Runtime

Generated compose runtime for:

- `specs/010-pricing-awareness-market-data`

Run:

```bash
docker compose -f docker-compose.yml up -d --build
```

Entrypoints:

- UI/ingress: `http://localhost:8080`
- NATS monitor: `http://localhost:8222/varz`
- NATS websocket (ingress proxied): `ws://localhost:8080/nats-ws`
- Price publisher API: `http://localhost:18100/prices`

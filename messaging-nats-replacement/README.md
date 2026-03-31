# State 007 Messaging NATS Replacement Runtime

Generated compose runtime for:

- `specs/007-messaging-nats-replacement`

Run:

```bash
docker compose -f docker-compose.yml up -d --build
```

Entrypoints:

- UI/ingress: `http://localhost:8080`
- NATS monitor: `http://localhost:8222/varz`
- NATS websocket (ingress proxied): `ws://localhost:8080/nats-ws`

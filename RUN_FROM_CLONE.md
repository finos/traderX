# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-002-edge-proxy-generated.sh
```

Endpoints:
- Browser entrypoint (edge proxy): `http://localhost:18080`
- Angular direct dev server: `http://localhost:18093`
- Edge proxy health: `http://localhost:18080/health`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

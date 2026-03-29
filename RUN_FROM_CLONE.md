# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

Endpoints:
- UI: `http://localhost:18093`
- Reference data: `http://localhost:18085/stocks`
- Trade service swagger: `http://localhost:18092/swagger-ui.html`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

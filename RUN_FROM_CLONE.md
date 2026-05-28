# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

```powershell
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-base-uncontainerized-generated.ps1 -BuildOnly
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-base-uncontainerized-generated.ps1
```

Endpoints:
- UI: `http://localhost:18093`
- Reference data: `http://localhost:18085/stocks`
- Trade service swagger: `http://localhost:18092/v3/api-docs`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

```powershell
./scripts/status-base-uncontainerized-generated.ps1
./scripts/stop-base-uncontainerized-generated.ps1
```

## Stable Entrypoints

Use root wrappers for this generated branch:

```bash
./start-env.sh   # start this state runtime
./status-env.sh  # runtime health/status
./stop-env.sh    # stop runtime
./test-env.sh    # state smoke/validation
```

```bat
start-env.bat
status-env.bat
stop-env.bat
test-env.bat
```

Wrappers intentionally delegate to numbered state scripts to maximize reuse while keeping clone-first commands stable.

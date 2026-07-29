# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-003-agentic-harness-foundation-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

```powershell
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-state-003-agentic-harness-foundation-generated.ps1 -BuildOnly
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-state-003-agentic-harness-foundation-generated.ps1
```

Endpoints:
- Browser entrypoint (edge proxy): `http://localhost:18080`
- API explorer (edge proxy): `http://localhost:18080/api/docs`
- Angular direct dev server: `http://localhost:18093`
- Edge proxy health: `http://localhost:18080/health`

Harness metadata:
- `AGENTS.md`
- `ARCHITECTURE.md`
- `CONTRIBUTING.md`

Status / stop:

```bash
./scripts/status-state-003-agentic-harness-foundation-generated.sh
./scripts/stop-state-003-agentic-harness-foundation-generated.sh
```

```powershell
./scripts/status-state-003-agentic-harness-foundation-generated.ps1
./scripts/stop-state-003-agentic-harness-foundation-generated.ps1
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

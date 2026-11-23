# Local experiment console contract

Status: implemented and locally verified for SL-T17; local operator tool, with user-authorized temporary authenticated tunnel access under [remote-console.md](remote-console.md).

## User stories and requirements

- SL-UI-01: A learner selects one of ten implemented demonstrations, reads its expected outcome and limitations, then runs it and sees actual progress, results and downloadable evidence. Baseline trading, network/admission, WAF mode comparison and live business-workload restrictions are available. Unimplemented controls are visibly planned and cannot be run.
- SL-UI-02: Distinguish historical verification from the current run. Never label C3 hardened based on fixture success. Show failed, running, passed and inconclusive states without manufacturing results. A test failure remains a failure even when its process produced partial evidence.
- SL-UI-03: Display a roadmap distinguishing specification coverage, implementation and measured validation. Describe remaining identity, database/broker, workload/network/image, runtime, recovery and CCC work. CALM is a separate planned follow-on state; supplier evaluation depends on its integration contract.
- SL-UI-04: Serialize runs, use fixed server-side commands and the named isolated lab only; do not accept shell text, arbitrary targets, file paths, profiles or payloads from the browser. Bound execution to 15 minutes and preserve failed/timeout evidence.
- SL-UI-05: Bind only loopback. Enforce expected Host, same-origin writes, JSON content type and a per-process CSRF token. Reject oversized/malformed requests. Never expose credentials, kubeconfig, generated baseline manifests or arbitrary filesystem paths. Evidence URLs are selected by server-owned run IDs.
- SL-UI-06: Persist each run ID, start/end times, exit code, configuration/source hashes, output log and structured result under the private runtime directory. Hash artifacts on download. Interrupted runs are marked inconclusive on server restart. Do not call this tamper-proof storage or signed compliance evidence.
- SL-UI-07: Accessible keyboard controls, readable contrast, responsive layouts, visible busy/error states, text-safe rendering and no external UI/CDN dependencies.

## API

`GET /api/state`: scenario catalog, roadmap, historical verification, runner state, run summaries and CSRF token. `POST /api/runs` accepts exactly `{ "scenario": "baseline" | "platform" | "waf" | "workloads" | "support" | "database" | "collector" | "observability" | "sql" | "nats" }` and requires `X-Lab-CSRF`. Returns 202 with run ID, 409 if busy. `GET /api/runs/<uuid>` returns summary plus bounded log tail and structured results. `GET /api/runs/<uuid>/evidence` downloads a JSON bundle containing source/configuration hashes, result, log and artifact hashes. Other methods and paths fail closed. Static assets are explicitly allowlisted.

## Execution and acceptance

Baseline runs the existing C3 smoke wrapper against localhost:18080 and the dedicated kubeconfig. Network/admission reruns only owned fixtures in `security-platform-check`; WAF uses its owned Docker fixture names and localhost:18443, removing fixture containers afterward. All controls share the same serial queue. No reset of the main C3 database is exposed; smoke tests do mutate its synthetic records, which the interface states before launch.

Tests must prove arbitrary action/body rejection, cross-origin and Host rejection, concurrent-run refusal, persisted success/failure/interruption, and text-safe result display. Verify a real demonstration from the browser when computer-use access is available, with resulting evidence downloadable. Browser QA limits must be reported. Completion of this console does not complete SL-T12's compromise/canary/reset or external authoritative-collector requirements.

The workload experiment inspects the live eight-service profile and its kernel process settings, verifies Kubernetes permission denials, and submits eleven unsafe Deployment variants as server dry-runs. It writes/removes one bounded /tmp probe file and verifies a root-filesystem write is denied. It does not apply or roll back the profile.

The support experiment verifies six supporting workloads plus direct-Pod and ephemeral-container admission for the protected labels/identities. Valid Pod positive controls and unsafe variants are server dry-runs; no debug container is installed.

The database experiment verifies current process/storage controls and the separately recorded historical migration/restart proof. It does not restore, migrate, restart or reset the database. The UI must distinguish the current PVC observation from historical recovery evidence.

The collector experiment checks application-wide admission, the isolated collector exception, identity permissions and a fresh Loki log marker. It creates and cleans up one bounded synthetic log Pod. Current runs verify Restricted; historical Baseline runs retain their actual policy label and limitations. Restricted does not itself require read-only roots, resource bounds or token suppression.

The observability experiment verifies four live process restrictions, PVC status, admission denials and historical file-copy/API retention evidence. It must not claim that a historical check is a new restore or that local volumes establish cluster-loss recovery.

The SQL experiment follows database-permissions.md: four real logins, exact table
grants, rollback-only operations and SQLSTATE authorization denials. It also checks
Secret/DDL admission and rejects use of the retired demo bootstrap password. One
account sequence value is allocated; no synthetic test row survives rollback.

After SL-T09c, the SQL experiment also rechecks retired position-service password
rejection and displays historical old-pool survival/drain and post-rotation trading
evidence. No credential rotation is initiated by a console click.

The NATS experiment follows nats-authorization.md: disposable pinned broker, TLS/WSS protocol clients, exact synthetic account permissions and 28 checks. Its results include explicit fixture limitations. It does not modify live C3 authorization.

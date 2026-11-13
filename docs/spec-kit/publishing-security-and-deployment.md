# Publishing security and verified demo deployment

Generated snapshots retain the one-snapshot ancestry contract: regenerate from the canonical sources, reset to the configured base, and publish with force-with-lease. Security results never require an extra commit on a generated branch.

## Normal path

1. Generate the state and run `pipeline/publish-generated-state-branch.sh <state-id> --push`. Local dependency scans have independent acquisition and execution deadlines. Configure `TRADERX_SECURITY_PULL_TIMEOUT_SECONDS` (default 120) and `TRADERX_SECURITY_SCAN_TIMEOUT_SECONDS` (default 1800) as positive integers. Python 3 is required. The deadline kills the operation's process group; Docker cleanup has an additional maximum five-second allowance and targets only its unique scanner container. No Docker daemon, unrelated container, or shared scanner cache is removed.
2. Wait for **Build and Test Snapshot**, **Security Scanning**, and **Build and Publish Application Images** on the exact generated commit. Every job must succeed; missing, skipped, pending, failed, cancelled, timed-out and neutral results are ineligible. A successful image build cannot substitute for dependency security. The newest push run and its current attempt are used, never a previous successful run. Rerun the push workflow after fixing infrastructure; manually dispatched substitute workflows are not accepted.
3. Dispatch **Redeploy Live Demo** from the canonical branch with the target host. Leave `snapshot` empty to resolve the generated branch tip once, or supply a full SHA to roll back to an older snapshot. Overrides still require successful push runs from that state's generated branch and retained exact-run artifacts. The workflow verifies expected jobs, including **Runtime Image Security**, and checks the image digest, complete runtime lock, snapshot identity, inventory and OCI proofs. Original evidence may be older than 24 hours; missing, future-dated, duplicated or substituted evidence still blocks deployment.
4. The host checks out that SHA, verifies the complete authorized service inventory and OCI platform-digest proofs, substitutes all scanned digests, and refreshes the pinned scanner's vulnerability and Java database metadata. It checks their freshness and rescans all authorized images for HIGH/CRITICAL findings before replacement. It does not rebuild images or resolve new infrastructure tags at deployment time. The normal path blocks on scanner/database failure or findings and starts Compose with `--no-build --wait` only after successful scans. Neither `latest` nor a subsequently changed tag can change any authorized runtime image.
5. The workflow retains `deployment-authorization-*` as its audit artifact, and `infrastructure-scans-*` includes `scan-review.json` with the database timestamps, results and any emergency exceptions. The host records the deployed snapshot, run URLs, attempts, timestamp and complete resolved service image set in `~/traderx/.traderx-deploy/deployed.json` and a SHA-named history file only after Compose reports success. The directory is private because resolved Compose configuration may contain environment values.

For direct generated-bundle use, authenticate `gh` with read access to repository Actions, set `TRADERX_SNAPSHOT` to the full SHA, and run `runtime/deploy/aws-ec2-compose/deploy.sh --use-ghcr`. This performs the same remote authorization. `--dry-run` validates the SHA format and describes the operation without contacting or modifying the host. Python 3, Git, Docker Compose with `--wait` support, outbound GitHub/GHCR/Trivy access and the existing demo runtime prerequisites must be available. The live workflow no longer invokes an unverified `~/redeploy.sh`; migrate host-specific settings into its environment/runtime configuration before the first deployment.

The non-GHCR bundle path and clone-first scripts remain available for local development builds. They do not grant live-demo deployment eligibility.

Build-only container states also require complete runtime inventory scans. Their Docker scan matrix records immutable local image IDs, raw reports and exact snapshot/run/attempt evidence. A dependent job validates every built-image record and scans all pulled runtime images, including Kubernetes init containers, sidecars and the Sail companion. These reports do not grant publication or deployment authorization. API Explorer is included wherever Kubernetes runs it as a separate image.

## Failure recovery

Use the workflow's `preflight_only=true` input to authorize the exact snapshot,
check it out on the host, pull and scan all authorized runtime images, and stop before
Compose pull/up or writing a deployment record. Direct helper invocation supports
`--preflight-only` and `--report-dir <new-private-directory>`. This mode changes
the host checkout and image cache; it is not a read-only host diagnosis.

The host inventories all runtime image blockers instead of stopping at the first
finding. Each scan has a ten-minute deadline and scoped scanner cleanup. The
workflow retrieves `infrastructure-scans-<run>-<attempt>` diagnostics even when
scans fail: an allowlisted per-service status and finding count, without raw
Trivy reports or stderr. Missing reports, malformed results, scanner failures
and HIGH/CRITICAL findings block normal replacement. These summaries are
diagnostic artifacts, not successful runtime-image authorization. Detailed
scanner output must be kept in a suitably restricted location when needed.

Issue [#487](https://github.com/finos/traderX/issues/487) tracks runtime-image coverage
and state 009 recovery. Generated convergence publishing now requires complete
runtime-image scan evidence; preflight alone cannot make vulnerable images eligible.
The deployment-time vulnerability database must be no older than 24 hours.
The Java artifact-mapping database has a separate 96-hour limit because its
refresh metadata permits a 72-hour cycle; this does not extend vulnerability-data freshness. Before replacement, diagnose any existing 502 independently,
identify the live Compose project and database volume, and back up PostgreSQL.
Compose `--wait` alone does not establish application or trading-flow readiness.

Local reports live under `ci/local-security-reports/<project>/`. `acquisition.json` and `result.json` distinguish success (exit 0), findings (10), infrastructure failure (20), timeout (124), and cancellation (130). Dependency-Check's findings exit status is mapped separately from its analyzer/update failures. The overall `ci/local-security-status.json` stays incomplete if execution stops early.

For acquisition failures, restore registry/Docker access and rerun; increase the acquisition deadline only when the download needs more time. For scanner execution failures, restore its database/NVD access or adjust the execution deadline. Reusing an existing database via `TRADERX_DEPENDENCY_CHECK_NO_UPDATE=1` remains supported. Inspect the named container if cleanup could not be confirmed. Findings require remediation or reviewed, narrowly scoped canonical suppression changes, followed by regeneration and successful CI.

`--skip-cve-scan` / `TRADERX_SKIP_CVE_SCAN=1` and `--skip-prepublish-gate` explicitly record **deferred_to_ci** in snapshot metadata. They allow publishing for CI evaluation; they do not waive deployment checks. Compilation and other local skips likewise cannot bypass the required remote workflows.

After all pulls and scans succeed, state 009 briefly stops only its verified Compose project to take a physical PostgreSQL 16 backup. The helper rejects unexpected writers, nested mounts, data symlinks and insufficient backup space before stopping containers. It records a private backup checksum before startup. A failed backup attempts to resume the prior project without starting a competing database writer. If Compose fails partway through startup, it resumes only retained, unchanged containers where safe; it never replaces newer containers or restores the database automatically. No successful deployment record is written on failure. Inspect service health and use the last recorded digest set for incident diagnosis. Rollback through the normal workflow requires republishing the intended source as the current generated snapshot and completing its checks; the gate deliberately rejects old branch tips. Do not rerun with `latest` as a workaround.

## Emergency deployment

Repository writers may select `break_glass=true` and provide a non-sensitive,
single-line incident reason of 10–500 characters. The workflow attempts the
normal fresh database downloads and all image scans, but can continue when the
scanner or database is unavailable or stale, or scans report HIGH/CRITICAL
findings. The actor, reason and scan exceptions are recorded in the deployment
authorization and host audit; scan details remain in the scan artifact. This is
an explicit security risk and does not waive snapshot provenance, successful
original checks, inventory, immutable digests, platform checks or database
backup safeguards. It applies to that deployment only. Run a normal
`preflight_only` scan as soon as possible and remediate any findings. Protecting
this path with reviewer approval requires repository environment configuration;
currently any repository writer can use it.

The `diagnose_only` mode produces structured current container status, restart
counts, recent Docker lifecycle events, boot and OOM metadata, system service
warning timestamps, resource usage, and HTTP status codes. It does not export raw journal, container or cron logs,
environment variables, mount paths or proxy configuration. Docker events and
the system journal have limited retention and may be incomplete across reboots;
collection errors are represented explicitly in the report. HTTP probes include
paths for later states and can return 404 on state 004. Diagnosis does not
establish that a trading flow works. Reports are Actions artifacts in this
public repository; do not add unfiltered logs or secrets to them.

Regression coverage: `python3 scripts/test-publishing-security.py` and `bash scripts/test-generated-ci-assets.sh`. Dependency version remediation is tracked separately in issue #465; issue #466 defines these publishing/deployment guarantees.

### Local Node scanner alternative

Set `TRADERX_NODE_SECURITY_SCANNER=npm-audit` when publishing to audit generated
Node production lockfiles via [npm audit](https://docs.npmjs.com/cli/v11/commands/npm-audit/) directly against the npm registry without NVD. This
opt-in mode fails on **any** production advisory (including low severity), does
not apply Dependency-Check XML suppressions, and retains the scanner deadline
and separate findings/infrastructure-failure results. Reports stay in
`ci/local-security-reports/` locally and are excluded from published snapshots.
Java/.NET scans and GitHub security checks still use Dependency-Check; this is
not a replacement for their coverage or a way to authorize deployment on failure.

[OSV-Scanner](https://google.github.io/osv-scanner/supported-languages-and-lockfiles/) is another option for npm and Gradle lockfiles, while [Trivy](https://trivy.dev/docs/latest/guide/target/filesystem/) can scan
lockfiles and compiled Java archives. Adopting either as a full replacement
requires validating coverage and suppression policy across all generated modules.

### Snapshot packaging regression checks

The publisher retains `ci/` alongside the workflows and checks that the build/test
helper and module metadata survived pruning. Keep local scanner reports out of
snapshots. Run `scripts/test-publish-generated-state-branch.sh` before publishing;
its fixtures also cover the API-explorer lineage policy for states 010–014.

The missing-helper regression originated in commit `57878613` (PR #467,
2026-09-18), which added the build/test workflow without retaining `ci/` in the
publisher's root allowlist. The API-explorer mismatch originated in `224e2429`
(PR #457, 2026-09-16), which retained that build context without updating the
lineage validator. These are canonical pipeline fixes; do not patch generated
branches by hand.

## Daily demo redeployment

`Daily Demo Deployment` dispatches `Redeploy Live Demo` from `main` for both
public demo hosts daily at 05:15 UTC (GitHub scheduled jobs may start late).
It can also be dispatched manually. Each deployment resolves its generated
branch tip and uses the same provenance checks, fresh scans, immutable images,
database backup and health checks as a manual deployment. Scheduled runs never
request break-glass or image-cache reclamation. Per-host deployment concurrency
serializes scheduled and manual deployments. The dispatcher succeeding confirms
submission only; inspect the separate `Redeploy Live Demo` runs for deployment
results and retained evidence.

Do not reinstall the old host `redeploy.sh` cron job: it removes the checkout
and runs cleanup before validating its replacement, leaving the demo down when
a deployment gate fails. The legacy daily reboot is also disabled. Preserve
certificate-renewal jobs. Validation and scan failures in the verified workflow
occur before container replacement; startup failures still require inspection
and are not a guarantee of automatic rollback.

Failed normal scans retain `scan-review.json` with a blocked outcome, completed
database evidence and allowlisted results before propagating the failure.
Database-refresh failures also retain these sanitized artifacts, including any
already completed database refresh. Diagnostic project matching covers the
explicit state-004/state-009 canonical, GHCR and start-script aliases. Kernel
history queries include retained prior boots; systemd-manager startup failures
are counted through their allowlisted `UNIT` metadata.

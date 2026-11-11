# Publishing security and verified demo deployment

Generated snapshots retain the one-snapshot ancestry contract: regenerate from the canonical sources, reset to the configured base, and publish with force-with-lease. Security results never require an extra commit on a generated branch.

## Normal path

1. Generate the state and run `pipeline/publish-generated-state-branch.sh <state-id> --push`. Local dependency scans have independent acquisition and execution deadlines. Configure `TRADERX_SECURITY_PULL_TIMEOUT_SECONDS` (default 120) and `TRADERX_SECURITY_SCAN_TIMEOUT_SECONDS` (default 1800) as positive integers. Python 3 is required. The deadline kills the operation's process group; Docker cleanup has an additional maximum five-second allowance and targets only its unique scanner container. No Docker daemon, unrelated container, or shared scanner cache is removed.
2. Wait for **Build and Test Snapshot**, **Security Scanning**, and **Build and Publish Application Images** on the exact generated commit. Every job must succeed; missing, skipped, pending, failed, cancelled, timed-out and neutral results are ineligible. A successful image build cannot substitute for dependency security. The newest push run and its current attempt are used, never a previous successful run. Rerun the push workflow after fixing infrastructure; manually dispatched substitute workflows are not accepted.
3. Dispatch **Redeploy Live Demo** from the canonical branch, providing the target host and full generated commit SHA. The SHA must match the catalog's generated branch tip for that host. The workflow verifies expected jobs, including **Runtime Image Security**, and downloads image digests and the complete runtime lock from that snapshot's successful publishing run and attempt. It derives the expected inventory from the exact snapshot. Expired, missing, duplicated or substituted image evidence blocks deployment.
4. The host checks out that SHA, verifies the complete authorized service inventory and OCI platform-digest proofs, substitutes all scanned digests, and rescans the authorized images for HIGH/CRITICAL findings. It does not resolve new infrastructure tags at deployment time. It starts Compose with `--no-build --wait`. Any image lacking required evidence or any runtime scan failure stops deployment. Neither `latest` nor a subsequently changed tag can change any authorized runtime image.
5. The workflow retains `deployment-authorization-*` as its audit artifact. The host records the deployed snapshot, run URLs, attempts, timestamp and complete resolved service image set in `~/traderx/.traderx-deploy/deployed.json` and a SHA-named history file only after Compose reports success. The directory is private because resolved Compose configuration may contain environment values.

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
scans fail: per-service Trivy JSON, stderr and `summary.json`. Missing reports,
malformed results, scanner failures and HIGH/CRITICAL findings block replacement.
These reports are diagnostic artifacts, not successful runtime-image authorization.

Issue [#487](https://github.com/finos/traderX/issues/487) tracks runtime-image coverage
and state 009 recovery. Generated convergence publishing now requires complete
runtime-image scan evidence; preflight alone cannot make vulnerable images eligible.
Scan evidence and the vulnerability database must be no older than 24 hours.
The Java artifact-mapping database has a separate 96-hour limit because its
refresh metadata permits a 72-hour cycle; this does not extend vulnerability-data freshness. Before replacement, diagnose any existing 502 independently,
identify the live Compose project and database volume, and back up PostgreSQL.
Compose `--wait` alone does not establish application or trading-flow readiness.

Local reports live under `ci/local-security-reports/<project>/`. `acquisition.json` and `result.json` distinguish success (exit 0), findings (10), infrastructure failure (20), timeout (124), and cancellation (130). Dependency-Check's findings exit status is mapped separately from its analyzer/update failures. The overall `ci/local-security-status.json` stays incomplete if execution stops early.

For acquisition failures, restore registry/Docker access and rerun; increase the acquisition deadline only when the download needs more time. For scanner execution failures, restore its database/NVD access or adjust the execution deadline. Reusing an existing database via `TRADERX_DEPENDENCY_CHECK_NO_UPDATE=1` remains supported. Inspect the named container if cleanup could not be confirmed. Findings require remediation or reviewed, narrowly scoped canonical suppression changes, followed by regeneration and successful CI.

`--skip-cve-scan` / `TRADERX_SKIP_CVE_SCAN=1` and `--skip-prepublish-gate` explicitly record **deferred_to_ci** in snapshot metadata. They allow publishing for CI evaluation; they do not waive deployment checks. Compilation and other local skips likewise cannot bypass the required remote workflows.

After all pulls and scans succeed, state 009 briefly stops only its verified Compose project to take a physical PostgreSQL 16 backup. The helper rejects unexpected writers, nested mounts, data symlinks and insufficient backup space before stopping containers. It records a private backup checksum before startup. A failed backup attempts to resume the prior project without starting a competing database writer. If Compose fails partway through startup, it resumes only retained, unchanged containers where safe; it never replaces newer containers or restores the database automatically. No successful deployment record is written on failure. Inspect service health and use the last recorded digest set for incident diagnosis. Rollback through the normal workflow requires republishing the intended source as the current generated snapshot and completing its checks; the gate deliberately rejects old branch tips. Do not rerun with `latest` as a workaround.

## Exceptions

There is no built-in force-deploy or security-check bypass. Any exceptional policy change must be reviewed as a canonical pull request with the incident/approval link, precise scope, owner, expiry and recovery plan. Retain that review and deployment authorization artifact for audit. An ad hoc local skip or manually edited manifest is not an approved exception.

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

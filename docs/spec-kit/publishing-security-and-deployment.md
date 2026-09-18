# Publishing security and verified demo deployment

Generated snapshots retain the one-snapshot ancestry contract: regenerate from the canonical sources, reset to the configured base, and publish with force-with-lease. Security results never require an extra commit on a generated branch.

## Normal path

1. Generate the state and run `pipeline/publish-generated-state-branch.sh <state-id> --push`. Local dependency scans have independent acquisition and execution deadlines. Configure `TRADERX_SECURITY_PULL_TIMEOUT_SECONDS` (default 120) and `TRADERX_SECURITY_SCAN_TIMEOUT_SECONDS` (default 1800) as positive integers. Python 3 is required. The deadline kills the operation's process group; Docker cleanup has an additional maximum five-second allowance and targets only its unique scanner container. No Docker daemon, unrelated container, or shared scanner cache is removed.
2. Wait for **Build and Test Snapshot**, **Security Scanning**, and **Build and Publish Application Images** on the exact generated commit. Every job must succeed; missing, skipped, pending, failed, cancelled, timed-out and neutral results are ineligible. A successful image build cannot substitute for dependency security. The newest push run and its current attempt are used, never a previous successful run. Rerun the push workflow after fixing infrastructure; manually dispatched substitute workflows are not accepted.
3. Dispatch **Redeploy Live Demo** from the canonical branch, providing the target host and full generated commit SHA. The SHA must match the catalog's generated branch tip for that host. The workflow verifies expected jobs and downloads digest artifacts from that snapshot's successful publishing run and attempt. Expired or missing artifacts block deployment.
4. The host checks out that SHA, substitutes the scanned application digests, resolves infrastructure images to digests and scans those digests for HIGH/CRITICAL findings. It starts Compose with `--no-build --wait`. Any image lacking required evidence or any infrastructure scan failure stops deployment. Neither `latest` nor a subsequently changed SHA tag can change the deployed application images.
5. The workflow retains `deployment-authorization-*` as its audit artifact. The host records the deployed snapshot, run URLs, attempts, timestamp and complete resolved service image set in `~/traderx/.traderx-deploy/deployed.json` and a SHA-named history file only after Compose reports success. The directory is private because resolved Compose configuration may contain environment values.

For direct generated-bundle use, authenticate `gh` with read access to repository Actions, set `TRADERX_SNAPSHOT` to the full SHA, and run `runtime/deploy/aws-ec2-compose/deploy.sh --use-ghcr`. This performs the same remote authorization. `--dry-run` validates the SHA format and describes the operation without contacting or modifying the host. Python 3, Git, Docker Compose with `--wait` support, outbound GitHub/GHCR/Trivy access and the existing demo runtime prerequisites must be available. The live workflow no longer invokes an unverified `~/redeploy.sh`; migrate host-specific settings into its environment/runtime configuration before the first deployment.

The non-GHCR bundle path and clone-first scripts remain available for local development builds. They do not grant live-demo deployment eligibility.

## Failure recovery

Local reports live under `ci/local-security-reports/<project>/`. `acquisition.json` and `result.json` distinguish success (exit 0), findings (10), infrastructure failure (20), timeout (124), and cancellation (130). Dependency-Check's findings exit status is mapped separately from its analyzer/update failures. The overall `ci/local-security-status.json` stays incomplete if execution stops early.

For acquisition failures, restore registry/Docker access and rerun; increase the acquisition deadline only when the download needs more time. For scanner execution failures, restore its database/NVD access or adjust the execution deadline. Reusing an existing database via `TRADERX_DEPENDENCY_CHECK_NO_UPDATE=1` remains supported. Inspect the named container if cleanup could not be confirmed. Findings require remediation or reviewed, narrowly scoped canonical suppression changes, followed by regeneration and successful CI.

`--skip-cve-scan` / `TRADERX_SKIP_CVE_SCAN=1` and `--skip-prepublish-gate` explicitly record **deferred_to_ci** in snapshot metadata. They allow publishing for CI evaluation; they do not waive deployment checks. Compilation and other local skips likewise cannot bypass the required remote workflows.

If deployment stops before Compose starts, the previous running containers remain in place. If Compose fails partway through startup, no successful deployment record is written; inspect service health and use the last recorded digest set for incident diagnosis. Rollback through the normal workflow requires republishing the intended source as the current generated snapshot and completing its checks; the gate deliberately rejects old branch tips. Do not rerun with `latest` as a workaround.

## Exceptions

There is no built-in force-deploy or security-check bypass. Any exceptional policy change must be reviewed as a canonical pull request with the incident/approval link, precise scope, owner, expiry and recovery plan. Retain that review and deployment authorization artifact for audit. An ad hoc local skip or manually edited manifest is not an approved exception.

Regression coverage: `python3 scripts/test-publishing-security.py` and `bash scripts/test-generated-ci-assets.sh`. Dependency version remediation is tracked separately in issue #465; issue #466 defines these publishing/deployment guarantees.

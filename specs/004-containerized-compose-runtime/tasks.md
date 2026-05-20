# Tasks: 003 Containerized Compose Runtime

- [x] T301 Define container runtime requirements and traceability updates.
- [x] T302 Define compose topology, NGINX ingress, and service health/dependency model.
- [x] T303 Implement generation templates/manifests for container runtime assets.
- [x] T304 Regenerate containerized runtime artifacts from specs.
- [ ] T305 Execute containerized conformance and smoke checks.
- [ ] T306 Publish generated snapshot tag with evidence links.
- [ ] T307 Preserve state-aware GUI requirements from `001` in containerized runtime (header title + About metadata + API explorer link).
- [ ] T308 Preserve/verify `Status` page requirements from `002` in containerized runtime with ingress-visible health data.
- [ ] T309 Extend containerized smoke coverage to assert About metadata rendering and Status-page uptime/health visibility.
- [ ] T310 Add startup/runtime state-mismatch detection checks for state `004` scripts (match, mismatch, opt-in regeneration path).
- [ ] T311 Define state-catalog deployment metadata contract for demo-target states (`deploy.enabled`, profile, environment/domain mapping).
- [ ] T312 Generate `runtime/deploy/aws-ec2-compose/` bundle for this state snapshot with `README.md`, `deploy.sh`, `upgrade.sh`, `cleanup.sh`, and nginx snippet.
- [ ] T313 Enforce policy that pre-container states (`001-003`) do not emit deployment bundles in generated snapshots.
- [ ] T314 Add local deployment dry-run validation for generated deployment scripts (command rendering + required env var checks).
- [ ] T315 Publish deployment-runbook updates in state docs and generated snapshot runbook links.

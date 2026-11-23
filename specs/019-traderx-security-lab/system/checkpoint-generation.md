# Offline checkpoint generation contract

This is the artifact-reproduction and control-composition increment of S019-03, not the cumulative State 019 deployment. Its baseline is the exact generated C3 commit in the prototype's `baseline.lock.json`, not whatever current C3 generates today. A changed baseline requires a reviewed source/image lock and renewed compatibility evidence.

## Inputs and outputs

Inputs: immutable generated C3 commit and recorded canonical source relationship; complete committed runtime image inventory; canonical reference and business-workload renderers. Generation requires Python with the pinned PyYAML dependency and Git, but no Docker daemon, cluster, Java build or registry access.

Outputs: `reference.json`, `business-workloads.json`, `controls-candidate.json`, `deployment-plan.json`, `sql-grants.json`, `images.lock.json` and `checkpoint.json`. The latter records source hashes, artifact hashes, baseline commits and limitations. No absolute checkout paths or current timestamps enter the output. Reference and candidate artifacts remain separate: the reference retains public demonstration credentials and anonymous messaging. Applying the business restrictions alone does not establish an integrated hardened baseline.

## Lifecycle and invariants

1. `checkpoint.py fetch-baseline` is an explicit network preparation step, fetching the immutable commit from FINOS only when absent and checking the recorded source relationship. It does not switch branches.
2. `checkpoint.py generate --output DIR` is offline. Every required image must have a consistent source/platform/digest and match the baseline pin. Missing pins fail; no registry resolution is allowed.
3. The output directory must not exist. Compilation completes before output is created, and files are private by default. Generation never resets or overwrites a learner's existing directory.
4. `checkpoint.py verify --output DIR` recompiles from the current canonical inputs and compares every byte and the complete file set. It rejects missing, extra, modified or symlinked files, including changes to the provenance manifest.
5. The repeatability check generates twice into separate directories and compares all files. This is artifact reproducibility, not image availability, clean-machine runtime reproduction or enforcement proof.

Current pins mix AMD64 application images with ARM64 infrastructure for the reviewed ARM host. Do not advertise universal host support. Signatures, complete source provenance, integrated generator/start/stop/test scripts and a fresh-machine trading campaign remain separate release gates.

## Composed control candidate

The compiler overlays the reviewed business, support, database and observability restrictions into all **19 application Deployments**, retaining their required Services and ConfigMaps. It collects **12 admission policies and bindings**, **5 PVCs**, and a single collector in its separate infrastructure namespace. SQL consumers reference four distinct service Secrets; database bootstrap references a fifth Secret. No SQL password values or Secret objects are emitted in the candidate. Operator defaults such as the inherited Grafana demo login remain unchanged until operator access/authentication integration; this is not a secret-free or fully hardened deployment. `sql-grants.json` records the required role/table/operation contract; it does not create roles.

The compiler rejects duplicate objects, undeclared replacement collisions, changed application inventory, missing mounts/service accounts, literal SQL credentials, missing policy pairs and changes to the collector exception or namespace restrictions. The original collector, obsolete RBAC and old seed ConfigMap are excluded from the cumulative candidate; the reference artifact remains unchanged.

The application namespace specifies Restricted v1.35. The collector namespace retains an explicit privileged-PSS exception for the read-only host-log mount and bounded API token; its dedicated admission policies constrain that exception. This is not a claim that the whole deployment is unprivileged.

**The deployment plan is blocked, not ready to apply.** Existing persistence renderers suppress seed scripts and expect restored data. A fresh database needs a separately specified synthetic-schema bootstrap; service Secrets must be accompanied by real scoped SQL grants. Existing installations need backups, collector checkpoints, rollout verification and ordered namespace enforcement. Running `kubectl apply` on the candidate does not perform that workflow.

```bash
python scripts/security-lab/checkpoint.py plan --output /tmp/traderx-019-checkpoint-review
```

This verifies the complete bundle first, then displays prerequisites and phases without contacting a cluster. A changed bundle must be regenerated into a new directory. Start/stop orchestration remains S019-03c: own-cluster identity checks, an exclusive operation lock, resource preflight, private credentials, resumable bootstrap/restore, bounded rollout, effect checks and nondestructive stop. Keep business authorization, authenticated NATS, WAF/network integration, image trust and runtime enforcement visibly pending.

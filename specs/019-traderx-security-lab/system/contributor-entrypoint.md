# Verified contributor entrypoint

`state_candidate.py` unifies offline generation/verification with the reviewed candidate lifecycle. It works from any current directory when invoked by its checkout path. It does not create a cluster, install a CNI, load images, grant certificate trust or provision private SQL identities implicitly. State 019 remains a planned generated state; this contributor entrypoint is not a standalone published snapshot.

## Fresh checkout: artifact reproduction

Check out the Security Lab branch or review commit into a new directory. With Python 3.14 and Git available:

```bash
python3 -m venv .venv-security-checkpoint
.venv-security-checkpoint/bin/python -m pip install -r scripts/security-lab/requirements.txt
export TRADERX_SECURITY_PYTHON="$PWD/.venv-security-checkpoint/bin/python"
"$TRADERX_SECURITY_PYTHON" scripts/security-lab/state_candidate.py fetch-baseline
bash scripts/test-state-019-checkpoint.sh
```

The fetch is explicit and checks the immutable C3 snapshot/source relationship. The test changes to a temporary directory, generates twice, compares every output byte, verifies the result and prints the lifecycle plan. It starts no containers and changes no certificate trust. Python dependencies can be reused for a second checkout, but that is not independent clean-machine reproduction.

For a retained review bundle, choose a new destination outside source control:

```bash
"$TRADERX_SECURITY_PYTHON" scripts/security-lab/state_candidate.py generate --checkpoint "$HOME/traderx-019-review"
"$TRADERX_SECURITY_PYTHON" scripts/security-lab/state_candidate.py plan --checkpoint "$HOME/traderx-019-review"
```

The checkpoint hashes the lifecycle entrypoint and its transitive local Python imports, including outcome verifiers and resource/operation guards. Start and test recompile and compare the complete artifact set before invoking the runtime. Changed artifacts or source inputs cause refusal. Hashes provide consistency checks, not signatures or proof against a malicious checkout.

## Explicit runtime identity

Only use the following after preparing the supported existing cluster, enforcing CNI, pinned images and private SQL identity store described in the [runtime contract](telemetry-lifecycle.md). All six identity/path arguments are required. Values below are placeholders, not maintainer-private defaults:

```bash
"$TRADERX_SECURITY_PYTHON" scripts/security-lab/state_candidate.py start \
  --checkpoint "$HOME/traderx-019-review" \
  --runtime-dir "$LAB_RUNTIME" --store "$LAB_SQL_STORE" \
  --kubeconfig "$LAB_KUBECONFIG" --context "$LAB_CONTEXT" \
  --cluster-uid "$LAB_CLUSTER_UID" --namespace traderx-security-lab-019
```

Use `test` with the same arguments plus `--output <new-private-evidence-file>`. It verifies telemetry persistence and trading outcomes. Use `stop` with the six runtime arguments, **without `--checkpoint`**. Recovery stop intentionally remains available after source changes or checkpoint corruption; it still uses the lifecycle's cluster-identity, ownership and operation-lock checks. Storage and credentials are retained.

Never apply `controls-candidate.json` wholesale. The runtime uses ordered bootstrap and rollout. Keep the lightweight browser lab stopped during the full candidate run; resource preflight may refuse startup while host pressure is elevated. No Kubernetes run is necessary for the offline packaging checks.

## Lightweight browser certificate setup

The account/identity learner lab remains a separate mode. Use its [onboarding contract](../../012-platform-convergence-c3/security-lab/contracts/learner-onboarding.md). For a fresh setup, `traderx-lab setup --install-ca` explicitly authorizes the mkcert development CA. This trusts a development CA beyond localhost and may require a local approval prompt. Do not use hostname-scoped macOS trust as Chrome acceptance evidence: Chrome ignores those policy-specific trust entries.

An existing self-signed certificate is preserved by setup; it is not automatically migrated. Stop the lightweight lab, preserve its old TLS directory privately, provision a trusted replacement, then restart and verify the page in the actual browser. A native certificate check alone is insufficient. Current learner passwords are in the private `users.json` location printed by start and change on restart. Never include them in source, screenshots, issues or evidence.

## Remaining acceptance

This increment covers checkout-relative commands and repeatable artifact generation. Automatic supported-cluster provisioning, standalone generated-state packaging, independent clean-machine runtime acceptance and the remaining integrated security controls are still pending. The current runtime is verified on the existing macOS ARM64/Docker environment only.

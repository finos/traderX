#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/traderx-publish-state.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

STATE_ID="012-platform-convergence-c3"

make_state_012_fixture() {
  local fixture_root="$1"
  local context_rel="${2:-api-explorer}"
  local dockerfile_rel="${3:-Dockerfile}"

  rm -rf "${fixture_root}"
  mkdir -p \
    "${fixture_root}/.github" \
    "${fixture_root}/account-service" \
    "${fixture_root}/api-explorer" \
    "${fixture_root}/database" \
    "${fixture_root}/ingress" \
    "${fixture_root}/kubernetes-runtime" \
    "${fixture_root}/order-matcher" \
    "${fixture_root}/people-service" \
    "${fixture_root}/position-service" \
    "${fixture_root}/price-publisher" \
    "${fixture_root}/reference-data" \
    "${fixture_root}/runtime" \
    "${fixture_root}/tilt-kubernetes-dev-loop" \
    "${fixture_root}/trade-processor" \
    "${fixture_root}/trade-service" \
    "${fixture_root}/web-front-end" \
    "${fixture_root}/will-be-pruned"

  mkdir -p "${fixture_root}/ci"
  printf '{}\n' > "${fixture_root}/ci/state-metadata.json"
  cp "${ROOT}/pipeline/build-test-generated-snapshot.sh" "${fixture_root}/ci/build-test-generated-snapshot.sh"
  touch "${fixture_root}/api-explorer/Dockerfile"
  cat > "${fixture_root}/kubernetes-runtime/build-plan.json" <<EOF
{
  "images": [
    {
      "name": "api-explorer",
      "image": "traderx-api-explorer:local",
      "context": "${context_rel}",
      "dockerfile": "${dockerfile_rel}"
    }
  ]
}
EOF
}

run_publish_fixture() {
  local fixture_root="$1"
  TRADERX_PUBLISH_SNAPSHOT_FIXTURE_ROOT="${fixture_root}" \
  TRADERX_PUBLISH_VALIDATE_SNAPSHOT_ONLY=1 \
    bash "${ROOT}/pipeline/publish-generated-state-branch.sh" "${STATE_ID}"
}

expect_publish_fixture_failure() {
  local fixture_root="$1"
  local expected_message="$2"
  local log_file="${TMP_DIR}/failure.log"

  set +e
  run_publish_fixture "${fixture_root}" >"${log_file}" 2>&1
  local exit_code=$?
  set -e

  if [[ "${exit_code}" -eq 0 ]]; then
    echo "[fail] expected publisher fixture validation to fail"
    cat "${log_file}"
    exit 1
  fi

  grep -q "${expected_message}" "${log_file}" || {
    echo "[fail] expected failure output to contain: ${expected_message}"
    cat "${log_file}"
    exit 1
  }
}

echo "[check] publisher keeps api-explorer build context through state pruning"
valid_fixture="${TMP_DIR}/valid"
make_state_012_fixture "${valid_fixture}"
run_publish_fixture "${valid_fixture}" >/dev/null

echo "[check] publisher rejects missing build-plan context"
missing_context_fixture="${TMP_DIR}/missing-context"
make_state_012_fixture "${missing_context_fixture}" "missing-context" "Dockerfile"
expect_publish_fixture_failure "${missing_context_fixture}" "references missing context"

echo "[check] publisher rejects missing build-plan dockerfile"
missing_dockerfile_fixture="${TMP_DIR}/missing-dockerfile"
make_state_012_fixture "${missing_dockerfile_fixture}" "api-explorer" "Missing.Dockerfile"
expect_publish_fixture_failure "${missing_dockerfile_fixture}" "references missing dockerfile"

echo "[check] publisher rejects build-plan image entries missing required keys"
missing_key_fixture="${TMP_DIR}/missing-key"
make_state_012_fixture "${missing_key_fixture}"
cat > "${missing_key_fixture}/kubernetes-runtime/build-plan.json" <<'EOF'
{
  "images": [
    {
      "name": "api-explorer",
      "image": "traderx-api-explorer:local",
      "dockerfile": "Dockerfile"
    }
  ]
}
EOF
expect_publish_fixture_failure "${missing_key_fixture}" "kubernetes build plan must contain"

echo "[check] publisher rejects malformed kubernetes build plan"
malformed_fixture="${TMP_DIR}/malformed"
make_state_012_fixture "${malformed_fixture}"
printf '{bad json' > "${malformed_fixture}/kubernetes-runtime/build-plan.json"
expect_publish_fixture_failure "${malformed_fixture}" "kubernetes build plan must contain"

echo "[done] generated-state publisher snapshot checks passed"

echo "[check] publisher rejects a missing CI helper after pruning"
missing_ci_fixture="${TMP_DIR}/missing-ci"
make_state_012_fixture "${missing_ci_fixture}"
rm "${missing_ci_fixture}/ci/build-test-generated-snapshot.sh"
expect_publish_fixture_failure "${missing_ci_fixture}" "missing published CI input"

for state in 010-kubernetes-runtime 011-tilt-kubernetes-dev-loop 012-platform-convergence-c3 013-radius-kubernetes-platform 014-fdc3-intent-interoperability; do
  lineage_fixture="${TMP_DIR}/lineage-${state}"
  mkdir -p "${lineage_fixture}/api-explorer" "${lineage_fixture}/ci" "${lineage_fixture}/scripts"
  touch "${lineage_fixture}/RUN_FROM_CLONE.md" "${lineage_fixture}/start-env.sh" "${lineage_fixture}/stop-env.sh" "${lineage_fixture}/status-env.sh" "${lineage_fixture}/test-env.sh"
  bash "${ROOT}/pipeline/validate-generated-state-lineage-invariants.sh" --state-id "${state}" --snapshot-dir "${lineage_fixture}"
done

echo "[check] state 001 remains publishable without CI assets"
STATE_ID="001-baseline-uncontainerized-parity"
baseline_fixture="${TMP_DIR}/baseline"
mkdir -p "${baseline_fixture}/api-explorer" "${baseline_fixture}/catalog" "${baseline_fixture}/generated" "${baseline_fixture}/scripts"
TRADERX_SKIP_RUNTIME_PREFLIGHT=1 run_publish_fixture "${baseline_fixture}" >/dev/null

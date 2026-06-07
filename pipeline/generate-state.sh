#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
COMPONENTS_ROOT="${GENERATED_ROOT}/code/components"
GEN_DEPTH="${TRADERX_GENERATION_DEPTH:-0}"
GEN_DEPTH="$((GEN_DEPTH + 1))"
export TRADERX_GENERATION_DEPTH="${GEN_DEPTH}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/generate-state.sh <state-id>"
  echo "example: bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized"
  exit 1
fi

if (( GEN_DEPTH == 1 )); then
  bash "${ROOT}/pipeline/smoke-dependency-version-targets.sh"
fi

# Top-level generation must run exclusively because state generation writes to
# shared output roots by default (`generated/code/target-generated` and
# `generated/code/components`).
if (( GEN_DEPTH == 1 )); then
  LOCK_ROOT="${GENERATED_ROOT}/.locks"
  LOCK_DIR="${LOCK_ROOT}/generate-state.lock"
  mkdir -p "${LOCK_ROOT}"
  if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "[fail] concurrent generation is not supported with shared target directories"
    echo "[hint] wait for the active generation process to complete, then retry"
    echo "[hint] lock path: ${LOCK_DIR}"
    exit 1
  fi

  release_generation_lock() {
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  }
  trap release_generation_lock EXIT INT TERM
fi

clean_target_root() {
  local attempts=6
  local delay=1
  local i

  for ((i=1; i<=attempts; i++)); do
    if [[ -d "${TARGET_ROOT}" ]]; then
      # Preserve runtime state/cache in .run while ensuring all generated
      # component/layout directories are refreshed for this generation pass.
      find "${TARGET_ROOT}" -maxdepth 1 -mindepth 1 ! -name '.run' -exec rm -rf {} + && break || true
    else
      mkdir -p "${TARGET_ROOT}" && break || true
    fi
    if (( i == attempts )); then
      echo "[fail] unable to clean target root after ${attempts} attempts: ${TARGET_ROOT}"
      echo "[hint] stop active state runtimes, then retry."
      exit 1
    fi
    echo "[warn] target cleanup retry ${i}/${attempts} for ${TARGET_ROOT}"
    sleep "${delay}"
  done

  mkdir -p "${TARGET_ROOT}"
}

clean_components_root() {
  local attempts=6
  local delay=1
  local i

  for ((i=1; i<=attempts; i++)); do
    rm -rf "${COMPONENTS_ROOT}" && break || true
    if (( i == attempts )); then
      echo "[fail] unable to clean components root after ${attempts} attempts: ${COMPONENTS_ROOT}"
      echo "[hint] stop active state runtimes, then retry."
      exit 1
    fi
    echo "[warn] components cleanup retry ${i}/${attempts} for ${COMPONENTS_ROOT}"
    sleep "${delay}"
  done

  mkdir -p "${COMPONENTS_ROOT}"
}

# Always regenerate from a clean target so each state output is deterministic
# and does not carry unrelated artifacts from prior state runs.
clean_target_root
clean_components_root

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    bash "${ROOT}/pipeline/generate-from-spec.sh"
    bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"
    cat <<'EOT'
[summary] state=001-baseline-uncontainerized-parity
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-base-uncontainerized-generated.sh
EOT
    ;;
  002-edge-proxy-uncontainerized)
    bash "${ROOT}/pipeline/generate-state-002-edge-proxy-uncontainerized.sh"
    ;;
  004-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state-004-containerized-compose-runtime.sh"
    ;;
  *)
    HOOK="${ROOT}/pipeline/generate-state-${STATE_ID}.sh"
    if [[ -x "${HOOK}" ]]; then
      bash "${HOOK}"
    else
      echo "[fail] unsupported state-id: ${STATE_ID}"
      echo "[hint] add a state hook at ${HOOK} or implement explicit case logic."
      exit 1
    fi
    ;;
esac

# Enforce state lifecycle pruning contracts: once components are removed by an
# approved state spec, generated outputs for that and descendant states must
# prune those artifacts and avoid stale references.
bash "${ROOT}/pipeline/prune-generated-state-removed-assets.sh" "${STATE_ID}" "${TARGET_ROOT}" "${COMPONENTS_ROOT}"

# Validate dependency version targets across generated outputs. Dependency
# versions are canonical in templates/patches and catalog/dependency-version-targets.json.
# Optional apply mode is provided only for explicit bulk remediation.
if (( GEN_DEPTH == 1 )) || [[ "${TRADERX_REFRESH_JAVA_BASELINE_IN_NESTED_GENERATION:-0}" == "1" ]]; then
  bash "${ROOT}/pipeline/sync-node-dependency-overrides.sh" "${COMPONENTS_ROOT}" "${TARGET_ROOT}"
  if [[ "${TRADERX_APPLY_JAVA_DEPENDENCY_TARGETS:-0}" == "1" ]]; then
    bash "${ROOT}/pipeline/refresh-generated-java-dependency-baseline.sh" "${COMPONENTS_ROOT}" "${TARGET_ROOT}"
  fi
  bash "${ROOT}/pipeline/validate-generated-dependency-targets.sh" "${COMPONENTS_ROOT}" "${TARGET_ROOT}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping dependency target validation"
fi

# Keep Gradle wrapper assets canonical and template-owned across all generated
# modules so wrapper changes are centralized and not patch-owned.
bash "${ROOT}/pipeline/sync-gradle-wrapper-assets.sh" "${COMPONENTS_ROOT}"
bash "${ROOT}/pipeline/sync-gradle-wrapper-assets.sh" "${TARGET_ROOT}"

# Synchronize Node lockfiles against generated manifests. Lockfiles are refreshed
# only when package manifests change (or when missing/invalid), and otherwise
# left intact to avoid unnecessary regeneration churn.
if [[ "${TRADERX_SKIP_LOCKFILE_REFRESH:-0}" == "1" ]]; then
  echo "[info] TRADERX_SKIP_LOCKFILE_REFRESH=1; skipping lockfile refresh"
elif (( GEN_DEPTH == 1 )) || [[ "${TRADERX_REFRESH_LOCKFILES_IN_NESTED_GENERATION:-0}" == "1" ]]; then
  bash "${ROOT}/pipeline/refresh-generated-node-lockfiles.sh" "${COMPONENTS_ROOT}"
  bash "${ROOT}/pipeline/refresh-generated-node-lockfiles.sh" "${TARGET_ROOT}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping lockfile refresh"
fi

# Install self-contained runtime scripts alongside the generated codebase.
# API explorer install mutates runtime ingress/proxy configs, so avoid applying
# it during nested parent-state generation where later patchsets may expect the
# pre-install file shape.
if (( GEN_DEPTH == 1 )) || [[ "${TRADERX_INSTALL_API_EXPLORER_IN_NESTED_GENERATION:-0}" == "1" ]]; then
bash "${ROOT}/pipeline/install-generated-api-explorer.sh" "${STATE_ID}" "${TARGET_ROOT}" "${COMPONENTS_ROOT}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping API explorer install"
fi
bash "${ROOT}/pipeline/install-generated-ui-state-metadata.sh" "${STATE_ID}" "${TARGET_ROOT}" "${COMPONENTS_ROOT}"
bash "${ROOT}/pipeline/validate-generated-ui-status-checks.sh" "${STATE_ID}" "${TARGET_ROOT}" "${COMPONENTS_ROOT}"
bash "${ROOT}/pipeline/install-generated-runtime-harness.sh" "${STATE_ID}" "${TARGET_ROOT}"
bash "${ROOT}/pipeline/install-generated-ci-assets.sh" "${STATE_ID}" "${TARGET_ROOT}"

bash "${ROOT}/pipeline/refresh-state-docs.sh"

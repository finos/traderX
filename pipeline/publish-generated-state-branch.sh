#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
CATALOG="${ROOT}/catalog/state-catalog.json"
GENERATED_ROOT_BRANCH="${GENERATED_ROOT_BRANCH:-code/generated-state-root}"

usage() {
  cat <<'EOF'
usage: bash pipeline/publish-generated-state-branch.sh <state-id> [--branch <branch-name>] [--push] [--skip-compile-preflight] [--skip-prepublish-gate] [--skip-runtime-preflight] [--skip-contract-validation] [--skip-lineage-validation]

Examples:
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --skip-compile-preflight
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --skip-prepublish-gate
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --skip-runtime-preflight --skip-prepublish-gate --skip-compile-preflight --skip-contract-validation --skip-lineage-validation --push
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --branch code/generated-state-001-baseline-uncontainerized-parity
EOF
}

STATE_ID="${1:-}"
if [[ -z "${STATE_ID}" ]]; then
  usage
  exit 1
fi
state_num="${STATE_ID%%-*}"
if [[ ! "${state_num}" =~ ^[0-9]+$ ]]; then
  echo "[fail] invalid state id format: ${STATE_ID}"
  exit 1
fi
shift || true

BRANCH_OVERRIDE=""
PUSH=0
SKIP_COMPILE_PREFLIGHT="${TRADERX_SKIP_COMPILE_PREFLIGHT:-0}"
SKIP_PREPUBLISH_GATE="${TRADERX_SKIP_PREPUBLISH_GATE:-0}"
SKIP_RUNTIME_PREFLIGHT="${TRADERX_SKIP_RUNTIME_PREFLIGHT:-0}"
SKIP_CONTRACT_VALIDATION="${TRADERX_SKIP_CONTRACT_VALIDATION:-0}"
SKIP_LINEAGE_VALIDATION="${TRADERX_SKIP_LINEAGE_VALIDATION:-0}"

while (( "$#" )); do
  case "$1" in
    --branch)
      BRANCH_OVERRIDE="${2:-}"
      if [[ -z "${BRANCH_OVERRIDE}" ]]; then
        echo "[fail] --branch requires a value"
        exit 1
      fi
      shift 2
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --skip-compile-preflight)
      SKIP_COMPILE_PREFLIGHT=1
      shift
      ;;
    --skip-prepublish-gate)
      SKIP_PREPUBLISH_GATE=1
      shift
      ;;
    --skip-runtime-preflight)
      SKIP_RUNTIME_PREFLIGHT=1
      shift
      ;;
    --skip-contract-validation)
      SKIP_CONTRACT_VALIDATION=1
      shift
      ;;
    --skip-lineage-validation)
      SKIP_LINEAGE_VALIDATION=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

if ! jq -e --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
  echo "[fail] state not found in catalog: ${STATE_ID}"
  exit 1
fi

PREVIOUS_STATE_COUNT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | ((.previous // []) | length)' "${CATALOG}")"
if [[ "${PREVIOUS_STATE_COUNT}" -gt 1 ]]; then
  echo "[fail] state ${STATE_ID} has multiple previous states; publisher currently supports one parent branch"
  echo "[hint] add merge-aware publish behavior before enabling multi-parent state lineage"
  exit 1
fi

PRIMARY_PREVIOUS_STATE_ID="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | ((.previous // [])[0] // "")' "${CATALOG}")"
DOTTED_PARENTS_FOR_STATE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | ((.dottedParents // []) | join(", "))' "${CATALOG}")"
PRIMARY_PREVIOUS_BRANCH=""
if [[ -n "${PRIMARY_PREVIOUS_STATE_ID}" ]]; then
  PRIMARY_PREVIOUS_BRANCH="$(jq -r --arg id "${PRIMARY_PREVIOUS_STATE_ID}" '.states[] | select(.id == $id) | (.publish.branch // "")' "${CATALOG}")"
  if [[ -z "${PRIMARY_PREVIOUS_BRANCH}" ]]; then
    echo "[fail] previous state ${PRIMARY_PREVIOUS_STATE_ID} does not define publish.branch"
    exit 1
  fi
fi

if [[ -n "${DOTTED_PARENTS_FOR_STATE}" ]]; then
  echo "[info] dotted-line parents for ${STATE_ID}: ${DOTTED_PARENTS_FOR_STATE}"
  echo "[info] dotted-line parents are documentation lineage only and are ignored for publish ancestry"
fi

FEATURE_PACK="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .featurePack' "${CATALOG}")"
STATE_STATUS="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .status' "${CATALOG}")"
GEN_MODE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .generation.mode' "${CATALOG}")"
STATE_TITLE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .title' "${CATALOG}")"
DEFAULT_BRANCH="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .publish.branch' "${CATALOG}")"
TAG_HINT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .publish.tag' "${CATALOG}")"
GENERATION_ENTRYPOINT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .generation.entrypoint' "${CATALOG}")"
GENERATION_RUNTIME="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.generation.runtime // "")' "${CATALOG}")"

BRANCH_NAME="${BRANCH_OVERRIDE:-${DEFAULT_BRANCH}}"
if [[ "${BRANCH_NAME}" != code/generated-state-* ]]; then
  echo "[fail] generated-state branch must use code/generated-state-* prefix: ${BRANCH_NAME}"
  exit 1
fi

if [[ ! -d "${ROOT}/${FEATURE_PACK}" ]]; then
  echo "[fail] feature pack path does not exist: ${FEATURE_PACK}"
  exit 1
fi

if [[ "${GEN_MODE}" != "implemented" ]]; then
  echo "[fail] state ${STATE_ID} is ${STATE_STATUS} with generation.mode=${GEN_MODE}."
  echo "[hint] implement state-aware generation first, then publish branch."
  exit 1
fi

if [[ -n "$(git -C "${ROOT}" status --porcelain)" ]]; then
  echo "[fail] working tree must be clean before publishing generated-state branch."
  echo "[hint] commit or stash current changes and retry."
  exit 1
fi

echo "[info] generating state ${STATE_ID} (${STATE_TITLE})"
case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping runtime preflight (--skip-runtime-preflight)"
    else
      "${ROOT}/scripts/start-base-uncontainerized-generated.sh" --build-only
      "${ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run
    fi
    ;;
  002-edge-proxy-uncontainerized)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping runtime preflight (--skip-runtime-preflight)"
    else
      "${ROOT}/scripts/start-state-002-edge-proxy-generated.sh" --build-only
      "${ROOT}/scripts/start-state-002-edge-proxy-generated.sh" --dry-run
    fi
    ;;
  003-agentic-harness-foundation)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping runtime preflight (--skip-runtime-preflight)"
    else
      "${ROOT}/scripts/start-state-003-agentic-harness-foundation-generated.sh" --build-only
      "${ROOT}/scripts/start-state-003-agentic-harness-foundation-generated.sh" --dry-run
    fi
    ;;
  004-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${GENERATED_ROOT}/code/target-generated/containerized-compose/docker-compose.yml" ]] || {
      echo "[fail] missing generated compose file for state 004"
      exit 1
    }
    ;;
  010-kubernetes-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${GENERATED_ROOT}/code/target-generated/kubernetes-runtime/build-plan.json" ]] || {
      echo "[fail] missing generated kubernetes build-plan for state 010"
      exit 1
    }
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping runtime preflight (--skip-runtime-preflight)"
    else
      "${ROOT}/scripts/start-state-010-kubernetes-runtime-generated.sh" --dry-run
    fi
    ;;
  013-radius-kubernetes-platform)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${GENERATED_ROOT}/code/target-generated/radius-kubernetes-platform/radius/app.bicep" ]] || {
      echo "[fail] missing generated radius app model for state 013"
      exit 1
    }
    ;;
  011-tilt-kubernetes-dev-loop)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${GENERATED_ROOT}/code/target-generated/tilt-kubernetes-dev-loop/tilt/Tiltfile" ]] || {
      echo "[fail] missing generated tilt assets for state 011"
      exit 1
    }
    ;;
  *)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    RUNTIME_START_SCRIPT="${ROOT}/scripts/start-state-${STATE_ID}-generated.sh"
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping runtime preflight (--skip-runtime-preflight)"
    elif [[ -x "${RUNTIME_START_SCRIPT}" ]]; then
      "${RUNTIME_START_SCRIPT}" --dry-run || true
    else
      echo "[info] no state-specific start script found at ${RUNTIME_START_SCRIPT}; skipping runtime dry-run"
    fi
    ;;
esac

# Recompute CI assets after runtime dry-run because some states (notably
# uncontainerized 002/003 lineage) materialize runnable component layout into
# target-generated during dry-run. Without this refresh, workflow target
# discovery may emit "no targets" stubs.
bash "${ROOT}/pipeline/install-generated-ci-assets.sh" "${STATE_ID}" "${GENERATED_ROOT}/code/target-generated"

if [[ "${SKIP_PREPUBLISH_GATE}" == "1" ]]; then
  echo "[warn] skipping prepublish generated-state gate (--skip-prepublish-gate)"
  if [[ "${SKIP_CONTRACT_VALIDATION}" == "1" ]]; then
    echo "[warn] skipping generated-state contract validation (--skip-contract-validation)"
  else
    bash "${ROOT}/pipeline/validate-generated-state-contracts.sh" "${GENERATED_ROOT}/code/target-generated"
  fi
  if [[ "${SKIP_COMPILE_PREFLIGHT}" == "1" ]]; then
    echo "[warn] skipping generated compile preflight (--skip-compile-preflight)"
  else
    CI_METADATA="${GENERATED_ROOT}/code/target-generated/ci/state-metadata.json"
    if [[ -f "${CI_METADATA}" ]]; then
      echo "[step] run generated compile preflight"
      bash "${ROOT}/pipeline/preflight-generated-ci.sh" "${GENERATED_ROOT}/code/target-generated"
    elif [[ "${state_num}" -lt 2 ]]; then
      echo "[info] compile preflight metadata unavailable for ${STATE_ID}; skipping for legacy pre-CI state"
    else
      echo "[fail] missing compile preflight metadata: ${CI_METADATA}"
      echo "[hint] ensure CI assets were installed during state generation"
      exit 1
    fi
  fi
else
  prepublish_args=("${STATE_ID}" "--target-root" "${GENERATED_ROOT}/code/target-generated" "--components-root" "${GENERATED_ROOT}/code/components")
  if [[ "${SKIP_COMPILE_PREFLIGHT}" == "1" ]]; then
    prepublish_args+=("--skip-compile-preflight")
  fi
  echo "[step] run prepublish generated-state gate"
  bash "${ROOT}/pipeline/prepublish-generated-state-gate.sh" "${prepublish_args[@]}"
fi

SNAPSHOT_ROOT="${GENERATED_ROOT}/code/target-generated"
if [[ ! -d "${SNAPSHOT_ROOT}" ]]; then
  echo "[fail] missing generated target directory: ${SNAPSHOT_ROOT}"
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/traderx-generated-state.XXXXXX")"
WORKTREE_DIR="${TMP_DIR}/worktree"
SNAPSHOT_DIR="${TMP_DIR}/snapshot"
mkdir -p "${WORKTREE_DIR}" "${SNAPSHOT_DIR}"

cleanup() {
  git -C "${ROOT}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

ensure_local_branch_ref() {
  local branch="$1"
  if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
    return 0
  fi

  if git -C "${ROOT}" ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
    git -C "${ROOT}" fetch origin "${branch}:${branch}" >/dev/null
    return 0
  fi

  return 1
}

ensure_generated_root_branch() {
  local root_branch="$1"
  if ensure_local_branch_ref "${root_branch}"; then
    return 0
  fi

  local root_worktree="${TMP_DIR}/root-worktree"
  git -C "${ROOT}" worktree add --detach "${root_worktree}" HEAD >/dev/null
  git -C "${root_worktree}" checkout --orphan "${root_branch}" >/dev/null
  git -C "${root_worktree}" rm -rf . >/dev/null 2>&1 || true
  git -C "${root_worktree}" clean -fdx >/dev/null 2>&1 || true
  git -C "${root_worktree}" commit --allow-empty -m "root: generated-state ancestry anchor" >/dev/null
  git -C "${ROOT}" worktree remove --force "${root_worktree}" >/dev/null 2>&1 || true
  echo "[ok] created generated root branch ${root_branch}"
}

ensure_generated_root_branch "${GENERATED_ROOT_BRANCH}"

BASE_BRANCH="${GENERATED_ROOT_BRANCH}"
if [[ -n "${PRIMARY_PREVIOUS_BRANCH}" ]]; then
  BASE_BRANCH="${PRIMARY_PREVIOUS_BRANCH}"
fi

if ! ensure_local_branch_ref "${BASE_BRANCH}"; then
  echo "[fail] base branch ${BASE_BRANCH} not found locally or on origin"
  if [[ -n "${PRIMARY_PREVIOUS_STATE_ID}" ]]; then
    echo "[hint] publish parent state first: ${PRIMARY_PREVIOUS_STATE_ID}"
  fi
  exit 1
fi

cp -R "${SNAPSHOT_ROOT}/." "${SNAPSHOT_DIR}/"
rm -rf "${SNAPSHOT_DIR}/.run"

CORE_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "reference-data"
  "trade-feed"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

NATS_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

PRICING_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

ORDER_COMPONENT_DIRS=(
  "account-service"
  "database"
  "order-matcher"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

C2_COMPONENT_DIRS=(
  "account-service"
  "database"
  "ingress"
  "order-matcher"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

snapshot_keep_paths_for_state() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
        printf '%s\n' "api-explorer" "catalog" "generated" "scripts"
      else
        printf '%s\n' "${CORE_COMPONENT_DIRS[@]}"
      fi
      ;;
  002-edge-proxy-uncontainerized)
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      printf '%s\n' "api-explorer" "catalog" "generated" "scripts" ".github"
    else
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "edge-proxy" ".github"
    fi
    ;;
  003-agentic-harness-foundation)
    if [[ "${SKIP_RUNTIME_PREFLIGHT}" == "1" ]]; then
      printf '%s\n' "api-explorer" "catalog" "generated" "scripts" ".github"
    else
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "edge-proxy" ".github"
    fi
    ;;
  004-containerized-compose-runtime)
    printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress" ".github" "runtime"
    ;;
  005-postgres-database-replacement)
    printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress" "postgres-database-replacement" ".github"
    ;;
  006-messaging-nats-replacement)
    printf '%s\n' "${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "postgres-database-replacement" ".github"
    ;;
  007-observability-lgtm-compose)
    printf '%s\n' "${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "observability-lgtm-compose" "postgres-database-replacement" ".github" "runtime"
    ;;
  008-pricing-awareness-market-data)
    printf '%s\n' "${PRICING_COMPONENT_DIRS[@]}" "ingress" "pricing-awareness-market-data" "postgres-database-replacement" ".github"
    ;;
  009-order-management-matcher)
    printf '%s\n' "${ORDER_COMPONENT_DIRS[@]}" "ingress" "order-management-matcher" "postgres-database-replacement" ".github" "runtime"
    ;;
    010-kubernetes-runtime)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" ".github"
      ;;
    011-tilt-kubernetes-dev-loop)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop" ".github"
      ;;
    012-platform-convergence-c3)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop" ".github" "runtime"
      ;;
  013-radius-kubernetes-platform)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "radius-kubernetes-platform" ".github"
      ;;
    014-fdc3-intent-interoperability)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop" "fdc3-intent-interoperability" ".github" "runtime"
      ;;
    *)
      echo "[fail] missing explicit snapshot keep-path policy for ${STATE_ID}"
      echo "[hint] add ${STATE_ID} to snapshot_keep_paths_for_state and install-generated-ci-assets.sh state_allowed_roots"
      exit 1
      ;;
  esac
}

path_in_keep_list() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "${needle}" == "${item}" ]]; then
      return 0
    fi
  done
  return 1
}

prune_snapshot_for_state() {
  local keep_paths=()
  local keep_path
  while IFS= read -r keep_path; do
    [[ -n "${keep_path}" ]] || continue
    keep_paths+=("${keep_path}")
  done < <(snapshot_keep_paths_for_state | sed '/^$/d' | sort -u)

  if [[ "${#keep_paths[@]}" -eq 0 ]]; then
    echo "[fail] no keep-paths resolved for state ${STATE_ID}"
    exit 1
  fi

  local required
  for required in "${keep_paths[@]}"; do
    if [[ ! -e "${SNAPSHOT_DIR}/${required}" ]]; then
      echo "[fail] expected state artifact missing after generation: ${required}"
      exit 1
    fi
  done

  local entry base
  while IFS= read -r entry; do
    base="$(basename "${entry}")"
    if ! path_in_keep_list "${base}" "${keep_paths[@]}"; then
      rm -rf "${entry}"
    fi
  done < <(find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -print)
}

prune_snapshot_for_state

strip_precontainer_docker_artifacts() {
  if (( 10#${state_num} >= 4 )); then
    return
  fi

  find "${SNAPSHOT_DIR}" -type f \
    \( -name 'Dockerfile' -o -name 'Dockerfile.compose' -o -name 'docker-compose.yml' -o -name 'docker-compose.*.yml' \) \
    -delete
}

strip_precontainer_docker_artifacts

remove_snapshot_transient_artifacts() {
  local transient_dirs=(
    "node_modules"
    ".angular"
    ".gradle"
    ".npm"
    ".pnpm-store"
    ".cache"
    ".run"
    "coverage"
    "dist"
    "build"
    "bin"
    "obj"
  )

  local name dirpath
  for name in "${transient_dirs[@]}"; do
    while IFS= read -r dirpath; do
      rm -rf "${dirpath}"
    done < <(find "${SNAPSHOT_DIR}" -type d -name "${name}" -print)
  done

  find "${SNAPSHOT_DIR}" -type f \( -name "*.log" -o -name ".DS_Store" \) -delete
}

assert_snapshot_size_guardrails() {
  local oversized
  oversized="$(find "${SNAPSHOT_DIR}" -type f -size +95M -print | sed '/^$/d')"
  if [[ -n "${oversized}" ]]; then
    echo "[fail] oversized files found in snapshot (must be <=95MB):"
    printf '%s\n' "${oversized}"
    echo "[hint] ensure transient caches/build outputs are excluded from generated snapshot branches."
    exit 1
  fi
}

remove_snapshot_transient_artifacts
assert_snapshot_size_guardrails

SOURCE_COMMIT="$(git -C "${ROOT}" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "${ROOT}" branch --show-current)"
GENERATED_AT_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

PREVIOUS_STATES_JSON="$(jq -c --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // [])' "${CATALOG}")"
NEXT_STATES_JSON="$(jq -c --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ]' "${CATALOG}")"
PREVIOUS_STATES_TEXT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // []) | if length == 0 then "none" else join(", ") end' "${CATALOG}")"
NEXT_STATES_TEXT="$(jq -r --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ] | if length == 0 then "none" else join(", ") end' "${CATALOG}")"
IS_CONVERGENCE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.isConvergence // false)' "${CATALOG}")"
CONVERGENCE_LEVEL="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.convergenceLevel // "none")' "${CATALOG}")"
CONVERGENCE_ROLE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.primaryLineageRole // "canonical")' "${CATALOG}")"
DOTTED_PARENTS_JSON="$(jq -c --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.dottedParents // [])' "${CATALOG}")"
DOTTED_PARENTS_TEXT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.dottedParents // []) | if length == 0 then "none" else join(", ") end' "${CATALOG}")"
PREVIOUS_CONVERGENCE_STATE="$(jq -r --arg id "${STATE_ID}" '
  .states as $states
  | ($states | map(.id) | index($id)) as $idx
  | if $idx == null then ""
    else
      [ range(0; $idx) as $i
        | $states[$i]
        | select((.isConvergence // false) == true)
        | .id ] as $prev
      | if ($prev | length) == 0 then "" else ($prev[-1] // "") end
    end
' "${CATALOG}")"
NEXT_CONVERGENCE_STATE="$(jq -r --arg id "${STATE_ID}" '
  .states as $states
  | ($states | map(.id) | index($id)) as $idx
  | if $idx == null then ""
    else
      [ range($idx + 1; ($states | length)) as $i
        | $states[$i]
        | select((.isConvergence // false) == true)
        | .id ] as $next
      | if ($next | length) == 0 then "" else ($next[0] // "") end
    end
' "${CATALOG}")"

ORIGIN_URL="$(git -C "${ROOT}" remote get-url origin)"
REPO_WEB_BASE=""
case "${ORIGIN_URL}" in
  https://github.com/*)
    REPO_WEB_BASE="${ORIGIN_URL%.git}"
    ;;
  git@github.com:*)
    REPO_WEB_BASE="https://github.com/${ORIGIN_URL#git@github.com:}"
    REPO_WEB_BASE="${REPO_WEB_BASE%.git}"
    ;;
esac

urlencode() {
  local raw="${1:-}"
  jq -nr --arg s "${raw}" '$s|@uri'
}

state_branch_name() {
  local state_id="${1:-}"
  jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.publish.branch // "")' "${CATALOG}"
}

state_branch_url() {
  local state_id="${1:-}"
  local branch
  branch="$(state_branch_name "${state_id}")"
  if [[ -z "${REPO_WEB_BASE}" || -z "${branch}" ]]; then
    return 1
  fi
  printf '%s/tree/%s' "${REPO_WEB_BASE}" "$(urlencode "${branch}")"
}

compare_url() {
  local from_branch="${1:-}"
  local to_branch="${2:-}"
  if [[ -z "${REPO_WEB_BASE}" || -z "${from_branch}" || -z "${to_branch}" ]]; then
    return 1
  fi
  printf '%s/compare/%s...%s' "${REPO_WEB_BASE}" "$(urlencode "${from_branch}")" "$(urlencode "${to_branch}")"
}

render_convergence_reference_markdown() {
  local direction="${1:-}"
  local ref_state_id="${2:-}"
  if [[ -z "${ref_state_id}" ]]; then
    printf '`none`'
    return 0
  fi

  local branch_name branch_url compare_link compare_from compare_to
  branch_name="$(state_branch_name "${ref_state_id}")"
  branch_url="$(state_branch_url "${ref_state_id}" || true)"

  local state_md="\`${ref_state_id}\`"
  if [[ -n "${branch_url}" ]]; then
    state_md="[${ref_state_id}](${branch_url})"
  fi

  compare_from="$(state_branch_name "${STATE_ID}")"
  compare_to="${branch_name}"
  if [[ "${direction}" == "previous" ]]; then
    compare_from="${branch_name}"
    compare_to="$(state_branch_name "${STATE_ID}")"
  fi

  compare_link="$(compare_url "${compare_from}" "${compare_to}" || true)"
  if [[ -n "${compare_link}" ]]; then
    printf '%s (🔍 [compare](%s))' "${state_md}" "${compare_link}"
    return 0
  fi

  printf '%s' "${state_md}"
}

render_state_lineage_table_rows() {
  local current_branch
  current_branch="$(state_branch_name "${STATE_ID}")"
  local rows=""
  local prev_id prev_branch prev_branch_url prev_compare_url
  while IFS= read -r prev_id; do
    [[ -n "${prev_id}" ]] || continue
    prev_branch="$(state_branch_name "${prev_id}")"
    prev_branch_url="$(state_branch_url "${prev_id}" || true)"
    prev_compare_url="$(compare_url "${prev_branch}" "${current_branch}" || true)"

    local prev_branch_md="\`${prev_branch:-n/a}\`"
    if [[ -n "${prev_branch_url}" ]]; then
      prev_branch_md="[${prev_branch}](${prev_branch_url})"
    fi

    local prev_compare_md="n/a"
    if [[ -n "${prev_compare_url}" ]]; then
      prev_compare_md="🔍 [compare](${prev_compare_url})"
    fi

    rows="${rows}| Previous | \`${prev_id}\` | ${prev_branch_md} | ${prev_compare_md} |\n"
  done < <(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // [])[]?' "${CATALOG}")

  local next_id next_branch next_branch_url next_compare_url
  while IFS= read -r next_id; do
    [[ -n "${next_id}" ]] || continue
    next_branch="$(state_branch_name "${next_id}")"
    next_branch_url="$(state_branch_url "${next_id}" || true)"
    next_compare_url="$(compare_url "${current_branch}" "${next_branch}" || true)"

    local next_branch_md="\`${next_branch:-n/a}\`"
    if [[ -n "${next_branch_url}" ]]; then
      next_branch_md="[${next_branch}](${next_branch_url})"
    fi

    local next_compare_md="n/a"
    if [[ -n "${next_compare_url}" ]]; then
      next_compare_md="🔍 [compare](${next_compare_url})"
    fi

    rows="${rows}| Next | \`${next_id}\` | ${next_branch_md} | ${next_compare_md} |\n"
  done < <(jq -r --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ][]?' "${CATALOG}")

  if [[ -z "${rows}" ]]; then
    rows="| Current | \`${STATE_ID}\` | \`$(state_branch_name "${STATE_ID}")\` | n/a |\n"
  fi

  printf '%b' "${rows}"
}

render_state_lineage_mermaid() {
  local current_node="S_CUR"
  local current_label
  current_label="${STATE_ID} (current)"

  printf '%s\n' '```mermaid'
  printf '%s\n' 'flowchart LR'
  printf '  %s["%s"]\n' "${current_node}" "${current_label}"
  printf '  style %s fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px\n' "${current_node}"

  local prev_id prev_node prev_url
  while IFS= read -r prev_id; do
    [[ -n "${prev_id}" ]] || continue
    prev_node="S_PREV_$(echo "${prev_id}" | sed 's/[^A-Za-z0-9]/_/g')"
    printf '  %s["%s"] --> %s\n' "${prev_node}" "${prev_id}" "${current_node}"
    prev_url="$(state_branch_url "${prev_id}" || true)"
    if [[ -n "${prev_url}" ]]; then
      printf '  click %s href "%s" "Open branch"\n' "${prev_node}" "${prev_url}"
    fi
  done < <(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // [])[]?' "${CATALOG}")

  local next_id next_node next_url
  while IFS= read -r next_id; do
    [[ -n "${next_id}" ]] || continue
    next_node="S_NEXT_$(echo "${next_id}" | sed 's/[^A-Za-z0-9]/_/g')"
    printf '  %s --> %s["%s"]\n' "${current_node}" "${next_node}" "${next_id}"
    next_url="$(state_branch_url "${next_id}" || true)"
    if [[ -n "${next_url}" ]]; then
      printf '  click %s href "%s" "Open branch"\n' "${next_node}" "${next_url}"
    fi
  done < <(jq -r --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ][]?' "${CATALOG}")

  local current_url
  current_url="$(state_branch_url "${STATE_ID}" || true)"
  if [[ -n "${current_url}" ]]; then
    printf '  click %s href "%s" "Open current branch"\n' "${current_node}" "${current_url}"
  fi

  printf '%s\n' '```'
}

render_convergence_mermaid() {
  local current_node="C_CUR"
  local current_label="${STATE_ID} (current)"
  local prev_id="${PREVIOUS_CONVERGENCE_STATE}"
  local next_id="${NEXT_CONVERGENCE_STATE}"

  printf '%s\n' '```mermaid'
  printf '%s\n' 'flowchart LR'
  printf '  %s["%s"]\n' "${current_node}" "${current_label}"
  printf '  style %s fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px\n' "${current_node}"

  if [[ -n "${prev_id}" ]]; then
    local prev_node="C_PREV_$(echo "${prev_id}" | sed 's/[^A-Za-z0-9]/_/g')"
    local prev_url
    prev_url="$(state_branch_url "${prev_id}" || true)"
    local prev_compare
    prev_compare="$(compare_url "$(state_branch_name "${prev_id}")" "$(state_branch_name "${STATE_ID}")" || true)"
    printf '  %s["%s"] --> %s\n' "${prev_node}" "${prev_id}" "${current_node}"
    if [[ -n "${prev_url}" ]]; then
      printf '  click %s href "%s" "Open branch"\n' "${prev_node}" "${prev_url}"
    fi
    if [[ -n "${prev_compare}" ]]; then
      printf '  %%%% compare: %s\n' "${prev_compare}"
    fi
  fi

  if [[ -n "${next_id}" ]]; then
    local next_node="C_NEXT_$(echo "${next_id}" | sed 's/[^A-Za-z0-9]/_/g')"
    local next_url
    next_url="$(state_branch_url "${next_id}" || true)"
    local next_compare
    next_compare="$(compare_url "$(state_branch_name "${STATE_ID}")" "$(state_branch_name "${next_id}")" || true)"
    printf '  %s --> %s["%s"]\n' "${current_node}" "${next_node}" "${next_id}"
    if [[ -n "${next_url}" ]]; then
      printf '  click %s href "%s" "Open branch"\n' "${next_node}" "${next_url}"
    fi
    if [[ -n "${next_compare}" ]]; then
      printf '  %%%% compare: %s\n' "${next_compare}"
    fi
  fi

  local current_url
  current_url="$(state_branch_url "${STATE_ID}" || true)"
  if [[ -n "${current_url}" ]]; then
    printf '  click %s href "%s" "Open current branch"\n' "${current_node}" "${current_url}"
  fi

  printf '%s\n' '```'
}

state_summary_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- Base case for TraderX generated code.
- Runtime model: uncontainerized local processes in deterministic startup order.
- Browser directly calls multiple service ports (cross-origin CORS behavior is part of this state).
EOF
      ;;
  002-edge-proxy-uncontainerized)
      cat <<'EOF'
- Builds on state `001` while keeping uncontainerized process runtime.
- Adds `edge-proxy` as a single browser-facing origin for UI + API + WebSocket traffic.
- Preserves baseline functional behavior with topology-focused NFR deltas.
EOF
      ;;
    003-agentic-harness-foundation)
      cat <<'EOF'
- Builds on state `002` while preserving uncontainerized edge-proxy runtime behavior.
- Adds generated repository harness metadata (`AGENTS.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`).
- Clarifies contribution flow: durable enhancements belong in upstream specs/state packs.
EOF
      ;;
    004-containerized-compose-runtime)
      cat <<'EOF'
- Builds on state `003` by moving runtime to Docker Compose.
- Uses NGINX ingress (`ingress` service) as the browser/API/WebSocket entrypoint.
- Preserves baseline functional behavior while changing runtime/ops model.
EOF
      ;;
    010-kubernetes-runtime)
      cat <<'EOF'
- Builds on state `009` by moving runtime from Docker Compose to Kubernetes (Kind baseline).
- Uses in-cluster NGINX edge-proxy as browser/API/WebSocket entrypoint at `http://localhost:8080`.
- Preserves C2 functional behavior while changing runtime orchestration and deployment model.
EOF
      ;;
    013-radius-kubernetes-platform)
      cat <<'EOF'
- Builds on state `010` and preserves Kubernetes runtime behavior.
- Adds Radius application/resource model artifacts as platform abstraction overlays.
- Preserves baseline functional behavior and API contracts.
EOF
      ;;
    011-tilt-kubernetes-dev-loop)
      cat <<'EOF'
- Builds on state `010` and preserves Kubernetes runtime behavior.
- Adds Tilt local developer-loop artifacts (`Tiltfile`, Tilt settings, workflow docs).
- Preserves baseline functional behavior and API contracts.
EOF
      ;;
    006-messaging-nats-replacement)
      cat <<'EOF'
- Builds on state `004` and preserves containerized ingress runtime behavior.
- Replaces Socket.IO trade-feed with NATS broker for backend and browser streaming.
- Preserves baseline user-visible behavior while changing messaging transport.
EOF
      ;;
    005-postgres-database-replacement)
      cat <<'EOF'
- Builds on state `004` and preserves containerized ingress runtime behavior.
- Replaces H2 runtime database with PostgreSQL container + deterministic init SQL.
- Preserves baseline REST/event contracts and user-visible behavior.
EOF
      ;;
    008-pricing-awareness-market-data)
      cat <<'EOF'
- Builds on state `007` and preserves NATS-based messaging + compose ingress runtime behavior.
- Adds market pricing stream, trade execution price stamping, and position average cost basis aggregation.
- Extends UI blotters with pricing/value/P&L visualization while preserving baseline trade/account workflows.
EOF
      ;;
    014-fdc3-intent-interoperability)
      cat <<'EOF'
- Builds on state `012` and preserves C3 runtime behavior.
- Adds TraderX app-side FDC3 flows plus a local Sail sidecar and two-tab demo profile.
- Keeps interoperability payloads canonical (`fdc3.instrument.id.ticker`) and tracks Sail-specific workaround logic as technical debt.
EOF
      ;;
    *)
      cat <<'EOF'
- Generated code snapshot for TraderX state transition.
EOF
      ;;
  esac
}

runtime_guidance_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-base-uncontainerized-generated.sh
```

```powershell
./scripts/start-base-uncontainerized-generated.ps1
```

UI endpoint: `http://localhost:18093`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

```powershell
./scripts/status-base-uncontainerized-generated.ps1
./scripts/stop-base-uncontainerized-generated.ps1
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/start-state-002-edge-proxy-generated.ps1
```

Browser endpoint (via edge proxy): `http://localhost:18080`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/status-state-002-edge-proxy-generated.ps1
./scripts/stop-state-002-edge-proxy-generated.ps1
```
EOF
      ;;
    003-agentic-harness-foundation)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

```powershell
./scripts/start-state-003-agentic-harness-foundation-generated.ps1
```

Browser endpoint (via edge proxy): `http://localhost:18080`

State-specific generated metadata:

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
EOF
      ;;
    004-containerized-compose-runtime)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-004-containerized-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`

Stop:

```bash
./scripts/stop-state-004-containerized-generated.sh
```
EOF
      ;;
    010-kubernetes-runtime)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
```

UI/edge endpoint: `http://localhost:8080`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh
./scripts/stop-state-010-kubernetes-runtime-generated.sh
```
EOF
      ;;
    013-radius-kubernetes-platform)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`

Radius artifact pack:

- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/stop-state-010-kubernetes-runtime-generated.sh --provider kind
```
EOF
      ;;
    011-tilt-kubernetes-dev-loop)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`
Tilt UI: `http://localhost:10350`

Tilt artifact pack:

- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/stop-state-010-kubernetes-runtime-generated.sh --provider kind
```
EOF
      ;;
    006-messaging-nats-replacement)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-006-messaging-nats-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```
EOF
      ;;
    005-postgres-database-replacement)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-005-postgres-database-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
PostgreSQL endpoint: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-005-postgres-database-replacement-generated.sh
./scripts/stop-state-005-postgres-database-replacement-generated.sh
```
EOF
      ;;
    008-pricing-awareness-market-data)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`
Price publisher endpoint: `http://localhost:18100/prices`

Smoke test:

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```

Status / stop:

```bash
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
```
EOF
      ;;
    *)
      cat <<'EOF'
See `RUN_FROM_CLONE.md` for clone-first runtime instructions.
EOF
      ;;
  esac
}

interactive_urls_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- UI: `http://localhost:18093`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Account service Swagger: `http://localhost:18088/v3/api-docs`
EOF
      ;;
    002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
      cat <<'EOF'
- UI (edge): `http://localhost:18080`
- API explorer (edge): `http://localhost:18080/api/docs`
- Trade service Swagger (edge): `http://localhost:18080/trade-service/v3/api-docs`
- Account service Swagger (edge): `http://localhost:18080/account-service/v3/api-docs`
EOF
      ;;
    004-containerized-compose-runtime|005-postgres-database-replacement|006-messaging-nats-replacement|008-pricing-awareness-market-data)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Account service API sample: `http://localhost:18088/account/22214`
- Position service health: `http://localhost:18090/health/alive`
EOF
      ;;
    007-observability-lgtm-compose)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
EOF
      ;;
    009-order-management-matcher)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Order matcher health: `http://localhost:18110/health`
- Order matcher metrics: `http://localhost:18110/metrics`
EOF
      ;;
    010-kubernetes-runtime|011-tilt-kubernetes-dev-loop|012-platform-convergence-c3|013-radius-kubernetes-platform)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade page: `http://localhost:8080/trade`
- Account service route: `http://localhost:8080/account-service/account/22214`
- Position service route: `http://localhost:8080/position-service/positions/22214`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Prometheus (ingress): `http://localhost:8080/prometheus`
EOF
      ;;
    *)
      cat <<'EOF'
- Use `./scripts/status-*.sh` for this state to print active endpoint URLs.
EOF
      ;;
  esac
}

windows_supported_for_state() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity|002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

snapshot_platform_badges_markdown() {
  local linux_badge='![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux)'
  local windows_badge='![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)'

  if windows_supported_for_state; then
    windows_badge='![windows support](https://badgen.net/badge/windows/supported/green?icon=windows)'
  fi

  printf '%s %s\n' "${linux_badge}" "${windows_badge}"
}

api_explorer_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- Not available in this state (no edge/ingress API explorer mount).
EOF
      ;;
    002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
      cat <<'EOF'
- API explorer (edge): `http://localhost:18080/api/docs`
EOF
      ;;
    *)
      cat <<'EOF'
- API explorer (ingress): `http://localhost:8080/api/docs`
EOF
      ;;
  esac
}

learning_focus_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- Understand baseline service boundaries and call patterns.
- Understand startup sequencing and fixed port coupling.
- Understand why CORS is an explicit NFR in this state.
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat <<'EOF'
- Understand browser traffic consolidation through the edge proxy.
- Understand how path routing and websocket proxying preserve baseline behavior.
- Compare cross-origin behavior vs state 001.
EOF
      ;;
    003-agentic-harness-foundation)
      cat <<'EOF'
- Understand generated repo harness metadata and agent operating boundaries.
- Understand how generated snapshots support experimentation but not primary contribution flow.
- Validate that contribution guidance points back to upstream specs and state packs.
EOF
      ;;
    004-containerized-compose-runtime)
      cat <<'EOF'
- Understand runtime transition from host processes to containers.
- Understand NGINX ingress behavior under Compose.
- Trace container wiring back to unchanged functional requirements.
EOF
      ;;
    010-kubernetes-runtime)
      cat <<'EOF'
- Understand Kubernetes deployment/service decomposition.
- Understand image build plan and runtime orchestration scripts.
- Compare local Kind/Minikube execution model to state 004.
EOF
      ;;
    013-radius-kubernetes-platform)
      cat <<'EOF'
- Understand Radius artifacts as a platform-model overlay on Kubernetes.
- Understand what remains baseline runtime vs what is platform abstraction.
- Evaluate portability goals and platform-level NFR impact.
EOF
      ;;
    011-tilt-kubernetes-dev-loop)
      cat <<'EOF'
- Understand developer-loop acceleration using Tilt.
- Understand what parts are runtime-stable vs dev-loop specific.
- Evaluate inner-loop productivity deltas while preserving contracts.
EOF
      ;;
    006-messaging-nats-replacement)
      cat <<'EOF'
- Understand focused messaging-layer replacement on top of stable runtime.
- Compare NATS subject topology to prior Socket.IO channel patterns.
- Validate realtime behavior parity while changing transport internals.
EOF
      ;;
    005-postgres-database-replacement)
      cat <<'EOF'
- Understand focused database-engine replacement on top of stable runtime.
- Compare datasource and schema-init changes required for PostgreSQL migration.
- Validate flow compatibility after persistence-layer substitution.
EOF
      ;;
    008-pricing-awareness-market-data)
      cat <<'EOF'
- Understand how pricing streams integrate with existing account-scoped event flows.
- Review trade execution price stamping and position cost-basis aggregation logic.
- Validate realtime UI valuation behavior (position value, totals, and P&L) under live price ticks.
EOF
      ;;
    014-fdc3-intent-interoperability)
      cat <<'EOF'
- Understand inbound/outbound FDC3 flows between TraderX and the local Sail demo desktop agent.
- Validate two-tab Sail demo behaviors (tab `One`: chart/pricing/ticket-launch controls; tab `Two`: news view).
- Track temporary Sail interop workarounds and expected removal path toward robust event delivery and CDM-native symbology.
EOF
      ;;
    *)
      cat <<'EOF'
- Review state metadata and runtime instructions.
- Trace state intent back to canonical SpecKit artifacts.
EOF
      ;;
  esac
}

require_snapshot_component_dir() {
  local component_rel="$1"
  if [[ ! -d "${SNAPSHOT_DIR}/${component_rel}" ]]; then
    local source_component_dir=""
    case "${component_rel}" in
      web-front-end/angular)
        source_component_dir="${GENERATED_ROOT}/code/components/web-front-end-angular-specfirst"
        ;;
      *)
        source_component_dir="${GENERATED_ROOT}/code/components/${component_rel}-specfirst"
        ;;
    esac

    if [[ -d "${source_component_dir}" ]]; then
      mkdir -p "${SNAPSHOT_DIR}/${component_rel}"
      cp -R "${source_component_dir}/." "${SNAPSHOT_DIR}/${component_rel}/"
    fi
  fi

  if [[ ! -d "${SNAPSHOT_DIR}/${component_rel}" ]]; then
    echo "[fail] expected component directory missing in snapshot: ${component_rel}"
    exit 1
  fi
}

link_snapshot_component() {
  local component_name="$1"
  local component_rel="$2"
  require_snapshot_component_dir "${component_rel}"
  ln -sfn "../../../${component_rel}" "${SNAPSHOT_DIR}/generated/code/components/${component_name}-specfirst"
}

extract_script_dependencies_from_file() {
  local script_path="$1"
  [[ -f "${script_path}" ]] || return 0
  sed -nE 's#.*\/scripts\/([A-Za-z0-9._-]+\.sh).*#\1#p' "${script_path}" | sort -u
}

COPIED_SNAPSHOT_SCRIPTS=""
copy_snapshot_script_with_deps() {
  local script_name="$1"
  [[ -n "${script_name}" ]] || return 0

  if [[ "${COPIED_SNAPSHOT_SCRIPTS}" == *"|${script_name}|"* ]]; then
    return 0
  fi
  COPIED_SNAPSHOT_SCRIPTS="${COPIED_SNAPSHOT_SCRIPTS}|${script_name}|"

  local snapshot_script="${SNAPSHOT_DIR}/scripts/${script_name}"
  local source_script=""
  if [[ -f "${snapshot_script}" ]]; then
    source_script="${snapshot_script}"
  elif [[ -f "${ROOT}/scripts/${script_name}" ]]; then
    mkdir -p "${SNAPSHOT_DIR}/scripts"
    cp "${ROOT}/scripts/${script_name}" "${snapshot_script}"
    chmod +x "${snapshot_script}" 2>/dev/null || true
    source_script="${snapshot_script}"
  else
    return 0
  fi

  local dep
  while IFS= read -r dep; do
    [[ -n "${dep}" ]] || continue
    [[ "${dep}" == "${script_name}" ]] && continue
    copy_snapshot_script_with_deps "${dep}"
  done < <(extract_script_dependencies_from_file "${source_script}")
}

resolve_primary_script_for_action() {
  local action="$1"
  local state_num="${STATE_ID%%-*}"
  local candidate=""
  case "${action}" in
    start|stop|status)
      candidate="scripts/${action}-state-${STATE_ID}-generated.sh"
      ;;
    test)
      candidate="scripts/test-state-${STATE_ID}.sh"
      ;;
    *)
      return 1
      ;;
  esac

  if [[ -f "${SNAPSHOT_DIR}/${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  # Some generated runtime scripts intentionally use shortened numeric prefixes
  # (e.g. 004 -> start-state-004-containerized-generated.sh). Fall back to the
  # first matching state-number-prefixed script for the requested action.
  case "${action}" in
    start|stop|status)
      candidate="$(find "${SNAPSHOT_DIR}/scripts" -maxdepth 1 -type f -name "${action}-state-${state_num}-*-generated.sh" -print | sed "s#^${SNAPSHOT_DIR}/##" | sort | head -n 1 || true)"
      ;;
    test)
      candidate="$(find "${SNAPSHOT_DIR}/scripts" -maxdepth 1 -type f -name "test-state-${state_num}-*.sh" -print | sed "s#^${SNAPSHOT_DIR}/##" | sort | head -n 1 || true)"
      ;;
  esac
  if [[ -n "${candidate}" && -f "${SNAPSHOT_DIR}/${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  case "${action}" in
    start)
      candidate="scripts/start-base-uncontainerized-generated.sh"
      ;;
    stop)
      candidate="scripts/stop-base-uncontainerized-generated.sh"
      ;;
    status)
      candidate="scripts/status-base-uncontainerized-generated.sh"
      ;;
    test)
      candidate=""
      ;;
  esac

  if [[ -n "${candidate}" && -f "${SNAPSHOT_DIR}/${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  return 1
}

collect_snapshot_script_dependency_closure() {
  local root_script_name="$1"
  local queue=("${root_script_name}")
  local seen=""
  local current dep

  while ((${#queue[@]} > 0)); do
    current="${queue[0]}"
    queue=("${queue[@]:1}")

    if [[ "${seen}" == *"|${current}|"* ]]; then
      continue
    fi
    seen="${seen}|${current}|"
    printf '%s\n' "${current}"

    if [[ ! -f "${SNAPSHOT_DIR}/scripts/${current}" ]]; then
      continue
    fi

    while IFS= read -r dep; do
      [[ -n "${dep}" ]] || continue
      [[ -f "${SNAPSHOT_DIR}/scripts/${dep}" ]] || continue
      queue+=("${dep}")
    done < <(extract_script_dependencies_from_file "${SNAPSHOT_DIR}/scripts/${current}")
  done
}

write_env_wrapper_script() {
  local wrapper_name="$1"
  local action="$2"
  local target_script="$3"
  local wrapper_path="${SNAPSHOT_DIR}/${wrapper_name}"
  local target_script_name="${target_script#scripts/}"

  local flow_lines=""
  local dep_count=0
  local dep_script
  while IFS= read -r dep_script; do
    [[ -n "${dep_script}" ]] || continue
    dep_count=$((dep_count + 1))
    flow_lines="${flow_lines}#  - scripts/${dep_script}\n"
  done < <(collect_snapshot_script_dependency_closure "${target_script_name}")

  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n\n' 'ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
    printf '%s\n' "# Wrapper purpose: stable, state-local ${action} entrypoint."
    printf '%s\n' '# This may delegate across multiple numbered state scripts to maximize reuse.'
    if (( dep_count > 1 )); then
      printf '%s\n' '# Execution flow:'
      printf '%b' "${flow_lines}"
    else
      printf '%s\n' "# Execution flow: scripts/${target_script_name}"
    fi
    printf '\nexec "${ROOT}/%s" "$@"\n' "${target_script}"
  } > "${wrapper_path}"
  chmod +x "${wrapper_path}"
}

write_env_wrapper_batch_script() {
  local wrapper_name="$1"
  local action="$2"
  local target_script="$3"
  local wrapper_path="${SNAPSHOT_DIR}/${wrapper_name}"
  local target_script_name="${target_script#scripts/}"
  local target_ps1_name="${target_script_name%.sh}.ps1"
  local target_ps1_windows="${target_ps1_name//\//\\}"

  if [[ -f "${SNAPSHOT_DIR}/scripts/${target_ps1_name}" ]]; then
    cat > "${wrapper_path}" <<EOF
@echo off
setlocal
set "ROOT=%~dp0"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\\${target_ps1_windows}" %*
EOF
    return 0
  fi

  cat > "${wrapper_path}" <<EOF
@echo off
echo [error] no PowerShell entrypoint is available for ${action} in this state snapshot.
echo [hint] use .\\${wrapper_name%.bat}.sh on Linux/macOS.
exit /b 2
EOF
}

write_test_env_wrapper_without_target() {
  local wrapper_path="${SNAPSHOT_DIR}/test-env.sh"
  cat > "${wrapper_path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[info] no state-specific test entrypoint was detected for this snapshot."
if [[ -d "${ROOT}/scripts" ]]; then
  echo "[hint] available test scripts:"
  ls "${ROOT}/scripts"/test-state-*.sh 2>/dev/null || true
fi
exit 2
EOF
  chmod +x "${wrapper_path}"
}

write_test_env_wrapper_without_target_batch() {
  local wrapper_path="${SNAPSHOT_DIR}/test-env.bat"
  cat > "${wrapper_path}" <<'EOF'
@echo off
echo [info] no state-specific test entrypoint was detected for this snapshot.
if exist "%~dp0scripts" (
  echo [hint] available test scripts:
  dir /b "%~dp0scripts\test-state-*.ps1" 2>nul
  dir /b "%~dp0scripts\test-state-*.sh" 2>nul
)
exit /b 2
EOF
}

prune_snapshot_scripts_for_targets() {
  local keep_file
  keep_file="$(mktemp "${TMPDIR:-/tmp}/traderx-snapshot-script-keep.XXXXXX")"

  add_script_keep() {
    local rel="$1"
    [[ -n "${rel}" ]] || return 0
    [[ -f "${SNAPSHOT_DIR}/scripts/${rel}" ]] || return 0
    if ! grep -Fxq "${rel}" "${keep_file}"; then
      printf '%s\n' "${rel}" >> "${keep_file}"
    fi
  }

  add_script_keep "README.runtime-harness.md"
  add_script_keep "lib/generated-state-detection.sh"
  add_script_keep "lib/generated-state-detection.ps1"
  add_script_keep "lib/resolve-socketio-client-path.sh"
  add_script_keep "lib/runtime-common.ps1"

  local target dep dep_root
  for target in "$@"; do
    [[ -n "${target}" ]] || continue
    dep_root="${target#scripts/}"
    while IFS= read -r dep; do
      [[ -n "${dep}" ]] || continue
      add_script_keep "${dep}"
    done < <(collect_snapshot_script_dependency_closure "${dep_root}")
  done

  local rel sibling_ps1
  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    if [[ "${rel}" == *.sh ]]; then
      sibling_ps1="${rel%.sh}.ps1"
      add_script_keep "${sibling_ps1}"
    fi
  done < "${keep_file}"

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    if ! grep -Fxq "${rel}" "${keep_file}"; then
      rm -f "${SNAPSHOT_DIR}/scripts/${rel}"
    fi
  done < <(find "${SNAPSHOT_DIR}/scripts" -type f -print | sed "s#^${SNAPSHOT_DIR}/scripts/##" | sort)

  find "${SNAPSHOT_DIR}/scripts" -type d -empty -delete
  rm -f "${keep_file}"
}

write_env_entrypoint_wrappers() {
  local start_target stop_target status_target test_target

  start_target="$(resolve_primary_script_for_action start || true)"
  stop_target="$(resolve_primary_script_for_action stop || true)"
  status_target="$(resolve_primary_script_for_action status || true)"
  test_target="$(resolve_primary_script_for_action test || true)"

  if [[ -z "${start_target}" || -z "${stop_target}" || -z "${status_target}" ]]; then
    echo "[fail] missing mandatory runtime scripts for env wrappers in ${STATE_ID}"
    echo "[hint] expected start/stop/status scripts under snapshot scripts/"
    exit 1
  fi

  write_env_wrapper_script "start-env.sh" "start" "${start_target}"
  write_env_wrapper_script "stop-env.sh" "stop" "${stop_target}"
  write_env_wrapper_script "status-env.sh" "status" "${status_target}"
  if windows_supported_for_state; then
    write_env_wrapper_batch_script "start-env.bat" "start" "${start_target}"
    write_env_wrapper_batch_script "stop-env.bat" "stop" "${stop_target}"
    write_env_wrapper_batch_script "status-env.bat" "status" "${status_target}"
  else
    rm -f "${SNAPSHOT_DIR}/start-env.bat" "${SNAPSHOT_DIR}/stop-env.bat" "${SNAPSHOT_DIR}/status-env.bat" "${SNAPSHOT_DIR}/test-env.bat"
  fi

  if [[ -n "${test_target}" ]]; then
    write_env_wrapper_script "test-env.sh" "test" "${test_target}"
    if windows_supported_for_state; then
      write_env_wrapper_batch_script "test-env.bat" "test" "${test_target}"
    fi
  else
    write_test_env_wrapper_without_target
    if windows_supported_for_state; then
      write_test_env_wrapper_without_target_batch
    fi
  fi

  prune_snapshot_scripts_for_targets "${start_target}" "${stop_target}" "${status_target}" "${test_target}"
}

assert_snapshot_clone_entrypoints() {
  local required_exec
  for required_exec in start-env.sh stop-env.sh status-env.sh test-env.sh; do
    if [[ ! -x "${SNAPSHOT_DIR}/${required_exec}" ]]; then
      echo "[fail] missing executable wrapper: ${required_exec}"
      exit 1
    fi
  done

  if windows_supported_for_state; then
    local required_batch
    for required_batch in start-env.bat stop-env.bat status-env.bat test-env.bat; do
      if [[ ! -f "${SNAPSHOT_DIR}/${required_batch}" ]]; then
        echo "[fail] missing batch wrapper: ${required_batch}"
        exit 1
      fi
    done
  fi

  if [[ ! -f "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" ]]; then
    echo "[fail] missing RUN_FROM_CLONE.md in snapshot"
    exit 1
  fi

  if rg -q "No state-specific clone runtime instructions were generated" "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md"; then
    echo "[fail] clone runbook placeholder detected for ${STATE_ID}; add explicit instructions"
    exit 1
  fi
}

install_uncontainerized_clone_harness() {
  copy_uncontainerized_script_with_ps1_sibling() {
    local script_name="$1"
    if [[ -f "${ROOT}/scripts/${script_name}" ]]; then
      cp "${ROOT}/scripts/${script_name}" "${SNAPSHOT_DIR}/scripts/"
    fi
    if [[ "${script_name}" == *.sh ]]; then
      local ps_script="${script_name%.sh}.ps1"
      if [[ -f "${ROOT}/scripts/${ps_script}" ]]; then
        cp "${ROOT}/scripts/${ps_script}" "${SNAPSHOT_DIR}/scripts/"
      fi
    fi
  }

  mkdir -p \
    "${SNAPSHOT_DIR}/scripts" \
    "${SNAPSHOT_DIR}/scripts/lib" \
    "${SNAPSHOT_DIR}/catalog" \
    "${SNAPSHOT_DIR}/generated/code/components" \
    "${SNAPSHOT_DIR}/generated/code/target-generated"

  cp -R "${ROOT}/scripts/lib/." "${SNAPSHOT_DIR}/scripts/lib/"
  copy_uncontainerized_script_with_ps1_sibling "start-base-uncontainerized-generated.sh"
  copy_uncontainerized_script_with_ps1_sibling "stop-base-uncontainerized-generated.sh"
  copy_uncontainerized_script_with_ps1_sibling "status-base-uncontainerized-generated.sh"
  cp "${ROOT}/catalog/base-uncontainerized-processes.csv" "${SNAPSHOT_DIR}/catalog/"

  link_snapshot_component "reference-data" "reference-data"
  link_snapshot_component "database" "database"
  link_snapshot_component "people-service" "people-service"
  link_snapshot_component "account-service" "account-service"
  link_snapshot_component "position-service" "position-service"
  link_snapshot_component "trade-feed" "trade-feed"
  link_snapshot_component "trade-processor" "trade-processor"
  link_snapshot_component "trade-service" "trade-service"
  link_snapshot_component "web-front-end-angular" "web-front-end/angular"

if [[ "${STATE_ID}" == "002-edge-proxy-uncontainerized" || "${STATE_ID}" == "003-agentic-harness-foundation" ]]; then
  copy_uncontainerized_script_with_ps1_sibling "start-state-002-edge-proxy-generated.sh"
  copy_uncontainerized_script_with_ps1_sibling "stop-state-002-edge-proxy-generated.sh"
  copy_uncontainerized_script_with_ps1_sibling "status-state-002-edge-proxy-generated.sh"
  copy_uncontainerized_script_with_ps1_sibling "test-state-002-edge-proxy.sh"
  copy_uncontainerized_script_with_ps1_sibling "test-web-angular-baseline-ux-contract.sh"

  if [[ "${STATE_ID}" == "003-agentic-harness-foundation" ]]; then
    copy_uncontainerized_script_with_ps1_sibling "start-state-003-agentic-harness-foundation-generated.sh"
    copy_uncontainerized_script_with_ps1_sibling "stop-state-003-agentic-harness-foundation-generated.sh"
    copy_uncontainerized_script_with_ps1_sibling "status-state-003-agentic-harness-foundation-generated.sh"
    copy_uncontainerized_script_with_ps1_sibling "test-state-003-agentic-harness-foundation.sh"
  fi

  if [[ ! -d "${SNAPSHOT_DIR}/edge-proxy" ]]; then
      local edge_source="${GENERATED_ROOT}/code/components/edge-proxy-specfirst"
      if [[ ! -d "${edge_source}" ]]; then
        echo "[fail] missing generated edge-proxy component: ${edge_source}"
        echo "[hint] run: bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized"
        exit 1
      fi
      mkdir -p "${SNAPSHOT_DIR}/edge-proxy"
      cp -R "${edge_source}/." "${SNAPSHOT_DIR}/edge-proxy/"
    fi

    link_snapshot_component "edge-proxy" "edge-proxy"
  fi
}

install_containerized_clone_harness() {
  mkdir -p "${SNAPSHOT_DIR}/scripts"

  cat > "${SNAPSHOT_DIR}/scripts/start-state-004-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-004}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"
DRY_RUN=0
SKIP_BUILD=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build"
      exit 1
      ;;
  esac
  shift
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

if (( DRY_RUN == 1 )); then
  if (( SKIP_BUILD == 1 )); then
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --no-build"
  else
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --build"
  fi
  echo "[done] dry run complete for state 004"
  exit 0
fi

if (( SKIP_BUILD == 1 )); then
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --no-build
else
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build
fi
echo "[done] state 004 containerized compose runtime started"
echo "[ui] http://localhost:8080"
echo "[api-explorer] http://localhost:8080/api/docs"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/stop-state-004-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-004}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" down --remove-orphans
echo "[done] state 004 containerized compose runtime stopped"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/status-state-004-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-004}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
EOF

  chmod +x \
    "${SNAPSHOT_DIR}/scripts/start-state-004-containerized-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/stop-state-004-containerized-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/status-state-004-containerized-generated.sh"
}

install_state_compose_clone_harness() {
  local state_id="$1"
  mkdir -p "${SNAPSHOT_DIR}/scripts"
  COPIED_SNAPSHOT_SCRIPTS=""

  local script_name
  for script_name in \
    "start-state-${state_id}-generated.sh" \
    "stop-state-${state_id}-generated.sh" \
    "status-state-${state_id}-generated.sh" \
    "test-state-${state_id}.sh"; do
    copy_snapshot_script_with_deps "${script_name}"
  done
  local state_num="${state_id%%-*}"
  local messaging_script
  messaging_script="$(
    find "${ROOT}/scripts" -maxdepth 1 -type f -name "test-messaging-${state_num}-*.sh" -print \
      | sed "s#^${ROOT}/scripts/##" | sort | head -n 1 || true
  )"
  if [[ -n "${messaging_script}" ]]; then
    copy_snapshot_script_with_deps "${messaging_script}"
  fi

  if [[ "${state_id}" == "012-platform-convergence-c3" ]]; then
    cat > "${SNAPSHOT_DIR}/scripts/start-state-012-platform-convergence-c3-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/tilt-kubernetes-dev-loop"
TILT_DIR="${STATE_DIR}/tilt"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
RUN_TILT=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-012}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --run-tilt)
      RUN_TILT=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    --minikube-driver)
      MINIKUBE_DRIVER="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --run-tilt --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

for required in \
  "${STATE_DIR}/README.md" \
  "${TILT_DIR}/Tiltfile" \
  "${TILT_DIR}/tilt-settings.json" \
  "${TILT_DIR}/README.md"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing state 012 artifact: ${required}"
    exit 1
  }
done

start_args=(--provider "${K8S_PROVIDER}")
start_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
if (( DRY_RUN == 1 )); then
  start_args+=(--dry-run)
fi
if (( SKIP_BUILD == 1 )); then
  start_args+=(--skip-build)
fi
if (( RECREATE_CLUSTER == 1 )); then
  start_args+=(--recreate-cluster)
fi
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  start_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi
if [[ -n "${MINIKUBE_DRIVER}" ]]; then
  start_args+=(--minikube-driver "${MINIKUBE_DRIVER}")
fi

"${ROOT}/scripts/start-state-010-kubernetes-runtime-generated.sh" "${start_args[@]}"

if (( DRY_RUN == 1 )); then
  echo "[dry-run] tilt assets validated at ${TILT_DIR}"
  if (( RUN_TILT == 1 )); then
    echo "[dry-run] (cd ${TILT_DIR} && tilt up)"
  fi
  echo "[done] dry run complete for state 012"
  exit 0
fi

echo "[info] state 012 convergence assets ready at ${TILT_DIR}"
if command -v tilt >/dev/null 2>&1; then
  echo "[info] tilt CLI detected: $(tilt version | head -n 1)"
  if (( RUN_TILT == 1 )); then
    echo "[start] launching Tilt from ${TILT_DIR}"
    cd "${TILT_DIR}"
    exec tilt up
  fi
  echo "[hint] run: (cd ${TILT_DIR} && tilt up)"
else
  echo "[info] tilt CLI not found; install Tilt to run local dev loop"
fi

echo "[done] state 012 platform convergence ready (runtime inherited from state 010)"
EOF

    cat > "${SNAPSHOT_DIR}/scripts/stop-state-012-platform-convergence-c3-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DELETE_CLUSTER=0
STOP_TILT=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-012}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --stop-tilt)
      STOP_TILT=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --delete-cluster --stop-tilt --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

if (( STOP_TILT == 1 )); then
  pids="$(pgrep -f "tilt up" || true)"
  for pid in ${pids}; do
    if kill -0 "${pid}" >/dev/null 2>&1; then
      echo "[stop] tilt up process (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done
fi

stop_args=(--provider "${K8S_PROVIDER}")
stop_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
if (( DELETE_CLUSTER == 1 )); then
  stop_args+=(--delete-cluster)
fi
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  stop_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi

"${ROOT}/scripts/stop-state-010-kubernetes-runtime-generated.sh" "${stop_args[@]}"
echo "[done] state 012 stop sequence complete"
EOF

    cat > "${SNAPSHOT_DIR}/scripts/status-state-012-platform-convergence-c3-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/tilt-kubernetes-dev-loop"
TILT_DIR="${STATE_DIR}/tilt"

K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-012}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

status_args=(--provider "${K8S_PROVIDER}")
status_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  status_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi

"${ROOT}/scripts/status-state-010-kubernetes-runtime-generated.sh" "${status_args[@]}"

echo
echo "[status] tilt artifacts"
for target in \
  "${STATE_DIR}/README.md" \
  "${TILT_DIR}/Tiltfile" \
  "${TILT_DIR}/tilt-settings.json" \
  "${TILT_DIR}/README.md"; do
  if [[ -f "${target}" ]]; then
    echo "[ok] ${target}"
  else
    echo "[missing] ${target}"
  fi
done

tilt_running="no"
if pgrep -af "tilt up" >/dev/null 2>&1; then
  tilt_running="yes"
fi
echo "[info] tilt-up-running: ${tilt_running}"

if command -v tilt >/dev/null 2>&1; then
  echo "[info] tilt CLI: $(tilt version | head -n 1)"
else
  echo "[info] tilt CLI not found on PATH"
fi
EOF

    chmod +x \
      "${SNAPSHOT_DIR}/scripts/start-state-012-platform-convergence-c3-generated.sh" \
      "${SNAPSHOT_DIR}/scripts/stop-state-012-platform-convergence-c3-generated.sh" \
      "${SNAPSHOT_DIR}/scripts/status-state-012-platform-convergence-c3-generated.sh"
  fi
}

install_kubernetes_clone_harness() {
  mkdir -p "${SNAPSHOT_DIR}/scripts"

  cat > "${SNAPSHOT_DIR}/scripts/start-state-010-kubernetes-runtime-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-010-kubernetes-runtime"

SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
USE_PUBLISHED_IMAGES="${TRADERX_USE_PUBLISHED_IMAGES:-0}"
PUBLISHED_REGISTRY="${TRADERX_PUBLISHED_REGISTRY:-ghcr.io/finos}"
PUBLISHED_NAMESPACE="${TRADERX_PUBLISHED_NAMESPACE:-}"
PUBLISHED_TAG="${TRADERX_PUBLISHED_TAG:-latest}"

while (( "$#" )); do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    --minikube-driver)
      MINIKUBE_DRIVER="${2:-}"
      shift
      ;;
    --use-published-images)
      USE_PUBLISHED_IMAGES=1
      ;;
    --published-registry)
      PUBLISHED_REGISTRY="${2:-}"
      shift
      ;;
    --published-namespace)
      PUBLISHED_NAMESPACE="${2:-}"
      shift
      ;;
    --published-tag)
      PUBLISHED_TAG="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --skip-build --recreate-cluster --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name> --use-published-images --published-registry <registry> --published-namespace <namespace> --published-tag <tag>"
      exit 1
      ;;
  esac
  shift
done

if (( USE_PUBLISHED_IMAGES == 1 )); then
  SKIP_BUILD=1
  if [[ -z "${PUBLISHED_NAMESPACE}" ]]; then
    echo "[error] published image mode requires namespace"
    echo "[hint] set --published-namespace <name> or TRADERX_PUBLISHED_NAMESPACE=<name>"
    exit 1
  fi
fi

for cmd in docker kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }
[[ -f "${KIND_CONFIG}" ]] || { echo "[error] missing ${KIND_CONFIG}"; exit 1; }
[[ -d "${KUSTOMIZE_DIR}" ]] || { echo "[error] missing ${KUSTOMIZE_DIR}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
edge_service="$(jq -r '.edgeService' "${BUILD_PLAN}")"

if [[ -n "${KIND_CLUSTER_NAME}" ]]; then
  cluster_name="${KIND_CLUSTER_NAME}"
fi

if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind|minikube)
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

mkdir -p "${RUN_DIR}"
PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
PORT_FORWARD_LOG_FILE="${RUN_DIR}/minikube-port-forward.log"

stop_minikube_port_forward() {
  if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
    pid="$(cat "${PORT_FORWARD_PID_FILE}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${PORT_FORWARD_PID_FILE}"
  fi
}

if [[ "${K8S_PROVIDER}" == "kind" ]]; then
  if ! command -v kind >/dev/null 2>&1; then
    echo "[error] required command not found: kind"
    exit 1
  fi
  cluster_exists=0
  if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
    cluster_exists=1
  fi
  if (( cluster_exists == 1 && RECREATE_CLUSTER == 1 )); then
    kind delete cluster --name "${cluster_name}"
    cluster_exists=0
  fi
  if (( cluster_exists == 0 )); then
    kind create cluster --name "${cluster_name}" --config "${KIND_CONFIG}"
  fi
  kubectl config use-context "kind-${cluster_name}" >/dev/null
else
  if ! command -v minikube >/dev/null 2>&1; then
    echo "[error] required command not found: minikube"
    exit 1
  fi
  if (( RECREATE_CLUSTER == 1 )); then
    minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
  fi
  minikube start -p "${MINIKUBE_PROFILE}" --driver "${MINIKUBE_DRIVER}" >/dev/null
  if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
    kubectl config use-context "minikube" >/dev/null
  fi
fi

while IFS= read -r item; do
  name="$(jq -r '.name' <<<"${item}")"
  image="$(jq -r '.image' <<<"${item}")"
  if (( USE_PUBLISHED_IMAGES == 1 )); then
    published_image="${PUBLISHED_REGISTRY}/${PUBLISHED_NAMESPACE}/${name}:${PUBLISHED_TAG}"
    echo "[pull] ${name} <- ${published_image}"
    docker pull "${published_image}"
    docker tag "${published_image}" "${image}"
  elif (( SKIP_BUILD == 0 )); then
    context_rel="$(jq -r '.context' <<<"${item}")"
    dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
    context_abs="${ROOT}/${context_rel}"
    dockerfile_abs="${context_abs}/${dockerfile_rel}"

    [[ -d "${context_abs}" ]] || { echo "[error] missing build context ${context_abs}"; exit 1; }
    [[ -f "${dockerfile_abs}" ]] || { echo "[error] missing dockerfile ${dockerfile_abs}"; exit 1; }

    echo "[build] ${name} -> ${image}"
    docker build -t "${image}" -f "${dockerfile_abs}" "${context_abs}"
  else
    docker image inspect "${image}" >/dev/null 2>&1 || {
      echo "[error] --skip-build was set, but local image is missing: ${image}"
      echo "[hint] rerun without --skip-build to build images first."
      exit 1
    }
    echo "[reuse] using local image ${image} (--skip-build)"
  fi

  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    kind load docker-image "${image}" --name "${cluster_name}"
  else
    minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
  fi
done < <(jq -c '.images[]' "${BUILD_PLAN}")

kubectl apply -k "${KUSTOMIZE_DIR}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  stop_minikube_port_forward
  nohup kubectl -n "${namespace}" port-forward "svc/${edge_service}" "${host_port}:8080" >"${PORT_FORWARD_LOG_FILE}" 2>&1 &
  echo "$!" > "${PORT_FORWARD_PID_FILE}"
fi

echo "[done] state 010 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
if (( USE_PUBLISHED_IMAGES == 1 )); then
  echo "[images] published namespace=${PUBLISHED_NAMESPACE} tag=${PUBLISHED_TAG}"
fi
echo "[ui] http://localhost:${host_port}"
echo "[api-explorer] http://localhost:${host_port}/api/docs"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/stop-state-010-kubernetes-runtime-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${ROOT}/kubernetes-runtime/build-plan.json"
RUN_DIR="${ROOT}/kubernetes-runtime/.run/state-010-kubernetes-runtime"
DELETE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --delete-cluster --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
if [[ -n "${KIND_CLUSTER_NAME}" ]]; then
  cluster_name="${KIND_CLUSTER_NAME}"
fi
if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
  pid="$(cat "${PORT_FORWARD_PID_FILE}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${PORT_FORWARD_PID_FILE}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] required command not found: kind"
      exit 1
    fi
    if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1 || true
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    fi
    if (( DELETE_CLUSTER == 1 )); then
      kind delete cluster --name "${cluster_name}"
    fi
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] required command not found: minikube"
      exit 1
    fi
    if minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
        kubectl config use-context "minikube" >/dev/null 2>&1 || true
      fi
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    fi
    if (( DELETE_CLUSTER == 1 )); then
      minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[done] state 010 stop sequence complete"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/status-state-010-kubernetes-runtime-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${ROOT}/kubernetes-runtime/build-plan.json"
RUN_DIR="${ROOT}/kubernetes-runtime/.run/state-010-kubernetes-runtime"
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in kubectl jq curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
if [[ -n "${KIND_CLUSTER_NAME}" ]]; then
  cluster_name="${KIND_CLUSTER_NAME}"
fi
if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] required command not found: kind"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      echo "[info] kind cluster not found: ${cluster_name}"
      exit 0
    fi
    kubectl config use-context "kind-${cluster_name}" >/dev/null
    echo "[info] provider: kind"
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] required command not found: minikube"
      exit 1
    fi
    if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[info] minikube profile not running: ${MINIKUBE_PROFILE}"
      exit 0
    fi
    if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      kubectl config use-context "minikube" >/dev/null
    fi
    echo "[info] provider: minikube"
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[info] cluster/profile: ${cluster_name}"
kubectl get deployments -n "${namespace}" || true
kubectl get pods -n "${namespace}" || true
kubectl get services -n "${namespace}" || true

echo "[status] edge-health $(curl -sS -o /dev/null -w "%{http_code}" "http://localhost:${host_port}/health" 2>/dev/null || true)"

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  pid="-"
  running="no"
  pid_file="${RUN_DIR}/minikube-port-forward.pid"
  if [[ -f "${pid_file}" ]]; then
    pid="$(cat "${pid_file}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      running="yes"
    fi
  fi
  echo "[status] minikube-port-forward pid=${pid} running=${running}"
fi
EOF

  chmod +x \
    "${SNAPSHOT_DIR}/scripts/start-state-010-kubernetes-runtime-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/stop-state-010-kubernetes-runtime-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/status-state-010-kubernetes-runtime-generated.sh"
}

write_clone_runbook() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

```powershell
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-base-uncontainerized-generated.ps1 -BuildOnly
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-base-uncontainerized-generated.ps1
```

Endpoints:
- UI: `http://localhost:18093`
- Reference data: `http://localhost:18085/stocks`
- Trade service swagger: `http://localhost:18092/v3/api-docs`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

```powershell
./scripts/status-base-uncontainerized-generated.ps1
./scripts/stop-base-uncontainerized-generated.ps1
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-002-edge-proxy-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-002-edge-proxy-generated.sh
```

```powershell
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-state-002-edge-proxy-generated.ps1 -BuildOnly
$env:CORS_ALLOWED_ORIGINS='http://localhost:18093'; ./scripts/start-state-002-edge-proxy-generated.ps1
```

Endpoints:
- Browser entrypoint (edge proxy): `http://localhost:18080`
- API explorer (edge proxy): `http://localhost:18080/api/docs`
- Angular direct dev server: `http://localhost:18093`
- Edge proxy health: `http://localhost:18080/health`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/status-state-002-edge-proxy-generated.ps1
./scripts/stop-state-002-edge-proxy-generated.ps1
```
EOF
      ;;
    003-agentic-harness-foundation)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
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
EOF
      ;;
    004-containerized-compose-runtime)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-004-containerized-generated.sh
./scripts/start-state-004-containerized-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`

Status / stop:

```bash
./scripts/status-state-004-containerized-generated.sh
./scripts/stop-state-004-containerized-generated.sh
```
EOF
      ;;
    010-kubernetes-runtime)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
# optional:
# ./scripts/start-state-010-kubernetes-runtime-generated.sh --provider minikube --minikube-profile traderx-state-010
```

Endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Edge health: `http://localhost:8080/health`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh
./scripts/stop-state-010-kubernetes-runtime-generated.sh
```
EOF
      ;;
    013-radius-kubernetes-platform)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start baseline runtime (inherited from state 010):

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

State 013 artifact pack:
- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`
- `radius-kubernetes-platform/radius/.rad/rad.yaml`

Optional Radius flow:

```bash
cd radius-kubernetes-platform/radius
rad run app.bicep
```
EOF
      ;;
    011-tilt-kubernetes-dev-loop)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start baseline runtime (inherited from state 010):

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

State 011 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Optional Tilt flow:

```bash
cd tilt-kubernetes-dev-loop/tilt
tilt up
```
EOF
      ;;
    012-platform-convergence-c3)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start convergence runtime:

```bash
./scripts/start-state-012-platform-convergence-c3-generated.sh
./scripts/start-state-012-platform-convergence-c3-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

State 012 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Status / stop:

```bash
./scripts/status-state-012-platform-convergence-c3-generated.sh
./scripts/stop-state-012-platform-convergence-c3-generated.sh
```
EOF
      ;;
    014-fdc3-intent-interoperability)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Docker Compose plugin (required for optional Sail sidecar mode)

Start TraderX runtime (state 014 wrapper):

```bash
./start-env.sh --provider kind
```

Start TraderX + Sail sidecar demo mode:

```bash
./start-env.sh --provider kind --with-sail
```

Endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Sail UI (when `--with-sail`): `http://localhost:8090`

Status / stop:

```bash
./status-env.sh --provider kind
./stop-env.sh --provider kind
```

Functional smoke test:

```bash
./test-env.sh
```
EOF
      ;;
    007-observability-lgtm-compose)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-007-observability-lgtm-compose-generated.sh
./scripts/start-state-007-observability-lgtm-compose-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- Grafana: `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`

Status / stop:

```bash
./scripts/status-state-007-observability-lgtm-compose-generated.sh
./scripts/stop-state-007-observability-lgtm-compose-generated.sh
```
EOF
      ;;
    006-messaging-nats-replacement)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-006-messaging-nats-replacement-generated.sh
./scripts/start-state-006-messaging-nats-replacement-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```
EOF
      ;;
    005-postgres-database-replacement)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-005-postgres-database-replacement-generated.sh
./scripts/start-state-005-postgres-database-replacement-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- PostgreSQL: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-005-postgres-database-replacement-generated.sh
./scripts/stop-state-005-postgres-database-replacement-generated.sh
```
EOF
      ;;
    009-order-management-matcher)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-009-order-management-matcher-generated.sh
./scripts/start-state-009-order-management-matcher-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- Order matcher health: `http://localhost:18110/health`
- Grafana: `http://localhost:3001`
- Prometheus: `http://localhost:9090`

Smoke test:

```bash
./scripts/test-state-009-order-management-matcher.sh
./scripts/test-state-009-order-management-matcher.sh --skip-messaging
./scripts/test-messaging-009-order-management-matcher.sh
```

Status / stop:

```bash
./scripts/status-state-009-order-management-matcher-generated.sh
./scripts/stop-state-009-order-management-matcher-generated.sh
```
EOF
      ;;
    008-pricing-awareness-market-data)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
./scripts/start-state-008-pricing-awareness-market-data-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/prices`

Smoke test:

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```

Status / stop:

```bash
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
```
EOF
      ;;
    *)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

No state-specific clone runtime instructions were generated for this snapshot.
EOF
      ;;
  esac

  cat >> "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'

## Stable Entrypoints

Use root wrappers for this generated branch:

```bash
./start-env.sh   # start this state runtime
./status-env.sh  # runtime health/status
./stop-env.sh    # stop runtime
./test-env.sh    # state smoke/validation
```
EOF

  if windows_supported_for_state; then
    cat >> "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'

```bat
start-env.bat
status-env.bat
stop-env.bat
test-env.bat
```
EOF
  fi

  cat >> "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'

Wrappers intentionally delegate to numbered state scripts to maximize reuse while keeping clone-first commands stable.
EOF
}

write_snapshot_learning_docs() {
  local feature_pack_dir="${ROOT}/${FEATURE_PACK}"
  local system_dir="${feature_pack_dir}/system"
  local model_path="${system_dir}/architecture.model.json"
  local architecture_md_path="${system_dir}/architecture.md"
  local runtime_topology_path="${system_dir}/runtime-topology.md"
  local flows_path="${system_dir}/end-to-end-flows.md"
  local system_design_source=""
  local docs_root="${SNAPSHOT_DIR}/docs"
  local learning_root="${docs_root}/learning"
  local doc_source_links=""

  if [[ ! -f "${model_path}" ]]; then
    echo "[fail] missing architecture model for snapshot docs: ${model_path}"
    exit 1
  fi

  if [[ -f "${runtime_topology_path}" ]]; then
    system_design_source="${runtime_topology_path}"
  elif [[ -f "${flows_path}" ]]; then
    system_design_source="${flows_path}"
  fi

  mkdir -p "${learning_root}"

  cat > "${docs_root}/README.md" <<EOF
# Generated Docs

This folder provides generated learning-oriented documentation for state \`${STATE_ID}\`.

- [Learning Index](./learning/README.md)
- [Component List](./learning/component-list.md)
- [System Design](./learning/system-design.md)
- [Software Architecture](./learning/software-architecture.md)
- [Component Diagram](./learning/component-diagram.md)
EOF

  cat > "${learning_root}/component-list.md" <<EOF
# Component List

State: \`${STATE_ID}\`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
$(jq -r '.nodes[] | "| `\(.id)` | \(.label) | \(.kind // "component") | \((.description // "n/a") | gsub("\\|"; "\\\\|")) |"' "${model_path}")
EOF

  cat > "${learning_root}/component-diagram.md" <<EOF
# Component Diagram

State: \`${STATE_ID}\`

\`\`\`mermaid
flowchart $(jq -r '.mermaidDirection // "LR"' "${model_path}")
$(jq -r '
  def sid: gsub("[^A-Za-z0-9_]"; "_");
  .nodes[] | "  \(.id | sid)[\"" + (.label | gsub("\""; "\\\"")) + "\"]"
' "${model_path}")

$(jq -r '
  def sid: gsub("[^A-Za-z0-9_]"; "_");
  .edges[] |
  if ((.label // "") | length) > 0 then
    "  \(.from | sid) -->|"+(.label | gsub("\""; "\\\""))+"| \(.to | sid)"
  else
    "  \(.from | sid) --> \(.to | sid)"
  end
' "${model_path}")
\`\`\`
EOF

  cat > "${learning_root}/software-architecture.md" <<EOF
# Software Architecture

State: \`${STATE_ID}\`
Title: \`$(jq -r '.title' "${model_path}")\`

## Architecture Summary

$(jq -r '.description' "${model_path}")

## Entrypoints

$(jq -r '(.entrypoints // [])[] | "- `\(.name)` -> `\(.url)`"' "${model_path}")

## Notes

$(jq -r '(.notes // [])[] | "- " + .' "${model_path}")

## Diagram

See [Component Diagram](./component-diagram.md).
EOF

  if [[ -f "${architecture_md_path}" ]]; then
    cat >> "${learning_root}/software-architecture.md" <<EOF

## Detailed Architecture (Spec Extract)

EOF
    cat "${architecture_md_path}" >> "${learning_root}/software-architecture.md"
  fi

  cat > "${learning_root}/system-design.md" <<EOF
# System Design

State: \`${STATE_ID}\`

## Design Intent

$(jq -r '.description' "${model_path}")
EOF

  if [[ -n "${system_design_source}" ]]; then
    cat >> "${learning_root}/system-design.md" <<EOF

## Runtime Topology / Flow (Spec Extract)

EOF
    cat "${system_design_source}" >> "${learning_root}/system-design.md"
  fi

  if [[ -n "${REPO_WEB_BASE}" ]]; then
    doc_source_links="- Source feature pack at commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- Source architecture model at commit: ${REPO_WEB_BASE}/blob/${SOURCE_COMMIT}/${FEATURE_PACK}/system/architecture.model.json"
  fi

  cat > "${learning_root}/README.md" <<EOF
# Learning Docs

These docs are generated for the published code snapshot for state \`${STATE_ID}\`.

- [Component List](./component-list.md)
- [System Design](./system-design.md)
- [Software Architecture](./software-architecture.md)
- [Component Diagram](./component-diagram.md)

## Source-of-Truth

Canonical source remains SpecKit artifacts in the main authoring branch:

- Feature pack: \`${FEATURE_PACK}\`
${doc_source_links}
EOF
}

write_snapshot_agentic_docs() {
  local state_num="${STATE_ID%%-*}"
  if [[ ! "${state_num}" =~ ^[0-9]+$ ]] || (( 10#${state_num} < 3 )); then
    return
  fi

  cat > "${SNAPSHOT_DIR}/AGENTS.md" <<EOF
# AGENTS.md

This generated codebase is a reproducible runtime snapshot for state \`${STATE_ID}\`.

- Treat this snapshot as generated output; expect regeneration to replace it.
- Use this branch for local experimentation and runtime validation.
- Promote durable changes into upstream \`specs/\` state packs and generation assets.
- Use \`RUN_FROM_CLONE.md\` and \`scripts/\` as runtime entrypoints.
EOF

  cat > "${SNAPSHOT_DIR}/ARCHITECTURE.md" <<EOF
# ARCHITECTURE.md

This snapshot was generated from TraderX state \`${STATE_ID}\`.

- Architecture source-of-truth remains in the upstream feature pack and SpecKit docs.
- This branch contains runnable generated artifacts for the selected state.
- Re-generate instead of manually editing generated runtime/source artifacts.
EOF

  cat > "${SNAPSHOT_DIR}/CONTRIBUTING.md" <<EOF
# CONTRIBUTING.md

This branch is generated output.

- Enhancement contributions should be made in upstream \`specs/\` state packs and pipeline generation scripts.
- Generated snapshots are outputs and are routinely replaced during regeneration.
- Local edits here are for experimentation and debugging, then should be translated back into source specs/state packs.
EOF
}

write_learning_guide() {
  local docs_learning_path="docs/learning/state-${STATE_ID}.md"
  local docs_learning_route="/docs/learning/state-${STATE_ID}"
  local docs_state_docs_route="/docs/spec-kit/state-docs"

  cat > "${SNAPSHOT_DIR}/LEARNING.md" <<EOF
# Learning Guide For ${STATE_ID}

This snapshot is code-first output. Canonical intent remains in SpecKit artifacts.

## Learning Focus

$(learning_focus_markdown)

## Read In This Snapshot

- [README.md](./README.md)
- [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- [STATE.md](./STATE.md)
- [docs/README.md](./docs/README.md)
- [docs/learning/README.md](./docs/learning/README.md)

## Canonical Spec Sources

- Feature pack: \`${FEATURE_PACK}\`
- State docs map route: \`${docs_state_docs_route}\`
- Learning guide route: \`${docs_learning_route}\`
- Learning guide markdown path in source branch: \`${docs_learning_path}\`
EOF

  if [[ -n "${REPO_WEB_BASE}" ]]; then
    cat >> "${SNAPSHOT_DIR}/LEARNING.md" <<EOF
- Source branch feature pack (exact commit): ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- Source branch learning guide (exact commit): ${REPO_WEB_BASE}/blob/${SOURCE_COMMIT}/${docs_learning_path}
EOF
  fi
}

write_functional_testing_guide() {
  local smoke_script=""
  local messaging_smoke_script=""
  smoke_script="scripts/test-state-${STATE_ID}.sh"
  messaging_smoke_script="scripts/test-messaging-${STATE_ID}.sh"
  if [[ ! -f "${SNAPSHOT_DIR}/${messaging_smoke_script}" ]]; then
    messaging_smoke_script="$(
      find "${SNAPSHOT_DIR}/scripts" -maxdepth 1 -type f -name "test-messaging-${state_num}-*.sh" -print \
        | sed "s#^${SNAPSHOT_DIR}/##" | sort | head -n 1 || true
    )"
  fi

  cat > "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF
# Functional Testing Guide

State: \`${STATE_ID}\`

This guide captures intended functional behavior for this generated snapshot branch.

## What Should Work

$(state_summary_markdown)

## Suggested Functional Validation

1. Start runtime using [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md).
2. Execute the state's smoke test script when available.
3. Confirm user-facing behavior and invariants described in [LEARNING.md](./LEARNING.md).
4. If behavior differs from expectations, compare with parent state using lineage links in [README.md](./README.md).

## Smoke Test Commands

EOF

  if [[ -f "${SNAPSHOT_DIR}/${smoke_script}" ]]; then
    cat >> "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF
\`\`\`bash
./${smoke_script}
\`\`\`
EOF
    if [[ -n "${messaging_smoke_script}" && -f "${SNAPSHOT_DIR}/${messaging_smoke_script}" ]]; then
      cat >> "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF
\`\`\`bash
./${smoke_script} --skip-messaging
./${messaging_smoke_script}
\`\`\`
EOF
    fi
  else
    cat >> "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF
\`\`\`bash
ls ./scripts/test-state-*.sh
\`\`\`

Use the script matching this state id when available.
EOF
  fi

  cat >> "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF

## Canonical References

- Spec pack: \`${FEATURE_PACK}\`
- Runtime guide: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- Snapshot learning guide: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md)
EOF

  if [[ -n "${REPO_WEB_BASE}" ]]; then
    cat >> "${SNAPSHOT_DIR}/FUNCTIONAL_TESTING.md" <<EOF
- Canonical Getting Started (main): ${REPO_WEB_BASE}/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Canonical SpecKit docs (source commit): ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/docs/spec-kit
EOF
  fi
}

write_snapshot_gitignore() {
  cat > "${SNAPSHOT_DIR}/.gitignore" <<'EOF'
# Runtime + package-manager artifacts
**/node_modules/
**/.angular/
**/.gradle/
**/.npm/
**/.pnpm-store/
**/.cache/
**/.run/

# Build outputs
**/build/
**/dist/
**/out/
**/coverage/
**/bin/
**/obj/

# Logs and local temp files
**/*.log
**/.DS_Store

# Environment + editor local state
**/.env
**/.env.*
**/.idea/
**/.vscode/
EOF
}

mkdir -p "${SNAPSHOT_DIR}/.traderx-state"
cat > "${SNAPSHOT_DIR}/.traderx-state/state.json" <<EOF
{
  "stateId": "${STATE_ID}",
  "stateTitle": "${STATE_TITLE}",
  "stateStatus": "${STATE_STATUS}",
  "featurePack": "${FEATURE_PACK}",
  "previousStates": ${PREVIOUS_STATES_JSON},
  "nextStates": ${NEXT_STATES_JSON},
  "isConvergenceState": ${IS_CONVERGENCE},
  "convergenceLevel": "${CONVERGENCE_LEVEL}",
  "lineageRole": "${CONVERGENCE_ROLE}",
  "dottedParents": ${DOTTED_PARENTS_JSON},
  "previousConvergenceState": "${PREVIOUS_CONVERGENCE_STATE}",
  "nextConvergenceState": "${NEXT_CONVERGENCE_STATE}",
  "sourceBranch": "${SOURCE_BRANCH}",
  "sourceCommit": "${SOURCE_COMMIT}",
  "generatedAtUtc": "${GENERATED_AT_UTC}",
  "generationEntryPoint": "${GENERATION_ENTRYPOINT}",
  "publishTagHint": "${TAG_HINT}"
}
EOF

cat > "${SNAPSHOT_DIR}/STATE.md" <<EOF
# TraderX Generated State Snapshot

- State ID: \`${STATE_ID}\`
- Title: \`${STATE_TITLE}\`
- Status: \`${STATE_STATUS}\`
- Feature Pack: \`${FEATURE_PACK}\`
- Previous States: \`${PREVIOUS_STATES_JSON}\`
- Next States: \`${NEXT_STATES_JSON}\`
- Convergence State: \`${IS_CONVERGENCE}\`
- Convergence Level: \`${CONVERGENCE_LEVEL}\`
- Lineage Role: \`${CONVERGENCE_ROLE}\`
- Dotted Parents: \`${DOTTED_PARENTS_TEXT}\`
- Previous Convergence State: \`${PREVIOUS_CONVERGENCE_STATE:-none}\`
- Next Convergence State: \`${NEXT_CONVERGENCE_STATE:-none}\`
- Source Branch: \`${SOURCE_BRANCH}\`
- Source Commit: \`${SOURCE_COMMIT}\`
- Generated At (UTC): \`${GENERATED_AT_UTC}\`
- Suggested Tag: \`${TAG_HINT}\`

Machine-readable metadata: \`.traderx-state/state.json\`
EOF

cat > "${SNAPSHOT_DIR}/README.md" <<EOF
# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

$(snapshot_platform_badges_markdown)

- State ID: \`${STATE_ID}\`
- State Title: \`${STATE_TITLE}\`
- Status: \`${STATE_STATUS}\`
- Suggested Version Tag: \`${TAG_HINT}\`
- Source Branch: \`${SOURCE_BRANCH}\`
- Source Commit: \`${SOURCE_COMMIT}\`
- Generated At (UTC): \`${GENERATED_AT_UTC}\`

## State Summary

$(state_summary_markdown)

## State Lineage

$(render_state_lineage_mermaid)

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
$(render_state_lineage_table_rows)

State sets:
- Previous states: \`${PREVIOUS_STATES_TEXT}\`
- Next states: \`${NEXT_STATES_TEXT}\`

## Convergence Status

- Convergence state: \`${IS_CONVERGENCE}\`
- Convergence level: \`${CONVERGENCE_LEVEL}\`
- Lineage role: \`${CONVERGENCE_ROLE}\`
- Dotted-line parents: \`${DOTTED_PARENTS_TEXT}\`
- Previous convergence milestone: $(render_convergence_reference_markdown "previous" "${PREVIOUS_CONVERGENCE_STATE}")
- Next convergence milestone: $(render_convergence_reference_markdown "next" "${NEXT_CONVERGENCE_STATE}")

### Convergence Neighborhood

$(render_convergence_mermaid)

## Runtime Guidance

$(runtime_guidance_markdown)

## API Explorer

$(api_explorer_markdown)

## Interactive URLs

$(interactive_urls_markdown)

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: \`${FEATURE_PACK}\`
- Generation entrypoint: \`${GENERATION_ENTRYPOINT}\`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
EOF

if [[ -n "${REPO_WEB_BASE}" ]]; then
  cat >> "${SNAPSHOT_DIR}/README.md" <<EOF
- Canonical Getting Started (main): ${REPO_WEB_BASE}/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: ${REPO_WEB_BASE}/commit/${SOURCE_COMMIT}
- Feature pack at source commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- SpecKit docs at source commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/docs/spec-kit
EOF
fi

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity|002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
    install_uncontainerized_clone_harness
    ;;
  004-containerized-compose-runtime)
    install_containerized_clone_harness
    ;;
  005-postgres-database-replacement|006-messaging-nats-replacement|007-observability-lgtm-compose|008-pricing-awareness-market-data|009-order-management-matcher)
    install_state_compose_clone_harness "${STATE_ID}"
    ;;
  010-kubernetes-runtime)
    install_kubernetes_clone_harness
    ;;
  011-tilt-kubernetes-dev-loop|012-platform-convergence-c3|013-radius-kubernetes-platform)
    install_kubernetes_clone_harness
    install_state_compose_clone_harness "${STATE_ID}"
    ;;
  014-fdc3-intent-interoperability)
    install_kubernetes_clone_harness
    install_state_compose_clone_harness "${STATE_ID}"
    ;;
esac

write_env_entrypoint_wrappers
write_clone_runbook
assert_snapshot_clone_entrypoints
bash "${ROOT}/pipeline/validate-ghcr-run-bundle-readmes.sh" "${SNAPSHOT_DIR}"
write_snapshot_learning_docs
write_snapshot_agentic_docs
write_learning_guide
write_functional_testing_guide
write_snapshot_gitignore

if [[ "${SKIP_LINEAGE_VALIDATION}" == "1" ]]; then
  echo "[warn] skipping lineage invariant validation (--skip-lineage-validation)"
else
  bash "${ROOT}/pipeline/validate-generated-state-lineage-invariants.sh" --state-id "${STATE_ID}" --snapshot-dir "${SNAPSHOT_DIR}"
fi

BRANCH_EXISTS=0
if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  BRANCH_EXISTS=1
  git -C "${ROOT}" worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}" >/dev/null
else
  git -C "${ROOT}" worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${BASE_BRANCH}" >/dev/null
fi

PREVIOUS_BRANCH_TIP=""
if (( BRANCH_EXISTS == 1 )); then
  PREVIOUS_BRANCH_TIP="$(git -C "${WORKTREE_DIR}" rev-parse HEAD)"
  git -C "${WORKTREE_DIR}" reset --hard "${BASE_BRANCH}" >/dev/null
fi

git -C "${WORKTREE_DIR}" rm -rf . >/dev/null 2>&1 || true
git -C "${WORKTREE_DIR}" clean -fdx >/dev/null 2>&1 || true
cp -R "${SNAPSHOT_DIR}/." "${WORKTREE_DIR}/"
git -C "${WORKTREE_DIR}" add -A

if git -C "${WORKTREE_DIR}" diff --cached --quiet; then
  if (( BRANCH_EXISTS == 1 )); then
    git -C "${WORKTREE_DIR}" reset --hard "${PREVIOUS_BRANCH_TIP}" >/dev/null
    echo "[info] no snapshot changes for ${BRANCH_NAME}; preserved prior tip"
  else
    echo "[info] no snapshot changes to commit on ${BRANCH_NAME}"
  fi
else
  git -C "${WORKTREE_DIR}" commit \
    -m "snapshot: ${STATE_ID} generated from ${SOURCE_COMMIT}" \
    -m "lineage-base: ${BASE_BRANCH}" >/dev/null
  echo "[ok] committed generated snapshot on branch ${BRANCH_NAME}"
fi

if (( PUSH == 1 )); then
  if [[ "${BASE_BRANCH}" == "${GENERATED_ROOT_BRANCH}" ]]; then
    git -C "${ROOT}" push --force-with-lease origin "${GENERATED_ROOT_BRANCH}"
  fi
  git -C "${WORKTREE_DIR}" push --force-with-lease origin "${BRANCH_NAME}"
  echo "[ok] pushed ${BRANCH_NAME}"
fi

echo "[done] generated-state branch ready: ${BRANCH_NAME}"

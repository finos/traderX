#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage: bash pipeline/validate-generated-state-lineage-invariants.sh [--state-id <id> --snapshot-dir <dir>] [--state-id <id> --branch <branch>] [--policy-only]

Checks:
  1) implemented states must define explicit snapshot root allowlist policy
  2) generated snapshot roots must not include state-external component directories
  3) decommissioned components must not reappear in downstream states
EOF
}

STATE_ID=""
SNAPSHOT_DIR=""
BRANCH_NAME=""
POLICY_ONLY=0

while (( "$#" )); do
  case "$1" in
    --state-id)
      STATE_ID="${2:-}"
      shift 2
      ;;
    --snapshot-dir)
      SNAPSHOT_DIR="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH_NAME="${2:-}"
      shift 2
      ;;
    --policy-only)
      POLICY_ONLY=1
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

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required"
  exit 1
fi

if [[ -n "${SNAPSHOT_DIR}" && -n "${BRANCH_NAME}" ]]; then
  echo "[fail] choose one of --snapshot-dir or --branch"
  exit 1
fi

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

allowed_roots_for_state() {
  local state_id="$1"
  case "${state_id}" in
    001-baseline-uncontainerized-parity)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}"
      ;;
    002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "edge-proxy"
      ;;
    004-containerized-compose-runtime)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress"
      ;;
    005-postgres-database-replacement)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress" "postgres-database-replacement"
      ;;
    006-messaging-nats-replacement)
      printf '%s\n' "${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "postgres-database-replacement"
      ;;
    007-observability-lgtm-compose)
      printf '%s\n' "${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "observability-lgtm-compose" "postgres-database-replacement"
      ;;
    008-pricing-awareness-market-data)
      printf '%s\n' "${PRICING_COMPONENT_DIRS[@]}" "ingress" "pricing-awareness-market-data" "postgres-database-replacement"
      ;;
    009-order-management-matcher)
      printf '%s\n' "${ORDER_COMPONENT_DIRS[@]}" "ingress" "order-management-matcher" "postgres-database-replacement"
      ;;
    010-kubernetes-runtime)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime"
      ;;
    011-tilt-kubernetes-dev-loop|012-platform-convergence-c3)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop"
      ;;
    013-radius-kubernetes-platform)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "radius-kubernetes-platform"
      ;;
    014-fdc3-intent-interoperability)
      printf '%s\n' "${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop" "fdc3-intent-interoperability"
      ;;
    *)
      return 1
      ;;
  esac
}

is_ignored_entry() {
  local entry="$1"
  case "${entry}" in
    .github|.traderx-state|catalog|ci|docs|generated|runtime|scripts)
      return 0
      ;;
    AGENTS.md|ARCHITECTURE.md|CONTRIBUTING.md|FUNCTIONAL_TESTING.md|LEARNING.md|README.md|RUN_FROM_CLONE.md|RUN_FROM_GENERATED.md|STATE.md|.gitignore)
      return 0
      ;;
    start-env.sh|stop-env.sh|status-env.sh|test-env.sh|start-env.bat|stop-env.bat|status-env.bat|test-env.bat)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

path_in_list() {
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

validate_policy_matrix() {
  local missing=()
  local state_id mode
  while IFS=$'\t' read -r state_id mode; do
    [[ "${mode}" == "implemented" || "${mode}" == "released" ]] || continue
    if ! allowed_roots_for_state "${state_id}" >/dev/null; then
      missing+=("${state_id}")
    fi
  done < <(jq -r '.states[] | [.id, (.generation.mode // .status // "")] | @tsv' "${CATALOG}")

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "[fail] missing allowlist policy for state(s):"
    printf '  - %s\n' "${missing[@]}"
    echo "[hint] add states to allowed_roots_for_state() in ${BASH_SOURCE[0]}"
    exit 1
  fi
}

collect_entries_from_snapshot_dir() {
  local dir="$1"
  [[ -d "${dir}" ]] || {
    echo "[fail] snapshot dir not found: ${dir}"
    exit 1
  }
  find "${dir}" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort -u
}

resolve_branch_ref() {
  local branch="$1"
  if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
    printf '%s\n' "${branch}"
    return 0
  fi
  if git -C "${ROOT}" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    printf '%s\n' "origin/${branch}"
    return 0
  fi
  return 1
}

collect_entries_from_branch() {
  local branch="$1"
  local resolved
  if ! resolved="$(resolve_branch_ref "${branch}")"; then
    echo "[fail] branch not found locally or on origin: ${branch}"
    exit 1
  fi
  git -C "${ROOT}" ls-tree --name-only "${resolved}" | sed '/^$/d' | sort -u
}

validate_state_entries() {
  local state_id="$1"
  shift || true
  local entries=("$@")
  local allowed=()
  local line

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    allowed+=("${line}")
  done < <(allowed_roots_for_state "${state_id}" | sed '/^$/d' | sort -u)

  if [[ "${#allowed[@]}" -eq 0 ]]; then
    echo "[fail] no allowlist entries resolved for state ${state_id}"
    exit 1
  fi

  local extras=()
  local entry
  for entry in "${entries[@]}"; do
    is_ignored_entry "${entry}" && continue
    if ! path_in_list "${entry}" "${allowed[@]}"; then
      extras+=("${entry}")
    fi
  done

  if [[ "${#extras[@]}" -gt 0 ]]; then
    echo "[fail] state ${state_id} includes out-of-policy snapshot roots:"
    printf '  - %s\n' "${extras[@]}"
    echo "[hint] expected component roots:"
    printf '  - %s\n' "${allowed[@]}"
    exit 1
  fi

  local required_clone_entries=(
    "scripts"
    "RUN_FROM_CLONE.md"
    "start-env.sh"
    "stop-env.sh"
    "status-env.sh"
    "test-env.sh"
  )
  local missing_clone_entries=()
  local required_entry
  for required_entry in "${required_clone_entries[@]}"; do
    if ! path_in_list "${required_entry}" "${entries[@]}"; then
      missing_clone_entries+=("${required_entry}")
    fi
  done
  if [[ "${#missing_clone_entries[@]}" -gt 0 ]]; then
    echo "[fail] state ${state_id} missing required clone/runtime entrypoints:"
    printf '  - %s\n' "${missing_clone_entries[@]}"
    exit 1
  fi

  local state_num="${state_id%%-*}"
  if [[ "${state_num}" =~ ^[0-9]+$ ]] && (( 10#${state_num} >= 6 )); then
    if path_in_list "trade-feed" "${entries[@]}"; then
      echo "[fail] decommission invariant violation: trade-feed must not reappear after state 006"
      exit 1
    fi
  fi
}

validate_catalog_branches() {
  local state_id branch mode
  while IFS=$'\t' read -r state_id branch mode; do
    [[ -n "${branch}" ]] || continue
    [[ "${mode}" == "implemented" || "${mode}" == "released" ]] || continue
    if ! resolve_branch_ref "${branch}" >/dev/null; then
      echo "[warn] skipping branch invariant check (branch not present locally): ${branch}"
      continue
    fi
    local entries=()
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      entries+=("${line}")
    done < <(collect_entries_from_branch "${branch}")
    validate_state_entries "${state_id}" "${entries[@]}"
  done < <(jq -r '.states[] | [.id, (.publish.branch // ""), (.generation.mode // .status // "")] | @tsv' "${CATALOG}")
}

validate_policy_matrix

if (( POLICY_ONLY == 1 )); then
  echo "[ok] lineage policy matrix validated"
  exit 0
fi

if [[ -n "${SNAPSHOT_DIR}" ]]; then
  [[ -n "${STATE_ID}" ]] || {
    echo "[fail] --state-id is required with --snapshot-dir"
    exit 1
  }
  entries=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    entries+=("${line}")
  done < <(collect_entries_from_snapshot_dir "${SNAPSHOT_DIR}")
  validate_state_entries "${STATE_ID}" "${entries[@]}"
  echo "[ok] lineage invariants validated for snapshot dir ${SNAPSHOT_DIR} (${STATE_ID})"
  exit 0
fi

if [[ -n "${BRANCH_NAME}" ]]; then
  if [[ -z "${STATE_ID}" ]]; then
    STATE_ID="$(jq -r --arg b "${BRANCH_NAME}" '.states[] | select((.publish.branch // "") == $b) | .id' "${CATALOG}")"
  fi
  [[ -n "${STATE_ID}" ]] || {
    echo "[fail] unable to resolve state-id for branch ${BRANCH_NAME}"
    exit 1
  }
  entries=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    entries+=("${line}")
  done < <(collect_entries_from_branch "${BRANCH_NAME}")
  validate_state_entries "${STATE_ID}" "${entries[@]}"
  echo "[ok] lineage invariants validated for branch ${BRANCH_NAME} (${STATE_ID})"
  exit 0
fi

validate_catalog_branches
echo "[ok] lineage invariants validated for available generated-state branches"

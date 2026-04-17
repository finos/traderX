#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage:
  bash pipeline/state-playbook.sh --state <state-id> [--publish-neighborhood] [--push-generated] [--push-spec-branch]
  bash pipeline/state-playbook.sh --all-implemented [--publish-tree] [--push-generated] [--push-spec-branch]

This playbook executes the canonical state-change flow:
  1) Refresh all state-derived docs (learning paths, visual graph, state lists)
  2) Run quality gates
  3) Generate requested state codebase(s)
  4) Optionally publish generated-code branches
  5) Optionally push current spec/source branch

Options:
  --state <state-id>         Target one state
  --all-implemented          Target all implemented states from catalog
  --publish-neighborhood     Publish target state + immediate previous/next states
  --publish-tree             Publish all implemented states in topological order
  --push-generated           Push generated branches when publishing
  --push-spec-branch         Push current checked-out branch after successful gates/generation
  --skip-gates               Skip quality gates (not recommended)
EOF
}

STATE_ID=""
ALL_IMPLEMENTED=0
PUBLISH_NEIGHBORHOOD=0
PUBLISH_TREE=0
PUSH_GENERATED=0
PUSH_SPEC_BRANCH=0
SKIP_GATES=0

while (($# > 0)); do
  case "$1" in
    --state)
      STATE_ID="${2:-}"
      shift 2
      ;;
    --all-implemented)
      ALL_IMPLEMENTED=1
      shift
      ;;
    --publish-neighborhood)
      PUBLISH_NEIGHBORHOOD=1
      shift
      ;;
    --publish-tree)
      PUBLISH_TREE=1
      shift
      ;;
    --push-generated)
      PUSH_GENERATED=1
      shift
      ;;
    --push-spec-branch)
      PUSH_SPEC_BRANCH=1
      shift
      ;;
    --skip-gates)
      SKIP_GATES=1
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

if [[ -n "${STATE_ID}" && "${ALL_IMPLEMENTED}" -eq 1 ]]; then
  echo "[fail] use either --state or --all-implemented, not both"
  exit 1
fi

if [[ -z "${STATE_ID}" && "${ALL_IMPLEMENTED}" -eq 0 ]]; then
  echo "[fail] either --state or --all-implemented is required"
  exit 1
fi

if [[ -n "${STATE_ID}" ]]; then
  if ! jq -e --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
    echo "[fail] unknown state: ${STATE_ID}"
    exit 1
  fi
fi

if [[ "${PUBLISH_NEIGHBORHOOD}" -eq 1 && -z "${STATE_ID}" ]]; then
  echo "[fail] --publish-neighborhood requires --state"
  exit 1
fi

echo "[step] refresh generated state docs and learning catalogs"
bash "${ROOT}/pipeline/refresh-state-docs.sh"

if [[ "${SKIP_GATES}" -eq 0 ]]; then
  echo "[step] run quality gates"
  bash "${ROOT}/tools/validate-frontmatter.sh"
  bash "${ROOT}/pipeline/speckit/validate-root-spec-kit-gates.sh"
  bash "${ROOT}/pipeline/speckit/validate-speckit-readiness.sh"
  bash "${ROOT}/pipeline/verify-spec-coverage.sh"
fi

declare -a target_states=()
if [[ -n "${STATE_ID}" ]]; then
  target_states+=("${STATE_ID}")
else
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    target_states+=("${id}")
  done < <(jq -r '.states[] | select(.generation.mode == "implemented") | .id' "${CATALOG}" | sort)
fi

if [[ "${#target_states[@]}" -eq 0 ]]; then
  echo "[fail] no target states resolved"
  exit 1
fi

if printf '%s\n' "${target_states[@]}" | grep -Fxq '014-fdc3-intent-interoperability'; then
  echo "[step] Sail pin drift check (informational)"
  bash "${ROOT}/pipeline/check-sail-pin-drift.sh" || true
fi

echo "[step] generate target states"
for id in "${target_states[@]}"; do
  echo "[state] generating ${id}"
  bash "${ROOT}/pipeline/generate-state.sh" "${id}"
done

if [[ "${PUBLISH_NEIGHBORHOOD}" -eq 1 ]]; then
  echo "[step] publish neighborhood for ${STATE_ID}"
  if [[ "${PUSH_GENERATED}" -eq 1 ]]; then
    bash "${ROOT}/pipeline/publish-generated-state-neighborhood.sh" "${STATE_ID}" --push
  else
    bash "${ROOT}/pipeline/publish-generated-state-neighborhood.sh" "${STATE_ID}"
  fi
elif [[ "${PUBLISH_TREE}" -eq 1 ]]; then
  echo "[step] publish generated-state tree"
  if [[ "${PUSH_GENERATED}" -eq 1 ]]; then
    bash "${ROOT}/pipeline/publish-generated-state-tree.sh" --push
  else
    bash "${ROOT}/pipeline/publish-generated-state-tree.sh"
  fi
fi

if [[ "${PUSH_SPEC_BRANCH}" -eq 1 ]]; then
  branch_name="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD)"
  echo "[step] push spec/source branch ${branch_name}"
  git -C "${ROOT}" push origin "${branch_name}"
fi

echo "[ok] state playbook complete"

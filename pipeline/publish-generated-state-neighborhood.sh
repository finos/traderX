#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage: bash pipeline/publish-generated-state-neighborhood.sh <state-id> [--push] [--skip-compile-preflight]

Publishes a state and its immediate lineage neighbors so generated README lineage
sections stay current:
- target state
- all immediate previous states
- all immediate next states

Examples:
  bash pipeline/publish-generated-state-neighborhood.sh 008-pricing-awareness-market-data
  bash pipeline/publish-generated-state-neighborhood.sh 008-pricing-awareness-market-data --push
EOF
}

STATE_ID=""
PUSH=0
SKIP_COMPILE_PREFLIGHT=0
while (( "$#" )); do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --skip-compile-preflight)
      SKIP_COMPILE_PREFLIGHT=1
      shift
      ;;
    -*)
      echo "[fail] unknown arg: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -n "${STATE_ID}" ]]; then
        echo "[fail] unexpected extra argument: $1"
        usage
        exit 1
      fi
      STATE_ID="$1"
      shift
      ;;
  esac
done

if [[ -z "${STATE_ID}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing catalog: ${CATALOG}"
  exit 1
fi

if ! jq -e --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
  echo "[fail] state not found in catalog: ${STATE_ID}"
  exit 1
fi

if [[ -n "$(git -C "${ROOT}" status --porcelain)" ]]; then
  echo "[fail] working tree must be clean before publishing generated-state neighborhood"
  exit 1
fi

declare -a targets=()
targets+=("${STATE_ID}")

while IFS= read -r prev; do
  [[ -n "${prev}" ]] || continue
  targets+=("${prev}")
done < <(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // [])[]?' "${CATALOG}")

while IFS= read -r nxt; do
  [[ -n "${nxt}" ]] || continue
  targets+=("${nxt}")
done < <(jq -r --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ][]?' "${CATALOG}")

deduped=()
for id in "${targets[@]}"; do
  skip=0
  for seen in "${deduped[@]:-}"; do
    if [[ "${seen}" == "${id}" ]]; then
      skip=1
      break
    fi
  done
  if [[ "${skip}" -eq 0 ]]; then
    deduped+=("${id}")
  fi
done

echo "[info] publishing neighborhood for ${STATE_ID}: ${deduped[*]}"

for id in "${deduped[@]}"; do
  echo "[state] ${id}"
  branch_args=()
  if (( SKIP_COMPILE_PREFLIGHT == 1 )); then
    branch_args+=(--skip-compile-preflight)
  fi
  if (( PUSH == 1 )); then
    bash "${ROOT}/pipeline/publish-generated-state-branch.sh" "${id}" "${branch_args[@]}" --push
  else
    bash "${ROOT}/pipeline/publish-generated-state-branch.sh" "${id}" "${branch_args[@]}"
  fi
done

echo "[done] published neighborhood (${#deduped[@]} states)"

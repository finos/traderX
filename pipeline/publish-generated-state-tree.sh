#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage: bash pipeline/publish-generated-state-tree.sh [--push]

Publishes all implemented generated-state branches in topological order derived
from catalog/state-catalog.json state.previous relationships.

Examples:
  bash pipeline/publish-generated-state-tree.sh
  bash pipeline/publish-generated-state-tree.sh --push
EOF
}

PUSH=0
while (( "$#" )); do
  case "$1" in
    --push)
      PUSH=1
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
  echo "[fail] missing catalog: ${CATALOG}"
  exit 1
fi

if [[ -n "$(git -C "${ROOT}" status --porcelain)" ]]; then
  echo "[fail] working tree must be clean before publishing generated-state tree"
  exit 1
fi

remaining=()
while IFS= read -r state_id; do
  [[ -n "${state_id}" ]] || continue
  remaining+=("${state_id}")
done < <(jq -r '.states[] | select(.generation.mode == "implemented") | .id' "${CATALOG}")
if [[ "${#remaining[@]}" -eq 0 ]]; then
  echo "[fail] no implemented states found in catalog"
  exit 1
fi

published=()
publish_one() {
  local state_id="$1"
  echo "[state] publishing ${state_id}"
  if (( PUSH == 1 )); then
    bash "${ROOT}/pipeline/publish-generated-state-branch.sh" "${state_id}" --push
  else
    bash "${ROOT}/pipeline/publish-generated-state-branch.sh" "${state_id}"
  fi
  published+=("${state_id}")
}

has_published() {
  local needle="$1"
  local id
  for id in "${published[@]}"; do
    if [[ "${id}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

progress=1
while [[ "${#remaining[@]}" -gt 0 && "${progress}" -eq 1 ]]; do
  progress=0
  next_round=()

  for state_id in "${remaining[@]}"; do
    can_publish=1
    while IFS= read -r prev; do
      [[ -n "${prev}" ]] || continue
      if ! has_published "${prev}"; then
        can_publish=0
        break
      fi
    done < <(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.previous // [])[]?' "${CATALOG}")

    if [[ "${can_publish}" -eq 1 ]]; then
      publish_one "${state_id}"
      progress=1
    else
      next_round+=("${state_id}")
    fi
  done

  remaining=()
  if [[ "${#next_round[@]}" -gt 0 ]]; then
    remaining=("${next_round[@]}")
  fi
done

if [[ "${#remaining[@]}" -gt 0 ]]; then
  echo "[fail] could not resolve topological publish order for remaining states:"
  printf ' - %s\n' "${remaining[@]}"
  echo "[hint] check catalog previous relationships for cycles/missing parents"
  exit 1
fi

echo "[done] published generated-state tree (${#published[@]} states)"

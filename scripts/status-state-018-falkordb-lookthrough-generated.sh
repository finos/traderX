#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID=018-falkordb-lookthrough
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-018}"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/falkordb-lookthrough/docker-compose.yml"
DRY_RUN=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "unsupported argument: $arg" >&2; exit 2 ;;
  esac
done
[[ -f "${COMPOSE_FILE}" ]] || { echo "Generate the state first" >&2; exit 1; }
command=(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}")
command+=(ps)
if (( DRY_RUN )); then printf '%q ' "${command[@]}"; printf '
'; exit; fi
"${command[@]}"

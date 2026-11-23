#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID=017-portfolio-lookthrough
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-017}"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/portfolio-lookthrough/docker-compose.yml"
DRY_RUN=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "unsupported argument: $arg" >&2; exit 2 ;;
  esac
done
if [[ "${TRADERX_SKIP_GENERATE:-0}" != 1 ]]; then
  bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
fi
[[ -f "${COMPOSE_FILE}" ]] || { echo "Generate the state first" >&2; exit 1; }
command=(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}")
if (( SKIP_BUILD )); then command+=(up -d --no-build); else command+=(up -d --build); fi
if (( DRY_RUN )); then printf '%q ' "${command[@]}"; printf '
'; exit; fi
"${command[@]}"

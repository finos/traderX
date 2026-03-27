#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash TraderSpec/pipeline/speckit/run-all-conformance-packs.sh [--execute-runtime-checks]
EOF
}

EXECUTE_RUNTIME_CHECKS=0

while (($# > 0)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --execute-runtime-checks)
      EXECUTE_RUNTIME_CHECKS=1
      ;;
    *)
      echo "[fail] unexpected argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

bash "${ROOT}/pipeline/speckit/sync-conformance-packs.sh"

failed=0
passed=0

while IFS= read -r component_id; do
  [[ -n "${component_id}" ]] || continue
  echo "[run] conformance pack: ${component_id}"
  if (( EXECUTE_RUNTIME_CHECKS == 1 )); then
    if bash "${ROOT}/pipeline/speckit/run-component-conformance-pack.sh" "${component_id}" --execute-runtime-checks; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
  else
    if bash "${ROOT}/pipeline/speckit/run-component-conformance-pack.sh" "${component_id}"; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
  fi
done < <(speckit_list_generated_components)

if (( failed > 0 )); then
  echo "[fail] conformance packs failed (${passed} passed, ${failed} failed)"
  exit 1
fi

echo "[ok] all conformance packs passed (${passed} components)"

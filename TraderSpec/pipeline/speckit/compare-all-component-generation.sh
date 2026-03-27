#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh [legacy-ref] [--allow-differences]

Examples:
  bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD
  bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh origin/main --allow-differences
EOF
}

LEGACY_REF="HEAD"
ALLOW_DIFFERENCES=0

while (($# > 0)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --allow-differences)
      ALLOW_DIFFERENCES=1
      ;;
    *)
      if [[ "${LEGACY_REF}" == "HEAD" ]]; then
        LEGACY_REF="$1"
      else
        echo "[fail] unexpected argument: $1"
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

failed=0
diff_detected=0

while IFS= read -r component_id; do
  [[ -n "${component_id}" ]] || continue
  echo "================ ${component_id} ================"

  set +e
  if (( ALLOW_DIFFERENCES == 1 )); then
    bash "${ROOT}/pipeline/speckit/compare-component-generation.sh" "${component_id}" "${LEGACY_REF}" --allow-differences
  else
    bash "${ROOT}/pipeline/speckit/compare-component-generation.sh" "${component_id}" "${LEGACY_REF}"
  fi
  status=$?
  set -e

  if [[ "${status}" -eq 0 ]]; then
    continue
  fi
  if [[ "${status}" -eq 1 ]]; then
    diff_detected=1
    continue
  fi
  failed=1
done < <(speckit_list_generated_components)

if (( failed == 1 )); then
  echo "[fail] comparison harness encountered errors"
  exit 2
fi

if (( diff_detected == 1 && ALLOW_DIFFERENCES == 0 )); then
  echo "[fail] one or more components differ from ${LEGACY_REF}"
  exit 1
fi

echo "[ok] compare-all harness completed"

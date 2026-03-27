#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${ROOT}/codebase/target-generated-specfirst"
CSV="${ROOT}/catalog/component-spec.csv"

[[ -f "${CSV}" ]] || { echo "[error] missing ${CSV}"; exit 1; }
[[ -d "${TARGET}/apps" ]] || { echo "[error] missing ${TARGET}/apps; run generate-from-spec first"; exit 1; }

SEEN_TOPS=""
row=0
while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  subpath="${target_path#apps/}"
  top="${subpath%%/*}"
  [[ -n "${top}" ]] || continue

  if [[ " ${SEEN_TOPS} " == *" ${top} "* ]]; then
    continue
  fi
  SEEN_TOPS="${SEEN_TOPS} ${top}"

  dst="${TARGET}/${top}"
  src="apps/${top}"
  if [[ -L "${dst}" || -d "${dst}" ]]; then
    rm -rf "${dst}"
  fi
  ln -s "${src}" "${dst}"
  echo "[link] ${dst} -> ${src}"
done < "${CSV}"

echo "[ok] spec-first compose layout prepared in ${TARGET}"

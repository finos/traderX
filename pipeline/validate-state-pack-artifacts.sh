#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0
packs=0

for pack_dir in "${ROOT}"/specs/[0-9][0-9][0-9]-*; do
  [[ -d "${pack_dir}" ]] || continue
  packs=$((packs + 1))
  pack_id="$(basename "${pack_dir}")"

  required=(
    "README.md"
    "spec.md"
    "plan.md"
    "tasks.md"
    "research.md"
    "data-model.md"
    "quickstart.md"
    "system/architecture.md"
  )

  for relative_path in "${required[@]}"; do
    if [[ ! -f "${pack_dir}/${relative_path}" ]]; then
      echo "[missing] ${pack_id}/${relative_path}"
      errors=$((errors + 1))
    fi
  done
done

if ((packs == 0)); then
  echo "[fail] no state packs found under specs/"
  exit 1
fi

if ((errors > 0)); then
  echo "[fail] state pack artifact validation failed (${errors} missing files)"
  exit 1
fi

echo "[ok] state pack artifact validation passed (${packs} packs)"

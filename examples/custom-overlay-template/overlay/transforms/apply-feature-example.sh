#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash overlay/transforms/apply-feature-example.sh <target-dir>
#
# Contract:
# - Must be idempotent (safe to run multiple times).
# - Must run after prepare_generated_base_layout (or equivalent destructive copy).
# - Must exit non-zero on failure.

TARGET_DIR="${1:-}"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "[fail] usage: $0 <target-dir>"
  exit 1
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "[fail] target directory does not exist: ${TARGET_DIR}"
  exit 1
fi

# Example idempotent transform: ensure an overlay marker file exists.
MARKER_DIR="${TARGET_DIR}/.overlay"
MARKER_FILE="${MARKER_DIR}/feature-example.txt"
mkdir -p "${MARKER_DIR}"

cat > "${MARKER_FILE}" <<'MARKER'
This file is managed by overlay/transforms/apply-feature-example.sh.
It may be regenerated and should not be edited manually.
MARKER

# Example idempotent line insertion into a generated runbook.
RUNBOOK="${TARGET_DIR}/RUN_FROM_GENERATED.md"
if [[ -f "${RUNBOOK}" ]]; then
  LINE='- Overlay note: custom transform `apply-feature-example.sh` was applied.'
  if ! grep -Fq "${LINE}" "${RUNBOOK}"; then
    printf '\n%s\n' "${LINE}" >> "${RUNBOOK}"
  fi
fi

echo "[ok] apply-feature-example.sh applied to ${TARGET_DIR}"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN_FILE="${1:-${ROOT}/specs/014-fdc3-intent-interoperability/generation/sail-pin.env}"
RENDER_SCRIPT="${ROOT}/pipeline/render-state-014-fdc3-intent-interoperability.sh"

fail() {
  echo "[fail] $*"
  exit 1
}

[[ -f "${PIN_FILE}" ]] || fail "missing Sail pin manifest: ${PIN_FILE}"

# shellcheck disable=SC1090
source "${PIN_FILE}"

[[ -n "${SAIL_PIN_REPO_URL:-}" ]] || fail "SAIL_PIN_REPO_URL missing in ${PIN_FILE}"
[[ -n "${SAIL_PIN_TRACKING_REF:-}" ]] || fail "SAIL_PIN_TRACKING_REF missing in ${PIN_FILE}"
[[ -n "${SAIL_PINNED_REF:-}" ]] || fail "SAIL_PINNED_REF missing in ${PIN_FILE}"
[[ -n "${SAIL_PIN_UPDATED_ON:-}" ]] || fail "SAIL_PIN_UPDATED_ON missing in ${PIN_FILE}"

if ! [[ "${SAIL_PINNED_REF}" =~ ^[0-9a-f]{40}$ ]]; then
  fail "SAIL_PINNED_REF must be a 40-char git commit SHA (got: ${SAIL_PINNED_REF})"
fi

if [[ "${SAIL_PIN_TRACKING_REF}" =~ ^[0-9a-f]{40}$ ]]; then
  fail "SAIL_PIN_TRACKING_REF must be a branch/tag name, not a commit SHA"
fi

[[ -f "${RENDER_SCRIPT}" ]] || fail "missing render script: ${RENDER_SCRIPT}"
rg -q "SAIL_PIN_FILE" "${RENDER_SCRIPT}" || fail "render script does not consume Sail pin manifest"
rg -q "SAIL_PINNED_REF" "${RENDER_SCRIPT}" || fail "render script does not propagate Sail pin ref"

echo "[ok] Sail pin manifest contract validated (${PIN_FILE})"

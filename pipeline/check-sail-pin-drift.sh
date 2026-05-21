#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN_FILE="${ROOT}/specs/014-fdc3-intent-interoperability/generation/sail-pin.env"
FAIL_ON_DRIFT=0
FAIL_ON_FETCH_ERROR=0

usage() {
  cat <<'EOF'
usage: bash pipeline/check-sail-pin-drift.sh [--pin-file <path>] [--fail-on-drift] [--fail-on-fetch-error]

Checks whether Sail upstream tracking ref has moved beyond the pinned commit.
EOF
}

while (($# > 0)); do
  case "$1" in
    --pin-file)
      PIN_FILE="${2:-}"
      shift 2
      ;;
    --fail-on-drift)
      FAIL_ON_DRIFT=1
      shift
      ;;
    --fail-on-fetch-error)
      FAIL_ON_FETCH_ERROR=1
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

fail() {
  echo "[fail] $*"
  exit 1
}

warn() {
  echo "[warn] $*"
}

[[ -f "${PIN_FILE}" ]] || fail "missing Sail pin manifest: ${PIN_FILE}"
# shellcheck disable=SC1090
source "${PIN_FILE}"

[[ -n "${SAIL_PIN_REPO_URL:-}" ]] || fail "SAIL_PIN_REPO_URL missing in ${PIN_FILE}"
[[ -n "${SAIL_PIN_TRACKING_REF:-}" ]] || fail "SAIL_PIN_TRACKING_REF missing in ${PIN_FILE}"
[[ -n "${SAIL_PINNED_REF:-}" ]] || fail "SAIL_PINNED_REF missing in ${PIN_FILE}"

if ! [[ "${SAIL_PINNED_REF}" =~ ^[0-9a-f]{40}$ ]]; then
  fail "SAIL_PINNED_REF must be a 40-char git commit SHA (got: ${SAIL_PINNED_REF})"
fi

if ! command -v git >/dev/null 2>&1; then
  fail "git is required"
fi

tracking_ref_path="${SAIL_PIN_TRACKING_REF}"
if [[ "${tracking_ref_path}" != refs/* ]]; then
  tracking_ref_path="refs/heads/${tracking_ref_path}"
fi

if ! tracking_line="$(git ls-remote "${SAIL_PIN_REPO_URL}" "${tracking_ref_path}" 2>/dev/null)"; then
  if ((FAIL_ON_FETCH_ERROR)); then
    fail "unable to query Sail upstream ref ${tracking_ref_path}"
  fi
  warn "unable to query Sail upstream ref ${tracking_ref_path}; skipping drift verdict"
  exit 0
fi

tracking_sha="$(awk '{print $1}' <<<"${tracking_line}" | head -n1)"
if [[ -z "${tracking_sha}" ]]; then
  if ((FAIL_ON_FETCH_ERROR)); then
    fail "no commit resolved for ${tracking_ref_path}"
  fi
  warn "no commit resolved for ${tracking_ref_path}; skipping drift verdict"
  exit 0
fi

if ! git ls-remote "${SAIL_PIN_REPO_URL}" "${SAIL_PINNED_REF}" >/dev/null 2>&1; then
  fail "pinned commit not found in Sail remote: ${SAIL_PINNED_REF}"
fi

echo "[info] Sail repo: ${SAIL_PIN_REPO_URL}"
echo "[info] Sail tracking ref: ${tracking_ref_path} @ ${tracking_sha}"
echo "[info] Sail pinned ref: ${SAIL_PINNED_REF}"

if [[ "${tracking_sha}" == "${SAIL_PINNED_REF}" ]]; then
  echo "[ok] Sail pin is current (no upstream drift)"
  exit 0
fi

warn "Sail pin drift detected: tracking ref moved beyond pinned commit"
warn "update ${PIN_FILE} after validating state maintenance refresh"
if ((FAIL_ON_DRIFT)); then
  exit 1
fi
exit 0

#!/usr/bin/env bash
set -euo pipefail

# Also guard the build itself: build hooks can bypass Netlify's ignore command.
if [[ "${CONTEXT:-}" != "deploy-preview" ]]; then
  echo "[fail] Netlify builds are restricted to deploy-preview; GitHub Actions publishes production." >&2
  exit 1
fi
: "${DEPLOY_PRIME_URL:?Set DEPLOY_PRIME_URL to the preview URL (or local test URL)}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOCUSAURUS_URL="${DEPLOY_PRIME_URL}"
export DOCUSAURUS_BASE_URL="/"
TRADERX_SITE_ROOT="" bash "${ROOT}/pipeline/refresh-state-docs.sh"
npm --prefix "${ROOT}/website" run clear
npm --prefix "${ROOT}/website" run build

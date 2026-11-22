#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[info] no state-specific test entrypoint was detected for this snapshot."
if [[ -d "${ROOT}/scripts" ]]; then
  echo "[hint] available test scripts:"
  ls "${ROOT}/scripts"/test-state-*.sh 2>/dev/null || true
fi
exit 2

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/TraderSpec/codebase/target-generated"

mkdir -p "${TARGET}"
mkdir -p "${TARGET}/apps" "${TARGET}/infra" "${TARGET}/contracts" "${TARGET}/tests"

cat <<'EOF' > "${TARGET}/README.md"
# TraderSpec Generated Target

This folder is the destination for full code generation from TraderSpec requirements.

Generation must preserve baseline behavior and apply selected track step overlays.
EOF

echo "[bootstrap] target-generated initialized"

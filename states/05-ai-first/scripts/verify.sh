#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -f "${ROOT}/AGENTS.md" ]] || { echo "missing AGENTS.md"; exit 1; }
[[ -f "${ROOT}/prompts/session/00_session-kickoff.md" ]] || { echo "missing session prompt"; exit 1; }
[[ -f "${ROOT}/prompts/navigation/learning-path-navigator.md" ]] || { echo "missing navigator prompt"; exit 1; }
[[ -f "${ROOT}/prompts/generation/state-from-contract.md" ]] || { echo "missing generation prompt"; exit 1; }
[[ -f "${ROOT}/prompts/explanation/diff-between-states.md" ]] || { echo "missing diff prompt"; exit 1; }
[[ -f "${ROOT}/prompts/validation/mesh-sanity-check.md" ]] || { echo "missing validation prompt"; exit 1; }
[[ -f "${ROOT}/prompts/contrib/new-learning-path.md" ]] || { echo "missing contribution prompt"; exit 1; }

echo "[verify] 05-ai-first checks passed"

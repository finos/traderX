#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local test entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/test-state-003-agentic-harness-foundation.sh
#  - scripts/test-web-angular-baseline-ux-contract.sh

exec "${ROOT}/scripts/test-state-003-agentic-harness-foundation.sh" "$@"

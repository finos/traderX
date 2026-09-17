#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local start entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/start-state-003-agentic-harness-foundation-generated.sh
#  - scripts/start-base-uncontainerized-generated.sh
#  - scripts/stop-state-003-agentic-harness-foundation-generated.sh
#  - scripts/stop-base-uncontainerized-generated.sh

exec "${ROOT}/scripts/start-state-003-agentic-harness-foundation-generated.sh" "$@"

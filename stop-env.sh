#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local stop entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/stop-state-003-agentic-harness-foundation-generated.sh
#  - scripts/stop-base-uncontainerized-generated.sh

exec "${ROOT}/scripts/stop-state-003-agentic-harness-foundation-generated.sh" "$@"

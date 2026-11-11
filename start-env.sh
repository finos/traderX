#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local start entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/start-base-uncontainerized-generated.sh
#  - scripts/stop-base-uncontainerized-generated.sh

exec "${ROOT}/scripts/start-base-uncontainerized-generated.sh" "$@"

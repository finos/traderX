#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local stop entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/stop-state-013-radius-kubernetes-platform-generated.sh
#  - scripts/stop-state-010-kubernetes-runtime-generated.sh

exec "${ROOT}/scripts/stop-state-013-radius-kubernetes-platform-generated.sh" "$@"

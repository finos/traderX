#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local start entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/start-state-012-platform-convergence-c3-generated.sh
#  - scripts/start-state-010-kubernetes-runtime-generated.sh

exec "${ROOT}/scripts/start-state-012-platform-convergence-c3-generated.sh" "$@"

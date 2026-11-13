#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local status entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/status-state-014-fdc3-intent-interoperability-generated.sh
#  - scripts/status-state-012-platform-convergence-c3-generated.sh
#  - scripts/status-state-010-kubernetes-runtime-generated.sh

exec "${ROOT}/scripts/status-state-014-fdc3-intent-interoperability-generated.sh" "$@"

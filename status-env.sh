#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local status entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow: scripts/status-state-010-kubernetes-runtime-generated.sh

exec "${ROOT}/scripts/status-state-010-kubernetes-runtime-generated.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local start entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow: scripts/start-state-008-pricing-awareness-market-data-generated.sh

exec "${ROOT}/scripts/start-state-008-pricing-awareness-market-data-generated.sh" "$@"

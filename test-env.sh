#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local test entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/test-state-013-radius-kubernetes-platform.sh
#  - scripts/test-state-010-kubernetes-runtime.sh
#  - scripts/test-account-service-overlay.sh
#  - scripts/test-people-service-overlay.sh
#  - scripts/test-position-service-overlay.sh
#  - scripts/test-reference-data-overlay.sh
#  - scripts/test-trade-service-overlay.sh
#  - scripts/test-web-angular-baseline-ux-contract.sh
#  - scripts/test-web-angular-overlay.sh

exec "${ROOT}/scripts/test-state-013-radius-kubernetes-platform.sh" "$@"

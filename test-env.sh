#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local test entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/test-state-008-pricing-awareness-market-data.sh
#  - scripts/test-account-service-overlay.sh
#  - scripts/test-api-explorer-pubsub-inspector.sh
#  - scripts/test-messaging-008-pricing-awareness-market-data.sh
#  - scripts/test-people-service-overlay.sh
#  - scripts/test-position-service-overlay.sh
#  - scripts/test-reference-data-overlay.sh
#  - scripts/test-trade-service-overlay.sh
#  - scripts/test-web-angular-baseline-ux-contract.sh
#  - scripts/test-web-angular-overlay.sh

exec "${ROOT}/scripts/test-state-008-pricing-awareness-market-data.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local test entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/test-state-009-order-management-matcher.sh
#  - scripts/test-api-explorer-pubsub-inspector.sh
#  - scripts/test-messaging-009-order-management-matcher.sh
#  - scripts/test-web-angular-baseline-ux-contract.sh
#  - scripts/test-messaging-008-pricing-awareness-market-data.sh
#  - scripts/test-order-create-pubsub-smoke.sh
#  - scripts/test-realtime-order-stream-overlay.sh

exec "${ROOT}/scripts/test-state-009-order-management-matcher.sh" "$@"

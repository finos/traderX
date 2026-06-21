#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper purpose: stable, state-local start entrypoint.
# This may delegate across multiple numbered state scripts to maximize reuse.
# Execution flow:
#  - scripts/start-state-007-observability-lgtm-compose-generated.sh
#  - scripts/start-grafana-traderx-dashboards.sh

exec "${ROOT}/scripts/start-state-007-observability-lgtm-compose-generated.sh" "$@"

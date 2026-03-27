#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MANIFESTS="${ROOT}/states/03-service-mesh/solo-demo/manifests"
OBS="${ROOT}/states/03-service-mesh/solo-demo/observability"

[[ -f "${MANIFESTS}/peerauthentication-mtls.yaml" ]] || { echo "missing mTLS policy"; exit 1; }
[[ -f "${MANIFESTS}/networkpolicy-default-deny.yaml" ]] || { echo "missing default deny network policy"; exit 1; }
[[ -f "${MANIFESTS}/virtualservice-trade-service.yaml" ]] || { echo "missing canary virtual service"; exit 1; }
grep -q "weight: 10" "${MANIFESTS}/virtualservice-trade-service.yaml" || { echo "missing 10% canary route"; exit 1; }
[[ -f "${OBS}/prometheus-scrape.yaml" ]] || { echo "missing observability scrape config"; exit 1; }

echo "[verify] solo-demo static mesh checks passed"

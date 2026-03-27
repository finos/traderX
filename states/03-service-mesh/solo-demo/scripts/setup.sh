#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MANIFESTS="${ROOT}/states/03-service-mesh/solo-demo/manifests"

echo "[setup] static scaffold ready at ${MANIFESTS}"
echo "[setup] apply with: kubectl apply -k ${MANIFESTS}"

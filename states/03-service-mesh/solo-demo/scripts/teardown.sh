#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MANIFESTS="${ROOT}/states/03-service-mesh/solo-demo/manifests"

echo "[teardown] remove with: kubectl delete -k ${MANIFESTS}"

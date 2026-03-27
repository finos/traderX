#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -f "${ROOT}/docker-compose.yml" ]] || { echo "missing docker-compose.yml"; exit 1; }
[[ -d "${ROOT}/gitops" ]] || { echo "missing gitops"; exit 1; }
[[ -d "${ROOT}/ingress" ]] || { echo "missing ingress"; exit 1; }

echo "[verify] 02-containerized checks passed"

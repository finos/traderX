#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "${ROOT}/pipeline/generate-state-docs-from-catalog.mjs"

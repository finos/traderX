#!/usr/bin/env bash
set -euo pipefail

# Shared runtime loader for overlay scripts.
# Source from every start/stop/smoke/pipeline script:
#   source "${OVERLAY_ROOT}/overlay/runtime/env-loader.sh"
#
# Requirements:
# - idempotent
# - export tool availability to child processes
# - pin specific versions (do not float on defaults)
# - print active versions for diagnostics

if [[ "${TRADERX_OVERLAY_ENV_LOADED:-0}" == "1" ]]; then
  return 0
fi
export TRADERX_OVERLAY_ENV_LOADED=1

OVERLAY_RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_ROOT="$(cd "${OVERLAY_RUNTIME_ROOT}/../.." && pwd)"

# Optional isolated HOME for per-run credentials/tool caches.
# export HOME="${OVERLAY_ROOT}/.tool-cache/home"
# mkdir -p "${HOME}"

# Option A: local tool installations with explicit PATH ordering.
# export JAVA_HOME="/opt/java/jdk-21"
# export DOTNET_ROOT="/opt/dotnet/9.0"
# export PATH="${JAVA_HOME}/bin:${DOTNET_ROOT}:${PATH}"

# Option B: source profile script that pins versions.
# source "${OVERLAY_ROOT}/overlay/runtime/path-setup.sh"

# Option C: module-loader environments.
# module purge
# module load java/21
# module load node/22
# module load dotnet/9.0
# module load jq/1.7

# Fail fast on required tools.
required_tools=(java node dotnet jq)
for tool in "${required_tools[@]}"; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "[fail] required tool not found on PATH: ${tool}" >&2
    return 1
  fi
done

# Emit active versions for debugging.
java -version 2>&1 | head -n 1 | sed 's/^/[env] /'
node --version | sed 's/^/[env] node /'
dotnet --version | sed 's/^/[env] dotnet /'
jq --version | sed 's/^/[env] /'

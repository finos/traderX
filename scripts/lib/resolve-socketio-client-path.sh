#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

candidate_paths=(
  "${REPO_ROOT}/generated/code/target-generated/trade-feed/node_modules/socket.io-client"
  "${REPO_ROOT}/generated/code/components/trade-feed-specfirst/node_modules/socket.io-client"
  "${REPO_ROOT}/node_modules/socket.io-client"
)

for candidate in "${candidate_paths[@]}"; do
  if [[ -d "${candidate}" ]]; then
    echo "${candidate}"
    exit 0
  fi
done

if ! command -v npm >/dev/null 2>&1; then
  echo "[error] npm command not found and no socket.io-client module is available" >&2
  exit 1
fi

cache_dir="${REPO_ROOT}/generated/tool-cache/socketio-client"
module_dir="${cache_dir}/node_modules/socket.io-client"

if [[ ! -d "${module_dir}" ]]; then
  mkdir -p "${cache_dir}"
  if [[ ! -f "${cache_dir}/package.json" ]]; then
    cat > "${cache_dir}/package.json" <<'EOF'
{
  "name": "traderx-smoke-tooling",
  "private": true,
  "dependencies": {
    "socket.io-client": "^4.8.1"
  }
}
EOF
  fi
  echo "[setup] installing socket.io-client smoke-test dependency in ${cache_dir}" >&2
  npm --prefix "${cache_dir}" install --no-audit --prefer-offline >/dev/null
fi

echo "${module_dir}"

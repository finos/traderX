#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${1:-${GENERATED_ROOT}/code/target-generated}"
STATE_METADATA="${TARGET_ROOT}/ci/state-metadata.json"

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  echo "[hint] generate a state first (for example: bash pipeline/generate-state.sh 008-pricing-awareness-market-data)"
  exit 1
fi

if [[ ! -f "${STATE_METADATA}" ]]; then
  echo "[fail] missing state metadata: ${STATE_METADATA}"
  echo "[hint] ensure CI assets were installed during state generation"
  exit 1
fi

run_actionlint() {
  if ! command -v actionlint >/dev/null 2>&1; then
    echo "[warn] actionlint not found; skipping workflow lint"
    return 0
  fi
  echo "[info] actionlint .github/workflows"
  (
    cd "${TARGET_ROOT}"
    actionlint -color .github/workflows/*.yml
  )
}

run_node_preflight() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "[fail] npm not found"
    exit 1
  fi
  node_modules=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    node_modules+=("${module}")
  done < <(jq -r '.modules.node[]?' "${STATE_METADATA}")
  if ((${#node_modules[@]} == 0)); then
    echo "[info] no Node modules detected"
    return 0
  fi
  for module in "${node_modules[@]}"; do
    echo "[info] node preflight: ${module}"
    (
      cd "${TARGET_ROOT}/${module}"
      if [[ -f package-lock.json ]]; then
        npm ci
      else
        npm install
      fi
      npm run build --if-present
    )
  done
}

run_gradle_preflight() {
  gradle_modules=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    gradle_modules+=("${module}")
  done < <(jq -r '.modules.gradle[]?' "${STATE_METADATA}")
  if ((${#gradle_modules[@]} == 0)); then
    echo "[info] no Gradle modules detected"
    return 0
  fi
  for module in "${gradle_modules[@]}"; do
    echo "[info] gradle preflight: ${module}"
    (
      cd "${TARGET_ROOT}/${module}"
      if [[ -x ./gradlew ]]; then
        ./gradlew clean build --no-daemon
      else
        gradle clean build --no-daemon
      fi
    )
  done
}

run_dotnet_preflight() {
  dotnet_modules=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    dotnet_modules+=("${module}")
  done < <(jq -r '.modules.dotnet[]?' "${STATE_METADATA}")
  if ((${#dotnet_modules[@]} == 0)); then
    echo "[info] no .NET modules detected"
    return 0
  fi
  if ! command -v dotnet >/dev/null 2>&1; then
    echo "[fail] dotnet CLI not found but .NET modules are present"
    exit 1
  fi
  for module in "${dotnet_modules[@]}"; do
    echo "[info] dotnet preflight: ${module}"
    (
      cd "${TARGET_ROOT}/${module}"
      dotnet build --configuration Release
    )
  done
}

run_actionlint
run_node_preflight
run_gradle_preflight
run_dotnet_preflight

echo "[ok] generated CI preflight passed for ${TARGET_ROOT}"

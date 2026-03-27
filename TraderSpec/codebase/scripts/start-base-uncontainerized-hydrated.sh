#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TRADERSPEC_ROOT="${REPO_ROOT}/TraderSpec"
TARGET="${TRADERSPEC_ROOT}/codebase/target-generated"
SPEC="${TRADERSPEC_ROOT}/catalog/base-uncontainerized-processes.csv"
RUN_DIR="${TARGET}/.run/base-uncontainerized"
TOOL_CACHE_DIR="${RUN_DIR}/tool-cache"
REFERENCE_DATA_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/reference-data-specfirst"
DATABASE_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/database-specfirst"
PEOPLE_SERVICE_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/people-service-specfirst"
ACCOUNT_SERVICE_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/account-service-specfirst"
POSITION_SERVICE_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/position-service-specfirst"
TRADE_FEED_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/trade-feed-specfirst"
TRADE_PROCESSOR_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/trade-processor-specfirst"
TRADE_SERVICE_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/trade-service-specfirst"
WEB_FRONT_END_ANGULAR_SPECFIRST="${TRADERSPEC_ROOT}/codebase/generated-components/web-front-end-angular-specfirst"

DRY_RUN=0
OVERLAY_REFERENCE_GENERATED=0
OVERLAY_DATABASE_GENERATED=0
OVERLAY_PEOPLE_GENERATED=0
OVERLAY_ACCOUNT_GENERATED=0
OVERLAY_POSITION_GENERATED=0
OVERLAY_TRADE_FEED_GENERATED=0
OVERLAY_TRADE_PROCESSOR_GENERATED=0
OVERLAY_TRADE_SERVICE_GENERATED=0
OVERLAY_WEB_ANGULAR_GENERATED=0
PURE_GENERATED_BASE=0
while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --pure-generated-base)
      PURE_GENERATED_BASE=1
      OVERLAY_REFERENCE_GENERATED=1
      OVERLAY_DATABASE_GENERATED=1
      OVERLAY_PEOPLE_GENERATED=1
      OVERLAY_ACCOUNT_GENERATED=1
      OVERLAY_POSITION_GENERATED=1
      OVERLAY_TRADE_FEED_GENERATED=1
      OVERLAY_TRADE_PROCESSOR_GENERATED=1
      OVERLAY_TRADE_SERVICE_GENERATED=1
      OVERLAY_WEB_ANGULAR_GENERATED=1
      ;;
    --overlay-reference-generated)
      OVERLAY_REFERENCE_GENERATED=1
      ;;
    --overlay-database-generated)
      OVERLAY_DATABASE_GENERATED=1
      ;;
    --overlay-people-generated)
      OVERLAY_PEOPLE_GENERATED=1
      ;;
    --overlay-account-generated)
      OVERLAY_ACCOUNT_GENERATED=1
      ;;
    --overlay-position-generated)
      OVERLAY_POSITION_GENERATED=1
      ;;
    --overlay-trade-feed-generated)
      OVERLAY_TRADE_FEED_GENERATED=1
      ;;
    --overlay-trade-processor-generated)
      OVERLAY_TRADE_PROCESSOR_GENERATED=1
      ;;
    --overlay-trade-service-generated)
      OVERLAY_TRADE_SERVICE_GENERATED=1
      ;;
    --overlay-web-angular-generated)
      OVERLAY_WEB_ANGULAR_GENERATED=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run, --pure-generated-base, --overlay-reference-generated, --overlay-database-generated, --overlay-people-generated, --overlay-account-generated, --overlay-position-generated, --overlay-trade-feed-generated, --overlay-trade-processor-generated, --overlay-trade-service-generated, --overlay-web-angular-generated"
      exit 1
      ;;
  esac
  shift
done

if (( OVERLAY_REFERENCE_GENERATED == 1 &&
      OVERLAY_DATABASE_GENERATED == 1 &&
      OVERLAY_PEOPLE_GENERATED == 1 &&
      OVERLAY_ACCOUNT_GENERATED == 1 &&
      OVERLAY_POSITION_GENERATED == 1 &&
      OVERLAY_TRADE_FEED_GENERATED == 1 &&
      OVERLAY_TRADE_PROCESSOR_GENERATED == 1 &&
      OVERLAY_TRADE_SERVICE_GENERATED == 1 &&
      OVERLAY_WEB_ANGULAR_GENERATED == 1 )); then
  PURE_GENERATED_BASE=1
fi

legacy_baseline_available() {
  local required=(
    "account-service"
    "trade-service"
    "position-service"
    "trade-processor"
    "reference-data"
    "people-service"
    "trade-feed"
    "database"
    "web-front-end/angular"
  )

  local path
  for path in "${required[@]}"; do
    if [[ ! -d "${REPO_ROOT}/${path}" ]]; then
      return 1
    fi
  done
  return 0
}

if (( PURE_GENERATED_BASE == 0 )) && ! legacy_baseline_available; then
  echo "[info] legacy root baseline is not present; switching to pure-generated base layout"
  PURE_GENERATED_BASE=1
  OVERLAY_REFERENCE_GENERATED=1
  OVERLAY_DATABASE_GENERATED=1
  OVERLAY_PEOPLE_GENERATED=1
  OVERLAY_ACCOUNT_GENERATED=1
  OVERLAY_POSITION_GENERATED=1
  OVERLAY_TRADE_FEED_GENERATED=1
  OVERLAY_TRADE_PROCESSOR_GENERATED=1
  OVERLAY_TRADE_SERVICE_GENERATED=1
  OVERLAY_WEB_ANGULAR_GENERATED=1
fi

prepare_pure_generated_base_layout() {
  local generated_paths=(
    "${REFERENCE_DATA_SPECFIRST}"
    "${DATABASE_SPECFIRST}"
    "${PEOPLE_SERVICE_SPECFIRST}"
    "${ACCOUNT_SERVICE_SPECFIRST}"
    "${POSITION_SERVICE_SPECFIRST}"
    "${TRADE_FEED_SPECFIRST}"
    "${TRADE_PROCESSOR_SPECFIRST}"
    "${TRADE_SERVICE_SPECFIRST}"
    "${WEB_FRONT_END_ANGULAR_SPECFIRST}"
  )

  local p
  for p in "${generated_paths[@]}"; do
    if [[ ! -d "${p}" ]]; then
      echo "[error] required generated component not found: ${p}"
      echo "[hint] run the TraderSpec generation pipeline scripts first."
      exit 1
    fi
  done

  mkdir -p "${TARGET}" "${TARGET}/web-front-end"

  # Keep runtime cache/state under .run intact and only refresh component workdirs.
  rm -rf "${TARGET}/reference-data"
  rm -rf "${TARGET}/database"
  rm -rf "${TARGET}/people-service"
  rm -rf "${TARGET}/account-service"
  rm -rf "${TARGET}/position-service"
  rm -rf "${TARGET}/trade-feed"
  rm -rf "${TARGET}/trade-processor"
  rm -rf "${TARGET}/trade-service"
  rm -rf "${TARGET}/web-front-end/angular"

  cp -R "${REFERENCE_DATA_SPECFIRST}" "${TARGET}/reference-data"
  cp -R "${DATABASE_SPECFIRST}" "${TARGET}/database"
  cp -R "${PEOPLE_SERVICE_SPECFIRST}" "${TARGET}/people-service"
  cp -R "${ACCOUNT_SERVICE_SPECFIRST}" "${TARGET}/account-service"
  cp -R "${POSITION_SERVICE_SPECFIRST}" "${TARGET}/position-service"
  cp -R "${TRADE_FEED_SPECFIRST}" "${TARGET}/trade-feed"
  cp -R "${TRADE_PROCESSOR_SPECFIRST}" "${TARGET}/trade-processor"
  cp -R "${TRADE_SERVICE_SPECFIRST}" "${TARGET}/trade-service"
  cp -R "${WEB_FRONT_END_ANGULAR_SPECFIRST}" "${TARGET}/web-front-end/angular"

  echo "[ok] pure generated base layout prepared in ${TARGET}"
}

if ((PURE_GENERATED_BASE == 1)); then
  prepare_pure_generated_base_layout
else
  "${TRADERSPEC_ROOT}/pipeline/generate-baseline-from-current.sh"
  "${TRADERSPEC_ROOT}/codebase/scripts/prepare-parity-layout.sh"
fi

if ((OVERLAY_REFERENCE_GENERATED == 1)); then
  if [[ ! -d "${REFERENCE_DATA_SPECFIRST}" ]]; then
    echo "[error] generated reference-data component not found: ${REFERENCE_DATA_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/reference-data"
  cp -R "${REFERENCE_DATA_SPECFIRST}" "${TARGET}/reference-data"
  echo "[overlay] using generated reference-data component from ${REFERENCE_DATA_SPECFIRST}"
fi

if ((OVERLAY_DATABASE_GENERATED == 1)); then
  if [[ ! -d "${DATABASE_SPECFIRST}" ]]; then
    echo "[error] generated database component not found: ${DATABASE_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/database"
  cp -R "${DATABASE_SPECFIRST}" "${TARGET}/database"
  echo "[overlay] using generated database component from ${DATABASE_SPECFIRST}"
fi

if ((OVERLAY_PEOPLE_GENERATED == 1)); then
  if [[ ! -d "${PEOPLE_SERVICE_SPECFIRST}" ]]; then
    echo "[error] generated people-service component not found: ${PEOPLE_SERVICE_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/people-service"
  cp -R "${PEOPLE_SERVICE_SPECFIRST}" "${TARGET}/people-service"
  echo "[overlay] using generated people-service component from ${PEOPLE_SERVICE_SPECFIRST}"
fi

if ((OVERLAY_ACCOUNT_GENERATED == 1)); then
  if [[ ! -d "${ACCOUNT_SERVICE_SPECFIRST}" ]]; then
    echo "[error] generated account-service component not found: ${ACCOUNT_SERVICE_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/account-service"
  cp -R "${ACCOUNT_SERVICE_SPECFIRST}" "${TARGET}/account-service"
  echo "[overlay] using generated account-service component from ${ACCOUNT_SERVICE_SPECFIRST}"
fi

if ((OVERLAY_POSITION_GENERATED == 1)); then
  if [[ ! -d "${POSITION_SERVICE_SPECFIRST}" ]]; then
    echo "[error] generated position-service component not found: ${POSITION_SERVICE_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/position-service"
  cp -R "${POSITION_SERVICE_SPECFIRST}" "${TARGET}/position-service"
  echo "[overlay] using generated position-service component from ${POSITION_SERVICE_SPECFIRST}"
fi

if ((OVERLAY_TRADE_FEED_GENERATED == 1)); then
  if [[ ! -d "${TRADE_FEED_SPECFIRST}" ]]; then
    echo "[error] generated trade-feed component not found: ${TRADE_FEED_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/trade-feed"
  cp -R "${TRADE_FEED_SPECFIRST}" "${TARGET}/trade-feed"
  echo "[overlay] using generated trade-feed component from ${TRADE_FEED_SPECFIRST}"
fi

if ((OVERLAY_TRADE_PROCESSOR_GENERATED == 1)); then
  if [[ ! -d "${TRADE_PROCESSOR_SPECFIRST}" ]]; then
    echo "[error] generated trade-processor component not found: ${TRADE_PROCESSOR_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/trade-processor"
  cp -R "${TRADE_PROCESSOR_SPECFIRST}" "${TARGET}/trade-processor"
  echo "[overlay] using generated trade-processor component from ${TRADE_PROCESSOR_SPECFIRST}"
fi

if ((OVERLAY_TRADE_SERVICE_GENERATED == 1)); then
  if [[ ! -d "${TRADE_SERVICE_SPECFIRST}" ]]; then
    echo "[error] generated trade-service component not found: ${TRADE_SERVICE_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/trade-service"
  cp -R "${TRADE_SERVICE_SPECFIRST}" "${TARGET}/trade-service"
  echo "[overlay] using generated trade-service component from ${TRADE_SERVICE_SPECFIRST}"
fi

if ((OVERLAY_WEB_ANGULAR_GENERATED == 1)); then
  if [[ ! -d "${WEB_FRONT_END_ANGULAR_SPECFIRST}" ]]; then
    echo "[error] generated web-front-end-angular component not found: ${WEB_FRONT_END_ANGULAR_SPECFIRST}"
    exit 1
  fi
  rm -rf "${TARGET}/web-front-end/angular"
  mkdir -p "${TARGET}/web-front-end"
  cp -R "${WEB_FRONT_END_ANGULAR_SPECFIRST}" "${TARGET}/web-front-end/angular"
  echo "[overlay] using generated web-front-end-angular component from ${WEB_FRONT_END_ANGULAR_SPECFIRST}"
fi

mkdir -p \
  "${RUN_DIR}/logs" \
  "${RUN_DIR}/pids" \
  "${TOOL_CACHE_DIR}/gradle" \
  "${TOOL_CACHE_DIR}/npm" \
  "${TOOL_CACHE_DIR}/dotnet-home" \
  "${TOOL_CACHE_DIR}/nuget"

# Keep tool caches inside TraderSpec runtime state so startup works in restricted environments.
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${TOOL_CACHE_DIR}/gradle}"
export npm_config_cache="${npm_config_cache:-${TOOL_CACHE_DIR}/npm}"
export DOTNET_CLI_HOME="${DOTNET_CLI_HOME:-${TOOL_CACHE_DIR}/dotnet-home}"
export NUGET_PACKAGES="${NUGET_PACKAGES:-${TOOL_CACHE_DIR}/nuget}"

export DATABASE_TCP_PORT="${DATABASE_TCP_PORT:-18082}"
export DATABASE_PG_PORT="${DATABASE_PG_PORT:-18083}"
export DATABASE_WEB_PORT="${DATABASE_WEB_PORT:-18084}"
export REFERENCE_DATA_SERVICE_PORT="${REFERENCE_DATA_SERVICE_PORT:-18085}"
export TRADE_FEED_PORT="${TRADE_FEED_PORT:-18086}"
export ACCOUNT_SERVICE_PORT="${ACCOUNT_SERVICE_PORT:-18088}"
export PEOPLE_SERVICE_PORT="${PEOPLE_SERVICE_PORT:-18089}"
export POSITION_SERVICE_PORT="${POSITION_SERVICE_PORT:-18090}"
export TRADE_PROCESSOR_SERVICE_PORT="${TRADE_PROCESSOR_SERVICE_PORT:-18091}"
export TRADING_SERVICE_PORT="${TRADING_SERVICE_PORT:-18092}"
export WEB_SERVICE_ANGULAR_PORT="${WEB_SERVICE_ANGULAR_PORT:-18093}"

export DATABASE_TCP_HOST=localhost
export PEOPLE_SERVICE_HOST=localhost
export ACCOUNT_SERVICE_HOST=localhost
export REFERENCE_DATA_HOST=localhost
export TRADE_FEED_HOST=localhost

preflight_checks() {
  if ! command -v nc >/dev/null 2>&1; then
    echo "[error] missing required command: nc"
    exit 1
  fi

  if ! command -v dotnet >/dev/null 2>&1; then
    echo "[error] missing required runtime: dotnet (needed for people-service)"
    exit 1
  fi

  if ! dotnet --version >/dev/null 2>&1; then
    echo "[error] dotnet runtime is installed but not runnable on this machine."
    echo "[hint] install a native arm64 dotnet runtime or enable Rosetta/x64 compatibility."
    exit 1
  fi

  local dotnet_runtimes
  dotnet_runtimes="$(dotnet --list-runtimes 2>/dev/null || true)"

  if ! printf '%s\n' "${dotnet_runtimes}" | grep -Eq '^Microsoft\.NETCore\.App 9\.'; then
    echo "[error] missing required runtime: Microsoft.NETCore.App 9.x (arm64) for people-service (net9.0)."
    exit 1
  fi

  if ! printf '%s\n' "${dotnet_runtimes}" | grep -Eq '^Microsoft\.AspNetCore\.App 9\.'; then
    echo "[error] missing required runtime: Microsoft.AspNetCore.App 9.x (arm64) for people-service (net9.0)."
    echo "[hint] install ASP.NET Core Runtime 9 for arm64 and retry."
    exit 1
  fi

  if [[ "${TRADERSPEC_SKIP_NETWORK_CHECK:-0}" != "1" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
      echo "[error] missing required command: curl (needed for gradle network preflight)"
      exit 1
    fi

    local gradle_dist_url="${GRADLE_WRAPPER_CHECK_URL:-https://services.gradle.org/distributions/}"
    local maven_repo_url="${MAVEN_CENTRAL_CHECK_URL:-https://repo.maven.apache.org/maven2/}"

    if ! curl -fsSLI --max-time 10 "${gradle_dist_url}" >/dev/null 2>&1; then
      echo "[error] gradle network preflight failed for ${gradle_dist_url}"
      echo "[hint] verify outbound HTTPS access (or proxy) for Gradle distribution downloads."
      echo "[hint] set TRADERSPEC_SKIP_NETWORK_CHECK=1 only if dependencies are already cached."
      exit 1
    fi

    if ! curl -fsSLI --max-time 10 "${maven_repo_url}" >/dev/null 2>&1; then
      echo "[error] gradle network preflight failed for ${maven_repo_url}"
      echo "[hint] verify outbound HTTPS access (or proxy) for Maven Central dependency resolution."
      echo "[hint] set TRADERSPEC_SKIP_NETWORK_CHECK=1 only if dependencies are already cached."
      exit 1
    fi
  fi
}

wait_for_port() {
  local process="$1"
  local port="$2"
  local attempts=120
  local sleep_seconds=1
  local i

  for ((i=1; i<=attempts; i++)); do
    if nc -z localhost "${port}" >/dev/null 2>&1; then
      echo "[ready] ${process} on :${port}"
      return 0
    fi
    sleep "${sleep_seconds}"
  done

  echo "[error] timeout waiting for ${process} on :${port}"
  return 1
}

port_listener_pids() {
  local port="$1"
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  lsof -nP -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true
}

start_process() {
  local process="$1"
  local workdir_rel="$2"
  local cmd="$3"
  local port="$4"

  local workdir="${TARGET}/${workdir_rel}"
  local pidfile="${RUN_DIR}/pids/${process}.pid"
  local logfile="${RUN_DIR}/logs/${process}.log"

  if [[ ! -d "${workdir}" ]]; then
    echo "[error] missing workdir for ${process}: ${workdir}"
    exit 1
  fi

  if [[ -f "${pidfile}" ]]; then
    local oldpid
    oldpid="$(cat "${pidfile}")"
    if kill -0 "${oldpid}" >/dev/null 2>&1; then
      echo "[skip] ${process} already running (pid ${oldpid})"
      return 0
    fi
  fi

  if nc -z localhost "${port}" >/dev/null 2>&1; then
    echo "[error] port :${port} already in use before starting ${process}"
    local pids
    pids="$(port_listener_pids "${port}")"
    if [[ -n "${pids}" ]]; then
      echo "[hint] listener pid(s): ${pids}"
    fi
    echo "[hint] run stop script, then retry:"
    echo "       ./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh"
    exit 1
  fi

  if ((DRY_RUN == 1)); then
    echo "[dry-run] ${process}: cd ${workdir} && ${cmd}"
    return 0
  fi

  echo "[start] ${process}"
  nohup /bin/zsh -lc "cd '${workdir}' && ${cmd}" >"${logfile}" 2>&1 &
  echo "$!" > "${pidfile}"

  wait_for_port "${process}" "${port}" || {
    echo "[hint] check logs: ${logfile}"
    exit 1
  }
}

if [[ ! -f "${SPEC}" ]]; then
  echo "[error] missing startup spec: ${SPEC}"
  exit 1
fi

if ((DRY_RUN == 0)); then
  preflight_checks
fi

while IFS=, read -r order process workdir start_cmd port health_hint; do
  if [[ "${order}" == "order" ]]; then
    continue
  fi
  start_process "${process}" "${workdir}" "${start_cmd}" "${port}"
done < <(tail -n +2 "${SPEC}" | sort -t, -k1,1n)

if ((DRY_RUN == 1)); then
  echo "[done] dry run complete"
else
  echo "[done] base uncontainerized hydrated stack started"
  echo "[ui] http://localhost:${WEB_SERVICE_ANGULAR_PORT}"
fi

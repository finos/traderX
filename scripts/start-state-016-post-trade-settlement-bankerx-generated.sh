#!/usr/bin/env bash
set -euo pipefail

# State 016 start script — FDC3 Post-Trade Cash-Leg Payment Transfer
# (TraderX ↔ BankerX). Child state of 014: the runtime baseline is the
# generated 014 Sail runtime; this state's overlay is the spec pack in
# specs/016-post-trade-settlement-bankerx (mock receiver + standalone web
# blotter + acceptance assets).
#
# Modes:
#   (default) Sail runtime mode
#             — generate the 014 baseline (unless TRADERX_SKIP_GENERATE=1),
#               validate this pack's overlay artifacts, start the C3 baseline
#               runtime (k8s provider, --dry-run capable), start the Sail
#               sidecar, and merge the mock-receiver record into the Sail
#               runtime app directory (FR-01608: mock receiver is the default;
#               switching to the BankerX terminal is an appd URL swap).
#   --static  offline acceptance mode
#             — validate the pack and serve it directly (python http.server on
#               $ACCEPT_PORT): blotter + mock receiver on one origin, no
#               cluster needed. See specs/016-.../acceptance/README.md.
#
# Documented --dry-run contract: validate everything and print every runtime
# action without executing it — verifiable from a clean checkout without kind.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi

STATE_ID="016-post-trade-settlement-bankerx"
PACK_DIR="${REPO_ROOT}/specs/${STATE_ID}"
BASE_STATE_ID="014-fdc3-intent-interoperability"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_COMPOSE_FILE="${SAIL_DIR}/docker-compose.yml"
SAIL_PROJECT_NAME="${SAIL_PROJECT_NAME:-traderx-state-016-sail}"
SAIL_HTTP_PORT="${SAIL_HTTP_PORT:-8090}"
SAIL_RUNTIME_APPD="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"
RECEIVER_OVERLAY="${PACK_DIR}/acceptance/sail-receiver-overlay.appd.json"
ACCEPT_PORT="${ACCEPT_PORT:-8090}"

DRY_RUN=0
SKIP_BUILD=0
STATIC_MODE=0
START_SERVER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-016}"

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --static)
      STATIC_MODE=1
      ;;
    --serve)
      STATIC_MODE=1
      START_SERVER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build --static --serve --provider <kind|minikube> --cluster-name <name>"
      exit 1
      ;;
  esac
  shift
done

# ─── 1. Pack artifact validation (both modes) ────────────────────────────────
for required in \
  "${PACK_DIR}/spec.md" \
  "${PACK_DIR}/quickstart.md" \
  "${PACK_DIR}/acceptance-demo.md" \
  "${PACK_DIR}/acceptance/appd.json" \
  "${PACK_DIR}/acceptance/sail-receiver-overlay.appd.json" \
  "${PACK_DIR}/generation/mock-receiver/index.html" \
  "${PACK_DIR}/generation/mock-receiver/payment-lifecycle.mjs" \
  "${PACK_DIR}/generation/mock-receiver/appd/mock-receiver.appd.json" \
  "${PACK_DIR}/generation/mock-receiver/fdc3-client.js" \
  "${PACK_DIR}/generation/traderx-blotter-web/index.html" \
  "${PACK_DIR}/generation/traderx-blotter-web/fdc3-agent.js" \
  "${PACK_DIR}/generation/traderx-blotter-web/payment-lifecycle.mjs"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing state 016 pack artifact: ${required}"
    exit 1
  }
done
echo "[ok] state 016 pack artifacts validated"

if (( STATIC_MODE == 1 )); then
  base_url="http://localhost:${ACCEPT_PORT}"
  echo "[info] offline acceptance mode (FR-01608, Tier 2a): no cluster, no external estate"
  echo "[info] app directory: ${base_url}/acceptance/appd.json"
  if (( DRY_RUN == 1 )); then
    if (( START_SERVER == 1 )); then
      echo "[dry-run] python3 -m http.server ${ACCEPT_PORT} --directory ${PACK_DIR}"
    fi
    echo "[dry-run] open ${base_url}/generation/traderx-blotter-web/index.html?launcher=1&directory=<encoded ${base_url}/acceptance/appd.json>"
    echo "[dry-run] flow: LAUNCH BANKERX → SETTLE (BANKERX) → Acsc → SETTLED (row correlated by UETR)"
    echo "[done] dry run complete for state 016 (static)"
    exit 0
  fi
  echo "[done] state 016 validation complete"
  echo "[hint] serve the pack:  python3 -m http.server ${ACCEPT_PORT} --directory ${PACK_DIR}"
  echo "[hint] open: ${base_url}/generation/traderx-blotter-web/index.html?launcher=1&directory=<url-encoded ${base_url}/acceptance/appd.json>"
  if (( START_SERVER == 1 )); then
    if curl -fsS "${base_url}/acceptance/appd.json" >/dev/null 2>&1; then
      echo "[ready] acceptance server already responding at ${base_url}"
    else
      echo "[start] serving ${PACK_DIR} at ${base_url} (Ctrl+C to stop)"
      exec python3 -m http.server "${ACCEPT_PORT}" --directory "${PACK_DIR}"
    fi
  fi
  exit 0
fi

# ─── 2. Sail runtime mode: generate the 014 baseline ─────────────────────────
if [[ "${TRADERX_SKIP_GENERATE:-0}" != "1" ]]; then
  # 016 is an overlay state: its runtime baseline is the generated 014
  # Sail runtime; the 016 overlay (mock receiver, web blotter, acceptance
  # assets) ships in the pack itself and needs no code generation.
  generate_state_script="${REPO_ROOT}/pipeline/${TRADERX_GENERATE_STATE_SCRIPT_BASENAME:-generate-state.sh}"
  if [[ -f "${generate_state_script}" ]]; then
    bash "${generate_state_script}" "${BASE_STATE_ID}"
  else
    echo "[warn] generation script not found: ${generate_state_script}; continuing with existing artifacts"
  fi
else
  echo "[info] skipping state generation (TRADERX_SKIP_GENERATE=1)"
fi

for required in \
  "${STATE_DIR}/README.md" \
  "${SAIL_COMPOSE_FILE}" \
  "${SAIL_DIR}/bootstrap/run-sail.sh" \
  "${SAIL_DIR}/bootstrap/sail-pin.env" \
  "${SAIL_DIR}/appd/traderx.appd.v2.json"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing generated state 014 baseline artifact: ${required}"
    exit 1
  }
done
echo "[ok] generated 014 baseline runtime artifacts present"

# ─── 3. Delegate the C3 baseline runtime start (dry-run contract preserved) ──
if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found (required for the Sail sidecar)"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required for the Sail sidecar"
  exit 1
fi

start_args=(--provider "${K8S_PROVIDER}" --cluster-name "${KIND_CLUSTER_NAME}")
if (( DRY_RUN == 1 )); then
  start_args+=(--dry-run)
fi
if (( SKIP_BUILD == 1 )); then
  start_args+=(--skip-build)
fi
runtime_scripts_dir="${REPO_ROOT}/scripts"
state_012_start_script="${runtime_scripts_dir}/start-state-012-platform-convergence-c3-generated.sh"
TRADERX_SKIP_GENERATE=1 "${state_012_start_script}" "${start_args[@]}"

# ─── 4. Sail sidecar + receiver overlay merge (FR-01608) ─────────────────────
if (( DRY_RUN == 1 )); then
  echo "[dry-run] docker compose -f ${SAIL_COMPOSE_FILE} --project-name ${SAIL_PROJECT_NAME} up -d"
  echo "[dry-run] bash ${SAIL_DIR}/bootstrap/merge-traderx-appd.sh ${SAIL_RUNTIME_APPD} ${RECEIVER_OVERLAY}"
  echo "[done] dry run complete for state 016"
  exit 0
fi

echo "[start] launching Sail sidecar (${SAIL_PROJECT_NAME})"
docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" up -d

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts=150
  local i
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "[ready] ${name} ${url}"
      return 0
    fi
    sleep 2
  done
  echo "[error] timeout waiting for ${name} at ${url}"
  return 1
}

wait_for_http "sail-ui" "http://localhost:${SAIL_HTTP_PORT}/html/" || exit 1

if [[ -f "${SAIL_RUNTIME_APPD}" ]]; then
  echo "[step] merging the 016 mock-receiver record into the Sail runtime app directory"
  bash "${SAIL_DIR}/bootstrap/merge-traderx-appd.sh" "${SAIL_RUNTIME_APPD}" "${RECEIVER_OVERLAY}"
  echo "[ready] receiver overlay merged (StartPayment → bankerx-clearing-desk/mock receiver)"
else
  echo "[warn] Sail runtime app directory not found yet (overlay not merged): ${SAIL_RUNTIME_APPD}"
fi

echo "[done] state 016 runtime started (baseline 014 + Sail + receiver overlay)"
echo "[ui] TraderX cluster: http://localhost:8080"
echo "[ui] Sail: http://localhost:${SAIL_HTTP_PORT}"
echo "[ui] offline acceptance (static, no cluster): $(basename "$0") --static"
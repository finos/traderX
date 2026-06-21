#!/usr/bin/env bash

if [[ "${TRADERX_K8S_SMOKE_READINESS_LOADED:-0}" == "1" ]]; then
  return 0
fi
export TRADERX_K8S_SMOKE_READINESS_LOADED=1

traderx_k8s_smoke_ready_timeout() {
  if [[ -n "${TRADERX_SMOKE_READY_TIMEOUT:-}" ]]; then
    echo "${TRADERX_SMOKE_READY_TIMEOUT}"
    return 0
  fi

  if [[ "$(uname -m)" == "arm64" && "${TRADERX_USE_PUBLISHED_IMAGES:-0}" == "1" ]]; then
    echo "420"
    return 0
  fi

  echo "240"
}

traderx_k8s_rollout_status_all() {
  local namespace="$1"
  local build_plan="${2:-}"
  local timeout="${3:-${TRADERX_K8S_ROLLOUT_TIMEOUT:-600s}}"
  local deployment
  local deployments=()

  if [[ -n "${build_plan}" && -f "${build_plan}" ]] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r deployment; do
      [[ -z "${deployment}" ]] && continue
      deployments+=("deployment/${deployment}")
    done < <(jq -r '.deployments[]?' "${build_plan}")
  else
    while IFS= read -r deployment; do
      [[ -z "${deployment}" ]] && continue
      deployments+=("${deployment}")
    done < <(kubectl get deployments -n "${namespace}" -o name)
  fi

  for deployment in "${deployments[@]}"; do
    echo "[wait] rollout ${deployment} in namespace ${namespace}"
    kubectl rollout status "${deployment}" -n "${namespace}" --timeout="${timeout}" >/dev/null
  done

  if kubectl get daemonset/promtail -n "${namespace}" >/dev/null 2>&1; then
    echo "[wait] rollout daemonset/promtail in namespace ${namespace}"
    kubectl rollout status daemonset/promtail -n "${namespace}" --timeout="${timeout}" >/dev/null
  fi
}

traderx_http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

traderx_wait_for_traderx_ingress_readiness() {
  local ingress_url="${1%/}"
  local timeout="${2:-$(traderx_k8s_smoke_ready_timeout)}"
  local interval="${TRADERX_SMOKE_READY_INTERVAL:-3}"
  local deadline=$((SECONDS + timeout))
  local i target name url url_and_expected expected code all_ready
  local targets=(
    "edge-health|${ingress_url}/health|200"
    "edge-ui|${ingress_url}/|200"
    "reference-data|${ingress_url}/reference-data/health|200"
    "people-service|${ingress_url}/people-service/People/ValidatePerson?LogonId=user01|200"
    "account-service|${ingress_url}/account-service/actuator/health|200"
    "account-lookup|${ingress_url}/account-service/account/22214|200"
    "position-service|${ingress_url}/position-service/health/ready|200"
    "trade-service|${ingress_url}/trade-service/health|200"
    "trade-processor|${ingress_url}/trade-processor/health|200"
    "price-publisher|${ingress_url}/price-publisher/health|200"
    "order-matcher|${ingress_url}/order-matcher/health|200"
    "grafana|${ingress_url}/grafana/api/health|200"
    "prometheus|${ingress_url}/prometheus/-/ready|200"
  )
  local ready=()
  local last_codes=()

  echo "[wait] application readiness through ingress ${ingress_url} (timeout ${timeout}s)"
  if [[ "$(uname -m)" == "arm64" && "${TRADERX_USE_PUBLISHED_IMAGES:-0}" == "1" ]]; then
    echo "[info] Apple Silicon with published images detected; allowing extended JVM warm-up under emulation"
  fi

  for i in "${!targets[@]}"; do
    ready[$i]=0
    last_codes[$i]="000"
  done

  while (( SECONDS <= deadline )); do
    all_ready=1
    for i in "${!targets[@]}"; do
      if [[ "${ready[$i]}" == "1" ]]; then
        continue
      fi
      target="${targets[$i]}"
      name="${target%%|*}"
      url_and_expected="${target#*|}"
      url="${url_and_expected%|*}"
      expected="${target##*|}"
      code="$(traderx_http_code_for "${url}")"
      last_codes[$i]="${code:-000}"
      if [[ "${code}" == "${expected}" ]]; then
        ready[$i]=1
        echo "[ready] ${name} ${url}"
      else
        all_ready=0
      fi
    done

    if (( all_ready == 1 )); then
      echo "[ready] TraderX ingress service checkoff complete"
      return 0
    fi

    sleep "${interval}"
  done

  echo "[error] timeout waiting for TraderX ingress service readiness"
  for i in "${!targets[@]}"; do
    if [[ "${ready[$i]}" != "1" ]]; then
      target="${targets[$i]}"
      name="${target%%|*}"
      url_and_expected="${target#*|}"
      url="${url_and_expected%|*}"
      expected="${target##*|}"
      echo "[error] not ready: ${name} expected=${expected} last=${last_codes[$i]} url=${url}"
    fi
  done
  return 1
}

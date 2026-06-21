#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
source "${REPO_ROOT}/scripts/lib/kubernetes-smoke-readiness.sh"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
BUILD_PLAN="${GENERATED_ROOT}/code/target-generated/kubernetes-runtime/build-plan.json"
SPEC_FILE="${REPO_ROOT}/specs/010-kubernetes-runtime/system/kubernetes-runtime.spec.json"
RUN_DIR="${GENERATED_ROOT}/code/target-generated/kubernetes-runtime/.run/state-010-kubernetes-runtime"
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-}"
MINIKUBE_PROFILE=""
WAIT_READY=0

while (( "$#" )); do
  case "$1" in
    --wait-ready)
      WAIT_READY=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --wait-ready --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[error] kubectl command not found"
  exit 1
fi

if [[ -f "${BUILD_PLAN}" ]]; then
  cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
  namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
  host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
else
  cluster_name="$(jq -r '.runtime.kind.clusterName' "${SPEC_FILE}")"
  namespace="$(jq -r '.runtime.namespace' "${SPEC_FILE}")"
  host_port="$(jq -r '.runtime.kind.hostPort' "${SPEC_FILE}")"
fi

if [[ -n "${KIND_CLUSTER_NAME}" ]]; then
  cluster_name="${KIND_CLUSTER_NAME}"
fi

if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] kind command not found"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      echo "[info] kind cluster not found: ${cluster_name}"
      exit 0
    fi
    kubectl config use-context "kind-${cluster_name}" >/dev/null
    echo "[info] provider: kind"
    echo "[info] cluster: ${cluster_name}"
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] minikube command not found"
      exit 1
    fi
    if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[info] minikube profile not running: ${MINIKUBE_PROFILE}"
      exit 0
    fi
    if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      kubectl config use-context "minikube" >/dev/null
    fi
    echo "[info] provider: minikube"
    echo "[info] profile: ${MINIKUBE_PROFILE}"
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[info] namespace: ${namespace}"

echo
echo "[status] deployments"
kubectl get deployments -n "${namespace}" || true

echo
echo "[status] pods"
kubectl get pods -n "${namespace}" || true

echo
echo "[status] services"
kubectl get services -n "${namespace}" || true

http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

echo
printf "%-20s %-8s %s\n" "endpoint" "http" "url"
printf "%-20s %-8s %s\n" "--------------------" "--------" "---"
for target in \
  "edge-health|http://localhost:${host_port}/health" \
  "edge-ui|http://localhost:${host_port}/" \
  "grafana|http://localhost:${host_port}/grafana/api/health" \
  "prometheus|http://localhost:${host_port}/prometheus/-/ready" \
  "reference-data|http://localhost:${host_port}/reference-data/health" \
  "account|http://localhost:${host_port}/account-service/account/22214" \
  "position-ready|http://localhost:${host_port}/position-service/health/ready" \
  "trade-service|http://localhost:${host_port}/trade-service/health" \
  "trade-processor|http://localhost:${host_port}/trade-processor/health" \
  "order-matcher|http://localhost:${host_port}/order-matcher/health" \
  "vite-client|http://localhost:${host_port}/@vite/client"; do
  name="${target%%|*}"
  url="${target#*|}"
  code="$(http_code_for "${url}")"
  printf "%-20s %-8s %s\n" "${name}" "${code:-000}" "${url}"
done

if (( WAIT_READY == 1 )); then
  echo
  traderx_wait_for_traderx_ingress_readiness \
    "http://localhost:${host_port}" \
    "$(traderx_k8s_smoke_ready_timeout)"
fi

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  pid="-"
  running="no"
  pid_file="${RUN_DIR}/minikube-port-forward.pid"
  if [[ -f "${pid_file}" ]]; then
    pid="$(cat "${pid_file}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      running="yes"
    fi
  fi
  echo
  printf "%-20s %-10s %-8s\n" "minikube-port-forward" "${pid}" "${running}"
fi

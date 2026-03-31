#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-004-kubernetes"

SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"

while (( "$#" )); do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    --minikube-driver)
      MINIKUBE_DRIVER="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --skip-build --recreate-cluster --provider <kind|minikube> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in docker kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }
[[ -f "${KIND_CONFIG}" ]] || { echo "[error] missing ${KIND_CONFIG}"; exit 1; }
[[ -d "${KUSTOMIZE_DIR}" ]] || { echo "[error] missing ${KUSTOMIZE_DIR}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
edge_service="$(jq -r '.edgeService' "${BUILD_PLAN}")"

if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind|minikube)
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

mkdir -p "${RUN_DIR}"
PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
PORT_FORWARD_LOG_FILE="${RUN_DIR}/minikube-port-forward.log"

stop_minikube_port_forward() {
  if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
    pid="$(cat "${PORT_FORWARD_PID_FILE}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${PORT_FORWARD_PID_FILE}"
  fi
}

if [[ "${K8S_PROVIDER}" == "kind" ]]; then
  if ! command -v kind >/dev/null 2>&1; then
    echo "[error] required command not found: kind"
    exit 1
  fi
  cluster_exists=0
  if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
    cluster_exists=1
  fi
  if (( cluster_exists == 1 && RECREATE_CLUSTER == 1 )); then
    kind delete cluster --name "${cluster_name}"
    cluster_exists=0
  fi
  if (( cluster_exists == 0 )); then
    kind create cluster --name "${cluster_name}" --config "${KIND_CONFIG}"
  fi
  kubectl config use-context "kind-${cluster_name}" >/dev/null
else
  if ! command -v minikube >/dev/null 2>&1; then
    echo "[error] required command not found: minikube"
    exit 1
  fi
  if (( RECREATE_CLUSTER == 1 )); then
    minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
  fi
  minikube start -p "${MINIKUBE_PROFILE}" --driver "${MINIKUBE_DRIVER}" >/dev/null
  if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
    kubectl config use-context "minikube" >/dev/null
  fi
fi

if (( SKIP_BUILD == 0 )); then
  while IFS= read -r item; do
    name="$(jq -r '.name' <<<"${item}")"
    image="$(jq -r '.image' <<<"${item}")"
    context_rel="$(jq -r '.context' <<<"${item}")"
    dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
    context_abs="${ROOT}/${context_rel}"
    dockerfile_abs="${context_abs}/${dockerfile_rel}"

    [[ -d "${context_abs}" ]] || { echo "[error] missing build context ${context_abs}"; exit 1; }
    [[ -f "${dockerfile_abs}" ]] || { echo "[error] missing dockerfile ${dockerfile_abs}"; exit 1; }

    echo "[build] ${name} -> ${image}"
    docker build -t "${image}" -f "${dockerfile_abs}" "${context_abs}"
    if [[ "${K8S_PROVIDER}" == "kind" ]]; then
      kind load docker-image "${image}" --name "${cluster_name}"
    else
      minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
    fi
  done < <(jq -c '.images[]' "${BUILD_PLAN}")
fi

kubectl apply -k "${KUSTOMIZE_DIR}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  stop_minikube_port_forward
  nohup kubectl -n "${namespace}" port-forward "svc/${edge_service}" "${host_port}:8080" >"${PORT_FORWARD_LOG_FILE}" 2>&1 &
  echo "$!" > "${PORT_FORWARD_PID_FILE}"
fi

echo "[done] state 004 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
echo "[ui] http://localhost:${host_port}"

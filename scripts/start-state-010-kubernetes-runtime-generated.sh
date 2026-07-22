#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-010-kubernetes-runtime"

SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
USE_PUBLISHED_IMAGES="${TRADERX_USE_PUBLISHED_IMAGES:-0}"
PUBLISHED_REGISTRY="${TRADERX_PUBLISHED_REGISTRY:-ghcr.io/finos}"
PUBLISHED_NAMESPACE="${TRADERX_PUBLISHED_NAMESPACE:-}"
PUBLISHED_TAG="${TRADERX_PUBLISHED_TAG:-latest}"

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
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
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
    --use-published-images)
      USE_PUBLISHED_IMAGES=1
      ;;
    --published-registry)
      PUBLISHED_REGISTRY="${2:-}"
      shift
      ;;
    --published-namespace)
      PUBLISHED_NAMESPACE="${2:-}"
      shift
      ;;
    --published-tag)
      PUBLISHED_TAG="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --skip-build --recreate-cluster --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name> --use-published-images --published-registry <registry> --published-namespace <namespace> --published-tag <tag>"
      exit 1
      ;;
  esac
  shift
done

if (( USE_PUBLISHED_IMAGES == 1 )); then
  SKIP_BUILD=1
  if [[ -z "${PUBLISHED_NAMESPACE}" ]]; then
    echo "[error] published image mode requires namespace"
    echo "[hint] set --published-namespace <name> or TRADERX_PUBLISHED_NAMESPACE=<name>"
    exit 1
  fi
fi

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

if [[ -n "${KIND_CLUSTER_NAME}" ]]; then
  cluster_name="${KIND_CLUSTER_NAME}"
fi

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

while IFS= read -r item; do
  name="$(jq -r '.name' <<<"${item}")"
  image="$(jq -r '.image' <<<"${item}")"
  if (( USE_PUBLISHED_IMAGES == 1 )); then
    published_image="${PUBLISHED_REGISTRY}/${PUBLISHED_NAMESPACE}/${name}:${PUBLISHED_TAG}"
    echo "[pull] ${name} <- ${published_image}"
    docker pull "${published_image}"
    docker tag "${published_image}" "${image}"
  elif (( SKIP_BUILD == 0 )); then
    context_rel="$(jq -r '.context' <<<"${item}")"
    dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
    context_abs="${ROOT}/${context_rel}"
    dockerfile_abs="${context_abs}/${dockerfile_rel}"

    [[ -d "${context_abs}" ]] || { echo "[error] missing build context ${context_abs}"; exit 1; }
    [[ -f "${dockerfile_abs}" ]] || { echo "[error] missing dockerfile ${dockerfile_abs}"; exit 1; }

    echo "[build] ${name} -> ${image}"
    docker build -t "${image}" -f "${dockerfile_abs}" "${context_abs}"
  else
    docker image inspect "${image}" >/dev/null 2>&1 || {
      echo "[error] --skip-build was set, but local image is missing: ${image}"
      echo "[hint] rerun without --skip-build to build images first."
      exit 1
    }
    echo "[reuse] using local image ${image} (--skip-build)"
  fi

  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    kind load docker-image "${image}" --name "${cluster_name}"
  else
    minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
  fi
done < <(jq -c '.images[]' "${BUILD_PLAN}")

kubectl apply -k "${KUSTOMIZE_DIR}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  stop_minikube_port_forward
  nohup kubectl -n "${namespace}" port-forward "svc/${edge_service}" "${host_port}:8080" >"${PORT_FORWARD_LOG_FILE}" 2>&1 &
  echo "$!" > "${PORT_FORWARD_PID_FILE}"
fi

echo "[done] state 010 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
if (( USE_PUBLISHED_IMAGES == 1 )); then
  echo "[images] published namespace=${PUBLISHED_NAMESPACE} tag=${PUBLISHED_TAG}"
fi
echo "[ui] http://localhost:${host_port}"
echo "[api-explorer] http://localhost:${host_port}/api/docs"

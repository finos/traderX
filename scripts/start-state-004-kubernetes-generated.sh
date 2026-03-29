#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="004-kubernetes-runtime"
STATE_DIR="${REPO_ROOT}/generated/code/target-generated/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-004-kubernetes"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
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
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --provider <kind|minikube> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  echo "[error] required command not found: jq"
  exit 1
fi

bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

[[ -f "${BUILD_PLAN}" ]] || {
  echo "[error] missing build plan: ${BUILD_PLAN}"
  exit 1
}

[[ -f "${KIND_CONFIG}" ]] || {
  echo "[error] missing kind config: ${KIND_CONFIG}"
  exit 1
}

[[ -d "${KUSTOMIZE_DIR}" ]] || {
  echo "[error] missing kustomize dir: ${KUSTOMIZE_DIR}"
  exit 1
}

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
      echo "[stop] minikube edge port-forward (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${PORT_FORWARD_PID_FILE}"
  fi
}

if (( DRY_RUN == 1 )); then
  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    echo "[dry-run] kind get clusters | grep -Fx '${cluster_name}' || kind create cluster --name '${cluster_name}' --config '${KIND_CONFIG}'"
  else
    echo "[dry-run] minikube status -p '${MINIKUBE_PROFILE}' || minikube start -p '${MINIKUBE_PROFILE}' --driver '${MINIKUBE_DRIVER}'"
  fi
  if (( SKIP_BUILD == 0 )); then
    while IFS= read -r item; do
      name="$(jq -r '.name' <<<"${item}")"
      image="$(jq -r '.image' <<<"${item}")"
      context_rel="$(jq -r '.context' <<<"${item}")"
      dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
      echo "[dry-run] docker build -t ${image} -f ${REPO_ROOT}/generated/code/target-generated/${context_rel}/${dockerfile_rel} ${REPO_ROOT}/generated/code/target-generated/${context_rel}  # ${name}"
      if [[ "${K8S_PROVIDER}" == "kind" ]]; then
        echo "[dry-run] kind load docker-image ${image} --name ${cluster_name}"
      else
        echo "[dry-run] minikube image load ${image} -p ${MINIKUBE_PROFILE}"
      fi
    done < <(jq -c '.images[]' "${BUILD_PLAN}")
  else
    echo "[dry-run] skipping image build/load (--skip-build)"
  fi
  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    echo "[dry-run] kubectl config use-context kind-${cluster_name}"
  else
    echo "[dry-run] kubectl config use-context ${MINIKUBE_PROFILE}  # falls back to minikube context if needed"
    echo "[dry-run] kubectl -n ${namespace} port-forward svc/${edge_service} ${host_port}:8080"
  fi
  echo "[dry-run] kubectl apply -k ${KUSTOMIZE_DIR}"
  echo "[done] dry run complete for state 004"
  exit 0
fi

for cmd in docker kubectl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

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
    echo "[info] deleting existing cluster ${cluster_name} (--recreate-cluster)"
    kind delete cluster --name "${cluster_name}"
    cluster_exists=0
  fi

  if (( cluster_exists == 0 )); then
    echo "[start] creating kind cluster ${cluster_name}"
    kind create cluster --name "${cluster_name}" --config "${KIND_CONFIG}"
  else
    echo "[info] using existing kind cluster ${cluster_name}"
  fi

  kubectl config use-context "kind-${cluster_name}" >/dev/null
else
  if ! command -v minikube >/dev/null 2>&1; then
    echo "[error] required command not found: minikube"
    exit 1
  fi

  minikube_running=0
  if minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
    minikube_running=1
  fi

  if (( minikube_running == 1 && RECREATE_CLUSTER == 1 )); then
    echo "[info] deleting existing minikube profile ${MINIKUBE_PROFILE} (--recreate-cluster)"
    minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null
    minikube_running=0
  fi

  if (( minikube_running == 0 )); then
    echo "[start] starting minikube profile ${MINIKUBE_PROFILE}"
    minikube start -p "${MINIKUBE_PROFILE}" --driver "${MINIKUBE_DRIVER}"
  else
    echo "[info] using existing minikube profile ${MINIKUBE_PROFILE}"
  fi

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
    context_abs="${REPO_ROOT}/generated/code/target-generated/${context_rel}"
    dockerfile_abs="${context_abs}/${dockerfile_rel}"

    [[ -d "${context_abs}" ]] || {
      echo "[error] build context not found for ${name}: ${context_abs}"
      exit 1
    }
    [[ -f "${dockerfile_abs}" ]] || {
      echo "[error] dockerfile not found for ${name}: ${dockerfile_abs}"
      exit 1
    }

    echo "[build] ${name} -> ${image}"
    docker build -t "${image}" -f "${dockerfile_abs}" "${context_abs}"
    if [[ "${K8S_PROVIDER}" == "kind" ]]; then
      echo "[load] ${image} into kind/${cluster_name}"
      kind load docker-image "${image}" --name "${cluster_name}"
    else
      echo "[load] ${image} into minikube/${MINIKUBE_PROFILE}"
      minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
    fi
  done < <(jq -c '.images[]' "${BUILD_PLAN}")
else
  echo "[info] skipping image build/load (--skip-build)"
fi

echo "[apply] kubernetes manifests"
kubectl apply -k "${KUSTOMIZE_DIR}"

echo "[wait] deployments available in namespace ${namespace}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  stop_minikube_port_forward
  echo "[start] edge service port-forward localhost:${host_port} -> ${edge_service}:8080"
  nohup kubectl -n "${namespace}" port-forward "svc/${edge_service}" "${host_port}:8080" >"${PORT_FORWARD_LOG_FILE}" 2>&1 &
  echo "$!" > "${PORT_FORWARD_PID_FILE}"
fi

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts=90
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

wait_for_http "edge-health" "http://localhost:${host_port}/health"
wait_for_http "edge-ui" "http://localhost:${host_port}/"

echo "[done] state 004 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
echo "[ui] http://localhost:${host_port}"

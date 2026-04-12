#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
STATE_ID="010-kubernetes-runtime"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-010-kubernetes-runtime"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
SKIP_GENERATE=0
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
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --skip-generate)
      SKIP_GENERATE=1
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
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --skip-generate --use-published-images --published-registry <registry> --published-namespace <namespace> --published-tag <tag> --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

if [[ "${TRADERX_SKIP_GENERATE:-0}" == "1" ]]; then
  SKIP_GENERATE=1
fi

if (( USE_PUBLISHED_IMAGES == 1 )); then
  SKIP_BUILD=1
  if [[ -z "${PUBLISHED_NAMESPACE}" ]]; then
    echo "[error] published image mode requires namespace"
    echo "[hint] set --published-namespace <name> or TRADERX_PUBLISHED_NAMESPACE=<name>"
    exit 1
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[error] required command not found: jq"
  exit 1
fi

if (( SKIP_GENERATE == 0 )); then
  bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
else
  echo "[info] skipping state generation for ${STATE_ID} (--skip-generate)"
fi

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
  if (( USE_PUBLISHED_IMAGES == 1 )); then
    while IFS= read -r item; do
      name="$(jq -r '.name' <<<"${item}")"
      image="$(jq -r '.image' <<<"${item}")"
      published_image="${PUBLISHED_REGISTRY}/${PUBLISHED_NAMESPACE}/${name}:${PUBLISHED_TAG}"
      echo "[dry-run] docker pull ${published_image}  # ${name}"
      echo "[dry-run] docker tag ${published_image} ${image}"
      if [[ "${K8S_PROVIDER}" == "kind" ]]; then
        echo "[dry-run] kind load docker-image ${image} --name ${cluster_name}"
      else
        echo "[dry-run] minikube image load ${image} -p ${MINIKUBE_PROFILE}"
      fi
    done < <(jq -c '.images[]' "${BUILD_PLAN}")
  elif (( SKIP_BUILD == 0 )); then
    while IFS= read -r item; do
      name="$(jq -r '.name' <<<"${item}")"
      image="$(jq -r '.image' <<<"${item}")"
      context_rel="$(jq -r '.context' <<<"${item}")"
      dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
      echo "[dry-run] docker build -t ${image} -f ${GENERATED_ROOT}/code/target-generated/${context_rel}/${dockerfile_rel} ${GENERATED_ROOT}/code/target-generated/${context_rel}  # ${name}"
      if [[ "${K8S_PROVIDER}" == "kind" ]]; then
        echo "[dry-run] kind load docker-image ${image} --name ${cluster_name}"
      else
        echo "[dry-run] minikube image load ${image} -p ${MINIKUBE_PROFILE}"
      fi
    done < <(jq -c '.images[]' "${BUILD_PLAN}")
  else
    echo "[dry-run] skipping docker build (--skip-build); will load existing local images into cluster"
    while IFS= read -r item; do
      image="$(jq -r '.image' <<<"${item}")"
      if [[ "${K8S_PROVIDER}" == "kind" ]]; then
        echo "[dry-run] kind load docker-image ${image} --name ${cluster_name}"
      else
        echo "[dry-run] minikube image load ${image} -p ${MINIKUBE_PROFILE}"
      fi
    done < <(jq -c '.images[]' "${BUILD_PLAN}")
  fi
  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    echo "[dry-run] kubectl config use-context kind-${cluster_name}"
  else
    echo "[dry-run] kubectl config use-context ${MINIKUBE_PROFILE}  # falls back to minikube context if needed"
    echo "[dry-run] kubectl -n ${namespace} port-forward svc/${edge_service} ${host_port}:8080"
  fi
  echo "[dry-run] kubectl apply -k ${KUSTOMIZE_DIR}"
  while IFS= read -r deployment; do
    echo "[dry-run] kubectl rollout restart deployment/${deployment} -n ${namespace}"
  done < <(jq -r '.deployments[]' "${BUILD_PLAN}")
  echo "[dry-run] kubectl rollout restart daemonset/promtail -n ${namespace}  # if present"
  echo "[done] dry run complete for state 010"
  exit 0
fi

for cmd in docker kubectl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

if [[ -z "${DOCKER_BUILDKIT:-}" ]]; then
  export DOCKER_BUILDKIT=1
  echo "[info] DOCKER_BUILDKIT not set; defaulting to 1 for Docker cache mounts"
fi

if [[ "${K8S_PROVIDER}" == "kind" ]]; then
  if ! command -v kind >/dev/null 2>&1; then
    echo "[error] required command not found: kind"
    exit 1
  fi

  cluster_exists=0
  if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
    cluster_exists=1
  fi

  cluster_running=0
  if (( cluster_exists == 1 )); then
    if docker ps --format '{{.Names}}' | grep -Fx "${cluster_name}-control-plane" >/dev/null 2>&1; then
      cluster_running=1
    fi
  fi

  if (( cluster_exists == 1 && cluster_running == 0 )); then
    echo "[info] kind cluster entry exists but control-plane is not running; recreating ${cluster_name}"
    kind delete cluster --name "${cluster_name}" >/dev/null 2>&1 || true
    cluster_exists=0
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
    context_abs="${GENERATED_ROOT}/code/target-generated/${context_rel}"
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
  else
    docker image inspect "${image}" >/dev/null 2>&1 || {
      echo "[error] --skip-build was set, but local image is missing: ${image}"
      echo "[hint] rerun without --skip-build to build images first."
      exit 1
    }
    echo "[reuse] using local image ${image} (--skip-build)"
  fi

  if [[ "${K8S_PROVIDER}" == "kind" ]]; then
    echo "[load] ${image} into kind/${cluster_name}"
    kind load docker-image "${image}" --name "${cluster_name}"
  else
    echo "[load] ${image} into minikube/${MINIKUBE_PROFILE}"
    minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
  fi
done < <(jq -c '.images[]' "${BUILD_PLAN}")

if (( USE_PUBLISHED_IMAGES == 1 )); then
  echo "[info] pulled and retagged published images from ${PUBLISHED_REGISTRY}/${PUBLISHED_NAMESPACE}:${PUBLISHED_TAG}"
elif (( SKIP_BUILD == 1 )); then
  echo "[info] skipped docker build and loaded existing local images (--skip-build)"
else
  echo "[info] built and loaded images"
fi

echo "[apply] kubernetes manifests"
kubectl apply -k "${KUSTOMIZE_DIR}"

echo "[restart] rolling deployments to pick freshly loaded images"
while IFS= read -r deployment; do
  kubectl rollout restart "deployment/${deployment}" -n "${namespace}" >/dev/null
done < <(jq -r '.deployments[]' "${BUILD_PLAN}")

if kubectl get daemonset/promtail -n "${namespace}" >/dev/null 2>&1; then
  echo "[restart] rolling daemonset/promtail to refresh mounted config"
  kubectl rollout restart daemonset/promtail -n "${namespace}" >/dev/null
fi

echo "[wait] deployments available in namespace ${namespace}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s
if kubectl get daemonset/promtail -n "${namespace}" >/dev/null 2>&1; then
  kubectl rollout status daemonset/promtail -n "${namespace}" --timeout=300s >/dev/null
fi

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
wait_for_http "grafana-health" "http://localhost:${host_port}/grafana/api/health"
wait_for_http "prometheus-ready" "http://localhost:${host_port}/prometheus/-/ready"

echo "[done] state 010 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
if (( USE_PUBLISHED_IMAGES == 1 )); then
  echo "[images] published namespace=${PUBLISHED_NAMESPACE} tag=${PUBLISHED_TAG}"
fi
echo "[ui] http://localhost:${host_port}"
echo "[api-explorer] http://localhost:${host_port}/api/docs"
echo "[grafana] http://localhost:${host_port}/grafana (local login credentials)"
echo "[prometheus] http://localhost:${host_port}/prometheus"

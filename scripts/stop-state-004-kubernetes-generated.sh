#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${REPO_ROOT}/generated/code/target-generated/kubernetes-runtime/build-plan.json"
SPEC_FILE="${REPO_ROOT}/specs/004-kubernetes-runtime/system/kubernetes-runtime.spec.json"
RUN_DIR="${REPO_ROOT}/generated/code/target-generated/kubernetes-runtime/.run/state-004-kubernetes"

DELETE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --delete-cluster --provider <kind|minikube> --minikube-profile <name>"
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
else
  cluster_name="$(jq -r '.runtime.kind.clusterName' "${SPEC_FILE}")"
  namespace="$(jq -r '.runtime.namespace' "${SPEC_FILE}")"
fi

if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
  pid="$(cat "${PORT_FORWARD_PID_FILE}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    echo "[stop] minikube edge port-forward (pid ${pid})"
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${PORT_FORWARD_PID_FILE}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] kind command not found"
      exit 1
    fi
    if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1 || true
      echo "[stop] deleting namespace ${namespace}"
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    else
      echo "[info] kind cluster not present: ${cluster_name}"
    fi

    if (( DELETE_CLUSTER == 1 )); then
      echo "[stop] deleting kind cluster ${cluster_name}"
      kind delete cluster --name "${cluster_name}"
    fi
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] minikube command not found"
      exit 1
    fi
    if minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
        kubectl config use-context "minikube" >/dev/null 2>&1 || true
      fi
      echo "[stop] deleting namespace ${namespace}"
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    else
      echo "[info] minikube profile not running: ${MINIKUBE_PROFILE}"
    fi

    if (( DELETE_CLUSTER == 1 )); then
      echo "[stop] deleting minikube profile ${MINIKUBE_PROFILE}"
      minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null || true
    fi
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[done] state 004 stop sequence complete"

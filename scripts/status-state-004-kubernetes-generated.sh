#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${ROOT}/kubernetes-runtime/build-plan.json"
RUN_DIR="${ROOT}/kubernetes-runtime/.run/state-004-kubernetes"
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
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
      echo "[hint] supported: --provider <kind|minikube> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in kubectl jq curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] required command not found: kind"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      echo "[info] kind cluster not found: ${cluster_name}"
      exit 0
    fi
    kubectl config use-context "kind-${cluster_name}" >/dev/null
    echo "[info] provider: kind"
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] required command not found: minikube"
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
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[info] cluster/profile: ${cluster_name}"
kubectl get deployments -n "${namespace}" || true
kubectl get pods -n "${namespace}" || true
kubectl get services -n "${namespace}" || true

echo "[status] edge-health $(curl -sS -o /dev/null -w "%{http_code}" "http://localhost:${host_port}/health" 2>/dev/null || true)"

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
  echo "[status] minikube-port-forward pid=${pid} running=${running}"
fi

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INGRESS_URL="${1:-http://localhost:8080}"
NAMESPACE="${2:-traderx}"
K8S_PROVIDER="${3:-${K8S_PROVIDER:-kind}}"
MINIKUBE_PROFILE="${4:-${MINIKUBE_PROFILE:-traderx-state-004}}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[error] kubectl command not found"
  exit 1
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] kind command not found"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[error] expected kind cluster not found: ${MINIKUBE_PROFILE}"
      exit 1
    fi
    kubectl config use-context "kind-${MINIKUBE_PROFILE}" >/dev/null
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] minikube command not found"
      exit 1
    fi
    if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[error] expected minikube profile not running: ${MINIKUBE_PROFILE}"
      exit 1
    fi
    if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      kubectl config use-context "minikube" >/dev/null
    fi
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[check] kubernetes deployments available in namespace ${NAMESPACE}"
kubectl get deployments -n "${NAMESPACE}"
kubectl wait --for=condition=Available deployment --all -n "${NAMESPACE}" --timeout=180s >/dev/null

echo "[check] edge health endpoint"
health_headers="$(curl -sS -i "${INGRESS_URL}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/health"
  exit 1
}

echo "[check] edge account-service path"
account_headers="$(curl -sS -i "${INGRESS_URL}/account-service/account/22214" | sed -n '1,25p')"
echo "${account_headers}"
printf '%s\n' "${account_headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/account-service/account/22214"
  exit 1
}

echo "[check] state 004 ingress-routed service smoke suite"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/reference-data"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/account-service"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/people-service" "${INGRESS_URL}/account-service/accountuser/"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/position-service"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/trade-service" "${INGRESS_URL}/position-service"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 004 kubernetes runtime smoke tests passed"

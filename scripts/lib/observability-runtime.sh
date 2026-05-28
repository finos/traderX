#!/usr/bin/env bash

traderx_state_number_from_id() {
  local state_id="$1"
  if [[ "${state_id}" =~ ^([0-9]{3})- ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

traderx_detect_docker_server_api_version() {
  docker version --format '{{.Server.APIVersion}}' 2>/dev/null || true
}

traderx_configure_observability_runtime() {
  local state_id="$1"
  local state_number
  local detected_api_version

  state_number="$(traderx_state_number_from_id "${state_id}")" || {
    echo "[error] unable to derive state number from ${state_id}"
    return 1
  }

  export TRADERX_GRAFANA_ADMIN_USER="${TRADERX_GRAFANA_ADMIN_USER:-traderx-admin}"
  export TRADERX_GRAFANA_ADMIN_PASSWORD="${TRADERX_GRAFANA_ADMIN_PASSWORD:-traderx-state-${state_number}}"
  export TRADERX_GRAFANA_ANONYMOUS_ENABLED="${TRADERX_GRAFANA_ANONYMOUS_ENABLED:-true}"
  export TRADERX_GRAFANA_ANONYMOUS_ORG_ROLE="${TRADERX_GRAFANA_ANONYMOUS_ORG_ROLE:-Viewer}"
  export TRADERX_GRAFANA_ROOT_URL="${TRADERX_GRAFANA_ROOT_URL:-%(protocol)s://%(domain)s/grafana/}"

  if [[ -z "${TRADERX_PROMTAIL_DOCKER_API_VERSION:-}" ]]; then
    detected_api_version="$(traderx_detect_docker_server_api_version)"
    export TRADERX_PROMTAIL_DOCKER_API_VERSION="${detected_api_version:-1.44}"
  fi
}

traderx_print_observability_runtime_summary() {
  echo "[grafana] anonymous dashboards: ${TRADERX_GRAFANA_ANONYMOUS_ENABLED:-true} (${TRADERX_GRAFANA_ANONYMOUS_ORG_ROLE:-Viewer})"
  echo "[grafana-admin] user=${TRADERX_GRAFANA_ADMIN_USER:-traderx-admin} password=${TRADERX_GRAFANA_ADMIN_PASSWORD:-}"
  echo "[promtail] docker API version=${TRADERX_PROMTAIL_DOCKER_API_VERSION:-1.44}"
}

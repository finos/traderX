#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/dependency-targets.sh"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/kubernetes-runtime"
MANIFEST_DIR="${STATE_DIR}/manifests/base"
SPEC_SOURCE_JSON="${ROOT}/specs/010-kubernetes-runtime/system/kubernetes-runtime.spec.json"
SPEC_JSON="$(mktemp)"
NGINX_CONF="${ROOT}/specs/010-kubernetes-runtime/system/nginx-edge.conf"
SQL_SOURCE="${TARGET_ROOT}/postgres-database-replacement/postgres-init/initialSchema.sql"
NATS_CONF_SOURCE="${TARGET_ROOT}/pricing-awareness-market-data/nats/nats.conf"
OBS_SOURCE_DIR="${TARGET_ROOT}/order-management-matcher/observability"
PROMETHEUS_SOURCE="${OBS_SOURCE_DIR}/prometheus/prometheus.yml"
BLACKBOX_SOURCE="${OBS_SOURCE_DIR}/blackbox/blackbox.yml"
LOKI_SOURCE="${OBS_SOURCE_DIR}/loki/config.yaml"
TEMPO_SOURCE="${OBS_SOURCE_DIR}/tempo/config.yaml"
OTEL_SOURCE="${OBS_SOURCE_DIR}/otel-collector/config.yaml"
GRAFANA_DATASOURCES_SOURCE="${OBS_SOURCE_DIR}/grafana/provisioning/datasources/datasources.yaml"
GRAFANA_DASHBOARD_PROVIDER_SOURCE="${OBS_SOURCE_DIR}/grafana/provisioning/dashboards/dashboards.yaml"
GRAFANA_DASHBOARDS_DIR="${OBS_SOURCE_DIR}/grafana/dashboards"
LOG_COMPOSE_PROJECT_LABEL="traderx-state-009"

trap 'rm -f "${SPEC_JSON}"' EXIT

for required in \
  "${SPEC_SOURCE_JSON}" \
  "${NGINX_CONF}" \
  "${SQL_SOURCE}" \
  "${NATS_CONF_SOURCE}" \
  "${PROMETHEUS_SOURCE}" \
  "${BLACKBOX_SOURCE}" \
  "${LOKI_SOURCE}" \
  "${TEMPO_SOURCE}" \
  "${OTEL_SOURCE}" \
  "${GRAFANA_DATASOURCES_SOURCE}" \
  "${GRAFANA_DASHBOARD_PROVIDER_SOURCE}" \
  "${GRAFANA_DASHBOARDS_DIR}"; do
  [[ -f "${required}" ]] || {
    if [[ -d "${required}" ]]; then
      continue
    fi
    echo "[fail] required file missing for state 010 render: ${required}"
    exit 1
  }
done

jq --arg image "$(traderx_docker_image_ref "${ROOT}" "nats")" \
  '(.components[] | select(.name == "nats-broker") | .image) = $image' \
  "${SPEC_SOURCE_JSON}" > "${SPEC_JSON}"

dashboard_count="$(find "${GRAFANA_DASHBOARDS_DIR}" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
if [[ "${dashboard_count}" == "0" ]]; then
  echo "[fail] no Grafana dashboards found at ${GRAFANA_DASHBOARDS_DIR}"
  exit 1
fi

patch_web_frontend_env_for_ingress() {
  local env_dir="${TARGET_ROOT}/web-front-end/angular/main/environments"
  local env_file=""

  [[ -d "${env_dir}" ]] || return 0

  for env_file in "${env_dir}/environment.ts" "${env_dir}/environment.prod.ts"; do
    [[ -f "${env_file}" ]] || continue
    perl -0pi -e 's#accountUrl:\s*`[^`]*`#accountUrl:         `/account-service`#g' "${env_file}"
    perl -0pi -e 's#refrenceDataUrl:\s*`[^`]*`#refrenceDataUrl:    `/reference-data`#g' "${env_file}"
    perl -0pi -e 's#tradesUrl:\s*`[^`]*`#tradesUrl:          `/trade-service/trade/`#g' "${env_file}"
    perl -0pi -e 's#positionsUrl:\s*`[^`]*`#positionsUrl:       `/position-service`#g' "${env_file}"
    perl -0pi -e 's#peopleUrl:\s*`[^`]*`#peopleUrl:          `/people-service`#g' "${env_file}"
    perl -0pi -e 's#orderMatcherUrl:\s*`[^`]*`#orderMatcherUrl:    `/order-matcher`#g' "${env_file}"
  done
  echo "[info] patched web-front-end angular environments for ingress-routed APIs"
}

patch_web_frontend_env_for_ingress

rm -rf "${STATE_DIR}"
mkdir -p "${MANIFEST_DIR}" "${STATE_DIR}/kind" "${STATE_DIR}/spec-source"

cp "${SPEC_JSON}" "${STATE_DIR}/spec-source/kubernetes-runtime.spec.json"
cp "${NGINX_CONF}" "${STATE_DIR}/spec-source/nginx-edge.conf"

cat > "${STATE_DIR}/README.md" <<'EOF'
# State 010 Kubernetes Runtime Artifacts

Generated from:

- `specs/010-kubernetes-runtime/system/kubernetes-runtime.spec.json`
- `specs/010-kubernetes-runtime/system/nginx-edge.conf`

Artifacts:

- Kind cluster config: `kind/cluster-config.yaml`
- K8s manifests: `manifests/base`
- Image build plan: `build-plan.json`
- Observability assets: Prometheus + Grafana + Loki + Tempo + OpenTelemetry + blackbox exporter

Run:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
```

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- API Explorer: `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana`
- Prometheus: `http://localhost:8080/prometheus`
EOF

jq '{
  stateId: "010-kubernetes-runtime",
  namespace: .runtime.namespace,
  kindClusterName: .runtime.kind.clusterName,
  hostPort: .runtime.kind.hostPort,
  nodePort: .runtime.kind.nodePort,
  edgeService: .runtime.edge.serviceName,
  images: [.components[] | select(has("build")) | {
    name,
    image,
    context: .build.context,
    dockerfile: .build.dockerfile
  }],
  deployments: (([.components[].name] + [.runtime.edge.serviceName]) + [
    "blackbox-exporter",
    "loki",
    "tempo",
    "otel-collector",
    "prometheus",
    "grafana"
  ])
}' "${SPEC_JSON}" > "${STATE_DIR}/build-plan.json"

KIND_CLUSTER_NAME="$(jq -r '.runtime.kind.clusterName' "${SPEC_JSON}")"
NODE_PORT="$(jq -r '.runtime.kind.nodePort' "${SPEC_JSON}")"
HOST_PORT="$(jq -r '.runtime.kind.hostPort' "${SPEC_JSON}")"

cat > "${STATE_DIR}/kind/cluster-config.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${KIND_CLUSTER_NAME}
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: ${NODE_PORT}
        hostPort: ${HOST_PORT}
        protocol: TCP
EOF

NAMESPACE="$(jq -r '.runtime.namespace' "${SPEC_JSON}")"
EDGE_NAME="$(jq -r '.runtime.edge.serviceName' "${SPEC_JSON}")"
EDGE_IMAGE="$(jq -r '.runtime.edge.image' "${SPEC_JSON}")"
EDGE_PORT="$(jq -r '.runtime.edge.containerPort' "${SPEC_JSON}")"
NODE_PORT="$(jq -r '.runtime.kind.nodePort' "${SPEC_JSON}")"

cat > "${MANIFEST_DIR}/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: edge-proxy-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  default.conf: |"
  sed 's/^/    /' "${NGINX_CONF}"
} > "${MANIFEST_DIR}/edge-proxy-configmap.yaml"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: database-init-sql"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  001-initialSchema.sql: |"
  sed 's/^/    /' "${SQL_SOURCE}"
} > "${MANIFEST_DIR}/database-init-configmap.yaml"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: nats-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  nats.conf: |"
  sed 's/^/    /' "${NATS_CONF_SOURCE}"
} > "${MANIFEST_DIR}/nats-configmap.yaml"

PROMETHEUS_RENDER_SOURCE="$(mktemp)"
sed 's#http://ingress:8080#http://edge-proxy:8080#g' "${PROMETHEUS_SOURCE}" > "${PROMETHEUS_RENDER_SOURCE}"
# Prometheus is served behind /prometheus in state 010+, so self-scrape path must include the prefix.
if ! rg -q 'metrics_path:\s*/prometheus/metrics' "${PROMETHEUS_RENDER_SOURCE}"; then
  perl -0pi -e 's/(^\s*-\sjob_name:\sprometheus\n)/$1    metrics_path: \/prometheus\/metrics\n/m' "${PROMETHEUS_RENDER_SOURCE}"
fi
{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-prometheus-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  prometheus.yml: |"
  sed 's/^/    /' "${PROMETHEUS_RENDER_SOURCE}"
} > "${MANIFEST_DIR}/observability-prometheus-configmap.yaml"
rm -f "${PROMETHEUS_RENDER_SOURCE}"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-blackbox-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  blackbox.yml: |"
  sed 's/^/    /' "${BLACKBOX_SOURCE}"
} > "${MANIFEST_DIR}/observability-blackbox-configmap.yaml"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-loki-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  config.yaml: |"
  sed 's/^/    /' "${LOKI_SOURCE}"
} > "${MANIFEST_DIR}/observability-loki-configmap.yaml"

cat > "${MANIFEST_DIR}/observability-promtail-configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: observability-promtail-config
  namespace: ${NAMESPACE}
data:
  config.yaml: |
    server:
      http_listen_port: 3101
      grpc_listen_port: 0

    positions:
      filename: /run/promtail/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: traderx-pod-logs
        pipeline_stages:
          - cri: {}
          - regex:
              source: filename
              expression: '/var/log/pods/(?P<namespace>[^_]+)_(?P<pod>[^_]+)_(?P<pod_uid>[^/]+)/(?P<service>[^/]+)/.*'
          - labels:
              namespace:
              pod:
              service:
        static_configs:
          - targets: [localhost]
            labels:
              compose_project: ${LOG_COMPOSE_PROJECT_LABEL}
              job: traderx-docker
              __path__: /var/log/pods/${NAMESPACE}_*/*/*.log
EOF

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-tempo-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  config.yaml: |"
  sed 's/^/    /' "${TEMPO_SOURCE}"
} > "${MANIFEST_DIR}/observability-tempo-configmap.yaml"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-otel-collector-config"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  config.yaml: |"
  sed 's/^/    /' "${OTEL_SOURCE}"
} > "${MANIFEST_DIR}/observability-otel-configmap.yaml"

GRAFANA_DATASOURCES_RENDER_SOURCE="$(mktemp)"
cp "${GRAFANA_DATASOURCES_SOURCE}" "${GRAFANA_DATASOURCES_RENDER_SOURCE}"
# Grafana runs in-cluster and must query Prometheus through its configured route prefix.
perl -0pi -e 's#url:\s*http://prometheus:9090\b#url: http://prometheus:9090/prometheus#g' "${GRAFANA_DATASOURCES_RENDER_SOURCE}"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-grafana-datasources"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  datasources.yaml: |"
  sed 's/^/    /' "${GRAFANA_DATASOURCES_RENDER_SOURCE}"
} > "${MANIFEST_DIR}/observability-grafana-datasources-configmap.yaml"
rm -f "${GRAFANA_DATASOURCES_RENDER_SOURCE}"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-grafana-dashboard-providers"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  echo "  dashboards.yaml: |"
  sed 's/^/    /' "${GRAFANA_DASHBOARD_PROVIDER_SOURCE}"
} > "${MANIFEST_DIR}/observability-grafana-dashboard-providers-configmap.yaml"

{
  echo "apiVersion: v1"
  echo "kind: ConfigMap"
  echo "metadata:"
  echo "  name: observability-grafana-dashboards"
  echo "  namespace: ${NAMESPACE}"
  echo "data:"
  while IFS= read -r dashboard_file; do
    dashboard_name="$(basename "${dashboard_file}")"
    echo "  ${dashboard_name}: |"
    sed 's/^/    /' "${dashboard_file}"
  done < <(find "${GRAFANA_DASHBOARDS_DIR}" -maxdepth 1 -type f -name '*.json' | sort)
} > "${MANIFEST_DIR}/observability-grafana-dashboards-configmap.yaml"

cat > "${MANIFEST_DIR}/edge-proxy-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${EDGE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${EDGE_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${EDGE_NAME}
  template:
    metadata:
      labels:
        app: ${EDGE_NAME}
    spec:
      containers:
        - name: ${EDGE_NAME}
          image: ${EDGE_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: ${EDGE_PORT}
              protocol: TCP
          volumeMounts:
            - name: edge-proxy-config
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
          readinessProbe:
            httpGet:
              path: /health
              port: ${EDGE_PORT}
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: ${EDGE_PORT}
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: edge-proxy-config
          configMap:
            name: edge-proxy-config
EOF

cat > "${MANIFEST_DIR}/edge-proxy-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${EDGE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${EDGE_NAME}
spec:
  type: NodePort
  selector:
    app: ${EDGE_NAME}
  ports:
    - name: http
      protocol: TCP
      port: ${EDGE_PORT}
      targetPort: ${EDGE_PORT}
      nodePort: ${NODE_PORT}
EOF

render_component() {
  local name="$1"
  local image replicas
  image="$(jq -r --arg name "${name}" '.components[] | select(.name == $name) | .image' "${SPEC_JSON}")"
  replicas="$(jq -r --arg name "${name}" '.components[] | select(.name == $name) | .replicas // 1' "${SPEC_JSON}")"

  local ports_yaml env_yaml service_ports_yaml
  ports_yaml="$(jq -r --arg name "${name}" '
    .components[] | select(.name == $name) | .ports[] |
    "            - name: \(.name)\n              containerPort: \(.containerPort)\n              protocol: TCP"
  ' "${SPEC_JSON}")"
  service_ports_yaml="$(jq -r --arg name "${name}" '
    .components[] | select(.name == $name) | .ports[] |
    "    - name: \(.name)\n      protocol: TCP\n      port: \(.servicePort)\n      targetPort: \(.containerPort)"
  ' "${SPEC_JSON}")"
  env_yaml="$(jq -r --arg name "${name}" '
    .components[] | select(.name == $name) | (.env // [])[] |
    "            - name: \(.name)\n              value: \"\(.value)\""
  ' "${SPEC_JSON}")"

  case "${name}" in
    account-service|position-service|trade-processor|trade-service|order-matcher)
      if ! printf '%s\n' "${env_yaml}" | rg -q 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE'; then
        env_yaml+=$'\n            - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE\n              value: "health,prometheus,info"'
      fi
      if ! printf '%s\n' "${env_yaml}" | rg -q 'MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED'; then
        env_yaml+=$'\n            - name: MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED\n              value: "true"'
      fi
      if ! printf '%s\n' "${env_yaml}" | rg -q 'MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED'; then
        env_yaml+=$'\n            - name: MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED\n              value: "true"'
      fi
      ;;
  esac

  cat > "${MANIFEST_DIR}/${name}-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels:
    app: ${name}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:
      containers:
        - name: ${name}
          image: ${image}
          imagePullPolicy: IfNotPresent
          ports:
${ports_yaml}
EOF

  if [[ -n "${env_yaml}" ]]; then
    cat >> "${MANIFEST_DIR}/${name}-deployment.yaml" <<EOF
          env:
${env_yaml}
EOF
  fi

  if [[ "${name}" == "database" ]]; then
    cat >> "${MANIFEST_DIR}/${name}-deployment.yaml" <<'EOF'
          volumeMounts:
            - name: db-data
              mountPath: /var/lib/postgresql/data
            - name: database-init-sql
              mountPath: /docker-entrypoint-initdb.d/001-initialSchema.sql
              subPath: 001-initialSchema.sql
          readinessProbe:
            exec:
              command: ["sh", "-c", "pg_isready -U traderx -d traderx"]
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command: ["sh", "-c", "pg_isready -U traderx -d traderx"]
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: db-data
          emptyDir: {}
        - name: database-init-sql
          configMap:
            name: database-init-sql
EOF
  elif [[ "${name}" == "nats-broker" ]]; then
    cat >> "${MANIFEST_DIR}/${name}-deployment.yaml" <<'EOF'
          args: ["-c", "/etc/nats/nats.conf"]
          volumeMounts:
            - name: nats-config
              mountPath: /etc/nats/nats.conf
              subPath: nats.conf
      volumes:
        - name: nats-config
          configMap:
            name: nats-config
EOF
  fi

  cat > "${MANIFEST_DIR}/${name}-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels:
    app: ${name}
spec:
  type: ClusterIP
  selector:
    app: ${name}
  ports:
${service_ports_yaml}
EOF
}

while IFS= read -r component; do
  render_component "${component}"
done < <(jq -r '.components[].name' "${SPEC_JSON}")

cat > "${MANIFEST_DIR}/blackbox-exporter-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blackbox-exporter
  namespace: ${NAMESPACE}
  labels:
    app: blackbox-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blackbox-exporter
  template:
    metadata:
      labels:
        app: blackbox-exporter
    spec:
      containers:
        - name: blackbox-exporter
          image: prom/blackbox-exporter:v0.25.0
          imagePullPolicy: IfNotPresent
          args: ["--config.file=/etc/blackbox_exporter/config.yml"]
          ports:
            - name: http
              containerPort: 9115
              protocol: TCP
          volumeMounts:
            - name: blackbox-config
              mountPath: /etc/blackbox_exporter/config.yml
              subPath: blackbox.yml
      volumes:
        - name: blackbox-config
          configMap:
            name: observability-blackbox-config
EOF

cat > "${MANIFEST_DIR}/blackbox-exporter-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: blackbox-exporter
  namespace: ${NAMESPACE}
  labels:
    app: blackbox-exporter
spec:
  type: ClusterIP
  selector:
    app: blackbox-exporter
  ports:
    - name: http
      protocol: TCP
      port: 9115
      targetPort: 9115
EOF

cat > "${MANIFEST_DIR}/loki-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: ${NAMESPACE}
  labels:
    app: loki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
        - name: loki
          image: grafana/loki:2.9.8
          imagePullPolicy: IfNotPresent
          args: ["-config.file=/etc/loki/config.yaml"]
          ports:
            - name: http
              containerPort: 3100
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /ready
              port: 3100
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /ready
              port: 3100
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: loki-config
              mountPath: /etc/loki/config.yaml
              subPath: config.yaml
      volumes:
        - name: loki-config
          configMap:
            name: observability-loki-config
EOF

cat > "${MANIFEST_DIR}/loki-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: ${NAMESPACE}
  labels:
    app: loki
spec:
  type: ClusterIP
  selector:
    app: loki
  ports:
    - name: http
      protocol: TCP
      port: 3100
      targetPort: 3100
EOF

cat > "${MANIFEST_DIR}/promtail-serviceaccount.yaml" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: promtail
  namespace: ${NAMESPACE}
EOF

cat > "${MANIFEST_DIR}/promtail-clusterrole.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail-traderx
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "namespaces", "services"]
    verbs: ["get", "list", "watch"]
EOF

cat > "${MANIFEST_DIR}/promtail-clusterrolebinding.yaml" <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: promtail-traderx
subjects:
  - kind: ServiceAccount
    name: promtail
    namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: promtail-traderx
EOF

cat > "${MANIFEST_DIR}/promtail-daemonset.yaml" <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: ${NAMESPACE}
  labels:
    app: promtail
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
        - name: promtail
          image: grafana/promtail:2.9.8
          imagePullPolicy: IfNotPresent
          args: ["-config.file=/etc/promtail/config.yaml"]
          ports:
            - name: http
              containerPort: 3101
              protocol: TCP
          volumeMounts:
            - name: promtail-config
              mountPath: /etc/promtail/config.yaml
              subPath: config.yaml
            - name: varlogpods
              mountPath: /var/log/pods
              readOnly: true
            - name: run
              mountPath: /run/promtail
      volumes:
        - name: promtail-config
          configMap:
            name: observability-promtail-config
        - name: varlogpods
          hostPath:
            path: /var/log/pods
            type: DirectoryOrCreate
        - name: run
          emptyDir: {}
EOF

cat > "${MANIFEST_DIR}/tempo-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tempo
  namespace: ${NAMESPACE}
  labels:
    app: tempo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tempo
  template:
    metadata:
      labels:
        app: tempo
    spec:
      containers:
        - name: tempo
          image: grafana/tempo:2.5.0
          imagePullPolicy: IfNotPresent
          args: ["-config.file=/etc/tempo/config.yaml"]
          ports:
            - name: http
              containerPort: 3200
              protocol: TCP
            - name: otlp-grpc
              containerPort: 4317
              protocol: TCP
            - name: otlp-http
              containerPort: 4318
              protocol: TCP
          volumeMounts:
            - name: tempo-config
              mountPath: /etc/tempo/config.yaml
              subPath: config.yaml
      volumes:
        - name: tempo-config
          configMap:
            name: observability-tempo-config
EOF

cat > "${MANIFEST_DIR}/tempo-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: tempo
  namespace: ${NAMESPACE}
  labels:
    app: tempo
spec:
  type: ClusterIP
  selector:
    app: tempo
  ports:
    - name: http
      protocol: TCP
      port: 3200
      targetPort: 3200
    - name: otlp-grpc
      protocol: TCP
      port: 4317
      targetPort: 4317
    - name: otlp-http
      protocol: TCP
      port: 4318
      targetPort: 4318
EOF

cat > "${MANIFEST_DIR}/otel-collector-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: ${NAMESPACE}
  labels:
    app: otel-collector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.103.1
          imagePullPolicy: IfNotPresent
          args: ["--config=/etc/otelcol-contrib/config.yaml"]
          ports:
            - name: otlp-grpc
              containerPort: 4317
              protocol: TCP
            - name: otlp-http
              containerPort: 4318
              protocol: TCP
            - name: prometheus
              containerPort: 8889
              protocol: TCP
            - name: metrics
              containerPort: 8888
              protocol: TCP
            - name: health
              containerPort: 13133
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /
              port: 13133
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 13133
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: otel-config
              mountPath: /etc/otelcol-contrib/config.yaml
              subPath: config.yaml
      volumes:
        - name: otel-config
          configMap:
            name: observability-otel-collector-config
EOF

cat > "${MANIFEST_DIR}/otel-collector-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: ${NAMESPACE}
  labels:
    app: otel-collector
spec:
  type: ClusterIP
  selector:
    app: otel-collector
  ports:
    - name: otlp-grpc
      protocol: TCP
      port: 4317
      targetPort: 4317
    - name: otlp-http
      protocol: TCP
      port: 4318
      targetPort: 4318
    - name: metrics
      protocol: TCP
      port: 8888
      targetPort: 8888
    - name: prometheus
      protocol: TCP
      port: 8889
      targetPort: 8889
    - name: health
      protocol: TCP
      port: 13133
      targetPort: 13133
EOF

cat > "${MANIFEST_DIR}/prometheus-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.53.2
          imagePullPolicy: IfNotPresent
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --web.enable-lifecycle
            - --web.route-prefix=/prometheus
            - --web.external-url=/prometheus
          ports:
            - name: http
              containerPort: 9090
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /prometheus/-/ready
              port: 9090
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /prometheus/-/healthy
              port: 9090
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: prometheus-config
              mountPath: /etc/prometheus/prometheus.yml
              subPath: prometheus.yml
      volumes:
        - name: prometheus-config
          configMap:
            name: observability-prometheus-config
EOF

cat > "${MANIFEST_DIR}/prometheus-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
  labels:
    app: prometheus
spec:
  type: ClusterIP
  selector:
    app: prometheus
  ports:
    - name: http
      protocol: TCP
      port: 9090
      targetPort: 9090
EOF

cat > "${MANIFEST_DIR}/grafana-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: ${NAMESPACE}
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:11.1.0
          imagePullPolicy: IfNotPresent
          env:
            - name: GF_SECURITY_ADMIN_USER
              value: "admin"
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: "admin"
            - name: GF_USERS_ALLOW_SIGN_UP
              value: "false"
            - name: GF_AUTH_ANONYMOUS_ENABLED
              value: "false"
            - name: GF_SERVER_ROOT_URL
              value: "%(protocol)s://%(domain)s/grafana/"
            - name: GF_SERVER_SERVE_FROM_SUB_PATH
              value: "true"
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: grafana-datasources
              mountPath: /etc/grafana/provisioning/datasources/datasources.yaml
              subPath: datasources.yaml
            - name: grafana-dashboard-providers
              mountPath: /etc/grafana/provisioning/dashboards/dashboards.yaml
              subPath: dashboards.yaml
            - name: grafana-dashboards
              mountPath: /var/lib/grafana/dashboards
      volumes:
        - name: grafana-datasources
          configMap:
            name: observability-grafana-datasources
        - name: grafana-dashboard-providers
          configMap:
            name: observability-grafana-dashboard-providers
        - name: grafana-dashboards
          configMap:
            name: observability-grafana-dashboards
EOF

cat > "${MANIFEST_DIR}/grafana-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: ${NAMESPACE}
  labels:
    app: grafana
spec:
  type: ClusterIP
  selector:
    app: grafana
  ports:
    - name: http
      protocol: TCP
      port: 3000
      targetPort: 3000
EOF

{
  echo "apiVersion: kustomize.config.k8s.io/v1beta1"
  echo "kind: Kustomization"
  echo "namespace: ${NAMESPACE}"
  echo "resources:"
  echo "  - namespace.yaml"
  echo "  - edge-proxy-configmap.yaml"
  echo "  - database-init-configmap.yaml"
  echo "  - nats-configmap.yaml"
  echo "  - observability-blackbox-configmap.yaml"
  echo "  - observability-loki-configmap.yaml"
  echo "  - observability-promtail-configmap.yaml"
  echo "  - observability-tempo-configmap.yaml"
  echo "  - observability-otel-configmap.yaml"
  echo "  - observability-prometheus-configmap.yaml"
  echo "  - observability-grafana-datasources-configmap.yaml"
  echo "  - observability-grafana-dashboard-providers-configmap.yaml"
  echo "  - observability-grafana-dashboards-configmap.yaml"
  echo "  - edge-proxy-deployment.yaml"
  echo "  - edge-proxy-service.yaml"
  echo "  - blackbox-exporter-deployment.yaml"
  echo "  - blackbox-exporter-service.yaml"
  echo "  - loki-deployment.yaml"
  echo "  - loki-service.yaml"
  echo "  - promtail-serviceaccount.yaml"
  echo "  - promtail-clusterrole.yaml"
  echo "  - promtail-clusterrolebinding.yaml"
  echo "  - promtail-daemonset.yaml"
  echo "  - tempo-deployment.yaml"
  echo "  - tempo-service.yaml"
  echo "  - otel-collector-deployment.yaml"
  echo "  - otel-collector-service.yaml"
  echo "  - prometheus-deployment.yaml"
  echo "  - prometheus-service.yaml"
  echo "  - grafana-deployment.yaml"
  echo "  - grafana-service.yaml"
  while IFS= read -r component; do
    echo "  - ${component}-deployment.yaml"
    echo "  - ${component}-service.yaml"
  done < <(jq -r '.components[].name' "${SPEC_JSON}")
} > "${MANIFEST_DIR}/kustomization.yaml"

echo "[done] rendered state 010 kubernetes runtime assets into ${STATE_DIR}"

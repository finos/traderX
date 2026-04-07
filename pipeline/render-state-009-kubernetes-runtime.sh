#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/kubernetes-runtime"
MANIFEST_DIR="${STATE_DIR}/manifests/base"
SPEC_JSON="${ROOT}/specs/009-kubernetes-runtime/system/kubernetes-runtime.spec.json"
NGINX_CONF="${ROOT}/specs/009-kubernetes-runtime/system/nginx-edge.conf"
SQL_SOURCE="${TARGET_ROOT}/postgres-database-replacement/postgres-init/initialSchema.sql"
NATS_CONF_SOURCE="${TARGET_ROOT}/pricing-awareness-market-data/nats/nats.conf"

for required in "${SPEC_JSON}" "${NGINX_CONF}" "${SQL_SOURCE}" "${NATS_CONF_SOURCE}"; do
  [[ -f "${required}" ]] || {
    echo "[fail] required file missing for state 009 render: ${required}"
    exit 1
  }
done

rm -rf "${STATE_DIR}"
mkdir -p "${MANIFEST_DIR}" "${STATE_DIR}/kind" "${STATE_DIR}/spec-source"

cp "${SPEC_JSON}" "${STATE_DIR}/spec-source/kubernetes-runtime.spec.json"
cp "${NGINX_CONF}" "${STATE_DIR}/spec-source/nginx-edge.conf"

cat > "${STATE_DIR}/README.md" <<'EOF'
# State 009 Kubernetes Runtime Artifacts

Generated from:

- `specs/009-kubernetes-runtime/system/kubernetes-runtime.spec.json`
- `specs/009-kubernetes-runtime/system/nginx-edge.conf`

Artifacts:

- Kind cluster config: `kind/cluster-config.yaml`
- K8s manifests: `manifests/base`
- Image build plan: `build-plan.json`

Run:

```bash
./scripts/start-state-009-kubernetes-runtime-generated.sh
```
EOF

jq '{
  stateId: "009-kubernetes-runtime",
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
  deployments: ([.components[].name] + [.runtime.edge.serviceName])
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

{
  echo "apiVersion: kustomize.config.k8s.io/v1beta1"
  echo "kind: Kustomization"
  echo "namespace: ${NAMESPACE}"
  echo "resources:"
  echo "  - namespace.yaml"
  echo "  - edge-proxy-configmap.yaml"
  echo "  - database-init-configmap.yaml"
  echo "  - nats-configmap.yaml"
  echo "  - edge-proxy-deployment.yaml"
  echo "  - edge-proxy-service.yaml"
  while IFS= read -r component; do
    echo "  - ${component}-deployment.yaml"
    echo "  - ${component}-service.yaml"
  done < <(jq -r '.components[].name' "${SPEC_JSON}")
} > "${MANIFEST_DIR}/kustomization.yaml"

echo "[done] rendered state 009 kubernetes runtime assets into ${STATE_DIR}"

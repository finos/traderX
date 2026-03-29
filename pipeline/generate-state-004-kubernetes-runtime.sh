#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="004-kubernetes-runtime"
TARGET_ROOT="${ROOT}/generated/code/target-generated"
STATE_OUT="${TARGET_ROOT}/kubernetes-runtime"
SPEC_DIR="${ROOT}/specs/004-kubernetes-runtime/system"
RUNTIME_SPEC="${SPEC_DIR}/kubernetes-runtime.spec.json"
EDGE_CONF_SPEC="${SPEC_DIR}/nginx-edge.conf"
MANIFEST_DIR="${STATE_OUT}/manifests/base"
KIND_DIR="${STATE_OUT}/kind"
BUILD_PLAN="${STATE_OUT}/build-plan.json"
KUSTOMIZATION_FILE="${MANIFEST_DIR}/kustomization.yaml"

[[ -f "${RUNTIME_SPEC}" ]] || {
  echo "[fail] missing runtime spec: ${RUNTIME_SPEC}"
  exit 1
}

[[ -f "${EDGE_CONF_SPEC}" ]] || {
  echo "[fail] missing edge config spec: ${EDGE_CONF_SPEC}"
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq command is required"
  exit 1
fi

# Build on top of state 003 generated assets to preserve lineage.
bash "${ROOT}/pipeline/generate-state.sh" 003-containerized-compose-runtime

namespace="$(jq -r '.runtime.namespace' "${RUNTIME_SPEC}")"
cluster_name="$(jq -r '.runtime.kind.clusterName' "${RUNTIME_SPEC}")"
host_port="$(jq -r '.runtime.kind.hostPort' "${RUNTIME_SPEC}")"
node_port="$(jq -r '.runtime.kind.nodePort' "${RUNTIME_SPEC}")"
edge_service_name="$(jq -r '.runtime.edge.serviceName' "${RUNTIME_SPEC}")"
edge_image="$(jq -r '.runtime.edge.image' "${RUNTIME_SPEC}")"
edge_container_port="$(jq -r '.runtime.edge.containerPort' "${RUNTIME_SPEC}")"

rm -rf "${STATE_OUT}"
mkdir -p "${MANIFEST_DIR}" "${KIND_DIR}" "${STATE_OUT}/spec-source"

cp "${RUNTIME_SPEC}" "${STATE_OUT}/spec-source/kubernetes-runtime.spec.json"
cp "${EDGE_CONF_SPEC}" "${STATE_OUT}/spec-source/nginx-edge.conf"

cat > "${KIND_DIR}/cluster-config.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: ${node_port}
        hostPort: ${host_port}
        protocol: TCP
EOF

cat > "${MANIFEST_DIR}/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
EOF

cat > "${MANIFEST_DIR}/edge-proxy-configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: edge-proxy-config
  namespace: ${namespace}
data:
  default.conf: |
$(sed 's/^/    /' "${EDGE_CONF_SPEC}")
EOF

cat > "${MANIFEST_DIR}/edge-proxy-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${edge_service_name}
  namespace: ${namespace}
  labels:
    app: ${edge_service_name}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${edge_service_name}
  template:
    metadata:
      labels:
        app: ${edge_service_name}
    spec:
      containers:
        - name: ${edge_service_name}
          image: ${edge_image}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: ${edge_container_port}
              protocol: TCP
          volumeMounts:
            - name: edge-proxy-config
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
          readinessProbe:
            httpGet:
              path: /health
              port: ${edge_container_port}
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: ${edge_container_port}
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
  name: ${edge_service_name}
  namespace: ${namespace}
  labels:
    app: ${edge_service_name}
spec:
  type: NodePort
  selector:
    app: ${edge_service_name}
  ports:
    - name: http
      protocol: TCP
      port: ${edge_container_port}
      targetPort: ${edge_container_port}
      nodePort: ${node_port}
EOF

component_resources=()
while IFS= read -r component; do
  name="$(jq -r '.name' <<<"${component}")"
  image="$(jq -r '.image' <<<"${component}")"
  replicas="$(jq -r '.replicas // 1' <<<"${component}")"
  deployment_file="${MANIFEST_DIR}/${name}-deployment.yaml"
  service_file="${MANIFEST_DIR}/${name}-service.yaml"

  ports_block="$(jq -r '.ports[] | "            - name: \(.name)\n              containerPort: \(.containerPort)\n              protocol: \(.protocol // "TCP")"' <<<"${component}")"
  env_block="$(jq -r '.env[]? | "            - name: \(.name)\n              value: \"\(.value)\""' <<<"${component}")"
  service_ports_block="$(jq -r '.ports[] | "    - name: \(.name)\n      protocol: \(.protocol // "TCP")\n      port: \(.servicePort)\n      targetPort: \(.containerPort)"' <<<"${component}")"

  {
    cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${namespace}
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
${ports_block}
EOF
    if [[ -n "${env_block}" ]]; then
      cat <<EOF
          env:
${env_block}
EOF
    fi
  } > "${deployment_file}"

  {
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
spec:
  type: ClusterIP
  selector:
    app: ${name}
  ports:
${service_ports_block}
EOF
  } > "${service_file}"

  component_resources+=("${name}-deployment.yaml")
  component_resources+=("${name}-service.yaml")
done < <(jq -c '.components[]' "${RUNTIME_SPEC}")

{
  cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${namespace}
resources:
  - namespace.yaml
  - edge-proxy-configmap.yaml
  - edge-proxy-deployment.yaml
  - edge-proxy-service.yaml
EOF
  for resource in "${component_resources[@]}"; do
    echo "  - ${resource}"
  done
} > "${KUSTOMIZATION_FILE}"

jq '{
  stateId: "004-kubernetes-runtime",
  namespace: .runtime.namespace,
  kindClusterName: .runtime.kind.clusterName,
  hostPort: .runtime.kind.hostPort,
  nodePort: .runtime.kind.nodePort,
  edgeService: .runtime.edge.serviceName,
  images: [
    .components[] | {
      name: .name,
      image: .image,
      context: .build.context,
      dockerfile: .build.dockerfile
    }
  ],
  deployments: ((.components | map(.name)) + [.runtime.edge.serviceName])
}' "${RUNTIME_SPEC}" > "${BUILD_PLAN}"

cat > "${STATE_OUT}/README.md" <<EOF
# State 004 Kubernetes Runtime Artifacts

Generated from:

- \`specs/004-kubernetes-runtime/system/kubernetes-runtime.spec.json\`
- \`specs/004-kubernetes-runtime/system/nginx-edge.conf\`

Artifacts:

- Kind cluster config: \`kind/cluster-config.yaml\`
- K8s manifests: \`manifests/base\`
- Image build plan: \`build-plan.json\`

Run:

\`\`\`bash
./scripts/start-state-004-kubernetes-generated.sh
\`\`\`
EOF

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
UPSTREAM_DIR="${TARGET_ROOT}/kubernetes-runtime"
STATE_DIR="${TARGET_ROOT}/radius-kubernetes-platform"
RADIUS_DIR="${STATE_DIR}/radius"
UPSTREAM_BUILD_PLAN="${UPSTREAM_DIR}/build-plan.json"
UPSTREAM_SPEC="${UPSTREAM_DIR}/spec-source/kubernetes-runtime.spec.json"

for required in "${UPSTREAM_BUILD_PLAN}" "${UPSTREAM_SPEC}"; do
  [[ -f "${required}" ]] || {
    echo "[fail] required state 010 artifact missing for state 013 render: ${required}"
    exit 1
  }
done

rm -rf "${STATE_DIR}"
mkdir -p "${RADIUS_DIR}/.rad"

cp "${UPSTREAM_BUILD_PLAN}" "${STATE_DIR}/upstream-build-plan.json"

cat > "${STATE_DIR}/README.md" <<'EOF'
# State 013 Radius Platform Artifacts

Generated from:

- `specs/013-radius-kubernetes-platform/**`
- `generated/code/target-generated/kubernetes-runtime/build-plan.json`

State intent:

- preserve state 010 runtime behavior,
- add Radius app/resource definitions as platform abstraction artifacts.

Artifacts:

- Radius app model: `radius/app.bicep`
- Radius workspace config: `radius/.rad/rad.yaml`
- Bicep extension config: `radius/bicepconfig.json`
- Parent image map reference: `upstream-build-plan.json`

Run baseline runtime for this state:

```bash
./scripts/start-state-013-radius-kubernetes-platform-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-013-radius-kubernetes-platform.sh
```

Optional Radius command flow (requires `rad`):

```bash
cd generated/code/target-generated/radius-kubernetes-platform/radius
rad run app.bicep
```
EOF

cat > "${RADIUS_DIR}/.rad/rad.yaml" <<'EOF'
workspace:
  application: "traderx-state-010"
EOF

cat > "${RADIUS_DIR}/bicepconfig.json" <<'EOF'
{
  "experimentalFeaturesEnabled": {
    "extensibility": true,
    "extensionRegistry": true,
    "dynamicTypeLoading": true
  },
  "extensions": {
    "radius": "br:biceptypes.azurecr.io/radius:0.38",
    "aws": "br:biceptypes.azurecr.io/aws:0.38"
  }
}
EOF

sanitize_identifier() {
  local value="$1"
  value="${value//-/}"
  value="${value//./}"
  echo "${value}"
}

{
  echo "extension radius"
  echo
  echo "param application string = 'traderx-state-010'"
  echo

  while IFS= read -r item; do
    name="$(jq -r '.name' <<<"${item}")"
    image="$(jq -r '.image' <<<"${item}")"
    first_port="$(jq -r '.ports[0].containerPort // empty' <<<"${item}")"
    resource_id="$(sanitize_identifier "${name}")"

    echo "resource ${resource_id} 'Applications.Core/containers@2023-10-01-preview' = {"
    echo "  name: '${name}'"
    echo "  properties: {"
    echo "    application: application"
    echo "    container: {"
    echo "      image: '${image}'"
    if [[ -n "${first_port}" ]]; then
      echo "      ports: {"
      echo "        web: { containerPort: ${first_port} }"
      echo "      }"
    fi
    echo "    }"
    echo "  }"
    echo "}"
    echo
  done < <(jq -c '.components[]' "${UPSTREAM_SPEC}")

  edge_name="$(jq -r '.runtime.edge.serviceName' "${UPSTREAM_SPEC}")"
  edge_image="$(jq -r '.runtime.edge.image' "${UPSTREAM_SPEC}")"
  edge_port="$(jq -r '.runtime.edge.containerPort' "${UPSTREAM_SPEC}")"
  edge_id="$(sanitize_identifier "${edge_name}")"
  echo "resource ${edge_id} 'Applications.Core/containers@2023-10-01-preview' = {"
  echo "  name: '${edge_name}'"
  echo "  properties: {"
  echo "    application: application"
  echo "    container: {"
  echo "      image: '${edge_image}'"
  echo "      ports: {"
  echo "        web: { containerPort: ${edge_port} }"
  echo "      }"
  echo "    }"
  echo "  }"
  echo "}"
} > "${RADIUS_DIR}/app.bicep"

echo "[done] rendered state 013 radius artifacts into ${STATE_DIR}"

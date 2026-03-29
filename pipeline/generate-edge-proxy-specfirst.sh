#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENT_ID="edge-proxy"
TARGET="${ROOT}/generated/code/components/edge-proxy-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/edge-proxy-specfirst"
ROUTES_SPEC_PATH="${ROOT}/specs/002-edge-proxy-uncontainerized/system/edge-routing.json"

[[ -d "${TEMPLATE_ROOT}" ]] || {
  echo "[fail] missing template directory: ${TEMPLATE_ROOT}"
  exit 1
}

[[ -f "${ROUTES_SPEC_PATH}" ]] || {
  echo "[fail] missing edge-routing spec file: ${ROUTES_SPEC_PATH}"
  exit 1
}

jq -e '
  .defaultPort == 18080 and
  (.webTarget | type == "string") and
  (.apiRoutes | type == "array") and
  (.apiRoutes | length >= 5)
' "${ROUTES_SPEC_PATH}" >/dev/null

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"
cp "${ROUTES_SPEC_PATH}" "${TARGET}/config/routes.json"

ROUTE_COUNT="$(jq -r '.apiRoutes | length' "${ROUTES_SPEC_PATH}")"
WEB_TARGET="$(jq -r '.webTarget' "${ROUTES_SPEC_PATH}")"
DEFAULT_PORT="$(jq -r '.defaultPort' "${ROUTES_SPEC_PATH}")"

cat <<EOF > "${TARGET}/README.md"
# Edge Proxy (Spec-First Generated)

This component is generated from:

- state pack: \`specs/002-edge-proxy-uncontainerized\`
- routing spec: \`specs/002-edge-proxy-uncontainerized/system/edge-routing.json\`

## Run

\`\`\`bash
npm install
npm run start
\`\`\`

## Runtime Contract

- listen port: \`${DEFAULT_PORT}\` (env override: \`EDGE_PROXY_PORT\`)
- web upstream: \`${WEB_TARGET}\` (env override: \`EDGE_PROXY_WEB_TARGET\`)
- configured API routes: \`${ROUTE_COUNT}\`
EOF

cat <<EOF > "${TARGET}/SPEC.generated.md"
# Edge Proxy (Spec-First Generated)

- component: \`${COMPONENT_ID}\`
- defaultPort: \`${DEFAULT_PORT}\`
- routesFile: \`config/routes.json\`
- routeCount: \`${ROUTE_COUNT}\`
- state: \`002-edge-proxy-uncontainerized\`
EOF

echo "[done] regenerated ${TARGET} from ${ROUTES_SPEC_PATH}"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="web-front-end-angular"
TARGET="${ROOT}/generated/code/components/web-front-end-angular-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/web-front-end/angular"
MANIFEST_PATH="${ROOT}/generated/manifests/${COMPONENT_ID}.manifest.json"

speckit_assert_global_readiness
speckit_assert_component_ready "${COMPONENT_ID}"
bash "${ROOT}/pipeline/speckit/compile-component-manifest.sh" "${COMPONENT_ID}" "${MANIFEST_PATH}"

[[ -d "${TEMPLATE_ROOT}" ]] || {
  echo "[fail] missing template directory: ${TEMPLATE_ROOT}"
  exit 1
}

[[ -f "${MANIFEST_PATH}" ]] || {
  echo "[fail] manifest was not generated: ${MANIFEST_PATH}"
  exit 1
}

jq -e '
  .schemaVersion == "1.0.0" and
  .component.id == "web-front-end-angular" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

WEB_SERVICE_PORT_ENV="$(jq -r '.runtime.requiredEnv[] | select(startswith("WEB_SERVICE_PORT"))' "${MANIFEST_PATH}" | head -n 1)"
DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"

[[ -n "${WEB_SERVICE_PORT_ENV}" ]] || {
  echo "[fail] manifest missing required runtime env mapping: WEB_SERVICE_PORT"
  exit 1
}

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"

for asset in \
  "main/assets/img/traderx-apple-touch-icon.png" \
  "main/assets/img/traderx-icon.png" \
  "main/assets/img/FINOS_Icon_White.png"; do
  if [[ ! -f "${TARGET}/${asset}" ]]; then
    echo "[fail] missing required branding asset after generation: ${asset}"
    exit 1
  fi
done

cat <<EOF > "${TARGET}/README.md"
# Web Front End Angular (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
npm install
npm run start
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${WEB_SERVICE_PORT_ENV}\`
- Branding assets preserved:
  - \`main/assets/img/traderx-apple-touch-icon.png\`
  - \`main/assets/img/traderx-icon.png\`
  - \`main/assets/img/FINOS_Icon_White.png\`
EOF

cat <<EOF > "${TARGET}/SPEC.generated.md"
# Web Front End Angular (Spec-First Generated)

Synthesized from Spec Kit manifest:

- component: \`${COMPONENT_ID}\`
- defaultPort: \`${DEFAULT_PORT}\`
- portEnv: \`${WEB_SERVICE_PORT_ENV}\`

Branding assets preserved:

- \`main/assets/img/traderx-apple-touch-icon.png\`
- \`main/assets/img/traderx-icon.png\`
- \`main/assets/img/FINOS_Icon_White.png\`
EOF

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"

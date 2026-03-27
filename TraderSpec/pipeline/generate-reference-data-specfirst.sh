#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="reference-data"
TARGET="${ROOT}/codebase/generated-components/reference-data-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/reference-data-specfirst"
MANIFEST_PATH="${ROOT}/codebase/generated-manifests/${COMPONENT_ID}.manifest.json"

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
  .component.id == "reference-data" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
CONTRACT_PATH="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
PORT_ENV="REFERENCE_DATA_SERVICE_PORT"
CORS_ENV="CORS_ALLOWED_ORIGINS"

if [[ -n "${CONTRACT_PATH}" ]]; then
  [[ -f "${REPO_ROOT}/${CONTRACT_PATH}" ]] || {
    echo "[fail] manifest contract path does not exist: ${CONTRACT_PATH}"
    exit 1
  }
fi

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"

cat <<EOF > "${TARGET}/README.md"
# Reference-Data (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
npm install
npm run start
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${PORT_ENV}\`
- CORS allowlist: \`${CORS_ENV}\` (default \`*\`)
- Dataset: \`data/s-and-p-500-companies.csv\`
EOF

cat <<EOF > "${TARGET}/src/main.ts"
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configuredOrigins = (process.env.${CORS_ENV} ?? '*')
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  app.enableCors({
    origin: configuredOrigins.includes('*') ? true : configuredOrigins,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['*'],
  });

  const port = Number(process.env.${PORT_ENV} ?? ${DEFAULT_PORT});
  await app.listen(port, '0.0.0.0');
  // Used by startup orchestration readiness checks.
  // eslint-disable-next-line no-console
  console.log(\`[ready] reference-data-specfirst listening on :\${port}\`);
}

bootstrap();
EOF

if [[ -n "${CONTRACT_PATH}" ]]; then
  cp "${REPO_ROOT}/${CONTRACT_PATH}" "${TARGET}/openapi.yaml"
fi

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"

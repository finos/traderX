#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="trade-service"
TARGET="${ROOT}/generated/code/components/trade-service-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/trade-service-specfirst"
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
  .component.id == "trade-service" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
CONTRACT_PATH="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
TRADING_SERVICE_PORT_ENV="$(manifest_env_by_prefix "TRADING_SERVICE_PORT")"
ACCOUNT_SERVICE_URL_ENV="$(manifest_env_by_prefix "ACCOUNT_SERVICE_URL")"
ACCOUNT_SERVICE_HOST_ENV="$(manifest_env_by_prefix "ACCOUNT_SERVICE_HOST")"
REFERENCE_DATA_SERVICE_URL_ENV="$(manifest_env_by_prefix "REFERENCE_DATA_SERVICE_URL")"
REFERENCE_DATA_HOST_ENV="$(manifest_env_by_prefix "REFERENCE_DATA_HOST")"
PEOPLE_SERVICE_URL_ENV="$(manifest_env_by_prefix "PEOPLE_SERVICE_URL")"
PEOPLE_SERVICE_HOST_ENV="$(manifest_env_by_prefix "PEOPLE_SERVICE_HOST")"
TRADE_FEED_ADDRESS_ENV="$(manifest_env_by_prefix "TRADE_FEED_ADDRESS")"
TRADE_FEED_HOST_ENV="$(manifest_env_by_prefix "TRADE_FEED_HOST")"
CORS_ALLOWED_ORIGINS_ENV="$(manifest_env_by_prefix "CORS_ALLOWED_ORIGINS")"

for required_var in \
  TRADING_SERVICE_PORT_ENV \
  ACCOUNT_SERVICE_URL_ENV \
  ACCOUNT_SERVICE_HOST_ENV \
  REFERENCE_DATA_SERVICE_URL_ENV \
  REFERENCE_DATA_HOST_ENV \
  PEOPLE_SERVICE_URL_ENV \
  PEOPLE_SERVICE_HOST_ENV \
  TRADE_FEED_ADDRESS_ENV \
  TRADE_FEED_HOST_ENV \
  CORS_ALLOWED_ORIGINS_ENV; do
  [[ -n "${!required_var}" ]] || {
    echo "[fail] manifest missing required runtime env mapping: ${required_var}"
    exit 1
  }
done

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
# Trade-Service (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
./gradlew build
./gradlew bootRun
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${TRADING_SERVICE_PORT_ENV}\`
- Reference data endpoint: \`${REFERENCE_DATA_SERVICE_URL_ENV}\` or \`${REFERENCE_DATA_HOST_ENV}\`
- Account endpoint: \`${ACCOUNT_SERVICE_URL_ENV}\` or \`${ACCOUNT_SERVICE_HOST_ENV}\`
- People endpoint: \`${PEOPLE_SERVICE_URL_ENV}\` or \`${PEOPLE_SERVICE_HOST_ENV}\`
- Trade feed endpoint: \`${TRADE_FEED_ADDRESS_ENV}\` or \`${TRADE_FEED_HOST_ENV}\`
- CORS allowlist: \`${CORS_ALLOWED_ORIGINS_ENV}\` (default \`*\`)
EOF

cat <<EOF > "${TARGET}/src/main/resources/application.properties"
server.port=\${${TRADING_SERVICE_PORT_ENV}:${DEFAULT_PORT}}
spring.threads.virtual.enabled=true

people.service.url=\${${PEOPLE_SERVICE_URL_ENV}:http://\${${PEOPLE_SERVICE_HOST_ENV}:localhost}:18089}
account.service.url=\${${ACCOUNT_SERVICE_URL_ENV}:http://\${${ACCOUNT_SERVICE_HOST_ENV}:localhost}:18088}
reference.data.service.url=\${${REFERENCE_DATA_SERVICE_URL_ENV}:http://\${${REFERENCE_DATA_HOST_ENV}:localhost}:18085}

trade.feed.address=\${${TRADE_FEED_ADDRESS_ENV}:http://\${${TRADE_FEED_HOST_ENV}:localhost}:18086}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.root=info
EOF

cat <<EOF > "${TARGET}/Dockerfile"
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE ${DEFAULT_PORT}
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF

if [[ -n "${CONTRACT_PATH}" ]]; then
  cp "${REPO_ROOT}/${CONTRACT_PATH}" "${TARGET}/openapi.yaml"
fi

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"
chmod +x "${TARGET}/gradlew"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"

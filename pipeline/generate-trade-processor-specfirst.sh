#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="trade-processor"
TARGET="${ROOT}/generated/code/components/trade-processor-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/trade-processor-specfirst"
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
  .component.id == "trade-processor" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
CONTRACT_PATH="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
TRADE_PROCESSOR_SERVICE_PORT_ENV="$(manifest_env_by_prefix "TRADE_PROCESSOR_SERVICE_PORT")"
DATABASE_TCP_HOST_ENV="$(manifest_env_by_prefix "DATABASE_TCP_HOST")"
DATABASE_TCP_PORT_ENV="$(manifest_env_by_prefix "DATABASE_TCP_PORT")"
DATABASE_NAME_ENV="$(manifest_env_by_prefix "DATABASE_NAME")"
DATABASE_DBUSER_ENV="$(manifest_env_by_prefix "DATABASE_DBUSER")"
DATABASE_DBPASS_ENV="$(manifest_env_by_prefix "DATABASE_DBPASS")"
TRADE_FEED_ADDRESS_ENV="$(manifest_env_by_prefix "TRADE_FEED_ADDRESS")"
TRADE_FEED_HOST_ENV="$(manifest_env_by_prefix "TRADE_FEED_HOST")"
CORS_ALLOWED_ORIGINS_ENV="$(manifest_env_by_prefix "CORS_ALLOWED_ORIGINS")"

for required_var in \
  TRADE_PROCESSOR_SERVICE_PORT_ENV \
  DATABASE_TCP_HOST_ENV \
  DATABASE_TCP_PORT_ENV \
  DATABASE_NAME_ENV \
  DATABASE_DBUSER_ENV \
  DATABASE_DBPASS_ENV \
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
# Trade-Processor (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
./gradlew build
./gradlew bootRun
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${TRADE_PROCESSOR_SERVICE_PORT_ENV}\`
- Database: \`${DATABASE_TCP_HOST_ENV}\`, \`${DATABASE_TCP_PORT_ENV}\`, \`${DATABASE_NAME_ENV}\`, \`${DATABASE_DBUSER_ENV}\`, \`${DATABASE_DBPASS_ENV}\`
- Trade feed: \`${TRADE_FEED_ADDRESS_ENV}\` or \`${TRADE_FEED_HOST_ENV}\`
- CORS allowlist: \`${CORS_ALLOWED_ORIGINS_ENV}\` (default \`*\`)
EOF

cat <<EOF > "${TARGET}/src/main/resources/application.properties"
server.port=\${${TRADE_PROCESSOR_SERVICE_PORT_ENV}:${DEFAULT_PORT}}

spring.datasource.url=jdbc:h2:tcp://\${${DATABASE_TCP_HOST_ENV}:localhost}:\${${DATABASE_TCP_PORT_ENV}:18082}/\${${DATABASE_NAME_ENV}:traderx};CASE_INSENSITIVE_IDENTIFIERS=TRUE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=\${${DATABASE_DBUSER_ENV}:sa}
spring.datasource.password=\${${DATABASE_DBPASS_ENV}:sa}
spring.data.jpa.database-platform=org.hibernate.dialect.H2Dialect
spring.data.jpa.show-sql=true
spring.jpa.hibernate.ddl-auto=update
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.threads.virtual.enabled=true

trade.feed.address=\${${TRADE_FEED_ADDRESS_ENV}:http://\${${TRADE_FEED_HOST_ENV}:localhost}:18086}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=DEBUG
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

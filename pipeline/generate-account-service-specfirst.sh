#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="account-service"
TARGET="${ROOT}/generated/code/components/account-service-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/account-service-specfirst"
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
  .component.id == "account-service" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
CONTRACT_PATH="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
ACCOUNT_SERVICE_PORT_ENV="$(manifest_env_by_prefix "ACCOUNT_SERVICE_PORT")"
DATABASE_TCP_HOST_ENV="$(manifest_env_by_prefix "DATABASE_TCP_HOST")"
PEOPLE_SERVICE_URL_ENV="$(manifest_env_by_prefix "PEOPLE_SERVICE_URL")"
PEOPLE_SERVICE_HOST_ENV="$(manifest_env_by_prefix "PEOPLE_SERVICE_HOST")"
CORS_ALLOWED_ORIGINS_ENV="$(manifest_env_by_prefix "CORS_ALLOWED_ORIGINS")"

for required_var in \
  ACCOUNT_SERVICE_PORT_ENV \
  DATABASE_TCP_HOST_ENV \
  PEOPLE_SERVICE_URL_ENV \
  PEOPLE_SERVICE_HOST_ENV \
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
# Account-Service (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
./gradlew build
./gradlew bootRun
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${ACCOUNT_SERVICE_PORT_ENV}\`
- Database host: \`${DATABASE_TCP_HOST_ENV}\` (other DB envs keep compatibility defaults: \`DATABASE_TCP_PORT\`, \`DATABASE_NAME\`, \`DATABASE_DBUSER\`, \`DATABASE_DBPASS\`)
- People service: \`${PEOPLE_SERVICE_URL_ENV}\` or \`${PEOPLE_SERVICE_HOST_ENV}\`
- CORS allowlist: \`${CORS_ALLOWED_ORIGINS_ENV}\` (default \`*\`)
EOF

cat <<EOF > "${TARGET}/src/main/resources/application.properties"
server.port=\${${ACCOUNT_SERVICE_PORT_ENV}:${DEFAULT_PORT}}

spring.datasource.url=jdbc:h2:tcp://\${${DATABASE_TCP_HOST_ENV}:localhost}:\${DATABASE_TCP_PORT:18082}/\${DATABASE_NAME:traderx};CASE_INSENSITIVE_IDENTIFIERS=TRUE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=\${DATABASE_DBUSER:sa}
spring.datasource.password=\${DATABASE_DBPASS:sa}
spring.threads.virtual.enabled=true

people.service.url=\${${PEOPLE_SERVICE_URL_ENV}:http://\${${PEOPLE_SERVICE_HOST_ENV}:localhost}:18089}

server.max-http-request-header-size=1000000
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

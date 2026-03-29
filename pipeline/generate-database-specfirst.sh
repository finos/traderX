#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="database"
TARGET="${ROOT}/TraderSpec/codebase/generated-components/database-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/database-specfirst"
MANIFEST_PATH="${ROOT}/TraderSpec/codebase/generated-manifests/${COMPONENT_ID}.manifest.json"

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
  .component.id == "database" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_TCP_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
DEFAULT_PG_PORT="$((DEFAULT_TCP_PORT + 1))"
DEFAULT_WEB_PORT="$((DEFAULT_TCP_PORT + 2))"
DATABASE_WEB_HOSTNAMES_ENV="$(manifest_env_by_prefix "DATABASE_WEB_HOSTNAMES")"
[[ -n "${DATABASE_WEB_HOSTNAMES_ENV}" ]] || DATABASE_WEB_HOSTNAMES_ENV="DATABASE_WEB_HOSTNAMES"

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"

cat <<EOF > "${TARGET}/README.md"
# Database (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
./gradlew build
./run.sh
\`\`\`

## Runtime Contract

- Default TCP port: \`${DEFAULT_TCP_PORT}\` via \`DATABASE_TCP_PORT\`
- Default PG port: \`${DEFAULT_PG_PORT}\` via \`DATABASE_PG_PORT\`
- Default web console port: \`${DEFAULT_WEB_PORT}\` via \`DATABASE_WEB_PORT\`
- Web hostname allowlist env: \`${DATABASE_WEB_HOSTNAMES_ENV}\`
EOF

cat <<EOF > "${TARGET}/run.sh"
#!/usr/bin/env bash
set -euo pipefail

set -a
: "\${DATABASE_TCP_PORT:=${DEFAULT_TCP_PORT}}"
: "\${DATABASE_PG_PORT:=${DEFAULT_PG_PORT}}"
: "\${DATABASE_WEB_PORT:=${DEFAULT_WEB_PORT}}"
: "\${DATABASE_DBUSER:=sa}"
: "\${DATABASE_DBPASS:=sa}"
: "\${DATABASE_H2JAR:=./build/libs/database-specfirst.jar}"
: "\${DATABASE_DATA_DIR:=./_data}"
: "\${DATABASE_DBNAME:=traderx}"
: "\${DATABASE_HOSTNAME:=\${HOSTNAME:-localhost}}"
: "\${DATABASE_JDBC_URL:=jdbc:h2:tcp://\$DATABASE_HOSTNAME:\$DATABASE_TCP_PORT/\$DATABASE_DBNAME}"
: "\${DATABASE_WEB_HOSTNAMES:=\${DATABASE_HOSTNAME}}"
set +a

echo "Data will be located in \${DATABASE_DATA_DIR}"
echo "Database name is \${DATABASE_DBNAME}"
echo "Running schema setup script"
echo "---------------------------------------------------------------------------"

java -cp "\${DATABASE_H2JAR}" org.h2.tools.RunScript \
  -url "jdbc:h2:\${DATABASE_DATA_DIR}/\${DATABASE_DBNAME};DATABASE_TO_UPPER=TRUE;TRACE_LEVEL_SYSTEM_OUT=3" \
  -user "\${DATABASE_DBUSER}" \
  -password "\${DATABASE_DBPASS}" \
  -script initialSchema.sql

echo "Starting Database Server"
echo "---------------------------------------------------------------------------"

exec java -jar "\${DATABASE_H2JAR}" \
  -pg -pgPort "\${DATABASE_PG_PORT}" -pgAllowOthers -baseDir "\${DATABASE_DATA_DIR}" \
  -tcp -tcpPort "\${DATABASE_TCP_PORT}" -tcpAllowOthers \
  -web -webPort "\${DATABASE_WEB_PORT}" -webExternalNames "\${DATABASE_WEB_HOSTNAMES}" -webAllowOthers
EOF

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"
chmod +x "${TARGET}/gradlew" "${TARGET}/run.sh"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"

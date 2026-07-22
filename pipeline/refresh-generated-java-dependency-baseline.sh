#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS_FILE="${TRADERX_DEPENDENCY_TARGETS_FILE:-${ROOT}/catalog/dependency-version-targets.json}"

if [[ "$#" -lt 1 ]]; then
  echo "usage: bash pipeline/refresh-generated-java-dependency-baseline.sh <root> [root...]"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required"
  exit 1
fi

if [[ ! -f "${TARGETS_FILE}" ]]; then
  echo "[fail] missing dependency targets file: ${TARGETS_FILE}"
  exit 1
fi

BOOT_VERSION="$(jq -er '.java.plugins["org.springframework.boot"]' "${TARGETS_FILE}")"
SPRINGDOC_VERSION="$(jq -er '.java.dependencies["org.springdoc:springdoc-openapi-starter-webmvc-api"]' "${TARGETS_FILE}")"
LOG4J_API_VERSION="$(jq -er '.java.dependencies["org.apache.logging.log4j:log4j-api"]' "${TARGETS_FILE}")"
LOG4J_TO_SLF4J_VERSION="$(jq -er '.java.dependencies["org.apache.logging.log4j:log4j-to-slf4j"]' "${TARGETS_FILE}")"
KOTLIN_STDLIB_VERSION="$(jq -er '.java.dependencies["org.jetbrains.kotlin:kotlin-stdlib"]' "${TARGETS_FILE}")"
JACKSON_BOM_VERSION="$(jq -er '.java.properties["jackson-bom.version"]' "${TARGETS_FILE}")"
TOMCAT_VERSION="$(jq -er '.java.properties["tomcat.version"]' "${TARGETS_FILE}")"

normalize_gradle_file() {
  local gradle_file="$1"

  [[ -f "${gradle_file}" ]] || return 0
  if ! rg -q "id 'org\\.springframework\\.boot' version" "${gradle_file}"; then
    return 0
  fi

  perl -0pi -e "s/(id 'org\\.springframework\\.boot' version ')[^']+(')/\${1}${BOOT_VERSION}\$2/g" "${gradle_file}"
  perl -0pi -e "s/org\\.springdoc:springdoc-openapi-starter-webmvc-ui:/org.springdoc:springdoc-openapi-starter-webmvc-api:/g" "${gradle_file}"
  perl -0pi -e "s/(org\\.springdoc:springdoc-openapi-starter-webmvc-api:)[^']+/\${1}${SPRINGDOC_VERSION}/g" "${gradle_file}"
  perl -0pi -e "s/(org\\.apache\\.logging\\.log4j:log4j-api:)[^']+/\${1}${LOG4J_API_VERSION}/g" "${gradle_file}"
  perl -0pi -e "s/(org\\.apache\\.logging\\.log4j:log4j-to-slf4j:)[^']+/\${1}${LOG4J_TO_SLF4J_VERSION}/g" "${gradle_file}"
  perl -0pi -e "s/(org\\.jetbrains\\.kotlin:kotlin-stdlib:)[^']+/\${1}${KOTLIN_STDLIB_VERSION}/g" "${gradle_file}"
  perl -0pi -e "s/^\\s*implementation 'org\\.webjars:swagger-ui:[^']+'\\n//mg" "${gradle_file}"

  if rg -q "ext\\['jackson-bom\\.version'\\]" "${gradle_file}"; then
    perl -0pi -e "s/ext\\['jackson-bom\\.version'\\]\\s*=\\s*'[^']+'/ext['jackson-bom.version'] = '${JACKSON_BOM_VERSION}'/g" "${gradle_file}"
  elif rg -q "ext\\['tomcat\\.version'\\]" "${gradle_file}"; then
    perl -0pi -e "s/(ext\\['tomcat\\.version'\\]\\s*=\\s*'[^']+')/ext['jackson-bom.version'] = '${JACKSON_BOM_VERSION}'\\n\${1}/g" "${gradle_file}"
  else
    perl -0pi -e "s/(plugins\\s*\\{[^}]*\\}\\n\\n)/\${1}ext['jackson-bom.version'] = '${JACKSON_BOM_VERSION}'\\n/s" "${gradle_file}"
  fi

  if rg -q "ext\\['tomcat\\.version'\\]" "${gradle_file}"; then
    perl -0pi -e "s/ext\\['tomcat\\.version'\\]\\s*=\\s*'[^']+'/ext['tomcat.version'] = '${TOMCAT_VERSION}'/g" "${gradle_file}"
  else
    perl -0pi -e "s/(plugins\\s*\\{[^}]*\\}\\n\\n)/\${1}ext['tomcat.version'] = '${TOMCAT_VERSION}'\\n\\n/s" "${gradle_file}"
  fi
}

for root in "$@"; do
  [[ -d "${root}" ]] || continue

  while IFS= read -r -d '' gradle_file; do
    normalize_gradle_file "${gradle_file}"
  done < <(find "${root}" -type f -name 'build.gradle' -print0)
done

echo "[done] applied Java dependency targets (boot=${BOOT_VERSION}, springdoc=${SPRINGDOC_VERSION}, jackson-bom=${JACKSON_BOM_VERSION}, tomcat=${TOMCAT_VERSION})"

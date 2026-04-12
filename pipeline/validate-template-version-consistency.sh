#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_ROOT="${ROOT}/templates"

fail() {
  echo "[fail] $*"
  exit 1
}

collect_unique() {
  tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

count_words() {
  awk '{ print NF }'
}

extract_boot_version() {
  local file="$1"
  sed -n "s/.*id 'org\\.springframework\\.boot' version '\\([^']*\\)'.*/\\1/p" "${file}" | head -n1
}

extract_dep_mgmt_version() {
  local file="$1"
  sed -n "s/.*id 'io\\.spring\\.dependency-management' version '\\([^']*\\)'.*/\\1/p" "${file}" | head -n1
}

extract_java_major() {
  local file="$1"
  sed -n "s/.*sourceCompatibility = JavaVersion\\.VERSION_\\([0-9][0-9]*\\).*/\\1/p" "${file}" | head -n1
}

extract_gradle_wrapper_version() {
  local file="$1"
  sed -n 's#.*distributionUrl=.*gradle-\([0-9.]*\)-bin\.zip.*#\1#p' "${file}" | head -n1
}

extract_dependency_version() {
  local file="$1"
  local coordinate="$2"
  local escaped
  escaped="$(printf '%s' "${coordinate}" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
  rg -o --pcre2 "'${escaped}:\\K[^']+" "${file}" | head -n1 || true
}

spring_build_files=()
while IFS= read -r file; do
  if rg -q "id 'org\\.springframework\\.boot' version" "${file}"; then
    spring_build_files+=("${file}")
  fi
done < <(find "${TEMPLATES_ROOT}" -maxdepth 2 -type f -name build.gradle -print | sort)

[[ "${#spring_build_files[@]}" -gt 0 ]] || fail "no Spring Boot template build.gradle files found under ${TEMPLATES_ROOT}"

wrapper_files=()
while IFS= read -r file; do
  wrapper_files+=("${file}")
done < <(find "${TEMPLATES_ROOT}" -path '*/gradle/wrapper/gradle-wrapper.properties' -type f -print | sort)
[[ "${#wrapper_files[@]}" -gt 0 ]] || fail "no Gradle wrapper properties found under ${TEMPLATES_ROOT}"

boot_versions=""
dep_mgmt_versions=""
java_majors=""

for file in "${spring_build_files[@]}"; do
  boot_version="$(extract_boot_version "${file}")"
  dep_mgmt_version="$(extract_dep_mgmt_version "${file}")"
  java_major="$(extract_java_major "${file}")"

  [[ -n "${boot_version}" ]] || fail "missing Spring Boot plugin version in ${file}"
  [[ -n "${dep_mgmt_version}" ]] || fail "missing dependency-management plugin version in ${file}"
  [[ -n "${java_major}" ]] || fail "missing Java sourceCompatibility in ${file}"

  boot_versions="${boot_versions} ${boot_version}"
  dep_mgmt_versions="${dep_mgmt_versions} ${dep_mgmt_version}"
  java_majors="${java_majors} ${java_major}"
done

unique_boot_versions="$(printf '%s\n' "${boot_versions}" | collect_unique)"
unique_dep_mgmt_versions="$(printf '%s\n' "${dep_mgmt_versions}" | collect_unique)"
unique_java_majors="$(printf '%s\n' "${java_majors}" | collect_unique)"

if [[ "$(printf '%s\n' "${unique_boot_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Spring Boot plugin versions across templates: ${unique_boot_versions}"
fi

if [[ "$(printf '%s\n' "${unique_dep_mgmt_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent dependency-management plugin versions across templates: ${unique_dep_mgmt_versions}"
fi

if [[ "$(printf '%s\n' "${unique_java_majors}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Java sourceCompatibility versions across templates: ${unique_java_majors}"
fi

wrapper_versions=""
for file in "${wrapper_files[@]}"; do
  wrapper_version="$(extract_gradle_wrapper_version "${file}")"
  [[ -n "${wrapper_version}" ]] || fail "missing Gradle distributionUrl version in ${file}"
  wrapper_versions="${wrapper_versions} ${wrapper_version}"
done

unique_wrapper_versions="$(printf '%s\n' "${wrapper_versions}" | collect_unique)"
if [[ "$(printf '%s\n' "${unique_wrapper_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Gradle wrapper versions across templates: ${unique_wrapper_versions}"
fi

shared_dependencies=(
  "org.springdoc:springdoc-openapi-starter-webmvc-ui"
  "org.webjars:swagger-ui"
  "org.apache.logging.log4j:log4j-api"
  "ch.qos.logback:logback-core"
  "ch.qos.logback:logback-classic"
  "org.apache.commons:commons-lang3"
  "org.jetbrains.kotlin:kotlin-stdlib"
)

for dep in "${shared_dependencies[@]}"; do
  versions=""
  seen=0
  for file in "${spring_build_files[@]}"; do
    dep_version="$(extract_dependency_version "${file}" "${dep}")"
    if [[ -n "${dep_version}" ]]; then
      versions="${versions} ${dep_version}"
      seen=$((seen + 1))
    fi
  done

  if (( seen <= 1 )); then
    continue
  fi

  unique_versions="$(printf '%s\n' "${versions}" | collect_unique)"
  if [[ "$(printf '%s\n' "${unique_versions}" | count_words)" -ne 1 ]]; then
    fail "inconsistent ${dep} versions across templates: ${unique_versions}"
  fi
done

echo "[ok] template version consistency validated (spring=${unique_boot_versions}, java=${unique_java_majors}, gradle=${unique_wrapper_versions})"

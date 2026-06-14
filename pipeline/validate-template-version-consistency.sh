#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_ROOT="${ROOT}/templates"
TARGETS_FILE="${TRADERX_DEPENDENCY_TARGETS_FILE:-${ROOT}/catalog/dependency-version-targets.json}"

fail() {
  echo "[fail] $*"
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required"
fi

[[ -f "${TARGETS_FILE}" ]] || fail "missing dependency targets file: ${TARGETS_FILE}"

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

extract_tomcat_version() {
  local file="$1"
  sed -n "s/.*ext\\['tomcat\\.version'\\][[:space:]]*=[[:space:]]*'\\([^']*\\)'.*/\\1/p" "${file}" | head -n1
}

extract_gradle_wrapper_version() {
  local file="$1"
  sed -n 's#.*distributionUrl=.*gradle-\([0-9.]*\)-bin\.zip.*#\1#p' "${file}" | head -n1
}

extract_gradle_wrapper_sha() {
  local file="$1"
  sed -n 's/^distributionSha256Sum=\(.*\)$/\1/p' "${file}" | head -n1
}

extract_dependency_version() {
  local file="$1"
  local coordinate="$2"
  local escaped
  escaped="$(printf '%s' "${coordinate}" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
  rg -o --pcre2 "'${escaped}:\\K[^']+" "${file}" | head -n1 || true
}

extract_yaml_image_tags() {
  local file="$1"
  local image_name="$2"
  local escaped
  escaped="$(printf '%s' "${image_name}" | sed 's/[][(){}.+*?^$|\\/]/\\&/g')"
  rg -o --pcre2 "image\\s*:\\s*['\"]?${escaped}:\\K[^'\"\\s]+" "${file}" || true
}

extract_json_image_tags() {
  local file="$1"
  local image_name="$2"
  local escaped
  escaped="$(printf '%s' "${image_name}" | sed 's/[][(){}.+*?^$|\\/]/\\&/g')"
  rg -o --pcre2 "\"image\"\\s*:\\s*\"${escaped}:\\K[^\"]+" "${file}" || true
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

canonical_wrapper_root="${TEMPLATES_ROOT}/gradle-wrapper"
[[ -d "${canonical_wrapper_root}" ]] || fail "missing canonical wrapper template directory: ${canonical_wrapper_root}"

canonical_wrapper_files=(
  "gradlew"
  "gradlew.bat"
  "gradle/wrapper/gradle-wrapper.jar"
  "gradle/wrapper/gradle-wrapper.properties"
)

sha256_file() {
  local file="$1"
  shasum -a 256 "${file}" | awk '{print $1}'
}

for rel in "${canonical_wrapper_files[@]}"; do
  [[ -f "${canonical_wrapper_root}/${rel}" ]] || fail "missing canonical wrapper file: ${canonical_wrapper_root}/${rel}"
done

target_boot_version="$(jq -er '.java.plugins["org.springframework.boot"]' "${TARGETS_FILE}")"
target_dep_mgmt_version="$(jq -er '.java.plugins["io.spring.dependency-management"]' "${TARGETS_FILE}")"
target_java_major="$(jq -er '.java.sourceCompatibility' "${TARGETS_FILE}")"
target_tomcat_version="$(jq -er '.java.properties["tomcat.version"]' "${TARGETS_FILE}")"
target_wrapper_version="$(jq -er '.gradleWrapper.distributionVersion' "${TARGETS_FILE}")"
target_wrapper_sha="$(jq -er '.gradleWrapper.distributionSha256Sum' "${TARGETS_FILE}")"

boot_versions=""
dep_mgmt_versions=""
java_majors=""
tomcat_versions=""

for file in "${spring_build_files[@]}"; do
  boot_version="$(extract_boot_version "${file}")"
  dep_mgmt_version="$(extract_dep_mgmt_version "${file}")"
  java_major="$(extract_java_major "${file}")"
  tomcat_version="$(extract_tomcat_version "${file}")"

  [[ -n "${boot_version}" ]] || fail "missing Spring Boot plugin version in ${file}"
  [[ -n "${dep_mgmt_version}" ]] || fail "missing dependency-management plugin version in ${file}"
  [[ -n "${java_major}" ]] || fail "missing Java sourceCompatibility in ${file}"
  [[ -n "${tomcat_version}" ]] || fail "missing tomcat.version in ${file}"

  boot_versions="${boot_versions} ${boot_version}"
  dep_mgmt_versions="${dep_mgmt_versions} ${dep_mgmt_version}"
  java_majors="${java_majors} ${java_major}"
  tomcat_versions="${tomcat_versions} ${tomcat_version}"
done

unique_boot_versions="$(printf '%s\n' "${boot_versions}" | collect_unique)"
unique_dep_mgmt_versions="$(printf '%s\n' "${dep_mgmt_versions}" | collect_unique)"
unique_java_majors="$(printf '%s\n' "${java_majors}" | collect_unique)"
unique_tomcat_versions="$(printf '%s\n' "${tomcat_versions}" | collect_unique)"

if [[ "$(printf '%s\n' "${unique_boot_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Spring Boot plugin versions across templates: ${unique_boot_versions}"
fi

if [[ "$(printf '%s\n' "${unique_dep_mgmt_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent dependency-management plugin versions across templates: ${unique_dep_mgmt_versions}"
fi

if [[ "$(printf '%s\n' "${unique_java_majors}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Java sourceCompatibility versions across templates: ${unique_java_majors}"
fi

if [[ "$(printf '%s\n' "${unique_tomcat_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent tomcat.version values across templates: ${unique_tomcat_versions}"
fi

[[ "${unique_boot_versions}" == "${target_boot_version}" ]] || fail "Spring Boot plugin version (${unique_boot_versions}) does not match target (${target_boot_version})"
[[ "${unique_dep_mgmt_versions}" == "${target_dep_mgmt_version}" ]] || fail "dependency-management plugin version (${unique_dep_mgmt_versions}) does not match target (${target_dep_mgmt_version})"
[[ "${unique_java_majors}" == "${target_java_major}" ]] || fail "Java sourceCompatibility (${unique_java_majors}) does not match target (${target_java_major})"
[[ "${unique_tomcat_versions}" == "${target_tomcat_version}" ]] || fail "tomcat.version (${unique_tomcat_versions}) does not match target (${target_tomcat_version})"

wrapper_versions=""
wrapper_shas=""
for file in "${wrapper_files[@]}"; do
  wrapper_version="$(extract_gradle_wrapper_version "${file}")"
  wrapper_sha="$(extract_gradle_wrapper_sha "${file}")"
  [[ -n "${wrapper_version}" ]] || fail "missing Gradle distributionUrl version in ${file}"
  [[ -n "${wrapper_sha}" ]] || fail "missing distributionSha256Sum in ${file}"
  wrapper_versions="${wrapper_versions} ${wrapper_version}"
  wrapper_shas="${wrapper_shas} ${wrapper_sha}"
done

unique_wrapper_versions="$(printf '%s\n' "${wrapper_versions}" | collect_unique)"
if [[ "$(printf '%s\n' "${unique_wrapper_versions}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Gradle wrapper versions across templates: ${unique_wrapper_versions}"
fi

unique_wrapper_shas="$(printf '%s\n' "${wrapper_shas}" | collect_unique)"
if [[ "$(printf '%s\n' "${unique_wrapper_shas}" | count_words)" -ne 1 ]]; then
  fail "inconsistent Gradle wrapper SHA values across templates: ${unique_wrapper_shas}"
fi

[[ "${unique_wrapper_versions}" == "${target_wrapper_version}" ]] || fail "Gradle wrapper version (${unique_wrapper_versions}) does not match target (${target_wrapper_version})"
[[ "${unique_wrapper_shas}" == "${target_wrapper_sha}" ]] || fail "Gradle wrapper SHA (${unique_wrapper_shas}) does not match target (${target_wrapper_sha})"

while IFS= read -r gradle_file; do
  module_dir="$(dirname "${gradle_file}")"
  for rel in "${canonical_wrapper_files[@]}"; do
    module_file="${module_dir}/${rel}"
    [[ -f "${module_file}" ]] || fail "missing wrapper file in template module ${module_dir}: ${rel}"

    canonical_hash="$(sha256_file "${canonical_wrapper_root}/${rel}")"
    module_hash="$(sha256_file "${module_file}")"
    if [[ "${canonical_hash}" != "${module_hash}" ]]; then
      fail "wrapper file drift detected in ${module_dir}: ${rel} differs from templates/gradle-wrapper baseline"
    fi
  done
done < <(find "${TEMPLATES_ROOT}" -maxdepth 2 -type f -name build.gradle -print | sort)

while IFS=$'\t' read -r dep target_dep_version; do
  [[ -n "${dep}" && -n "${target_dep_version}" ]] || continue
  versions=""
  seen=0
  for file in "${spring_build_files[@]}"; do
    dep_version="$(extract_dependency_version "${file}" "${dep}")"
    if [[ -n "${dep_version}" ]]; then
      versions="${versions} ${dep_version}"
      seen=$((seen + 1))
    fi
  done

  if (( seen == 0 )); then
    fail "dependency target ${dep} not found in template Gradle files"
  fi

  unique_versions="$(printf '%s\n' "${versions}" | collect_unique)"
  [[ "$(printf '%s\n' "${unique_versions}" | count_words)" -eq 1 ]] || fail "inconsistent ${dep} versions across templates: ${unique_versions}"
  [[ "${unique_versions}" == "${target_dep_version}" ]] || fail "${dep} version (${unique_versions}) does not match target (${target_dep_version})"
done < <(jq -r '.java.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r npm_dep npm_target; do
  [[ -n "${npm_dep}" && -n "${npm_target}" ]] || continue
  seen=0
  while IFS= read -r package_file; do
    actual="$(jq -r --arg dep "${npm_dep}" '(.dependencies[$dep] // .devDependencies[$dep] // .overrides[$dep] // empty)' "${package_file}")"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    [[ "${actual}" == "${npm_target}" ]] || fail "npm target mismatch for ${npm_dep} in ${package_file}: expected ${npm_target}, found ${actual}"
  done < <(find "${TEMPLATES_ROOT}" -type f -name package.json ! -path '*/node_modules/*' -print | sort)
  (( seen > 0 )) || fail "npm target ${npm_dep} not found under templates/"
done < <(jq -r '.npm.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r npm_dep npm_target; do
  [[ -n "${npm_dep}" && -n "${npm_target}" ]] || continue
  seen=0
  while IFS= read -r package_file; do
    actual="$(jq -r --arg dep "${npm_dep}" '(.overrides[$dep] // empty)' "${package_file}")"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    [[ "${actual}" == "${npm_target}" ]] || fail "npm override target mismatch for ${npm_dep} in ${package_file}: expected ${npm_target}, found ${actual}"
  done < <(find "${TEMPLATES_ROOT}" -type f -name package.json ! -path '*/node_modules/*' -print | sort)
  (( seen > 0 )) || fail "npm override target ${npm_dep} not found under templates/"
done < <(jq -r '(.npm.overrides // {}) | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS= read -r package_file; do
  while IFS=$'\t' read -r npm_dep npm_actual; do
    [[ -n "${npm_dep}" && -n "${npm_actual}" ]] || continue
    npm_target="$(jq -r --arg dep "${npm_dep}" '(.npm.overrides // {})[$dep] // empty' "${TARGETS_FILE}")"
    [[ -n "${npm_target}" ]] || fail "template npm override ${npm_dep} in ${package_file} is not declared in ${TARGETS_FILE}"
    [[ "${npm_actual}" == "${npm_target}" ]] || fail "template npm override ${npm_dep} in ${package_file} does not match catalog target: expected ${npm_target}, found ${npm_actual}"
  done < <(jq -r '(.overrides // {}) | to_entries[] | [.key, (.value | tostring)] | @tsv' "${package_file}")
done < <(find "${TEMPLATES_ROOT}" -type f -name package.json ! -path '*/node_modules/*' -print | sort)

while IFS=$'\t' read -r nuget_dep nuget_target; do
  [[ -n "${nuget_dep}" && -n "${nuget_target}" ]] || continue
  seen=0
  while IFS= read -r csproj_file; do
    actual="$(sed -n "s/.*<PackageReference Include=\"${nuget_dep}\" Version=\"\\([^\"]*\\)\".*/\\1/p" "${csproj_file}" | head -n1)"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    [[ "${actual}" == "${nuget_target}" ]] || fail "NuGet target mismatch for ${nuget_dep} in ${csproj_file}: expected ${nuget_target}, found ${actual}"
  done < <(find "${TEMPLATES_ROOT}" -type f -name '*.csproj' -print | sort)
  (( seen > 0 )) || fail "NuGet target ${nuget_dep} not found under templates/"
done < <(jq -r '.nuget.packages | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r image_name image_target; do
  [[ -n "${image_name}" && -n "${image_target}" ]] || continue
  seen=0
  while IFS= read -r manifest_file; do
    while IFS= read -r actual; do
      [[ -n "${actual}" ]] || continue
      seen=$((seen + 1))
      [[ "${actual}" == "${image_target}" ]] || fail "docker image target mismatch for ${image_name} in ${manifest_file}: expected ${image_target}, found ${actual}"
    done < <(extract_yaml_image_tags "${manifest_file}" "${image_name}")

    while IFS= read -r actual; do
      [[ -n "${actual}" ]] || continue
      seen=$((seen + 1))
      [[ "${actual}" == "${image_target}" ]] || fail "docker image target mismatch for ${image_name} in ${manifest_file}: expected ${image_target}, found ${actual}"
    done < <(extract_json_image_tags "${manifest_file}" "${image_name}")
  done < <(find "${TEMPLATES_ROOT}" -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) -print | sort)
  (( seen > 0 )) || fail "docker image target ${image_name}:${image_target} not found under templates/"
done < <(jq -r '(.docker.images // {}) | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

echo "[ok] template dependency targets validated (spring=${unique_boot_versions}, java=${unique_java_majors}, gradle=${unique_wrapper_versions})"

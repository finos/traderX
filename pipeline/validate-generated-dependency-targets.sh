#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS_FILE="${TRADERX_DEPENDENCY_TARGETS_FILE:-${ROOT}/catalog/dependency-version-targets.json}"

fail() {
  echo "[fail] $*"
  exit 1
}

if [[ "$#" -lt 1 ]]; then
  echo "usage: bash pipeline/validate-generated-dependency-targets.sh <root> [root...]"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required"
fi

if [[ ! -f "${TARGETS_FILE}" ]]; then
  fail "missing dependency targets file: ${TARGETS_FILE}"
fi

tmp_files="$(mktemp)"
trap 'rm -f "${tmp_files}"' EXIT

for scan_root in "$@"; do
  [[ -d "${scan_root}" ]] || continue
  find "${scan_root}" -type f \
    \( -name 'build.gradle' -o -name 'gradle-wrapper.properties' -o -name 'package.json' -o -name '*.csproj' \) \
    ! -path '*/node_modules/*' \
    -print >> "${tmp_files}"
done

if [[ ! -s "${tmp_files}" ]]; then
  fail "no dependency-bearing files found under provided roots"
fi

check_equals() {
  local label="$1"
  local file="$2"
  local expected="$3"
  local actual="$4"
  if [[ "${actual}" != "${expected}" ]]; then
    fail "${label} mismatch in ${file}: expected ${expected}, found ${actual}"
  fi
}

JAVA_BOOT_TARGET="$(jq -er '.java.plugins["org.springframework.boot"]' "${TARGETS_FILE}")"
JAVA_DEP_MGMT_TARGET="$(jq -er '.java.plugins["io.spring.dependency-management"]' "${TARGETS_FILE}")"
JAVA_SOURCE_TARGET="$(jq -er '.java.sourceCompatibility' "${TARGETS_FILE}")"
JAVA_TOMCAT_TARGET="$(jq -er '.java.properties["tomcat.version"]' "${TARGETS_FILE}")"
GRADLE_WRAPPER_TARGET="$(jq -er '.gradleWrapper.distributionVersion' "${TARGETS_FILE}")"
GRADLE_WRAPPER_SHA_TARGET="$(jq -er '.gradleWrapper.distributionSha256Sum' "${TARGETS_FILE}")"

spring_files_count=0
tomcat_seen=0
while IFS= read -r gradle_file; do
  [[ -f "${gradle_file}" ]] || continue
  if ! rg -q "id 'org\\.springframework\\.boot' version" "${gradle_file}"; then
    continue
  fi

  spring_files_count=$((spring_files_count + 1))

  boot_version="$(sed -n "s/.*id 'org\\.springframework\\.boot' version '\\([^']*\\)'.*/\\1/p" "${gradle_file}" | head -n1)"
  dep_mgmt_version="$(sed -n "s/.*id 'io\\.spring\\.dependency-management' version '\\([^']*\\)'.*/\\1/p" "${gradle_file}" | head -n1)"
  java_source="$(sed -n "s/.*sourceCompatibility = JavaVersion\\.VERSION_\\([0-9][0-9]*\\).*/\\1/p" "${gradle_file}" | head -n1)"
  tomcat_version="$(sed -n "s/.*ext\\['tomcat\\.version'\\][[:space:]]*=[[:space:]]*'\\([^']*\\)'.*/\\1/p" "${gradle_file}" | head -n1)"

  [[ -n "${boot_version}" ]] || fail "missing Spring Boot plugin version in ${gradle_file}"
  [[ -n "${dep_mgmt_version}" ]] || fail "missing dependency-management plugin version in ${gradle_file}"
  [[ -n "${java_source}" ]] || fail "missing Java sourceCompatibility in ${gradle_file}"
  check_equals "Spring Boot plugin" "${gradle_file}" "${JAVA_BOOT_TARGET}" "${boot_version}"
  check_equals "Dependency-management plugin" "${gradle_file}" "${JAVA_DEP_MGMT_TARGET}" "${dep_mgmt_version}"
  check_equals "Java sourceCompatibility" "${gradle_file}" "${JAVA_SOURCE_TARGET}" "${java_source}"
  if [[ -n "${tomcat_version}" ]]; then
    tomcat_seen=$((tomcat_seen + 1))
    check_equals "tomcat.version property" "${gradle_file}" "${JAVA_TOMCAT_TARGET}" "${tomcat_version}"
  fi

done < <(rg -N "" "${tmp_files}" | rg 'build\.gradle$' || true)

(( spring_files_count > 0 )) || fail "no Spring Boot build.gradle files found under provided roots"
(( tomcat_seen > 0 )) || fail "tomcat.version property target not found in generated Gradle files"

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  seen=0
  escaped="$(printf '%s' "${dep}" | sed 's/[.[\*^$()+?{}|]/\\&/g')"

  while IFS= read -r gradle_file; do
    [[ -f "${gradle_file}" ]] || continue
    actual="$(rg -o --pcre2 "'${escaped}:\\K[^']+" "${gradle_file}" | head -n1 || true)"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    check_equals "Gradle dependency ${dep}" "${gradle_file}" "${expected}" "${actual}"
  done < <(rg -N "" "${tmp_files}" | rg 'build\.gradle$' || true)

  (( seen > 0 )) || fail "dependency target ${dep} not found in generated Gradle files"
done < <(jq -r '.java.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

wrapper_files_count=0
while IFS= read -r wrapper_file; do
  [[ -f "${wrapper_file}" ]] || continue
  wrapper_files_count=$((wrapper_files_count + 1))
  wrapper_version="$(sed -n 's#.*distributionUrl=.*gradle-\([0-9.]*\)-bin\.zip.*#\1#p' "${wrapper_file}" | head -n1)"
  wrapper_sha="$(sed -n 's/^distributionSha256Sum=\(.*\)$/\1/p' "${wrapper_file}" | head -n1)"

  [[ -n "${wrapper_version}" ]] || fail "missing Gradle wrapper version in ${wrapper_file}"
  [[ -n "${wrapper_sha}" ]] || fail "missing Gradle wrapper SHA in ${wrapper_file}"

  check_equals "Gradle wrapper distribution" "${wrapper_file}" "${GRADLE_WRAPPER_TARGET}" "${wrapper_version}"
  check_equals "Gradle wrapper SHA" "${wrapper_file}" "${GRADLE_WRAPPER_SHA_TARGET}" "${wrapper_sha}"
done < <(rg -N "" "${tmp_files}" | rg 'gradle-wrapper\.properties$' || true)

(( wrapper_files_count > 0 )) || fail "no gradle-wrapper.properties files found under provided roots"

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  seen=0
  while IFS= read -r package_file; do
    [[ -f "${package_file}" ]] || continue
    actual="$(jq -r --arg dep "${dep}" '(.dependencies[$dep] // .devDependencies[$dep] // .overrides[$dep] // empty)' "${package_file}")"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    check_equals "npm dependency ${dep}" "${package_file}" "${expected}" "${actual}"
  done < <(rg -N "" "${tmp_files}" | rg 'package\.json$' || true)

  (( seen > 0 )) || fail "npm target ${dep} not found in generated package.json files"
done < <(jq -r '.npm.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  seen=0
  while IFS= read -r package_file; do
    [[ -f "${package_file}" ]] || continue
    actual="$(jq -r --arg dep "${dep}" '(.overrides[$dep] // empty)' "${package_file}")"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    check_equals "npm override ${dep}" "${package_file}" "${expected}" "${actual}"
  done < <(rg -N "" "${tmp_files}" | rg 'package\.json$' || true)

  (( seen > 0 )) || fail "npm override target ${dep} not found in generated package.json files"
done < <(jq -r '(.npm.overrides // {}) | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  seen=0
  while IFS= read -r csproj_file; do
    [[ -f "${csproj_file}" ]] || continue
    actual="$(sed -n "s/.*<PackageReference Include=\"${dep}\" Version=\"\\([^\"]*\\)\".*/\\1/p" "${csproj_file}" | head -n1)"
    if [[ -z "${actual}" ]]; then
      continue
    fi
    seen=$((seen + 1))
    check_equals "NuGet package ${dep}" "${csproj_file}" "${expected}" "${actual}"
  done < <(rg -N "" "${tmp_files}" | rg '\.csproj$' || true)

  (( seen > 0 )) || fail "NuGet target ${dep} not found in generated csproj files"
done < <(jq -r '.nuget.packages | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

echo "[ok] dependency targets validated for generated roots ($# root(s))"

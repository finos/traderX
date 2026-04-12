#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${1:-}"
CANONICAL_WRAPPER_ROOT="${ROOT}/templates/gradle-wrapper"

if [[ -z "${TARGET_ROOT}" ]]; then
  echo "usage: bash pipeline/sync-gradle-wrapper-assets.sh <target-root>"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

for required in \
  "${CANONICAL_WRAPPER_ROOT}/gradlew" \
  "${CANONICAL_WRAPPER_ROOT}/gradlew.bat" \
  "${CANONICAL_WRAPPER_ROOT}/gradle/wrapper/gradle-wrapper.jar" \
  "${CANONICAL_WRAPPER_ROOT}/gradle/wrapper/gradle-wrapper.properties"; do
  if [[ ! -f "${required}" ]]; then
    echo "[fail] missing canonical wrapper asset: ${required}"
    exit 1
  fi
done

synced=0
while IFS= read -r build_file; do
  module_dir="$(dirname "${build_file}")"
  mkdir -p "${module_dir}/gradle/wrapper"
  cp "${CANONICAL_WRAPPER_ROOT}/gradlew" "${module_dir}/gradlew"
  cp "${CANONICAL_WRAPPER_ROOT}/gradlew.bat" "${module_dir}/gradlew.bat"
  cp "${CANONICAL_WRAPPER_ROOT}/gradle/wrapper/gradle-wrapper.jar" "${module_dir}/gradle/wrapper/gradle-wrapper.jar"
  cp "${CANONICAL_WRAPPER_ROOT}/gradle/wrapper/gradle-wrapper.properties" "${module_dir}/gradle/wrapper/gradle-wrapper.properties"
  chmod +x "${module_dir}/gradlew"
  synced=$((synced + 1))
done < <(find "${TARGET_ROOT}" -type f \( -name build.gradle -o -name build.gradle.kts \) | sort)

if (( synced == 0 )); then
  echo "[info] no Gradle modules found under ${TARGET_ROOT}; wrapper sync skipped"
else
  echo "[ok] synced canonical Gradle wrapper assets into ${synced} module(s) under ${TARGET_ROOT}"
fi

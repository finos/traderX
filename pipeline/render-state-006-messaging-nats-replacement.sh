#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"

ensure_micrometer_core() {
  local gradle_file="$1"
  [[ -f "${gradle_file}" ]] || return 0

  if rg -q "io\\.micrometer:micrometer-core|spring-boot-starter-actuator" "${gradle_file}"; then
    return 0
  fi

  perl -0pi -e "s/(implementation 'org\\.springframework\\.boot:spring-boot-starter-web'\\n)/\${1}  implementation 'io.micrometer:micrometer-core'\\n/" "${gradle_file}"
}

ensure_micrometer_core "${TARGET_ROOT}/trade-service/build.gradle"
ensure_micrometer_core "${TARGET_ROOT}/trade-processor/build.gradle"

echo "[ok] rendered state 006 micrometer dependency overrides"

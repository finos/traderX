#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
RUNTIME_OVERRIDES_DIR="${ROOT}/specs/006-messaging-nats-replacement/generation/runtime-overrides"

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

if [[ -d "${RUNTIME_OVERRIDES_DIR}" ]]; then
  rsync -a "${RUNTIME_OVERRIDES_DIR}/" "${TARGET_ROOT}/"
fi

# State 006 replaces the legacy trade-feed service with NATS. Remove the
# superseded component directory so downstream states do not carry stale
# lockfiles or runtime artifacts.
rm -rf "${TARGET_ROOT}/trade-feed"

echo "[ok] rendered state 006 micrometer dependency overrides"

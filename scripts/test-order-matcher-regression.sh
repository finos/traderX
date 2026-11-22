#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT}/order-matcher/gradlew" ]]; then
  DEFAULT_TARGET_ROOT="${ROOT}" # Standalone generated snapshot.
else
  DEFAULT_TARGET_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}/code/target-generated"
fi
TARGET_ROOT="${1:-${DEFAULT_TARGET_ROOT}}"
MATCHER_ROOT="${TARGET_ROOT}/order-matcher"
[[ -f "${MATCHER_ROOT}/gradlew" ]] || {
  echo "[fail] generate state 009 (or a descendant) before running matcher regressions"
  exit 1
}
container_id=""
cleanup() {
  if [[ -n "${container_id}" ]]; then docker rm -f "${container_id}" >/dev/null; fi
}
trap cleanup EXIT
if [[ -z "${TRADERX_TEST_POSTGRES_URL:-}" ]]; then
  # Only this disposable container is removed; no application volumes are mounted.
  container_id="$(docker run --rm -d -e POSTGRES_PASSWORD=traderx-regression \
    -e POSTGRES_DB=traderx -p 127.0.0.1::5432 postgres:16-alpine)"
  ready=0
  for ((attempt=0; attempt<30; attempt++)); do
    if docker exec "${container_id}" pg_isready -U postgres -d traderx >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  [[ "${ready}" == 1 ]] || { echo "[fail] test PostgreSQL did not become ready"; exit 1; }
  port="$(docker port "${container_id}" 5432/tcp | awk -F: '{print $NF}')"
  export TRADERX_TEST_POSTGRES_URL="jdbc:postgresql://127.0.0.1:${port}/traderx"
  export TRADERX_TEST_POSTGRES_USER=postgres
  export TRADERX_TEST_POSTGRES_PASSWORD=traderx-regression
else
  : "${TRADERX_TEST_POSTGRES_USER:?set the test database user}"
  : "${TRADERX_TEST_POSTGRES_PASSWORD:?set the test database password}"
fi
# Force execution even if the last Gradle run skipped the optional PostgreSQL tests.
(cd "${MATCHER_ROOT}" && bash ./gradlew test --rerun-tasks --console=plain)

# Assertions belong to state 009; the reference adapter drives the real generated JAR.
(cd "${MATCHER_ROOT}" && bash ./gradlew bootJar --console=plain)
python3 "${TARGET_ROOT}/conformance/state-009/run.py" \
  --adapter python3 "${TARGET_ROOT}/conformance/state-009/reference_adapter.py" \
  --target-root "${TARGET_ROOT}"

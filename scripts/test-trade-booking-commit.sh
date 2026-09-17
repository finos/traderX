#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT
cp -R "${ROOT}/templates/database-specfirst" "${TEST_ROOT}/database"
cp -R "${ROOT}/templates/trade-processor-specfirst" "${TEST_ROOT}/processor"
(cd "${TEST_ROOT}/database" && bash ./gradlew test --no-daemon)
(cd "${TEST_ROOT}/processor" && bash ./gradlew test --no-daemon)
cp "${ROOT}/templates/state-010-pricing-awareness-market-data-overlay/database/initialSchema.sql" "${TEST_ROOT}/database/initialSchema.sql"
(cd "${TEST_ROOT}/database" && bash ./gradlew test --rerun-tasks --no-daemon)
cp -R "${ROOT}/templates/state-010-pricing-awareness-market-data-overlay/trade-processor/." "${TEST_ROOT}/processor/"
(cd "${TEST_ROOT}/processor" && bash ./gradlew clean test --no-daemon)

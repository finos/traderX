#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
SCRIPTS_SRC="${ROOT}/scripts"
SCRIPTS_DST="${TARGET_ROOT}/scripts"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/install-generated-runtime-harness.sh <state-id> [target-root]"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

# Rebuild harness layout on each invocation to avoid stale parent-state scripts.
rm -rf "${SCRIPTS_DST}" "${TARGET_ROOT}/generated/code/components"

mkdir -p \
  "${SCRIPTS_DST}" \
  "${SCRIPTS_DST}/lib" \
  "${TARGET_ROOT}/catalog" \
  "${TARGET_ROOT}/generated/code/components"

# Compatibility layout: keep existing root scripts runnable when copied local.
ln -sfn ../.. "${TARGET_ROOT}/generated/code/target-generated"

# Copy process spec needed by uncontainerized harness.
if [[ -f "${ROOT}/catalog/base-uncontainerized-processes.csv" ]]; then
  cp "${ROOT}/catalog/base-uncontainerized-processes.csv" "${TARGET_ROOT}/catalog/"
fi

# Local helper lib used by some runtime tests.
cp "${SCRIPTS_SRC}/lib/resolve-socketio-client-path.sh" "${SCRIPTS_DST}/lib/"

copy_script_if_exists() {
  local name="$1"
  if [[ -f "${SCRIPTS_SRC}/${name}" ]]; then
    cp "${SCRIPTS_SRC}/${name}" "${SCRIPTS_DST}/"
  fi
}

# Always include helper test scripts used by state smoke wrappers.
shopt -s nullglob
for test_script in "${SCRIPTS_SRC}"/test-*.sh; do
  cp "${test_script}" "${SCRIPTS_DST}/"
done
shopt -u nullglob

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    copy_script_if_exists "start-base-uncontainerized-generated.sh"
    copy_script_if_exists "stop-base-uncontainerized-generated.sh"
    copy_script_if_exists "status-base-uncontainerized-generated.sh"
    ;;
  002-edge-proxy-uncontainerized)
    copy_script_if_exists "start-base-uncontainerized-generated.sh"
    copy_script_if_exists "stop-base-uncontainerized-generated.sh"
    copy_script_if_exists "status-base-uncontainerized-generated.sh"
    copy_script_if_exists "start-state-002-edge-proxy-generated.sh"
    copy_script_if_exists "stop-state-002-edge-proxy-generated.sh"
    copy_script_if_exists "status-state-002-edge-proxy-generated.sh"
    copy_script_if_exists "test-state-002-edge-proxy.sh"
    ;;
  003-containerized-compose-runtime)
    copy_script_if_exists "start-state-003-containerized-generated.sh"
    copy_script_if_exists "stop-state-003-containerized-generated.sh"
    copy_script_if_exists "status-state-003-containerized-generated.sh"
    copy_script_if_exists "test-state-003-containerized.sh"
    ;;
  004-postgres-database-replacement)
    copy_script_if_exists "start-state-004-postgres-database-replacement-generated.sh"
    copy_script_if_exists "stop-state-004-postgres-database-replacement-generated.sh"
    copy_script_if_exists "status-state-004-postgres-database-replacement-generated.sh"
    copy_script_if_exists "test-state-004-postgres-database-replacement.sh"
    ;;
  005-messaging-nats-replacement)
    copy_script_if_exists "start-state-005-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "stop-state-005-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "status-state-005-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "test-state-005-messaging-nats-replacement.sh"
    ;;
  006-observability-lgtm-compose)
    copy_script_if_exists "start-state-006-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "stop-state-006-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "status-state-006-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "test-state-006-observability-lgtm-compose.sh"
    ;;
  007-pricing-awareness-market-data)
    copy_script_if_exists "start-state-007-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "stop-state-007-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "status-state-007-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "test-state-007-pricing-awareness-market-data.sh"
    ;;
  008-order-management-matcher)
    copy_script_if_exists "start-state-008-order-management-matcher-generated.sh"
    copy_script_if_exists "stop-state-008-order-management-matcher-generated.sh"
    copy_script_if_exists "status-state-008-order-management-matcher-generated.sh"
    copy_script_if_exists "test-state-008-order-management-matcher.sh"
    ;;
  009-kubernetes-runtime)
    copy_script_if_exists "start-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "test-state-009-kubernetes-runtime.sh"
    ;;
  010-tilt-kubernetes-dev-loop)
    copy_script_if_exists "start-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-010-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "stop-state-010-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "status-state-010-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "test-state-010-tilt-kubernetes-dev-loop.sh"
    ;;
  011-platform-convergence-c3)
    copy_script_if_exists "start-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-011-platform-convergence-c3-generated.sh"
    copy_script_if_exists "stop-state-011-platform-convergence-c3-generated.sh"
    copy_script_if_exists "status-state-011-platform-convergence-c3-generated.sh"
    copy_script_if_exists "test-state-011-platform-convergence-c3.sh"
    ;;
  012-radius-kubernetes-platform)
    copy_script_if_exists "start-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-009-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-012-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "stop-state-012-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "status-state-012-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "test-state-012-radius-kubernetes-platform.sh"
    ;;
esac

# Mark copied scripts as local-runtime scripts and disable re-generation there.
for script in "${SCRIPTS_DST}"/*.sh; do
  [[ -f "${script}" ]] || continue
  if ! rg -q '^export TRADERX_LOCAL_RUNTIME_SCRIPT=1$' "${script}"; then
    perl -0pi -e 's#set -euo pipefail\n#set -euo pipefail\n\nexport TRADERX_LOCAL_RUNTIME_SCRIPT=1\nexport TRADERX_SKIP_GENERATE=1\nif [[ -z "\${TRADERX_GENERATED_ROOT:-}" ]]; then\n  TRADERX_GENERATED_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../../.." && pwd)"\n  export TRADERX_GENERATED_ROOT\nfi\n#' "${script}"
  fi
  chmod +x "${script}"
done
chmod +x "${SCRIPTS_DST}/lib/resolve-socketio-client-path.sh"

# Recreate component-compat symlinks used by uncontainerized/edge scripts.
link_component() {
  local component_name="$1"
  local component_rel="$2"
  local source_dir="${TARGET_ROOT}/${component_rel}"
  local link_path="${TARGET_ROOT}/generated/code/components/${component_name}-specfirst"

  if [[ -d "${source_dir}" ]]; then
    ln -sfn "../../../${component_rel}" "${link_path}"
  fi
}

link_component "reference-data" "reference-data"
link_component "database" "database"
link_component "people-service" "people-service"
link_component "account-service" "account-service"
link_component "position-service" "position-service"
link_component "trade-feed" "trade-feed"
link_component "trade-processor" "trade-processor"
link_component "trade-service" "trade-service"
link_component "web-front-end-angular" "web-front-end/angular"
link_component "edge-proxy" "edge-proxy"

cat > "${SCRIPTS_DST}/README.runtime-harness.md" <<EOM
# Generated Runtime Harness

This directory is generated for state: ${STATE_ID}

- Scripts in this folder are local-runtime wrappers for the generated codebase.
- They are designed to run without invoking root pipeline generation.
- Root repository scripts may delegate to these local scripts when present.
- State-specific usage is documented in \`../RUN_FROM_GENERATED.md\`.
EOM

write_generated_runbook() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 001)

Start:

```bash
./scripts/start-base-uncontainerized-generated.sh
```

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 002)

Start:

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```
EOF
      ;;
    003-containerized-compose-runtime)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 003)

Start:

```bash
./scripts/start-state-003-containerized-generated.sh
```

Status / stop:

```bash
./scripts/status-state-003-containerized-generated.sh
./scripts/stop-state-003-containerized-generated.sh
```

Smoke test:

```bash
./scripts/test-state-003-containerized.sh
```
EOF
      ;;
    004-postgres-database-replacement)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 004)

Start:

```bash
./scripts/start-state-004-postgres-database-replacement-generated.sh
```

Status / stop:

```bash
./scripts/status-state-004-postgres-database-replacement-generated.sh
./scripts/stop-state-004-postgres-database-replacement-generated.sh
```

Smoke test:

```bash
./scripts/test-state-004-postgres-database-replacement.sh
```
EOF
      ;;
    005-messaging-nats-replacement)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 005)

Start:

```bash
./scripts/start-state-005-messaging-nats-replacement-generated.sh
```

Status / stop:

```bash
./scripts/status-state-005-messaging-nats-replacement-generated.sh
./scripts/stop-state-005-messaging-nats-replacement-generated.sh
```

Smoke test:

```bash
./scripts/test-state-005-messaging-nats-replacement.sh
```
EOF
      ;;
    006-observability-lgtm-compose)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 006)

Start:

```bash
./scripts/start-state-006-observability-lgtm-compose-generated.sh
```

Status / stop:

```bash
./scripts/status-state-006-observability-lgtm-compose-generated.sh
./scripts/stop-state-006-observability-lgtm-compose-generated.sh
```

Smoke test:

```bash
./scripts/test-state-006-observability-lgtm-compose.sh
```
EOF
      ;;
    007-pricing-awareness-market-data)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 007)

Start:

```bash
./scripts/start-state-007-pricing-awareness-market-data-generated.sh
```

Status / stop:

```bash
./scripts/status-state-007-pricing-awareness-market-data-generated.sh
./scripts/stop-state-007-pricing-awareness-market-data-generated.sh
```

Smoke test:

```bash
./scripts/test-state-007-pricing-awareness-market-data.sh
```
EOF
      ;;
    008-order-management-matcher)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 008)

Start:

```bash
./scripts/start-state-008-order-management-matcher-generated.sh
```

Status / stop:

```bash
./scripts/status-state-008-order-management-matcher-generated.sh
./scripts/stop-state-008-order-management-matcher-generated.sh
```

Smoke test:

```bash
./scripts/test-state-008-order-management-matcher.sh
```
EOF
      ;;
    009-kubernetes-runtime)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 009)

Start:

```bash
./scripts/start-state-009-kubernetes-runtime-generated.sh
```

Status / stop:

```bash
./scripts/status-state-009-kubernetes-runtime-generated.sh
./scripts/stop-state-009-kubernetes-runtime-generated.sh
```

Smoke test:

```bash
./scripts/test-state-009-kubernetes-runtime.sh
```
EOF
      ;;
    010-tilt-kubernetes-dev-loop)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 010)

Start:

```bash
./scripts/start-state-010-tilt-kubernetes-dev-loop-generated.sh
```

Status / stop:

```bash
./scripts/status-state-010-tilt-kubernetes-dev-loop-generated.sh
./scripts/stop-state-010-tilt-kubernetes-dev-loop-generated.sh
```

Smoke test:

```bash
./scripts/test-state-010-tilt-kubernetes-dev-loop.sh
```
EOF
      ;;
    011-platform-convergence-c3)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 011)

Start:

```bash
./scripts/start-state-011-platform-convergence-c3-generated.sh
```

Status / stop:

```bash
./scripts/status-state-011-platform-convergence-c3-generated.sh
./scripts/stop-state-011-platform-convergence-c3-generated.sh
```

Smoke test:

```bash
./scripts/test-state-011-platform-convergence-c3.sh
```
EOF
      ;;
    012-radius-kubernetes-platform)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 012)

Start:

```bash
./scripts/start-state-012-radius-kubernetes-platform-generated.sh
```

Status / stop:

```bash
./scripts/status-state-012-radius-kubernetes-platform-generated.sh
./scripts/stop-state-012-radius-kubernetes-platform-generated.sh
```

Smoke test:

```bash
./scripts/test-state-012-radius-kubernetes-platform.sh
```
EOF
      ;;
    *)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated

No state-specific run instructions were generated.
EOF
      ;;
  esac
}

write_generated_runbook

echo "[ok] installed generated runtime harness for ${STATE_ID} at ${SCRIPTS_DST}"

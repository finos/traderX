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
cp "${SCRIPTS_SRC}/lib/generated-state-detection.sh" "${SCRIPTS_DST}/lib/"
if [[ -f "${SCRIPTS_SRC}/lib/runtime-common.ps1" ]]; then
  cp "${SCRIPTS_SRC}/lib/runtime-common.ps1" "${SCRIPTS_DST}/lib/"
fi
if [[ -f "${SCRIPTS_SRC}/lib/generated-state-detection.ps1" ]]; then
  cp "${SCRIPTS_SRC}/lib/generated-state-detection.ps1" "${SCRIPTS_DST}/lib/"
fi

copy_script_if_exists() {
  local name="$1"
  if [[ -f "${SCRIPTS_SRC}/${name}" ]]; then
    cp "${SCRIPTS_SRC}/${name}" "${SCRIPTS_DST}/"
  fi
  if [[ "${name}" == *.sh ]]; then
    local ps_name="${name%.sh}.ps1"
    if [[ -f "${SCRIPTS_SRC}/${ps_name}" ]]; then
      cp "${SCRIPTS_SRC}/${ps_name}" "${SCRIPTS_DST}/"
    fi
  fi
}

inject_containerized_web_ui_vite_guard() {
  local overlay_test_script="${SCRIPTS_DST}/test-web-angular-overlay.sh"
  [[ -f "${overlay_test_script}" ]] || return 0
  if rg -q 'Vite dev endpoints are not exposed' "${overlay_test_script}"; then
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  awk '
    /echo "\[check\] angular route fallback for \/trade"/ && inserted == 0 {
      print "if printf '\''%s\\n'\'' \"${root_body}\" | grep -q '\''/@vite/client'\''; then"
      print "  echo \"[error] root response unexpectedly includes Vite dev client (/@vite/client)\""
      print "  exit 1"
      print "fi"
      print "if printf '\''%s\\n'\'' \"${root_body}\" | grep -q '\''/@fs/'\''; then"
      print "  echo \"[error] root response unexpectedly includes Vite file-system dev paths (/@fs/)\""
      print "  exit 1"
      print "fi"
      print ""
      print "echo \"[check] Vite dev endpoints are not exposed\""
      print "vite_status=\"$(curl -sS -o /dev/null -w \"%{http_code}\" \"${BASE_URL}/@vite/client\")\""
      print "if [[ \"${vite_status}\" == \"200\" ]]; then"
      print "  echo \"[error] ${BASE_URL}/@vite/client should not be served in deployed/runtime images\""
      print "  exit 1"
      print "fi"
      print ""
      inserted = 1
    }
    { print }
    END {
      if (inserted == 0) {
        exit 2
      }
    }
  ' "${overlay_test_script}" > "${tmp_file}" || {
    rm -f "${tmp_file}"
    echo "[fail] unable to inject Vite guard into ${overlay_test_script}"
    exit 1
  }
  mv "${tmp_file}" "${overlay_test_script}"
}

# Always include helper test scripts used by state smoke wrappers.
shopt -s nullglob
for test_script in "${SCRIPTS_SRC}"/test-*.sh; do
  cp "${test_script}" "${SCRIPTS_DST}/"
done
for test_script in "${SCRIPTS_SRC}"/test-*.ps1; do
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
  003-agentic-harness-foundation)
    copy_script_if_exists "start-base-uncontainerized-generated.sh"
    copy_script_if_exists "stop-base-uncontainerized-generated.sh"
    copy_script_if_exists "status-base-uncontainerized-generated.sh"
    copy_script_if_exists "start-state-003-agentic-harness-foundation-generated.sh"
    copy_script_if_exists "stop-state-003-agentic-harness-foundation-generated.sh"
    copy_script_if_exists "status-state-003-agentic-harness-foundation-generated.sh"
    copy_script_if_exists "test-state-003-agentic-harness-foundation.sh"
    ;;
  004-containerized-compose-runtime)
    copy_script_if_exists "start-state-004-containerized-generated.sh"
    copy_script_if_exists "stop-state-004-containerized-generated.sh"
    copy_script_if_exists "status-state-004-containerized-generated.sh"
    copy_script_if_exists "test-state-004-containerized.sh"
    ;;
  005-postgres-database-replacement)
    copy_script_if_exists "start-state-005-postgres-database-replacement-generated.sh"
    copy_script_if_exists "stop-state-005-postgres-database-replacement-generated.sh"
    copy_script_if_exists "status-state-005-postgres-database-replacement-generated.sh"
    copy_script_if_exists "test-state-005-postgres-database-replacement.sh"
    ;;
  006-messaging-nats-replacement)
    copy_script_if_exists "start-state-006-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "stop-state-006-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "status-state-006-messaging-nats-replacement-generated.sh"
    copy_script_if_exists "test-state-006-messaging-nats-replacement.sh"
    ;;
  007-observability-lgtm-compose)
    copy_script_if_exists "start-state-007-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "stop-state-007-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "status-state-007-observability-lgtm-compose-generated.sh"
    copy_script_if_exists "test-state-007-observability-lgtm-compose.sh"
    ;;
  008-pricing-awareness-market-data)
    copy_script_if_exists "start-state-008-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "stop-state-008-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "status-state-008-pricing-awareness-market-data-generated.sh"
    copy_script_if_exists "test-state-008-pricing-awareness-market-data.sh"
    copy_script_if_exists "test-messaging-008-pricing-awareness-market-data.sh"
    ;;
  009-order-management-matcher)
    copy_script_if_exists "start-state-009-order-management-matcher-generated.sh"
    copy_script_if_exists "stop-state-009-order-management-matcher-generated.sh"
    copy_script_if_exists "status-state-009-order-management-matcher-generated.sh"
    copy_script_if_exists "test-state-009-order-management-matcher.sh"
    copy_script_if_exists "test-messaging-009-order-management-matcher.sh"
    ;;
  010-kubernetes-runtime)
    copy_script_if_exists "start-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "test-state-010-kubernetes-runtime.sh"
    ;;
  011-tilt-kubernetes-dev-loop)
    copy_script_if_exists "start-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-011-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "stop-state-011-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "status-state-011-tilt-kubernetes-dev-loop-generated.sh"
    copy_script_if_exists "test-state-011-tilt-kubernetes-dev-loop.sh"
    ;;
  012-platform-convergence-c3)
    copy_script_if_exists "start-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "stop-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "status-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "test-state-012-platform-convergence-c3.sh"
    ;;
  013-radius-kubernetes-platform)
    copy_script_if_exists "start-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-013-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "stop-state-013-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "status-state-013-radius-kubernetes-platform-generated.sh"
    copy_script_if_exists "test-state-013-radius-kubernetes-platform.sh"
    ;;
  014-fdc3-intent-interoperability)
    copy_script_if_exists "start-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "stop-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "status-state-010-kubernetes-runtime-generated.sh"
    copy_script_if_exists "start-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "stop-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "status-state-012-platform-convergence-c3-generated.sh"
    copy_script_if_exists "start-state-014-fdc3-intent-interoperability-generated.sh"
    copy_script_if_exists "stop-state-014-fdc3-intent-interoperability-generated.sh"
    copy_script_if_exists "status-state-014-fdc3-intent-interoperability-generated.sh"
    copy_script_if_exists "test-state-012-platform-convergence-c3.sh"
    copy_script_if_exists "test-state-014-fdc3-intent-interoperability.sh"
    ;;
esac

case "${STATE_ID}" in
  004-*|005-*|006-*|007-*|008-*|009-*|010-*|011-*|012-*|013-*|014-*)
    inject_containerized_web_ui_vite_guard
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
chmod +x "${SCRIPTS_DST}/lib/generated-state-detection.sh"

for script in "${SCRIPTS_DST}"/*.ps1; do
  [[ -f "${script}" ]] || continue
  if ! rg -q '^\$env:TRADERX_LOCAL_RUNTIME_SCRIPT = '\''1'\''' "${script}"; then
    perl -0pi -e 's#\$ErrorActionPreference = '\''Stop'\''\n#\$ErrorActionPreference = '\''Stop'\''\n\n\$env:TRADERX_LOCAL_RUNTIME_SCRIPT = '\''1'\''\n\$env:TRADERX_SKIP_GENERATE = '\''1'\''\nif ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('\''TRADERX_GENERATED_ROOT'\''))) {\n  \$env:TRADERX_GENERATED_ROOT = (Resolve-Path (Join-Path \$PSScriptRoot '\''../../..'\'')).Path\n}\n#' "${script}"
  fi
done

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
# Build/preflight only (no runtime start)
./scripts/start-base-uncontainerized-generated.sh --build-only

# Start runtime (will build if needed)
./scripts/start-base-uncontainerized-generated.sh
```

```powershell
# Build/preflight only (no runtime start)
./scripts/start-base-uncontainerized-generated.ps1 -BuildOnly

# Start runtime (will build if needed)
./scripts/start-base-uncontainerized-generated.ps1
```

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

```powershell
./scripts/status-base-uncontainerized-generated.ps1
./scripts/stop-base-uncontainerized-generated.ps1
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 002)

Start:

```bash
# Build/preflight only (no runtime start)
./scripts/start-state-002-edge-proxy-generated.sh --build-only

# Start runtime (will build if needed)
./scripts/start-state-002-edge-proxy-generated.sh
```

```powershell
# Build/preflight only (no runtime start)
./scripts/start-state-002-edge-proxy-generated.ps1 -BuildOnly

# Start runtime (will build if needed)
./scripts/start-state-002-edge-proxy-generated.ps1
```

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

```powershell
./scripts/status-state-002-edge-proxy-generated.ps1
./scripts/stop-state-002-edge-proxy-generated.ps1
```
EOF
      ;;
    003-agentic-harness-foundation)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 003)

Start:

```bash
# Build/preflight only (no runtime start)
./scripts/start-state-003-agentic-harness-foundation-generated.sh --build-only

# Start runtime (will build if needed)
./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

```powershell
# Build/preflight only (no runtime start)
./scripts/start-state-003-agentic-harness-foundation-generated.ps1 -BuildOnly

# Start runtime (will build if needed)
./scripts/start-state-003-agentic-harness-foundation-generated.ps1
```

Status / stop:

```bash
./scripts/status-state-003-agentic-harness-foundation-generated.sh
./scripts/stop-state-003-agentic-harness-foundation-generated.sh
```

```powershell
./scripts/status-state-003-agentic-harness-foundation-generated.ps1
./scripts/stop-state-003-agentic-harness-foundation-generated.ps1
```

Smoke test:

```bash
./scripts/test-state-003-agentic-harness-foundation.sh
```

```powershell
./scripts/test-state-003-agentic-harness-foundation.ps1
```
EOF
      ;;
    004-containerized-compose-runtime)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 004)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-004-containerized-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-004-containerized-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-004-containerized-generated.sh
./scripts/stop-state-004-containerized-generated.sh
```

Smoke test:

```bash
./scripts/test-state-004-containerized.sh
```
EOF
      ;;
    005-postgres-database-replacement)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 005)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-005-postgres-database-replacement-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-005-postgres-database-replacement-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-005-postgres-database-replacement-generated.sh
./scripts/stop-state-005-postgres-database-replacement-generated.sh
```

Smoke test:

```bash
./scripts/test-state-005-postgres-database-replacement.sh
```
EOF
      ;;
    006-messaging-nats-replacement)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 006)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-006-messaging-nats-replacement-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-006-messaging-nats-replacement-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```

Smoke test:

```bash
./scripts/test-state-006-messaging-nats-replacement.sh
```
EOF
      ;;
    007-observability-lgtm-compose)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 007)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-007-observability-lgtm-compose-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-007-observability-lgtm-compose-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-007-observability-lgtm-compose-generated.sh
./scripts/stop-state-007-observability-lgtm-compose-generated.sh
```

Smoke test:

```bash
./scripts/test-state-007-observability-lgtm-compose.sh
```
EOF
      ;;
    008-pricing-awareness-market-data)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 008)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-008-pricing-awareness-market-data-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-008-pricing-awareness-market-data-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
```

Smoke test:

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```
EOF
      ;;
    009-order-management-matcher)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 009)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-009-order-management-matcher-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-009-order-management-matcher-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-009-order-management-matcher-generated.sh
./scripts/stop-state-009-order-management-matcher-generated.sh
```

Smoke test:

```bash
./scripts/test-state-009-order-management-matcher.sh
./scripts/test-state-009-order-management-matcher.sh --skip-messaging
./scripts/test-messaging-009-order-management-matcher.sh
```
EOF
      ;;
    010-kubernetes-runtime)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 010)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-010-kubernetes-runtime-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh
./scripts/stop-state-010-kubernetes-runtime-generated.sh
```

Smoke test:

```bash
./scripts/test-state-010-kubernetes-runtime.sh
```
EOF
      ;;
    011-tilt-kubernetes-dev-loop)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 011)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-011-tilt-kubernetes-dev-loop-generated.sh
./scripts/stop-state-011-tilt-kubernetes-dev-loop-generated.sh
```

Smoke test:

```bash
./scripts/test-state-011-tilt-kubernetes-dev-loop.sh
```
EOF
      ;;
    012-platform-convergence-c3)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 012)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-012-platform-convergence-c3-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-012-platform-convergence-c3-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-012-platform-convergence-c3-generated.sh
./scripts/stop-state-012-platform-convergence-c3-generated.sh
```

Smoke test:

```bash
./scripts/test-state-012-platform-convergence-c3.sh
```
EOF
      ;;
    013-radius-kubernetes-platform)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 013)

Start (choose one):

```bash
# Full start (build + start)
./scripts/start-state-013-radius-kubernetes-platform-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-013-radius-kubernetes-platform-generated.sh --skip-build
```

Status / stop:

```bash
./scripts/status-state-013-radius-kubernetes-platform-generated.sh
./scripts/stop-state-013-radius-kubernetes-platform-generated.sh
```

Smoke test:

```bash
./scripts/test-state-013-radius-kubernetes-platform.sh
```
EOF
      ;;
    014-fdc3-intent-interoperability)
      cat > "${TARGET_ROOT}/RUN_FROM_GENERATED.md" <<'EOF'
# Run From Generated (State 014)

Start baseline C3 runtime (choose one):

```bash
# Full start (build + start)
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh

# Fast restart (reuse existing artifacts; skips build)
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --skip-build
```

Start C3 + Sail sidecar:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --with-sail
```

Status / stop:

```bash
./scripts/status-state-014-fdc3-intent-interoperability-generated.sh --with-sail
./scripts/stop-state-014-fdc3-intent-interoperability-generated.sh --with-sail
```

Smoke test:

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
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

generated_runtime_urls_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- UI: `http://localhost:18093`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Account service Swagger: `http://localhost:18088/v3/api-docs`
EOF
      ;;
    002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
      cat <<'EOF'
- UI (edge): `http://localhost:18080`
- API explorer (edge): `http://localhost:18080/api/docs`
- Trade service Swagger (edge): `http://localhost:18080/trade-service/v3/api-docs`
- Account service Swagger (edge): `http://localhost:18080/account-service/v3/api-docs`
EOF
      ;;
    004-containerized-compose-runtime|005-postgres-database-replacement|006-messaging-nats-replacement|008-pricing-awareness-market-data)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Account service API sample: `http://localhost:18088/account/22214`
- Position service health: `http://localhost:18090/health/alive`
EOF
      ;;
    007-observability-lgtm-compose)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
EOF
      ;;
    009-order-management-matcher)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Order matcher health: `http://localhost:18110/health`
- Order matcher metrics: `http://localhost:18110/metrics`
EOF
      ;;
    010-kubernetes-runtime|011-tilt-kubernetes-dev-loop|012-platform-convergence-c3|013-radius-kubernetes-platform)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade page: `http://localhost:8080/trade`
- Account service route: `http://localhost:8080/account-service/account/22214`
- Position service route: `http://localhost:8080/position-service/positions/22214`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Prometheus (ingress): `http://localhost:8080/prometheus`
EOF
      ;;
    014-fdc3-intent-interoperability)
      cat <<'EOF'
- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade page: `http://localhost:8080/trade`
- Account service route: `http://localhost:8080/account-service/account/22214`
- Position service route: `http://localhost:8080/position-service/positions/22214`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Prometheus (ingress): `http://localhost:8080/prometheus`
- Sail sidecar UI: `http://localhost:8090`
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

write_generated_agentic_docs() {
  local state_num="${STATE_ID%%-*}"
  if [[ ! "${state_num}" =~ ^[0-9]+$ ]] || (( 10#${state_num} < 3 )); then
    return
  fi

  cat > "${TARGET_ROOT}/AGENTS.md" <<EOF
# AGENTS.md

This generated codebase is a reproducible runtime snapshot for state \`${STATE_ID}\`.

- Treat this snapshot as generated output; expect it to be replaced on regeneration.
- Prototype and experiment locally here when needed.
- Promote durable changes into upstream state packs and specs, not generated snapshots.
- Use \`./scripts\` and \`./RUN_FROM_GENERATED.md\` as the runtime entrypoints.
EOF

  cat > "${TARGET_ROOT}/ARCHITECTURE.md" <<EOF
# ARCHITECTURE.md

This snapshot was generated from TraderX state \`${STATE_ID}\`.

- Service/runtime topology is defined by the source state pack in the upstream repository.
- This generated directory contains runnable artifacts, not the authoritative architecture source.
- Rebuild this snapshot through the generation pipeline instead of manually editing generated files.
EOF

  cat > "${TARGET_ROOT}/CONTRIBUTING.md" <<EOF
# CONTRIBUTING.md

This directory is generated output.

- Enhancement contributions should be made in upstream \`specs/\` state packs and generation pipeline artifacts.
- Generated snapshots are outputs and are routinely replaced during regeneration.
- Local edits here are useful for experimentation and debugging, then should be translated back into specs/state packs.
EOF
}

write_generated_runbook
if generated_runtime_urls_markdown >/tmp/traderx-runtime-urls.$$; then
  {
    echo
    echo "## Interactive URLs"
    echo
    cat /tmp/traderx-runtime-urls.$$
  } >> "${TARGET_ROOT}/RUN_FROM_GENERATED.md"
  rm -f /tmp/traderx-runtime-urls.$$
fi
write_generated_agentic_docs

echo "[ok] installed generated runtime harness for ${STATE_ID} at ${SCRIPTS_DST}"

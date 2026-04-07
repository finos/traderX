#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/traderx-runtime-harness.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TARGET_ROOT="${TMP_DIR}/generated/code/target-generated"
mkdir -p "${TARGET_ROOT}/containerized-compose" "${TARGET_ROOT}/web-front-end/angular"
touch "${TARGET_ROOT}/containerized-compose/docker-compose.yml"

echo "[check] install harness into synthetic target-generated root"
bash "${ROOT}/pipeline/install-generated-runtime-harness.sh" 003-containerized-compose-runtime "${TARGET_ROOT}"

for required in \
  "${TARGET_ROOT}/scripts/start-state-003-containerized-generated.sh" \
  "${TARGET_ROOT}/scripts/stop-state-003-containerized-generated.sh" \
  "${TARGET_ROOT}/scripts/status-state-003-containerized-generated.sh" \
  "${TARGET_ROOT}/scripts/README.runtime-harness.md" \
  "${TARGET_ROOT}/RUN_FROM_GENERATED.md"; do
  [[ -f "${required}" ]] || {
    echo "[fail] missing generated harness artifact: ${required}"
    exit 1
  }
done

echo "[check] local harness scripts are marked local + skip-generate"
grep -q '^export TRADERX_LOCAL_RUNTIME_SCRIPT=1$' "${TARGET_ROOT}/scripts/start-state-003-containerized-generated.sh"
grep -q '^export TRADERX_SKIP_GENERATE=1$' "${TARGET_ROOT}/scripts/start-state-003-containerized-generated.sh"
grep -q 'TRADERX_GENERATED_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE\[0\]}")/../../.." && pwd)"' "${TARGET_ROOT}/scripts/start-state-003-containerized-generated.sh"
grep -q './scripts/start-state-003-containerized-generated.sh' "${TARGET_ROOT}/RUN_FROM_GENERATED.md"

echo "[check] root wrapper forwards execution to local harness when present"
cat > "${TARGET_ROOT}/scripts/status-base-uncontainerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "[ok] forwarded-to-local-runtime-harness"
EOF
chmod +x "${TARGET_ROOT}/scripts/status-base-uncontainerized-generated.sh"

forward_output="$(
  TRADERX_GENERATED_ROOT="${TMP_DIR}/generated" \
    bash "${ROOT}/scripts/status-base-uncontainerized-generated.sh"
)"

printf '%s\n' "${forward_output}" | grep -q "forwarded-to-local-runtime-harness" || {
  echo "[fail] root script did not forward to local runtime harness"
  exit 1
}

echo "[done] generated runtime harness checks passed"

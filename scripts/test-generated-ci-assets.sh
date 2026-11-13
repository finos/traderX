#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/traderx-ci-assets.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TARGET_ROOT="${TMP_DIR}/generated/code/target-generated"
mkdir -p "${TARGET_ROOT}"

echo "[check] state 002 installs security/license workflows and suppression files"
mkdir -p \
  "${TARGET_ROOT}/reference-data" \
  "${TARGET_ROOT}/web-front-end/angular" \
  "${TARGET_ROOT}/account-service" \
  "${TARGET_ROOT}/people-service" \
  "${TARGET_ROOT}/ingress"
touch \
  "${TARGET_ROOT}/reference-data/package.json" \
  "${TARGET_ROOT}/web-front-end/angular/package.json" \
  "${TARGET_ROOT}/account-service/build.gradle" \
  "${TARGET_ROOT}/people-service/people-service.csproj" \
  "${TARGET_ROOT}/ingress/Dockerfile.compose"

bash "${ROOT}/pipeline/install-generated-ci-assets.sh" 002-edge-proxy-uncontainerized "${TARGET_ROOT}"

for required in \
  "${TARGET_ROOT}/.github/workflows/security.yml" \
  "${TARGET_ROOT}/.github/workflows/license-scanning-node.yml" \
  "${TARGET_ROOT}/.github/gradle-cve-ignore-list.xml" \
  "${TARGET_ROOT}/.github/node-cve-ignore-list.xml" \
  "${TARGET_ROOT}/.github/dotnet-cve-ignore-list.xml" \
  "${TARGET_ROOT}/ci/state-metadata.json"; do
  [[ -f "${required}" ]] || {
    echo "[fail] missing generated CI artifact: ${required}"
    exit 1
  }
done

grep -q "name: Prepare artifact name" "${TARGET_ROOT}/.github/workflows/security.yml" || {
  echo "[fail] security workflow should include artifact-name preparation step"
  exit 1
}

grep -q "security-node-\${{ env.UPNAME }}" "${TARGET_ROOT}/.github/workflows/security.yml" || {
  echo "[fail] security workflow should use sanitized node artifact names"
  exit 1
}

grep -q "security-dotnet-\${{ env.UPNAME }}" "${TARGET_ROOT}/.github/workflows/security.yml" || {
  echo "[fail] security workflow should use sanitized dotnet artifact names"
  exit 1
}

grep -q "security-gradle-\${{ env.UPNAME }}" "${TARGET_ROOT}/.github/workflows/security.yml" || {
  echo "[fail] security workflow should use sanitized gradle artifact names"
  exit 1
}

grep -q "JAVA_HOME: /opt/jdk" "${TARGET_ROOT}/.github/workflows/security.yml" || {
  echo "[fail] security workflow should set JAVA_HOME=/opt/jdk for dependency-check"
  exit 1
}

[[ ! -f "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" ]] || {
  echo "[fail] state 002 should not generate convergence build-and-publish workflow"
  exit 1
}
[[ ! -d "${TARGET_ROOT}/runtime/deploy" ]] || {
  echo "[fail] state 002 should not generate deployment bundles"
  exit 1
}

echo "[check] state 009 generates convergence workflows + GHCR run bundle"
rm -rf "${TARGET_ROOT}"
mkdir -p \
  "${TARGET_ROOT}/api-explorer" \
  "${TARGET_ROOT}/reference-data" \
  "${TARGET_ROOT}/web-front-end/angular" \
  "${TARGET_ROOT}/order-matcher" \
  "${TARGET_ROOT}/ingress" \
  "${TARGET_ROOT}/order-management-matcher"
touch \
  "${TARGET_ROOT}/api-explorer/Dockerfile" \
  "${TARGET_ROOT}/reference-data/package.json" \
  "${TARGET_ROOT}/web-front-end/angular/package.json" \
  "${TARGET_ROOT}/order-matcher/Dockerfile.compose" \
  "${TARGET_ROOT}/ingress/Dockerfile.compose"
cat > "${TARGET_ROOT}/order-management-matcher/docker-compose.yml" <<'EOF'
name: traderx-state-009
services:
  reference-data:
    build:
      context: ../reference-data
      dockerfile: Dockerfile.compose
  web-front-end-angular:
    build:
      context: ../web-front-end/angular
      dockerfile: Dockerfile.compose
  ingress:
    build:
      context: ../ingress
      dockerfile: Dockerfile.compose
  database:
    image: postgres:16-alpine
volumes:
  postgres_state_009_data: {}
EOF

bash "${ROOT}/pipeline/install-generated-ci-assets.sh" 009-order-management-matcher "${TARGET_ROOT}"

for required in \
  "${TARGET_ROOT}/.github/workflows/security.yml" \
  "${TARGET_ROOT}/.github/workflows/license-scanning-node.yml" \
  "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" \
  "${TARGET_ROOT}/runtime/ghcr/009-order-management-matcher/README.md" \
  "${TARGET_ROOT}/runtime/ghcr/009-order-management-matcher/images.lock" \
  "${TARGET_ROOT}/runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml" \
  "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/README.md" \
  "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" \
  "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/upgrade.sh" \
  "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/cleanup.sh" \
  "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/nginx.reverse-proxy.snippet.conf"; do
  [[ -f "${required}" ]] || {
    echo "[fail] missing convergence CI artifact: ${required}"
    exit 1
  }
done

grep -q 'IMAGE_NAMESPACE: traderx-c2' "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" || {
  echo "[fail] convergence namespace traderx-c2 not found in build-and-publish workflow"
  exit 1
}

grep -q 'GHCR_PUSH_TOKEN' "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" || {
  echo "[fail] build-and-publish workflow should support GHCR_PUSH_TOKEN fallback auth"
  exit 1
}

if grep -q 'directory: api-explorer' "${TARGET_ROOT}/.github/workflows/build-and-publish.yml"; then
  echo "[fail] api-explorer should not be included in generated container CI matrix"
  exit 1
fi

grep -q 'ghcr.io/finos/traderx-c2' "${TARGET_ROOT}/runtime/ghcr/009-order-management-matcher/images.lock" || {
  echo "[fail] ghcr namespace mapping missing from images.lock"
  exit 1
}

grep -q -- '--dry-run' "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" || {
  echo "[fail] deploy bundle should support --dry-run"
  exit 1
}

grep -q -- '--use-ghcr' "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" || {
  echo "[fail] deploy bundle should support --use-ghcr"
  exit 1
}

grep -q 'TRADERX_GHCR_COMPOSE_PATH_REL' "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" || {
  echo "[fail] deploy bundle should support GHCR compose path override"
  exit 1
}

if rg -qi 'token|password' "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh"; then
  echo "[fail] deploy bundle should not embed credentials/tokens"
  exit 1
fi

echo "[check] generated deployment requires snapshot checks and scanned digest evidence"
python3 - "${TARGET_ROOT}" <<'PYTEST'
from pathlib import Path
import sys
root = Path(sys.argv[1])
publish = (root / '.github/workflows/build-and-publish.yml').read_text()
assert 'id: publish' in publish
assert '@${{ steps.publish.outputs.digest }}' in publish
assert 'image-digest-${{ matrix.image_name }}-${{ github.run_attempt }}' in publish
assert (root / '.github/workflows/build-and-test.yml').exists()
assert 'paths:' not in (root / '.github/workflows/security.yml').read_text()
assert 'paths:' not in publish
assert 'name: Runtime Image Security' in publish
assert 'needs: build-ghcr' in publish
assert 'kubernetesManifestRenderer.version' in publish
assert 'kubernetesManifestRenderer.sha256' in publish
assert 'sha256sum --check' in publish
assert 'kubernetesManifestParser' in publish
assert 'runtime-lock-${{ github.run_attempt }}' in publish
assert 'runtime-security-diagnostics-${{ github.run_attempt }}' in publish
assert 'platforms: linux/amd64' in publish
import json
assert json.loads((root / 'ci/state-metadata.json').read_text())['runtime'] == {
    'kind': 'compose', 'path': 'runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml'}
for helper in ['runtime_image_security.py', 'dependency-version-targets.json']:
    assert (root / 'ci' / helper).is_file()
deploy = (root / 'runtime/deploy/aws-ec2-compose/deploy.sh').read_text()
assert 'TRADERX_SNAPSHOT' in deploy
assert 'verify-deployment-snapshot.py' in deploy
assert 'deploy-verified-snapshot.py' in deploy
for name in ['verify-deployment-snapshot.py', 'deploy-verified-snapshot.py', 'deployment-catalog.json']:
    assert (root / 'ci' / name).is_file()
PYTEST
bash -n "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh"
if command -v actionlint >/dev/null 2>&1; then
  actionlint -shellcheck= "${TARGET_ROOT}/.github/workflows/build-and-test.yml" "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" "${TARGET_ROOT}/.github/workflows/security.yml"
fi
TRADERX_SNAPSHOT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bash "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" --use-ghcr --dry-run
if TRADERX_SNAPSHOT=latest bash "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/deploy.sh" --use-ghcr --dry-run; then
  echo "[fail] mutable snapshot was accepted"
  exit 1
fi

echo "[check] state 012 publishes and scans its active api-explorer runtime"
rm -rf "${TARGET_ROOT}"
mkdir -p \
  "${TARGET_ROOT}/api-explorer" \
  "${TARGET_ROOT}/ingress" \
  "${TARGET_ROOT}/scripts" \
  "${TARGET_ROOT}/kubernetes-runtime/manifests/base"
printf '%s\n' '{"images":[]}' > "${TARGET_ROOT}/kubernetes-runtime/build-plan.json"
touch \
  "${TARGET_ROOT}/api-explorer/Dockerfile" \
  "${TARGET_ROOT}/ingress/Dockerfile.compose"
cat > "${TARGET_ROOT}/scripts/start-state-012-platform-convergence-c3-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

TRADERX_USE_PUBLISHED_IMAGES="${TRADERX_USE_PUBLISHED_IMAGES:-0}"
TRADERX_PUBLISHED_NAMESPACE="${TRADERX_PUBLISHED_NAMESPACE:-}"
TRADERX_PUBLISHED_TAG="${TRADERX_PUBLISHED_TAG:-latest}"

echo "published image mode: ${TRADERX_USE_PUBLISHED_IMAGES} ${TRADERX_PUBLISHED_NAMESPACE} ${TRADERX_PUBLISHED_TAG}"
EOF

bash "${ROOT}/pipeline/install-generated-ci-assets.sh" 012-platform-convergence-c3 "${TARGET_ROOT}"

grep -q 'directory: ingress' "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" || {
  echo "[fail] state 012 should publish retained ingress container image"
  exit 1
}

if ! grep -q 'directory: api-explorer' "${TARGET_ROOT}/.github/workflows/build-and-publish.yml"; then
  echo "[fail] active api-explorer must be published for complete immutable runtime coverage"
  exit 1
fi

grep -q 'ingress=ghcr.io/finos/traderx-c3/ingress:latest' "${TARGET_ROOT}/runtime/ghcr/012-platform-convergence-c3/images.lock" || {
  echo "[fail] state 012 GHCR image map should include publishable ingress image"
  exit 1
}

grep -q 'directory: api-explorer' "${TARGET_ROOT}/.github/workflows/security.yml"

jq -e '.runtime.kind == "kubernetes" and .runtime.path == "kubernetes-runtime/manifests/base" and .runtime.buildPlan == "kubernetes-runtime/build-plan.json"' "${TARGET_ROOT}/ci/state-metadata.json" >/dev/null

echo "[check] generated-state contract validation guards order-matcher schema"
mkdir -p "${TARGET_ROOT}/order-matcher" "${TARGET_ROOT}/database" "${TARGET_ROOT}/ci"
cat > "${TARGET_ROOT}/ci/state-metadata.json" <<'EOF'
{
  "stateId": "009-order-management-matcher"
}
EOF
cat > "${TARGET_ROOT}/database/initialSchema.sql" <<'EOF'
CREATE TABLE Accounts (ID INTEGER PRIMARY KEY);
EOF
if bash "${ROOT}/pipeline/validate-generated-state-contracts.sh" "${TARGET_ROOT}" >/dev/null 2>&1; then
  echo "[fail] contract validator should fail when OrderBook table is missing"
  exit 1
fi
cat > "${TARGET_ROOT}/database/initialSchema.sql" <<'EOF'
CREATE TABLE Accounts (ID INTEGER PRIMARY KEY);
CREATE TABLE OrderBook (
  OrderId VARCHAR(32) PRIMARY KEY,
  Status VARCHAR(24)
);
EOF
bash "${ROOT}/pipeline/validate-generated-state-contracts.sh" "${TARGET_ROOT}" >/dev/null

echo "[check] template Node.js packages declare Apache-2.0"
while IFS= read -r pkg; do
  license="$(jq -r '.license // empty' "${pkg}")"
  if [[ "${license}" != "Apache-2.0" ]]; then
    echo "[fail] Node template package license must be Apache-2.0: ${pkg} (found: ${license:-<missing>})"
    exit 1
  fi
done < <(find "${ROOT}/templates" -type d -name node_modules -prune -o -name package.json -print | sort)

echo "[check] state 014 builds and scans dedicated Sail companion without publication"
mkdir -p "${TARGET_ROOT}/fdc3-intent-interoperability/sail/runtime-images/sail"
cp "${ROOT}/templates/runtime-image-rebuilds/sail/Dockerfile" "${TARGET_ROOT}/fdc3-intent-interoperability/sail/runtime-images/sail/Dockerfile.compose"
printf '%s\n' 'services:' '  sail:' '    image: traderx-remediation/sail:014' > "${TARGET_ROOT}/fdc3-intent-interoperability/sail/docker-compose.yml"
bash "${ROOT}/pipeline/install-generated-ci-assets.sh" 014-fdc3-intent-interoperability "${TARGET_ROOT}"
jq -e '.modules.docker | any(.imageName == "sail" and .directory == "fdc3-intent-interoperability/sail/runtime-images/sail")' "${TARGET_ROOT}/ci/state-metadata.json" >/dev/null
[[ ! -f "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" ]]
grep -q 'fdc3-intent-interoperability/sail/runtime-images/sail' "${TARGET_ROOT}/.github/workflows/build-container-images.yml"
grep -q 'fdc3-intent-interoperability/sail/runtime-images/sail' "${TARGET_ROOT}/.github/workflows/security.yml"
jq -e '.runtime.companions[0].path == "fdc3-intent-interoperability/sail/docker-compose.yml"' "${TARGET_ROOT}/ci/state-metadata.json" >/dev/null

grep -q 'Runtime Image Security (build only)' "${TARGET_ROOT}/.github/workflows/security.yml"
grep -q 'needs: docker-image-scan' "${TARGET_ROOT}/.github/workflows/security.yml"
grep -q 'local-image-.*github.run_attempt' "${TARGET_ROOT}/.github/workflows/security.yml"
grep -q 'nonpublishing_runtime_security.py --artifacts local-images' "${TARGET_ROOT}/.github/workflows/security.yml"
[[ -f "${TARGET_ROOT}/ci/nonpublishing_runtime_security.py" ]]
! grep -q 'name: runtime-lock-' "${TARGET_ROOT}/.github/workflows/security.yml"
if command -v actionlint >/dev/null 2>&1; then
  actionlint -shellcheck= "${TARGET_ROOT}/.github/workflows/security.yml" "${TARGET_ROOT}/.github/workflows/build-container-images.yml"
fi

for mapping in '005-postgres-database-replacement:postgres-database-replacement' '006-messaging-nats-replacement:messaging-nats-replacement' '008-pricing-awareness-market-data:pricing-awareness-market-data'; do
  state="${mapping%%:*}"
  runtime="${mapping#*:}"
  local_target="${TMP_DIR}/${state}"
  mkdir -p "${local_target}/reference-data" "${local_target}/${runtime}"
  printf '%s\n' 'FROM scratch' > "${local_target}/reference-data/Dockerfile.compose"
  printf '%s\n' 'services:' '  app:' '    build:' '      context: ../reference-data' '      dockerfile: Dockerfile.compose' > "${local_target}/${runtime}/docker-compose.yml"
  bash "${ROOT}/pipeline/install-generated-ci-assets.sh" "${state}" "${local_target}"
  jq -e --arg path "${runtime}/docker-compose.yml" '.runtime.kind == "compose" and .runtime.path == $path' "${local_target}/ci/state-metadata.json" >/dev/null
  grep -q 'Runtime Image Security (build only)' "${local_target}/.github/workflows/security.yml"
  [[ ! -f "${local_target}/.github/workflows/build-and-publish.yml" ]]
done

mkdir -p "${TARGET_ROOT}/kubernetes-runtime/runtime-images/sail"
printf '%s\n' 'FROM scratch' > "${TARGET_ROOT}/kubernetes-runtime/runtime-images/sail/Dockerfile.compose"
if bash "${ROOT}/pipeline/install-generated-ci-assets.sh" 014-fdc3-intent-interoperability "${TARGET_ROOT}" > "${TMP_DIR}/duplicates.log" 2>&1; then
  echo "[fail] duplicate Sail image names must block CI metadata generation"
  exit 1
fi
grep -q 'duplicate Docker image names' "${TMP_DIR}/duplicates.log"

echo "[done] generated CI assets checks passed"

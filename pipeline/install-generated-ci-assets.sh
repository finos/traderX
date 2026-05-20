#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
CATALOG="${ROOT}/catalog/state-catalog.json"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/install-generated-ci-assets.sh <state-id> [target-root]"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

state_num="${STATE_ID%%-*}"
if [[ ! "${state_num}" =~ ^[0-9]+$ ]]; then
  echo "[fail] invalid state id format: ${STATE_ID}"
  exit 1
fi

if (( 10#${state_num} < 2 )); then
  echo "[info] skipping generated CI assets for ${STATE_ID} (policy starts at state 002)"
  exit 0
fi

enable_container_ci=0
if (( 10#${state_num} >= 4 )); then
  enable_container_ci=1
fi

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

state_entry="$(jq -c --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}")"
if [[ -z "${state_entry}" ]]; then
  echo "[fail] state ${STATE_ID} not found in catalog"
  exit 1
fi

is_convergence="$(jq -r '.isConvergence // false' <<<"${state_entry}")"
convergence_level="$(jq -r '.convergenceLevel // "none"' <<<"${state_entry}")"
convergence_level_lc="$(printf '%s' "${convergence_level}" | tr '[:upper:]' '[:lower:]')"
convergence_namespace=""
deploy_enabled="$(jq -r '(.deploy.enabled // false) | if . then "true" else "false" end' <<<"${state_entry}")"
deploy_profile="$(jq -r '.deploy.profile // ""' <<<"${state_entry}")"
deploy_environment="$(jq -r '.deploy.environment // ""' <<<"${state_entry}")"
deploy_domain_hint="$(jq -r '.deploy.domain // ""' <<<"${state_entry}")"
publish_branch="$(jq -r '.publish.branch // ""' <<<"${state_entry}")"
case "${convergence_level}" in
  C0|C1|C2|C3)
    convergence_namespace="traderx-${convergence_level_lc}"
    ;;
esac

node_modules=()
gradle_modules=()
dotnet_modules=()
docker_entries=()
compose_file_rel=""
state_allowed_roots=()

temp_dir="$(mktemp -d /tmp/traderx-generated-ci.XXXXXX)"
trap 'rm -rf "${temp_dir}"' EXIT

is_ignored_dir() {
  local rel="$1"
  case "${rel}" in
    .github*|runtime/*|scripts*|catalog*|generated/*|docs/*|ci/*|spec-source/*|.run/*|\
    *runtime-cache/*|runtime-cache/*|\
    *node_modules/*|node_modules/*|\
    *.vite/*|.vite/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

CORE_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "reference-data"
  "trade-feed"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

NATS_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

PRICING_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

ORDER_COMPONENT_DIRS=(
  "account-service"
  "database"
  "order-matcher"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

C2_COMPONENT_DIRS=(
  "account-service"
  "database"
  "ingress"
  "order-matcher"
  "people-service"
  "position-service"
  "price-publisher"
  "reference-data"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    state_allowed_roots=("${CORE_COMPONENT_DIRS[@]}")
    ;;
  002-edge-proxy-uncontainerized|003-agentic-harness-foundation)
    state_allowed_roots=("${CORE_COMPONENT_DIRS[@]}" "edge-proxy")
    ;;
  004-containerized-compose-runtime)
    state_allowed_roots=("${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress")
    ;;
  005-postgres-database-replacement)
    state_allowed_roots=("${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress" "postgres-database-replacement")
    ;;
  006-messaging-nats-replacement)
    state_allowed_roots=("${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "postgres-database-replacement")
    ;;
  007-observability-lgtm-compose)
    state_allowed_roots=("${NATS_COMPONENT_DIRS[@]}" "ingress" "messaging-nats-replacement" "observability-lgtm-compose" "postgres-database-replacement")
    ;;
  008-pricing-awareness-market-data)
    state_allowed_roots=("${PRICING_COMPONENT_DIRS[@]}" "ingress" "pricing-awareness-market-data" "postgres-database-replacement")
    ;;
  009-order-management-matcher)
    state_allowed_roots=("${ORDER_COMPONENT_DIRS[@]}" "ingress" "order-management-matcher" "postgres-database-replacement")
    ;;
  010-kubernetes-runtime)
    state_allowed_roots=("${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime")
    ;;
  011-tilt-kubernetes-dev-loop|012-platform-convergence-c3)
    state_allowed_roots=("${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop")
    ;;
  013-radius-kubernetes-platform)
    state_allowed_roots=("${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "radius-kubernetes-platform")
    ;;
  014-fdc3-intent-interoperability)
    state_allowed_roots=("${C2_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop" "fdc3-intent-interoperability")
    ;;
esac

state_allows_dir() {
  local rel="$1"
  if ((${#state_allowed_roots[@]} == 0)); then
    return 0
  fi
  local top_level="${rel%%/*}"
  local allowed
  for allowed in "${state_allowed_roots[@]}"; do
    if [[ "${top_level}" == "${allowed}" ]]; then
      return 0
    fi
  done
  return 1
}

add_unique_line() {
  local file="$1"
  local line="$2"
  if [[ -z "${line}" ]]; then
    return
  fi
  if ! grep -Fx "${line}" "${file}" >/dev/null 2>&1; then
    printf '%s\n' "${line}" >> "${file}"
  fi
}

discover_node_modules() {
  local out_file="$1"
  : > "${out_file}"
  while IFS= read -r package_json; do
    [[ -z "${package_json}" ]] && continue
    rel="${package_json#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    state_allows_dir "${dir}" || continue
    add_unique_line "${out_file}" "${dir}"
  done < <(find "${TARGET_ROOT}" \
    -type f -name package.json \
    -not -path '*/node_modules/*' \
    -not -path '*/runtime-cache/*' \
    -not -path '*/.vite/*' | sort)
  sort -u -o "${out_file}" "${out_file}"
}

discover_gradle_modules() {
  local out_file="$1"
  : > "${out_file}"
  while IFS= read -r gradle_file; do
    [[ -z "${gradle_file}" ]] && continue
    rel="${gradle_file#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    state_allows_dir "${dir}" || continue
    add_unique_line "${out_file}" "${dir}"
  done < <(find "${TARGET_ROOT}" -type f \( -name build.gradle -o -name build.gradle.kts \) | sort)
  sort -u -o "${out_file}" "${out_file}"
}

discover_dotnet_modules() {
  local out_file="$1"
  : > "${out_file}"
  while IFS= read -r csproj_file; do
    [[ -z "${csproj_file}" ]] && continue
    rel="${csproj_file#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    state_allows_dir "${dir}" || continue
    add_unique_line "${out_file}" "${dir}"
  done < <(find "${TARGET_ROOT}" -type f -name '*.csproj' | sort)
  sort -u -o "${out_file}" "${out_file}"
}

docker_dir_exists() {
  local dir="$1"
  local entries_file="$2"
  grep -q "^${dir}|" "${entries_file}" >/dev/null 2>&1
}

skip_docker_ci_dir() {
  local dir="$1"
  case "${dir}" in
    api-explorer)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

discover_docker_entries() {
  local out_file="$1"
  : > "${out_file}"

  # Container build CI starts at state 004 onward.
  if (( enable_container_ci == 0 )); then
    return
  fi

  while IFS= read -r dockerfile; do
    [[ -z "${dockerfile}" ]] && continue
    rel="${dockerfile#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    state_allows_dir "${dir}" || continue
    skip_docker_ci_dir "${dir}" && continue
    image_name="$(printf '%s' "${dir}" | tr '/' '-')"
    printf '%s|%s|%s\n' "${dir}" "$(basename "${dockerfile}")" "${image_name}" >> "${out_file}"
  done < <(find "${TARGET_ROOT}" -type f -name Dockerfile.compose | sort)

  while IFS= read -r dockerfile; do
    [[ -z "${dockerfile}" ]] && continue
    rel="${dockerfile#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    state_allows_dir "${dir}" || continue
    skip_docker_ci_dir "${dir}" && continue
    if docker_dir_exists "${dir}" "${out_file}"; then
      continue
    fi
    image_name="$(printf '%s' "${dir}" | tr '/' '-')"
    printf '%s|%s|%s\n' "${dir}" "$(basename "${dockerfile}")" "${image_name}" >> "${out_file}"
  done < <(find "${TARGET_ROOT}" -type f -name Dockerfile | sort)

  sort -u -o "${out_file}" "${out_file}"
}

discover_node_modules "${temp_dir}/node-modules.txt"
discover_gradle_modules "${temp_dir}/gradle-modules.txt"
discover_dotnet_modules "${temp_dir}/dotnet-modules.txt"
discover_docker_entries "${temp_dir}/docker-entries.txt"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  node_modules+=("${line}")
done < "${temp_dir}/node-modules.txt"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  gradle_modules+=("${line}")
done < "${temp_dir}/gradle-modules.txt"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  dotnet_modules+=("${line}")
done < "${temp_dir}/dotnet-modules.txt"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  docker_entries+=("${line}")
done < "${temp_dir}/docker-entries.txt"

case "${STATE_ID}" in
  004-containerized-compose-runtime)
    compose_file_rel="containerized-compose/docker-compose.yml"
    ;;
  007-observability-lgtm-compose)
    compose_file_rel="observability-lgtm-compose/docker-compose.yml"
    ;;
  009-order-management-matcher)
    compose_file_rel="order-management-matcher/docker-compose.yml"
    ;;
  *)
    compose_file_rel=""
    ;;
esac

mkdir -p "${TARGET_ROOT}/.github/workflows" "${TARGET_ROOT}/ci"
rm -rf "${TARGET_ROOT}/runtime/ghcr"
rm -rf "${TARGET_ROOT}/runtime/deploy"

for suppression in gradle-cve-ignore-list.xml node-cve-ignore-list.xml dotnet-cve-ignore-list.xml; do
  if [[ -f "${ROOT}/.github/${suppression}" ]]; then
    cp "${ROOT}/.github/${suppression}" "${TARGET_ROOT}/.github/${suppression}"
  fi
done

write_security_workflow() {
  local file_path="$1"
  cat > "${file_path}" <<'EOF'
name: Security Scanning

on:
  workflow_dispatch:
  push:
    paths:
      - '**/build.gradle'
      - '**/build.gradle.kts'
      - '**/package.json'
      - '**/package-lock.json'
      - '**/*.csproj'
      - '.github/*-cve-ignore-list.xml'
      - '.github/workflows/security.yml'
EOF

  if ((${#docker_entries[@]} > 0)); then
    {
      echo "      - '**/Dockerfile'"
      echo "      - '**/Dockerfile.compose'"
    } >> "${file_path}"
  fi

  cat >> "${file_path}" <<'EOF'

jobs:
EOF

  local job_count=0

  if ((${#node_modules[@]} > 0)); then
    job_count=$((job_count + 1))
    cat >> "${file_path}" <<'EOF'
  node-modules-scan:
    name: ${{ matrix.module_folder }}-node-scan
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        module_folder:
EOF
    for module in "${node_modules[@]}"; do
      printf '          - %s\n' "${module}" >> "${file_path}"
    done
    cat >> "${file_path}" <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install production dependencies
        run: npm install --omit=dev
        working-directory: ${{ matrix.module_folder }}
      - name: Prepare artifact name
        shell: bash
        run: |
          echo "UPNAME=$(echo '${{ matrix.module_folder }}' | tr '/\\ ' '---' | tr -cd '[:alnum:]._-')" >> "${GITHUB_ENV}"
      - name: Dependency check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: ${{ matrix.module_folder }}
          path: ${{ matrix.module_folder }}
          format: HTML
          out: ${{ matrix.module_folder }}-reports
          args: >
            --suppression .github/node-cve-ignore-list.xml
            --nodeAuditSkipDevDependencies
            --nodePackageSkipDevDependencies
            --failOnCVSS 5
            --enableRetired
      - name: Upload reports
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: security-node-${{ env.UPNAME }}-${{ github.run_id }}-${{ github.run_attempt }}
          path: ${{ github.workspace }}/${{ matrix.module_folder }}-reports
EOF
  fi

  if ((${#dotnet_modules[@]} > 0)); then
    job_count=$((job_count + 1))
    cat >> "${file_path}" <<'EOF'

  dotnet-modules-scan:
    name: ${{ matrix.module_folder }}-dotnet-scan
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        module_folder:
EOF
    for module in "${dotnet_modules[@]}"; do
      printf '          - %s\n' "${module}" >> "${file_path}"
    done
    cat >> "${file_path}" <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 9.0.x
      - name: Build project
        run: dotnet build --configuration Release
        working-directory: ${{ matrix.module_folder }}
      - name: Prepare artifact name
        shell: bash
        run: |
          echo "UPNAME=$(echo '${{ matrix.module_folder }}' | tr '/\\ ' '---' | tr -cd '[:alnum:]._-')" >> "${GITHUB_ENV}"
      - name: Dependency check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: ${{ matrix.module_folder }}
          path: ${{ matrix.module_folder }}
          format: HTML
          out: ${{ matrix.module_folder }}-reports
          args: >
            --suppression .github/dotnet-cve-ignore-list.xml
            --failOnCVSS 5
            --enableRetired
      - name: Upload reports
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: security-dotnet-${{ env.UPNAME }}-${{ github.run_id }}-${{ github.run_attempt }}
          path: ${{ github.workspace }}/${{ matrix.module_folder }}-reports
EOF
  fi

  if ((${#gradle_modules[@]} > 0)); then
    job_count=$((job_count + 1))
    cat >> "${file_path}" <<'EOF'

  gradle-modules-scan:
    name: ${{ matrix.module_folder }}-gradle-scan
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        module_folder:
EOF
    for module in "${gradle_modules[@]}"; do
      printf '          - %s\n' "${module}" >> "${file_path}"
    done
    cat >> "${file_path}" <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21
      - name: Build project
        shell: bash
        working-directory: ${{ matrix.module_folder }}
        run: |
          if [[ -x ./gradlew ]]; then
            ./gradlew clean build --no-daemon
          else
            gradle clean build --no-daemon
          fi
      - name: Prepare artifact name
        shell: bash
        run: |
          echo "UPNAME=$(echo '${{ matrix.module_folder }}' | tr '/\\ ' '---' | tr -cd '[:alnum:]._-')" >> "${GITHUB_ENV}"
      - name: Dependency check
        uses: dependency-check/Dependency-Check_Action@main
        env:
          JAVA_HOME: /opt/jdk
        with:
          project: ${{ matrix.module_folder }}
          path: ${{ matrix.module_folder }}
          format: HTML
          out: ${{ matrix.module_folder }}-reports
          args: >
            --suppression .github/gradle-cve-ignore-list.xml
            --failOnCVSS 5
            --enableRetired
            --disableCentral
      - name: Upload reports
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: security-gradle-${{ env.UPNAME }}-${{ github.run_id }}-${{ github.run_attempt }}
          path: ${{ github.workspace }}/${{ matrix.module_folder }}-reports
EOF
  fi

  if ((${#docker_entries[@]} > 0)); then
    job_count=$((job_count + 1))
    cat >> "${file_path}" <<'EOF'

  docker-image-scan:
    name: ${{ matrix.image_name }}-docker-scan
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
EOF
    for entry in "${docker_entries[@]}"; do
      directory="$(cut -d'|' -f1 <<<"${entry}")"
      dockerfile="$(cut -d'|' -f2 <<<"${entry}")"
      image_name="$(cut -d'|' -f3 <<<"${entry}")"
      printf '          - directory: %s\n' "${directory}" >> "${file_path}"
      printf '            dockerfile: %s\n' "${dockerfile}" >> "${file_path}"
      printf '            image_name: %s\n' "${image_name}" >> "${file_path}"
    done
    cat >> "${file_path}" <<'EOF'
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build image for scan
        run: docker build -f "${{ matrix.directory }}/${{ matrix.dockerfile }}" -t "traderx-security/${{ matrix.image_name }}:scan" "${{ matrix.directory }}"
      - name: Scan image for vulnerabilities
        uses: crazy-max/ghaction-container-scan@v3
        with:
          image: traderx-security/${{ matrix.image_name }}:scan
          severity: HIGH
EOF
  fi

  if ((job_count == 0)); then
    cat >> "${file_path}" <<'EOF'
  no-security-targets:
    runs-on: ubuntu-latest
    steps:
      - run: echo "No dependency or container targets detected for security scanning."
EOF
  fi
}

write_license_workflow() {
  local file_path="$1"
  cat > "${file_path}" <<'EOF'
name: License Scanning for Node.js

on:
  workflow_dispatch:
  push:
    paths:
      - '**/package.json'
      - '**/package-lock.json'
      - '.github/workflows/license-scanning-node.yml'

jobs:
EOF

  if ((${#node_modules[@]} == 0)); then
    cat >> "${file_path}" <<'EOF'
  no-node-targets:
    runs-on: ubuntu-latest
    steps:
      - run: echo "No Node.js modules detected for license scanning."
EOF
    return
  fi

  cat >> "${file_path}" <<'EOF'
  scan:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        module_folder:
EOF
  for module in "${node_modules[@]}"; do
    printf '          - %s\n' "${module}" >> "${file_path}"
  done
  cat >> "${file_path}" <<'EOF'
    steps:
      - uses: actions/checkout@v4
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install production dependencies
        run: npm install --omit=dev
        working-directory: ${{ matrix.module_folder }}
      - name: Install license validator
        run: npm install -g node-license-validator
      - name: Validate licenses
        run: node-license-validator . --allow-licenses Apache-2.0 MIT BSD-2-Clause BSD BSD-3-Clause Unlicense ISC
        working-directory: ${{ matrix.module_folder }}
EOF
}

write_build_publish_workflow() {
  local file_path="$1"
  local namespace="$2"
  cat > "${file_path}" <<EOF
name: Build and Publish Application Images

on:
  workflow_dispatch:
  push:
    branches:
      - code/generated-state-*

env:
  GHCR_ORG: ghcr.io/finos
  IMAGE_NAMESPACE: ${namespace}

jobs:
  build-ghcr:
    name: Build and push \${{ matrix.image_name }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    strategy:
      fail-fast: false
      matrix:
        include:
EOF

  for entry in "${docker_entries[@]}"; do
    directory="$(cut -d'|' -f1 <<<"${entry}")"
    dockerfile="$(cut -d'|' -f2 <<<"${entry}")"
    image_name="$(cut -d'|' -f3 <<<"${entry}")"
    printf '          - directory: %s\n' "${directory}" >> "${file_path}"
    printf '            dockerfile: %s\n' "${dockerfile}" >> "${file_path}"
    printf '            image_name: %s\n' "${image_name}" >> "${file_path}"
  done

  cat >> "${file_path}" <<'EOF'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: GHCR auth mode
        run: |
          if [[ -n "${{ secrets.GHCR_PUSH_TOKEN }}" ]]; then
            echo "Using GHCR_PUSH_TOKEN secret for package publish."
          else
            echo "Using GITHUB_TOKEN for package publish."
            echo "If publish fails with write_package, either:"
            echo "1) enable package write for Actions in repo/org settings, or"
            echo "2) set GHCR_PUSH_TOKEN (packages:write) and GHCR_PUSH_USERNAME secrets."
          fi
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ secrets.GHCR_PUSH_USERNAME != '' && secrets.GHCR_PUSH_USERNAME || github.actor }}
          password: ${{ secrets.GHCR_PUSH_TOKEN != '' && secrets.GHCR_PUSH_TOKEN || secrets.GITHUB_TOKEN }}
      - name: Build and publish image
        uses: docker/build-push-action@v6
        with:
          context: ${{ matrix.directory }}
          file: ${{ matrix.directory }}/${{ matrix.dockerfile }}
          push: ${{ github.event_name == 'push' }}
          tags: |
            ${{ env.GHCR_ORG }}/${{ env.IMAGE_NAMESPACE }}/${{ matrix.image_name }}:${{ github.sha }}
            ${{ env.GHCR_ORG }}/${{ env.IMAGE_NAMESPACE }}/${{ matrix.image_name }}:latest
      - name: Scan published image
        uses: crazy-max/ghaction-container-scan@v3
        with:
          image: ${{ env.GHCR_ORG }}/${{ env.IMAGE_NAMESPACE }}/${{ matrix.image_name }}:${{ github.sha }}
          severity: HIGH
EOF
}

write_build_only_workflow() {
  local file_path="$1"
  cat > "${file_path}" <<'EOF'
name: Build Container Images (No Publish)

on:
  workflow_dispatch:
  push:
    branches:
      - code/generated-state-*
    paths:
      - '**/Dockerfile'
      - '**/Dockerfile.compose'
      - '.github/workflows/build-container-images.yml'

jobs:
  build-container-images:
    name: Build ${{ matrix.image_name }}
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
EOF

  for entry in "${docker_entries[@]}"; do
    directory="$(cut -d'|' -f1 <<<"${entry}")"
    dockerfile="$(cut -d'|' -f2 <<<"${entry}")"
    image_name="$(cut -d'|' -f3 <<<"${entry}")"
    printf '          - directory: %s\n' "${directory}" >> "${file_path}"
    printf '            dockerfile: %s\n' "${dockerfile}" >> "${file_path}"
    printf '            image_name: %s\n' "${image_name}" >> "${file_path}"
  done

  cat >> "${file_path}" <<'EOF'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build image (no publish)
        run: |
          docker build \
            -f "${{ matrix.directory }}/${{ matrix.dockerfile }}" \
            -t "traderx-local/${{ matrix.image_name }}:${{ github.sha }}" \
            "${{ matrix.directory }}"
      - name: Scan built image
        uses: crazy-max/ghaction-container-scan@v3
        with:
          image: traderx-local/${{ matrix.image_name }}:${{ github.sha }}
          severity: HIGH
EOF
}

json_array_from_lines() {
  local lines_file="$1"
  jq -Rsc 'split("\n") | map(select(length > 0))' < "${lines_file}"
}

json_docker_entries() {
  local lines_file="$1"
  jq -Rn '
    [inputs
      | select(length > 0)
      | split("|")
      | {directory: .[0], dockerfile: .[1], imageName: .[2]}
    ]
  ' < "${lines_file}"
}

node_json="$(json_array_from_lines "${temp_dir}/node-modules.txt")"
gradle_json="$(json_array_from_lines "${temp_dir}/gradle-modules.txt")"
dotnet_json="$(json_array_from_lines "${temp_dir}/dotnet-modules.txt")"
docker_json="$(json_docker_entries "${temp_dir}/docker-entries.txt")"

jq -n \
  --arg stateId "${STATE_ID}" \
  --arg convergenceLevel "${convergence_level}" \
  --arg convergenceNamespace "${convergence_namespace}" \
  --argjson isConvergence "${is_convergence}" \
  --argjson deployEnabled "${deploy_enabled}" \
  --arg deployProfile "${deploy_profile}" \
  --arg deployEnvironment "${deploy_environment}" \
  --arg deployDomainHint "${deploy_domain_hint}" \
  --argjson nodeModules "${node_json}" \
  --argjson gradleModules "${gradle_json}" \
  --argjson dotnetModules "${dotnet_json}" \
  --argjson dockerModules "${docker_json}" \
  '{
    stateId: $stateId,
    isConvergence: $isConvergence,
    convergenceLevel: $convergenceLevel,
    convergenceNamespace: $convergenceNamespace,
    modules: {
      node: $nodeModules,
      gradle: $gradleModules,
      dotnet: $dotnetModules,
      docker: $dockerModules
    },
    deploy: {
      enabled: $deployEnabled,
      profile: $deployProfile,
      environment: $deployEnvironment,
      domainHint: $deployDomainHint
    }
  }' > "${TARGET_ROOT}/ci/state-metadata.json"

write_security_workflow "${TARGET_ROOT}/.github/workflows/security.yml"
write_license_workflow "${TARGET_ROOT}/.github/workflows/license-scanning-node.yml"

# Prevent inherited workflow leakage across state lineage.
rm -f "${TARGET_ROOT}/.github/workflows/build-and-publish.yml"
rm -f "${TARGET_ROOT}/.github/workflows/build-container-images.yml"

write_compose_ghcr_bundle() {
  local bundle_dir="$1"
  local compose_rel="$2"
  local namespace="$3"
  local compose_abs="${TARGET_ROOT}/${compose_rel}"
  local compose_extends_rel="../../../${compose_rel}"

  local services_file="${temp_dir}/compose-services.txt"
  local volumes_file="${temp_dir}/compose-volumes.txt"
  local networks_file="${temp_dir}/compose-networks.txt"
  : > "${services_file}"
  : > "${volumes_file}"
  : > "${networks_file}"

  awk '
    /^services:/ {in_services=1; next}
    in_services && /^[^[:space:]]/ {in_services=0}
    in_services && /^  [A-Za-z0-9][A-Za-z0-9_-]*:/ {
      svc=$1
      sub(/:$/, "", svc)
      print svc
    }
  ' "${compose_abs}" > "${services_file}"

  awk '
    /^volumes:/ {in_volumes=1; next}
    in_volumes && /^[^[:space:]]/ {in_volumes=0}
    in_volumes && /^  [A-Za-z0-9][A-Za-z0-9_.-]*:/ {
      vol=$1
      sub(/:$/, "", vol)
      print vol
    }
  ' "${compose_abs}" > "${volumes_file}"

  awk '
    /^networks:/ {in_networks=1; next}
    in_networks && /^[^[:space:]]/ {in_networks=0}
    in_networks && /^  [A-Za-z0-9][A-Za-z0-9_.-]*:/ {
      net=$1
      sub(/:$/, "", net)
      print net
    }
  ' "${compose_abs}" > "${networks_file}"

  local compose_ghcr="${bundle_dir}/docker-compose.ghcr.yml"
  {
    echo "name: traderx-${STATE_ID}-ghcr"
    echo
    echo "services:"
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      echo "  ${service}:"
      echo "    extends:"
      echo "      file: ${compose_extends_rel}"
      echo "      service: ${service}"

      service_has_build="$(
        awk -v svc="${service}" '
          /^services:/ {in_services=1; next}
          in_services && /^[^[:space:]]/ {in_services=0}
          in_services && $0 ~ ("^  " svc ":") {in_target=1; next}
          in_target && /^  [A-Za-z0-9][A-Za-z0-9_-]*:/ {in_target=0}
          in_target && /^    build:/ {print "yes"; exit}
        ' "${compose_abs}"
      )"

      local image_name_match=""
      if [[ "${service_has_build}" == "yes" ]]; then
        for entry in "${docker_entries[@]}"; do
          image_name="$(cut -d'|' -f3 <<<"${entry}")"
          if [[ "${image_name}" == "${service}" ]]; then
            image_name_match="${image_name}"
            break
          fi
        done
      fi

      if [[ -n "${image_name_match}" && "${service_has_build}" == "yes" ]]; then
        echo "    image: ghcr.io/finos/${namespace}/${image_name_match}:\${TRADERX_IMAGE_TAG:-latest}"
        echo "    build: null"
      fi
    done < "${services_file}"

    if [[ -s "${volumes_file}" ]]; then
      echo
      echo "volumes:"
      while IFS= read -r volume; do
        [[ -z "${volume}" ]] && continue
        echo "  ${volume}: {}"
      done < "${volumes_file}"
    fi

    if [[ -s "${networks_file}" ]]; then
      echo
      echo "networks:"
      while IFS= read -r network; do
        [[ -z "${network}" ]] && continue
        echo "  ${network}: {}"
      done < "${networks_file}"
    fi
  } > "${compose_ghcr}"

  cat > "${bundle_dir}/.env.example" <<'EOF'
TRADERX_IMAGE_TAG=latest
EOF
}

write_ghcr_run_bundle() {
  local namespace="$1"
  local bundle_dir="${TARGET_ROOT}/runtime/ghcr/${STATE_ID}"
  local state_num="${STATE_ID%%-*}"
  mkdir -p "${bundle_dir}"

  {
    echo "# GHCR image map for ${STATE_ID}"
    for entry in "${docker_entries[@]}"; do
      image_name="$(cut -d'|' -f3 <<<"${entry}")"
      echo "${image_name}=ghcr.io/finos/${namespace}/${image_name}:latest"
    done
  } > "${bundle_dir}/images.lock"

  if [[ -n "${compose_file_rel}" && -f "${TARGET_ROOT}/${compose_file_rel}" ]]; then
    write_compose_ghcr_bundle "${bundle_dir}" "${compose_file_rel}" "${namespace}"
    cat > "${bundle_dir}/README.md" <<EOF
# GHCR Run Bundle (${STATE_ID})

Run this state directly from published GHCR images.

1. Optionally set a specific tag:

\`\`\`bash
export TRADERX_IMAGE_TAG=latest
\`\`\`

2. Pull and start:

\`\`\`bash
docker compose -f runtime/ghcr/${STATE_ID}/docker-compose.ghcr.yml pull
docker compose -f runtime/ghcr/${STATE_ID}/docker-compose.ghcr.yml up -d
\`\`\`

3. Stop:

\`\`\`bash
docker compose -f runtime/ghcr/${STATE_ID}/docker-compose.ghcr.yml down
\`\`\`

This bundle overlays \`${compose_file_rel}\` and replaces buildable app services with GHCR images under \`ghcr.io/finos/${namespace}\`.
EOF
    return
  fi

  start_script="scripts/start-state-${STATE_ID}-generated.sh"
  if [[ ! -f "${TARGET_ROOT}/${start_script}" ]]; then
    fallback_script="$(
      find "${TARGET_ROOT}/scripts" -maxdepth 1 -type f \
        -name "start-state-${state_num}-*-generated.sh" -print \
        | sed "s#^${TARGET_ROOT}/##" | sort | head -n 1 || true
    )"
    if [[ -n "${fallback_script}" ]]; then
      start_script="${fallback_script}"
    fi
  fi
  cat > "${bundle_dir}/README.md" <<EOF
# GHCR Run Bundle (${STATE_ID})

This convergence state does not use a compose runtime bundle. Use published images with the generated start script:

\`\`\`bash
TRADERX_USE_PUBLISHED_IMAGES=1 \\
TRADERX_PUBLISHED_NAMESPACE=${namespace} \\
TRADERX_PUBLISHED_TAG=latest \\
./${start_script} --skip-build
\`\`\`

The start script will pull published images from \`ghcr.io/finos/${namespace}\`, retag them to local expected names, and continue normal cluster startup.
EOF
}

write_aws_ec2_compose_deploy_bundle() {
  local compose_rel="$1"
  local default_branch="$2"
  local default_environment="$3"
  local default_domain="$4"
  local bundle_dir="${TARGET_ROOT}/runtime/deploy/aws-ec2-compose"

  mkdir -p "${bundle_dir}"

  cat > "${bundle_dir}/README.md" <<EOF
# AWS EC2 Compose Deploy Bundle (${STATE_ID})

This bundle is generated for state \`${STATE_ID}\` and is intended for compose-based demo rollout.

## Defaults

- Branch: \`${default_branch}\`
- Environment label: \`${default_environment:-demo}\`
- Domain/FQDN hint: \`${default_domain:-set TRADERX_FQDN at runtime}\`
- Compose file: \`${compose_rel}\`

## Required runtime inputs

- \`TRADERX_FQDN\` (if no default domain was generated for this state)

## Optional runtime inputs

- \`TRADERX_REPO_URL\` (default: \`https://github.com/finos/traderX.git\`)
- \`TRADERX_BRANCH\` (default: generated-state branch for this state)
- \`TRADERX_WORKDIR\` (default: \`\$HOME/traderx\`)
- \`TRADERX_COMPOSE_PATH_REL\` (default: \`${compose_rel}\`)
- \`TRADERX_GHCR_COMPOSE_PATH_REL\` (default: \`runtime/ghcr/${STATE_ID}/docker-compose.ghcr.yml\`)
- \`TRADERX_COMPOSE_PROJECT_NAME\` (default: \`traderx-${STATE_ID}\`)
- \`TRADERX_DEPLOY_ENV\` (default: \`${default_environment:-demo}\`)
- \`TRADERX_IMAGE_TAG\` (default: \`latest\`)
- \`TRADERX_CORS_ALLOWED_ORIGINS\` (default: \`https://\$TRADERX_FQDN,http://\$TRADERX_FQDN,http://localhost:8080\`)
- \`TRADERX_PRUNE_DOCKER\` (\`1\` enables aggressive prune in \`cleanup.sh\`)
- \`TRADERX_RUN_CLEANUP\` (\`1\` runs cleanup before \`upgrade.sh\`)

## Dry-run examples

\`\`\`bash
./runtime/deploy/aws-ec2-compose/deploy.sh --dry-run
./runtime/deploy/aws-ec2-compose/deploy.sh --use-ghcr --dry-run
./runtime/deploy/aws-ec2-compose/upgrade.sh --dry-run
./runtime/deploy/aws-ec2-compose/cleanup.sh --dry-run
\`\`\`
EOF

  cat > "${bundle_dir}/deploy.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

STATE_ID="${STATE_ID}"
TRADERX_REPO_URL="\${TRADERX_REPO_URL:-https://github.com/finos/traderX.git}"
TRADERX_BRANCH="\${TRADERX_BRANCH:-${default_branch}}"
TRADERX_WORKDIR="\${TRADERX_WORKDIR:-\${HOME}/traderx}"
TRADERX_COMPOSE_PATH_REL="\${TRADERX_COMPOSE_PATH_REL:-${compose_rel}}"
TRADERX_GHCR_COMPOSE_PATH_REL="\${TRADERX_GHCR_COMPOSE_PATH_REL:-runtime/ghcr/\${STATE_ID}/docker-compose.ghcr.yml}"
TRADERX_COMPOSE_PROJECT_NAME="\${TRADERX_COMPOSE_PROJECT_NAME:-traderx-\${STATE_ID}}"
TRADERX_DEPLOY_ENV="\${TRADERX_DEPLOY_ENV:-${default_environment:-demo}}"
TRADERX_FQDN="\${TRADERX_FQDN:-${default_domain}}"
TRADERX_IMAGE_TAG="\${TRADERX_IMAGE_TAG:-latest}"
TRADERX_CORS_ALLOWED_ORIGINS="\${TRADERX_CORS_ALLOWED_ORIGINS:-https://\${TRADERX_FQDN},http://\${TRADERX_FQDN},http://localhost:8080}"
DRY_RUN=0
USE_GHCR=0

while (( "\$#" )); do
  case "\$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --use-ghcr)
      USE_GHCR=1
      ;;
    *)
      echo "[fail] unknown argument: \$1"
      echo "[hint] supported: --dry-run --use-ghcr"
      exit 1
      ;;
  esac
  shift
done

if [[ -z "\${TRADERX_FQDN}" ]]; then
  echo "[fail] TRADERX_FQDN is required for deploy"
  exit 1
fi

run_cmd() {
  echo "[run] \$*"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  "\$@"
}

run_compose_up() {
  local compose_file="\$1"
  echo "[run] TRADERX_FQDN=\${TRADERX_FQDN} TRADERX_IMAGE_TAG=\${TRADERX_IMAGE_TAG} TRADERX_CORS_ALLOWED_ORIGINS=\${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f \${compose_file} --project-name \${TRADERX_COMPOSE_PROJECT_NAME} up -d --build"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  TRADERX_FQDN="\${TRADERX_FQDN}" TRADERX_IMAGE_TAG="\${TRADERX_IMAGE_TAG}" CORS_ALLOWED_ORIGINS="\${TRADERX_CORS_ALLOWED_ORIGINS}" \\
    docker compose -f "\${compose_file}" --project-name "\${TRADERX_COMPOSE_PROJECT_NAME}" up -d --build
}

run_compose_ghcr_up() {
  local ghcr_compose_file="\$1"
  echo "[run] TRADERX_CORS_ALLOWED_ORIGINS=\${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f \${ghcr_compose_file} --project-name \${TRADERX_COMPOSE_PROJECT_NAME} pull"
  echo "[run] TRADERX_CORS_ALLOWED_ORIGINS=\${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f \${ghcr_compose_file} --project-name \${TRADERX_COMPOSE_PROJECT_NAME} up -d"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  CORS_ALLOWED_ORIGINS="\${TRADERX_CORS_ALLOWED_ORIGINS}" docker compose -f "\${ghcr_compose_file}" --project-name "\${TRADERX_COMPOSE_PROJECT_NAME}" pull
  CORS_ALLOWED_ORIGINS="\${TRADERX_CORS_ALLOWED_ORIGINS}" docker compose -f "\${ghcr_compose_file}" --project-name "\${TRADERX_COMPOSE_PROJECT_NAME}" up -d
}

if [[ ! -d "\${TRADERX_WORKDIR}/.git" ]]; then
  run_cmd git clone "\${TRADERX_REPO_URL}" "\${TRADERX_WORKDIR}"
fi

run_cmd git -C "\${TRADERX_WORKDIR}" fetch --all --prune
run_cmd git -C "\${TRADERX_WORKDIR}" checkout "\${TRADERX_BRANCH}"
run_cmd git -C "\${TRADERX_WORKDIR}" reset --hard "origin/\${TRADERX_BRANCH}"

compose_file="\${TRADERX_WORKDIR}/\${TRADERX_COMPOSE_PATH_REL}"
ghcr_compose_file="\${TRADERX_WORKDIR}/\${TRADERX_GHCR_COMPOSE_PATH_REL}"
if (( USE_GHCR == 1 )); then
  if [[ ! -f "\${ghcr_compose_file}" ]]; then
    if (( DRY_RUN == 1 )); then
      echo "[warn] GHCR compose file not found in dry-run mode: \${ghcr_compose_file}"
    else
      echo "[fail] GHCR compose file not found: \${ghcr_compose_file}"
      exit 1
    fi
  fi
else
  if [[ ! -f "\${compose_file}" ]]; then
    if (( DRY_RUN == 1 )); then
      echo "[warn] compose file not found in dry-run mode: \${compose_file}"
    else
      echo "[fail] compose file not found: \${compose_file}"
      exit 1
    fi
  fi
fi

if (( USE_GHCR == 1 )); then
  run_compose_ghcr_up "\${ghcr_compose_file}"
  echo "[done] deploy completed for state \${STATE_ID} (\${TRADERX_DEPLOY_ENV}) using ghcr images"
else
  run_compose_up "\${compose_file}"
  echo "[done] deploy completed for state \${STATE_ID} (\${TRADERX_DEPLOY_ENV}) using local builds"
fi
EOF

  cat > "${bundle_dir}/upgrade.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRADERX_RUN_CLEANUP="${TRADERX_RUN_CLEANUP:-0}"

if [[ "${TRADERX_RUN_CLEANUP}" == "1" ]]; then
  "${SCRIPT_DIR}/cleanup.sh" "$@"
fi

"${SCRIPT_DIR}/deploy.sh" "$@"
EOF

  cat > "${bundle_dir}/cleanup.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

STATE_ID="${STATE_ID}"
TRADERX_WORKDIR="\${TRADERX_WORKDIR:-\${HOME}/traderx}"
TRADERX_COMPOSE_PATH_REL="\${TRADERX_COMPOSE_PATH_REL:-${compose_rel}}"
TRADERX_COMPOSE_PROJECT_NAME="\${TRADERX_COMPOSE_PROJECT_NAME:-traderx-\${STATE_ID}}"
TRADERX_PRUNE_DOCKER="\${TRADERX_PRUNE_DOCKER:-0}"
DRY_RUN=0

while (( "\$#" )); do
  case "\$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "[fail] unknown argument: \$1"
      echo "[hint] supported: --dry-run"
      exit 1
      ;;
  esac
  shift
done

run_cmd() {
  echo "[run] \$*"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  "\$@"
}

compose_file="\${TRADERX_WORKDIR}/\${TRADERX_COMPOSE_PATH_REL}"
if [[ -f "\${compose_file}" ]]; then
  run_cmd docker compose -f "\${compose_file}" --project-name "\${TRADERX_COMPOSE_PROJECT_NAME}" down --remove-orphans
else
  echo "[info] compose file not found; skipping compose down: \${compose_file}"
fi

if [[ "\${TRADERX_PRUNE_DOCKER}" == "1" ]]; then
  run_cmd docker system prune -f
  run_cmd docker volume prune -f
fi

echo "[done] cleanup completed for state \${STATE_ID}"
EOF

  cat > "${bundle_dir}/nginx.reverse-proxy.snippet.conf" <<'EOF'
# Optional reverse-proxy snippet for TraderX demo endpoints.
# Adjust upstream host/port and include this in your active nginx server block.

location /ng-cli-ws {
    proxy_pass http://localhost:8080/ng-cli-ws;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}

location /trade-feed/ {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:8080/trade-feed/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}

location /socket.io/ {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:8080/socket.io/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
EOF

  chmod +x "${bundle_dir}/deploy.sh" "${bundle_dir}/upgrade.sh" "${bundle_dir}/cleanup.sh"
}

if ((${#docker_entries[@]} > 0)); then
  if [[ -n "${convergence_namespace}" && "${is_convergence}" == "true" ]]; then
    write_build_publish_workflow "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" "${convergence_namespace}"
    write_ghcr_run_bundle "${convergence_namespace}"
  else
    write_build_only_workflow "${TARGET_ROOT}/.github/workflows/build-container-images.yml"
  fi
fi

if [[ "${deploy_enabled}" == "true" ]]; then
  case "${deploy_profile}" in
    aws-ec2-compose)
      if [[ -z "${compose_file_rel}" ]]; then
        echo "[fail] deploy profile ${deploy_profile} requires a compose runtime mapping for ${STATE_ID}"
        exit 1
      fi
      if [[ ! -f "${TARGET_ROOT}/${compose_file_rel}" ]]; then
        echo "[fail] deploy profile ${deploy_profile} requires compose file: ${TARGET_ROOT}/${compose_file_rel}"
        exit 1
      fi
      write_aws_ec2_compose_deploy_bundle "${compose_file_rel}" "${publish_branch}" "${deploy_environment}" "${deploy_domain_hint}"
      ;;
    *)
      echo "[fail] unsupported deploy profile for ${STATE_ID}: ${deploy_profile}"
      exit 1
      ;;
  esac
fi

if [[ -f "${TARGET_ROOT}/RUN_FROM_GENERATED.md" && -f "${TARGET_ROOT}/runtime/ghcr/${STATE_ID}/README.md" ]]; then
  if ! grep -q 'GHCR Run Bundle' "${TARGET_ROOT}/RUN_FROM_GENERATED.md"; then
    {
      echo
      echo "## GHCR Run Bundle"
      echo
      echo "- See: \`./runtime/ghcr/${STATE_ID}/README.md\`"
      echo "- Image map: \`./runtime/ghcr/${STATE_ID}/images.lock\`"
    } >> "${TARGET_ROOT}/RUN_FROM_GENERATED.md"
  fi
fi

if [[ -f "${TARGET_ROOT}/RUN_FROM_GENERATED.md" && -f "${TARGET_ROOT}/runtime/deploy/aws-ec2-compose/README.md" ]]; then
  if ! grep -q 'Deployment Bundle' "${TARGET_ROOT}/RUN_FROM_GENERATED.md"; then
    {
      echo
      echo "## Deployment Bundle"
      echo
      echo "- See: \`./runtime/deploy/aws-ec2-compose/README.md\`"
      echo "- Dry-run deploy: \`./runtime/deploy/aws-ec2-compose/deploy.sh --dry-run\`"
    } >> "${TARGET_ROOT}/RUN_FROM_GENERATED.md"
  fi
fi

bash "${ROOT}/pipeline/validate-ghcr-run-bundle-readmes.sh" "${TARGET_ROOT}"

echo "[ok] installed generated CI assets for ${STATE_ID} at ${TARGET_ROOT}/.github"

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

temp_dir="$(mktemp -d /tmp/traderx-generated-ci.XXXXXX)"
trap 'rm -rf "${temp_dir}"' EXIT

is_ignored_dir() {
  local rel="$1"
  case "${rel}" in
    .github*|runtime/*|scripts*|catalog*|generated/*|docs/*|ci/*|spec-source/*|.run/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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
    add_unique_line "${out_file}" "${dir}"
  done < <(find "${TARGET_ROOT}" -type f -name package.json -not -path '*/node_modules/*' | sort)
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
    add_unique_line "${out_file}" "${dir}"
  done < <(find "${TARGET_ROOT}" -type f -name '*.csproj' | sort)
  sort -u -o "${out_file}" "${out_file}"
}

docker_dir_exists() {
  local dir="$1"
  local entries_file="$2"
  grep -q "^${dir}|" "${entries_file}" >/dev/null 2>&1
}

discover_docker_entries() {
  local out_file="$1"
  : > "${out_file}"

  while IFS= read -r dockerfile; do
    [[ -z "${dockerfile}" ]] && continue
    rel="${dockerfile#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
    image_name="$(printf '%s' "${dir}" | tr '/' '-')"
    printf '%s|%s|%s\n' "${dir}" "$(basename "${dockerfile}")" "${image_name}" >> "${out_file}"
  done < <(find "${TARGET_ROOT}" -type f -name Dockerfile.compose | sort)

  while IFS= read -r dockerfile; do
    [[ -z "${dockerfile}" ]] && continue
    rel="${dockerfile#${TARGET_ROOT}/}"
    dir="$(dirname "${rel}")"
    is_ignored_dir "${dir}" && continue
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
      - '**/Dockerfile'
      - '**/Dockerfile.compose'
      - '.github/*-cve-ignore-list.xml'
      - '.github/workflows/security.yml'

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

if ((${#docker_entries[@]} > 0)); then
  if [[ -n "${convergence_namespace}" && "${is_convergence}" == "true" ]]; then
    write_build_publish_workflow "${TARGET_ROOT}/.github/workflows/build-and-publish.yml" "${convergence_namespace}"
    write_ghcr_run_bundle "${convergence_namespace}"
  else
    write_build_only_workflow "${TARGET_ROOT}/.github/workflows/build-container-images.yml"
  fi
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

echo "[ok] installed generated CI assets for ${STATE_ID} at ${TARGET_ROOT}/.github"

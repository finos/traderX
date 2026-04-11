#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-unknown-state}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required to normalize generated dependency manifests"
  exit 1
fi

update_json_file() {
  local file_path="$1"
  local jq_expr="$2"
  local tmp

  [[ -f "${file_path}" ]] || return 0

  tmp="$(mktemp)"
  jq "${jq_expr}" "${file_path}" > "${tmp}"
  mv "${tmp}" "${file_path}"
}

ensure_web_frontend_dependency_baseline() {
  local web_root="${TARGET_ROOT}/web-front-end/angular"
  local package_json="${TARGET_ROOT}/web-front-end/angular/package.json"
  [[ -f "${package_json}" ]] || return 0

  update_json_file "${package_json}" '
    .dependencies["@angular/animations"] = "^19.2.20" |
    .dependencies["@angular/common"] = "^19.2.20" |
    .dependencies["@angular/compiler"] = "^19.2.20" |
    .dependencies["@angular/core"] = "^19.2.20" |
    .dependencies["@angular/forms"] = "^19.2.20" |
    .dependencies["@angular/platform-browser"] = "^19.2.20" |
    .dependencies["@angular/platform-browser-dynamic"] = "^19.2.20" |
    .dependencies["@angular/router"] = "^19.2.20" |
    .dependencies["bootstrap"] = "^5.3.8" |
    .dependencies["ngx-bootstrap"] = "^19.0.2" |
    .dependencies["socket.io-client"] = "^4.8.3" |
    .dependencies["zone.js"] = "^0.15.0" |
    .devDependencies["@angular-devkit/build-angular"] = "^19.2.20" |
    .devDependencies["@angular/cli"] = "^19.2.20" |
    .devDependencies["@angular/compiler-cli"] = "^19.2.20" |
    .devDependencies["@angular/language-service"] = "^19.2.20" |
    .devDependencies["typescript"] = "~5.8.2"
  '

  # Historical state patchsets may carry lockfiles/node_modules pinned to older
  # Angular versions; remove them so runtime/docker builds resolve from the
  # normalized package.json contract.
  rm -rf "${web_root}/node_modules"
  rm -f "${web_root}/package-lock.json"
}

ensure_web_frontend_angular_compatibility() {
  local web_root="${TARGET_ROOT}/web-front-end/angular"
  local angular_json="${web_root}/angular.json"

  [[ -d "${web_root}" ]] || return 0

  # Angular 19+ expects buildTarget instead of browserTarget for dev server config.
  if [[ -f "${angular_json}" ]]; then
    perl -pi -e 's/browserTarget/buildTarget/g' "${angular_json}"
  fi

  # This codebase is NgModule-based. Angular 19 treats components as standalone
  # unless explicitly marked otherwise, so enforce standalone:false for all
  # generated components that do not already declare standalone.
  while IFS= read -r -d '' component_ts; do
    perl -0777 -i -pe 's/\@Component\(\{\n(?!\s*standalone\s*:)/\@Component\(\{\n    standalone: false,\n/g' "${component_ts}"
  done < <(find "${web_root}/main/app" -type f -name "*.ts" -not -name "*.spec.ts" -print0 2>/dev/null || true)
}

ensure_price_publisher_dependency_baseline() {
  local package_json="${TARGET_ROOT}/price-publisher/package.json"
  [[ -f "${package_json}" ]] || return 0

  update_json_file "${package_json}" '
    .dependencies["express"] = "4.22.1" |
    .overrides["qs"] = "6.15.1"
  '
}

ensure_gradle_security_overrides() {
  local gradle_file="$1"
  [[ -f "${gradle_file}" ]] || return 0

  if ! rg -q "org\.apache\.logging\.log4j:log4j-api" "${gradle_file}"; then
    perl -0pi -e "s/(implementation 'org\\.springdoc:springdoc-openapi-starter-webmvc-ui:[^']+'\\n)/\$1  implementation 'org.apache.logging.log4j:log4j-api:2.25.4'\\n/" "${gradle_file}"
  fi

  if ! rg -q "org\.webjars:swagger-ui" "${gradle_file}"; then
    perl -0pi -e "s/(implementation 'org\\.springdoc:springdoc-openapi-starter-webmvc-ui:[^']+'\\n)/\$1  implementation 'org.webjars:swagger-ui:5.32.2'\\n/" "${gradle_file}"
  fi

  case "${gradle_file}" in
    *trade-service/build.gradle|*trade-processor/build.gradle|*order-matcher/build.gradle)
      if ! rg -q "org\\.jetbrains\\.kotlin:kotlin-stdlib" "${gradle_file}"; then
        perl -0pi -e "s/(testImplementation 'org\\.springframework\\.boot:spring-boot-starter-test'\\n)/  implementation 'org.jetbrains.kotlin:kotlin-stdlib:2.3.20'\\n\\n\$1/" "${gradle_file}"
      fi
      ;;
  esac
}

ensure_web_frontend_dependency_baseline
ensure_web_frontend_angular_compatibility
ensure_price_publisher_dependency_baseline

for gradle_file in \
  "${TARGET_ROOT}/account-service/build.gradle" \
  "${TARGET_ROOT}/position-service/build.gradle" \
  "${TARGET_ROOT}/trade-service/build.gradle" \
  "${TARGET_ROOT}/trade-processor/build.gradle" \
  "${TARGET_ROOT}/order-matcher/build.gradle"; do
  ensure_gradle_security_overrides "${gradle_file}"
done

echo "[ok] normalized generated dependency security baseline for ${STATE_ID}"

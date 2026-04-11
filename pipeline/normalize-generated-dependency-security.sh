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
      if ! rg -q "org\\.apache\\.commons:commons-lang3:3\\.20\\.0" "${gradle_file}"; then
        perl -0pi -e "s/(testImplementation 'org\\.springframework\\.boot:spring-boot-starter-test'\\n)/  implementation 'org.apache.commons:commons-lang3:3.20.0'\\n\\n\$1/" "${gradle_file}"
      fi
      if ! rg -q "kotlin-stdlib-jdk7" "${gradle_file}"; then
        cat >> "${gradle_file}" <<'EOF'

configurations.configureEach {
  exclude group: 'org.jetbrains.kotlin', module: 'kotlin-stdlib-jdk7'
}
EOF
      fi
      if ! rg -q "kotlin-stdlib-jdk8" "${gradle_file}"; then
        cat >> "${gradle_file}" <<'EOF'

configurations.configureEach {
  exclude group: 'org.jetbrains.kotlin', module: 'kotlin-stdlib-jdk8'
}
EOF
      fi
      ;;
  esac
}

ensure_java_compose_build_baseline() {
  local dockerfile="$1"
  [[ -f "${dockerfile}" ]] || return 0

  if rg -q "^FROM eclipse-temurin:21-jdk AS build" "${dockerfile}"; then
    perl -0pi -e 's/^FROM eclipse-temurin:21-jdk AS build$/FROM gradle:8.13-jdk21 AS build/m' "${dockerfile}"
  fi

  if rg -q "target=/root/\\.gradle" "${dockerfile}"; then
    perl -0pi -e 's#target=/root/\.gradle#target=/home/gradle/.gradle#g' "${dockerfile}"
  fi

  if rg -q "\\./gradlew --no-daemon clean bootJar" "${dockerfile}"; then
    perl -0pi -e 's/chmod \+x gradlew && \.\/gradlew --no-daemon clean bootJar/gradle --no-daemon clean bootJar/g' "${dockerfile}"
  fi
}

ensure_order_matcher_test_baseline() {
  local order_matcher_root="${TARGET_ROOT}/order-matcher"
  local test_file="${order_matcher_root}/src/test/java/finos/traderx/ordermatcher/OrderMatcherApplicationTests.java"
  local test_resource_dir="${order_matcher_root}/src/test/resources"
  local test_properties="${test_resource_dir}/application-test.properties"
  local gradle_file="${order_matcher_root}/build.gradle"

  [[ -d "${order_matcher_root}" ]] || return 0

  mkdir -p "$(dirname "${test_file}")"
  cat > "${test_file}" <<'EOF'
package finos.traderx.ordermatcher;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class OrderMatcherApplicationTests {
    @Test
    void contextLoads() {
    }
}
EOF

  mkdir -p "${test_resource_dir}"
  cat > "${test_properties}" <<'EOF'
spring.datasource.url=jdbc:h2:mem:ordermatcher;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect
spring.jpa.hibernate.ddl-auto=create-drop
order.matcher.seed-enabled=false
EOF

  if [[ -f "${gradle_file}" ]] && ! rg -q "testRuntimeOnly 'com\\.h2database:h2'" "${gradle_file}"; then
    perl -0pi -e "s/(testImplementation 'org\\.springframework\\.boot:spring-boot-starter-test'\\n)/\$1  testRuntimeOnly 'com.h2database:h2'\\n/" "${gradle_file}"
  fi
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

for dockerfile in \
  "${TARGET_ROOT}/account-service/Dockerfile.compose" \
  "${TARGET_ROOT}/position-service/Dockerfile.compose" \
  "${TARGET_ROOT}/trade-service/Dockerfile.compose" \
  "${TARGET_ROOT}/trade-processor/Dockerfile.compose" \
  "${TARGET_ROOT}/order-matcher/Dockerfile.compose"; do
  ensure_java_compose_build_baseline "${dockerfile}"
done

ensure_order_matcher_test_baseline

echo "[ok] normalized generated dependency security baseline for ${STATE_ID}"

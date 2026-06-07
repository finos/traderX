#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"
TARGETS_FILE="${TRADERX_DEPENDENCY_TARGETS_FILE:-${ROOT}/catalog/dependency-version-targets.json}"
ALLOW_MISSING=0
STATE_FILTER=""

usage() {
  cat <<'USAGE'
usage: bash pipeline/validate-generated-branch-dependency-consistency.sh [--states <comma-separated-state-ids>] [--allow-missing-branches]

Validates dependency-version consistency and target propagation across generated-state branches.

The check compares dependencies by key:
- ecosystem (gradle/npm)
- file path
- scope/grouping
- dependency coordinate/name

and fails if the same key has multiple versions across states.
The check also validates selected dependency targets from catalog/dependency-version-targets.json.
USAGE
}

while (($# > 0)); do
  case "$1" in
    --states)
      STATE_FILTER="${2:-}"
      shift 2
      ;;
    --allow-missing-branches)
      ALLOW_MISSING=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing catalog: ${CATALOG}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required"
  exit 1
fi

if [[ ! -f "${TARGETS_FILE}" ]]; then
  echo "[fail] missing dependency targets file: ${TARGETS_FILE}"
  exit 1
fi

resolve_ref() {
  local branch="$1"
  if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "refs/heads/${branch}"
    return 0
  fi
  if git -C "${ROOT}" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    echo "refs/remotes/origin/${branch}"
    return 0
  fi
  return 1
}

rows_file="$(mktemp)"
keys_file="$(mktemp)"
trap 'rm -f "${rows_file}" "${keys_file}"' EXIT

assert_target() {
  local ecosystem="$1"
  local scope="$2"
  local dependency="$3"
  local expected="$4"

  if ! awk -F'\t' -v e="${ecosystem}" -v s="${scope}" -v d="${dependency}" '
    $1==e && $3==s && $4==d { found=1 }
    END { exit(found ? 0 : 1) }
  ' "${rows_file}"; then
    echo "[fail] target dependency not found in generated branches: ${ecosystem} ${scope}:${dependency}"
    exit 1
  fi

  if ! awk -F'\t' -v e="${ecosystem}" -v s="${scope}" -v d="${dependency}" -v expected="${expected}" '
    $1==e && $3==s && $4==d && $6 != expected { bad=1 }
    END { exit(bad ? 1 : 0) }
  ' "${rows_file}"; then
    echo "[fail] target mismatch for ${ecosystem} ${scope}:${dependency}; expected ${expected}"
    awk -F'\t' -v e="${ecosystem}" -v s="${scope}" -v d="${dependency}" '
      $1==e && $3==s && $4==d { print "  - " $5 " " $2 ": " $6 }
    ' "${rows_file}" | sort -u
    exit 1
  fi
}

assert_target_any_scope() {
  local ecosystem="$1"
  local dependency="$2"
  local expected="$3"
  shift 3

  local found=0
  local scope
  for scope in "$@"; do
    if awk -F'\t' -v e="${ecosystem}" -v s="${scope}" -v d="${dependency}" '
      $1==e && $3==s && $4==d { found=1 }
      END { exit(found ? 0 : 1) }
    ' "${rows_file}"; then
      found=1
      assert_target "${ecosystem}" "${scope}" "${dependency}" "${expected}"
    fi
  done

  if (( found == 0 )); then
    echo "[fail] target dependency not found in generated branches: ${ecosystem} ${dependency} (scopes: $*)"
    exit 1
  fi
}

state_query='.states[] | select(.generation.mode == "implemented")'
if [[ -n "${STATE_FILTER}" ]]; then
  state_query+=" | select(.id as \$state_id | (\"${STATE_FILTER}\" | split(\",\") | index(\$state_id)))"
fi

missing=0
scanned_states=0

while IFS=$'\t' read -r state_id publish_branch; do
  [[ -n "${state_id}" && -n "${publish_branch}" ]] || continue

  ref="$(resolve_ref "${publish_branch}" || true)"
  if [[ -z "${ref}" ]]; then
    if (( ALLOW_MISSING == 1 )); then
      echo "[warn] missing generated branch ref for ${state_id}: ${publish_branch}"
      continue
    fi
    echo "[fail] missing generated branch ref for ${state_id}: ${publish_branch}"
    missing=$((missing + 1))
    continue
  fi

  scanned_states=$((scanned_states + 1))

  while IFS= read -r file_path; do
    [[ -n "${file_path}" ]] || continue

    if [[ "${file_path}" == "package.json" || "${file_path}" == */package.json ]]; then
      tmp_json="$(mktemp)"
      git -C "${ROOT}" show "${ref}:${file_path}" > "${tmp_json}"
      jq -r --arg state "${state_id}" --arg path "${file_path}" '
        def emit($scope):
          (getpath([$scope]) // {} | to_entries[]? |
            "npm\t\($path)\t\($scope)\t\(.key)\t\($state)\t\(.value|tostring)");
        emit("dependencies"), emit("devDependencies"), emit("overrides")
      ' "${tmp_json}" >> "${rows_file}"
      rm -f "${tmp_json}"
      continue
    fi

    if [[ "${file_path}" == "build.gradle" || "${file_path}" == */build.gradle ]]; then
      tmp_gradle="$(mktemp)"
      git -C "${ROOT}" show "${ref}:${file_path}" > "${tmp_gradle}"

      boot_version="$(sed -n "s/.*id 'org\\.springframework\\.boot' version '\\([^']*\\)'.*/\\1/p" "${tmp_gradle}" | head -n1)"
      if [[ -n "${boot_version}" ]]; then
        printf 'gradle\t%s\tplugin\torg.springframework.boot\t%s\t%s\n' "${file_path}" "${state_id}" "${boot_version}" >> "${rows_file}"
      fi

      dep_mgmt_version="$(sed -n "s/.*id 'io\\.spring\\.dependency-management' version '\\([^']*\\)'.*/\\1/p" "${tmp_gradle}" | head -n1)"
      if [[ -n "${dep_mgmt_version}" ]]; then
        printf 'gradle\t%s\tplugin\tio.spring.dependency-management\t%s\t%s\n' "${file_path}" "${state_id}" "${dep_mgmt_version}" >> "${rows_file}"
      fi

      java_source="$(sed -n "s/.*sourceCompatibility = JavaVersion\\.VERSION_\\([0-9][0-9]*\\).*/\\1/p" "${tmp_gradle}" | head -n1)"
      if [[ -n "${java_source}" ]]; then
        printf 'gradle\t%s\tjava\tsourceCompatibility\t%s\t%s\n' "${file_path}" "${state_id}" "${java_source}" >> "${rows_file}"
      fi

      tomcat_version="$(sed -n "s/.*ext\\['tomcat\\.version'\\][[:space:]]*=[[:space:]]*'\\([^']*\\)'.*/\\1/p" "${tmp_gradle}" | head -n1)"
      if [[ -n "${tomcat_version}" ]]; then
        printf 'gradle\t%s\tproperty\ttomcat.version\t%s\t%s\n' "${file_path}" "${state_id}" "${tomcat_version}" >> "${rows_file}"
      fi

      while IFS= read -r coord; do
        [[ -n "${coord}" ]] || continue
        ga="$(printf '%s' "${coord}" | cut -d: -f1-2)"
        ver="$(printf '%s' "${coord}" | cut -d: -f3)"
        [[ -n "${ga}" && -n "${ver}" ]] || continue
        printf 'gradle\t%s\tdependency\t%s\t%s\t%s\n' "${file_path}" "${ga}" "${state_id}" "${ver}" >> "${rows_file}"
      done < <(rg -o --pcre2 "'\\K[^':]+:[^':]+:[^']+" "${tmp_gradle}" | sort -u || true)

      rm -f "${tmp_gradle}"
      continue
    fi

    if [[ "${file_path}" == "gradle-wrapper.properties" || "${file_path}" == */gradle-wrapper.properties ]]; then
      tmp_wrapper="$(mktemp)"
      git -C "${ROOT}" show "${ref}:${file_path}" > "${tmp_wrapper}"

      wrapper_version="$(sed -n 's#.*distributionUrl=.*gradle-\([0-9.]*\)-bin\.zip.*#\1#p' "${tmp_wrapper}" | head -n1)"
      if [[ -n "${wrapper_version}" ]]; then
        printf 'gradle-wrapper\t%s\twrapper\tdistributionVersion\t%s\t%s\n' "${file_path}" "${state_id}" "${wrapper_version}" >> "${rows_file}"
      fi

      wrapper_sha="$(sed -n 's/^distributionSha256Sum=\(.*\)$/\1/p' "${tmp_wrapper}" | head -n1)"
      if [[ -n "${wrapper_sha}" ]]; then
        printf 'gradle-wrapper\t%s\twrapper\tdistributionSha256Sum\t%s\t%s\n' "${file_path}" "${state_id}" "${wrapper_sha}" >> "${rows_file}"
      fi

      rm -f "${tmp_wrapper}"
      continue
    fi

    if [[ "${file_path}" == *.csproj ]]; then
      tmp_csproj="$(mktemp)"
      git -C "${ROOT}" show "${ref}:${file_path}" > "${tmp_csproj}"
      sed -n 's/.*<PackageReference Include="\([^"]*\)" Version="\([^"]*\)".*/\1\t\2/p' "${tmp_csproj}" | \
        while IFS=$'\t' read -r pkg ver; do
          [[ -n "${pkg}" && -n "${ver}" ]] || continue
          printf 'nuget\t%s\tPackageReference\t%s\t%s\t%s\n' "${file_path}" "${pkg}" "${state_id}" "${ver}" >> "${rows_file}"
        done
      rm -f "${tmp_csproj}"
    fi
  done < <(git -C "${ROOT}" ls-tree -r --name-only "${ref}" | rg '(build\.gradle|gradle-wrapper\.properties|package\.json|\.csproj)$' || true)

done < <(jq -r "${state_query} | [.id, .publish.branch] | @tsv" "${CATALOG}")

if (( missing > 0 )); then
  exit 1
fi

if [[ ! -s "${rows_file}" ]]; then
  echo "[fail] no dependency rows collected from generated branches"
  exit 1
fi

cut -f1-4,6 "${rows_file}" | sort -u | \
  awk -F'\t' '{k=$1 FS $2 FS $3 FS $4; versions[k]++} END {for (k in versions) if (versions[k] > 1) print k}' | \
  sort > "${keys_file}"

if [[ -s "${keys_file}" ]]; then
  echo "[fail] inconsistent dependency versions detected across generated-state branches"
  echo
  while IFS=$'\t' read -r ecosystem file_path scope_key dep_name; do
    echo "[inconsistent] ${ecosystem} ${file_path} ${scope_key}:${dep_name}"
    awk -F'\t' -v e="${ecosystem}" -v p="${file_path}" -v s="${scope_key}" -v d="${dep_name}" '
      $1==e && $2==p && $3==s && $4==d {
        print "  - " $5 ": " $6;
      }
    ' "${rows_file}" | sort -u
  done < "${keys_file}"
  exit 1
fi

assert_target "gradle" "plugin" "org.springframework.boot" "$(jq -er '.java.plugins["org.springframework.boot"]' "${TARGETS_FILE}")"
assert_target "gradle" "plugin" "io.spring.dependency-management" "$(jq -er '.java.plugins["io.spring.dependency-management"]' "${TARGETS_FILE}")"
assert_target "gradle" "java" "sourceCompatibility" "$(jq -er '.java.sourceCompatibility' "${TARGETS_FILE}")"
assert_target "gradle" "property" "tomcat.version" "$(jq -er '.java.properties["tomcat.version"]' "${TARGETS_FILE}")"
assert_target "gradle-wrapper" "wrapper" "distributionVersion" "$(jq -er '.gradleWrapper.distributionVersion' "${TARGETS_FILE}")"
assert_target "gradle-wrapper" "wrapper" "distributionSha256Sum" "$(jq -er '.gradleWrapper.distributionSha256Sum' "${TARGETS_FILE}")"

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  assert_target "gradle" "dependency" "${dep}" "${expected}"
done < <(jq -r '.java.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  assert_target_any_scope "npm" "${dep}" "${expected}" "dependencies" "devDependencies" "overrides"
done < <(jq -r '.npm.dependencies | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  assert_target "npm" "overrides" "${dep}" "${expected}"
done < <(jq -r '(.npm.overrides // {}) | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

while IFS=$'\t' read -r dep expected; do
  [[ -n "${dep}" && -n "${expected}" ]] || continue
  assert_target "nuget" "PackageReference" "${dep}" "${expected}"
done < <(jq -r '.nuget.packages | to_entries[] | [.key, .value] | @tsv' "${TARGETS_FILE}")

echo "[ok] generated dependency consistency and targets validated across ${scanned_states} state branch(es)"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"
ALLOW_MISSING=0
STATE_FILTER=""

usage() {
  cat <<'USAGE'
usage: bash pipeline/validate-generated-branch-dependency-consistency.sh [--states <comma-separated-state-ids>] [--allow-missing-branches]

Validates dependency-version consistency across generated-state branches.

The check compares dependencies by key:
- ecosystem (gradle/npm)
- file path
- scope/grouping
- dependency coordinate/name

and fails if the same key has multiple versions across states.
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

state_query='.states[] | select(.generation.mode == "implemented")'
if [[ -n "${STATE_FILTER}" ]]; then
  state_query+=" | select((\"${STATE_FILTER}\" | split(\",\") | index(.id)))"
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
      git -C "${ROOT}" show "${ref}:${file_path}" | \
        awk -v state="${state_id}" -v path="${file_path}" -F"'" '
          /^[[:space:]]*(implementation|api|compileOnly|runtimeOnly|testImplementation|testRuntimeOnly|annotationProcessor)[[:space:]]+\x27[^\x27]+:[^\x27]+:[^\x27]+\x27/ {
            coord=$2;
            n=split(coord, parts, ":");
            if (n >= 3) {
              ga=parts[1] ":" parts[2];
              ver=parts[3];
              print "gradle\t" path "\tdependency\t" ga "\t" state "\t" ver;
            }
          }
        ' >> "${rows_file}"
    fi
  done < <(git -C "${ROOT}" ls-tree -r --name-only "${ref}" | rg '(build\.gradle|package\.json)$' || true)

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

echo "[ok] generated dependency consistency validated across ${scanned_states} state branch(es)"

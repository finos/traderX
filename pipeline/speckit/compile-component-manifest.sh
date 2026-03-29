#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${ROOT}"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="${1:-}"
OUTPUT_PATH="${2:-}"

if [[ -z "${COMPONENT_ID}" ]]; then
  echo "usage: $0 <component-id> [output-path]"
  exit 1
fi

speckit_assert_global_readiness
speckit_assert_component_ready "${COMPONENT_ID}"

CSV="${ROOT}/catalog/component-spec.csv"
MATRIX="${SPECKIT_MATRIX}"
OUT_DIR="${ROOT}/TraderSpec/codebase/generated-manifests"

json_escape() {
  local raw="$1"
  raw="${raw//\\/\\\\}"
  raw="${raw//\"/\\\"}"
  printf "%s" "${raw}"
}

to_json_array_from_pipe() {
  local value="$1"
  if [[ -z "${value}" || "${value}" == "none" ]]; then
    echo "[]"
    return
  fi

  local first=1
  local token
  echo -n "["
  IFS='|' read -ra tokens <<< "${value}"
  for token in "${tokens[@]}"; do
    token="${token#"${token%%[![:space:]]*}"}"
    token="${token%"${token##*[![:space:]]}"}"
    [[ -n "${token}" ]] || continue
    if (( first == 0 )); then
      echo -n ","
    fi
    first=0
    echo -n "\"$(json_escape "${token}")\""
  done
  echo "]"
}

to_json_array_from_lines() {
  local lines="$1"
  if [[ -z "${lines}" ]]; then
    echo "[]"
    return
  fi

  local first=1
  local line
  echo -n "["
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    if (( first == 0 )); then
      echo -n ","
    fi
    first=0
    echo -n "\"$(json_escape "${line}")\""
  done <<< "${lines}"
  echo "]"
}

normalize_field() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ "${value}" == \"*\" ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf "%s" "${value}"
}

component_row="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $1 == component_id { print; exit }' "${CSV}")"
if [[ -z "${component_row}" ]]; then
  echo "[fail] component ${COMPONENT_ID} not found in ${CSV}"
  exit 1
fi

IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes <<< "${component_row}"

component_id="$(normalize_field "${component_id}")"
kind="$(normalize_field "${kind}")"
source_path="$(normalize_field "${source_path}")"
target_path="$(normalize_field "${target_path}")"
language="$(normalize_field "${language}")"
framework="$(normalize_field "${framework}")"
build_tool="$(normalize_field "${build_tool}")"
default_port="$(normalize_field "${default_port}")"
contract_file="$(normalize_field "${contract_file}")"
depends_on="$(normalize_field "${depends_on}")"
required_env="$(normalize_field "${required_env}")"
notes="$(normalize_field "${notes}")"

requirements="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $1 }' "${MATRIX}" | sort -u)"
stories="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $2 }' "${MATRIX}" | sort -u)"
acceptance="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $3 }' "${MATRIX}" | sort -u)"
flows="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $4 }' "${MATRIX}" | sort -u)"
verification_refs="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $7 }' "${MATRIX}" | sort -u)"

cors_required="false"
if awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id && $1 == "SYS-NFR-001" { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
  cors_required="true"
fi

contract_primary="null"
if [[ "${contract_file}" != "none" ]]; then
  contract_primary="\"$(json_escape "${contract_file}")\""
fi

timestamp_utc="${TRADERSPEC_MANIFEST_GENERATED_AT_UTC:-}"
if [[ -z "${timestamp_utc}" ]]; then
  if git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    commit_epoch="$(git -C "${REPO_ROOT}" show -s --format=%ct HEAD)"
    if timestamp_utc="$(date -u -r "${commit_epoch}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)"; then
      :
    else
      timestamp_utc="$(date -u -d "@${commit_epoch}" +"%Y-%m-%dT%H:%M:%SZ")"
    fi
  else
    timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  fi
fi
depends_on_json="$(to_json_array_from_pipe "${depends_on}")"
required_env_json="$(to_json_array_from_pipe "${required_env}")"
requirements_json="$(to_json_array_from_lines "${requirements}")"
stories_json="$(to_json_array_from_lines "${stories}")"
acceptance_json="$(to_json_array_from_lines "${acceptance}")"
flows_json="$(to_json_array_from_lines "${flows}")"
verification_json="$(to_json_array_from_lines "${verification_refs}")"

if [[ -z "${OUTPUT_PATH}" ]]; then
  mkdir -p "${OUT_DIR}"
  OUTPUT_PATH="${OUT_DIR}/${COMPONENT_ID}.manifest.json"
else
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
fi

cat > "${OUTPUT_PATH}" <<EOF
{
  "schemaVersion": "1.0.0",
  "generatedAtUtc": "${timestamp_utc}",
  "component": {
    "id": "$(json_escape "${component_id}")",
    "kind": "$(json_escape "${kind}")",
    "language": "$(json_escape "${language}")",
    "framework": "$(json_escape "${framework}")",
    "buildTool": "$(json_escape "${build_tool}")",
    "sourcePath": "$(json_escape "${source_path}")",
    "targetPath": "$(json_escape "${target_path}")",
    "notes": "$(json_escape "${notes}")"
  },
  "runtime": {
    "defaultPort": ${default_port},
    "dependsOn": ${depends_on_json},
    "requiredEnv": ${required_env_json}
  },
  "contracts": {
    "primary": ${contract_primary}
  },
  "traceability": {
    "requirements": ${requirements_json},
    "stories": ${stories_json},
    "acceptanceCriteria": ${acceptance_json},
    "flows": ${flows_json},
    "verificationRefs": ${verification_json}
  },
  "constraints": {
    "preIngressCorsRequired": ${cors_required}
  }
}
EOF

echo "[ok] wrote manifest for ${COMPONENT_ID} -> ${OUTPUT_PATH}"

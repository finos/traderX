#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_CATALOG="${ROOT}/catalog/state-catalog.json"
LEARNING_YAML="${ROOT}/catalog/learning-paths.yaml"
LEARNING_MD="${ROOT}/catalog/learning-paths.md"

usage() {
  cat <<'EOF'
usage: bash pipeline/generate-learning-paths-catalog.sh [--check]

Generates:
  - catalog/learning-paths.yaml
  - catalog/learning-paths.md

Source of truth:
  - catalog/state-catalog.json

Options:
  --check   Validate generated output is up to date (no file writes)
EOF
}

CHECK_MODE=0
while (($# > 0)); do
  case "$1" in
    --check)
      CHECK_MODE=1
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

if [[ ! -f "${STATE_CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${STATE_CATALOG}"
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/traderx-learning-paths.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

tmp_yaml="${tmp_dir}/learning-paths.yaml"
tmp_md="${tmp_dir}/learning-paths.md"

baseline_id="$(jq -r '.states | sort_by(.id) | .[0].id' "${STATE_CATALOG}")"
baseline_title="$(jq -r --arg id "${baseline_id}" '.states[] | select(.id == $id) | .title' "${STATE_CATALOG}")"

if [[ -z "${baseline_id}" || "${baseline_id}" == "null" ]]; then
  echo "[fail] no states found in ${STATE_CATALOG}"
  exit 1
fi

devex_states="$(
  jq -r '.states[] | select((.track // "devex") == "devex") | .id' "${STATE_CATALOG}" | sort
)"
architecture_states="$(
  jq -r '
    [
      (.states[] | select(.track == "architecture") | .id),
      (.states[] | select(.track == "architecture") | (.previous // [])[])
    ]
    | flatten
    | unique
    | sort
    | .[]
  ' "${STATE_CATALOG}"
)"
functional_states="$(
  jq -r '
    [
      (.states[] | select(.track == "functional") | .id),
      (.states[] | select(.track == "functional") | (.previous // [])[])
    ]
    | flatten
    | unique
    | sort
    | .[]
  ' "${STATE_CATALOG}"
)"
nonfunctional_states="$(
  jq -r '
    [
      (.states[] | select(.track == "nonfunctional") | .id),
      (.states[] | select(.track == "nonfunctional") | (.previous // [])[])
    ]
    | flatten
    | unique
    | sort
    | .[]
  ' "${STATE_CATALOG}"
)"

yaml_state_catalog="$(
  jq -r '
    .states
    | sort_by(.id)
    | .[]
    | "  - id: \(.id)\n" +
      (if ((.previous // []) | length) == 0
       then "    previous: []"
       else "    previous:\n" + ((.previous // []) | map("      - " + .) | join("\n"))
       end) +
      "\n    spec: \(.featurePack)/spec.md"
  ' "${STATE_CATALOG}"
)"

{
  cat <<EOF
version: 2
baseline:
  id: ${baseline_id}
  label: "State ${baseline_id%%-*}: ${baseline_title}"
  artifacts:
    spec: specs/${baseline_id}/spec.md
    requirements: specs/${baseline_id}/system/system-requirements.md
    flows: specs/${baseline_id}/system/end-to-end-flows.md
    architecture: specs/${baseline_id}/system/architecture.md

tracks:
  devex:
    description: "Developer experience and runtime topology progression."
    states:
EOF

  while IFS= read -r state; do
    [[ -n "${state}" ]] && echo "      - ${state}"
  done <<< "${devex_states}"

  cat <<'EOF'
  architecture:
    description: "Architecture substitutions and component-level platform changes."
    states:
EOF
  while IFS= read -r state; do
    [[ -n "${state}" ]] && echo "      - ${state}"
  done <<< "${architecture_states}"

  cat <<'EOF'
  functional:
    description: "Functional capability expansion built on architecture states."
    states:
EOF
  while IFS= read -r state; do
    [[ -n "${state}" ]] && echo "      - ${state}"
  done <<< "${functional_states}"

  cat <<'EOF'
  nonfunctional:
    description: "Security, reliability, and platform NFR overlays."
    states:
EOF
  if [[ -z "${nonfunctional_states}" ]]; then
    echo "      - planned"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${nonfunctional_states}"
  fi

  cat <<'EOF'

stateCatalog:
EOF
  echo "${yaml_state_catalog}"
} > "${tmp_yaml}"

{
  cat <<'EOF'
# Learning Paths Catalog

This file is generated from `catalog/state-catalog.json`.

## Baseline

EOF
  printf -- "- \`%s\`: %s\n" "${baseline_id}" "${baseline_title}"

  cat <<'EOF'

## Tracks

### DevEx

EOF
  while IFS= read -r state; do
    [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
  done <<< "${devex_states}"

  cat <<'EOF'

### Architecture

EOF
  if [[ -z "${architecture_states}" ]]; then
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${architecture_states}"
  fi

  cat <<'EOF'

### Functional

EOF
  if [[ -z "${functional_states}" ]]; then
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${functional_states}"
  fi

  cat <<'EOF'

### Non-Functional

EOF
  if [[ -z "${nonfunctional_states}" ]]; then
    echo "- planned"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${nonfunctional_states}"
  fi

  cat <<'EOF'

## State Catalog

| State ID | Previous | Spec |
| --- | --- | --- |
EOF
  jq -r '
    .states
    | sort_by(.id)
    | .[]
    | "| `\(.id)` | " +
      ((.previous // []) | if length == 0 then "none" else (join(", ")) end) +
      " | `\(.featurePack)/spec.md` |"
  ' "${STATE_CATALOG}"
} > "${tmp_md}"

if ((CHECK_MODE == 1)); then
  diff_ok=1
  if ! diff -u "${LEARNING_YAML}" "${tmp_yaml}" >/dev/null; then
    echo "[fail] catalog/learning-paths.yaml is out of date"
    diff_ok=0
  fi
  if ! diff -u "${LEARNING_MD}" "${tmp_md}" >/dev/null; then
    echo "[fail] catalog/learning-paths.md is out of date"
    diff_ok=0
  fi
  if ((diff_ok == 0)); then
    echo "[hint] run: bash pipeline/generate-learning-paths-catalog.sh"
    exit 1
  fi
  echo "[ok] learning-paths catalog artifacts are up to date"
  exit 0
fi

cp "${tmp_yaml}" "${LEARNING_YAML}"
cp "${tmp_md}" "${LEARNING_MD}"
echo "[ok] generated catalog/learning-paths.yaml and catalog/learning-paths.md"

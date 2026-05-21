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

baseline_id="$(jq -r '.states[0].id // ""' "${STATE_CATALOG}")"
baseline_title="$(jq -r --arg id "${baseline_id}" '.states[] | select(.id == $id) | .title // ""' "${STATE_CATALOG}")"

if [[ -z "${baseline_id}" || "${baseline_id}" == "null" ]]; then
  echo "[fail] no states found in ${STATE_CATALOG}"
  exit 1
fi

track_states() {
  local track="$1"
  jq -r --arg track "${track}" '.states[] | select((.track // "") == $track) | .id' "${STATE_CATALOG}"
}

role_states() {
  local role="$1"
  jq -r --arg role "${role}" '.states[] | select((.primaryLineageRole // "canonical") == $role) | .id' "${STATE_CATALOG}"
}

convergence_states="$(
  jq -r '.states[] | select((.isConvergence // false) == true) | .id' "${STATE_CATALOG}"
)"

prelude_states="$(track_states "prelude")"
architecture_states="$(track_states "architecture")"
nonfunctional_states="$(track_states "nonfunctional")"
functional_states="$(track_states "functional")"
devex_states="$(track_states "devex")"
optional_states="$(role_states "optional")"

yaml_state_catalog="$(
  jq -r '
    .states[]
    | "  - id: \(.id)\n" +
      (if ((.previous // []) | length) == 0
       then "    previous: []"
       else "    previous:\n" + ((.previous // []) | map("      - " + .) | join("\n"))
       end) +
      "\n    convergenceLevel: \(.convergenceLevel // "none")" +
      "\n    isConvergence: \(.isConvergence // false)" +
      "\n    lineageRole: \(.primaryLineageRole // "canonical")" +
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
  prelude:
    description: "Onboarding progression before convergence baselines."
    states:
EOF
  if [[ -z "${prelude_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${prelude_states}"
  fi

  cat <<'EOF'
  devex:
    description: "Platform/runtime developer-experience progression."
    states:
EOF

  while IFS= read -r state; do
    [[ -n "${state}" ]] && echo "      - ${state}"
  done <<< "${devex_states}"

  cat <<'EOF'
  architecture:
    description: "Architecture substitutions and platform-component changes."
    states:
EOF
  if [[ -z "${architecture_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${architecture_states}"
  fi

  cat <<'EOF'
  functional:
    description: "Functional capability expansion states."
    states:
EOF
  if [[ -z "${functional_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${functional_states}"
  fi

  cat <<'EOF'
  nonfunctional:
    description: "Non-functional overlays (observability, resilience, operations)."
    states:
EOF
  if [[ -z "${nonfunctional_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${nonfunctional_states}"
  fi

  cat <<'EOF'
  optional:
    description: "Optional side branches not in primary publish lineage."
    states:
EOF
  if [[ -z "${optional_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${optional_states}"
  fi

  cat <<'EOF'
  convergence:
    description: "Named convergence milestones (C0/C1/C2/C3)."
    states:
EOF
  if [[ -z "${convergence_states}" ]]; then
    echo "      - none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && echo "      - ${state}"
    done <<< "${convergence_states}"
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

### Prelude

EOF
  if [[ -z "${prelude_states}" ]]; then
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${prelude_states}"
  fi

  cat <<'EOF'

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
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${nonfunctional_states}"
  fi

  cat <<'EOF'

### Optional

EOF
  if [[ -z "${optional_states}" ]]; then
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${optional_states}"
  fi

  cat <<'EOF'

### Convergence

EOF
  if [[ -z "${convergence_states}" ]]; then
    echo "- none"
  else
    while IFS= read -r state; do
      [[ -n "${state}" ]] && printf -- "- \`%s\`\n" "${state}"
    done <<< "${convergence_states}"
  fi

  cat <<'EOF'

## State Catalog

| State ID | Previous | Convergence | Is Convergence | Role | Spec |
| --- | --- | --- | --- | --- | --- |
EOF
  jq -r '
    .states[]
    | "| `\(.id)` | " +
      ((.previous // []) | if length == 0 then "none" else (join(", ")) end) +
      " | `\(.convergenceLevel // "none")` | `\(.isConvergence // false)` | `\(.primaryLineageRole // "canonical")` | `\(.featurePack)/spec.md` |"
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

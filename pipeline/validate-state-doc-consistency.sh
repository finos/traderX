#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"
SPECS_README="${ROOT}/specs/README.md"
GETTING_STARTED="${ROOT}/docs/spec-kit/getting-started-with-traderx.md"

fail() {
  echo "[fail] $*"
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing file: ${path}"
}

require_file "${CATALOG}"
require_file "${SPECS_README}"
require_file "${GETTING_STARTED}"

all_ids=()
while IFS= read -r line; do
  all_ids+=("${line}")
done < <(jq -r '.states[].id' "${CATALOG}")

implemented_ids=()
while IFS= read -r line; do
  implemented_ids+=("${line}")
done < <(jq -r '.states[] | select((.status // "") == "implemented") | .id' "${CATALOG}")

(( ${#all_ids[@]} > 0 )) || fail "state catalog is empty"

for id in "${all_ids[@]}"; do
  [[ -d "${ROOT}/specs/${id}" ]] || fail "missing state directory: specs/${id}"
done

active_packs=()
while IFS= read -r line; do
  active_packs+=("${line}")
done < <(
  awk '
    /^## Active Feature Packs/ {in_block=1; next}
    in_block && /^## / {in_block=0}
    in_block && /^- `/ {
      line=$0
      gsub(/^- `/, "", line)
      gsub(/`$/, "", line)
      print line
    }
  ' "${SPECS_README}"
)

for id in "${all_ids[@]}"; do
  found=0
  for listed in "${active_packs[@]}"; do
    if [[ "${listed}" == "${id}" ]]; then
      found=1
      break
    fi
  done
  (( found == 1 )) || fail "specs/README.md Active Feature Packs missing ${id}"
done

for listed in "${active_packs[@]}"; do
  found=0
  for id in "${all_ids[@]}"; do
    if [[ "${listed}" == "${id}" ]]; then
      found=1
      break
    fi
  done
  (( found == 1 )) || fail "specs/README.md has non-catalog Active Feature Pack: ${listed}"
done

seen_feature_pack_numbers=()
seen_feature_pack_files=()
for id in "${all_ids[@]}"; do
  readme="${ROOT}/specs/${id}/README.md"
  require_file "${readme}"
  first_line="$(sed -n '1p' "${readme}")"
  expected_num="${id%%-*}"

  if [[ "${first_line}" =~ ^#\ Feature\ Pack\ ([0-9]{3}): ]]; then
    actual_num="${BASH_REMATCH[1]}"
    [[ "${actual_num}" == "${expected_num}" ]] || fail "${readme} heading number ${actual_num} does not match state id ${expected_num}"
    idx=-1
    i=0
    for seen_num in "${seen_feature_pack_numbers[@]-}"; do
      if [[ "${seen_num}" == "${actual_num}" ]]; then
        idx="${i}"
        break
      fi
      i=$((i + 1))
    done
    if (( idx >= 0 )); then
      fail "duplicate Feature Pack number ${actual_num} in ${readme} and ${seen_feature_pack_files[${idx}]}"
    fi
    seen_feature_pack_numbers+=("${actual_num}")
    seen_feature_pack_files+=("${readme}")
  elif [[ "${first_line}" =~ ^#\ ${expected_num}\  ]]; then
    # Allowed alternate style for baseline-style headers.
    :
  else
    fail "${readme} heading must begin with '# Feature Pack ${expected_num}:' or '# ${expected_num} ...'"
  fi
done

for id in "${implemented_ids[@]}"; do
  branch_ref="code/generated-state-${id}"
  if ! grep -q "${branch_ref}" "${GETTING_STARTED}"; then
    fail "missing generated branch link in getting-started doc: ${branch_ref}"
  fi
done

echo "[ok] state-doc consistency validated (${#all_ids[@]} states)"

#!/usr/bin/env bash
set -euo pipefail

ALLOWED_STATES=(
  "00-monolith"
  "01-basic-microservices"
  "02-containerized"
  "03-service-mesh"
  "04-contract-driven"
  "05-ai-first"
)

if (($# > 0)); then
  FILES=("$@")
else
  FILES=()
  while IFS= read -r file; do
    FILES+=("${file}")
  done < <(find docs/guide -type f -name "*.md" | sort)
fi

if ((${#FILES[@]} == 0)); then
  echo "[error] no guide files found"
  exit 1
fi

errors=0

extract_frontmatter() {
  awk '
    BEGIN { sep = 0 }
    /^---[[:space:]]*$/ {
      sep++
      if (sep == 1) { next }
      if (sep == 2) { exit }
    }
    sep == 1 { print }
  ' "$1"
}

contains_required_key() {
  local block="$1"
  local key="$2"
  grep -Eq "^${key}:[[:space:]]*" <<<"${block}"
}

is_allowed_state() {
  local state="$1"
  local allowed
  for allowed in "${ALLOWED_STATES[@]}"; do
    [[ "${state}" == "${allowed}" ]] && return 0
  done
  return 1
}

for file in "${FILES[@]}"; do
  block="$(extract_frontmatter "${file}")"

  if [[ -z "${block}" ]]; then
    echo "[fail] ${file}: missing front-matter block"
    errors=$((errors + 1))
    continue
  fi

  for key in id title level prereqs outcomes state tags estimatedTimeMins owner; do
    if ! contains_required_key "${block}" "${key}"; then
      echo "[fail] ${file}: missing required key '${key}'"
      errors=$((errors + 1))
    fi
  done

  level="$(sed -nE 's/^level:[[:space:]]*([0-9]+).*/\1/p' <<<"${block}" | head -n1)"
  if [[ -z "${level}" || ! "${level}" =~ ^[0-5]$ ]]; then
    echo "[fail] ${file}: level must be an integer between 0 and 5"
    errors=$((errors + 1))
  fi

  state_id="$(
    awk '
      BEGIN { in_state = 0 }
      /^state:[[:space:]]*$/ { in_state = 1; next }
      in_state && /^[^[:space:]]/ { in_state = 0 }
      in_state && /^[[:space:]]+id:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]+id:[[:space:]]*/, "", line)
        gsub(/"/, "", line)
        print line
        exit
      }
    ' <<<"${block}"
  )"

  if [[ -z "${state_id}" ]]; then
    echo "[fail] ${file}: state.id is missing"
    errors=$((errors + 1))
  elif ! is_allowed_state "${state_id}"; then
    echo "[fail] ${file}: invalid state.id '${state_id}'"
    errors=$((errors + 1))
  fi

  time_mins="$(sed -nE 's/^estimatedTimeMins:[[:space:]]*([0-9]+).*/\1/p' <<<"${block}" | head -n1)"
  if [[ -z "${time_mins}" ]]; then
    echo "[fail] ${file}: estimatedTimeMins must be a positive integer"
    errors=$((errors + 1))
  fi
done

if ((errors > 0)); then
  echo "[result] ${errors} validation issue(s) found"
  exit 1
fi

echo "[result] front-matter validation passed for ${#FILES[@]} file(s)"

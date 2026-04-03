#!/usr/bin/env bash
set -euo pipefail

if (($# > 0)); then
  FILES=("$@")
else
  FILES=()
  while IFS= read -r file; do
    FILES+=("${file}")
  done < <(find docs/learning -type f -name "*.md" | sort)
fi

if ((${#FILES[@]} == 0)); then
  echo "[error] no learning doc files found under docs/learning"
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

for file in "${FILES[@]}"; do
  block="$(extract_frontmatter "${file}")"

  if [[ -z "${block}" ]]; then
    echo "[fail] ${file}: missing front-matter block"
    errors=$((errors + 1))
    continue
  fi

  if ! contains_required_key "${block}" "title"; then
    echo "[fail] ${file}: missing required key 'title'"
    errors=$((errors + 1))
  fi
done

if ((errors > 0)); then
  echo "[result] ${errors} validation issue(s) found"
  exit 1
fi

echo "[result] front-matter validation passed for ${#FILES[@]} file(s)"

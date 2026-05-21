#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${1:-${ROOT}}"
GHCR_ROOT="${TARGET_ROOT}/runtime/ghcr"
ENFORCE_CLONE_SCRIPT_CHECKS=0
if [[ -f "${TARGET_ROOT}/RUN_FROM_CLONE.md" ]]; then
  ENFORCE_CLONE_SCRIPT_CHECKS=1
fi

if [[ ! -d "${GHCR_ROOT}" ]]; then
  echo "[ok] no GHCR runtime bundles found under ${TARGET_ROOT}"
  exit 0
fi

contains_exact() {
  local needle="$1"
  shift || true
  local candidate
  for candidate in "$@"; do
    if [[ "${candidate}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

extract_script_deps() {
  local script_path="$1"
  [[ -f "${script_path}" ]] || return 0
  sed -nE 's#.*\/scripts\/([A-Za-z0-9._-]+\.sh).*#scripts/\1#p' "${script_path}" | sort -u
}

supports_published_image_mode() {
  local entry_script_rel="$1"
  local queue=("${entry_script_rel}")
  local seen="|"
  local current current_path dep

  while ((${#queue[@]} > 0)); do
    current="${queue[0]}"
    queue=("${queue[@]:1}")
    if [[ "${seen}" == *"|${current}|"* ]]; then
      continue
    fi
    seen="${seen}${current}|"
    current_path="${TARGET_ROOT}/${current}"
    [[ -f "${current_path}" ]] || continue

    if grep -Eq 'TRADERX_USE_PUBLISHED_IMAGES|--use-published-images|TRADERX_PUBLISHED_NAMESPACE|TRADERX_PUBLISHED_TAG' "${current_path}"; then
      return 0
    fi

    while IFS= read -r dep; do
      [[ -n "${dep}" ]] || continue
      queue+=("${dep}")
    done < <(extract_script_deps "${current_path}")
  done

  return 1
}

references_pipeline_generate() {
  local entry_script_rel="$1"
  local queue=("${entry_script_rel}")
  local seen="|"
  local current current_path dep

  while ((${#queue[@]} > 0)); do
    current="${queue[0]}"
    queue=("${queue[@]:1}")
    if [[ "${seen}" == *"|${current}|"* ]]; then
      continue
    fi
    seen="${seen}${current}|"
    current_path="${TARGET_ROOT}/${current}"
    [[ -f "${current_path}" ]] || continue

    if grep -Eq '(^|[[:space:]"'"'"'])pipeline/generate-state\.sh([[:space:]"'"'"']|$)|/pipeline/generate-state\.sh' "${current_path}"; then
      return 0
    fi

    while IFS= read -r dep; do
      [[ -n "${dep}" ]] || continue
      queue+=("${dep}")
    done < <(extract_script_deps "${current_path}")
  done

  return 1
}

errors=0
bundle_count=0

while IFS= read -r readme; do
  ((bundle_count += 1))
  bundle_dir="$(dirname "${readme}")"
  state_id="$(basename "${bundle_dir}")"
  readme_rel="${readme#${TARGET_ROOT}/}"
  expected_script="./scripts/start-state-${state_id}-generated.sh"
  expected_compose_ref="runtime/ghcr/${state_id}/docker-compose.ghcr.yml"
  compose_file="${bundle_dir}/docker-compose.ghcr.yml"
  images_lock="${bundle_dir}/images.lock"

  if [[ ! -f "${images_lock}" ]]; then
    echo "[fail] ${readme_rel}: missing runtime/ghcr/${state_id}/images.lock"
    ((errors += 1))
  fi

  script_refs=()
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    script_refs+=("${ref}")
  done < <(grep -oE '\./scripts/[A-Za-z0-9._/-]+\.sh' "${readme}" | sort -u || true)
  script_refs_count="${#script_refs[@]}"

  compose_refs=()
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    compose_refs+=("${ref}")
  done < <(grep -oE 'runtime/ghcr/[A-Za-z0-9._-]+/docker-compose\.ghcr\.yml' "${readme}" | sort -u || true)
  compose_refs_count="${#compose_refs[@]}"

  if [[ -f "${compose_file}" ]]; then
    if [[ "${compose_refs_count}" -eq 0 ]]; then
      echo "[fail] ${readme_rel}: compose bundle exists but README does not reference ${expected_compose_ref}"
      ((errors += 1))
    fi
    if [[ "${script_refs_count}" -gt 0 ]]; then
      echo "[fail] ${readme_rel}: compose bundle README should not reference ./scripts/*.sh entrypoints"
      ((errors += 1))
    fi
    for ref in "${compose_refs[@]-}"; do
      [[ -n "${ref}" ]] || continue
      if [[ "${ref}" != "${expected_compose_ref}" ]]; then
        echo "[fail] ${readme_rel}: unexpected compose path reference ${ref} (expected ${expected_compose_ref})"
        ((errors += 1))
      fi
      if [[ ! -f "${TARGET_ROOT}/${ref}" ]]; then
        echo "[fail] ${readme_rel}: referenced compose path is missing: ${ref}"
        ((errors += 1))
      fi
    done
  else
    if [[ "${script_refs_count}" -eq 0 ]]; then
      echo "[fail] ${readme_rel}: expected start script reference ${expected_script}"
      ((errors += 1))
    elif ! contains_exact "${expected_script}" "${script_refs[@]-}"; then
      echo "[fail] ${readme_rel}: expected start script reference ${expected_script}"
      ((errors += 1))
    fi

    entry_script_rel="${expected_script#./}"
    if (( ENFORCE_CLONE_SCRIPT_CHECKS == 1 )) && [[ ! -f "${TARGET_ROOT}/pipeline/generate-state.sh" ]] && references_pipeline_generate "${entry_script_rel}"; then
      echo "[fail] ${readme_rel}: ${expected_script} depends on pipeline/generate-state.sh, but that file is not present in this bundle root"
      ((errors += 1))
    fi
  fi

  for ref in "${script_refs[@]-}"; do
    [[ -n "${ref}" ]] || continue
    script_rel="${ref#./}"
    if [[ ! -f "${TARGET_ROOT}/${script_rel}" ]]; then
      echo "[fail] ${readme_rel}: referenced script is missing: ${ref}"
      ((errors += 1))
    fi
  done

  if grep -Eq 'TRADERX_USE_PUBLISHED_IMAGES|TRADERX_PUBLISHED_NAMESPACE|TRADERX_PUBLISHED_TAG' "${readme}"; then
    entry_script_rel="${expected_script#./}"
    if ! supports_published_image_mode "${entry_script_rel}"; then
      echo "[fail] ${readme_rel}: README documents published-image mode but ${expected_script} (or its script dependency chain) does not support it"
      ((errors += 1))
    fi
  fi

done < <(find "${GHCR_ROOT}" -mindepth 2 -maxdepth 2 -type f -name README.md | sort)

if (( bundle_count == 0 )); then
  echo "[ok] no GHCR runtime bundle README files found under ${GHCR_ROOT}"
  exit 0
fi

if (( errors > 0 )); then
  echo "[fail] GHCR runtime bundle README validation failed (${errors} issue(s))"
  exit 1
fi

echo "[ok] GHCR runtime bundle README validation passed (${bundle_count} bundle(s), root=${TARGET_ROOT})"

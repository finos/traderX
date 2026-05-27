#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
COMPONENTS_ROOT="${3:-${GENERATED_ROOT}/code/components}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/prune-generated-state-removed-assets.sh <state-id> [target-root] [components-root]"
  exit 1
fi

if [[ ! -d "${ROOT}/specs" ]]; then
  echo "[fail] specs directory not found: ${ROOT}/specs"
  exit 1
fi

prune_records="$({
  node - "${ROOT}" "${STATE_ID}" <<'NODE'
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const stateId = process.argv[3];
const specsRoot = path.join(root, 'specs');

const parseStateNum = (value) => {
  const match = String(value || '').match(/^(\d+)/);
  if (!match) return null;
  return Number.parseInt(match[1], 10);
};

const currentNum = parseStateNum(stateId);
if (currentNum === null) {
  process.exit(0);
}

const entries = fs.readdirSync(specsRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort((a, b) => {
    const aNum = parseStateNum(a);
    const bNum = parseStateNum(b);
    if (aNum === null && bNum === null) return a.localeCompare(b);
    if (aNum === null) return 1;
    if (bNum === null) return -1;
    return aNum - bNum;
  });

for (const specDir of entries) {
  const manifestPath = path.join(specsRoot, specDir, 'generation', 'prune-manifest.json');
  if (!fs.existsSync(manifestPath)) {
    continue;
  }

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    console.error(`[fail] invalid prune manifest JSON: ${manifestPath}`);
    process.exit(2);
  }

  const manifestState = manifest.stateId || specDir;
  const manifestNum = parseStateNum(manifestState);
  if (manifestNum === null || manifestNum > currentNum) {
    continue;
  }

  const appliesToDescendants = manifest.appliesToDescendants !== false;
  if (!appliesToDescendants && manifestNum !== currentNum) {
    continue;
  }

  const artifacts = Array.isArray(manifest.removedArtifacts) ? manifest.removedArtifacts : [];
  for (const artifact of artifacts) {
    const id = artifact.id || `${manifestState}:unnamed-artifact`;
    const targetPaths = Array.isArray(artifact.targetPaths) ? artifact.targetPaths : [];
    const componentsPaths = Array.isArray(artifact.componentsPaths) ? artifact.componentsPaths : [];
    const forbiddenTargetPaths = Array.isArray(artifact.forbiddenTargetPaths)
      ? artifact.forbiddenTargetPaths
      : targetPaths;
    const forbiddenComponentsPaths = Array.isArray(artifact.forbiddenComponentsPaths)
      ? artifact.forbiddenComponentsPaths
      : componentsPaths;
    const forbiddenScriptPatterns = Array.isArray(artifact.forbiddenScriptPatterns)
      ? artifact.forbiddenScriptPatterns
      : [];

    for (const rel of targetPaths) {
      console.log(`REMOVE_TARGET\t${id}\t${rel}`);
    }
    for (const rel of componentsPaths) {
      console.log(`REMOVE_COMPONENT\t${id}\t${rel}`);
    }
    for (const rel of forbiddenTargetPaths) {
      console.log(`FORBID_TARGET_PATH\t${id}\t${rel}`);
    }
    for (const rel of forbiddenComponentsPaths) {
      console.log(`FORBID_COMPONENT_PATH\t${id}\t${rel}`);
    }
    for (const pattern of forbiddenScriptPatterns) {
      console.log(`FORBID_SCRIPT_PATTERN\t${id}\t${pattern}`);
    }
  }
}
NODE
} 2>&1)"

if [[ -z "${prune_records}" ]]; then
  echo "[info] no prune manifests apply to ${STATE_ID}"
  exit 0
fi

if printf '%s\n' "${prune_records}" | rg -q '^\[fail\]'; then
  printf '%s\n' "${prune_records}"
  exit 1
fi

declare -a forbid_script_patterns

while IFS=$'\t' read -r op artifact value; do
  [[ -n "${op}" ]] || continue
  case "${op}" in
    REMOVE_TARGET)
      if [[ -e "${TARGET_ROOT}/${value}" ]]; then
        rm -rf "${TARGET_ROOT}/${value}"
        echo "[info] pruned target artifact (${artifact}): ${TARGET_ROOT}/${value}"
      fi
      ;;
    REMOVE_COMPONENT)
      if [[ -e "${COMPONENTS_ROOT}/${value}" ]]; then
        rm -rf "${COMPONENTS_ROOT}/${value}"
        echo "[info] pruned component artifact (${artifact}): ${COMPONENTS_ROOT}/${value}"
      fi
      ;;
    FORBID_TARGET_PATH)
      if [[ -e "${TARGET_ROOT}/${value}" ]]; then
        echo "[fail] forbidden target artifact still present (${artifact}): ${TARGET_ROOT}/${value}"
        exit 1
      fi
      ;;
    FORBID_COMPONENT_PATH)
      if [[ -e "${COMPONENTS_ROOT}/${value}" ]]; then
        echo "[fail] forbidden component artifact still present (${artifact}): ${COMPONENTS_ROOT}/${value}"
        exit 1
      fi
      ;;
    FORBID_SCRIPT_PATTERN)
      forbid_script_patterns+=("${artifact}:::${value}")
      ;;
    *)
      echo "[fail] unknown prune record operation: ${op}"
      exit 1
      ;;
  esac
done <<< "${prune_records}"

scan_file_if_present() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || return 1
  printf '%s\n' "${file_path}"
  return 0
}

declare -a scan_files
while IFS= read -r script_path; do
  [[ -n "${script_path}" ]] || continue
  scan_files+=("${script_path}")
done < <(find "${TARGET_ROOT}/scripts" -maxdepth 1 -type f \( -name 'start-state-*-generated.sh' -o -name 'stop-state-*-generated.sh' -o -name 'status-state-*-generated.sh' -o -name 'test-state-*.sh' \) -print 2>/dev/null | sort)

for top_file in \
  "${TARGET_ROOT}/start-env.sh" \
  "${TARGET_ROOT}/stop-env.sh" \
  "${TARGET_ROOT}/status-env.sh" \
  "${TARGET_ROOT}/test-env.sh" \
  "${TARGET_ROOT}/RUN_FROM_GENERATED.md" \
  "${TARGET_ROOT}/ci/state-metadata.json"; do
  if [[ -f "${top_file}" ]]; then
    scan_files+=("${top_file}")
  fi
done

if [[ "${#forbid_script_patterns[@]}" -gt 0 && "${#scan_files[@]}" -gt 0 ]]; then
  local_match=0
  for rule in "${forbid_script_patterns[@]}"; do
    artifact="${rule%%:::*}"
    pattern="${rule#*:::}"
    if rg -n --no-messages -e "${pattern}" "${scan_files[@]}" >/tmp/traderx-prune-match.out; then
      echo "[fail] forbidden reference pattern detected (${artifact}): ${pattern}"
      cat /tmp/traderx-prune-match.out
      local_match=1
      break
    fi
  done
  rm -f /tmp/traderx-prune-match.out
  if (( local_match == 1 )); then
    exit 1
  fi
fi

echo "[ok] pruned removed artifacts and verified post-prune invariants for ${STATE_ID}"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="${ROOT}/templates/state-pack-template"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage: bash pipeline/scaffold-state-pack.sh <state-id> --title "<state title>" --previous <state-id> [--track <track>]

Example:
  bash pipeline/scaffold-state-pack.sh 004-kubernetes-runtime \
    --title "Kubernetes Runtime Baseline" \
    --previous 003-containerized-compose-runtime \
    --track devex

Supported tracks:
  devex | architecture | functional | nonfunctional
EOF
}

STATE_ID="${1:-}"
if [[ -z "${STATE_ID}" ]]; then
  usage
  exit 1
fi
shift || true

TITLE=""
PREVIOUS=""
TRACK="devex"

while (( "$#" )); do
  case "$1" in
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --previous)
      PREVIOUS="${2:-}"
      shift 2
      ;;
    --track)
      TRACK="${2:-}"
      shift 2
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

if [[ ! "${STATE_ID}" =~ ^[0-9]{3}-[a-z0-9-]+$ ]]; then
  echo "[fail] state-id must match NNN-kebab-name: ${STATE_ID}"
  exit 1
fi

if [[ -z "${TITLE}" ]]; then
  echo "[fail] --title is required"
  exit 1
fi

if [[ -z "${PREVIOUS}" ]]; then
  echo "[fail] --previous is required"
  exit 1
fi

if [[ ! -d "${TEMPLATE_DIR}" ]]; then
  echo "[fail] missing state-pack template dir: ${TEMPLATE_DIR}"
  exit 1
fi

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

if ! jq -e --arg id "${PREVIOUS}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
  echo "[fail] previous state does not exist in catalog: ${PREVIOUS}"
  exit 1
fi

if jq -e --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
  echo "[fail] state already exists in catalog: ${STATE_ID}"
  exit 1
fi

STATE_DIR="${ROOT}/specs/${STATE_ID}"
if [[ -e "${STATE_DIR}" ]]; then
  echo "[fail] target state directory already exists: ${STATE_DIR}"
  exit 1
fi

STATE_NUMBER="${STATE_ID%%-*}"
STATE_SLUG="${STATE_ID#*-}"
TODAY="$(date +%Y-%m-%d)"
FEATURE_PACK="specs/${STATE_ID}"
PUBLISH_BRANCH="code/generated-state-${STATE_ID}"
PUBLISH_TAG="generated/${STATE_ID}/v1"
HOOK_SCRIPT_REL="pipeline/generate-state-${STATE_ID}.sh"
HOOK_SCRIPT_PATH="${ROOT}/${HOOK_SCRIPT_REL}"
SMOKE_SCRIPT_REL="scripts/test-state-${STATE_ID}.sh"
SMOKE_SCRIPT_PATH="${ROOT}/${SMOKE_SCRIPT_REL}"

mkdir -p "${STATE_DIR}"
cp -R "${TEMPLATE_DIR}/." "${STATE_DIR}/"

render_file() {
  local source_file="$1"
  local target_file="${source_file%.tmpl}"
  sed \
    -e "s/__STATE_ID__/${STATE_ID}/g" \
    -e "s/__STATE_NUMBER__/${STATE_NUMBER}/g" \
    -e "s/__STATE_SLUG__/${STATE_SLUG}/g" \
    -e "s/__STATE_TITLE__/${TITLE}/g" \
    -e "s/__TRACK__/${TRACK}/g" \
    -e "s/__PREVIOUS_STATE__/${PREVIOUS}/g" \
    -e "s/__TODAY__/${TODAY}/g" \
    -e "s|__GEN_HOOK__|${HOOK_SCRIPT_REL}|g" \
    -e "s|__SMOKE_SCRIPT__|${SMOKE_SCRIPT_REL}|g" \
    -e "s|__FEATURE_PACK__|${FEATURE_PACK}|g" \
    -e "s|__PUBLISH_BRANCH__|${PUBLISH_BRANCH}|g" \
    -e "s|__PUBLISH_TAG__|${PUBLISH_TAG}|g" \
    "${source_file}" > "${target_file}"
  rm -f "${source_file}"
}

while IFS= read -r tmpl_file; do
  render_file "${tmpl_file}"
done < <(find "${STATE_DIR}" -type f -name '*.tmpl' | sort)

cat > "${HOOK_SCRIPT_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="${STATE_ID}"
PARENT_STATE_ID="${PREVIOUS}"

echo "[info] generating parent state \${PARENT_STATE_ID} for \${STATE_ID}"
bash "\${ROOT}/pipeline/generate-state.sh" "\${PARENT_STATE_ID}"
bash "\${ROOT}/pipeline/apply-state-patchset.sh" "\${STATE_ID}"
bash "\${ROOT}/pipeline/generate-state-architecture-doc.sh" "\${STATE_ID}"

cat <<'EOT'
[todo] replace with state-specific summary lines
EOT
EOF
chmod +x "${HOOK_SCRIPT_PATH}"

mkdir -p "${STATE_DIR}/generation/patches"
touch "${STATE_DIR}/generation/patches/.gitkeep"

cat > "${SMOKE_SCRIPT_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

echo "[todo] smoke tests not implemented yet for ${STATE_ID}"
echo "[todo] implement state-specific smoke assertions"
exit 1
EOF
chmod +x "${SMOKE_SCRIPT_PATH}"

tmp_catalog="$(mktemp "${TMPDIR:-/tmp}/traderx-state-catalog.XXXXXX")"

jq \
  --arg id "${STATE_ID}" \
  --arg title "${TITLE}" \
  --arg track "${TRACK}" \
  --arg featurePack "${FEATURE_PACK}" \
  --arg previous "${PREVIOUS}" \
  --arg entry "bash pipeline/generate-state.sh ${STATE_ID}" \
  --arg branch "${PUBLISH_BRANCH}" \
  --arg tag "${PUBLISH_TAG}" \
  '.states += [{
    "id": $id,
    "title": $title,
    "status": "planned",
    "track": $track,
    "featurePack": $featurePack,
    "previous": [$previous],
    "generation": {
      "mode": "planned",
      "entrypoint": $entry,
      "runtime": "TBD"
    },
    "publish": {
      "branch": $branch,
      "tag": $tag
    }
  }]' \
  "${CATALOG}" > "${tmp_catalog}"

mv "${tmp_catalog}" "${CATALOG}"

bash "${ROOT}/pipeline/generate-learning-paths-catalog.sh"
node "${ROOT}/pipeline/generate-state-docs-from-catalog.mjs"

echo "[ok] scaffolded new state pack: ${STATE_ID}"
echo "[ok] created feature pack: ${STATE_DIR}"
echo "[ok] created generation hook: ${HOOK_SCRIPT_REL}"
echo "[ok] created smoke-test stub: ${SMOKE_SCRIPT_REL}"
echo "[ok] updated learning-paths catalog artifacts"

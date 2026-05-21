#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_CATALOG="${ROOT}/catalog/state-catalog.json"
STATE_ID="${1:-}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/generate-state-architecture-doc.sh <state-id>"
  echo "example: bash pipeline/generate-state-architecture-doc.sh 001-baseline-uncontainerized-parity"
  exit 1
fi

if [[ ! -f "${STATE_CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${STATE_CATALOG}"
  exit 1
fi

FEATURE_PACK="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .featurePack' "${STATE_CATALOG}")"
if [[ -z "${FEATURE_PACK}" || "${FEATURE_PACK}" == "null" ]]; then
  echo "[fail] state not found in catalog: ${STATE_ID}"
  exit 1
fi

MODEL_FILE="${ROOT}/${FEATURE_PACK}/system/architecture.model.json"
OUT_FILE="${ROOT}/${FEATURE_PACK}/system/architecture.md"

if [[ ! -f "${MODEL_FILE}" ]]; then
  echo "[fail] missing architecture model: ${MODEL_FILE}"
  exit 1
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/traderx-architecture.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT

TITLE="$(jq -r '.title' "${MODEL_FILE}")"
DESCRIPTION="$(jq -r '.description' "${MODEL_FILE}")"
INHERITS_FROM="$(jq -r '.inheritsFrom // empty' "${MODEL_FILE}")"
FLOW_DOC="$(jq -r '.flowDoc // "system/end-to-end-flows.md"' "${MODEL_FILE}")"

{
  echo "# ${TITLE}"
  echo
  echo "${DESCRIPTION}"
  echo

  if [[ -n "${INHERITS_FROM}" ]]; then
    echo "- Inherits architectural baseline from: \`${INHERITS_FROM}\`"
  fi
  echo "- Generated from: \`system/architecture.model.json\`"
  echo "- Canonical flows: \`${FLOW_DOC}\`"
  echo

  if jq -e '.entrypoints and (.entrypoints | length > 0)' "${MODEL_FILE}" >/dev/null; then
    echo "## Entry Points"
    echo
    jq -r '.entrypoints[] | "- `" + .name + "`: `" + .url + "`"' "${MODEL_FILE}"
    echo
  fi

  echo "## Architecture Diagram"
  echo
  echo '```mermaid'
  echo 'flowchart LR'
  jq -r '.nodes[] | "  " + .id + "[\"" + (.label | gsub("\""; "\\\\\"")) + "\"]"' "${MODEL_FILE}"
  jq -r '
    .edges[] |
    if ((.label // "") == "")
    then "  " + .from + " --> " + .to
    else "  " + .from + " -->|\"" + ((.label // "") | gsub("\""; "\\\\\"")) + "\"| " + .to
    end
  ' "${MODEL_FILE}"
  echo '```'
  echo

  echo "## Node Catalog"
  echo
  echo "| Node | Kind | Label | Notes |"
  echo "| --- | --- | --- | --- |"
  jq -r '.nodes[] | "| `" + .id + "` | " + (.kind // "component") + " | " + .label + " | " + (.description // "-") + " |"' "${MODEL_FILE}"
  echo

  if jq -e '.notes and (.notes | length > 0)' "${MODEL_FILE}" >/dev/null; then
    echo "## State Notes"
    echo
    jq -r '.notes[] | "- " + .' "${MODEL_FILE}"
    echo
  fi
} > "${tmp}"

mv "${tmp}" "${OUT_FILE}"
echo "[done] generated ${OUT_FILE} from ${MODEL_FILE}"

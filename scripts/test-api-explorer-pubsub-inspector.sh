#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
SUBJECT_MAP_FILE="${2:-specs/008-pricing-awareness-market-data/system/messaging-subject-map.md}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(git -C "${REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${REPO_ROOT}")"

resolve_subject_map_path() {
  local candidate="$1"
  if [[ -f "${candidate}" ]]; then
    echo "${candidate}"
    return
  fi
  if [[ -f "${REPO_ROOT}/${candidate}" ]]; then
    echo "${REPO_ROOT}/${candidate}"
    return
  fi
  if [[ -f "${WORKSPACE_ROOT}/${candidate}" ]]; then
    echo "${WORKSPACE_ROOT}/${candidate}"
    return
  fi
  echo "${WORKSPACE_ROOT}/${candidate}"
}

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${REPO_ROOT}/generated/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "${INGRESS_URL}" "${SUBJECT_MAP_FILE}"
  fi
fi

assert_content_type() {
  local url="$1"
  local expected_substring="$2"
  local headers content_type
  headers="$(curl -fsSI "${url}")" || {
    echo "[error] request failed for ${url}"
    exit 1
  }
  content_type="$(
    printf '%s\n' "${headers}" \
      | awk -F': *' 'tolower($1)=="content-type"{print tolower($2); exit}' \
      | tr -d '\r'
  )"
  if [[ -z "${content_type}" ]]; then
    echo "[error] missing Content-Type header for ${url}"
    exit 1
  fi
  if [[ "${content_type}" != *"${expected_substring}"* ]]; then
    echo "[error] unexpected Content-Type for ${url}: ${content_type} (expected substring: ${expected_substring})"
    exit 1
  fi
}

echo "[check] api explorer index route"
index_html="$(curl -fsS "${INGRESS_URL}/api/docs/")"
printf '%s' "${index_html}" | rg -q 'pubsub-inspector\.html' || {
  echo "[error] expected pubsub inspector link in /api/docs/ index"
  exit 1
}
printf '%s' "${index_html}" | rg -q 'window\.location\.href\.replace\(/\\/\[\^/\]\*\$/' || {
  echo "[error] expected computed relative inspector URL logic in /api/docs/ index"
  exit 1
}
printf '%s' "${index_html}" | rg -q 'href="/"' || {
  echo "[error] expected back-to-app link to / in /api/docs/ index"
  exit 1
}
assert_content_type "${INGRESS_URL}/api/docs/" "text/html"

echo "[check] pubsub inspector canonical route"
inspector_html="$(curl -fsS "${INGRESS_URL}/api/docs/pubsub-inspector.html")"
printf '%s' "${inspector_html}" | rg -q 'MAX_BUFFER = 2000' || {
  echo "[error] expected 2000 message buffer cap in pubsub inspector"
  exit 1
}
printf '%s' "${inspector_html}" | rg -q 'id="filter-input"' || {
  echo "[error] expected filter input in pubsub inspector"
  exit 1
}
printf '%s' "${inspector_html}" | rg -q 'id="pause-btn"' || {
  echo "[error] expected pause control in pubsub inspector"
  exit 1
}
printf '%s' "${inspector_html}" | rg -q 'id="clear-btn"' || {
  echo "[error] expected clear control in pubsub inspector"
  exit 1
}
printf '%s' "${inspector_html}" | rg -q './vendor/nats\.ws/nats\.js' || {
  echo "[error] expected local vendored nats.ws asset in pubsub inspector"
  exit 1
}
printf '%s' "${inspector_html}" | rg -q 'href="/"' || {
  echo "[error] expected back-to-app link to / in pubsub inspector"
  exit 1
}
if printf '%s' "${inspector_html}" | rg -qi 'unpkg|jsdelivr|skypack|cdn'; then
  echo "[error] pubsub inspector must not depend on CDN assets"
  exit 1
fi
assert_content_type "${INGRESS_URL}/api/docs/pubsub-inspector.html" "text/html"

echo "[check] pubsub inspector legacy no-extension compatibility route"
curl -fsS "${INGRESS_URL}/api/docs/pubsub-inspector" >/dev/null || {
  echo "[error] expected /api/docs/pubsub-inspector compatibility route"
  exit 1
}

echo "[check] api explorer catalog messaging subjects"
catalog_file="$(mktemp)"
trap 'rm -f "${catalog_file}"' EXIT
curl -fsS "${INGRESS_URL}/api/docs/catalog.json" > "${catalog_file}"
assert_content_type "${INGRESS_URL}/api/docs/catalog.json" "application/json"

jq -e '.messagingSubjects | type == "array"' "${catalog_file}" >/dev/null || {
  echo "[error] expected catalog.json to include messagingSubjects array"
  exit 1
}

SUBJECT_MAP_PATH="$(resolve_subject_map_path "${SUBJECT_MAP_FILE}")"
if [[ ! -f "${SUBJECT_MAP_PATH}" ]]; then
  echo "[warn] subject map file not found for strict inspector topic validation: ${SUBJECT_MAP_PATH}"
  exit 0
fi

CATALOG_FILE="${catalog_file}" SUBJECT_MAP_FILE="${SUBJECT_MAP_PATH}" node <<'NODE'
const fs = require('node:fs');

const catalogFile = process.env.CATALOG_FILE;
const mapFile = process.env.SUBJECT_MAP_FILE;

const parseSubjects = (markdown) => {
  const lines = String(markdown || '').split(/\r?\n/);
  const subjects = [];
  let current = null;
  for (const line of lines) {
    const familyMatch = line.match(/^\s*-\s+`([^`]+)`\s*$/);
    if (familyMatch) {
      current = {
        subject: familyMatch[1].trim(),
        pattern: familyMatch[1].trim(),
        wildcard: false,
      };
      subjects.push(current);
      continue;
    }
    if (!current) {
      continue;
    }
    const wildcardMatch = line.match(/^\s*-\s+wildcard:\s+`?yes`?(?:\s+\(`([^`]+)`\))?/i);
    if (wildcardMatch) {
      current.wildcard = true;
      if (wildcardMatch[1]) {
        current.pattern = wildcardMatch[1].trim();
      }
    }
  }
  return subjects;
};

const catalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
const map = fs.readFileSync(mapFile, 'utf8');
const expected = parseSubjects(map);
const actual = Array.isArray(catalog.messagingSubjects) ? catalog.messagingSubjects : [];

const actualByPattern = new Map(actual.map((entry) => [String(entry.pattern || ''), entry]));
const missing = [];
for (const subject of expected) {
  const actualEntry = actualByPattern.get(subject.pattern);
  if (!actualEntry) {
    missing.push(subject.pattern);
    continue;
  }
  if (subject.wildcard && !actualEntry.wildcard) {
    console.error(`[error] expected wildcard=true for pattern ${subject.pattern}`);
    process.exit(1);
  }
}

if (missing.length > 0) {
  console.error(`[error] missing messagingSubjects patterns in catalog: ${missing.join(', ')}`);
  process.exit(1);
}

console.log(`[info] inspector messagingSubjects validated (${expected.length} subjects)`);
NODE

echo "[done] api explorer pubsub inspector contract checks passed"

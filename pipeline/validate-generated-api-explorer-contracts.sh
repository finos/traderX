#!/usr/bin/env bash
set -euo pipefail

# Final generated-state check for served API explorer assets.
#
# Services without a runtime OpenAPI spec (today: Reference Data) are served
# from a static contract copied by pipeline/install-generated-api-explorer.sh.
# That contract must declare the service's edge route prefix in `servers`, or
# Swagger UI "Try it out" calls the edge root and receives the web UI instead.
# This runs after all generation steps so a later overlay or installer that
# rewrites the explorer assets cannot silently drop the prefix.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
COMPONENTS_ROOT="${3:-${GENERATED_ROOT}/code/components}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/validate-generated-api-explorer-contracts.sh <state-id> [target-root] [components-root]"
  exit 1
fi

STATE_ID="${STATE_ID}" \
TARGET_ROOT="${TARGET_ROOT}" \
COMPONENTS_ROOT="${COMPONENTS_ROOT}" \
node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const stateId = process.env.STATE_ID;
const targetRoot = process.env.TARGET_ROOT;
const componentsRoot = process.env.COMPONENTS_ROOT;

// Every location an explorer copy is served from at runtime.
const servedCopies = [
  {
    label: fs.existsSync(path.join(targetRoot, 'kubernetes-runtime'))
      ? 'api-explorer (Kubernetes image source)'
      : 'api-explorer',
    dir: path.join(targetRoot, 'api-explorer'),
  },
  { label: 'Compose ingress', dir: path.join(targetRoot, 'ingress', 'api-explorer') },
  { label: 'edge proxy component', dir: path.join(componentsRoot, 'edge-proxy-specfirst', 'api-explorer') },
  { label: 'edge proxy runtime', dir: path.join(targetRoot, 'edge-proxy', 'api-explorer') },
];

// Prefixes that must never regress, independent of catalog contents.
const requiredPrefixes = { 'reference-data': '/reference-data' };

const failures = [];
let checkedCopies = 0;
let checkedContracts = 0;

function declaredServerUrls(text) {
  const lines = text.split(/\r?\n/);
  const blocks = lines.filter((line) => /^servers:\s*$/.test(line)).length;
  const urls = [];
  let inServers = false;
  for (const line of lines) {
    if (/^servers:\s*$/.test(line)) {
      inServers = true;
      continue;
    }
    // Block-sequence items may start at column 0 ("- url: ..."); only a new
    // top-level mapping key ends the servers block.
    if (inServers && /^[^\s#-][^:]*:/.test(line)) {
      inServers = false;
    }
    if (inServers) {
      const match = /^\s*-\s*url:\s*['"]?([^'"\s]+)['"]?\s*$/.exec(line);
      if (match) urls.push(match[1]);
    }
  }
  return { blocks, urls };
}

for (const copy of servedCopies) {
  const catalogFile = path.join(copy.dir, 'catalog.json');
  if (!fs.existsSync(catalogFile)) {
    continue;
  }
  checkedCopies += 1;

  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
  } catch (error) {
    failures.push(`${copy.label}: unreadable catalog.json (${error.message})`);
    continue;
  }
  const services = Array.isArray(catalog.services) ? catalog.services : [];

  for (const [serviceId, prefix] of Object.entries(requiredPrefixes)) {
    const service = services.find((entry) => entry.id === serviceId);
    if (service && !service.runtimeSpecPath && service.runtimeBasePath !== prefix) {
      failures.push(`${copy.label}: catalog ${serviceId} runtimeBasePath is ${JSON.stringify(service.runtimeBasePath)}, expected ${prefix}`);
    }
  }

  for (const service of services) {
    if (service.runtimeSpecPath || !service.runtimeBasePath || !service.contractUrl) {
      continue;
    }
    const contractFile = path.join(copy.dir, 'contracts', path.basename(service.contractUrl));
    if (!fs.existsSync(contractFile)) {
      failures.push(`${copy.label}: missing static contract for ${service.id}: ${contractFile}`);
      continue;
    }
    checkedContracts += 1;
    const { blocks, urls } = declaredServerUrls(fs.readFileSync(contractFile, 'utf8'));
    if (blocks !== 1) {
      failures.push(`${copy.label}: ${service.id} contract must declare exactly one servers block (found ${blocks})`);
    } else if (urls.length !== 1 || urls[0] !== service.runtimeBasePath) {
      failures.push(`${copy.label}: ${service.id} contract servers ${JSON.stringify(urls)} must be ["${service.runtimeBasePath}"]`);
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`[fail] ${failure}`);
  }
  console.error('[hint] static explorer contracts are written by pipeline/install-generated-api-explorer.sh from catalog/state-catalog.json');
  process.exit(1);
}

if (checkedCopies === 0) {
  console.log(`[info] no served API explorer assets found for ${stateId}; skipping contract prefix checks`);
} else {
  console.log(`[ok] api explorer static contract prefixes validated for ${stateId} (${checkedCopies} served copies, ${checkedContracts} static contracts)`);
}
NODE

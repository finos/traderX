#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
COMPONENTS_ROOT="${3:-${GENERATED_ROOT}/code/components}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/install-generated-ui-state-metadata.sh <state-id> [target-root] [components-root]"
  exit 1
fi

ROOT="${ROOT}" \
STATE_ID="${STATE_ID}" \
TARGET_ROOT="${TARGET_ROOT}" \
COMPONENTS_ROOT="${COMPONENTS_ROOT}" \
TRADERX_SOURCE_REPO_URL="${TRADERX_SOURCE_REPO_URL:-}" \
node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const childProcess = require('node:child_process');

const root = process.env.ROOT;
const stateId = process.env.STATE_ID;
const targetRoot = process.env.TARGET_ROOT;
const componentsRoot = process.env.COMPONENTS_ROOT;
const explicitRepoUrl = process.env.TRADERX_SOURCE_REPO_URL || '';

const stateCatalogPath = path.join(root, 'catalog', 'state-catalog.json');
const stateCatalog = JSON.parse(fs.readFileSync(stateCatalogPath, 'utf8'));
const states = Array.isArray(stateCatalog.states) ? stateCatalog.states : [];
const stateById = new Map(states.map((entry) => [entry.id, entry]));
const activeState = stateById.get(stateId);

if (!activeState) {
  throw new Error(`state not found in catalog: ${stateId}`);
}

function stateNumber(value) {
  const match = /^([0-9]{3})-/.exec(value || '');
  return match ? Number.parseInt(match[1], 10) : 0;
}

function branchUrlEncode(branchName) {
  return String(branchName)
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

function deriveRepoBaseUrl() {
  const normalize = (input) => {
    if (!input) {
      return '';
    }
    let url = input.trim();
    if (!url) {
      return '';
    }
    if (url.startsWith('git@github.com:')) {
      url = `https://github.com/${url.slice('git@github.com:'.length)}`;
    }
    if (url.endsWith('.git')) {
      url = url.slice(0, -4);
    }
    return url.replace(/\/+$/, '');
  };

  if (explicitRepoUrl) {
    return normalize(explicitRepoUrl);
  }

  try {
    const remoteUrl = childProcess
      .execSync('git config --get remote.origin.url', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .trim();
    return normalize(remoteUrl);
  } catch (_error) {
    return '';
  }
}

function buildLineage(stateEntry) {
  const lineage = [];
  const seen = new Set([stateEntry.id]);
  let cursor = stateEntry;

  while (Array.isArray(cursor.previous) && cursor.previous.length > 0) {
    const parentId = cursor.previous[0];
    if (seen.has(parentId)) {
      break;
    }
    const parent = stateById.get(parentId);
    if (!parent) {
      break;
    }
    lineage.push(parent);
    seen.add(parent.id);
    cursor = parent;
  }

  return lineage;
}

const repoBaseUrl = deriveRepoBaseUrl();
const activeBranch = activeState.publish?.branch || '';
const stateNo = stateNumber(activeState.id);
const statusEnabled = stateNo >= 2;
const proxyMode = stateNo >= 2;
const baseOrigin = proxyMode ? '' : 'http://localhost';

const statusChecks = proxyMode
  ? [
      { id: 'edge-health', name: 'Edge/Ingress Health', url: '/health', expectedStatuses: [200] },
      { id: 'account-service', name: 'Account Service', url: '/account-service/account/22214', expectedStatuses: [200] },
      { id: 'reference-data', name: 'Reference Data', url: '/reference-data/stocks', expectedStatuses: [200] },
      { id: 'position-service', name: 'Position Service', url: '/position-service/health/alive', expectedStatuses: [200] },
      { id: 'trade-service', name: 'Trade Service', url: '/trade-service/v3/api-docs', expectedStatuses: [200] },
      { id: 'people-service', name: 'People Service', url: '/people-service/People/GetPerson?LogonId=user01', expectedStatuses: [200] },
      { id: 'trade-feed', name: 'Trade Feed', url: '/socket.io/?EIO=4&transport=polling', expectedStatuses: [200] },
    ]
  : [
      { id: 'account-service', name: 'Account Service', url: `${baseOrigin}:18088/account/22214`, expectedStatuses: [200] },
      { id: 'reference-data', name: 'Reference Data', url: `${baseOrigin}:18085/stocks`, expectedStatuses: [200] },
      { id: 'position-service', name: 'Position Service', url: `${baseOrigin}:18090/health/alive`, expectedStatuses: [200] },
      { id: 'trade-service', name: 'Trade Service', url: `${baseOrigin}:18092/v3/api-docs`, expectedStatuses: [200] },
      { id: 'people-service', name: 'People Service', url: `${baseOrigin}:18089/People/GetPerson?LogonId=user01`, expectedStatuses: [200] },
      { id: 'trade-feed', name: 'Trade Feed', url: `${baseOrigin}:18086/socket.io/?EIO=4&transport=polling`, expectedStatuses: [200] },
    ];

const previousStates = buildLineage(activeState).map((entry) => {
  const branch = entry.publish?.branch || '';
  return {
    id: entry.id,
    title: entry.title || entry.id,
    sourceBranch: branch,
    sourceBranchUrl: repoBaseUrl && branch ? `${repoBaseUrl}/tree/${branchUrlEncode(branch)}` : '',
    summary: `Introduces ${entry.title || entry.id} on the ${entry.track || 'unknown'} track.`,
  };
});

const metadata = {
  stateId: activeState.id,
  stateTitle: activeState.title || activeState.id,
  stateTrack: activeState.track || 'unknown',
  generatedAtUtc: new Date().toISOString(),
  sourceBranch: activeBranch,
  sourceBranchUrl: repoBaseUrl && activeBranch ? `${repoBaseUrl}/tree/${branchUrlEncode(activeBranch)}` : '',
  lineageLinkUrl: repoBaseUrl ? `${repoBaseUrl}/blob/main/docs/learning-paths/index.md` : '',
  apiExplorerUrl: '/api/docs',
  features: {
    statusPage: statusEnabled,
  },
  previousStates,
  statusChecks,
};

const candidatePaths = [
  path.join(componentsRoot, 'web-front-end-angular-specfirst', 'main', 'assets', 'state-ui.json'),
  path.join(targetRoot, 'web-front-end', 'angular', 'main', 'assets', 'state-ui.json'),
];

let writes = 0;
for (const candidate of candidatePaths) {
  const parentDir = path.dirname(candidate);
  if (!fs.existsSync(parentDir)) {
    continue;
  }
  fs.mkdirSync(parentDir, { recursive: true });
  fs.writeFileSync(candidate, `${JSON.stringify(metadata, null, 2)}\n`);
  writes += 1;
}

if (writes === 0) {
  console.warn('[warn] ui state metadata not installed (no Angular assets path found)');
} else {
  console.log(`[ok] installed ui state metadata for ${stateId} (${writes} target(s))`);
}
NODE

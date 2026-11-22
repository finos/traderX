#!/usr/bin/env bash
set -euo pipefail

BASE_FILE="${1:-}"
OVERLAY_FILE="${2:-}"
TRADERX_URL="${3:-http://localhost:8080}"

if [[ -z "${BASE_FILE}" || -z "${OVERLAY_FILE}" ]]; then
  echo "usage: merge-traderx-appd.sh <base-file> <overlay-file> [traderx-url]"
  exit 1
fi

node - "${BASE_FILE}" "${OVERLAY_FILE}" "${TRADERX_URL}" <<'NODE'
const fs = require("node:fs");

const [basePath, overlayPath, traderxUrl] = process.argv.slice(2);

const replaceTokens = (value) => {
  if (typeof value === "string") {
    return value.replaceAll("__TRADERX_URL__", traderxUrl);
  }
  if (Array.isArray(value)) {
    return value.map(replaceTokens);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, replaceTokens(v)]),
    );
  }
  return value;
};

const baseDoc = JSON.parse(fs.readFileSync(basePath, "utf8"));
const overlayDoc = replaceTokens(JSON.parse(fs.readFileSync(overlayPath, "utf8")));
const baseApps = Array.isArray(baseDoc.applications) ? baseDoc.applications : [];
const overlayApps = Array.isArray(overlayDoc.applications) ? overlayDoc.applications : [];

const mergedById = new Map();
for (const app of baseApps) {
  if (app && app.appId) mergedById.set(app.appId, app);
}
for (const app of overlayApps) {
  if (app && app.appId) mergedById.set(app.appId, app);
}

const mergedDoc = {
  ...baseDoc,
  applications: Array.from(mergedById.values()),
  message: baseDoc.message ?? "OK",
};

const next = `${JSON.stringify(mergedDoc, null, 2)}\n`;
const prev = fs.readFileSync(basePath, "utf8");
if (prev === next) {
  console.log(`[ok] TraderX AppD already current in ${basePath} (${mergedDoc.applications.length} apps)`);
  process.exit(0);
}
fs.writeFileSync(basePath, next, "utf8");
console.log(`[ok] merged TraderX AppD into ${basePath} (${mergedDoc.applications.length} apps)`);
NODE

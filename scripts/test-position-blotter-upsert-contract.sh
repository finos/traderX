#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${1:-generated/code/target-generated/web-front-end/angular}"
if [[ ! -d "${WEB_ROOT}" ]]; then
  ALT_WEB_ROOT="generated/code/components/web-front-end-angular-specfirst"
  if [[ -d "${ALT_WEB_ROOT}" ]]; then
    WEB_ROOT="${ALT_WEB_ROOT}"
  fi
fi
POSITION_BLOTTER_TS="${WEB_ROOT}/main/app/trade/position-blotter/position-blotter.component.ts"

if [[ ! -f "${POSITION_BLOTTER_TS}" ]]; then
  echo "[error] position blotter source not found: ${POSITION_BLOTTER_TS}"
  exit 1
fi

echo "[check] position blotter realtime upsert contract"
if ! grep -Eq "getRowNode\\(this\\.toRowId\\(security\\)\\)" "${POSITION_BLOTTER_TS}"; then
  echo "[error] expected in-place row lookup by position row-id key"
  exit 1
fi

if ! grep -Eq "return this\\.toRowId\\(params\\.data\\.security\\);" "${POSITION_BLOTTER_TS}"; then
  echo "[error] expected getRowId to use the same row-id key strategy"
  exit 1
fi

echo "[done] position blotter upsert contract check passed"

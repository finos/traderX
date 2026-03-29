#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:18093}"

echo "[check] angular UI root endpoint"
root_headers="$(curl -sS -i "${BASE_URL}/" | sed -n '1,25p')"
echo "${root_headers}"

if ! printf '%s\n' "${root_headers}" | head -n 1 | grep -Eq 'HTTP/1\.[01] 200'; then
  echo "[error] expected HTTP 200 from ${BASE_URL}/"
  exit 1
fi

root_body="$(curl -sS "${BASE_URL}/")"
if ! printf '%s\n' "${root_body}" | grep -qi "<app-root"; then
  echo "[error] expected Angular app shell (<app-root>) in root response"
  exit 1
fi

echo "[check] angular route fallback for /trade"
trade_headers="$(curl -sS -i "${BASE_URL}/trade" | sed -n '1,25p')"
echo "${trade_headers}"
if ! printf '%s\n' "${trade_headers}" | head -n 1 | grep -Eq 'HTTP/1\.[01] 200'; then
  echo "[error] expected HTTP 200 from ${BASE_URL}/trade"
  exit 1
fi

echo "[check] branding assets are served"
for asset in \
  "/assets/img/traderx-apple-touch-icon.png" \
  "/assets/img/traderx-icon.png" \
  "/assets/img/FINOS_Icon_White.png"; do
  asset_headers="$(curl -sS -i "${BASE_URL}${asset}" | sed -n '1,15p')"
  echo "${asset_headers}"
  if ! printf '%s\n' "${asset_headers}" | head -n 1 | grep -Eq 'HTTP/1\.[01] 200'; then
    echo "[error] expected HTTP 200 for branding asset ${asset}"
    exit 1
  fi
done

echo "[done] web-front-end-angular overlay smoke tests passed"

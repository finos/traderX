#!/usr/bin/env bash
set -euo pipefail

DB_TCP_PORT="${1:-18082}"
DB_PG_PORT="${2:-18083}"
DB_WEB_URL="${3:-http://localhost:18084/}"
ACCOUNT_URL="${4:-http://localhost:18088/account/22214}"

echo "[check] database tcp port ${DB_TCP_PORT}"
nc -z localhost "${DB_TCP_PORT}"

echo "[check] database pg port ${DB_PG_PORT}"
nc -z localhost "${DB_PG_PORT}"

echo "[check] database web console"
curl -sS -i "${DB_WEB_URL}" | sed -n '1,10p'

echo "[check] account-service can query baseline account data"
curl -sS -i "${ACCOUNT_URL}" | sed -n '1,20p'

echo "[done] database overlay smoke tests passed"

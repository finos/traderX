#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "[fail] unknown argument: $1"
      echo "[hint] supported: --dry-run"
      exit 1
      ;;
  esac
  shift
done

missing=0
check_cmd() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ok] ${cmd} is installed"
  else
    echo "[missing] ${cmd} is not installed"
    missing=1
  fi
}

echo "[info] validating EC2 host prerequisites for TraderX deploy bundle"
check_cmd git
check_cmd curl
check_cmd jq
check_cmd docker
check_cmd nginx

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    echo "[ok] docker compose plugin is available"
  else
    echo "[missing] docker compose plugin is not available"
    missing=1
  fi
fi

if command -v certbot >/dev/null 2>&1; then
  echo "[ok] certbot is installed"
else
  echo "[warn] certbot is not installed (required for automated TLS issuance)"
fi

if (( DRY_RUN == 1 )); then
  echo "[done] host setup check completed (dry-run mode)"
  exit 0
fi

if (( missing == 1 )); then
  echo "[fail] missing required host prerequisites; run host-setup-install.sh"
  exit 1
fi

echo "[done] host setup check passed"

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

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

run_cmd() {
  echo "[run] $*"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  "$@"
}

install_with_apt() {
  run_cmd ${SUDO} apt-get update
  run_cmd ${SUDO} apt-get install -y git curl jq nginx docker.io docker-compose-plugin certbot python3-certbot-nginx
}

install_with_dnf() {
  run_cmd ${SUDO} dnf install -y git curl jq nginx docker docker-compose-plugin certbot python3-certbot-nginx
}

install_with_yum() {
  run_cmd ${SUDO} yum install -y git curl jq nginx docker certbot
}

echo "[info] installing EC2 host prerequisites for TraderX deploy bundle"

if command -v apt-get >/dev/null 2>&1; then
  install_with_apt
elif command -v dnf >/dev/null 2>&1; then
  install_with_dnf
elif command -v yum >/dev/null 2>&1; then
  install_with_yum
else
  echo "[fail] unsupported package manager (expected apt-get, dnf, or yum)"
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  run_cmd ${SUDO} systemctl enable docker || true
  run_cmd ${SUDO} systemctl start docker || true
  run_cmd ${SUDO} systemctl enable nginx || true
  run_cmd ${SUDO} systemctl start nginx || true
fi

if (( DRY_RUN == 1 )); then
  echo "[done] host setup install dry-run complete"
  exit 0
fi

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/host-setup-check.sh"
echo "[done] host setup install complete"

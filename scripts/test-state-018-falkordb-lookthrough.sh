#!/usr/bin/env bash
set -euo pipefail
BASE="${1:-http://localhost:8080/exposure}"
body="$(curl --fail --silent --show-error "${BASE}/api/exposure?account=70000&target=Z0G")"
python3 -c 'import json,sys; r=json.load(sys.stdin); assert abs(r["totalFraction"]-.14)<1e-8; assert r["pathCount"]==2; print("[ok]",r["backend"],r["revision"],r["elapsedMs"])' <<<"${body}"
curl --fail --silent --show-error "${BASE}/health"

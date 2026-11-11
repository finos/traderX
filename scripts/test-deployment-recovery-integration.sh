#!/usr/bin/env bash
# Linux Docker integration: quiesce, back up, restore into a separate database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo '[fail] requires Linux Docker host mount access'; exit 1; }
project="traderx-recovery-test-$(date +%s)-$$"
volume="${project}_postgres_state_009_data"
restored_volume="${project}_restored"
source_container="${project}-database"
restored_container="${project}-restore"
audit="$(mktemp -d /tmp/traderx-recovery-test.XXXXXXXX)"
image="traderx-recovery-test/postgres:${project}"
cleanup() {
  docker rm -f "$source_container" "$restored_container" >/dev/null 2>&1 || true
  docker volume rm "$volume" "$restored_volume" >/dev/null 2>&1 || true
  docker image rm "$image" >/dev/null 2>&1 || true
  sudo -n rm -rf "$audit"
}
trap cleanup EXIT
cd "$ROOT"
docker build -t "$image" -f templates/runtime-image-rebuilds/postgres/Dockerfile templates/runtime-image-rebuilds/postgres
docker volume create --label traderx.test=recovery "$volume" >/dev/null
docker run -d --name "$source_container" --network none \
  --label "com.docker.compose.project=$project" --label com.docker.compose.service=database \
  -e POSTGRES_HOST_AUTH_METHOD=trust -v "$volume:/var/lib/postgresql/data" "$image" >/dev/null
ready() {
  for attempt in {1..60}; do
    if docker exec "$1" pg_isready -U postgres >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}
ready "$source_container"
docker exec "$source_container" psql -U postgres -v ON_ERROR_STOP=1 -c "CREATE TABLE recovery_probe (value text); INSERT INTO recovery_probe VALUES ('preserved');" >/dev/null
python3 - "$project" "$audit" <<'PY'
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('deploy',Path('pipeline/deploy-verified-snapshot.py'))
deploy=importlib.util.module_from_spec(spec);spec.loader.exec_module(deploy)
record={'state':'009-order-management-matcher','snapshot':'a'*40}
deploy.backup_state009_database(record,sys.argv[1],Path(sys.argv[2]))
assert record['database_backup']['method']=='quiesced-physical'
Path(sys.argv[2],'result.json').write_text(json.dumps(record))
PY
backup="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["database_backup"]["path"])' "$audit/result.json")"
docker volume create --label traderx.test=recovery "$restored_volume" >/dev/null
restore_mount="$(docker volume inspect --format '{{.Mountpoint}}' "$restored_volume")"
sudo -n tar -xzf "$backup" -C "$restore_mount"
docker run -d --name "$restored_container" --network none -v "$restored_volume:/var/lib/postgresql/data" "$image" >/dev/null
ready "$restored_container"
[[ "$(docker exec "$restored_container" psql -U postgres -Atc 'SELECT value FROM recovery_probe')" == preserved ]]
docker start "$source_container" >/dev/null
ready "$source_container"
[[ "$(docker exec "$source_container" psql -U postgres -Atc 'SELECT value FROM recovery_probe')" == preserved ]]
echo '[ok] scoped quiescence, physical backup, independent restore and original-data preservation passed'

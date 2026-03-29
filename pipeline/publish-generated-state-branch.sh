#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

usage() {
  cat <<'EOF'
usage: bash pipeline/publish-generated-state-branch.sh <state-id> [--branch <branch-name>] [--push]

Examples:
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --branch codex/generated-state-001-baseline-uncontainerized-parity
EOF
}

STATE_ID="${1:-}"
if [[ -z "${STATE_ID}" ]]; then
  usage
  exit 1
fi
shift || true

BRANCH_OVERRIDE=""
PUSH=0

while (( "$#" )); do
  case "$1" in
    --branch)
      BRANCH_OVERRIDE="${2:-}"
      if [[ -z "${BRANCH_OVERRIDE}" ]]; then
        echo "[fail] --branch requires a value"
        exit 1
      fi
      shift 2
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

if ! jq -e --arg id "${STATE_ID}" '.states[] | select(.id == $id)' "${CATALOG}" >/dev/null; then
  echo "[fail] state not found in catalog: ${STATE_ID}"
  exit 1
fi

FEATURE_PACK="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .featurePack' "${CATALOG}")"
STATE_STATUS="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .status' "${CATALOG}")"
GEN_MODE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .generation.mode' "${CATALOG}")"
STATE_TITLE="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .title' "${CATALOG}")"
DEFAULT_BRANCH="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .publish.branch' "${CATALOG}")"
TAG_HINT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .publish.tag' "${CATALOG}")"
GENERATION_ENTRYPOINT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | .generation.entrypoint' "${CATALOG}")"
GENERATION_RUNTIME="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.generation.runtime // "")' "${CATALOG}")"

BRANCH_NAME="${BRANCH_OVERRIDE:-${DEFAULT_BRANCH}}"
if [[ "${BRANCH_NAME}" != codex/* ]]; then
  echo "[fail] generated-state branch must use codex/* prefix: ${BRANCH_NAME}"
  exit 1
fi

if [[ ! -d "${ROOT}/${FEATURE_PACK}" ]]; then
  echo "[fail] feature pack path does not exist: ${FEATURE_PACK}"
  exit 1
fi

if [[ "${GEN_MODE}" != "implemented" ]]; then
  echo "[fail] state ${STATE_ID} is ${STATE_STATUS} with generation.mode=${GEN_MODE}."
  echo "[hint] implement state-aware generation first, then publish branch."
  exit 1
fi

if [[ -n "$(git -C "${ROOT}" status --porcelain)" ]]; then
  echo "[fail] working tree must be clean before publishing generated-state branch."
  echo "[hint] commit or stash current changes and retry."
  exit 1
fi

echo "[info] generating state ${STATE_ID} (${STATE_TITLE})"
case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    "${ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run
    ;;
  002-edge-proxy-uncontainerized)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    "${ROOT}/scripts/start-state-002-edge-proxy-generated.sh" --dry-run
    ;;
  003-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${ROOT}/generated/code/target-generated/containerized-compose/docker-compose.yml" ]] || {
      echo "[fail] missing generated compose file for state 003"
      exit 1
    }
    ;;
  *)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    RUNTIME_START_SCRIPT="${ROOT}/scripts/start-state-${STATE_ID}-generated.sh"
    if [[ -x "${RUNTIME_START_SCRIPT}" ]]; then
      "${RUNTIME_START_SCRIPT}" --dry-run || true
    else
      echo "[info] no state-specific start script found at ${RUNTIME_START_SCRIPT}; skipping runtime dry-run"
    fi
    ;;
esac

SNAPSHOT_ROOT="${ROOT}/generated/code/target-generated"
if [[ ! -d "${SNAPSHOT_ROOT}" ]]; then
  echo "[fail] missing generated target directory: ${SNAPSHOT_ROOT}"
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/traderx-generated-state.XXXXXX")"
WORKTREE_DIR="${TMP_DIR}/worktree"
SNAPSHOT_DIR="${TMP_DIR}/snapshot"
mkdir -p "${WORKTREE_DIR}" "${SNAPSHOT_DIR}"

cleanup() {
  git -C "${ROOT}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

cp -R "${SNAPSHOT_ROOT}/." "${SNAPSHOT_DIR}/"
rm -rf "${SNAPSHOT_DIR}/.run"

SOURCE_COMMIT="$(git -C "${ROOT}" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "${ROOT}" branch --show-current)"
GENERATED_AT_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

PREVIOUS_STATES_JSON="$(jq -c --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // [])' "${CATALOG}")"
NEXT_STATES_JSON="$(jq -c --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ]' "${CATALOG}")"
PREVIOUS_STATES_TEXT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | (.previous // []) | if length == 0 then "none" else join(", ") end' "${CATALOG}")"
NEXT_STATES_TEXT="$(jq -r --arg id "${STATE_ID}" '.states | [ .[] | select((.previous // []) | index($id)) | .id ] | if length == 0 then "none" else join(", ") end' "${CATALOG}")"

ORIGIN_URL="$(git -C "${ROOT}" remote get-url origin)"
REPO_WEB_BASE=""
case "${ORIGIN_URL}" in
  https://github.com/*)
    REPO_WEB_BASE="${ORIGIN_URL%.git}"
    ;;
  git@github.com:*)
    REPO_WEB_BASE="https://github.com/${ORIGIN_URL#git@github.com:}"
    REPO_WEB_BASE="${REPO_WEB_BASE%.git}"
    ;;
esac

state_summary_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- Base case for TraderX generated code.
- Runtime model: uncontainerized local processes in deterministic startup order.
- Browser directly calls multiple service ports (cross-origin CORS behavior is part of this state).
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat <<'EOF'
- Builds on state `001` while keeping uncontainerized process runtime.
- Adds `edge-proxy` as a single browser-facing origin for UI + API + WebSocket traffic.
- Preserves baseline functional behavior with topology-focused NFR deltas.
EOF
      ;;
    003-containerized-compose-runtime)
      cat <<'EOF'
- Builds on state `002` by moving runtime to Docker Compose.
- Uses NGINX ingress (`ingress` service) as the browser/API/WebSocket entrypoint.
- Preserves baseline functional behavior while changing runtime/ops model.
EOF
      ;;
    *)
      cat <<'EOF'
- Generated code snapshot for TraderX state transition.
EOF
      ;;
  esac
}

runtime_guidance_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-base-uncontainerized-generated.sh
```

UI endpoint: `http://localhost:18093`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

Browser endpoint (via edge proxy): `http://localhost:18080`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```
EOF
      ;;
    003-containerized-compose-runtime)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-003-containerized-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`

Stop:

```bash
./scripts/stop-state-003-containerized-generated.sh
```
EOF
      ;;
    *)
      cat <<'EOF'
See `RUN_FROM_CLONE.md` for clone-first runtime instructions.
EOF
      ;;
  esac
}

require_snapshot_component_dir() {
  local component_rel="$1"
  if [[ ! -d "${SNAPSHOT_DIR}/${component_rel}" ]]; then
    echo "[fail] expected component directory missing in snapshot: ${component_rel}"
    exit 1
  fi
}

link_snapshot_component() {
  local component_name="$1"
  local component_rel="$2"
  require_snapshot_component_dir "${component_rel}"
  ln -sfn "../../../${component_rel}" "${SNAPSHOT_DIR}/generated/code/components/${component_name}-specfirst"
}

install_uncontainerized_clone_harness() {
  mkdir -p \
    "${SNAPSHOT_DIR}/scripts" \
    "${SNAPSHOT_DIR}/catalog" \
    "${SNAPSHOT_DIR}/generated/code/components" \
    "${SNAPSHOT_DIR}/generated/code/target-generated"

  cp "${ROOT}/scripts/start-base-uncontainerized-generated.sh" "${SNAPSHOT_DIR}/scripts/"
  cp "${ROOT}/scripts/stop-base-uncontainerized-generated.sh" "${SNAPSHOT_DIR}/scripts/"
  cp "${ROOT}/scripts/status-base-uncontainerized-generated.sh" "${SNAPSHOT_DIR}/scripts/"
  cp "${ROOT}/catalog/base-uncontainerized-processes.csv" "${SNAPSHOT_DIR}/catalog/"

  link_snapshot_component "reference-data" "reference-data"
  link_snapshot_component "database" "database"
  link_snapshot_component "people-service" "people-service"
  link_snapshot_component "account-service" "account-service"
  link_snapshot_component "position-service" "position-service"
  link_snapshot_component "trade-feed" "trade-feed"
  link_snapshot_component "trade-processor" "trade-processor"
  link_snapshot_component "trade-service" "trade-service"
  link_snapshot_component "web-front-end-angular" "web-front-end/angular"

  if [[ "${STATE_ID}" == "002-edge-proxy-uncontainerized" ]]; then
    cp "${ROOT}/scripts/start-state-002-edge-proxy-generated.sh" "${SNAPSHOT_DIR}/scripts/"
    cp "${ROOT}/scripts/stop-state-002-edge-proxy-generated.sh" "${SNAPSHOT_DIR}/scripts/"
    cp "${ROOT}/scripts/status-state-002-edge-proxy-generated.sh" "${SNAPSHOT_DIR}/scripts/"
    link_snapshot_component "edge-proxy" "edge-proxy"
  fi
}

install_containerized_clone_harness() {
  mkdir -p "${SNAPSHOT_DIR}/scripts"

  cat > "${SNAPSHOT_DIR}/scripts/start-state-003-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-003}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build
echo "[done] state 003 containerized compose runtime started"
echo "[ui] http://localhost:8080"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/stop-state-003-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-003}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" down --remove-orphans
echo "[done] state 003 containerized compose runtime stopped"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/status-state-003-containerized-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-003}"
COMPOSE_FILE="${ROOT}/containerized-compose/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
EOF

  chmod +x \
    "${SNAPSHOT_DIR}/scripts/start-state-003-containerized-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/stop-state-003-containerized-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/status-state-003-containerized-generated.sh"
}

write_clone_runbook() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

Endpoints:
- UI: `http://localhost:18093`
- Reference data: `http://localhost:18085/stocks`
- Trade service swagger: `http://localhost:18092/swagger-ui.html`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Java 21+
- Node.js + npm
- .NET runtime 9.x (`Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`)
- `nc`, `curl`, `lsof`
- Outbound network access for Gradle/Maven/npm downloads

Start:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-002-edge-proxy-generated.sh
```

Endpoints:
- Browser entrypoint (edge proxy): `http://localhost:18080`
- Angular direct dev server: `http://localhost:18093`
- Edge proxy health: `http://localhost:18080/health`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```
EOF
      ;;
    003-containerized-compose-runtime)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-003-containerized-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`

Status / stop:

```bash
./scripts/status-state-003-containerized-generated.sh
./scripts/stop-state-003-containerized-generated.sh
```
EOF
      ;;
    *)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

No state-specific clone runtime instructions were generated for this snapshot.
EOF
      ;;
  esac
}

mkdir -p "${SNAPSHOT_DIR}/.traderx-state"
cat > "${SNAPSHOT_DIR}/.traderx-state/state.json" <<EOF
{
  "stateId": "${STATE_ID}",
  "stateTitle": "${STATE_TITLE}",
  "stateStatus": "${STATE_STATUS}",
  "featurePack": "${FEATURE_PACK}",
  "previousStates": ${PREVIOUS_STATES_JSON},
  "nextStates": ${NEXT_STATES_JSON},
  "sourceBranch": "${SOURCE_BRANCH}",
  "sourceCommit": "${SOURCE_COMMIT}",
  "generatedAtUtc": "${GENERATED_AT_UTC}",
  "generationEntryPoint": "${GENERATION_ENTRYPOINT}",
  "publishTagHint": "${TAG_HINT}"
}
EOF

cat > "${SNAPSHOT_DIR}/STATE.md" <<EOF
# TraderX Generated State Snapshot

- State ID: \`${STATE_ID}\`
- Title: \`${STATE_TITLE}\`
- Status: \`${STATE_STATUS}\`
- Feature Pack: \`${FEATURE_PACK}\`
- Previous States: \`${PREVIOUS_STATES_JSON}\`
- Next States: \`${NEXT_STATES_JSON}\`
- Source Branch: \`${SOURCE_BRANCH}\`
- Source Commit: \`${SOURCE_COMMIT}\`
- Generated At (UTC): \`${GENERATED_AT_UTC}\`
- Suggested Tag: \`${TAG_HINT}\`

Machine-readable metadata: \`.traderx-state/state.json\`
EOF

cat > "${SNAPSHOT_DIR}/README.md" <<EOF
# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: \`${STATE_ID}\`
- State Title: \`${STATE_TITLE}\`
- Status: \`${STATE_STATUS}\`
- Suggested Version Tag: \`${TAG_HINT}\`
- Source Branch: \`${SOURCE_BRANCH}\`
- Source Commit: \`${SOURCE_COMMIT}\`
- Generated At (UTC): \`${GENERATED_AT_UTC}\`

## State Summary

$(state_summary_markdown)

## State Lineage

- Previous states: \`${PREVIOUS_STATES_TEXT}\`
- Next states: \`${NEXT_STATES_TEXT}\`

## Runtime Guidance

$(runtime_guidance_markdown)

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: \`${FEATURE_PACK}\`
- Generation entrypoint: \`${GENERATION_ENTRYPOINT}\`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
EOF

if [[ -n "${REPO_WEB_BASE}" ]]; then
  cat >> "${SNAPSHOT_DIR}/README.md" <<EOF
- Source commit: ${REPO_WEB_BASE}/commit/${SOURCE_COMMIT}
- Feature pack at source commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- SpecKit docs at source commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/docs/spec-kit
EOF
fi

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity|002-edge-proxy-uncontainerized)
    install_uncontainerized_clone_harness
    ;;
  003-containerized-compose-runtime)
    install_containerized_clone_harness
    ;;
esac

write_clone_runbook

if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  git -C "${ROOT}" worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}" >/dev/null
else
  git -C "${ROOT}" worktree add --detach "${WORKTREE_DIR}" HEAD >/dev/null
  git -C "${WORKTREE_DIR}" checkout --orphan "${BRANCH_NAME}" >/dev/null
fi

git -C "${WORKTREE_DIR}" rm -rf . >/dev/null 2>&1 || true
git -C "${WORKTREE_DIR}" clean -fdx >/dev/null 2>&1 || true
cp -R "${SNAPSHOT_DIR}/." "${WORKTREE_DIR}/"
git -C "${WORKTREE_DIR}" add -A

if git -C "${WORKTREE_DIR}" diff --cached --quiet; then
  echo "[info] no changes to commit on ${BRANCH_NAME}"
else
  git -C "${WORKTREE_DIR}" commit -m "snapshot: ${STATE_ID} generated from ${SOURCE_COMMIT}" >/dev/null
  echo "[ok] committed generated snapshot on branch ${BRANCH_NAME}"
fi

if (( PUSH == 1 )); then
  git -C "${WORKTREE_DIR}" push --force-with-lease origin "${BRANCH_NAME}"
  echo "[ok] pushed ${BRANCH_NAME}"
fi

echo "[done] generated-state branch ready: ${BRANCH_NAME}"

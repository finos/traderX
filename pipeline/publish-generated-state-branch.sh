#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"
GENERATED_ROOT_BRANCH="${GENERATED_ROOT_BRANCH:-code/generated-state-root}"

usage() {
  cat <<'EOF'
usage: bash pipeline/publish-generated-state-branch.sh <state-id> [--branch <branch-name>] [--push]

Examples:
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
  bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --branch code/generated-state-001-baseline-uncontainerized-parity
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

PREVIOUS_STATE_COUNT="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | ((.previous // []) | length)' "${CATALOG}")"
if [[ "${PREVIOUS_STATE_COUNT}" -gt 1 ]]; then
  echo "[fail] state ${STATE_ID} has multiple previous states; publisher currently supports one parent branch"
  echo "[hint] add merge-aware publish behavior before enabling multi-parent state lineage"
  exit 1
fi

PRIMARY_PREVIOUS_STATE_ID="$(jq -r --arg id "${STATE_ID}" '.states[] | select(.id == $id) | ((.previous // [])[0] // "")' "${CATALOG}")"
PRIMARY_PREVIOUS_BRANCH=""
if [[ -n "${PRIMARY_PREVIOUS_STATE_ID}" ]]; then
  PRIMARY_PREVIOUS_BRANCH="$(jq -r --arg id "${PRIMARY_PREVIOUS_STATE_ID}" '.states[] | select(.id == $id) | (.publish.branch // "")' "${CATALOG}")"
  if [[ -z "${PRIMARY_PREVIOUS_BRANCH}" ]]; then
    echo "[fail] previous state ${PRIMARY_PREVIOUS_STATE_ID} does not define publish.branch"
    exit 1
  fi
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
if [[ "${BRANCH_NAME}" != code/generated-state-* ]]; then
  echo "[fail] generated-state branch must use code/generated-state-* prefix: ${BRANCH_NAME}"
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
  004-kubernetes-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${ROOT}/generated/code/target-generated/kubernetes-runtime/build-plan.json" ]] || {
      echo "[fail] missing generated kubernetes build-plan for state 004"
      exit 1
    }
    "${ROOT}/scripts/start-state-004-kubernetes-generated.sh" --dry-run
    ;;
  005-radius-kubernetes-platform)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${ROOT}/generated/code/target-generated/radius-kubernetes-platform/radius/app.bicep" ]] || {
      echo "[fail] missing generated radius app model for state 005"
      exit 1
    }
    ;;
  006-tilt-kubernetes-dev-loop)
    bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
    [[ -f "${ROOT}/generated/code/target-generated/tilt-kubernetes-dev-loop/tilt/Tiltfile" ]] || {
      echo "[fail] missing generated tilt assets for state 006"
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

ensure_local_branch_ref() {
  local branch="$1"
  if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
    return 0
  fi

  if git -C "${ROOT}" ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
    git -C "${ROOT}" fetch origin "${branch}:${branch}" >/dev/null
    return 0
  fi

  return 1
}

ensure_generated_root_branch() {
  local root_branch="$1"
  if ensure_local_branch_ref "${root_branch}"; then
    return 0
  fi

  local root_worktree="${TMP_DIR}/root-worktree"
  git -C "${ROOT}" worktree add --detach "${root_worktree}" HEAD >/dev/null
  git -C "${root_worktree}" checkout --orphan "${root_branch}" >/dev/null
  git -C "${root_worktree}" rm -rf . >/dev/null 2>&1 || true
  git -C "${root_worktree}" clean -fdx >/dev/null 2>&1 || true
  git -C "${root_worktree}" commit --allow-empty -m "root: generated-state ancestry anchor" >/dev/null
  git -C "${ROOT}" branch -f "${root_branch}" "$(git -C "${root_worktree}" rev-parse HEAD)" >/dev/null
  git -C "${ROOT}" worktree remove --force "${root_worktree}" >/dev/null 2>&1 || true
  echo "[ok] created generated root branch ${root_branch}"
}

ensure_generated_root_branch "${GENERATED_ROOT_BRANCH}"

BASE_BRANCH="${GENERATED_ROOT_BRANCH}"
if [[ -n "${PRIMARY_PREVIOUS_BRANCH}" ]]; then
  BASE_BRANCH="${PRIMARY_PREVIOUS_BRANCH}"
fi

if ! ensure_local_branch_ref "${BASE_BRANCH}"; then
  echo "[fail] base branch ${BASE_BRANCH} not found locally or on origin"
  if [[ -n "${PRIMARY_PREVIOUS_STATE_ID}" ]]; then
    echo "[hint] publish parent state first: ${PRIMARY_PREVIOUS_STATE_ID}"
  fi
  exit 1
fi

cp -R "${SNAPSHOT_ROOT}/." "${SNAPSHOT_DIR}/"
rm -rf "${SNAPSHOT_DIR}/.run"

CORE_COMPONENT_DIRS=(
  "account-service"
  "database"
  "people-service"
  "position-service"
  "reference-data"
  "trade-feed"
  "trade-processor"
  "trade-service"
  "web-front-end"
)

snapshot_keep_paths_for_state() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}"
      ;;
    002-edge-proxy-uncontainerized)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "edge-proxy"
      ;;
    003-containerized-compose-runtime)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "containerized-compose" "ingress"
      ;;
    004-kubernetes-runtime)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "kubernetes-runtime"
      ;;
    005-radius-kubernetes-platform)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "kubernetes-runtime" "radius-kubernetes-platform"
      ;;
    006-tilt-kubernetes-dev-loop)
      printf '%s\n' "${CORE_COMPONENT_DIRS[@]}" "kubernetes-runtime" "tilt-kubernetes-dev-loop"
      ;;
    *)
      find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -exec basename {} \;
      ;;
  esac
}

path_in_keep_list() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "${needle}" == "${item}" ]]; then
      return 0
    fi
  done
  return 1
}

prune_snapshot_for_state() {
  local keep_paths=()
  local keep_path
  while IFS= read -r keep_path; do
    [[ -n "${keep_path}" ]] || continue
    keep_paths+=("${keep_path}")
  done < <(snapshot_keep_paths_for_state | sed '/^$/d' | sort -u)

  if [[ "${#keep_paths[@]}" -eq 0 ]]; then
    echo "[fail] no keep-paths resolved for state ${STATE_ID}"
    exit 1
  fi

  local required
  for required in "${keep_paths[@]}"; do
    if [[ ! -e "${SNAPSHOT_DIR}/${required}" ]]; then
      echo "[fail] expected state artifact missing after generation: ${required}"
      exit 1
    fi
  done

  local entry base
  while IFS= read -r entry; do
    base="$(basename "${entry}")"
    if ! path_in_keep_list "${base}" "${keep_paths[@]}"; then
      rm -rf "${entry}"
    fi
  done < <(find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -print)
}

prune_snapshot_for_state

remove_snapshot_transient_artifacts() {
  local transient_dirs=(
    "node_modules"
    ".angular"
    ".gradle"
    ".npm"
    ".pnpm-store"
    ".cache"
    ".run"
    "coverage"
    "dist"
    "build"
    "bin"
    "obj"
  )

  local name dirpath
  for name in "${transient_dirs[@]}"; do
    while IFS= read -r dirpath; do
      rm -rf "${dirpath}"
    done < <(find "${SNAPSHOT_DIR}" -type d -name "${name}" -print)
  done

  find "${SNAPSHOT_DIR}" -type f \( -name "*.log" -o -name ".DS_Store" \) -delete
}

assert_snapshot_size_guardrails() {
  local oversized
  oversized="$(find "${SNAPSHOT_DIR}" -type f -size +95M -print | sed '/^$/d')"
  if [[ -n "${oversized}" ]]; then
    echo "[fail] oversized files found in snapshot (must be <=95MB):"
    printf '%s\n' "${oversized}"
    echo "[hint] ensure transient caches/build outputs are excluded from generated snapshot branches."
    exit 1
  fi
}

remove_snapshot_transient_artifacts
assert_snapshot_size_guardrails

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
    004-kubernetes-runtime)
      cat <<'EOF'
- Builds on state `003` by moving runtime from Docker Compose to Kubernetes (Kind baseline).
- Uses in-cluster NGINX edge-proxy as browser/API/WebSocket entrypoint at `http://localhost:8080`.
- Preserves baseline functional behavior while changing runtime orchestration and deployment model.
EOF
      ;;
    005-radius-kubernetes-platform)
      cat <<'EOF'
- Builds on state `004` and preserves Kubernetes runtime behavior.
- Adds Radius application/resource model artifacts as platform abstraction overlays.
- Preserves baseline functional behavior and API contracts.
EOF
      ;;
    006-tilt-kubernetes-dev-loop)
      cat <<'EOF'
- Builds on state `004` and preserves Kubernetes runtime behavior.
- Adds Tilt local developer-loop artifacts (`Tiltfile`, Tilt settings, workflow docs).
- Preserves baseline functional behavior and API contracts.
EOF
      ;;
    007-messaging-nats-replacement)
      cat <<'EOF'
- Builds on state `003` and preserves containerized ingress runtime behavior.
- Replaces Socket.IO trade-feed with NATS broker for backend and browser streaming.
- Preserves baseline user-visible behavior while changing messaging transport.
EOF
      ;;
    009-postgres-database-replacement)
      cat <<'EOF'
- Builds on state `003` and preserves containerized ingress runtime behavior.
- Replaces H2 runtime database with PostgreSQL container + deterministic init SQL.
- Preserves baseline REST/event contracts and user-visible behavior.
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
    004-kubernetes-runtime)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-004-kubernetes-generated.sh
```

UI/edge endpoint: `http://localhost:8080`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh
./scripts/stop-state-004-kubernetes-generated.sh
```
EOF
      ;;
    005-radius-kubernetes-platform)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-004-kubernetes-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`

Radius artifact pack:

- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh --provider kind
./scripts/stop-state-004-kubernetes-generated.sh --provider kind
```
EOF
      ;;
    006-tilt-kubernetes-dev-loop)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-004-kubernetes-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`
Tilt UI: `http://localhost:10350`

Tilt artifact pack:

- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh --provider kind
./scripts/stop-state-004-kubernetes-generated.sh --provider kind
```
EOF
      ;;
    007-messaging-nats-replacement)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-007-messaging-nats-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-007-messaging-nats-replacement-generated.sh
./scripts/stop-state-007-messaging-nats-replacement-generated.sh
```
EOF
      ;;
    009-postgres-database-replacement)
      cat <<'EOF'
Run directly from this generated snapshot branch:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
PostgreSQL endpoint: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-009-postgres-database-replacement-generated.sh
./scripts/stop-state-009-postgres-database-replacement-generated.sh
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

learning_focus_markdown() {
  case "${STATE_ID}" in
    001-baseline-uncontainerized-parity)
      cat <<'EOF'
- Understand baseline service boundaries and call patterns.
- Understand startup sequencing and fixed port coupling.
- Understand why CORS is an explicit NFR in this state.
EOF
      ;;
    002-edge-proxy-uncontainerized)
      cat <<'EOF'
- Understand browser traffic consolidation through the edge proxy.
- Understand how path routing and websocket proxying preserve baseline behavior.
- Compare cross-origin behavior vs state 001.
EOF
      ;;
    003-containerized-compose-runtime)
      cat <<'EOF'
- Understand runtime transition from host processes to containers.
- Understand NGINX ingress behavior under Compose.
- Trace container wiring back to unchanged functional requirements.
EOF
      ;;
    004-kubernetes-runtime)
      cat <<'EOF'
- Understand Kubernetes deployment/service decomposition.
- Understand image build plan and runtime orchestration scripts.
- Compare local Kind/Minikube execution model to state 003.
EOF
      ;;
    005-radius-kubernetes-platform)
      cat <<'EOF'
- Understand Radius artifacts as a platform-model overlay on Kubernetes.
- Understand what remains baseline runtime vs what is platform abstraction.
- Evaluate portability goals and platform-level NFR impact.
EOF
      ;;
    006-tilt-kubernetes-dev-loop)
      cat <<'EOF'
- Understand developer-loop acceleration using Tilt.
- Understand what parts are runtime-stable vs dev-loop specific.
- Evaluate inner-loop productivity deltas while preserving contracts.
EOF
      ;;
    007-messaging-nats-replacement)
      cat <<'EOF'
- Understand focused messaging-layer replacement on top of stable runtime.
- Compare NATS subject topology to prior Socket.IO channel patterns.
- Validate realtime behavior parity while changing transport internals.
EOF
      ;;
    009-postgres-database-replacement)
      cat <<'EOF'
- Understand focused database-engine replacement on top of stable runtime.
- Compare datasource and schema-init changes required for PostgreSQL migration.
- Validate flow compatibility after persistence-layer substitution.
EOF
      ;;
    *)
      cat <<'EOF'
- Review state metadata and runtime instructions.
- Trace state intent back to canonical SpecKit artifacts.
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

install_state_compose_clone_harness() {
  local state_id="$1"
  mkdir -p "${SNAPSHOT_DIR}/scripts"

  local script_name
  for script_name in \
    "start-state-${state_id}-generated.sh" \
    "stop-state-${state_id}-generated.sh" \
    "status-state-${state_id}-generated.sh" \
    "test-state-${state_id}.sh"; do
    if [[ -f "${ROOT}/scripts/${script_name}" ]]; then
      cp "${ROOT}/scripts/${script_name}" "${SNAPSHOT_DIR}/scripts/"
    fi
  done
}

install_kubernetes_clone_harness() {
  mkdir -p "${SNAPSHOT_DIR}/scripts"

  cat > "${SNAPSHOT_DIR}/scripts/start-state-004-kubernetes-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT}/kubernetes-runtime"
BUILD_PLAN="${STATE_DIR}/build-plan.json"
KUSTOMIZE_DIR="${STATE_DIR}/manifests/base"
KIND_CONFIG="${STATE_DIR}/kind/cluster-config.yaml"
RUN_DIR="${STATE_DIR}/.run/state-004-kubernetes"

SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"

while (( "$#" )); do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    --minikube-driver)
      MINIKUBE_DRIVER="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --skip-build --recreate-cluster --provider <kind|minikube> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in docker kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }
[[ -f "${KIND_CONFIG}" ]] || { echo "[error] missing ${KIND_CONFIG}"; exit 1; }
[[ -d "${KUSTOMIZE_DIR}" ]] || { echo "[error] missing ${KUSTOMIZE_DIR}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
edge_service="$(jq -r '.edgeService' "${BUILD_PLAN}")"

if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind|minikube)
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

mkdir -p "${RUN_DIR}"
PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
PORT_FORWARD_LOG_FILE="${RUN_DIR}/minikube-port-forward.log"

stop_minikube_port_forward() {
  if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
    pid="$(cat "${PORT_FORWARD_PID_FILE}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${PORT_FORWARD_PID_FILE}"
  fi
}

if [[ "${K8S_PROVIDER}" == "kind" ]]; then
  if ! command -v kind >/dev/null 2>&1; then
    echo "[error] required command not found: kind"
    exit 1
  fi
  cluster_exists=0
  if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
    cluster_exists=1
  fi
  if (( cluster_exists == 1 && RECREATE_CLUSTER == 1 )); then
    kind delete cluster --name "${cluster_name}"
    cluster_exists=0
  fi
  if (( cluster_exists == 0 )); then
    kind create cluster --name "${cluster_name}" --config "${KIND_CONFIG}"
  fi
  kubectl config use-context "kind-${cluster_name}" >/dev/null
else
  if ! command -v minikube >/dev/null 2>&1; then
    echo "[error] required command not found: minikube"
    exit 1
  fi
  if (( RECREATE_CLUSTER == 1 )); then
    minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
  fi
  minikube start -p "${MINIKUBE_PROFILE}" --driver "${MINIKUBE_DRIVER}" >/dev/null
  if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
    kubectl config use-context "minikube" >/dev/null
  fi
fi

if (( SKIP_BUILD == 0 )); then
  while IFS= read -r item; do
    name="$(jq -r '.name' <<<"${item}")"
    image="$(jq -r '.image' <<<"${item}")"
    context_rel="$(jq -r '.context' <<<"${item}")"
    dockerfile_rel="$(jq -r '.dockerfile' <<<"${item}")"
    context_abs="${ROOT}/${context_rel}"
    dockerfile_abs="${context_abs}/${dockerfile_rel}"

    [[ -d "${context_abs}" ]] || { echo "[error] missing build context ${context_abs}"; exit 1; }
    [[ -f "${dockerfile_abs}" ]] || { echo "[error] missing dockerfile ${dockerfile_abs}"; exit 1; }

    echo "[build] ${name} -> ${image}"
    docker build -t "${image}" -f "${dockerfile_abs}" "${context_abs}"
    if [[ "${K8S_PROVIDER}" == "kind" ]]; then
      kind load docker-image "${image}" --name "${cluster_name}"
    else
      minikube image load "${image}" -p "${MINIKUBE_PROFILE}" >/dev/null
    fi
  done < <(jq -c '.images[]' "${BUILD_PLAN}")
fi

kubectl apply -k "${KUSTOMIZE_DIR}"
kubectl wait --for=condition=Available deployment --all -n "${namespace}" --timeout=600s

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  stop_minikube_port_forward
  nohup kubectl -n "${namespace}" port-forward "svc/${edge_service}" "${host_port}:8080" >"${PORT_FORWARD_LOG_FILE}" 2>&1 &
  echo "$!" > "${PORT_FORWARD_PID_FILE}"
fi

echo "[done] state 004 kubernetes runtime started"
echo "[provider] ${K8S_PROVIDER}"
echo "[ui] http://localhost:${host_port}"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/stop-state-004-kubernetes-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${ROOT}/kubernetes-runtime/build-plan.json"
RUN_DIR="${ROOT}/kubernetes-runtime/.run/state-004-kubernetes"
DELETE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --delete-cluster --provider <kind|minikube> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

PORT_FORWARD_PID_FILE="${RUN_DIR}/minikube-port-forward.pid"
if [[ -f "${PORT_FORWARD_PID_FILE}" ]]; then
  pid="$(cat "${PORT_FORWARD_PID_FILE}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${PORT_FORWARD_PID_FILE}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] required command not found: kind"
      exit 1
    fi
    if kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1 || true
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    fi
    if (( DELETE_CLUSTER == 1 )); then
      kind delete cluster --name "${cluster_name}"
    fi
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] required command not found: minikube"
      exit 1
    fi
    if minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
        kubectl config use-context "minikube" >/dev/null 2>&1 || true
      fi
      kubectl delete namespace "${namespace}" --ignore-not-found=true >/dev/null 2>&1 || true
    fi
    if (( DELETE_CLUSTER == 1 )); then
      minikube delete -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[done] state 004 stop sequence complete"
EOF

  cat > "${SNAPSHOT_DIR}/scripts/status-state-004-kubernetes-generated.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_PLAN="${ROOT}/kubernetes-runtime/build-plan.json"
RUN_DIR="${ROOT}/kubernetes-runtime/.run/state-004-kubernetes"
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --provider <kind|minikube> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

for cmd in kubectl jq curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[error] required command not found: ${cmd}"
    exit 1
  fi
done

[[ -f "${BUILD_PLAN}" ]] || { echo "[error] missing ${BUILD_PLAN}"; exit 1; }

cluster_name="$(jq -r '.kindClusterName' "${BUILD_PLAN}")"
namespace="$(jq -r '.namespace' "${BUILD_PLAN}")"
host_port="$(jq -r '.hostPort' "${BUILD_PLAN}")"
if [[ -z "${MINIKUBE_PROFILE}" ]]; then
  MINIKUBE_PROFILE="${cluster_name}"
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] required command not found: kind"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${cluster_name}" >/dev/null 2>&1; then
      echo "[info] kind cluster not found: ${cluster_name}"
      exit 0
    fi
    kubectl config use-context "kind-${cluster_name}" >/dev/null
    echo "[info] provider: kind"
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] required command not found: minikube"
      exit 1
    fi
    if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[info] minikube profile not running: ${MINIKUBE_PROFILE}"
      exit 0
    fi
    if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      kubectl config use-context "minikube" >/dev/null
    fi
    echo "[info] provider: minikube"
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[info] cluster/profile: ${cluster_name}"
kubectl get deployments -n "${namespace}" || true
kubectl get pods -n "${namespace}" || true
kubectl get services -n "${namespace}" || true

echo "[status] edge-health $(curl -sS -o /dev/null -w "%{http_code}" "http://localhost:${host_port}/health" 2>/dev/null || true)"

if [[ "${K8S_PROVIDER}" == "minikube" ]]; then
  pid="-"
  running="no"
  pid_file="${RUN_DIR}/minikube-port-forward.pid"
  if [[ -f "${pid_file}" ]]; then
    pid="$(cat "${pid_file}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      running="yes"
    fi
  fi
  echo "[status] minikube-port-forward pid=${pid} running=${running}"
fi
EOF

  chmod +x \
    "${SNAPSHOT_DIR}/scripts/start-state-004-kubernetes-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/stop-state-004-kubernetes-generated.sh" \
    "${SNAPSHOT_DIR}/scripts/status-state-004-kubernetes-generated.sh"
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
    004-kubernetes-runtime)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start:

```bash
./scripts/start-state-004-kubernetes-generated.sh
# optional:
# ./scripts/start-state-004-kubernetes-generated.sh --provider minikube --minikube-profile traderx-state-004
```

Endpoints:
- UI / edge: `http://localhost:8080`
- Edge health: `http://localhost:8080/health`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh
./scripts/stop-state-004-kubernetes-generated.sh
```
EOF
      ;;
    005-radius-kubernetes-platform)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start baseline runtime (inherited from state 004):

```bash
./scripts/start-state-004-kubernetes-generated.sh
```

State 005 artifact pack:
- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`
- `radius-kubernetes-platform/radius/.rad/rad.yaml`

Optional Radius flow:

```bash
cd radius-kubernetes-platform/radius
rad run app.bicep
```
EOF
      ;;
    006-tilt-kubernetes-dev-loop)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start baseline runtime (inherited from state 004):

```bash
./scripts/start-state-004-kubernetes-generated.sh
```

State 006 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Optional Tilt flow:

```bash
cd tilt-kubernetes-dev-loop/tilt
tilt up
```
EOF
      ;;
    007-messaging-nats-replacement)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-007-messaging-nats-replacement-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-007-messaging-nats-replacement-generated.sh
./scripts/stop-state-007-messaging-nats-replacement-generated.sh
```
EOF
      ;;
    009-postgres-database-replacement)
      cat > "${SNAPSHOT_DIR}/RUN_FROM_CLONE.md" <<'EOF'
# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`
- PostgreSQL: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-009-postgres-database-replacement-generated.sh
./scripts/stop-state-009-postgres-database-replacement-generated.sh
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

write_snapshot_learning_docs() {
  local feature_pack_dir="${ROOT}/${FEATURE_PACK}"
  local system_dir="${feature_pack_dir}/system"
  local model_path="${system_dir}/architecture.model.json"
  local architecture_md_path="${system_dir}/architecture.md"
  local runtime_topology_path="${system_dir}/runtime-topology.md"
  local flows_path="${system_dir}/end-to-end-flows.md"
  local system_design_source=""
  local docs_root="${SNAPSHOT_DIR}/docs"
  local learning_root="${docs_root}/learning"
  local doc_source_links=""

  if [[ ! -f "${model_path}" ]]; then
    echo "[fail] missing architecture model for snapshot docs: ${model_path}"
    exit 1
  fi

  if [[ -f "${runtime_topology_path}" ]]; then
    system_design_source="${runtime_topology_path}"
  elif [[ -f "${flows_path}" ]]; then
    system_design_source="${flows_path}"
  fi

  mkdir -p "${learning_root}"

  cat > "${docs_root}/README.md" <<EOF
# Generated Docs

This folder provides generated learning-oriented documentation for state \`${STATE_ID}\`.

- [Learning Index](./learning/README.md)
- [Component List](./learning/component-list.md)
- [System Design](./learning/system-design.md)
- [Software Architecture](./learning/software-architecture.md)
- [Component Diagram](./learning/component-diagram.md)
EOF

  cat > "${learning_root}/component-list.md" <<EOF
# Component List

State: \`${STATE_ID}\`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
$(jq -r '.nodes[] | "| `\(.id)` | \(.label) | \(.kind // "component") | \((.description // "n/a") | gsub("\\|"; "\\\\|")) |"' "${model_path}")
EOF

  cat > "${learning_root}/component-diagram.md" <<EOF
# Component Diagram

State: \`${STATE_ID}\`

\`\`\`mermaid
flowchart $(jq -r '.mermaidDirection // "LR"' "${model_path}")
$(jq -r '
  def sid: gsub("[^A-Za-z0-9_]"; "_");
  .nodes[] | "  \(.id | sid)[\"" + (.label | gsub("\""; "\\\"")) + "\"]"
' "${model_path}")

$(jq -r '
  def sid: gsub("[^A-Za-z0-9_]"; "_");
  .edges[] |
  if ((.label // "") | length) > 0 then
    "  \(.from | sid) -->|"+(.label | gsub("\""; "\\\""))+"| \(.to | sid)"
  else
    "  \(.from | sid) --> \(.to | sid)"
  end
' "${model_path}")
\`\`\`
EOF

  cat > "${learning_root}/software-architecture.md" <<EOF
# Software Architecture

State: \`${STATE_ID}\`
Title: \`$(jq -r '.title' "${model_path}")\`

## Architecture Summary

$(jq -r '.description' "${model_path}")

## Entrypoints

$(jq -r '(.entrypoints // [])[] | "- `\(.name)` -> `\(.url)`"' "${model_path}")

## Notes

$(jq -r '(.notes // [])[] | "- " + .' "${model_path}")

## Diagram

See [Component Diagram](./component-diagram.md).
EOF

  if [[ -f "${architecture_md_path}" ]]; then
    cat >> "${learning_root}/software-architecture.md" <<EOF

## Detailed Architecture (Spec Extract)

EOF
    cat "${architecture_md_path}" >> "${learning_root}/software-architecture.md"
  fi

  cat > "${learning_root}/system-design.md" <<EOF
# System Design

State: \`${STATE_ID}\`

## Design Intent

$(jq -r '.description' "${model_path}")
EOF

  if [[ -n "${system_design_source}" ]]; then
    cat >> "${learning_root}/system-design.md" <<EOF

## Runtime Topology / Flow (Spec Extract)

EOF
    cat "${system_design_source}" >> "${learning_root}/system-design.md"
  fi

  if [[ -n "${REPO_WEB_BASE}" ]]; then
    doc_source_links="- Source feature pack at commit: ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- Source architecture model at commit: ${REPO_WEB_BASE}/blob/${SOURCE_COMMIT}/${FEATURE_PACK}/system/architecture.model.json"
  fi

  cat > "${learning_root}/README.md" <<EOF
# Learning Docs

These docs are generated for the published code snapshot for state \`${STATE_ID}\`.

- [Component List](./component-list.md)
- [System Design](./system-design.md)
- [Software Architecture](./software-architecture.md)
- [Component Diagram](./component-diagram.md)

## Source-of-Truth

Canonical source remains SpecKit artifacts in the main authoring branch:

- Feature pack: \`${FEATURE_PACK}\`
${doc_source_links}
EOF
}

write_learning_guide() {
  local docs_learning_path="docs/learning/state-${STATE_ID}.md"
  local docs_learning_route="/docs/learning/state-${STATE_ID}"
  local docs_state_docs_route="/docs/spec-kit/state-docs"

  cat > "${SNAPSHOT_DIR}/LEARNING.md" <<EOF
# Learning Guide For ${STATE_ID}

This snapshot is code-first output. Canonical intent remains in SpecKit artifacts.

## Learning Focus

$(learning_focus_markdown)

## Read In This Snapshot

- [README.md](./README.md)
- [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
- [STATE.md](./STATE.md)
- [docs/README.md](./docs/README.md)
- [docs/learning/README.md](./docs/learning/README.md)

## Canonical Spec Sources

- Feature pack: \`${FEATURE_PACK}\`
- State docs map route: \`${docs_state_docs_route}\`
- Learning guide route: \`${docs_learning_route}\`
- Learning guide markdown path in source branch: \`${docs_learning_path}\`
EOF

  if [[ -n "${REPO_WEB_BASE}" ]]; then
    cat >> "${SNAPSHOT_DIR}/LEARNING.md" <<EOF
- Source branch feature pack (exact commit): ${REPO_WEB_BASE}/tree/${SOURCE_COMMIT}/${FEATURE_PACK}
- Source branch learning guide (exact commit): ${REPO_WEB_BASE}/blob/${SOURCE_COMMIT}/${docs_learning_path}
EOF
  fi
}

write_snapshot_gitignore() {
  cat > "${SNAPSHOT_DIR}/.gitignore" <<'EOF'
# Runtime + package-manager artifacts
**/node_modules/
**/.angular/
**/.gradle/
**/.npm/
**/.pnpm-store/
**/.cache/
**/.run/

# Build outputs
**/build/
**/dist/
**/out/
**/coverage/
**/bin/
**/obj/

# Logs and local temp files
**/*.log
**/.DS_Store

# Environment + editor local state
**/.env
**/.env.*
**/.idea/
**/.vscode/
EOF
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

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: \`${FEATURE_PACK}\`
- Generation entrypoint: \`${GENERATION_ENTRYPOINT}\`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
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
  007-messaging-nats-replacement)
    install_state_compose_clone_harness "${STATE_ID}"
    ;;
  009-postgres-database-replacement)
    install_state_compose_clone_harness "${STATE_ID}"
    ;;
  004-kubernetes-runtime|005-radius-kubernetes-platform|006-tilt-kubernetes-dev-loop)
    install_kubernetes_clone_harness
    ;;
esac

write_clone_runbook
write_snapshot_learning_docs
write_learning_guide
write_snapshot_gitignore

BRANCH_EXISTS=0
if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  BRANCH_EXISTS=1
  git -C "${ROOT}" worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}" >/dev/null
else
  git -C "${ROOT}" worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${BASE_BRANCH}" >/dev/null
fi

PREVIOUS_BRANCH_TIP=""
if (( BRANCH_EXISTS == 1 )); then
  PREVIOUS_BRANCH_TIP="$(git -C "${WORKTREE_DIR}" rev-parse HEAD)"
  git -C "${WORKTREE_DIR}" reset --hard "${BASE_BRANCH}" >/dev/null
fi

git -C "${WORKTREE_DIR}" rm -rf . >/dev/null 2>&1 || true
git -C "${WORKTREE_DIR}" clean -fdx >/dev/null 2>&1 || true
cp -R "${SNAPSHOT_DIR}/." "${WORKTREE_DIR}/"
git -C "${WORKTREE_DIR}" add -A

if git -C "${WORKTREE_DIR}" diff --cached --quiet; then
  if (( BRANCH_EXISTS == 1 )); then
    git -C "${WORKTREE_DIR}" reset --hard "${PREVIOUS_BRANCH_TIP}" >/dev/null
    echo "[info] no snapshot changes for ${BRANCH_NAME}; preserved prior tip"
  else
    echo "[info] no snapshot changes to commit on ${BRANCH_NAME}"
  fi
else
  git -C "${WORKTREE_DIR}" commit \
    -m "snapshot: ${STATE_ID} generated from ${SOURCE_COMMIT}" \
    -m "lineage-base: ${BASE_BRANCH}" >/dev/null
  echo "[ok] committed generated snapshot on branch ${BRANCH_NAME}"
fi

if (( PUSH == 1 )); then
  if [[ "${BASE_BRANCH}" == "${GENERATED_ROOT_BRANCH}" ]]; then
    git -C "${ROOT}" push --force-with-lease origin "${GENERATED_ROOT_BRANCH}"
  fi
  git -C "${WORKTREE_DIR}" push --force-with-lease origin "${BRANCH_NAME}"
  echo "[ok] pushed ${BRANCH_NAME}"
fi

echo "[done] generated-state branch ready: ${BRANCH_NAME}"

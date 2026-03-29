#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="trade-feed"
TARGET="${ROOT}/generated/code/components/trade-feed-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/trade-feed-specfirst"
MANIFEST_PATH="${ROOT}/generated/manifests/${COMPONENT_ID}.manifest.json"

speckit_assert_global_readiness
speckit_assert_component_ready "${COMPONENT_ID}"
bash "${ROOT}/pipeline/speckit/compile-component-manifest.sh" "${COMPONENT_ID}" "${MANIFEST_PATH}"

[[ -d "${TEMPLATE_ROOT}" ]] || {
  echo "[fail] missing template directory: ${TEMPLATE_ROOT}"
  exit 1
}

[[ -f "${MANIFEST_PATH}" ]] || {
  echo "[fail] manifest was not generated: ${MANIFEST_PATH}"
  exit 1
}

jq -e '
  .schemaVersion == "1.0.0" and
  .component.id == "trade-feed" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
TRADE_FEED_PORT_ENV="$(manifest_env_by_prefix "TRADE_FEED_PORT")"
CORS_ALLOWED_ORIGINS_ENV="$(manifest_env_by_prefix "CORS_ALLOWED_ORIGINS")"

for required_var in TRADE_FEED_PORT_ENV CORS_ALLOWED_ORIGINS_ENV; do
  [[ -n "${!required_var}" ]] || {
    echo "[fail] manifest missing required runtime env mapping: ${required_var}"
    exit 1
  }
done

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"

cat <<EOF > "${TARGET}/README.md"
# Trade-Feed (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
npm install
npm run start
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${TRADE_FEED_PORT_ENV}\`
- CORS origins: \`${CORS_ALLOWED_ORIGINS_ENV}\` (default \`*\`)
- Commands: \`subscribe\`, \`unsubscribe\`, \`unusbscribe\` (legacy compatibility), \`publish\`
EOF

cat <<EOF > "${TARGET}/index.js"
const sockio = require("socket.io");
const app = require("express")();
const winston = require("winston");
const http = require("http").createServer(app);

const configuredOrigins = (process.env.${CORS_ALLOWED_ORIGINS_ENV} || "*")
  .split(",")
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

const io = new sockio.Server(http, {
  cors: {
    origin: configuredOrigins.includes("*") ? "*" : configuredOrigins,
    methods: ["GET", "POST"]
  }
});

const port = Number(process.env.${TRADE_FEED_PORT_ENV} || ${DEFAULT_PORT});

const log = winston.createLogger({
  transports: [new winston.transports.Console()]
});

const SUBSCRIBE = "subscribe";
const UNSUBSCRIBE = "unsubscribe";
const UNSUBSCRIBE_LEGACY = "unusbscribe";
const PUBLISH = "publish";

app.get("/", (req, res) => {
  res.sendFile(__dirname + "/index.html");
});

function wrapMessage(sender, topic, payloadType, payload) {
  return {
    type: payloadType || "message",
    from: sender,
    topic: topic,
    date: new Date().getTime(),
    payload: payload
  };
}

function joinMessage(user, topic) {
  return {
    topic: topic,
    type: "message",
    payload: { message: \`New Joiner \${user} to topic \${topic}\` }
  };
}

function leaveMessage(user, topic) {
  return {
    topic: topic,
    type: "message",
    payload: { message: \`\${user} has left \${topic}\` }
  };
}

function broadcast(from, data) {
  const message = wrapMessage(from, data.topic, data.type, data.payload);
  log.info(\`Publish \${data.topic} -> \${JSON.stringify(message)}\`);
  io.sockets.in([data.topic, "/*"]).emit(PUBLISH, message);
}

function handleUnsubscribe(socket, topic) {
  log.info(\`Unsubscribe \${topic}\`);
  broadcast("System", leaveMessage(socket.id, topic));
  socket.leave(topic);
}

io.on("connection", (socket) => {
  log.info(\`New Connection from \${socket.id}\`);

  socket.on(SUBSCRIBE, (topic) => {
    log.info(\`Subscribe \${topic}\`);
    socket.join(topic);
    broadcast("System", joinMessage(socket.id, topic));
  });

  socket.on(UNSUBSCRIBE, (topic) => {
    handleUnsubscribe(socket, topic);
  });

  socket.on(UNSUBSCRIBE_LEGACY, (topic) => {
    handleUnsubscribe(socket, topic);
  });

  socket.on(PUBLISH, (data) => {
    broadcast(socket.id, data);
  });
});

http.listen(port, () => {
  log.info(\`[ready] trade-feed-specfirst listening on :\${port}\`);
});
EOF

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"

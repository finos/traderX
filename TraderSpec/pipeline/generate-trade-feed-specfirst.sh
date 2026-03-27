#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/trade-feed-specfirst"
SOURCE_INSPECTOR_HTML="${ROOT}/templates/trade-feed/index.html"

rm -rf "${TARGET}"
mkdir -p "${TARGET}"

cat <<'EOF' > "${TARGET}/README.md"
# Trade-Feed (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
npm install
npm run start
```

## Runtime Contract

- Default port: `18086` via `TRADE_FEED_PORT`
- CORS origins: `CORS_ALLOWED_ORIGINS` (default `*`)
- Commands: `subscribe`, `unsubscribe`, `unusbscribe` (legacy compatibility), `publish`
EOF

cat <<'EOF' > "${TARGET}/package.json"
{
  "name": "@traderspec/trade-feed-specfirst",
  "version": "0.1.0",
  "private": true,
  "license": "Apache-2.0",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^5.0.1",
    "socket.io": "^4.8.1",
    "socket.io-client": "^4.8.1",
    "winston": "^3.17.0"
  }
}
EOF

cat <<'EOF' > "${TARGET}/index.js"
const sockio = require("socket.io");
const app = require("express")();
const winston = require("winston");
const http = require("http").createServer(app);

const configuredOrigins = (process.env.CORS_ALLOWED_ORIGINS || "*")
  .split(",")
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

const io = new sockio.Server(http, {
  cors: {
    origin: configuredOrigins.includes("*") ? "*" : configuredOrigins,
    methods: ["GET", "POST"]
  }
});

const port = Number(process.env.TRADE_FEED_PORT || 18086);

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
    payload: { message: `New Joiner ${user} to topic ${topic}` }
  };
}

function leaveMessage(user, topic) {
  return {
    topic: topic,
    type: "message",
    payload: { message: `${user} has left ${topic}` }
  };
}

function broadcast(from, data) {
  const message = wrapMessage(from, data.topic, data.type, data.payload);
  log.info(`Publish ${data.topic} -> ${JSON.stringify(message)}`);
  io.sockets.in([data.topic, "/*"]).emit(PUBLISH, message);
}

function handleUnsubscribe(socket, topic) {
  log.info(`Unsubscribe ${topic}`);
  broadcast("System", leaveMessage(socket.id, topic));
  socket.leave(topic);
}

io.on("connection", (socket) => {
  log.info(`New Connection from ${socket.id}`);

  socket.on(SUBSCRIBE, (topic) => {
    log.info(`Subscribe ${topic}`);
    socket.join(topic);
    broadcast("System", joinMessage(socket.id, topic));
  });

  socket.on(UNSUBSCRIBE, (topic) => {
    handleUnsubscribe(socket, topic);
  });

  // Preserve baseline typo compatibility.
  socket.on(UNSUBSCRIBE_LEGACY, (topic) => {
    handleUnsubscribe(socket, topic);
  });

  socket.on(PUBLISH, (data) => {
    broadcast(socket.id, data);
  });
});

http.listen(port, () => {
  log.info(`[ready] trade-feed-specfirst listening on :${port}`);
});
EOF

if [[ -f "${SOURCE_INSPECTOR_HTML}" ]]; then
  cp "${SOURCE_INSPECTOR_HTML}" "${TARGET}/index.html"
else
  cat <<'EOF' > "${TARGET}/index.html"
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Trade Feed Inspector</title>
  </head>
  <body>
    <h1>Trade Feed Inspector</h1>
    <p>Spec-first generated fallback page.</p>
  </body>
</html>
EOF
fi

echo "[done] regenerated ${TARGET}"

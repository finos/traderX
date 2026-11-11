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

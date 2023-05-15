const sockio = require("socket.io");
const app = require('express')();
const winston = require('winston');
const http = require('http').createServer(app);

const io = new sockio.Server(http, {
  cors: {
    origin: "*"
  }
});
const port = process.env.TRADE_FEED_PORT || 18086;

const log = winston.createLogger({
  transports: [
    new winston.transports.Console()
  ]
});

// command names
const SUBSCRIBE = "subscribe";
const UNSUBSCRIBE = "unusbscribe";
const PUBLISH = "publish";

app.get('/', (req, res) => {
  res.sendFile(__dirname + '/index.html');
});

function broadcast(from, data) {
  data._from = from;
  data._at = new Date().getTime();
  log.info(`Publish ${data.topic} -> ${JSON.stringify(data)}`);
  io.sockets.in([data.topic, "/*"]).emit(PUBLISH, data);
}

io.on('connection', (socket) => {
  log.info(`New Connection from ${socket.id}`);
  socket.on(SUBSCRIBE, (topic) => {
    log.info(`Subscribe ${topic}`);
    socket.join(topic);
    broadcast('System', { topic: topic, message: `New Joiner ${socket.id} to topic ${topic}` });
  });
  socket.on(UNSUBSCRIBE, (topic) => {
    log.info(`Unsubscribe ${topic}`);
    broadcast('System', { topic: topic, message: `${socket.id} has left topic ${topic}` });
    socket.leave(topic);
  });
  socket.on(PUBLISH, (data) => {
    broadcast(socket.id, data);
  });
});


http.listen(port, () => {
  log.info(`Socket.IO server running at http://localhost:${port}/`);
});
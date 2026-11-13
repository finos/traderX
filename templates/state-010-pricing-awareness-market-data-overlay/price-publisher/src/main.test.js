const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const path = require('node:path');

test('real publisher starts with the locked Yahoo import and serves snapshot prices', { timeout: 15000 }, async (t) => {
  // Implement only the NATS handshake needed by this HTTP startup regression.
  const sockets = new Set();
  const broker = net.createServer((socket) => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    socket.write('INFO {"server_id":"test","version":"2.10.0","proto":1,"max_payload":1048576}\r\n');
    socket.on('data', (data) => {
      if (data.toString().includes('PING\r\n')) socket.write('PONG\r\n');
    });
  });
  broker.listen(0, '127.0.0.1');
  await once(broker, 'listening');
  const portProbe = net.createServer();
  portProbe.listen(0, '127.0.0.1');
  await once(portProbe, 'listening');
  const port = portProbe.address().port;
  await new Promise((resolve) => portProbe.close(resolve));
  const child = spawn(process.execPath, [path.join(__dirname, 'main.js')], {
    env: { ...process.env, PRICE_PUBLISHER_PORT: String(port), PRICE_BOOTSTRAP_MODE: 'snapshot',
      PRICE_TICKERS: 'AAPL,MSFT', NATS_ADDRESS: `nats://127.0.0.1:${broker.address().port}` },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let output = '';
  child.stdout.on('data', (data) => { output += data; });
  child.stderr.on('data', (data) => { output += data; });
  t.after(async () => {
    if (child.exitCode === null) { child.kill(); await once(child, 'exit'); }
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve) => broker.close(resolve));
  });
  const url = `http://127.0.0.1:${port}`;
  let health;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    assert.equal(child.exitCode, null, output);
    try { health = await (await fetch(`${url}/health`)).json(); break; } catch (_) { /* startup */ }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.ok(health, output);
  assert.equal(health.status, 'ok');
  assert.equal(health.tickers, 2);
  const { prices } = await (await fetch(`${url}/prices`)).json();
  assert.equal(prices.length, 2);
  const apple = await (await fetch(`${url}/prices/AAPL`)).json();
  assert.equal(apple.ticker, 'AAPL');
  assert.equal(apple.source, 'snapshot');
  assert.ok(Number.isFinite(apple.price) && apple.price > 0);
});

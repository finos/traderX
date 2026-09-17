'use strict';

const { spawn } = require('child_process');

const port = Number.parseInt(process.env.WEB_SERVICE_PORT || '18093', 10);
const ngBinary = process.platform === 'win32' ? 'npx.cmd' : 'npx';

const child = spawn(
  ngBinary,
  ['ng', 'serve', '--host', '0.0.0.0', '--disable-host-check', '--port', String(port)],
  { stdio: 'inherit', env: process.env }
);

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 1);
});

child.on('error', (err) => {
  console.error('[angular-dev] failed to start ng serve', err);
  process.exit(1);
});

'use strict';

const http = require('http');
const handler = require('serve-handler');
const path = require('path');
const fs = require('fs');

const port = Number.parseInt(process.env.WEB_SERVICE_PORT || '18093', 10);

const distBase = path.join(__dirname, 'dist');
const distBrowser = path.join(distBase, 'browser');
const publicDir = fs.existsSync(distBrowser) ? distBrowser : distBase;

const server = http.createServer((req, res) =>
  handler(req, res, {
    public: publicDir,
    rewrites: [{ source: '**', destination: '/index.html' }],
    headers: [
      {
        source: '**',
        headers: [{ key: 'Cache-Control', value: 'no-cache' }]
      }
    ]
  })
);

server.listen(port, '0.0.0.0', () => {
  console.log(`[angular-static] serving ${publicDir}`);
  console.log(`[angular-static] listening on :${port}`);
});

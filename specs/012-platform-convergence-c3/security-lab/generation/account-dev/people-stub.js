'use strict';
const http = require('node:http');
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://people');
  const user = url.searchParams.get('LogonId');
  const ok = req.method === 'GET' && url.pathname === '/People/GetPerson' && ['reader', 'trader', 'operator'].includes(user);
  res.writeHead(ok ? 200 : 404, {'Content-Type':'application/json'});
  res.end(JSON.stringify(ok ? {logonId:user, fullName:'Synthetic '+user, email:user+'@example.invalid', department:'Lab', photoUrl:''} : {error:'Synthetic person not found'}));
}).listen(18089, '0.0.0.0');

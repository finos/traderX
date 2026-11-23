const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { natsOptions } = require('./nats-options');

test('legacy options preserved and URL credentials rejected', () => {
  assert.deepEqual(natsOptions({}), { servers: 'nats://localhost:4222', maxReconnectAttempts: -1 });
  assert.throws(() => natsOptions({ NATS_ADDRESS: 'nats://user:secret@localhost:4222' }), /credentials/);
});

test('partial, disabled, plaintext and malformed security fail closed', () => {
  for (const env of [
    {NATS_SECURITY_REQUIRED:'true'}, {NATS_SECURITY_REQUIRED:'false'},
    {NATS_USER_FILE:'/missing'}, {NATS_SECURITY_REQUIRED:'true',NATS_ADDRESS:'nats://localhost:4222'},
    {NATS_SECURITY_REQUIRED:'true',NATS_ADDRESS:'tls://localhost:4222?password=secret'},
  ]) assert.throws(() => natsOptions(env));
});

test('projected files load without leaking missing file paths or credential contents', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'traderx-nats-options-'));
  t.after(() => fs.rmSync(dir, {recursive:true,force:true}));
  const env={NATS_SECURITY_REQUIRED:'true',NATS_ADDRESS:'tls://localhost:4222',NATS_USER_FILE:path.join(dir,'user'),NATS_PASSWORD_FILE:path.join(dir,'password'),NATS_CA_FILE:path.join(dir,'ca')};
  fs.writeFileSync(env.NATS_USER_FILE,'pricer\n');fs.writeFileSync(env.NATS_PASSWORD_FILE,'synthetic-secret\n');fs.writeFileSync(env.NATS_CA_FILE,'-----BEGIN CERTIFICATE-----\nfixture');
  const options=natsOptions(env);assert.equal(options.user,'pricer');assert.equal(options.pass,'synthetic-secret');assert.equal(options.tls.handshakeFirst,true);
  fs.writeFileSync(env.NATS_PASSWORD_FILE,'synthetic-secret\ninvalid');
  assert.throws(() => natsOptions(env), error => !error.message.includes('synthetic-secret') && error.message==='Invalid NATS_PASSWORD_FILE');
  fs.unlinkSync(env.NATS_PASSWORD_FILE);
  assert.throws(() => natsOptions(env), error => error.message==='Cannot read NATS_PASSWORD_FILE');
});

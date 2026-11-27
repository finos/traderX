const fs = require('node:fs');
const path = require('node:path');

// Secrets are projected files, never URL parameters or baked-in build inputs.
function natsOptions(env = process.env) {
  const keys = ['NATS_SECURITY_REQUIRED', 'NATS_USER_FILE', 'NATS_PASSWORD_FILE', 'NATS_CA_FILE'];
  const enabled = keys.some(key => env[key] !== undefined);
  const servers = env.NATS_ADDRESS || `nats://${env.NATS_BROKER_HOST || 'localhost'}:4222`;
  let address;
  try { address = new URL(servers); } catch { throw new Error('Invalid NATS address'); }
  if (address.username || address.password) throw new Error('NATS URL credentials are forbidden');
  if (!enabled) return { servers, maxReconnectAttempts: -1 };
  if (env.NATS_SECURITY_REQUIRED !== 'true') throw new Error('NATS security requires explicit true');
  if (!env.NATS_ADDRESS || address.protocol !== 'tls:' || address.search || address.hash || (address.pathname && address.pathname !== '/')) {
    throw new Error('NATS security requires an explicit credential-free TLS address');
  }
  function read(key) {
    const file = env[key];
    if (!file || !path.isAbsolute(file)) throw new Error(`Missing absolute ${key}`);
    let value;
    try { value = fs.readFileSync(file, 'utf8').replace(/\r?\n$/, ''); }
    catch { throw new Error(`Cannot read ${key}`); }
    if (!value || /[\r\n\0]/.test(value)) throw new Error(`Invalid ${key}`);
    return value;
  }
  const user = read('NATS_USER_FILE'), pass = read('NATS_PASSWORD_FILE');
  const caFile = env.NATS_CA_FILE;
  if (!caFile || !path.isAbsolute(caFile)) throw new Error('Missing absolute NATS_CA_FILE');
  try { if (!fs.readFileSync(caFile, 'utf8').includes('-----BEGIN CERTIFICATE-----')) throw new Error(); }
  catch { throw new Error('Invalid NATS_CA_FILE'); }
  return { servers, maxReconnectAttempts: -1, user, pass, tls: { caFile, handshakeFirst: true } };
}
module.exports = { natsOptions };

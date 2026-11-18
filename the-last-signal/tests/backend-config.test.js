import test from 'node:test';
import assert from 'node:assert/strict';
import { loadBackendConfig } from '../src/backend-config.js';

function fake(files, calls) {
  return async url => {
    calls.push(url);
    if (!Object.hasOwn(files, url)) return { ok: false };
    return { ok: true, json: async () => files[url] };
  };
}
test('backend config is a single explicit WebSocket endpoint file', async () => {
  const calls = [];
  const cfg = await loadBackendConfig('./', fake({ './backend-config.json': { websocketUrl: ' wss://example.test/ws ' } }, calls));
  assert.deepEqual(cfg, { websocketUrl: 'wss://example.test/ws' });
  assert.deepEqual(calls, ['./backend-config.json']);
});
test('old deployments can still use config.json', async () => {
  const calls = [];
  const cfg = await loadBackendConfig('./repo/', fake({ './repo/backend-config.json': { websocketUrl: '' }, './repo/config.json': { serverUrl: 'wss://legacy.test/ws' } }, calls));
  assert.equal(cfg.websocketUrl, 'wss://legacy.test/ws');
});
test('missing configuration leaves multiplayer endpoint blank', async () => {
  const cfg = await loadBackendConfig('./', async () => { throw new Error('offline'); });
  assert.equal(cfg.websocketUrl, '');
});

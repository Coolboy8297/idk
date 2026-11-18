import test from 'node:test';
import assert from 'node:assert/strict';
import { healthUrl, waitForBackend } from '../src/wake-monitor.js';

test('health probes translate a configured WebSocket endpoint into its host health route', () => {
  assert.equal(healthUrl('wss://game.example:9443/custom/ws?x=1'), 'https://game.example:9443/health');
  assert.equal(healthUrl('ws://localhost:8787/ws'), 'http://localhost:8787/health');
  assert.throws(() => healthUrl('https://game.example/ws'), /valid WebSocket/);
});

test('wake monitor retries cold responses then proceeds when the server is healthy', async () => {
  let time = 0, calls = 0, waiting = 0;
  const result = await waitForBackend('wss://game.example/ws', {
    now: () => time,
    sleep: async ms => { time += ms; },
    fetcher: async url => {
      assert.equal(url, 'https://game.example/health');
      calls += 1;
      return { ok: calls === 3, json: async () => ({ ok: calls === 3, version: 'test' }) };
    },
    onWaiting: () => waiting += 1,
  });
  assert.equal(result.version, 'test');
  assert.equal(calls, 3);
  assert.equal(waiting, 2);
});

test('wake monitor stops retrying after its bounded wait window', async () => {
  let time = 0, calls = 0;
  await assert.rejects(waitForBackend('wss://game.example/ws', {
    timeoutMs: 10,
    intervalMs: 4,
    requestTimeoutMs: 1,
    now: () => time,
    sleep: async ms => { time += ms; },
    fetcher: async () => { calls += 1; return { ok: false }; },
  }), /did not wake in time/);
  assert.ok(calls <= 4, `expected a bounded number of health checks, got ${calls}`);
});

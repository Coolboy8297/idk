import test from 'node:test';
import assert from 'node:assert/strict';
import { validateServerUrl } from '../src/network.js';

test('accepts secure and local development WebSocket endpoints', () => {
  assert.equal(validateServerUrl('wss://game.example/ws', 'https:'), 'wss://game.example/ws');
  assert.equal(validateServerUrl('ws://localhost:8080/ws', 'http:'), 'ws://localhost:8080/ws');
});
test('refuses insecure endpoints from an HTTPS page', () => {
  assert.throws(() => validateServerUrl('ws://example.com/ws', 'https:'), /secure/);
});
test('rejects missing, non-websocket, and credential-bearing endpoints', () => {
  assert.throws(() => validateServerUrl('', 'http:'));
  assert.throws(() => validateServerUrl('https://example.com', 'http:'));
  assert.throws(() => validateServerUrl('wss://u:p@example.com/ws', 'http:'));
});

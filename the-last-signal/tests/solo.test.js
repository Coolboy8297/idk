import test from 'node:test';
import assert from 'node:assert/strict';
import { SoloConnection } from '../src/solo.js';

class MemoryStorage {
  constructor() { this.items = new Map(); }
  getItem(key) { return this.items.has(key) ? this.items.get(key) : null; }
  setItem(key, value) { this.items.set(key, String(value)); }
}

test('single player saves and restores a persistent local checkpoint', () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'localStorage');
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: new MemoryStorage() });
  const solo = new SoloConnection(); let state, status, errors = [];
  solo.addEventListener('snapshot', event => { state = event.detail; });
  solo.addEventListener('status', event => { status = event.detail; });
  solo.addEventListener('error', event => errors.push(event.detail));
  try {
    assert.equal(SoloConnection.hasSavedCheckpoint(), false);
    solo.connect({ name: 'Tester' });
    assert.equal(status, 'connected'); assert.equal(state.players.length, 1); assert.equal(state.phase, 'playing');
    solo.room.player.x = -6; solo.room.player.z = 10;
    solo.send({ type: 'interact', target: 'fuse', actionId: 'fuse' });
    assert.equal(state.world.fuse, true); assert.match(state.objective, /generator/i);
    solo.setPaused(true);
    solo.send({ type: 'save' });
    assert.equal(SoloConnection.hasSavedCheckpoint(), true); assert.equal(state.checkpoint, true);
    solo.room.player.x = -6; solo.room.player.z = 0;
    solo.send({ type: 'interact', target: 'generator', actionId: 'generator' });
    assert.equal(state.world.generator, true);
    solo.send({ type: 'load' });
    assert.equal(state.world.fuse, true); assert.equal(state.world.generator, false); assert.equal(state.players[0].z, 16);
    solo.close();
    const resumed = new SoloConnection(); let resumedState;
    resumed.addEventListener('snapshot', event => { resumedState = event.detail; });
    resumed.connect({ resume: true });
    assert.equal(resumedState.world.fuse, true); assert.equal(resumedState.world.generator, false);
    resumed.close();
    assert.deepEqual(errors, []);
  } finally {
    solo.close();
    if (previous) Object.defineProperty(globalThis, 'localStorage', previous); else delete globalThis.localStorage;
  }
});

test('single-player objectives enforce prerequisites and reach an ending', () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'localStorage');
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: new MemoryStorage() });
  const solo = new SoloConnection(); let state, failure = '', action = 0;
  solo.addEventListener('snapshot', event => { state = event.detail; });
  solo.addEventListener('error', event => { failure = event.detail; });
  const interact = (target, x, z) => {
    solo.room.player.x = x; solo.room.player.z = z;
    solo.send({ type: 'interact', target, actionId: ++action });
  };
  try {
    solo.connect();
    solo.setPaused(true); // Keep the guardian still while testing objective rules.
    interact('generator', -6, 0);
    assert.match(failure, /fuse/i); assert.equal(state.world.generator, false);
    interact('fuse', -6, 10); interact('generator', -6, 0);
    interact('key', 6, -5); interact('archive', 0, -12);
    interact('note1', 5, -17); interact('note2', -5, -22); interact('note3', 5, -27);
    assert.deepEqual(state.world.notes, [true, true, true]);
    interact('exit', 0, -32);
    assert.equal(state.phase, 'won'); assert.equal(state.world.completed, true);
  } finally {
    solo.close();
    if (previous) Object.defineProperty(globalThis, 'localStorage', previous); else delete globalThis.localStorage;
  }
});

test('single player reports failure instead of pretending a blocked save succeeded', () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'localStorage');
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: { getItem: () => null, setItem: () => { throw Error('blocked'); } } });
  const solo = new SoloConnection(); let failure = '';
  solo.addEventListener('error', event => { failure = event.detail; });
  try { solo.connect(); solo.send({ type: 'save' }); assert.match(failure, /Could not save.*blocked/); }
  finally { solo.close(); if (previous) Object.defineProperty(globalThis, 'localStorage', previous); else delete globalThis.localStorage; }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createRequire } from 'node:module';
import { createGameServer, VERSION } from '../server/index.js';

const require = createRequire(new URL('../server/package.json', import.meta.url));
const WebSocket = require('ws');

class Client {
  constructor(ws) {
    this.ws = ws; this.messages = []; this.listeners = new Set(); this.seq = 0;
    this.x = 0; this.z = 16; this.counter = 0;
    ws.on('message', raw => {
      const msg = JSON.parse(raw.toString()); this.messages.push(msg);
      for (const listener of [...this.listeners]) listener();
    });
  }
  send(data) { this.ws.send(typeof data === 'string' ? data : JSON.stringify(data)); }
  mark() { return this.messages.length; }
  wait(fn, from = 0, timeout = 3000) {
    return new Promise((resolve, reject) => {
      let timer;
      const check = () => {
        const found = this.messages.slice(from).find(fn);
        if (found) { clearTimeout(timer); this.listeners.delete(check); resolve(found); }
      };
      this.listeners.add(check);
      timer = setTimeout(() => { this.listeners.delete(check); reject(new Error(`Timed out; received: ${JSON.stringify(this.messages.slice(from)).slice(-2000)}`)); }, timeout);
      check();
    });
  }
  async sync() {
    const t = `barrier-${++this.counter}`; const mark = this.mark();
    this.send({ type: 'ping', t });
    await this.wait(m => m.type === 'pong' && m.t === t, mark);
  }
}

async function setup(t, opts = {}) {
  const clock = { time: 100_000 };
  const server = createGameServer({ clock: () => clock.time, autoTick: false, ...opts });
  server.httpServer.listen(0, '127.0.0.1');
  await once(server.httpServer, 'listening');
  const port = server.httpServer.address().port;
  const clients = [];
  t.after(async () => { for (const c of clients) c.ws.terminate(); await server.close(); });
  return {
    server, clock, port,
    async connect(path = '/ws', headers = {}) {
      const ws = new WebSocket(`ws://127.0.0.1:${port}${path}`, { headers });
      await once(ws, 'open'); const c = new Client(ws); clients.push(c); return c;
    },
  };
}
async function hello(c, type, props = {}) {
  const mark = c.mark(); c.send({ type, version: VERSION, ...props });
  return c.wait(m => m.type === 'welcome', mark);
}
async function requestError(c, msg, code) {
  const mark = c.mark(); c.send(msg);
  return c.wait(m => m.type === 'error' && m.code === code, mark);
}
async function move(c, clock, x, z) {
  const d = Math.hypot(x - c.x, z - c.z), steps = Math.max(1, Math.ceil(d / 1.7));
  const sx = c.x, sz = c.z;
  for (let i = 1; i <= steps; i++) {
    clock.time += 300;
    c.send({ type: 'pose', x: sx + (x - sx) * i / steps, z: sz + (z - sz) * i / steps,
      yaw: 0, crouch: false, sprint: true, flashlight: true, seq: c.seq++ });
    await c.sync();
  }
  c.x = x; c.z = z;
}
let actionId = 0;
async function interact(c, target) {
  const mark = c.mark(); c.send({ type: 'interact', target, actionId: `test-${++actionId}` });
  return c.wait(m => m.type === 'snapshot' && m.state.world[target] === true ||
    (m.type === 'snapshot' && target.startsWith('note') && m.state.world.notes[Number(target.at(-1)) - 1]), mark);
}

// All network actions are real ws clients, while game time and the tick are controlled.
test('two clients play, reconnect, migrate host, checkpoint, hunt, progress and win in isolated rooms', async t => {
  const { server, clock, connect } = await setup(t);
  let host = await connect(); const guest = await connect(); const outsider = await connect();
  const hostWelcome = await hello(host, 'create', { name: 'Host' });
  assert.match(hostWelcome.code, /^[A-Z2-9]{6}$/);
  assert.ok(hostWelcome.token.length >= 40); assert.notEqual(hostWelcome.token, hostWelcome.code);
  const guestWelcome = await hello(guest, 'join', { code: hostWelcome.code, name: 'Guest' });
  const other = await hello(outsider, 'create', { name: 'Other room' });
  assert.notEqual(other.code, hostWelcome.code);
  await requestError(guest, { type: 'start' }, 'NOT_HOST');
  let mark = guest.mark(); host.send({ type: 'start' });
  let started = await guest.wait(m => m.type === 'snapshot' && m.state.phase === 'playing', mark);
  assert.equal(started.state.players.length, 2);
  assert.equal(started.state.hostId, hostWelcome.id);
  assert.equal(started.state.monster.mode, 'patrol');
  const originalMonsterX = started.state.monster.x;
  clock.time += 100; mark = guest.mark(); server.tick();
  const patrol = await guest.wait(m => m.type === 'snapshot', mark);
  assert.equal(patrol.state.monster.mode, 'patrol');
  assert.notEqual(patrol.state.monster.x, originalMonsterX);
  assert.ok(Math.abs(patrol.state.monster.z + 24) < 0.2);
  await requestError(host, { type: 'interact', target: 'fuse', actionId: 'far' }, 'TOO_FAR');
  await requestError(host, { type: 'pose', x: 8, z: -34, yaw: 0, crouch: false, sprint: true, flashlight: true, seq: host.seq++ }, 'INVALID_POSE');
  host.send('{broken json'); await host.wait(m => m.type === 'error' && m.code === 'INVALID_MESSAGE');
  await move(host, clock, -6, 10);
  mark = guest.mark(); clock.time += 100; server.tick();
  const movement = await guest.wait(m => m.type === 'snapshot' && m.state.players.find(p => p.id === hostWelcome.id).x === -6, mark);
  assert.equal(movement.state.players.find(p => p.id === hostWelcome.id).z, 10);
  const fuse = await interact(host, 'fuse');
  assert.equal(fuse.state.world.fuse, true); assert.match(fuse.state.objective, /generator/i);
  mark = host.mark(); host.send({ type: 'interact', target: 'fuse', actionId: `test-${actionId}` });
  host.send({ type: 'interact', target: 'fuse', actionId: 'a-fresh-id-for-the-same-object' }); await host.sync();
  assert.ok(!host.messages.slice(mark).some(m => m.type === 'snapshot' || m.type === 'error'));
  mark = guest.mark(); host.ws.terminate();
  const migrated = await guest.wait(m => m.type === 'snapshot' && m.state.hostId === guestWelcome.id, mark);
  assert.equal(migrated.state.players.find(p => p.id === hostWelcome.id).connected, false);
  const foreign = await connect();
  await requestError(foreign, { type: 'resume', code: other.code, token: hostWelcome.token, version: VERSION }, 'INVALID_RESUME');
  host = await connect();
  const resumed = await hello(host, 'resume', { code: hostWelcome.code, token: hostWelcome.token });
  assert.equal(resumed.id, hostWelcome.id); assert.equal(resumed.token, hostWelcome.token);
  assert.equal(resumed.hostId, guestWelcome.id); assert.equal(resumed.state.players.length, 2);
  assert.equal(resumed.state.world.fuse, true); host.x = -6; host.z = 10;
  await requestError(host, { type: 'save' }, 'NOT_HOST');
  mark = guest.mark(); guest.send({ type: 'save' });
  await guest.wait(m => m.type === 'event' && m.name === 'saved', mark);
  await move(host, clock, -6, 0); await interact(host, 'generator');
  mark = host.mark(); guest.send({ type: 'load' });
  const loaded = await host.wait(m => m.type === 'snapshot' && m.state.world.fuse && !m.state.world.generator, mark);
  assert.equal(loaded.state.players.find(p => p.id === hostWelcome.id).z, 16);
  assert.equal(loaded.state.players.find(p => p.id === guestWelcome.id).connected, true);
  host.x = 0; host.z = 16;
  await move(host, clock, -6, 0); const powered = await interact(host, 'generator');
  assert.equal(powered.state.world.generator, true); assert.match(powered.state.objective, /key/i);
  await move(host, clock, 6, -5); await interact(host, 'key');
  await move(host, clock, 0, -12); const open = await interact(host, 'archive');
  assert.equal(open.state.world.archive, true); assert.match(open.state.objective, /recordings/i);
  await move(host, clock, 0, -15);
  mark = guest.mark(); clock.time += 100; server.tick();
  const chase = await guest.wait(m => m.type === 'snapshot' && m.state.monster.mode === 'chase', mark);
  assert.ok(chase.state.monster.z > -24);
  await move(host, clock, 0, -1);
  mark = guest.mark(); clock.time += 100; server.tick();
  await guest.wait(m => m.type === 'snapshot' && m.state.monster.mode === 'investigate', mark);
  mark = guest.mark();
  for (let i = 0; i < 24; i++) { clock.time += 250; server.tick(); }
  const search = await guest.wait(m => m.type === 'snapshot' && m.state.monster.mode === 'search', mark);
  // Stop on the enemy's live location and allow an authoritative contact tick.
  await guest.sync(); const latest = guest.messages.filter(m => m.type === 'snapshot').at(-1).state;
  await move(host, clock, latest.monster.x, latest.monster.z);
  mark = host.mark(); clock.time += 100; server.tick();
  await host.wait(m => m.type === 'event' && m.name === 'caught', mark);
  const caught = await host.wait(m => m.type === 'snapshot' && m.state.players.find(p => p.id === hostWelcome.id).z === 16, mark);
  assert.equal(caught.state.world.archive, true); assert.equal(caught.state.world.generator, true);
  host.x = 0; host.z = 16;
  await move(host, clock, 5, -17); await interact(host, 'note1');
  await move(host, clock, -5, -22); await interact(host, 'note2');
  await move(host, clock, 5, -27); const allNotes = await interact(host, 'note3');
  assert.deepEqual(allNotes.state.world.notes, [true, true, true]); assert.match(allNotes.state.objective, /exit/i);
  await move(host, clock, 0, -32); const won = await interact(host, 'exit');
  assert.equal(won.state.phase, 'won'); assert.equal(won.state.world.completed, true);
  mark = host.mark(); guest.send({ type: 'load' });
  const replay = await host.wait(m => m.type === 'snapshot' && m.state.phase === 'playing' && !m.state.world.generator, mark);
  assert.equal(replay.state.world.fuse, true); assert.equal(replay.state.world.completed, false);
  assert.equal(replay.state.hostId, guestWelcome.id);
  await outsider.sync();
  for (const message of outsider.messages.filter(m => m.type === 'snapshot')) {
    assert.equal(message.state.players.length, 1); assert.equal(message.state.players[0].id, other.id);
    assert.equal(message.state.world.fuse, false); assert.equal(message.state.world.completed, false);
  }
  assert.ok(!outsider.messages.some(m => m.type === 'event' && ['caught', 'progress', 'won', 'saved', 'loaded'].includes(m.name)));
  assert.ok(search.state.monster.mode === 'search');
});

test('reserved seats, expiry, host-only start and archive/movement validation', async t => {
  const { server, clock, connect } = await setup(t, { graceMs: 5000 });
  const a = await connect(), b = await connect(), c = await connect(), d = await connect(), e = await connect();
  const wa = await hello(a, 'create', { name: 'A' });
  const wb = await hello(b, 'join', { name: 'B', code: wa.code });
  await hello(c, 'join', { name: 'C', code: wa.code });
  const wd = await hello(d, 'join', { name: 'D', code: wa.code });
  await requestError(e, { type: 'join', name: 'E', code: wa.code, version: VERSION }, 'ROOM_FULL');
  let mark = a.mark(); d.ws.terminate();
  await a.wait(m => m.type === 'snapshot' && m.state.players.find(p => p.id === wd.id)?.connected === false, mark);
  await requestError(e, { type: 'join', name: 'E', code: wa.code, version: VERSION }, 'ROOM_FULL');
  clock.time += 5001; server.tick();
  const wdResume = await connect();
  await requestError(wdResume, { type: 'resume', code: wa.code, token: wd.token, version: VERSION }, 'INVALID_RESUME');
  const we = await hello(e, 'join', { name: 'E', code: wa.code });
  assert.equal(we.state.players.length, 4);
  mark = b.mark(); a.ws.terminate();
  await b.wait(m => m.type === 'snapshot' && m.state.hostId === wb.id, mark);
  await requestError(c, { type: 'start' }, 'NOT_HOST');
  mark = b.mark(); b.send({ type: 'start' }); await b.wait(m => m.type === 'snapshot' && m.state.phase === 'playing', mark);
  await requestError(b, { type: 'load' }, 'NO_CHECKPOINT');
  await move(b, clock, -6, 0);
  await requestError(b, { type: 'interact', target: 'generator', actionId: 1 }, 'PREREQUISITE');
  await move(b, clock, 0, -12);
  clock.time += 300;
  b.send({ type: 'pose', x: 0, z: -13, yaw: 0, crouch: false, sprint: false, flashlight: true, seq: b.seq++ });
  await b.sync(); mark = b.mark(); clock.time += 100; server.tick();
  const blocked = await b.wait(m => m.type === 'snapshot', mark);
  assert.equal(blocked.state.players.find(p => p.id === wb.id).z, -12);
  assert.equal(blocked.state.world.archive, false);
});

test('production timer automatically broadcasts enemy movement to connected peers', async t => {
  const { connect } = await setup(t, { autoTick: true, clock: () => performance.now() });
  const a = await connect(), b = await connect();
  const wa = await hello(a, 'create', { name: 'One' });
  await hello(b, 'join', { name: 'Two', code: wa.code });
  const mark = b.mark(); a.send({ type: 'start' });
  const updated = await b.wait(m => m.type === 'snapshot' && m.state.phase === 'playing' && m.state.monster.x !== 0, mark);
  assert.equal(updated.state.monster.mode, 'patrol');
  assert.equal(updated.state.players.length, 2);
});

test('health, websocket origins and paths, malformed data, versions and rate limiting', async t => {
  const { clock, port, connect } = await setup(t, { allowedOrigins: 'https://game.example' });
  const health = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(health.status, 200); assert.deepEqual(await health.json(), { ok: true, version: VERSION });
  const browserHealth = await fetch(`http://127.0.0.1:${port}/health`, { headers: { Origin: 'https://game.example' } });
  assert.equal(browserHealth.status, 200); assert.equal(browserHealth.headers.get('access-control-allow-origin'), 'https://game.example');
  assert.equal((await fetch(`http://127.0.0.1:${port}/health`, { headers: { Origin: 'https://evil.example' } })).status, 403);
  assert.equal((await fetch(`http://127.0.0.1:${port}/`)).status, 404);
  async function rejected(path, origin, status) {
    const ws = new WebSocket(`ws://127.0.0.1:${port}${path}`, { headers: { Origin: origin } });
    ws.on('error', () => {});
    const [response] = await once(ws, 'unexpected-response').then(([req, res]) => [res]);
    assert.equal(response.statusCode, status); response.resume();
    ws.terminate();
  }
  await rejected('/ws', 'https://evil.example', 403);
  await rejected('/wrong', 'https://game.example', 404);
  const c = await connect('/ws', { Origin: 'https://game.example' });
  await requestError(c, { type: 'create', name: 'A', version: 'wrong' }, 'BAD_VERSION');
  const m = c.mark(); c.send('not json'); await c.wait(x => x.type === 'error' && x.code === 'INVALID_MESSAGE', m);
  await hello(c, 'create', { name: 'A' });
  let mark = c.mark();
  for (let i = 0; i < 130; i++) c.send({ type: 'ping', t: i });
  await c.wait(x => x.type === 'error' && x.code === 'RATE_LIMITED', mark);
  clock.time += 3000; mark = c.mark(); c.send({ type: 'ping', t: 'recovered' });
  await c.wait(x => x.type === 'pong' && x.t === 'recovered', mark);
  mark = c.mark(); c.ws.send(Buffer.from([1, 2, 3]));
  await c.wait(x => x.type === 'error' && x.code === 'INVALID_MESSAGE', mark);
});

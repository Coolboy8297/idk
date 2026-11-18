import http from 'node:http';
import { randomBytes, createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

export const VERSION = 'last-signal-1';
const SPAWN = { x: 0, z: 16 };
const TARGETS = Object.freeze({
  fuse: [-6, 10], generator: [-6, 0], key: [6, -5], archive: [0, -12],
  note1: [5, -17], note2: [-5, -22], note3: [5, -27], exit: [0, -32],
});
const MAX_PLAYERS = 4;
const INTERACT_RANGE = 2.75;
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PATROL = [[0, -24], [6, -26], [5, -18], [-5, -20], [-5, -28]];

const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const secret = (bytes) => randomBytes(bytes).toString('base64url');
const hashToken = (token) => createHash('sha256').update(token).digest('hex');
const nowMonotonic = () => performance.now();

function codeFor(rooms) {
  let code;
  do {
    // Alphabet has 32 characters, so this avoids modulo bias.
    code = Array.from(randomBytes(6), b => ALPHABET[b & 31]).join('');
  } while (rooms.has(code));
  return code;
}

function normalName(value) {
  if (typeof value !== 'string') return null;
  const name = value.replace(/[\u0000-\u001f\u007f-\u009f]/g, '').trim();
  return name.length > 0 && name.length <= 24 ? name : null;
}

function objective(world) {
  if (world.completed) return 'The signal is restored. You escaped.';
  if (!world.fuse) return 'Find the fuse in reception.';
  if (!world.generator) return 'Insert the fuse into the generator.';
  if (!world.key) return 'Find the archive key.';
  if (!world.archive) return 'Unlock the archive.';
  const count = world.notes.filter(Boolean).length;
  if (count < 3) return `Collect the recordings (${count}/3).`;
  return 'Reach the exit.';
}

function publicState(room) {
  return {
    revision: room.revision,
    phase: room.phase,
    hostId: room.hostId,
    players: [...room.players.values()].map(p => ({
      id: p.id, name: p.name, x: p.x, z: p.z, yaw: p.yaw,
      crouch: p.crouch, sprint: p.sprint, flashlight: p.flashlight,
      connected: p.connected,
    })),
    monster: { x: room.monster.x, z: room.monster.z, yaw: room.monster.yaw, mode: room.monster.mode },
    world: { ...room.world, notes: [...room.world.notes] },
    objective: objective(room.world),
    checkpoint: !!room.checkpoint,
  };
}

function send(ws, object) {
  if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(object));
}
function fail(ws, code, message) { send(ws, { type: 'error', code, message }); }
function broadcast(room, object) {
  for (const p of room.players.values()) if (p.connected) send(p.ws, object);
}
function snapshot(room) { broadcast(room, { type: 'snapshot', state: publicState(room) }); }
function event(room, name, message) { broadcast(room, { type: 'event', name, message }); }
function bump(room) { room.revision += 1; }
function welcome(ws, room, player) {
  send(ws, { type: 'welcome', id: player.id, token: player.token, code: room.code, hostId: room.hostId, state: publicState(room) });
}

function newRoom(code, time) {
  return {
    code, revision: 0, phase: 'lobby', hostId: null, players: new Map(), lastTick: time,
    world: { fuse: false, generator: false, key: false, archive: false, notes: [false, false, false], exit: false, completed: false },
    monster: { x: 0, z: -24, yaw: 0, mode: 'patrol', waypoint: 1, target: null, searchUntil: 0, nextSearchPoint: 0 },
    checkpoint: null,
  };
}
function newPlayer(name, ws, time) {
  return {
    id: secret(9), token: secret(32), name, ws, connected: true,
    x: SPAWN.x, z: SPAWN.z, yaw: 0, crouch: false, sprint: false, flashlight: true,
    lastSeq: -1, budget: 0.6, budgetAt: time, lastMovementAt: -Infinity,
    protectedUntil: 0, disconnectedAt: null, actions: new Map(),
  };
}
function migrateHost(room) {
  const old = room.hostId;
  if (!room.players.get(old)?.connected) {
    room.hostId = [...room.players.values()].find(p => p.connected)?.id ?? null;
  }
  return room.hostId !== old;
}

// The only global barrier represented in the contract is the archive threshold.
function sameSideOfLockedArchive(room, a, b) {
  return room.world.archive || (a.z >= -12) === (b.z >= -12);
}
function moveMonster(room, target, speed, dt) {
  const m = room.monster;
  const dx = target.x - m.x, dz = target.z - m.z;
  const d = Math.hypot(dx, dz);
  if (d < 0.0001) return true;
  const step = Math.min(d, speed * dt);
  m.x = clamp(m.x + dx / d * step, -9, 9);
  m.z = clamp(m.z + dz / d * step, -34, 20);
  if (!room.world.archive) m.z = Math.min(m.z, -12.01);
  m.yaw = Math.atan2(dx, dz);
  return d <= speed * dt + 0.05;
}
function updateMonster(room, time, dt) {
  const m = room.monster;
  const candidates = [...room.players.values()].filter(p => p.connected && time >= p.protectedUntil && sameSideOfLockedArchive(room, m, p));
  // Line of sight is unobstructed within each side of the only shared barrier.
  const visible = candidates.filter(p => distance(m, p) <= (p.crouch ? 5.5 : p.flashlight ? 11 : 8))
    .sort((a, b) => distance(m, a) - distance(m, b))[0];
  const audible = candidates.filter(p => time - p.lastMovementAt < 1200 && distance(m, p) <= (p.crouch ? 3 : p.sprint ? 15 : 8))
    .sort((a, b) => distance(m, a) - distance(m, b))[0];
  if (visible) {
    m.mode = 'chase';
    m.target = { x: visible.x, z: visible.z };
  } else if (m.mode === 'chase') {
    m.mode = 'investigate';
  } else if (audible && m.mode !== 'investigate') {
    m.mode = 'investigate';
    m.target = { x: audible.x, z: audible.z };
  } else if (audible && m.mode === 'investigate') {
    m.target = { x: audible.x, z: audible.z };
  }

  if (m.mode === 'chase') moveMonster(room, m.target, 3.2, dt);
  else if (m.mode === 'investigate') {
    if (!m.target || moveMonster(room, m.target, 2.0, dt)) {
      m.mode = 'search'; m.searchUntil = time + 6000; m.nextSearchPoint = 0;
      m.target = { x: m.x, z: m.z };
    }
  } else if (m.mode === 'search') {
    if (time >= m.searchUntil) { m.mode = 'patrol'; m.target = null; }
    else {
      if (!m.nextSearchPoint || time >= m.nextSearchPoint) {
        const sign = Math.floor(time / 1400) % 2 ? 1 : -1;
        m.target = { x: clamp(m.x + sign * 1.5, -8.5, 8.5), z: clamp(m.z + 0.5, -33.5, -12.1) };
        m.nextSearchPoint = time + 1400;
      }
      moveMonster(room, m.target, 1.1, dt);
    }
  }
  if (m.mode === 'patrol') {
    const [x, z] = PATROL[m.waypoint];
    if (moveMonster(room, { x, z }, 1.15, dt)) m.waypoint = (m.waypoint + 1) % PATROL.length;
  }

  for (const p of candidates) {
    if (distance(m, p) <= 1.1) {
      p.x = SPAWN.x; p.z = SPAWN.z; p.budget = 0.6; p.budgetAt = time;
      p.lastMovementAt = -Infinity; p.protectedUntil = time + 6000;
      event(room, 'caught', `${p.name} was caught and returned to reception. Shared progress is safe.`);
      if (m.mode === 'chase') { m.mode = 'search'; m.searchUntil = time + 6000; m.nextSearchPoint = 0; }
    }
  }
}

function parseAllowedOrigins(value) {
  if (!value) return null;
  return new Set(value.split(',').map(s => s.trim()).filter(Boolean));
}
function originAllowed(origin, configured) {
  // Non-browser clients do not normally send Origin. This is not authentication.
  if (!origin) return true;
  if (configured) return configured.has('*') || configured.has(origin);
  try {
    const u = new URL(origin);
    return (u.protocol === 'http:' || u.protocol === 'https:') &&
      ['localhost', '127.0.0.1', '[::1]'].includes(u.hostname) && u.origin === origin;
  } catch { return false; }
}

/** Construct a server. Options clock/autoTick exist to make integration tests deterministic. */
export function createGameServer(options = {}) {
  const clock = options.clock ?? nowMonotonic;
  const graceMs = options.graceMs ?? 60_000;
  const allowedOrigins = parseAllowedOrigins(options.allowedOrigins ?? process.env.ALLOWED_ORIGINS ?? '');
  const rooms = new Map();
  const httpServer = http.createServer((req, res) => {
    let path = '';
    try { path = new URL(req.url, 'http://local').pathname; } catch { /* Invalid request target. */ }
    if (req.method === 'GET' && path === '/health') {
      const origin = req.headers.origin;
      if (origin && !originAllowed(origin, allowedOrigins)) {
        res.writeHead(403, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
        res.end(JSON.stringify({ ok: false, error: 'origin not allowed' }));
        return;
      }
      if (origin) res.setHeader('access-control-allow-origin', origin);
      res.setHeader('vary', 'Origin');
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      res.end(JSON.stringify({ ok: true, version: VERSION }));
    } else {
      res.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ error: 'not found' }));
    }
  });
  const wss = new WebSocketServer({ noServer: true, maxPayload: 4096, perMessageDeflate: false });
  httpServer.on('upgrade', (req, socket, head) => {
    let path;
    try { path = new URL(req.url, 'http://local').pathname; } catch { path = ''; }
    if (path !== '/ws' || !originAllowed(req.headers.origin, allowedOrigins)) {
      socket.write(`HTTP/1.1 ${path !== '/ws' ? '404 Not Found' : '403 Forbidden'}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req));
  });

  function cleanAndTick() {
    const time = clock();
    for (const [code, room] of rooms) {
      let changed = false;
      for (const [id, p] of room.players) {
        if (!p.connected && time - p.disconnectedAt >= graceMs) {
          room.players.delete(id); changed = true;
        }
      }
      if (room.players.size === 0) { rooms.delete(code); continue; }
      if (migrateHost(room)) changed = true;
      if (room.phase === 'playing') {
        const dt = clamp((time - room.lastTick) / 1000, 0, 0.25);
        if (dt > 0) { updateMonster(room, time, dt); changed = true; }
      }
      room.lastTick = time;
      if (changed) { bump(room); snapshot(room); }
    }
  }

  wss.on('connection', ws => {
    const connection = { room: null, player: null, tokens: 120, tokenAt: clock(), lastRateError: -Infinity, rateStrikes: 0 };
    const authTimer = setTimeout(() => { if (!connection.player) ws.close(1008, 'Join a room first'); }, 15_000);
    authTimer.unref();
    ws.on('error', () => {});

    function admit(room, player) {
      connection.room = room; connection.player = player;
      clearTimeout(authTimer);
      bump(room); welcome(ws, room, player); snapshot(room);
    }
    ws.on('message', (data, isBinary) => {
      const time = clock();
      connection.tokens = Math.min(120, connection.tokens + Math.max(0, time - connection.tokenAt) * 0.06);
      connection.tokenAt = time;
      if (connection.tokens < 1) {
        if (time - connection.lastRateError >= 1000) { fail(ws, 'RATE_LIMITED', 'Too many messages; slow down.'); connection.lastRateError = time; }
        if (++connection.rateStrikes > 200) ws.close(1008, 'Rate limit exceeded');
        return;
      }
      connection.tokens -= 1;
      connection.rateStrikes = Math.max(0, connection.rateStrikes - 1);
      let msg;
      try { if (isBinary) throw new Error(); msg = JSON.parse(data.toString()); } catch { fail(ws, 'INVALID_MESSAGE', 'Send a valid JSON object.'); return; }
      if (!msg || typeof msg !== 'object' || Array.isArray(msg) || typeof msg.type !== 'string' || msg.type.length > 32) {
        fail(ws, 'INVALID_MESSAGE', 'Send a valid JSON message with a type.'); return;
      }
      if (msg.type === 'ping') {
        if (msg.t !== undefined && !['number', 'string'].includes(typeof msg.t)) { fail(ws, 'INVALID_MESSAGE', 'Invalid ping timestamp.'); return; }
        if (typeof msg.t === 'string' && msg.t.length > 128) { fail(ws, 'INVALID_MESSAGE', 'Invalid ping timestamp.'); return; }
        send(ws, { type: 'pong', t: msg.t }); return;
      }
      if (['create', 'join', 'resume'].includes(msg.type)) {
        if (connection.player) { fail(ws, 'ALREADY_JOINED', 'Already in a room.'); return; }
        if (msg.version !== VERSION) { fail(ws, 'BAD_VERSION', 'Game and server versions do not match.'); return; }
        if (msg.type === 'create') {
          const name = normalName(msg.name);
          if (!name) { fail(ws, 'INVALID_NAME', 'Name must be between 1 and 24 characters.'); return; }
          const room = newRoom(codeFor(rooms), time), player = newPlayer(name, ws, time);
          room.players.set(player.id, player); room.hostId = player.id; rooms.set(room.code, room);
          admit(room, player); return;
        }
        const code = typeof msg.code === 'string' ? msg.code.trim().toUpperCase() : '';
        if (!/^[A-Z2-9]{6}$/.test(code)) { fail(ws, 'ROOM_NOT_FOUND', 'Room not found. Check the invitation code.'); return; }
        const room = rooms.get(code);
        if (!room) { fail(ws, 'ROOM_NOT_FOUND', 'Room not found. Check the invitation code.'); return; }
        if (msg.type === 'join') {
          const name = normalName(msg.name);
          if (!name) { fail(ws, 'INVALID_NAME', 'Name must be between 1 and 24 characters.'); return; }
          if (room.phase === 'won') { fail(ws, 'GAME_OVER', 'This game has already ended.'); return; }
          if (room.players.size >= MAX_PLAYERS) { fail(ws, 'ROOM_FULL', 'This room is full, including reserved reconnecting players.'); return; }
          const player = newPlayer(name, ws, time);
          room.players.set(player.id, player);
          if (!room.hostId) room.hostId = player.id;
          admit(room, player); event(room, 'joined', `${player.name} joined the room.`); return;
        }
        if (typeof msg.token !== 'string' || msg.token.length < 30 || msg.token.length > 128) { fail(ws, 'INVALID_RESUME', 'Session expired or invalid.'); return; }
        const tokenHash = hashToken(msg.token);
        const player = [...room.players.values()].find(p => hashToken(p.token) === tokenHash);
        if (!player || (!player.connected && time - player.disconnectedAt >= graceMs)) {
          fail(ws, 'INVALID_RESUME', 'Session expired or invalid.'); return;
        }
        // A valid token may replace a connection which has not detected a network break yet.
        const oldWs = player.ws;
        player.ws = ws; player.connected = true; player.disconnectedAt = null; player.lastSeq = -1;
        player.budgetAt = time; player.budget = 0.6;
        if (oldWs && oldWs !== ws && oldWs.readyState === WebSocket.OPEN) oldWs.close(4001, 'Session resumed elsewhere');
        if (!room.hostId) room.hostId = player.id;
        admit(room, player); event(room, 'reconnected', `${player.name} reconnected.`); return;
      }
      const room = connection.room, p = connection.player;
      if (!room || !p || p.ws !== ws || !p.connected) { fail(ws, 'NOT_IN_ROOM', 'Create, join, or resume a room first.'); return; }
      if (msg.type === 'start') {
        if (room.hostId !== p.id) { fail(ws, 'NOT_HOST', 'Only the current host can start the game.'); return; }
        if (room.phase !== 'lobby') { fail(ws, 'WRONG_PHASE', 'The game has already started.'); return; }
        room.phase = 'playing'; room.lastTick = time;
        for (const player of room.players.values()) { player.budget = 0.6; player.budgetAt = time; }
        bump(room); snapshot(room); event(room, 'started', 'The game has started. Find the fuse.'); return;
      }
      if (msg.type === 'save' || msg.type === 'load') {
        if (room.hostId !== p.id) { fail(ws, 'NOT_HOST', 'Only the current host can save or load.'); return; }
        if (msg.type === 'save') {
          if (room.phase !== 'playing') { fail(ws, 'WRONG_PHASE', 'A checkpoint can only be saved during play.'); return; }
          room.checkpoint = {
            world: { ...room.world, notes: [...room.world.notes] },
            monster: { ...room.monster, target: room.monster.target ? { ...room.monster.target } : null,
              searchRemaining: Math.max(0, room.monster.searchUntil - time), nextSearchRemaining: Math.max(0, room.monster.nextSearchPoint - time) },
          };
          bump(room); snapshot(room);
          event(room, 'saved', 'Checkpoint saved for this room until the server or room closes.'); return;
        }
        if (!room.checkpoint) { fail(ws, 'NO_CHECKPOINT', 'No room checkpoint has been saved.'); return; }
        const saved = room.checkpoint;
        room.world = { ...saved.world, notes: [...saved.world.notes] };
        room.monster = { ...saved.monster, target: saved.monster.target ? { ...saved.monster.target } : null,
          searchUntil: time + saved.monster.searchRemaining, nextSearchPoint: time + saved.monster.nextSearchRemaining };
        delete room.monster.searchRemaining; delete room.monster.nextSearchRemaining;
        room.phase = 'playing'; room.lastTick = time;
        // Reposition everyone on the safe side so a restored lock cannot trap players.
        for (const player of room.players.values()) {
          player.x = SPAWN.x; player.z = SPAWN.z; player.budget = 0.6; player.budgetAt = time;
          player.lastMovementAt = -Infinity; player.protectedUntil = time + 3000;
          player.actions.clear();
        }
        bump(room); snapshot(room); event(room, 'loaded', 'Checkpoint restored. Players returned to reception.'); return;
      }
      if (msg.type === 'pose') {
        if (room.phase !== 'playing') { fail(ws, 'WRONG_PHASE', 'Movement is only accepted during play.'); return; }
        if (![msg.x, msg.z, msg.yaw].every(Number.isFinite) || !Number.isSafeInteger(msg.seq) || msg.seq < 0 ||
            typeof msg.crouch !== 'boolean' || typeof msg.sprint !== 'boolean' || typeof msg.flashlight !== 'boolean') {
          fail(ws, 'INVALID_POSE', 'Invalid movement data.'); return;
        }
        if (msg.seq <= p.lastSeq) return;
        let x = clamp(msg.x, -9, 9), z = clamp(msg.z, -34, 20);
        if (!room.world.archive && p.z >= -12) z = Math.max(z, -12);
        const moved = Math.hypot(x - p.x, z - p.z);
        p.budget = Math.min(2.5, p.budget + Math.max(0, time - p.budgetAt) * 0.008);
        p.budgetAt = time;
        if (moved > p.budget + 0.05) {
          p.lastSeq = msg.seq; fail(ws, 'INVALID_POSE', 'Movement was too fast; position corrected.');
          send(ws, { type: 'snapshot', state: publicState(room) }); return;
        }
        p.budget = Math.max(0, p.budget - moved);
        if (moved > 0.015) p.lastMovementAt = time;
        p.x = x; p.z = z; p.yaw = Math.atan2(Math.sin(msg.yaw), Math.cos(msg.yaw));
        p.crouch = msg.crouch; p.sprint = msg.sprint; p.flashlight = msg.flashlight; p.lastSeq = msg.seq;
        bump(room); return;
      }
      if (msg.type === 'interact') {
        if (room.phase !== 'playing') { fail(ws, 'WRONG_PHASE', 'Interactions are only available during play.'); return; }
        const target = msg.target;
        if (typeof target !== 'string' || !Object.hasOwn(TARGETS, target)) { fail(ws, 'INVALID_TARGET', 'Unknown interaction target.'); return; }
        const validAction = (typeof msg.actionId === 'string' && msg.actionId.length > 0 && msg.actionId.length <= 128) ||
          (Number.isSafeInteger(msg.actionId) && msg.actionId >= 0);
        if (!validAction) { fail(ws, 'INVALID_MESSAGE', 'An actionId is required.'); return; }
        const actionKey = `${typeof msg.actionId}:${msg.actionId}`;
        if (p.actions.has(actionKey)) return;
        const [tx, tz] = TARGETS[target];
        if (Math.hypot(p.x - tx, p.z - tz) > INTERACT_RANGE) { fail(ws, 'TOO_FAR', 'Move closer to interact.'); return; }
        const w = room.world;
        let already = false, required = null, message = '';
        switch (target) {
          case 'fuse': already = w.fuse; if (!already) { w.fuse = true; message = 'Fuse recovered.'; } break;
          case 'generator': already = w.generator; required = w.fuse ? null : 'Find the fuse first.'; if (!already && !required) { w.generator = true; message = 'Power restored.'; } break;
          case 'key': already = w.key; required = w.generator ? null : 'Restore power first.'; if (!already && !required) { w.key = true; message = 'Archive key recovered.'; } break;
          case 'archive': already = w.archive; required = w.key ? null : 'Find the archive key first.'; if (!already && !required) { w.archive = true; message = 'Archive unlocked.'; } break;
          case 'note1': case 'note2': case 'note3': {
            const index = Number(target.at(-1)) - 1; already = w.notes[index]; required = w.archive ? null : 'Unlock the archive first.';
            const fragments = [
              'Recording 01: We did not lose the signal. The signal learned our names.',
              'Recording 02: Keep the lights on. It follows footsteps through the archive.',
              'Recording 03: Take the evidence outside. Do not answer if it calls you back.',
            ];
            if (!already && !required) { w.notes[index] = true; message = fragments[index]; } break;
          }
          case 'exit': already = w.completed; required = w.notes.every(Boolean) ? null : 'Find all three recordings first.';
            if (!already && !required) { w.exit = true; w.completed = true; room.phase = 'won'; message = 'All recordings secured. You escaped.'; } break;
        }
        if (required && !already) { fail(ws, 'PREREQUISITE', required); return; }
        p.actions.set(actionKey, true); if (p.actions.size > 256) p.actions.delete(p.actions.keys().next().value);
        if (!already) { bump(room); snapshot(room); event(room, target === 'exit' ? 'won' : 'progress', message); }
        return;
      }
      fail(ws, 'UNKNOWN_TYPE', 'Unknown message type.');
    });
    ws.on('close', () => {
      clearTimeout(authTimer);
      const room = connection.room, p = connection.player;
      if (!room || !p || p.ws !== ws || !p.connected) return;
      p.connected = false; p.ws = null; p.disconnectedAt = clock();
      const migrated = migrateHost(room);
      bump(room); snapshot(room);
      event(room, 'disconnected', `${p.name} disconnected. Their slot is reserved for reconnection.`);
      if (migrated && room.hostId) event(room, 'host_changed', 'The host left; another player is now host.');
    });
  });

  const tickTimer = options.autoTick === false ? null : setInterval(cleanAndTick, 100);
  tickTimer?.unref();
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      // ws-level heartbeat does not depend on game or app messages.
      if (ws._lastHeartbeatAlive === false) { ws.terminate(); continue; }
      ws._lastHeartbeatAlive = false;
      ws.once('pong', () => { ws._lastHeartbeatAlive = true; });
      if (ws.readyState === WebSocket.OPEN) ws.ping();
    }
  }, 25_000);
  heartbeat.unref();

  async function close() {
    clearInterval(tickTimer); clearInterval(heartbeat);
    for (const ws of wss.clients) ws.terminate();
    await new Promise(resolve => wss.close(() => resolve()));
    if (httpServer.listening) await new Promise(resolve => httpServer.close(() => resolve()));
  }
  return { httpServer, tick: cleanAndTick, close };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT ?? 8787);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    console.error('PORT must be an integer between 0 and 65535.'); process.exit(1);
  }
  const game = createGameServer();
  game.httpServer.listen(port, '0.0.0.0', () => console.log(`The Last Signal server listening on port ${game.httpServer.address().port}`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, async () => { await game.close(); process.exit(0); });
}

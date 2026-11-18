// Offline counterpart to the authoritative room server. Only the real local
// player is represented; the guardian and world are simulated in this tab.
const CHECKPOINT_KEY = 'last-signal-solo-checkpoint-v1';
const CHECKPOINT_VERSION = 1;
const PLAYER_ID = 'solo-player';
const SPAWN = { x: 0, z: 16 };
const INTERACT_RANGE = 2.75;
const TARGETS = Object.freeze({
  fuse: [-6, 10], generator: [-6, 0], key: [6, -5], archive: [0, -12],
  note1: [5, -17], note2: [-5, -22], note3: [5, -27], exit: [0, -32],
});
const PATROL = [[0, -24], [6, -26], [5, -18], [-5, -20], [-5, -28]];
const RECORDINGS = [
  'Recording 01: We did not lose the signal. The signal learned our names.',
  'Recording 02: Keep the lights on. It follows footsteps through the archive.',
  'Recording 03: Take the evidence outside. Do not answer if it calls you back.',
];
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const now = () => globalThis.performance?.now?.() ?? Date.now();

function newWorld() {
  return { fuse: false, generator: false, key: false, archive: false,
    notes: [false, false, false], exit: false, completed: false };
}
function newMonster() {
  return { x: 0, z: -24, yaw: 0, mode: 'patrol', waypoint: 1,
    target: null, searchUntil: 0, nextSearchPoint: 0 };
}
function normalName(value) {
  const name = typeof value === 'string' ? value.replace(/[\u0000-\u001f\u007f-\u009f]/g, '').trim().slice(0, 24) : '';
  return name || 'Explorer';
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
function cloneWorld(world) {
  return { fuse: world.fuse, generator: world.generator, key: world.key, archive: world.archive,
    notes: [...world.notes], exit: world.exit, completed: world.completed };
}

// The storage format is deliberately versioned and checked before it can
// affect the playable world. A malformed/old record is never silently deleted.
function validCheckpoint(saved) {
  if (!saved || typeof saved !== 'object' || saved.version !== CHECKPOINT_VERSION ||
      typeof saved.name !== 'string' || !saved.name || normalName(saved.name) !== saved.name) return false;
  const w = saved.world, m = saved.monster;
  if (!w || typeof w !== 'object' || !m || typeof m !== 'object') return false;
  if (!['fuse', 'generator', 'key', 'archive', 'exit', 'completed'].every(key => typeof w[key] === 'boolean') ||
      !Array.isArray(w.notes) || w.notes.length !== 3 || !w.notes.every(n => typeof n === 'boolean')) return false;
  // Only an in-progress game can be saved. Verify the progression chain too.
  if (w.exit || w.completed || (w.generator && !w.fuse) || (w.key && !w.generator) ||
      (w.archive && !w.key) || (w.notes.some(Boolean) && !w.archive)) return false;
  if (![m.x, m.z, m.yaw, m.searchRemaining, m.nextSearchRemaining].every(Number.isFinite) ||
      m.x < -9 || m.x > 9 || m.z < -34 || m.z > 20 ||
      m.searchRemaining < 0 || m.searchRemaining > 6000 ||
      m.nextSearchRemaining < 0 || m.nextSearchRemaining > 1400 ||
      !Number.isInteger(m.waypoint) || m.waypoint < 0 || m.waypoint >= PATROL.length ||
      !['patrol', 'investigate', 'search', 'chase'].includes(m.mode)) return false;
  if (!w.archive && m.z > -12) return false;
  if (m.target !== null && (!m.target || typeof m.target !== 'object' ||
      !Number.isFinite(m.target.x) || !Number.isFinite(m.target.z) ||
      m.target.x < -9 || m.target.x > 9 || m.target.z < -34 || m.target.z > 20)) return false;
  return true;
}
function storage() {
  const store = globalThis.localStorage;
  if (!store || typeof store.getItem !== 'function' || typeof store.setItem !== 'function') {
    throw new Error('Browser storage is unavailable.');
  }
  return store;
}
function readCheckpoint() {
  const raw = storage().getItem(CHECKPOINT_KEY);
  if (!raw) return null;
  try {
    const saved = JSON.parse(raw);
    return validCheckpoint(saved) ? saved : null;
  } catch { return null; }
}
function saveRecord(room, time) {
  const m = room.monster;
  return {
    version: CHECKPOINT_VERSION,
    name: room.player.name,
    world: cloneWorld(room.world),
    monster: {
      x: m.x, z: m.z, yaw: m.yaw, mode: m.mode, waypoint: m.waypoint,
      target: m.target ? { ...m.target } : null,
      searchRemaining: Math.max(0, m.searchUntil - time),
      nextSearchRemaining: Math.max(0, m.nextSearchPoint - time),
    },
  };
}
function restoreRecord(room, saved, time) {
  room.world = cloneWorld(saved.world);
  const m = saved.monster;
  room.monster = {
    x: m.x, z: m.z, yaw: m.yaw, mode: m.mode, waypoint: m.waypoint,
    target: m.target ? { ...m.target } : null,
    searchUntil: time + m.searchRemaining, nextSearchPoint: time + m.nextSearchRemaining,
  };
  room.phase = 'playing';
  room.lastTick = time;
  const p = room.player;
  p.x = SPAWN.x; p.z = SPAWN.z; p.budget = 0.6; p.budgetAt = time;
  p.lastMovementAt = -Infinity; p.protectedUntil = time + 3000; p.actions.clear();
}
function publicState(room) {
  const p = room.player, m = room.monster;
  return {
    revision: room.revision,
    phase: room.phase,
    hostId: PLAYER_ID,
    players: [{ id: p.id, name: p.name, x: p.x, z: p.z, yaw: p.yaw,
      crouch: p.crouch, sprint: p.sprint, flashlight: p.flashlight, connected: true }],
    monster: { x: m.x, z: m.z, yaw: m.yaw, mode: m.mode },
    world: cloneWorld(room.world),
    objective: objective(room.world),
    checkpoint: room.checkpoint,
  };
}

export class SoloConnection extends EventTarget {
  constructor() {
    super();
    this.closed = true;
    this.room = null;
    this.timer = null;
    this.paused = false;
    this.pausedAt = 0;
  }
  static hasSavedCheckpoint() {
    try { return !!readCheckpoint(); } catch { return false; }
  }
  emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }
  fail(message) { this.emit('error', message); }
  snapshot() { if (!this.closed && this.room) this.emit('snapshot', publicState(this.room)); }
  event(name, message) { if (!this.closed) this.emit('event', { type: 'event', name, message }); }

  connect({ resume = false, name } = {}) {
    this.close();
    let saved = null;
    try { saved = readCheckpoint(); }
    catch (error) {
      if (resume) throw new Error(`Could not read the solo checkpoint: ${error.message || 'browser storage is unavailable.'}`);
    }
    if (resume && !saved) throw new Error('No valid solo checkpoint is available to resume.');
    const time = now();
    const player = {
      id: PLAYER_ID, name: normalName(name || (resume ? saved?.name : '')),
      x: SPAWN.x, z: SPAWN.z, yaw: 0, crouch: false, sprint: false, flashlight: true,
      lastSeq: -1, budget: 0.6, budgetAt: time, lastMovementAt: -Infinity,
      protectedUntil: 0, actions: new Map(),
    };
    const room = {
      revision: 1, phase: 'playing', player, world: newWorld(), monster: newMonster(),
      checkpoint: !!saved, lastTick: time,
    };
    if (resume) restoreRecord(room, saved, time);
    this.room = room;
    this.closed = false;
    this.timer = setInterval(() => this.tick(), 100);
    this.emit('status', 'connected');
    if (this.closed || this.room !== room) return;
    this.emit('welcome', { type: 'welcome', id: PLAYER_ID, token: 'local', code: '', hostId: PLAYER_ID, state: publicState(room) });
    if (this.closed || this.room !== room) return;
    this.snapshot();
  }

  moveMonster(room, target, speed, dt) {
    const m = room.monster;
    const dx = target.x - m.x, dz = target.z - m.z, d = Math.hypot(dx, dz);
    if (d < 0.0001) return true;
    const step = Math.min(d, speed * dt);
    m.x = clamp(m.x + dx / d * step, -9, 9);
    m.z = clamp(m.z + dz / d * step, -34, 20);
    if (!room.world.archive) m.z = Math.min(m.z, -12.01);
    m.yaw = Math.atan2(dx, dz);
    return d <= speed * dt + 0.05;
  }
  updateMonster(room, time, dt) {
    const m = room.monster, p = room.player;
    const candidate = time >= p.protectedUntil && (room.world.archive || (m.z >= -12) === (p.z >= -12));
    const visible = candidate && distance(m, p) <= (p.crouch ? 5.5 : p.flashlight ? 11 : 8);
    const audible = candidate && time - p.lastMovementAt < 1200 && distance(m, p) <= (p.crouch ? 3 : p.sprint ? 15 : 8);
    if (visible) {
      m.mode = 'chase'; m.target = { x: p.x, z: p.z };
    } else if (m.mode === 'chase') {
      m.mode = 'investigate';
    } else if (audible) {
      m.mode = 'investigate'; m.target = { x: p.x, z: p.z };
    }
    if (m.mode === 'chase') this.moveMonster(room, m.target, 3.2, dt);
    else if (m.mode === 'investigate') {
      if (!m.target || this.moveMonster(room, m.target, 2.0, dt)) {
        m.mode = 'search'; m.searchUntil = time + 6000; m.nextSearchPoint = 0;
        m.target = { x: m.x, z: m.z };
      }
    } else if (m.mode === 'search') {
      if (time >= m.searchUntil) { m.mode = 'patrol'; m.target = null; }
      else {
        if (!m.target || !m.nextSearchPoint || time >= m.nextSearchPoint) {
          const sign = Math.floor(time / 1400) % 2 ? 1 : -1;
          m.target = { x: clamp(m.x + sign * 1.5, -8.5, 8.5), z: clamp(m.z + 0.5, -33.5, -12.1) };
          m.nextSearchPoint = time + 1400;
        }
        this.moveMonster(room, m.target, 1.1, dt);
      }
    }
    if (m.mode === 'patrol') {
      const [x, z] = PATROL[m.waypoint];
      if (this.moveMonster(room, { x, z }, 1.15, dt)) m.waypoint = (m.waypoint + 1) % PATROL.length;
    }
    if (candidate && distance(m, p) <= 1.1) {
      p.x = SPAWN.x; p.z = SPAWN.z; p.budget = 0.6; p.budgetAt = time;
      p.lastMovementAt = -Infinity; p.protectedUntil = time + 6000;
      if (m.mode === 'chase') { m.mode = 'search'; m.searchUntil = time + 6000; m.nextSearchPoint = 0; }
      this.event('caught', `${p.name} was caught and returned to reception. Your progress is safe.`);
    }
  }
  tick() {
    const room = this.room;
    if (this.closed || !room || this.paused) return;
    const time = now();
    if (room.phase === 'playing') {
      const dt = clamp((time - room.lastTick) / 1000, 0, 0.25);
      if (dt > 0) {
        this.updateMonster(room, time, dt);
        if (this.closed || this.room !== room) return;
        room.revision += 1;
        this.snapshot();
      }
    }
    room.lastTick = time;
  }
  setPaused(paused) {
    const room = this.room;
    if (this.closed || !room || this.paused === !!paused) return;
    if (paused) {
      this.paused = true;
      this.pausedAt = now();
      if (this.timer !== null) clearInterval(this.timer);
      this.timer = null;
      return;
    }
    const time = now(), elapsed = Math.max(0, time - this.pausedAt);
    const p = room.player, m = room.monster;
    p.budgetAt += elapsed;
    if (Number.isFinite(p.lastMovementAt)) p.lastMovementAt += elapsed;
    if (p.protectedUntil) p.protectedUntil += elapsed;
    if (m.searchUntil) m.searchUntil += elapsed;
    if (m.nextSearchPoint) m.nextSearchPoint += elapsed;
    room.lastTick = time;
    this.paused = false;
    this.pausedAt = 0;
    this.timer = setInterval(() => this.tick(), 100);
  }

  send(message) {
    const room = this.room;
    if (this.closed || !room) return false;
    const p = room.player, time = this.paused ? this.pausedAt : now();
    if (!message || typeof message !== 'object' || Array.isArray(message) ||
        typeof message.type !== 'string' || message.type.length > 32) {
      this.fail('Send a valid JSON message with a type.'); return true;
    }
    if (message.type === 'ping') {
      if ((message.t !== undefined && !['number', 'string'].includes(typeof message.t)) ||
          (typeof message.t === 'string' && message.t.length > 128)) {
        this.fail('Invalid ping timestamp.'); return true;
      }
      this.emit('latency', Math.max(0, Date.now() - Number(message.t || Date.now()))); return true;
    }
    if (message.type === 'start') { this.fail('The game has already started.'); return true; }
    if (message.type === 'save') {
      if (room.phase !== 'playing') { this.fail('A checkpoint can only be saved during play.'); return true; }
      try {
        const store = storage(), serialized = JSON.stringify(saveRecord(room, time));
        store.setItem(CHECKPOINT_KEY, serialized);
        if (store.getItem(CHECKPOINT_KEY) !== serialized) throw new Error('The checkpoint could not be verified.');
      } catch (error) {
        this.fail(`Could not save the solo checkpoint: ${error.message || 'browser storage is unavailable.'}`); return true;
      }
      room.checkpoint = true; room.revision += 1; this.snapshot();
      if (!this.closed && this.room === room) this.event('saved', 'Checkpoint saved in this browser.');
      return true;
    }
    if (message.type === 'load') {
      let saved;
      try { saved = readCheckpoint(); }
      catch (error) { this.fail(`Could not read the solo checkpoint: ${error.message || 'browser storage is unavailable.'}`); return true; }
      if (!saved) {
        if (room.checkpoint) { room.checkpoint = false; room.revision += 1; this.snapshot(); }
        this.fail('No valid solo checkpoint has been saved.'); return true;
      }
      restoreRecord(room, saved, time); room.checkpoint = true; room.revision += 1; this.snapshot();
      if (!this.closed && this.room === room) this.event('loaded', 'Checkpoint restored. You returned to reception.');
      return true;
    }
    if (message.type === 'pose') {
      if (room.phase !== 'playing') { this.fail('Movement is only accepted during play.'); return true; }
      if (![message.x, message.z, message.yaw].every(Number.isFinite) || !Number.isSafeInteger(message.seq) || message.seq < 0 ||
          typeof message.crouch !== 'boolean' || typeof message.sprint !== 'boolean' || typeof message.flashlight !== 'boolean') {
        this.fail('Invalid movement data.'); return true;
      }
      if (message.seq <= p.lastSeq) return true;
      const x = clamp(message.x, -9, 9);
      let z = clamp(message.z, -34, 20);
      if (!room.world.archive && p.z >= -12) z = Math.max(z, -12);
      const moved = Math.hypot(x - p.x, z - p.z);
      p.budget = Math.min(2.5, p.budget + Math.max(0, time - p.budgetAt) * 0.008);
      p.budgetAt = time;
      if (moved > p.budget + 0.05) {
        p.lastSeq = message.seq; this.fail('Movement was too fast; position corrected.'); this.snapshot(); return true;
      }
      p.budget = Math.max(0, p.budget - moved);
      if (moved > 0.015) p.lastMovementAt = time;
      p.x = x; p.z = z; p.yaw = Math.atan2(Math.sin(message.yaw), Math.cos(message.yaw));
      p.crouch = message.crouch; p.sprint = message.sprint; p.flashlight = message.flashlight; p.lastSeq = message.seq;
      room.revision += 1; return true;
    }
    if (message.type === 'interact') {
      if (room.phase !== 'playing') { this.fail('Interactions are only available during play.'); return true; }
      const target = message.target;
      if (typeof target !== 'string' || !Object.hasOwn(TARGETS, target)) { this.fail('Unknown interaction target.'); return true; }
      const validAction = (typeof message.actionId === 'string' && message.actionId.length > 0 && message.actionId.length <= 128) ||
        (Number.isSafeInteger(message.actionId) && message.actionId >= 0);
      if (!validAction) { this.fail('An actionId is required.'); return true; }
      const actionKey = `${typeof message.actionId}:${message.actionId}`;
      if (p.actions.has(actionKey)) return true;
      const [x, z] = TARGETS[target];
      if (Math.hypot(p.x - x, p.z - z) > INTERACT_RANGE) { this.fail('Move closer to interact.'); return true; }
      const w = room.world;
      let already = false, required = null, text = '';
      switch (target) {
        case 'fuse': already = w.fuse; if (!already) { w.fuse = true; text = 'Fuse recovered.'; } break;
        case 'generator': already = w.generator; required = w.fuse ? null : 'Find the fuse first.';
          if (!already && !required) { w.generator = true; text = 'Power restored.'; } break;
        case 'key': already = w.key; required = w.generator ? null : 'Restore power first.';
          if (!already && !required) { w.key = true; text = 'Archive key recovered.'; } break;
        case 'archive': already = w.archive; required = w.key ? null : 'Find the archive key first.';
          if (!already && !required) { w.archive = true; text = 'Archive unlocked.'; } break;
        case 'note1': case 'note2': case 'note3': {
          const index = Number(target.at(-1)) - 1;
          already = w.notes[index]; required = w.archive ? null : 'Unlock the archive first.';
          if (!already && !required) { w.notes[index] = true; text = RECORDINGS[index]; } break;
        }
        case 'exit': already = w.completed; required = w.notes.every(Boolean) ? null : 'Find all three recordings first.';
          if (!already && !required) { w.exit = true; w.completed = true; room.phase = 'won'; text = 'All recordings secured. You escaped.'; } break;
      }
      if (required && !already) { this.fail(required); return true; }
      p.actions.set(actionKey, true);
      if (p.actions.size > 256) p.actions.delete(p.actions.keys().next().value);
      if (!already) {
        room.revision += 1; this.snapshot();
        if (!this.closed && this.room === room) this.event(target === 'exit' ? 'won' : 'progress', text);
      }
      return true;
    }
    this.fail('Unknown message type.'); return true;
  }
  close() {
    this.closed = true;
    if (this.timer !== null) clearInterval(this.timer);
    this.timer = null;
    this.room = null;
    this.paused = false;
    this.pausedAt = 0;
  }
}

import { createGame } from './engine.js';
import { RoomConnection, readSeat, validateServerUrl } from './network.js';
import { SoloConnection } from './solo.js';
import { loadBackendConfig } from './backend-config.js';
import { waitForBackend } from './wake-monitor.js';
import { Soundscape } from './audio.js';

const $ = id => document.getElementById(id);
const screens = ['menu-screen', 'lobby-screen', 'game-screen', 'end-screen'];
const overlays = ['loading-screen', 'settings-overlay', 'controls-overlay', 'credits-overlay', 'pause-overlay', 'inventory-overlay', 'connection-overlay'];
const multiplayer = new RoomConnection();
const solo = new SoloConnection();
let network = multiplayer, playMode = 'solo';
const sound = new Soundscape();
let game, currentState = null, localId = null, roomCode = '', status = 'disconnected';
let paused = false, activeScreen = 'menu-screen', dialogReturn = null, toastTimer = null, actionNumber = 0;
let settings = { quality: 'medium', resolution: 1, masterVolume: 0.8, mouseSensitivity: 1 };
try { settings = { ...settings, ...JSON.parse(localStorage.getItem('last-signal-settings') || '{}') }; } catch { /* storage unavailable */ }

function announce(message) { $('live-announcement').textContent = message || ''; }
function screen(name) {
  activeScreen = name;
  for (const id of screens) $(id).hidden = id !== name;
}
function hideAllOverlays() { for (const id of overlays) $(id).hidden = true; }
function setError(message, where = activeScreen === 'lobby-screen' ? 'lobby-error' : 'menu-error') {
  const el = $(where); el.textContent = message || ''; el.hidden = !message; announce(message);
}
function flashMessage(message) {
  if (!message) return;
  announce(message); $('hud-objective-detail').textContent = message;
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { $('hud-objective-detail').textContent = ''; }, 4500);
}
function setConnectionState(next) {
  status = next;
  const words = { connected: 'CONNECTED', connecting: 'CONNECTING', reconnecting: 'RECONNECTING', disconnected: 'NOT CONNECTED' };
  if (playMode === 'solo') { words.connected = 'SINGLE PLAYER · OFFLINE'; words.disconnected = 'SINGLE PLAYER · OFFLINE'; }
  for (const prefix of ['menu', 'lobby', 'hud']) {
    const wrapper = $(`${prefix}-connection-status`) || $('hud-network-status');
    const label = $(`${prefix}-connection-text`) || $('hud-network-text');
    if (!wrapper || !label) continue;
    wrapper.classList.remove('is-connected', 'is-connecting', 'is-error');
    if (next === 'connected') wrapper.classList.add('is-connected');
    else if (next === 'connecting' || next === 'reconnecting') wrapper.classList.add('is-connecting');
    else if (playMode !== 'solo') wrapper.classList.add('is-error');
    label.textContent = words[next] || next.toUpperCase();
  }
  if (next === 'reconnecting' && activeScreen !== 'menu-screen' && activeScreen !== 'end-screen') {
    game?.stop();
    $('loading-screen').hidden = true;
    $('connection-title').textContent = 'Signal interrupted.';
    $('connection-message').textContent = 'The connection was interrupted. Attempting to reclaim your room seat.';
    $('connection-overlay').hidden = false;
  }
  if (next === 'connected') $('connection-overlay').hidden = true;
  if (next === 'disconnected') {
    $('loading-screen').hidden = true;
    if (activeScreen === 'game-screen' || activeScreen === 'lobby-screen') {
      game?.stop();
      $('connection-title').textContent = 'Signal lost.';
      $('connection-message').textContent = 'The room could not be restored. Try reconnecting, or return to the menu and join again.';
      $('connection-overlay').hidden = false;
    }
  }
}

function setBattery({ level, flashlight }) {
  const value = Math.round(Math.max(0, Math.min(1, level)) * 100);
  $('hud-battery-fill').style.width = `${value}%`;
  $('hud-battery-value').textContent = `${value}%`;
  $('hud-battery-meter').setAttribute('aria-valuenow', String(value));
  $('hud-flashlight-status').textContent = flashlight ? 'LIGHT ON' : (value === 0 ? 'BATTERY DEPLETED' : 'LIGHT OFF · RECHARGING');
}
try {
  game = createGame({
    canvas: $('game-canvas'),
    onInteract: target => network.send({ type: 'interact', target, actionId: `${Date.now()}-${++actionNumber}` }),
    onPose: pose => { if (status === 'connected') network.send({ type: 'pose', ...pose }); },
    onHint: hint => {
      $('interaction-prompt').hidden = !hint;
      if (hint) { $('interaction-label').textContent = hint.label; $('interaction-detail').textContent = hint.detail || ''; }
    },
    onSound: (name, pan) => sound.cue(name, pan),
    onBattery: setBattery,
  });
} catch (error) {
  setError('Unable to start the 3D renderer. Enable WebGL in your browser or try another device.');
  $('create-room-button').disabled = $('join-room-button').disabled = true;
  if ($('solo-start-button')) $('solo-start-button').disabled = true;
  console.error(error);
}

function applySettings(persist = true) {
  settings = {
    quality: $('graphics-quality').value,
    resolution: Number($('resolution-scale').value),
    masterVolume: Number($('master-volume').value),
    mouseSensitivity: Number($('mouse-sensitivity').value),
  };
  $('master-volume-value').textContent = `${Math.round(settings.masterVolume * 100)}%`;
  $('mouse-sensitivity-value').textContent = `${settings.mouseSensitivity.toFixed(2)}×`;
  game?.setSettings(settings); sound.setVolume(settings.masterVolume);
  if (persist) try { localStorage.setItem('last-signal-settings', JSON.stringify(settings)); } catch { /* storage unavailable */ }
}
for (const [id, key] of [['graphics-quality', 'quality'], ['resolution-scale', 'resolution'], ['master-volume', 'masterVolume'], ['mouse-sensitivity', 'mouseSensitivity']]) {
  const el = $(id); el.value = String(settings[key]); el.addEventListener('input', () => applySettings());
}
applySettings(false);

function refreshResumeButton() {
  const saved = readSeat();
  $('resume-session-button').hidden = !saved;
  if (saved && !$('server-url').value) $('server-url').value = saved.url;
}
function refreshSoloResumeButton() {
  const canResume = SoloConnection.hasSavedCheckpoint();
  $('solo-continue-button').disabled = !canResume;
  $('solo-continue-button').title = canResume ? 'Continue the last saved solo checkpoint' : 'Save a solo checkpoint to continue later';
}
function selectMode(mode) {
  playMode = mode;
  setError('', 'menu-error');
  $('solo-panel').hidden = mode !== 'solo';
  $('multiplayer-panel').hidden = mode !== 'multiplayer';
  for (const [id, value] of [['mode-solo-button', 'solo'], ['mode-multiplayer-button', 'multiplayer']]) {
    $(id).setAttribute('aria-pressed', String(mode === value));
    $(id).classList.toggle('is-active', mode === value);
  }
  setConnectionState('disconnected');
  refreshSoloResumeButton();
}
$('mode-solo-button').addEventListener('click', () => selectMode('solo'));
$('mode-multiplayer-button').addEventListener('click', () => selectMode('multiplayer'));
selectMode('solo');
refreshResumeButton();
loadBackendConfig().then(config => {
  let previous = '';
  try { previous = localStorage.getItem('last-signal-server') || ''; } catch { /* storage unavailable */ }
  if (!$('server-url').value) $('server-url').value = config.websocketUrl || previous || '';
}).catch(() => {});

let connectAttempt = 0;
async function connect(create = false, resume = false) {
  const attempt = ++connectAttempt;
  try {
    if (network !== multiplayer) { network.close(); game?.reset(); network = multiplayer; }
    playMode = 'multiplayer';
    if (!resume) game?.reset();
    const saved = resume ? readSeat() : null;
    const url = validateServerUrl(saved?.url || $('server-url').value);
    const name = $('player-name').value.trim() || 'Explorer';
    const code = $('room-code-input').value.trim().toUpperCase();
    if (!create && !resume && !code) throw new Error('Enter the room code shared by the host.');
    $('server-url').value = url;
    try { localStorage.setItem('last-signal-server', url); } catch { /* storage unavailable */ }
    setError('', 'menu-error'); setError('', 'lobby-error');
    $('create-room-button').disabled = $('join-room-button').disabled = true;
    $('loading-title').textContent = resume ? 'Restoring your signal…' : 'Establishing a signal…';
    $('loading-message').textContent = 'Checking the multiplayer server';
    $('loading-screen').hidden = false;
    sound.unlock();
    await waitForBackend(url, { onWaiting: () => {
      if (attempt !== connectAttempt) return;
      $('loading-title').textContent = 'WAKE UP, DUDE!';
      $('loading-message').textContent = 'The server may be waking from its free-host nap. Keeping this page open while we check again…';
    } });
    if (attempt !== connectAttempt) return;
    $('loading-title').textContent = resume ? 'Restoring your signal…' : 'Establishing a signal…';
    $('loading-message').textContent = 'Server awake. Opening the multiplayer connection.';
    network.connect({ url, name, code, create, resume });
  } catch (error) {
    if (attempt !== connectAttempt) return;
    $('loading-screen').hidden = true; setError(error.message || 'Could not start the connection.', 'menu-error');
  } finally {
    if (attempt === connectAttempt) $('create-room-button').disabled = $('join-room-button').disabled = false;
  }
}
function startSolo(resume = false) {
  try {
    if (network !== solo) network.close(false);
    network = solo; playMode = 'solo';
    game?.reset(); setError('', 'menu-error');
    sound.unlock();
    solo.connect({ resume, name: 'Explorer' });
  } catch (error) {
    setError(error.message || 'Could not start single player.', 'menu-error');
  }
}
$('solo-start-button').addEventListener('click', () => startSolo(false));
$('solo-continue-button').addEventListener('click', () => startSolo(true));
$('create-room-button').addEventListener('click', () => connect(true));
$('join-room-button').addEventListener('click', () => connect(false));
$('resume-session-button').addEventListener('click', () => connect(false, true));
$('room-code-input').addEventListener('input', e => { e.target.value = e.target.value.toUpperCase(); });

for (const transport of [multiplayer, solo]) {
transport.addEventListener('status', event => { if (transport === network) setConnectionState(event.detail); });
transport.addEventListener('welcome', event => {
  if (transport !== network) return;
  const message = event.detail;
  localId = message.id; roomCode = message.code || '';
  $('lobby-room-code').textContent = roomCode;
  $('loading-screen').hidden = true; $('connection-overlay').hidden = true;
  setError('', 'menu-error'); setError('', 'lobby-error');
  refreshResumeButton();
  if (!message.state || message.state.phase === 'lobby') screen('lobby-screen');
});
transport.addEventListener('snapshot', event => {
  if (transport !== network) return;
  currentState = event.detail;
  game?.setSnapshot(currentState, localId);
  $('hud-objective').textContent = currentState.objective || 'Explore the facility.';
  sound.setThreat(currentState.monster?.mode === 'chase');
  updateLobby(currentState); updateInventory(currentState.world || {});
  if (currentState.phase === 'playing') {
    if (activeScreen !== 'game-screen') { screen('game-screen'); paused = false; hideAllOverlays(); }
    if (!paused && status === 'connected') game?.start();
  } else if (currentState.phase === 'won') {
    game?.stop(); paused = false; hideAllOverlays();
    $('end-title').innerHTML = 'The signal<br><em>remains.</em>';
    $('end-message').textContent = 'You secured the recordings and escaped. Whatever happened here will not be forgotten.';
    screen('end-screen');
  } else if (currentState.phase === 'lobby' && activeScreen !== 'lobby-screen') {
    game?.stop(); screen('lobby-screen');
  }
});
transport.addEventListener('event', event => {
  if (transport !== network) return;
  const { name, message } = event.detail;
  if (name === 'caught') sound.cue('alert');
  if (paused && message) document.querySelector('.checkpoint-hint').textContent = message;
  if (activeScreen === 'game-screen') flashMessage(message);
  else if (message) { $('lobby-message').textContent = message; announce(message); }
});
transport.addEventListener('error', event => {
  if (transport !== network) return;
  const message = event.detail || 'The server rejected the request.';
  $('loading-screen').hidden = true;
  if (paused) document.querySelector('.checkpoint-hint').textContent = message;
  if (activeScreen === 'game-screen') flashMessage(message);
  else setError(message);
});
}

function updateLobby(state) {
  const players = Array.isArray(state.players) ? state.players : [];
  const host = state.hostId === localId;
  $('lobby-player-count').textContent = `${players.length} / 4 OPERATORS`;
  const list = $('lobby-player-list'); list.replaceChildren();
  if (!players.length) {
    const item = document.createElement('li'); item.className = 'player-empty'; item.textContent = 'Waiting for connection…'; list.append(item);
  }
  for (const player of players) {
    const item = document.createElement('li');
    const name = document.createElement('span'); name.className = 'player-name'; name.textContent = `${player.name}${player.id === localId ? ' (YOU)' : ''}`;
    const tag = document.createElement('span'); tag.className = 'player-tag';
    tag.textContent = player.connected === false ? 'RECONNECTING' : player.id === state.hostId ? 'HOST' : 'CONNECTED';
    item.append(name, tag); list.append(item);
  }
  $('start-game-button').disabled = !host || state.phase !== 'lobby' || status !== 'connected';
  $('lobby-message').textContent = host ? 'You are the host. Begin when your team is ready.' : 'Waiting for the host to begin.';
  $('pause-save-checkpoint-button').disabled = !host || state.phase !== 'playing';
  $('pause-load-checkpoint-button').disabled = !host || !state.checkpoint;
}
function updateInventory(world) {
  const items = [];
  if (world.fuse && !world.generator) items.push('Generator fuse');
  if (world.generator) items.push('Generator restored');
  if (world.key) items.push('Archive key');
  (world.notes || []).forEach((found, i) => { if (found) items.push(`Recording 0${i + 1}`); });
  const list = $('inventory-list'); list.replaceChildren();
  if (!items.length) { const item = document.createElement('li'); item.className = 'inventory-empty'; item.textContent = 'No items recovered yet.'; list.append(item); }
  for (const text of items) { const item = document.createElement('li'); item.textContent = text; list.append(item); }
}
$('start-game-button').addEventListener('click', () => network.send({ type: 'start' }));
$('copy-room-code-button').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(roomCode); announce('Room code copied.'); }
  catch { announce(`Room code: ${roomCode}`); }
});
function leave() {
  network.close(); game?.stop(); sound.setThreat(false); currentState = null; localId = null; roomCode = ''; paused = false;
  hideAllOverlays(); screen('menu-screen'); setConnectionState('disconnected'); refreshResumeButton(); refreshSoloResumeButton();
}
for (const id of ['leave-room-button', 'pause-leave-button', 'connection-menu-button', 'end-menu-button']) $(id).addEventListener('click', leave);
$('reconnect-button').addEventListener('click', () => connect(false, true));
$('pause-save-checkpoint-button').addEventListener('click', () => network.send({ type: 'save' }));
$('pause-load-checkpoint-button').addEventListener('click', () => network.send({ type: 'load' }));

function openPause() {
  if (activeScreen !== 'game-screen' || currentState?.phase !== 'playing') return;
  paused = true; network.setPaused?.(true); game?.stop();
  document.querySelector('#pause-overlay .dialog-intro').textContent = playMode === 'solo' ? 'Your single-player game is paused.' : 'The facility does not wait for you. Your room remains active.';
  document.querySelector('.checkpoint-hint').textContent = playMode === 'solo' ? 'Solo checkpoints are saved on this device.' : 'Shared checkpoints are managed by the host.';
  $('pause-overlay').hidden = false; $('resume-game-button').focus();
}
function resumeGame() {
  $('pause-overlay').hidden = true; $('inventory-overlay').hidden = true;
  paused = false; network.setPaused?.(false);
  if (status === 'connected' && currentState?.phase === 'playing') game?.start();
}
function openInventory() {
  if (activeScreen !== 'game-screen' || currentState?.phase !== 'playing') return;
  paused = true; network.setPaused?.(true); game?.stop(); $('inventory-overlay').hidden = false; $('inventory-close-button').focus();
}
let hadPointerLock = false;
document.addEventListener('pointerlockchange', () => {
  const locked = document.pointerLockElement === $('game-canvas');
  if (hadPointerLock && !locked && !paused && activeScreen === 'game-screen' && status === 'connected') openPause();
  hadPointerLock = locked;
});
$('hud-pause-button').addEventListener('click', openPause);
$('resume-game-button').addEventListener('click', resumeGame);
$('inventory-button').addEventListener('click', openInventory);
for (const id of ['inventory-close-button', 'inventory-done-button']) $(id).addEventListener('click', resumeGame);
function openDialog(id, fromPause = false) {
  dialogReturn = fromPause ? 'pause-overlay' : null;
  if (fromPause) $('pause-overlay').hidden = true;
  $(id).hidden = false; $(id).querySelector('button, select, input')?.focus();
}
function closeDialog(id) {
  $(id).hidden = true;
  if (dialogReturn) { $(dialogReturn).hidden = false; $('resume-game-button').focus(); dialogReturn = null; }
}
for (const [trigger, dialog, fromPause] of [
  ['menu-settings-button', 'settings-overlay', false], ['pause-settings-button', 'settings-overlay', true],
  ['menu-controls-button', 'controls-overlay', false], ['pause-controls-button', 'controls-overlay', true],
  ['menu-credits-button', 'credits-overlay', false],
]) $(trigger).addEventListener('click', () => openDialog(dialog, fromPause));
for (const [close, dialog] of [
  ['settings-close-button', 'settings-overlay'], ['settings-done-button', 'settings-overlay'],
  ['controls-close-button', 'controls-overlay'], ['controls-done-button', 'controls-overlay'],
  ['credits-close-button', 'credits-overlay'], ['credits-done-button', 'credits-overlay'],
]) $(close).addEventListener('click', () => closeDialog(dialog));
window.addEventListener('keydown', event => {
  if (event.repeat || /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || '')) return;
  if (event.code === 'Escape') {
    for (const id of ['settings-overlay', 'controls-overlay', 'credits-overlay']) if (!$(id).hidden) { closeDialog(id); return; }
    if (!$('inventory-overlay').hidden) { resumeGame(); return; }
    if (!$('pause-overlay').hidden) { resumeGame(); return; }
    if (activeScreen === 'game-screen') openPause();
  }
  if (event.code === 'KeyI' && activeScreen === 'game-screen') {
    if (!$('inventory-overlay').hidden) resumeGame(); else if (!paused) openInventory();
  }
});

// Touch controls use the same movement and action methods as other devices.
const pad = $('touch-move'), knob = $('touch-move-knob');
let movePointer = null, lookPointer = null, lastLook = null;
function movePad(event) {
  const r = pad.getBoundingClientRect(); const radius = Math.min(r.width, r.height) * 0.38;
  let x = (event.clientX - (r.left + r.width / 2)) / radius;
  let y = (event.clientY - (r.top + r.height / 2)) / radius;
  const length = Math.hypot(x, y); if (length > 1) { x /= length; y /= length; }
  knob.style.transform = `translate(${x * radius}px, ${y * radius}px)`; game?.setMove(x, y);
}
pad.addEventListener('pointerdown', event => { event.preventDefault(); movePointer = event.pointerId; pad.setPointerCapture(event.pointerId); movePad(event); });
pad.addEventListener('pointermove', event => { if (event.pointerId === movePointer) movePad(event); });
function releasePad(event) { if (event.pointerId !== movePointer) return; movePointer = null; knob.style.transform = ''; game?.setMove(0, 0); }
pad.addEventListener('pointerup', releasePad); pad.addEventListener('pointercancel', releasePad);
const look = $('touch-look');
look.addEventListener('pointerdown', event => { event.preventDefault(); lookPointer = event.pointerId; lastLook = [event.clientX, event.clientY]; look.setPointerCapture(event.pointerId); });
look.addEventListener('pointermove', event => { if (event.pointerId !== lookPointer || !lastLook) return; game?.setLook(event.clientX - lastLook[0], event.clientY - lastLook[1]); lastLook = [event.clientX, event.clientY]; });
function releaseLook(event) { if (event.pointerId === lookPointer) { lookPointer = null; lastLook = null; } }
look.addEventListener('pointerup', releaseLook); look.addEventListener('pointercancel', releaseLook);
$('touch-interact').addEventListener('click', () => game?.interact());
$('touch-flashlight').addEventListener('click', () => game?.toggleFlashlight());
for (const [id, action] of [['touch-crouch', 'crouch'], ['touch-sprint', 'sprint']]) {
  const button = $(id);
  button.addEventListener('pointerdown', event => { event.preventDefault(); button.setPointerCapture(event.pointerId); game?.setTouchAction(action, true); });
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture']) button.addEventListener(type, () => game?.setTouchAction(action, false));
}
window.addEventListener('pagehide', () => sound.stop());

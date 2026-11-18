const VERSION = 'last-signal-1';
const SESSION_KEY = 'last-signal-seat-v1';

export function validateServerUrl(value, pageProtocol = globalThis.location?.protocol || 'http:') {
  const text = String(value || '').trim();
  if (!text) throw new Error('Enter your separately hosted WebSocket server URL.');
  let url;
  try { url = new URL(text); } catch { throw new Error('Enter a valid WebSocket URL, such as wss://example.com/ws.'); }
  if (!['ws:', 'wss:'].includes(url.protocol) || url.username || url.password || url.hash) {
    throw new Error('Use a ws:// or wss:// URL without credentials or a fragment.');
  }
  if (pageProtocol === 'https:' && url.protocol !== 'wss:') {
    throw new Error('An HTTPS game page requires a secure wss:// server.');
  }
  return url.toString();
}

export function readSeat() {
  try { return JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null'); } catch { return null; }
}
function saveSeat(seat) {
  try { sessionStorage.setItem(SESSION_KEY, JSON.stringify(seat)); } catch { /* private mode */ }
}
export function clearSeat() {
  try { sessionStorage.removeItem(SESSION_KEY); } catch { /* private mode */ }
}

export class RoomConnection extends EventTarget {
  constructor() {
    super();
    this.socket = null;
    this.room = null;
    this.config = null;
    this.closed = true;
    this.attempt = 0;
    this.timer = null;
    this.handshakeTimer = null;
    this.lastRevision = -1;
  }
  emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }
  connect({ url, name, code, create = false, resume = false }) {
    this.close(false);
    this.closed = false;
    const endpoint = validateServerUrl(url);
    const saved = resume ? readSeat() : null;
    if (resume && (!saved || saved.url !== endpoint)) throw new Error('No saved session is available for that server.');
    this.config = { url: endpoint, name: String(name || 'Explorer').trim().slice(0, 24), code: String(code || '').trim().toUpperCase(), create, resume, saved };
    this.room = saved ? { code: saved.code, token: saved.token } : null;
    this.lastRevision = -1;
    this.attempt = 0;
    this.open();
  }
  open() {
    if (this.closed) return;
    this.emit('status', this.attempt ? 'reconnecting' : 'connecting');
    let socket;
    try { socket = new WebSocket(this.config.url); }
    catch (error) { this.emit('error', error.message || 'Unable to connect.'); return; }
    this.socket = socket;
    socket.addEventListener('open', () => {
      if (socket !== this.socket) return;
      const existing = this.room || this.config.saved;
      if (existing?.token) {
        this.send({ type: 'resume', code: existing.code, token: existing.token, version: VERSION });
      } else if (this.config.create) {
        this.send({ type: 'create', name: this.config.name, version: VERSION });
      } else {
        this.send({ type: 'join', code: this.config.code, name: this.config.name, version: VERSION });
      }
      this.handshakeTimer = setTimeout(() => {
        if (socket.readyState === WebSocket.OPEN && !this.room?.id) socket.close();
      }, 10000);
    });
    socket.addEventListener('message', event => {
      if (socket !== this.socket) return;
      let msg;
      try { msg = JSON.parse(event.data); } catch { return; }
      if (!msg || typeof msg.type !== 'string') return;
      if (msg.type === 'welcome') {
        clearTimeout(this.handshakeTimer);
        this.attempt = 0;
        this.room = { id: msg.id, token: msg.token, code: msg.code, hostId: msg.hostId };
        saveSeat({ url: this.config.url, code: msg.code, token: msg.token });
        this.emit('status', 'connected');
        this.emit('welcome', msg);
        if (msg.state) this.receiveState(msg.state);
      } else if (msg.type === 'snapshot' && msg.state) {
        this.receiveState(msg.state);
      } else if (msg.type === 'event') {
        this.emit('event', msg);
      } else if (msg.type === 'error') {
        this.emit('error', msg.message || 'The server rejected the request.');
        if (['INVALID_RESUME', 'ROOM_EXPIRED', 'ROOM_NOT_FOUND'].includes(msg.code)) {
          clearSeat(); this.room = null; this.closed = true; socket.close(); this.emit('status', 'disconnected');
        }
      } else if (msg.type === 'pong') {
        this.emit('latency', Math.max(0, Date.now() - Number(msg.t || Date.now())));
      }
    });
    socket.addEventListener('close', () => {
      clearTimeout(this.handshakeTimer);
      if (socket !== this.socket || this.closed) return;
      if (!this.room?.token) {
        this.emit('status', 'disconnected');
        this.emit('error', 'Could not connect to the server or enter the room. Check the address, room code, and server origin settings.');
        return;
      }
      this.emit('status', 'reconnecting');
      const delay = Math.min(8000, 600 * 2 ** Math.min(this.attempt++, 4));
      this.timer = setTimeout(() => this.open(), delay);
    });
    socket.addEventListener('error', () => { /* close provides an actionable message */ });
  }
  receiveState(state) {
    if (Number.isFinite(state.revision) && state.revision < this.lastRevision) return;
    if (Number.isFinite(state.revision)) this.lastRevision = state.revision;
    this.emit('snapshot', state);
  }
  send(message) {
    if (this.socket?.readyState !== WebSocket.OPEN) return false;
    this.socket.send(JSON.stringify(message));
    return true;
  }
  close(forget = true) {
    this.closed = true;
    clearTimeout(this.timer); clearTimeout(this.handshakeTimer);
    if (this.socket) { const old = this.socket; this.socket = null; old.close(); }
    if (forget) clearSeat();
    this.room = null;
  }
}

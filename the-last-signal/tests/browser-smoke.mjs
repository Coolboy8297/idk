import { chromium } from 'playwright-core';
import assert from 'node:assert/strict';
const base = process.env.CLIENT_URL || 'http://localhost:5173/';
const endpoint = process.env.WS_URL || 'ws://localhost:8787/ws';
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const allErrors = [];
const makeClient = async name => {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage(); const frames = [], responses = [];
  await page.addInitScript(() => {
    const OriginalSocket = window.WebSocket;
    window.WebSocket = class extends OriginalSocket {
      constructor(...args) { super(...args); window.__testSocket = this; }
    };
  });
  page.on('pageerror', err => allErrors.push(`${name}: ${err.message}`));
  page.on('response', response => {
    responses.push({ url: response.url(), status: response.status() });
    if (response.status() >= 400) allErrors.push(`${name}: HTTP ${response.status()} ${response.url()}`);
  });
  page.on('websocket', socket => socket.on('framereceived', event => {
    try { frames.push(JSON.parse(String(event.payload))); } catch {}
  }));
  await page.goto(base, { waitUntil: 'networkidle' });
  await page.locator('#mode-multiplayer-button').click();
  await page.locator('#server-url').fill(endpoint);
  await page.locator('#player-name').fill(name);
  return { context, page, frames, responses, name };
};
const latest = client => client.frames.filter(m => m.type === 'snapshot').at(-1)?.state;
const until = async (fn, label, timeout = 15000) => {
  const start = Date.now(); while (Date.now() - start < timeout) { if (fn()) return; await new Promise(r => setTimeout(r, 100)); }
  throw new Error(`Timed out: ${label}`);
};
try {
  const host = await makeClient('Host'), guest = await makeClient('Guest');
  await host.page.locator('#create-room-button').click();
  await host.page.locator('#lobby-screen').waitFor({ state: 'visible', timeout: 15000 });
  const room = (await host.page.locator('#lobby-room-code').textContent()).trim();
  assert.match(room, /^[A-Z2-9]{6}$/);
  await guest.page.locator('#room-code-input').fill(room);
  await guest.page.locator('#join-room-button').click();
  await guest.page.locator('#lobby-screen').waitFor({ state: 'visible', timeout: 15000 });
  await until(() => latest(host)?.players.length === 2 && latest(guest)?.players.length === 2, 'both real browsers joined');
  await host.page.locator('#start-game-button').click();
  await Promise.all([host.page.locator('#game-screen').waitFor({ state: 'visible' }), guest.page.locator('#game-screen').waitFor({ state: 'visible' })]);
  await until(() => latest(host)?.phase === 'playing' && latest(guest)?.phase === 'playing', 'both browsers started');
  await until(() => host.responses.some(r => r.url.includes('Zombie_PolyPizza.glb') && r.status === 200), 'animated monster model loads', 15000);
  await new Promise(r => setTimeout(r, 1000));
  const hm = latest(host).monster, gm = latest(guest).monster;
  assert.ok(Math.hypot(hm.x - gm.x, hm.z - gm.z) < 2, 'enemy state is shared across browsers');
  const before = latest(host).players.find(p => p.name === 'Host');
  await host.page.keyboard.down('w');
  await until(() => (latest(host)?.players.find(p => p.name === 'Host')?.z ?? 16) < 12.7, 'walk toward reception fuse', 20000);
  await host.page.keyboard.up('w');
  await until(() => (latest(guest)?.players.find(p => p.name === 'Host')?.z ?? before.z) < before.z - 0.4, 'host movement propagated to guest', 15000);
  await host.page.keyboard.down('a');
  await until(() => (latest(host)?.players.find(p => p.name === 'Host')?.x ?? 0) < -4.5, 'walk left to fuse', 20000);
  await host.page.keyboard.up('a');
  await host.page.keyboard.down('w');
  await until(() => (latest(host)?.players.find(p => p.name === 'Host')?.z ?? 16) < 11.8, 'approach fuse', 20000);
  await host.page.keyboard.up('w');
  await host.page.locator('#interaction-prompt').waitFor({ state: 'visible', timeout: 10000 });
  await host.page.keyboard.press('e');
  await until(() => latest(guest)?.world.fuse === true, 'fuse pickup synced to guest', 10000);
  await host.page.screenshot({ path: '/tmp/last-signal-game.png' });
  console.log('two browser clients: room create/join, start, movement, fuse pickup and enemy sync PASS');
  await host.page.locator('#hud-pause-button').click();
  await host.page.locator('#pause-save-checkpoint-button').click();
  await until(() => latest(guest)?.checkpoint === true, 'host checkpoint synced to guest');
  await host.page.waitForFunction(() => !document.querySelector('#pause-load-checkpoint-button').disabled);
  await host.page.locator('#pause-load-checkpoint-button').click();
  await until(() => latest(host)?.players.find(p => p.name === 'Host')?.z === 16, 'checkpoint load restored position');
  console.log('browser host checkpoint save/load PASS');
  await host.page.evaluate(() => window.__testSocket.close(4000, 'test disconnect'));
  await until(() => host.frames.filter(m => m.type === 'welcome').length >= 2, 'browser reconnect received new welcome', 20000);
  const welcomes = host.frames.filter(m => m.type === 'welcome');
  assert.equal(welcomes[0].id, welcomes.at(-1).id);
  console.log('browser reconnection preserves player identity PASS');
  if (allErrors.length) throw new Error(`Browser errors: ${allErrors.join('; ')}`);
  await host.context.close(); await guest.context.close();
  console.log('browser JavaScript errors: none');
} finally { await browser.close(); }

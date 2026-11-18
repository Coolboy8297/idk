import { chromium } from 'playwright-core';
import assert from 'node:assert/strict';
const base = process.env.CLIENT_URL || 'http://localhost:5173/';
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage(); const errors = [];
page.on('pageerror', error => errors.push(error.message));
await page.addInitScript(() => {
  window.__websocketAttempts = 0;
  const OriginalSocket = window.WebSocket;
  window.WebSocket = class CheckedSocket extends OriginalSocket {
    constructor(url, protocols) {
      if (protocols === 'vite-hmr' || (Array.isArray(protocols) && protocols.includes('vite-hmr'))) super(url, protocols);
      else { window.__websocketAttempts++; throw new Error('Single-player must not open a game WebSocket'); }
    }
  };
  const dispatch = EventTarget.prototype.dispatchEvent;
  EventTarget.prototype.dispatchEvent = function(event) {
    if (event.type === 'snapshot' && event.detail?.hostId === 'solo-player') window.__soloState = event.detail;
    return dispatch.call(this, event);
  };
});
try {
  await page.goto(base, { waitUntil: 'networkidle' });
  assert.equal(await page.locator('#solo-panel').isVisible(), true);
  assert.equal(await page.locator('#multiplayer-panel').isVisible(), false);
  assert.equal(await page.locator('#solo-continue-button').isEnabled(), false);
  await page.locator('#solo-start-button').click();
  await page.locator('#game-screen').waitFor({ state: 'visible' });
  assert.match(await page.locator('#hud-network-text').textContent(), /SINGLE PLAYER/i);
  await page.keyboard.down('w');
  await page.waitForFunction(() => window.__soloState?.players?.[0]?.z < 12.7, null, { timeout: 25000 });
  await page.keyboard.up('w');
  await page.keyboard.down('a');
  await page.waitForFunction(() => window.__soloState?.players?.[0]?.x < -4.5, null, { timeout: 25000 });
  await page.keyboard.up('a');
  await page.keyboard.down('w');
  await page.waitForFunction(() => window.__soloState?.players?.[0]?.z < 11.8, null, { timeout: 20000 });
  await page.keyboard.up('w');
  await page.locator('#interaction-prompt').waitFor({ state: 'visible', timeout: 20000 });
  await page.keyboard.press('e');
  await page.waitForFunction(() => /generator/i.test(document.querySelector('#hud-objective').textContent), null, { timeout: 10000 });
  await page.locator('#hud-pause-button').click();
  await page.locator('#pause-save-checkpoint-button').click();
  await page.waitForFunction(() => !document.querySelector('#pause-load-checkpoint-button').disabled, null, { timeout: 10000 });
  await page.locator('#pause-leave-button').click();
  assert.equal(await page.locator('#solo-continue-button').isEnabled(), true);
  await page.reload({ waitUntil: 'networkidle' });
  assert.equal(await page.locator('#solo-continue-button').isEnabled(), true);
  await page.locator('#solo-continue-button').click();
  await page.locator('#game-screen').waitFor({ state: 'visible' });
  await page.waitForFunction(() => /generator/i.test(document.querySelector('#hud-objective').textContent), null, { timeout: 10000 });
  assert.equal(await page.evaluate(() => window.__websocketAttempts), 0);
  assert.deepEqual(errors, []);
  console.log('Solo: start, real objective pickup, save and continue after reload with zero WebSocket connections PASS');
} finally { await browser.close(); }

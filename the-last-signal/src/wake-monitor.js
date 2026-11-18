// Probe the backend only when a player starts a multiplayer connection. This
// wakes an idle free-tier service without background traffic that prevents sleep.
export function healthUrl(websocketUrl) {
  const url = new URL(String(websocketUrl || ''));
  if (!['ws:', 'wss:'].includes(url.protocol) || !url.hostname) {
    throw new Error('Enter a valid WebSocket server URL before checking server status.');
  }
  url.protocol = url.protocol === 'wss:' ? 'https:' : 'http:';
  url.pathname = '/health';
  url.search = '';
  url.hash = '';
  return url.toString();
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

export async function waitForBackend(websocketUrl, {
  timeoutMs = 90_000,
  intervalMs = 5_000,
  requestTimeoutMs = 5_000,
  fetcher = globalThis.fetch,
  sleep = delay,
  now = () => Date.now(),
  onWaiting = () => {},
} = {}) {
  const url = healthUrl(websocketUrl);
  const startedAt = now();
  let attempts = 0;
  while (now() - startedAt <= timeoutMs) {
    try {
      const response = await fetcher(url, {
        mode: 'cors', cache: 'no-store', signal: AbortSignal.timeout(requestTimeoutMs),
      });
      if (response.ok) {
        const body = await response.json();
        if (body?.ok === true) return body;
      }
    } catch { /* asleep, waking, or temporarily unreachable: retry below */ }
    attempts += 1;
    onWaiting({ attempts, url });
    const remaining = timeoutMs - (now() - startedAt);
    if (remaining <= 0) break;
    await sleep(Math.min(intervalMs, remaining));
  }
  throw new Error('The multiplayer server did not wake in time. Check its URL and hosting status, then try again.');
}

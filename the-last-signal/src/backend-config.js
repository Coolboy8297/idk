// Multiplayer configuration is public. Set websocketUrl in public/backend-config.json.
// It is only needed for multiplayer; single-player never opens a WebSocket.
export async function loadBackendConfig(base = import.meta.env.BASE_URL, fetcher = fetch) {
  async function read(file) {
    try {
      const response = await fetcher(`${base}${file}`, { cache: 'no-cache' });
      return response.ok ? await response.json() : null;
    } catch { return null; }
  }
  const current = await read('backend-config.json');
  if (typeof current?.websocketUrl === 'string' && current.websocketUrl.trim()) {
    return { websocketUrl: current.websocketUrl.trim() };
  }
  // Preserve deployments made before this configuration file was introduced.
  const legacy = await read('config.json');
  return { websocketUrl: typeof legacy?.serverUrl === 'string' ? legacy.serverUrl.trim() : '' };
}

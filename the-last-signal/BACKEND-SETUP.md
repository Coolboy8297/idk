# Multiplayer backend configuration

The file to edit for the website's multiplayer backend address is **`public/backend-config.json`**:

```json
{
  "websocketUrl": "wss://your-server.example/ws"
}
```

Replace the example with your own **public WebSocket endpoint**. An empty value is allowed: single-player continues to work, and multiplayer players may enter an endpoint in the menu. Do not put API keys, passwords, resume tokens, or other secrets in this public file.

`src/backend-config.js` loads this file, and `src/network.js` contains the WebSocket client. The independently runnable Node.js WebSocket backend is **`server/index.js`**; its setup and deployment instructions are in `server/README.md`. Its WebSocket path is `/ws` and its HTTP health-check path is `/health`.

For local development over HTTP, an endpoint such as `ws://localhost:8787/ws` works on the same computer. `localhost` does not connect other computers to that server. A game page hosted over HTTPS (including GitHub Pages) must use a secure `wss://` endpoint with a valid TLS certificate. The backend's `ALLOWED_ORIGINS` setting must allow the website's exact origin.

After editing the JSON, rebuild or redeploy the static client so the file is copied to the published site. The previous `public/config.json` is still read as a fallback when the new `websocketUrl` is blank, for compatibility with older deployments. No backend is pre-deployed with this project.

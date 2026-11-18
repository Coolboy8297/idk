# The Last Signal

A small, playable browser-based first-person horror build set in an abandoned signal research facility. Choose **Single Player** to play alone without a game server, or **Multiplayer** to explore with one to four real players. Find a fuse, restore the generator, open the archive, retrieve three recordings and reach the exit while the facility's guardian hunts you. The browser client and authoritative multiplayer server are separate programs; multiplayer rooms do not contain substitute AI players.

This is an early, limited-scope game rather than the requested full professional-quality, multi-level production. It has one connected facility divided into three sectors, with mostly procedural architecture and a stylized licensed enemy model. The environment and animation quality do not yet match the original visual brief.

> **Hosting requirement:** Single-player does not use a WebSocket server. GitHub Pages serves only the static game client; online multiplayer rooms require a separately running WebSocket server. This project includes that server, but **no public server or GitHub Pages site is pre-deployed**. You can run it on your own machine or a provider of your choice. A game served over HTTPS requires a `wss://` (TLS) WebSocket endpoint for multiplayer.

## Requirements

- Node.js 20 or later and npm.
- A browser with WebGL and a keyboard/mouse, touch screen, or supported gamepad.
- For online play outside your local computer: a publicly reachable server with HTTPS/WSS, plus an allowed client origin.

## Run single-player locally

```bash
npm ci
npm run dev
```

Open `http://localhost:5173/`, choose **Single Player**, then **Start New Game**. No multiplayer server or server address is required. After the page and its assets have loaded, the single-player game simulation does not need an internet connection. A later visit still needs the site to be available; this project does not install an offline web app or cache the whole site.

In the pause menu, **Save Checkpoint** saves solo progress in this browser's local storage. **Continue Saved Game** on the main menu restores that checkpoint on the same browser and origin. Clearing browser storage, using another device, or private-browsing restrictions may remove or prevent the save. Starting a new game does not overwrite the saved checkpoint until you choose Save Checkpoint again.

## Run multiplayer locally

1. In one terminal, start the standalone server:

   ```bash
   cd server
   npm ci
   ALLOWED_ORIGINS=http://localhost:5173 PORT=8787 npm start
   ```

2. In another terminal, install and start the client:

   ```bash
   npm ci
   npm run dev
   ```

3. Open `http://localhost:5173/`, choose **Multiplayer**, enter `ws://localhost:8787/ws` as the server address, create a room, and share its code. Open a second browser tab and join the same code to test. Use the same host name in the page URL and the server's origin allowlist. The server and client are separate processes.

`localhost` is only reachable from the same device. Two computers cannot join the same online room using `localhost` unless both connect to an independently reachable server address.

On a free host such as Render, the service may sleep after inactivity. When a player selects multiplayer, the browser checks the server's `/health` endpoint and retries briefly before connecting. If the host is waking, the loading screen says **“WAKE UP, DUDE!”**. This check happens only when multiplayer is started; it does not send background traffic to keep the free server awake. If the server does not become available within about 90 seconds, check the endpoint and hosting dashboard and try again.

## Publish the client on GitHub Pages

For a single-player-only site, skip the WebSocket setup and deploy the static client. To enable multiplayer as well:

1. Deploy the WebSocket server independently with a TLS-enabled public endpoint, for example `wss://game.example.com/ws`; follow [server/README.md](server/README.md). Configure its `ALLOWED_ORIGINS` to include `https://YOUR-USERNAME.github.io`, plus any other exact origin from which players will open the game. An origin is scheme, host and optional port, not a path. The WebSocket URL is public configuration, not a secret.
2. Set the secure multiplayer endpoint in the dedicated file `public/backend-config.json`:

   ```json
   { "websocketUrl": "wss://game.example.com/ws" }
   ```

   Alternatively, players can enter the server address in the game. Do not put private tokens, passwords, or credentials in this public file. `src/backend-config.js` loads the setting; `src/network.js` implements the WebSocket client; `server/index.js` is the standalone WebSocket backend and exposes `/health`. The older `public/config.json` is read as a fallback for existing deployments when `websocketUrl` is blank.
3. Create a GitHub repository containing these files, then push to `main`. In repository **Settings → Pages**, set the source to **GitHub Actions**. The included `.github/workflows/pages.yml` installs dependencies, builds the client, and deploys the `dist/` directory.
4. Visit `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/` after the Actions deployment completes. Relative Vite asset paths are configured so a repository subdirectory works. Open it in two different browser sessions and verify room creation, joining, and movement against the actual WSS server.

GitHub Actions and Pages require access to your own GitHub account; this package does not create the repository or deploy it on your behalf.

## Controls

- **W / A / S / D**: move; mouse: look; click the game view to capture the pointer.
- **Shift**: sprint; **Ctrl**: crouch; **F**: flashlight; **E**: interact.
- **Esc**: pause or release the pointer. Use the in-game controls on touch devices.
- A connected controller can be used where browser Gamepad support is available.

The objectives and shared item progression belong to the room. The WebSocket service runs the shared guardian and sends its state to clients. The client displays a reconnecting state on a dropped connection and attempts to reclaim its seat using a server-issued, tab-scoped token; resume is subject to the server's grace period and room lifetime. Room codes are invitations, not secure accounts.

In multiplayer, the host can save one shared checkpoint from the pause menu and load it while the room remains active. Loading returns everyone to reception and restores the saved world progression. This multiplayer checkpoint is kept in server memory only: it is lost when the room expires or the server restarts. Unlike the solo checkpoint, it is **not a durable save file**.

## Project layout

```text
index.html                  game shell
src/                        Three.js engine, offline solo simulation, wake check, UI, WebSocket client and audio
public/assets/              runtime artwork, models and sound
public/backend-config.json  optional public multiplayer WSS endpoint
src/backend-config.js       reads backend configuration
src/network.js              multiplayer WebSocket client
src/solo.js                 offline single-player simulation
server/                     independently deployable multiplayer service
.github/workflows/pages.yml GitHub Pages deployment
```

Run `npm run build` to generate the static site in `dist/`; a prebuilt copy is also included in the downloadable package for static hosting. Serve it over HTTP rather than opening its `index.html` as a `file://` URL. Run `npm ci` at the root and `npm ci` in `server/` before `npm test`: the tests include real WebSocket clients and require both installations. See `server/README.md` for server-only tests. Do not commit `node_modules`, `dist`, secrets, or private credentials.

## Checks completed

- The production Vite build and automated solo, configuration, and client/server tests passed locally. Tests exercised solo progression, its browser-local checkpoint, and server room isolation, objective progression through the ending, shared enemy state, host migration, checkpoint save/load, and reconnection with actual WebSocket clients.
- Multiplayer startup probes the backend health endpoint on demand; automated tests cover health-probe retries, timeout behavior, and allowed-origin access.
- A desktop Chromium browser started single-player, collected the fuse, saved a checkpoint, reloaded, and continued with the saved objective. No game WebSocket was opened during that flow.
- Two separate desktop Chromium browser contexts created and joined a room, started play, synchronized movement and a fuse pickup, saved/loaded a checkpoint, and recovered the same player identity after a forced socket interruption. An emulated touch browser was also checked for layout and touch controls.
- The built site was loaded from a local nested `/repository/` path to check relative asset paths. **This is not an actual GitHub Pages deployment or a public WSS test.** Chromebook hardware performance, Android hardware performance, and physical gamepad behavior have not been verified.

## Operational and compatibility notes

The development server is bound to `127.0.0.1` by default; do not expose it publicly. At the time this package was checked, `npm audit` reported an unpatched high-severity ReDoS advisory in `picomatch`, a Vite development dependency, for specially crafted glob patterns. Do not accept untrusted glob patterns in build tooling. `npm audit --omit=dev` reported no production dependency advisories. Recheck dependencies for updates before deploying.

Server rooms and session data are held by the server. Unless its documentation explicitly says otherwise, treat them as temporary: restarts and expired rooms may end a session. Do not use room codes as authentication for sensitive information. Configure an exact origin allowlist, WSS termination, reasonable rate/connection limits, and an independent service supervisor when hosting publicly. Client-owned movement is intended for casual cooperative play, not cheat-resistant competition.

Graphics and resolution settings are available to scale the load, but actual performance depends on the browser, GPU, screen size and device. Chromebook and specific Android hardware performance cannot be established by a desktop test alone.

The package contains generated original menu artwork and audio. Any additional third-party assets and their individual license information are listed in [ASSET-LICENSES.md](ASSET-LICENSES.md) when present.

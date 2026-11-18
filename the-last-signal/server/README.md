# The Last Signal server

This is the separately runnable, authoritative Node.js WebSocket server. It does not serve the frontend. Node.js 20 or newer is required.

## Local launch

```sh
cd server
npm ci
npm start
```

The default port is `8787`; change it with `PORT=9000 npm start`. The WebSocket endpoint is `ws://localhost:8787/ws` and `GET http://localhost:8787/health` returns JSON with `ok` and the protocol `version`. The health response permits browser requests only from origins in `ALLOWED_ORIGINS` (or local development origins when unset); the game uses it to notice and wait for a sleeping free-tier service when a player starts multiplayer. This on-demand health check does not keep an idle service awake. Set the game’s server URL to the complete `/ws` URL. One to four actual players can join a room; no bots or simulated players are added. Joining an active game is supported while a seat is free.

Run deterministic integration tests (from the project checkout, not just the server subdirectory copied alone):

```sh
cd server
npm ci
npm test
```

## Origins and public hosting

By default browser origins must be `http://localhost`, `http://127.0.0.1`, `http://[::1]`, or their HTTPS equivalents, with any port. Configure an exact comma-separated allowlist for a publicly hosted frontend:

```sh
PORT=8787 ALLOWED_ORIGINS=https://your-account.github.io,https://game.example.com npm start
```

Entries are exact **origins** (scheme, host, optional port), not URLs with paths or trailing slashes. Browsers send the same GitHub Pages origin for every repository page. WebSocket requests without an Origin are accepted for command-line/native clients; Origin filtering protects browsers and is not authentication. `ALLOWED_ORIGINS=*` explicitly permits all browser origins; use only if appropriate for your deployment. The invitation code identifies a room, whereas the independently generated resume token is a bearer secret. Do not put a token in an invitation link, logs, or shared browser storage.

For a public HTTPS game, put the Node process behind HTTPS/WSS termination and use `wss://your-host/ws` in the game. The reverse proxy must forward WebSocket Upgrade/Connection headers and route `/ws` to the server; `/health` can be used for health checks. Open the relevant firewall port. GitHub Pages only serves static assets and cannot run this process.

### Docker

From the project root:

```sh
docker build -t last-signal-server ./server
docker run --rm -p 8787:8787 \
  -e ALLOWED_ORIGINS=https://your-account.github.io \
  last-signal-server
```

A container host may inject `PORT`; publish or proxy that port accordingly. A public host still needs TLS termination for `wss://`. The image runs as a non-root user.

## Behavior and protocol

The contract protocol version is `last-signal-1`. Rooms hold up to four real sessions including temporarily disconnected seats. A disconnected seat is retained for 60 seconds. The same room code and secret token resume that identity during the grace period; a valid resume may replace an old connection that has not noticed a break. When a host disconnects, host authority immediately moves to the earliest connected remaining player; it is not automatically transferred back when the former host resumes. Once the grace period expires, the seat and its token are removed. Empty rooms are deleted after their final reservation expires. A restart deletes all rooms and tokens.

All shared game progression, interaction distance (2.75m), locked archive boundary, player membership, and the monster are validated on the server. Player poses are bounded to the facility and subject to a movement budget and monotonic sequence numbers. The client may move locally immediately and should apply authoritative correction. Patrol, investigation of recent movement, search and chase are driven on the server. Being caught returns the affected player to reception and briefly protects them; shared progress is not lost. The server emits `event` with `name: "caught"` and an intelligible message and broadcasts the corrected snapshot.

A world flag indicates the corresponding item or step has been acquired/completed: `fuse`, `generator`, `key`, `archive`, three `notes`, and `exit`/`completed`. `objective` is a display string. `interact.actionId` must be a nonempty string of at most 128 characters or a nonnegative safe integer; use a fresh ID per interaction. Recent successful IDs and already-completed objectives are idempotent. Invalid or disallowed messages produce an `{type:"error",code,message}`. Messages are capped at 4096 bytes and rate-limited; default limits allow normal pose traffic. All client messages must be JSON.

### Room checkpoint extension

The game contract is extended by the following host-only messages:

```json
{"type":"save"}
{"type":"load"}
```

`save` is available during `playing`; it replaces that room’s one checkpoint and broadcasts `{type:"event",name:"saved",message}`. The checkpoint contains the room’s world/progression and monster state. `load` restores it, sets the phase to `playing`, returns every player to reception so a restored archive lock cannot trap anyone, then broadcasts `{type:"snapshot",state}` and `{type:"event",name:"loaded",message}`. Current memberships, host, and secret resume tokens are not changed. Only the current host can save or load; errors include `NOT_HOST`, `WRONG_PHASE`, and `NO_CHECKPOINT`.

**Checkpoints are memory-only:** they are lost when the room expires, the process restarts, or the container is replaced. They are not durable saves. The same is true of live room state. Use one running server process; multiple replicas do not share rooms or checkpoints.

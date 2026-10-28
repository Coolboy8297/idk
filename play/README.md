# VEYΛORA Play — Prototype 0.1

VEYΛORA Play is the cloud-gaming frontend prototype for the VEYΛORA Arcade project.

## Frontend

This prototype is a static page in `play/index.html`. It is designed for GitHub Pages:

- Library cards and search/filter UI
- Responsive dark graphite and electric-blue theme
- Optional host URL configuration saved in the current browser
- Host health check at `GET /health`
- Session request at `POST /api/sessions`

The current game cards are **demo entries**, not a real Steam library. Steam sign-in, owned-game retrieval, secure user accounts, session scheduling, and browser streaming are not implemented yet.

## GitHub Pages URL

If GitHub Pages is enabled for the `main` branch at the repository root, open:

`https://coolboy8297.github.io/idk/play/`

## Host API contract

The website expects a separate gaming host that you control. Configure its base URL in the page.

### Health

`GET /health`

Example response:

```json
{ "status": "ok" }
```

### Request a session

`POST /api/sessions`

Request:

```json
{ "gameId": "portal-2" }
```

A future implementation can return:

```json
{ "sessionId": "example-session", "streamUrl": "https://your-stream-client.example/session/example-session" }
```

The prototype only opens a returned stream URL in a new tab. It does **not** yet embed or implement low-latency video/audio/gamepad streaming.

## Security requirements before public use

- Serve the host API over HTTPS for public access.
- Implement authentication, per-session authorization, rate limits, and strict CORS allowlists.
- Do not expose Steam Web API keys, host admin credentials, or other secrets in frontend JavaScript.
- Do not expose a raw game-launch endpoint to unauthenticated visitors.
- Only let the server start games that are installed and authorized on that host.
- Use a dedicated streaming stack for low-latency video, audio, and controller input.

Steam sign-in should be implemented on a trusted backend using Steam's official OpenID flow. Steam passwords must never be requested or stored by VEYΛORA Play. Library visibility depends on Steam privacy settings and available API data.

## Roadmap

1. [x] First static frontend prototype
2. [x] Host URL field and health-check contract
3. [ ] Create a secure host agent and session manager
4. [ ] Add Steam OpenID sign-in on the backend
5. [ ] Retrieve permitted Steam library metadata
6. [ ] Integrate a real streaming client and input transport
7. [ ] Add user authorization, session limits, and operational monitoring

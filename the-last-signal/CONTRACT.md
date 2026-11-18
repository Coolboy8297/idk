# The Last Signal — implementation contract

The deliverable is a standalone, editable Three.js/Vite game and a separately runnable Node.js WebSocket server. It is not a Manus-hosted service. One to four actual clients connect; there are no simulated players. The world is one connected, progressively unlocked facility with distinct reception, maintenance and archive sectors.

## Shared world coordinates (x,z, units in metres)
- Playable bounds: x from -9 to 9, z from -34 to 20. Spawn is (0,16).
- `fuse`: (-6,10), take fuse.
- `generator`: (-6,0), insert fuse to restore power.
- `key`: (6,-5), retrieve archive key after power is on.
- `archive`: (0,-12), unlock archive with key.
- `note1`: (5,-17), `note2`: (-5,-22), `note3`: (5,-27), collect all recordings after opening archive.
- `exit`: (0,-32), escape after collecting all 3 recordings.
- Monster starts at (0,-24). The archive lock blocks entry near z=-12 until unlocked. Avoid non-navigable maze geometry; these coordinates must be reachable.

## Network protocol (JSON)
Version string `last-signal-1`. Messages client -> server:
`{type:'create', name, version:'last-signal-1'}`; `{type:'join', code, name, version:'last-signal-1'}`; `{type:'resume', code, token, version:'last-signal-1'}`; `{type:'pose', x,z,yaw,crouch,sprint,flashlight, seq}`; `{type:'interact',target,actionId}`; `{type:'start'}`; `{type:'ping', t}`. A sessionStorage token is per tab, secret and never part of invitation codes.
Server -> client: `{type:'welcome',id,token,code,hostId,state}`; `{type:'snapshot',state}`; `{type:'event',name,message}`; `{type:'error',message,code}`; `{type:'pong',t}`. The state shape is `{revision,phase,hostId,players:[{id,name,x,z,yaw,crouch,sprint,flashlight,connected}],monster:{x,z,yaw,mode},world:{fuse,generator,key,archive,notes:[bool,bool,bool],exit,completed},objective}`. `phase` is `lobby`, `playing`, or `won`. Server is authoritative for shared progression, enemy and room membership; client movement is immediate then bounded/validated and relayed.
Action targets are names above. Server validates required item progression and server-side distance <= 2.75m before mutating; interactions idempotent. Enemies patrol, investigate movement, search and chase based on proximity and line of sight where possible. Contact should cause an intelligible recoverable outcome, not desync.

## Engine interface
`src/engine.js` exports `createGame({canvas,onInteract,onPose,onHint,onSound})`. Return `{start(), stop(), setSnapshot(state), setSettings(settings), interact(), toggleFlashlight(), setMove(x,y), setLook(dx,dy), dispose()}`. At <=30Hz `onPose({x,z,yaw,crouch,sprint,flashlight,seq})`; call `onInteract(target)` for nearby interactable; `onHint({target,label,detail}|null)` to present prompts. Include pointer-lock desktop controls, mobile hooks, gamepad support where possible. Initial pose 0,16. Setting graphics is `{quality:'low'|'medium'|'high'|'ultra',resolution:0.5..1,mouseSensitivity:number,masterVolume:number}`. When not in the playing phase movement must stop. Visibility and positions of world interactions/doors must reflect `world`.

## Main UI interface
Parent agent integrates networking and UI. HTML/stylesheet provide visible cinematic menu, create/join lobby, endpoint input (a `wss://` endpoint for GitHub Pages; `ws://localhost` only for local HTTP), room code, players, host start, reconnect states, game HUD and settings, pause, inventory and ending. No hard-coded localhost in public deploy; show actionable configuration error. Menu and overlay must match engine interaction interface.

## Project conventions
Use local import `three` from npm; Vite `base:'./'`; all local asset paths relative to app base. `npm run dev`, `npm run build`. Server lives separately in `server/`, uses its own package.json / lock and `npm start`, `PORT`/`ALLOWED_ORIGINS`, `/health` and WebSocket `/ws`. Static GitHub Pages cannot run it. Asset files must be portable and included in ZIP. Frontend and server deploy independently. Avoid editing files owned by another worker.

# The Last Signal — UI integration contract

The UI is markup and CSS only. `index.html` loads `./src/style.css` and `./src/main.js`; `main.js` owns all state, events, accessibility focus management, pointer lock, networking and persistence. `game-canvas` is behind the interface. No inline script or framework is required. Nothing in the markup claims that a server is connected by default.

## Screen and overlay conventions

- Exactly one of `menu-screen` (initially visible), `lobby-screen`, `game-screen`, `end-screen` should normally be visible. Toggle the `hidden` **property**; the stylesheet enforces `[hidden] { display:none }`.
- `loading-screen`, `settings-overlay`, `controls-overlay`, `credits-overlay`, `pause-overlay`, `inventory-overlay` and `connection-overlay` are initially hidden and may be shown above the active screen. Close the previous modal when appropriate, or restore it when a nested settings/controls dialog closes. Trap/restore keyboard focus in dialogs and release/reacquire pointer lock as appropriate in the controller.
- The canvas `game-canvas` is always available for `createGame({canvas,...})`. `app` is the application root. `live-announcement` is a polite live region for short nonvisual notices.
- `menu-connection-status`, `lobby-connection-status`, and `hud-network-status` are status wrappers; their respective text IDs are `menu-connection-text`, `lobby-connection-text`, and `hud-network-text`. Set their text to the actual state, and apply **one** of `is-connected`, `is-connecting`, `is-error` to the wrapper as appropriate. Clear these classes for an idle/disconnected neutral state. Do not mark connected until a real server connection is established.
- Errors are inserted using `textContent`, never raw HTML from player/server data. `menu-error` and `lobby-error` are initially hidden inline alerts. Set their text then toggle `hidden`. For connection loss, use the separate `connection-overlay` described below.

## Menu

The main menu defaults to **single player**: `solo-panel` is visible, `multiplayer-panel` is hidden, and the solo mode button has `is-active` and `aria-pressed="true"`. Both mode buttons stay visible so the player can switch in either direction. The controller must bind their clicks, toggle the two panels' `hidden` properties, move `is-active` to the chosen button, and set both buttons' `aria-pressed` values to match. These are ordinary buttons, not ARIA tabs; keyboard activation is native. If changing modes while an error is showing, clear or update `menu-error` so it describes the current mode. The shared status wrapper must report the actual state, never a fabricated connection.

Single player is an offline path and must not require, validate, or connect to `server-url`, or require a room code. `solo-continue-button` starts disabled; enable it only when a valid local checkpoint exists (or keep it hidden/disabled otherwise). Starting or continuing a solo game, checkpoint storage, and any solo-specific loading/status copy are the controller's responsibility. The multiplayer panel keeps the existing endpoint, callsign, room-code, create/join and resume controls; switching modes should not discard entered values.

| ID | Semantics |
| --- | --- |
| `game-title` | Menu title, also the screen's accessible heading. |
| `mode-solo-button`, `mode-multiplayer-button` | Visible mode-switch buttons; each has `aria-controls` pointing at its panel. Keep `is-active` and `aria-pressed` synchronized with the selected mode. |
| `solo-panel`, `multiplayer-panel` | Mutually exclusive mode panels controlled with `hidden`; `solo-panel` is initially visible. |
| `solo-start-button` | Start a new offline single-player game without a server endpoint or room code. |
| `solo-continue-button` | Continue a valid saved single-player game; initially disabled until a checkpoint is available. |
| `server-url` | Editable WebSocket endpoint; deliberately blank initially. Placeholder is an example only. Validate `wss://` on HTTPS and show actionable errors in `menu-error`; local HTTP may use `ws://`. `server-url-help` is its descriptive helper. |
| `player-name` | Callsign input, `maxlength=24`. |
| `room-code-input` | Invitation code input, uppercase visual styling, `maxlength=12`; normalize the actual value as needed. |
| `create-room-button` | Create a room with the entered name and endpoint. |
| `join-room-button` | Join using endpoint, callsign, and code. |
| `resume-session-button` | Resume the last multiplayer room when a resumable session exists; initially hidden. |
| `menu-settings-button`, `menu-controls-button`, `menu-credits-button` | Open the respective overlays. |

## Lobby

| ID | Semantics |
| --- | --- |
| `lobby-heading` | Accessible lobby heading. |
| `lobby-room-code` | Text of the current invitation code; never display a resume token here. |
| `copy-room-code-button` | Copy the visible code; announce success/failure in `live-announcement`. |
| `lobby-player-count` | Player count, e.g. `2 / 4 OPERATORS`. |
| `lobby-player-list` | `ul` for real room members only; replace the initial waiting placeholder from server snapshots. Use `li` children and safe text nodes. Optional styling: `.player-name` and `.player-tag` spans, e.g. `HOST`, `CONNECTED`, `RECONNECTING`. Never fabricate players. |
| `lobby-message` | Status/host instruction; a polite live status. |
| `start-game-button` | Host starts the game. Initially disabled: enable only when the actual host may start. |
| `leave-room-button` | Leave and return to the menu. |

## In-game HUD

| ID | Semantics |
| --- | --- |
| `hud-objective`, `hud-objective-detail` | Current objective and optional detail, displayed over the canvas. |
| `hud-pause-button` | Open pause. |
| `interaction-prompt` | Initially hidden; show while engine `onHint` supplies a target. |
| `interaction-label`, `interaction-detail` | Prompt label/detail from `onHint({target,label,detail})`; interaction itself is handled by the engine. The visual key is E. |
| `inventory-button` | Open inventory. |
| `hud-battery-meter`, `hud-battery-fill`, `hud-battery-value` | Battery indicator. Set fill `style.width` as a percentage, displayed value text, and meter `aria-valuenow` (0–100) together **only if a real battery value is provided**. Defaults are empty/unknown. |
| `hud-flashlight-status` | Text describing actual flashlight status. |

The `touch-controls` container appears for `pointer: coarse`; adding `touch-enabled` to `body` forces it on for testing. Its areas are deliberately `touch-action: none`. `touch-move` and `touch-move-knob` are the left analog pad and its movable visual; handle pointer down/move/up/cancel and reset on release. `touch-look` is the drag-to-look area on the right. `touch-interact`, `touch-flashlight`, `touch-crouch`, and `touch-sprint` are action buttons. Route gestures to the engine and release held actions on pointer cancel/up and when a screen changes. The HUD pause and inventory buttons also work on touch. The listed engine contract has `setMove`, `setLook`, `interact` and `toggleFlashlight`, but **does not currently specify touch sprint/crouch setters or a battery value**; add/coordinate those hooks or leave status unknown rather than simulate them.

## Dialogs and transitions

| ID | Semantics |
| --- | --- |
| `loading-screen`, `loading-title`, `loading-message` | Animated blocking connecting/loading state; set copy and show only during actual work. |
| `settings-overlay`, `settings-title` | Settings dialog and accessible title. |
| `settings-close-button`, `settings-done-button` | Close settings; return to whichever screen/dialog opened it. |
| `graphics-quality` | Select: `low`, `medium`, `high` (initial), `ultra`; map to engine `quality`. |
| `resolution-scale` | Select: `0.5`, `0.75`, `1` (initial); convert string to number and map to `resolution`. |
| `master-volume`, `master-volume-value` | Range 0–1, step .05, initial .8; update its output label and map numeric value to `masterVolume`. |
| `mouse-sensitivity`, `mouse-sensitivity-value` | Range .25–2.5, step .05, initial 1; update output label and map numeric value to `mouseSensitivity`. |
| `controls-overlay`, `controls-title`, `controls-close-button`, `controls-done-button` | Controls dialog and dismiss actions. The displayed keys are WASD, mouse, E interact, F flashlight, Shift sprint, Ctrl crouch, I inventory, Esc pause; make implementation agree or update the text. |
| `credits-overlay`, `credits-title`, `credits-close-button`, `credits-done-button` | Credits dialog and dismiss actions. |
| `pause-overlay`, `pause-title` | Pause dialog. The shared simulation may continue while an individual client is paused. |
| `resume-game-button` | Resume local play. |
| `pause-save-checkpoint-button`, `pause-load-checkpoint-button` | Distinct save and load checkpoint actions. **Both start disabled**; enable in solo or for the multiplayer host only when the corresponding checkpoint operation is supported/available, and keep disabled for multiplayer guests. Buttons do not imply server-side checkpoint support by themselves. |
| `pause-settings-button`, `pause-controls-button`, `pause-leave-button` | Open settings, controls, or leave the current room. |
| `inventory-overlay`, `inventory-title`, `inventory-close-button`, `inventory-done-button` | Inventory dialog and close actions. |
| `inventory-list` | `ul` of actual recovered items; replace its empty placeholder from authoritative game state using safe text nodes. |
| `connection-overlay`, `connection-title`, `connection-message` | Initially hidden alert dialog for disconnect/reconnect/error states; customize title and text to the actual state. |
| `reconnect-button`, `connection-menu-button` | Retry or abandon and return to menu. Never expose the session token. |
| `end-screen`, `end-title`, `end-message`, `end-menu-button` | End state and return-to-menu action; set copy to the actual outcome. |

## Styling and state notes

The menu uses local background artwork over a CSS background color. On small screens the menu scrolls; the HUD keeps pointer events off its decorative surface and on actionable controls. Reduced-motion preference is respected. Buttons are semantic and have focus styling. The host controller is responsible for keyboard bindings, mode and screen switching, validating multiplayer server URLs, setting meaningful status text and all behaviors; the static HTML alone does not implement a game.

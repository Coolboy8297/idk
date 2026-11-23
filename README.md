# VEYAORA — Eaglercraft Portal

Premium browser launcher for **Eaglercraft**, branded under VEYAORA.

**Slogan:** PLAY BEYOND WHAT’S NEXT.

## Features

- Dark black / deep-blue futuristic aesthetic with glass panels and subtle gradients
- Clean homepage with large **PLAY EAGLERCRAFT** button
- Dedicated full-size game view with:
  - Back to VEYAORA
  - Fullscreen toggle
  - Loading state
- Fully responsive (desktop, Chromebook, mobile)
- Pure HTML / CSS / JS — ready for GitHub Pages
- No fake game or copyrighted assets included

## Project structure

```
veyaora-eaglercraft/
├── index.html          # Homepage + game view shell
├── css/
│   └── style.css
├── js/
│   └── script.js
├── eaglercraft/        # ← Put your Eaglercraft build here
│   └── README.md
└── README.md
```

## Deploy to GitHub Pages

1. Create a new repository (or use an existing one).
2. Upload / push the contents of this folder.
3. Place your Eaglercraft build inside `eaglercraft/` so the entry file is `eaglercraft/index.html`.
4. In the repo settings → Pages → set source to the branch (usually `main`) and root `/`.
5. Visit `https://<username>.github.io/<repo>/`.

## Customizing the game path

Edit `js/script.js`:

```js
const GAME_SRC = "eaglercraft/index.html";
const GAME_VERSION = "1.8.8";
```

## Local testing

Open `index.html` in a modern browser, or serve the folder with any static server:

```bash
npx serve .
# or
python -m http.server 8080
```

Because the game is loaded in an iframe, some browsers require a local server (not `file://`) for full functionality.

---

© VEYAORA


## Website community features

The website-wide player counter and Community Chat use Firebase Realtime Database. They are part of the VEYΛORA website shell, not part of any embedded game.

1. Create or open the Firebase project used by the site.
2. Enable **Anonymous** sign-in under Authentication.
3. Create a Realtime Database.
4. Replace the placeholder values in `js/firebase-config.js` with the Firebase web-app configuration and the Realtime Database URL.
5. Paste the contents of `firebase-database.rules.json` into Realtime Database → Rules and publish them.

The chat is visible to signed-in site visitors. Messages are limited to 300 characters and can only be created by the anonymous account that authored them. Configure the Firebase project before expecting the live count or chat to connect.

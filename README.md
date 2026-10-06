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

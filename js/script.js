/**
 * VEYAORA — Eaglercraft Portal
 * Clean launcher logic: home ↔ game view, fullscreen, loading states.
 *
 * Place your Eaglercraft build at: eaglercraft/index.html
 * Or change GAME_SRC below to point at your build entry point.
 */

(function () {
  "use strict";

  // ── Config ──────────────────────────────────────────────
  // Path to the actual Eaglercraft entry file you will provide.
  // Common patterns: "eaglercraft/index.html" or "eaglercraft/eaglercraft.html"
  const GAME_SRC = "eaglercraft/index.html";

  // Optional: set a version string shown on the homepage
  const GAME_VERSION = "1.8.8";

  // Live presence is powered by Firebase Realtime Database.
  // Add your Firebase web-app config below and enable Realtime Database.
  // Until configured, the menu clearly reports that live count setup is needed.
  const FIREBASE_CONFIG = null; // Replace null with your Firebase config object.

  // ── Elements ────────────────────────────────────────────
  const homeView = document.getElementById("home-view");
  const gameView = document.getElementById("game-view");
  const playBtn = document.getElementById("play-btn");
  const backBtn = document.getElementById("back-btn");
  const fullscreenBtn = document.getElementById("fullscreen-btn");
  const gameFrame = document.getElementById("game-frame");
  const gameLoader = document.getElementById("game-loader");
  const statusText = document.getElementById("status-text");
  const gameVersionEl = document.getElementById("game-version");
  const fsIconEnter = document.getElementById("fs-icon-enter");
  const fsIconExit = document.getElementById("fs-icon-exit");
  const fsLabel = document.getElementById("fs-label");
  const liveVisitorsEl = document.getElementById("live-visitors");
  const visitorStatusEl = document.getElementById("visitor-status");

  let gameLoaded = false;
  let isFullscreen = false;

  // ── Init ────────────────────────────────────────────────
  if (gameVersionEl) {
    gameVersionEl.textContent = GAME_VERSION;
  }

  // ── Optional real-time visitor presence ─────────────────
  // Uses Firebase's onDisconnect cleanup, so counts fall when tabs disconnect.
  function setupLiveVisitors() {
    if (!FIREBASE_CONFIG || !window.firebase) {
      if (visitorStatusEl) visitorStatusEl.textContent = "Live count setup needed";
      return;
    }
    try {
      if (!firebase.apps.length) firebase.initializeApp(FIREBASE_CONFIG);
      const db = firebase.database();
      const connectedRef = db.ref(".info/connected");
      const presenceRef = db.ref("presence/veyaora");
      const clientId = db.ref("presence/veyaora").push().key;
      const myPresence = presenceRef.child(clientId);
      connectedRef.on("value", (snapshot) => {
        if (snapshot.val() !== true) {
          if (visitorStatusEl) visitorStatusEl.textContent = "Connecting…";
          return;
        }
        myPresence.onDisconnect().remove();
        myPresence.set({ since: firebase.database.ServerValue.TIMESTAMP });
        if (visitorStatusEl) visitorStatusEl.textContent = "live right now";
      });
      presenceRef.on("value", (snapshot) => {
        if (liveVisitorsEl) liveVisitorsEl.textContent = snapshot.numChildren();
      });
    } catch (error) {
      if (visitorStatusEl) visitorStatusEl.textContent = "Counter unavailable";
      console.warn("VEYAORA live visitor counter:", error);
    }
  }
  setupLiveVisitors();

  // ── View switching ──────────────────────────────────────
  function showView(view) {
    if (view === "game") {
      homeView.classList.remove("active");
      gameView.classList.add("active");
      document.body.style.overflow = "hidden";
      loadGame();
    } else {
      // Leaving game view
      if (document.fullscreenElement || document.webkitFullscreenElement) {
        exitFullscreen();
      }
      gameView.classList.remove("active");
      homeView.classList.add("active");
      document.body.style.overflow = "";
      // Unload frame to free resources (optional but cleaner)
      unloadGame();
    }
  }

  function loadGame() {
    if (gameLoaded) {
      // Already loaded once — just show it
      gameLoader.classList.add("hidden");
      gameFrame.classList.add("loaded");
      return;
    }

    gameLoader.classList.remove("hidden");
    gameFrame.classList.remove("loaded");
    statusText.textContent = "Loading…";

    // Set src only when entering game view (avoids preloading heavy assets)
    gameFrame.src = GAME_SRC;

    // Handle successful load
    const onLoad = () => {
      gameLoaded = true;
      gameLoader.classList.add("hidden");
      gameFrame.classList.add("loaded");
      statusText.textContent = "In Game";
      gameFrame.removeEventListener("load", onLoad);
    };

    // Handle load error (e.g. missing build file)
    const onError = () => {
      gameLoader.innerHTML = `
        <div class="loader-ring" style="border-top-color:#ff6b6b;animation:none;border-color:rgba(255,107,107,0.25)"></div>
        <p class="loader-text">Eaglercraft build not found</p>
        <p class="loader-sub">Place your build at <code style="color:var(--accent-bright)">${GAME_SRC}</code></p>
        <p class="loader-sub" style="margin-top:0.5rem;font-size:0.75rem">Then refresh and try again</p>
      `;
      statusText.textContent = "Error";
      gameFrame.removeEventListener("error", onError);
    };

    gameFrame.addEventListener("load", onLoad);
    gameFrame.addEventListener("error", onError);

    // Safety timeout: if nothing happens in 12s, show a gentle message
    setTimeout(() => {
      if (!gameLoaded && !gameLoader.classList.contains("hidden")) {
        // Still loading or missing — leave the error UI if already set
        if (gameLoader.querySelector(".loader-text")?.textContent === "Loading Eaglercraft…") {
          gameLoader.querySelector(".loader-sub").textContent =
            "Still loading… large builds can take a moment";
        }
      }
    }, 12000);
  }

  function unloadGame() {
    // Keep the frame src so the next open is fast, but hide loader state
    // If you prefer a full unload every time, uncomment the next line:
    // gameFrame.src = "about:blank";
    // gameLoaded = false;
    statusText.textContent = "Ready";
  }

  // ── Fullscreen ──────────────────────────────────────────
  function toggleFullscreen() {
    if (!document.fullscreenElement && !document.webkitFullscreenElement) {
      const el = gameView;
      if (el.requestFullscreen) {
        el.requestFullscreen().catch(() => {});
      } else if (el.webkitRequestFullscreen) {
        el.webkitRequestFullscreen();
      }
    } else {
      exitFullscreen();
    }
  }

  function exitFullscreen() {
    if (document.exitFullscreen) {
      document.exitFullscreen().catch(() => {});
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen();
    }
  }

  function updateFullscreenUI() {
    isFullscreen = !!(document.fullscreenElement || document.webkitFullscreenElement);
    if (isFullscreen) {
      fsIconEnter.classList.add("hidden");
      fsIconExit.classList.remove("hidden");
      fsLabel.textContent = "Exit Fullscreen";
    } else {
      fsIconEnter.classList.remove("hidden");
      fsIconExit.classList.add("hidden");
      fsLabel.textContent = "Fullscreen";
    }
  }

  // ── Events ──────────────────────────────────────────────
  playBtn.addEventListener("click", () => showView("game"));
  backBtn.addEventListener("click", () => showView("home"));
  fullscreenBtn.addEventListener("click", toggleFullscreen);

  document.addEventListener("fullscreenchange", updateFullscreenUI);
  document.addEventListener("webkitfullscreenchange", updateFullscreenUI);

  // Keyboard: Escape already exits fullscreen natively.
  // Optional: press F for fullscreen while in game view
  document.addEventListener("keydown", (e) => {
    if (!gameView.classList.contains("active")) return;
    if (e.key === "f" || e.key === "F") {
      // Don't trigger if user is typing in game
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
      e.preventDefault();
      toggleFullscreen();
    }
  });

  // ── Accessibility: focus management ─────────────────────
  playBtn.addEventListener("keydown", (e) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      playBtn.click();
    }
  });
})();

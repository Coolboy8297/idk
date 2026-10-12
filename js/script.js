/**
 * VEYAORA ARCADE — Eaglercraft 26.2 launcher
 * Main build: eaglercraft/index.html
 */
(function () {
  "use strict";
  const GAME_SRC = "eaglercraft/index.html";
  const GAME_VERSION = "26.2";
  // Configure a Firebase web app + Realtime Database to enable live presence.
  const FIREBASE_CONFIG = null;

  const homeView = document.getElementById("home-view");
  const gameView = document.getElementById("game-view");
  const playBtn = document.getElementById("play-btn");
  const versionCurrent = document.getElementById("version-current");
  const backBtn = document.getElementById("back-btn");
  const fullscreenBtn = document.getElementById("fullscreen-btn");
  const gameFrame = document.getElementById("game-frame");
  const gameLoader = document.getElementById("game-loader");
  const statusText = document.getElementById("status-text");
  const gameVersionEl = document.getElementById("game-version");
  const fsLabel = document.getElementById("fs-label");
  const liveVisitorsEl = document.getElementById("live-visitors");
  const visitorStatusEl = document.getElementById("visitor-status");
  let gameLoaded = false;

  if (gameVersionEl) gameVersionEl.textContent = GAME_VERSION;
  if (gameFrame) gameFrame.title = "Eaglercraft " + GAME_VERSION;

  function setupLiveVisitors() {
    if (!FIREBASE_CONFIG || !window.firebase) {
      if (visitorStatusEl) visitorStatusEl.textContent = "COUNTER NOT CONFIGURED";
      return;
    }
    try {
      if (!firebase.apps.length) firebase.initializeApp(FIREBASE_CONFIG);
      const db = firebase.database();
      const connected = db.ref(".info/connected");
      const presence = db.ref("presence/veyaora");
      const id = presence.push().key;
      const mine = presence.child(id);
      connected.on("value", snapshot => {
        if (snapshot.val() !== true) {
          if (visitorStatusEl) visitorStatusEl.textContent = "CONNECTING…";
          return;
        }
        mine.onDisconnect().remove();
        mine.set({ since: firebase.database.ServerValue.TIMESTAMP });
        if (visitorStatusEl) visitorStatusEl.textContent = "LIVE RIGHT NOW";
      });
      presence.on("value", snapshot => {
        if (liveVisitorsEl) liveVisitorsEl.textContent = String(snapshot.numChildren());
      });
    } catch (error) {
      if (visitorStatusEl) visitorStatusEl.textContent = "COUNTER UNAVAILABLE";
      console.warn("VEYAORA presence counter:", error);
    }
  }
  setupLiveVisitors();

  function showGame() {
    homeView.classList.remove("active");
    gameView.classList.add("active");
    document.body.style.overflow = "hidden";
    loadGame();
  }
  function showHome() {
    if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen().catch(() => {});
    gameView.classList.remove("active");
    homeView.classList.add("active");
    document.body.style.overflow = "";
    if (statusText) statusText.textContent = "SYSTEM READY";
  }
  function loadGame() {
    if (gameLoaded) {
      gameLoader.classList.add("hidden");
      gameFrame.classList.add("loaded");
      if (statusText) statusText.textContent = "GAME ACTIVE";
      return;
    }
    gameLoader.classList.remove("hidden");
    gameFrame.classList.remove("loaded");
    if (statusText) statusText.textContent = "BOOTING GAME";
    gameFrame.onload = () => {
      gameLoaded = true;
      gameLoader.classList.add("hidden");
      gameFrame.classList.add("loaded");
      if (statusText) statusText.textContent = "GAME ACTIVE";
    };
    gameFrame.src = GAME_SRC;
  }
  function toggleFullscreen() {
    if (document.fullscreenElement) {
      if (document.exitFullscreen) document.exitFullscreen().catch(() => {});
      return;
    }

    // Fullscreen the game iframe itself so the browser gives keyboard and
    // pointer-lock input to the game rather than to the surrounding launcher.
    const target = gameFrame && gameFrame.requestFullscreen
      ? gameFrame
      : gameView;

    if (target && target.requestFullscreen) {
      target.requestFullscreen().then(() => {
        // Focus the game after the fullscreen transition; pointer lock still
        // requires a click inside the game, as required by the browser.
        try { gameFrame.focus({ preventScroll: true }); }
        catch (_) { gameFrame.focus(); }
      }).catch(() => {
        // Some browsers only permit the containing element to go fullscreen.
        if (target !== gameView && gameView.requestFullscreen) {
          gameView.requestFullscreen().then(() => {
            try { gameFrame.focus({ preventScroll: true }); }
            catch (_) { gameFrame.focus(); }
          }).catch(() => {});
        }
      });
    }
  }
  function updateFullscreenLabel() {
    if (fsLabel) fsLabel.textContent = document.fullscreenElement ? "⛶ EXIT FULLSCREEN" : "⛶ FULLSCREEN";
  }

  playBtn.addEventListener("click", showGame);
  if (versionCurrent) versionCurrent.addEventListener("click", showGame);
  backBtn.addEventListener("click", showHome);
  fullscreenBtn.addEventListener("click", toggleFullscreen);
  document.addEventListener("fullscreenchange", updateFullscreenLabel);
  document.addEventListener("keydown", event => {
    if (!gameView.classList.contains("active")) return;
    if (event.key.toLowerCase() === "f" && !["INPUT", "TEXTAREA"].includes(event.target.tagName)) {
      event.preventDefault();
      toggleFullscreen();
    }
  });
})();
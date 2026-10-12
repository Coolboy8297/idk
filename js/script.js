/**
 * VEYAORA ARCADE — Eaglercraft 26.2 launcher
 * Main build: eaglercraft/index.html
 */
(function () {
  "use strict";
  // MAIN VERSION: keep the current build at eaglercraft/index.html.
  const GAME_SRC = "eaglercraft/index.html";
  const GAME_VERSION = "26.2";

  // ADD EXTRA VERSIONS HERE.
  // Put each extra HTML file in the eaglercraft folder and name it by version,
  // for example eaglercraft/1.8.8.html, then add:
  // { version: "1.8.8", file: "1.8.8.html" }
  // The main index.html above stays unchanged.
  const EXTRA_VERSIONS = [
    { version: "1.8.8", file: "1.8.8.html" },
    { version: "1.12.2", file: "1.12.2.html" },
    { version: "1.5.1", file: "1.5.1.html" },
    { version: "Beta 1.7.3", file: "b1.7.3.html" },
    { version: "Beta 1.3", file: "b1.3.html" },
    { version: "Alpha 1.2.6", file: "a1.2.6.html" },
    { version: "Indev", file: "indev.html" },
  ];
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
  const otherVersionsSection = document.getElementById("other-versions-section");
  const otherVersionsGrid = document.getElementById("other-versions-grid");
  let gameLoaded = false;
  let selectedGameSrc = GAME_SRC;
  let selectedGameVersion = GAME_VERSION;

  if (gameVersionEl) gameVersionEl.textContent = GAME_VERSION;
  if (gameFrame) gameFrame.title = "Eaglercraft " + GAME_VERSION;

  function renderExtraVersions() {
    if (!otherVersionsSection || !otherVersionsGrid) return;
    otherVersionsGrid.replaceChildren();

    EXTRA_VERSIONS.forEach((entry, index) => {
      if (!entry || !entry.version || !entry.file) return;

      const card = document.createElement("article");
      card.className = "game-card game-card-featured extra-version-card";

      const art = document.createElement("div");
      art.className = "card-art art-262";
      const artLabel = document.createElement("span");
      artLabel.className = "art-label";
      artLabel.textContent = "EXTRA BUILD";
      const artGrid = document.createElement("div");
      artGrid.className = "art-grid";
      const artNumber = document.createElement("div");
      artNumber.className = "art-number";
      artNumber.textContent = entry.version;
      const artFooter = document.createElement("span");
      artFooter.className = "art-bottom-label";
      artFooter.textContent = "EAGLERCRAFT / " + entry.version;
      art.append(artLabel, artGrid, artNumber, artFooter);

      const body = document.createElement("div");
      body.className = "card-body";
      const tags = document.createElement("div");
      tags.className = "card-tags";
      const available = document.createElement("span");
      available.className = "tag-available";
      available.textContent = "CONFIGURED BUILD";
      const code = document.createElement("span");
      code.className = "card-code";
      code.textContent = "EG / " + String(index + 1).padStart(3, "0");
      tags.append(available, code);

      const heading = document.createElement("h3");
      heading.textContent = "Eaglercraft " + entry.version;
      const description = document.createElement("p");
      description.textContent = "Launch this version from your VEYAORA library.";
      const launch = document.createElement("button");
      launch.type = "button";
      launch.className = "card-launch";
      launch.textContent = "LAUNCH VERSION ";
      const arrow = document.createElement("span");
      arrow.textContent = "↗";
      launch.appendChild(arrow);
      launch.addEventListener("click", () => launchVersion(entry));

      body.append(tags, heading, description, launch);
      card.append(art, body);
      otherVersionsGrid.appendChild(card);
    });

    otherVersionsSection.hidden = EXTRA_VERSIONS.length === 0;
  }

  function launchVersion(entry) {
    selectedGameSrc = "eaglercraft/" + entry.file;
    selectedGameVersion = entry.version;
    gameLoaded = false;
    if (gameFrame) {
      gameFrame.classList.remove("loaded");
      gameFrame.title = "Eaglercraft " + selectedGameVersion;
    }
    const loaderText = document.querySelector(".loader-text");
    if (loaderText) loaderText.textContent = "BOOTING EAGLERCRAFT " + selectedGameVersion;
    showGame();
  }

  renderExtraVersions();

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

  function showDefaultGame() {
    selectedGameSrc = GAME_SRC;
    selectedGameVersion = GAME_VERSION;
    gameLoaded = false;
    if (gameFrame) {
      gameFrame.classList.remove("loaded");
      gameFrame.title = "Eaglercraft " + GAME_VERSION;
    }
    const loaderText = document.querySelector(".loader-text");
    if (loaderText) loaderText.textContent = "BOOTING EAGLERCRAFT " + GAME_VERSION;
    showGame();
  }

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
    if (gameLoaded && gameFrame.src.endsWith(selectedGameSrc)) {
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
    gameFrame.src = selectedGameSrc;
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

  playBtn.addEventListener("click", showDefaultGame);
  if (versionCurrent) versionCurrent.addEventListener("click", showDefaultGame);
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
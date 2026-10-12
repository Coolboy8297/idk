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
    { version: "1.5.2", file: "1.5.2.html" },
    { version: "Beta 1.7.3", file: "b1.7.3.html" },
    { version: "Beta 1.3", file: "b1.3.html" },
    { version: "Indev", file: "indev.html" },
  ];
  // Public Firebase web-app configuration is kept in js/firebase-config.js.
  const FIREBASE_CONFIG = window.VEYAORA_FIREBASE_CONFIG || null;

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
    const hasPlaceholderConfig = !FIREBASE_CONFIG ||
      !FIREBASE_CONFIG.apiKey ||
      String(FIREBASE_CONFIG.apiKey).includes("PASTE_") ||
      !FIREBASE_CONFIG.databaseURL ||
      String(FIREBASE_CONFIG.databaseURL).includes("PASTE_") ||
      !FIREBASE_CONFIG.projectId ||
      String(FIREBASE_CONFIG.projectId).includes("PASTE_") ||
      !FIREBASE_CONFIG.appId ||
      String(FIREBASE_CONFIG.appId).includes("PASTE_");

    if (hasPlaceholderConfig || !window.firebase || !firebase.auth || !firebase.database) {
      if (liveVisitorsEl) liveVisitorsEl.textContent = "—";
      if (visitorStatusEl) visitorStatusEl.textContent = "FIREBASE SETUP REQUIRED";
      return;
    }

    try {
      if (!firebase.apps.length) firebase.initializeApp(FIREBASE_CONFIG);
      const auth = firebase.auth();
      const db = firebase.database();
      const presence = db.ref("presence/veyaora");

      auth.signInAnonymously().then(() => {
        const uid = auth.currentUser && auth.currentUser.uid;
        if (!uid) throw new Error("Anonymous sign-in returned no user ID");

        const connected = db.ref(".info/connected");
        const mine = presence.child(uid);

        connected.on("value", snapshot => {
          if (snapshot.val() !== true) {
            if (visitorStatusEl) visitorStatusEl.textContent = "CONNECTING…";
            return;
          }

          mine.onDisconnect().remove()
            .then(() => mine.set({ since: firebase.database.ServerValue.TIMESTAMP }))
            .then(() => {
              if (visitorStatusEl) visitorStatusEl.textContent = "LIVE RIGHT NOW";
            })
            .catch(error => {
              if (visitorStatusEl) visitorStatusEl.textContent = "DATABASE RULES NEED SETUP";
              console.warn("VEYAORA presence write:", error);
            });
        });

        presence.on("value", snapshot => {
          if (liveVisitorsEl) liveVisitorsEl.textContent = String(snapshot.numChildren());
        }, error => {
          if (visitorStatusEl) visitorStatusEl.textContent = "DATABASE RULES NEED SETUP";
          console.warn("VEYAORA presence read:", error);
        });
      }).catch(error => {
        if (visitorStatusEl) visitorStatusEl.textContent = "AUTH SETUP REQUIRED";
        console.warn("VEYAORA anonymous authentication:", error);
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
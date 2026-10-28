/**
 * VEYAORA ARCADE — Eaglercraft 26.2 launcher
 * Main build: eaglercraft/index.html
 */
(function () {
  "use strict";
  // MAIN VERSION: Eaglercraft 26.2.
  // The local Eaglercraft client is served from this repository.
  const GAME_URL = "eaglercraft/index.html?v=26.2-restored-20261020";
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
  const gameFrame = document.getElementById("game-frame");
  const gameLoader = document.getElementById("game-loader");
  const statusText = document.getElementById("status-text");
  const gameVersionEl = document.getElementById("game-version");
  const liveVisitorsEl = document.getElementById("live-visitors");
  const visitorStatusEl = document.getElementById("visitor-status");
  const otherVersionsSection = document.getElementById("other-versions-section");
  const otherVersionsGrid = document.getElementById("other-versions-grid");
  let gameLoaded = false;
  let activeGameUrl = GAME_URL;
  let activeGameTitle = "Eaglercraft 26.2";

  if (gameVersionEl) gameVersionEl.textContent = GAME_VERSION;

  function renderExtraVersions() {
    if (!otherVersionsSection || !otherVersionsGrid) return;
    otherVersionsGrid.replaceChildren();

    EXTRA_VERSIONS.forEach((entry, index) => {
      if (!entry || !entry.version || (!entry.file && !entry.externalUrl)) return;

      const card = document.createElement("article");
      card.className = "game-card game-card-featured extra-version-card";

      const art = document.createElement("div");
      art.className = "card-art art-262";
      const artLabel = document.createElement("span");
      artLabel.className = "art-label";
      artLabel.textContent = entry.externalUrl ? "MODPACK" : "EXTRA BUILD";
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
      description.textContent = entry.description || "Launch this version from your VEYAORA library.";
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
    if (entry.externalUrl) {
      window.open(entry.externalUrl, "_blank", "noopener,noreferrer");
      return;
    }
    window.open("eaglercraft/" + entry.file, "_blank", "noopener,noreferrer");
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
    showGame(GAME_URL, "Eaglercraft 26.2");
  }

  function showGame(url = GAME_URL, title = "Eaglercraft 26.2") {
    activeGameUrl = url;
    activeGameTitle = title;
    gameFrame.title = title;
    homeView.classList.remove("active");
    gameView.classList.add("active");
    document.body.style.overflow = "hidden";
    loadGame();
  }
  function loadGame() {
    if (gameLoaded && gameFrame.src.endsWith(activeGameUrl)) {
      gameLoader.classList.add("hidden");
      gameFrame.classList.add("loaded");
      if (statusText) statusText.textContent = "GAME ACTIVE";
      return;
    }

    gameLoaded = false;
    gameFrame.classList.remove("loaded");
    gameLoader.classList.remove("hidden");
    const loaderText = document.getElementById("loader-text");
    if (loaderText) loaderText.textContent = "BOOTING " + activeGameTitle.toUpperCase();
    if (statusText) statusText.textContent = "BOOTING GAME";

    gameFrame.onload = () => {
      gameLoaded = true;
      gameFrame.classList.add("loaded");
      gameLoader.classList.add("hidden");
      if (statusText) statusText.textContent = "GAME ACTIVE";
    };

    gameFrame.onerror = () => {
      gameLoaded = false;
      if (loaderText) loaderText.textContent = "GAME COULD NOT LOAD";
      if (statusText) statusText.textContent = "GAME FAILED TO LOAD";
      console.error("VEYAORA Arcade could not load:", activeGameUrl);
    };

    gameFrame.src = activeGameUrl;
  }


  // Console suite: local search, favorites, recent games, settings, and friends preview.
  const readLocal = (key, fallback) => {
    try { const v = localStorage.getItem(key); return v === null ? fallback : JSON.parse(v); }
    catch (_) { return fallback; }
  };
  const writeLocal = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} };
  const searchBox = document.getElementById("game-search");
  const filters = Array.from(document.querySelectorAll(".store-filter[data-filter]"));
  const favoritesButton = document.getElementById("show-favorites");
  const recentBox = document.getElementById("recent-games");
  let currentFilter = "all";
  let favoritesOnly = false;
  let favorites = readLocal("veyaoraFavorites", []);
  let recents = readLocal("veyaoraRecentGames", []);

  const cards = () => Array.from(document.querySelectorAll(".library-grid .game-card"));
  const titleOf = card => card.querySelector("h3")?.textContent.trim() || "Game";
  const keyOf = card => (card.id || titleOf(card)).toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const categoryOf = card => /experimental|android lab|xbox lab|afterburner/i.test(card.textContent) ? "experimental" : "browser";

  function filterGames() {
    const q = (searchBox?.value || "").trim().toLowerCase();
    cards().forEach(card => {
      card.hidden = !(card.textContent.toLowerCase().includes(q) &&
        (currentFilter === "all" || categoryOf(card) === currentFilter) &&
        (!favoritesOnly || favorites.includes(keyOf(card))));
    });
    const extras = document.getElementById("other-versions-section");
    if (extras) extras.hidden = !Array.from(extras.querySelectorAll(".game-card")).some(card => !card.hidden);
  }

  function addFavoriteButtons() {
    cards().forEach(card => {
      const body = card.querySelector(".card-body");
      const launch = body?.querySelector(".card-launch");
      if (!body || !launch || body.querySelector(".favorite-toggle")) return;
      const row = document.createElement("div");
      row.className = "card-tools-row";
      const fav = document.createElement("button");
      fav.type = "button";
      fav.className = "favorite-toggle";
      const refresh = () => {
        const yes = favorites.includes(keyOf(card));
        fav.textContent = yes ? "♥" : "♡";
        fav.classList.toggle("is-favorite", yes);
        fav.setAttribute("aria-pressed", String(yes));
        fav.setAttribute("aria-label", (yes ? "Remove " : "Add ") + titleOf(card) + " " + (yes ? "from" : "to") + " favorites");
      };
      fav.addEventListener("click", () => {
        favorites = favorites.includes(keyOf(card)) ? favorites.filter(k => k !== keyOf(card)) : [...favorites, keyOf(card)];
        writeLocal("veyaoraFavorites", favorites);
        refresh();
        filterGames();
      });
      launch.parentNode.insertBefore(row, launch);
      row.append(launch, fav);
      refresh();
    });
  }

  function drawRecents() {
    if (!recentBox) return;
    recentBox.replaceChildren();
    if (!recents.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "Your recently played games will appear here.";
      recentBox.appendChild(empty);
      return;
    }
    recents.slice(0, 4).forEach(game => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "recent-game";
      const art = document.createElement("span");
      art.className = "recent-art";
      art.textContent = game.mark || "V.";
      const copy = document.createElement("span");
      copy.className = "recent-game-copy";
      const title = document.createElement("strong");
      title.textContent = game.title;
      const hint = document.createElement("small");
      hint.textContent = "PLAY AGAIN ↗";
      copy.append(title, hint);
      button.append(art, copy);
      button.addEventListener("click", () => {
        if (game.url.startsWith("http") || game.url.startsWith("/")) window.open(game.url, "_blank", "noopener,noreferrer");
        else showGame(game.url, game.title);
      });
      recentBox.appendChild(button);
    });
  }
  function rememberRecent(title, url, mark) {
    recents = [{ key: title.toLowerCase(), title, url, mark: mark || "V." }, ...recents.filter(g => g.title !== title)].slice(0, 8);
    writeLocal("veyaoraRecentGames", recents);
    drawRecents();
  }
  filters.forEach(button => button.addEventListener("click", () => {
    currentFilter = button.dataset.filter || "all";
    filters.forEach(b => b.classList.toggle("is-selected", b === button));
    filterGames();
  }));
  searchBox?.addEventListener("input", filterGames);
  favoritesButton?.addEventListener("click", () => {
    favoritesOnly = !favoritesOnly;
    favoritesButton.setAttribute("aria-pressed", String(favoritesOnly));
    favoritesButton.classList.toggle("is-selected", favoritesOnly);
    filterGames();
  });
  document.getElementById("clear-recent")?.addEventListener("click", () => {
    recents = [];
    writeLocal("veyaoraRecentGames", recents);
    drawRecents();
  });

  const settingsDialog = document.getElementById("settings-dialog");
  const friendsDialog = document.getElementById("friends-dialog");
  function openDialog(dialog) { if (dialog) { dialog.hidden = false; dialog.querySelector("[data-close-dialog]")?.focus(); } }
  function closeDialogs() { [settingsDialog, friendsDialog].forEach(d => { if (d) d.hidden = true; }); }
  document.getElementById("open-settings")?.addEventListener("click", () => openDialog(settingsDialog));
  document.getElementById("network-settings-button")?.addEventListener("click", () => openDialog(settingsDialog));
  document.getElementById("open-friends")?.addEventListener("click", () => openDialog(friendsDialog));
  document.getElementById("network-friends-button")?.addEventListener("click", () => openDialog(friendsDialog));
  document.querySelectorAll("[data-close-dialog]").forEach(b => b.addEventListener("click", closeDialogs));
  [settingsDialog, friendsDialog].forEach(d => d?.addEventListener("click", e => { if (e.target === d) closeDialogs(); }));
  document.addEventListener("keydown", e => { if (e.key === "Escape") closeDialogs(); });

  const accent = document.getElementById("accent-setting");
  const motion = document.getElementById("motion-setting");
  const savedAccent = readLocal("veyaoraAccent", "green");
  document.body.classList.add("accent-" + (["green","cyan","blue"].includes(savedAccent) ? savedAccent : "green"));
  if (accent) {
    accent.value = savedAccent;
    accent.addEventListener("change", () => {
      document.body.classList.remove("accent-green","accent-cyan","accent-blue");
      document.body.classList.add("accent-" + accent.value);
      writeLocal("veyaoraAccent", accent.value);
    });
  }
  if (motion) {
    motion.checked = Boolean(readLocal("veyaoraReduceMotion", false));
    document.body.classList.toggle("reduce-motion", motion.checked);
    motion.addEventListener("change", () => {
      document.body.classList.toggle("reduce-motion", motion.checked);
      writeLocal("veyaoraReduceMotion", motion.checked);
    });
  }

  // Remember game launches without changing the existing launch flow.
  const showGameOriginal = showGame;
  showGame = function(url = GAME_URL, title = "Eaglercraft 26.2") {
    rememberRecent(title, url, title.toLowerCase().includes("neon") ? "NR" : "V.");
    showGameOriginal(url, title);
  };
  cards().forEach(card => {
    const launch = card.querySelector(".card-launch");
    if (!launch || launch.dataset.recentTracked) return;
    launch.dataset.recentTracked = "1";
    launch.addEventListener("click", () => {
      const title = titleOf(card);
      const href = launch.getAttribute("href");
      const url = card.id === "available" ? GAME_URL :
        card.querySelector("#launch-neon-run") ? "neon-runner/Neon-Runner.html" :
        (href || (title.toLowerCase().includes("neon") ? "neon-runner/Neon-Runner.html" : GAME_URL));
      rememberRecent(title, url, title.slice(0,2).toUpperCase());
    }, true);
  });
  drawRecents();
  addFavoriteButtons();
  filterGames();

  playBtn.addEventListener("click", showDefaultGame);
  if (versionCurrent) versionCurrent.addEventListener("click", showDefaultGame);
  const neonRunButton = document.getElementById("launch-neon-run");
  if (neonRunButton) neonRunButton.addEventListener("click", () => showGame("neon-runner/Neon-Runner.html", "Neon Runner"));
})();
/* VEYΛORA ARCADE — console dashboard controller */
(() => {
  "use strict";
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const GAME_URL = "eaglercraft/index.html?v=26.2-restored-20261020";
  const EXTRA_VERSIONS = [
    { version: "1.8.8", file: "1.8.8.html" },
    { version: "1.5.2", file: "1.5.2.html" },
    { version: "Beta 1.7.3", file: "b1.7.3.html" },
    { version: "Beta 1.3", file: "b1.3.html" },
    { version: "Indev", file: "indev.html" }
  ];
  const ALLOWED_PLAYERS = ["colton", "ethan", "john", "noah"];
  const AVATARS = ["V.", "⚡", "🎮", "👾", "🦊", "🚀", "🌙", "💠"];
  const store = {
    get(key, fallback) { try { const value = localStorage.getItem(key); return value === null ? fallback : JSON.parse(value); } catch (_) { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} }
  };
  let activePlayer = "Colton";
  let currentView = "discover";
  let activeFilter = "all";
  let favoritesOnly = false;
  let favorites = store.get("veyaoraFavorites", []);
  let recentGames = store.get("veyaoraRecentGames", []);
  let activeGameUrl = GAME_URL;
  let activeGameTitle = "Eaglercraft 26.2";
  let gameTimeout = null;

  const profileKey = player => "veyaoraProfile_" + player.toLowerCase();
  const getProfile = player => {
    const saved = store.get(profileKey(player), {});
    return {
      displayName: typeof saved.displayName === "string" && saved.displayName.trim() ? saved.displayName.trim().slice(0, 18) : player,
      avatar: AVATARS.includes(saved.avatar) ? saved.avatar : player.charAt(0).toUpperCase()
    };
  };
  const saveProfile = (player, profile) => store.set(profileKey(player), profile);
  const profileClass = player => ({colton:"avatar-v",ethan:"avatar-e",john:"avatar-j",noah:"avatar-n"}[player.toLowerCase()] || "avatar-v");

  const boot = $("#boot-screen");
  const login = $("#login-view");
  const home = $("#home-view");
  const gameScreen = $("#game-view");
  const loginForm = $("#login-form");
  const loginName = $("#login-name");
  const loginPassword = $("#login-password");
  const loginError = $("#login-error");
  const settingsDialog = $("#settings-dialog");
  const friendsDialog = $("#friends-dialog");
  const profileMenu = $("#profile-menu");

  function showLogin() {
    boot.hidden = true;
    home.hidden = true;
    gameScreen.hidden = true;
    login.hidden = false;
    loginError.textContent = "";
    loginPassword.value = "";
    document.body.style.overflow = "";
  }
  function showHome() {
    boot.hidden = true;
    login.hidden = true;
    gameScreen.hidden = true;
    home.hidden = false;
    document.body.style.overflow = "";
    closeOverlays();
    applyProfileToUI();
    setView("discover");
  }
  function beginBoot() {
    const storedPlayer = sessionStorage.getItem("veyaoraArcadeLoggedIn");
    const player = ALLOWED_PLAYERS.find(name => name.toLowerCase() === String(storedPlayer || "").toLowerCase());
    $("#boot-status").textContent = player ? "RESTORING PLAYER SESSION" : "INITIALIZING ARCADE SERVICES";
    const finish = () => {
      if (boot.hidden) return;
      boot.hidden = true;
      if (player) { activePlayer = player; showHome(); }
      else showLogin();
    };
    const timer = window.setTimeout(finish, 2450);
    $("#skip-boot").addEventListener("click", () => { window.clearTimeout(timer); finish(); });
  }

  function refreshProfilePicker() {
    $$(".profile-choice").forEach(button => {
      const player = button.dataset.player;
      const profile = getProfile(player);
      const avatar = $(".avatar", button);
      const name = $("span:last-child", button);
      if (avatar) {
        avatar.textContent = profile.avatar;
        avatar.className = "avatar " + profileClass(player);
        if (AVATARS.includes(profile.avatar) && profile.avatar.length > 1) avatar.classList.add("avatar-custom");
      }
      if (name) name.textContent = profile.displayName;
    });
  }

  function setPlayerSelection(player) {
    loginName.value = player;
    $$(".profile-choice").forEach(button => {
      const selected = button.dataset.player.toLowerCase() === player.toLowerCase();
      button.classList.toggle("selected", selected);
      button.setAttribute("aria-pressed", String(selected));
    });
  }
  $$(".profile-choice").forEach(button => button.addEventListener("click", () => setPlayerSelection(button.dataset.player)));
  loginName.addEventListener("input", () => {
    $$(".profile-choice").forEach(button => {
      const selected = button.dataset.player.toLowerCase() === loginName.value.trim().toLowerCase();
      button.classList.toggle("selected", selected);
      button.setAttribute("aria-pressed", String(selected));
    });
  });
  loginForm.addEventListener("submit", event => {
    event.preventDefault();
    const submitted = loginName.value.trim();
    const player = ALLOWED_PLAYERS.find(name => name.toLowerCase() === submitted.toLowerCase());
    if (!player || loginPassword.value !== "letmein") {
      loginError.textContent = "Access denied. Check the player name and password.";
      loginPassword.value = "";
      loginPassword.focus();
      return;
    }
    activePlayer = player;
    sessionStorage.setItem("veyaoraArcadeLoggedIn", player);
    showHome();
  });

  function applyProfileToUI() {
    const profile = getProfile(activePlayer);
    const initial = profile.avatar || activePlayer.charAt(0).toUpperCase();
    const elements = [$("#sidebar-avatar"), $("#top-avatar"), $("#profile-edit-avatar")];
    elements.forEach(el => {
      if (!el) return;
      el.textContent = initial;
      el.className = "avatar " + profileClass(activePlayer);
      if (AVATARS.includes(initial) && initial.length > 1) el.classList.add("avatar-custom");
    });
    ["#sidebar-username", "#top-username", "#welcome-username", "#profile-edit-name"].forEach(selector => {
      const el = $(selector);
      if (el) el.textContent = profile.displayName;
    });
    const displayInput = $("#display-name-input");
    if (displayInput) displayInput.value = profile.displayName;
    const footer = $("#footer-player");
    if (footer) footer.textContent = "PLAYER / " + profile.displayName.toUpperCase();
    $$("#avatar-options button").forEach(button => button.classList.toggle("selected", button.dataset.avatar === initial));
  }

  function setView(view) {
    currentView = view;
    $$(".nav-item[data-view]").forEach(button => button.classList.toggle("active", button.dataset.view === view));
    const crumb = $("#breadcrumb-current");
    const heading = $("#library-heading");
    const librarySection = $("#library-section");
    const hero = $(".hero-card");
    const continueSection = $(".continue-section");
    const titleMap = {discover:"HOME", library:"GAME LIBRARY", favorites:"FAVORITES"};
    if (crumb) crumb.textContent = titleMap[view] || "HOME";
    if (heading) heading.innerHTML = view === "favorites" ? 'Your favorites<span class="accent-dot">.</span>' : 'Game library<span class="accent-dot">.</span>';
    if (hero) hero.hidden = view !== "discover";
    if (continueSection) continueSection.hidden = view === "favorites";
    if (librarySection) librarySection.hidden = view === "discover";
    if (view === "favorites") {
      favoritesOnly = true;
      updateFavoriteFilterButton();
    } else if (view !== "favorites") {
      favoritesOnly = false;
      updateFavoriteFilterButton();
    }
    applyGameFilters();
    if (view !== "discover") librarySection?.scrollIntoView({behavior:document.body.classList.contains("reduce-motion") ? "auto" : "smooth", block:"start"});
    else window.scrollTo({top:0,behavior:document.body.classList.contains("reduce-motion") ? "auto" : "smooth"});
  }
  $$("[data-view]").forEach(button => button.addEventListener("click", () => setView(button.dataset.view)));
  $("#hero-library").addEventListener("click", () => setView("library"));

  function gameCards() {
    return $$(".game-card[data-game]");
  }
  function updateFavoriteButtons() {
    $$("[data-favorite]").forEach(button => {
      const yes = favorites.includes(button.dataset.favorite);
      button.classList.toggle("is-favorite", yes);
      button.textContent = yes ? "♥" : "♡";
      button.setAttribute("aria-pressed", String(yes));
    });
  }
  function updateFavoriteFilterButton() {
    const button = $("#show-favorites");
    if (!button) return;
    button.classList.toggle("active", favoritesOnly);
    button.setAttribute("aria-pressed", String(favoritesOnly));
  }
  function applyGameFilters() {
    const query = ($("#game-search")?.value || "").trim().toLowerCase();
    let visible = 0;
    gameCards().forEach(card => {
      const matchesQuery = !query || (card.dataset.game + " " + card.textContent).toLowerCase().includes(query);
      const matchesCategory = activeFilter === "all" || card.dataset.category === activeFilter;
      const favKey = card.querySelector("[data-favorite]")?.dataset.favorite;
      const matchesFavorite = !favoritesOnly || favorites.includes(favKey);
      const show = matchesQuery && matchesCategory && matchesFavorite;
      card.hidden = !show;
      if (show) visible++;
    });
    const noGames = $("#no-games");
    if (noGames) noGames.hidden = visible > 0;
    const count = $("#library-count");
    if (count) count.textContent = String(visible).padStart(2, "0");
    const extras = $("#other-versions-section");
    if (extras) {
      const extraCards = $$(".extra-version-card", extras);
      extraCards.forEach(card => {
        const title = card.dataset.game || card.textContent;
        card.hidden = !!query && !title.toLowerCase().includes(query);
      });
      extras.hidden = extraCards.length === 0 || !extraCards.some(card => !card.hidden);
    }
  }
  $("#game-search").addEventListener("input", applyGameFilters);
  $$(".filter-button").forEach(button => button.addEventListener("click", () => {
    activeFilter = button.dataset.filter;
    $$(".filter-button").forEach(item => item.classList.toggle("active", item === button));
    applyGameFilters();
  }));
  $("#reset-search").addEventListener("click", () => {
    $("#game-search").value = "";
    activeFilter = "all";
    favoritesOnly = false;
    $$(".filter-button").forEach(button => button.classList.toggle("active", button.dataset.filter === "all"));
    updateFavoriteFilterButton();
    applyGameFilters();
  });
  $$("[data-favorite]").forEach(button => button.addEventListener("click", () => {
    const key = button.dataset.favorite;
    favorites = favorites.includes(key) ? favorites.filter(item => item !== key) : [...favorites, key];
    store.set("veyaoraFavorites", favorites);
    updateFavoriteButtons();
    applyGameFilters();
  }));
  $("#show-favorites")?.addEventListener("click", () => {
    favoritesOnly = !favoritesOnly;
    updateFavoriteFilterButton();
    applyGameFilters();
  });

  function rememberRecent(title, url, mark, kind = "local") {
    recentGames = [{title,url,mark,kind}, ...recentGames.filter(game => game.title !== title)].slice(0,8);
    store.set("veyaoraRecentGames", recentGames);
    renderRecents();
  }
  function renderRecents() {
    const container = $("#recent-games");
    container.replaceChildren();
    if (!recentGames.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "No recent sessions yet. Launch a game and it will show up here.";
      container.appendChild(empty);
      return;
    }
    recentGames.slice(0,4).forEach(game => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "recent-game";
      const art = document.createElement("span");
      art.className = "recent-art";
      art.textContent = game.mark || "V.";
      const copy = document.createElement("span");
      copy.className = "recent-copy";
      const title = document.createElement("strong");
      title.textContent = game.title;
      const hint = document.createElement("small");
      hint.textContent = "PLAY AGAIN ↗";
      copy.append(title,hint);
      button.append(art,copy);
      button.addEventListener("click", () => launchGame(game.url, game.title, game.kind));
      container.appendChild(button);
    });
  }
  $("#clear-recent").addEventListener("click", () => {
    recentGames = [];
    store.set("veyaoraRecentGames", recentGames);
    renderRecents();
  });

  function launchGame(url, title, kind = "local") {
    if (kind === "external") {
      window.open(url, "_blank", "noopener,noreferrer");
      return;
    }
    activeGameUrl = url;
    activeGameTitle = title;
    $("#game-title").textContent = title;
    $("#game-frame").title = title;
    $("#loader-text").textContent = "STARTING " + title.toUpperCase();
    $("#game-loader").hidden = false;
    $("#game-frame").classList.remove("loaded");
    gameScreen.hidden = false;
    home.hidden = true;
    document.body.style.overflow = "hidden";
    if (gameTimeout) window.clearTimeout(gameTimeout);
    gameTimeout = window.setTimeout(() => {
      if (!$("#game-frame").classList.contains("loaded")) $("#loader-text").textContent = "STILL LOADING · CHECK THE GAME WINDOW";
    }, 12000);
    $("#game-frame").onload = () => {
      $("#game-frame").classList.add("loaded");
      $("#game-loader").hidden = true;
      if (gameTimeout) window.clearTimeout(gameTimeout);
      $("#status-text").textContent = "GAME ACTIVE";
    };
    $("#game-frame").onerror = () => {
      $("#loader-text").textContent = "GAME COULD NOT LOAD · TRY RELOAD";
      $("#game-loader").hidden = false;
      if (gameTimeout) window.clearTimeout(gameTimeout);
    };
    if ($("#game-frame").getAttribute("src") !== url) $("#game-frame").src = url;
    else {
      try { $("#game-frame").contentWindow.location.reload(); }
      catch (_) { $("#game-frame").src = url; }
    }
    rememberRecent(title,url,title.toLowerCase().includes("neon") ? "NR" : title.slice(0,2).toUpperCase(),kind);
  }
  $("#play-btn").addEventListener("click", () => launchGame(GAME_URL,"Eaglercraft 26.2"));
  $$("[data-launch]").forEach(button => button.addEventListener("click", () => {
    const key = button.dataset.launch;
    const routes = {
      eaglercraft: {url:GAME_URL,title:"Eaglercraft 26.2",kind:"local"},
      neon: {url:"neon-runner/Neon-Runner.html",title:"Neon Run",kind:"local"},
      android: {url:"https://github.com/Z3BOS/afterburner",title:"Android Lab",kind:"external"},
      xbox: {url:"/idk/xbox360/",title:"VEYΛORA Xbox Lab",kind:"local"},
      ssf2: {url:"https://www.supersmashflash.com/play/ssf2/?ruffle=true",title:"Super Smash Flash 2 · Ruffle",kind:"local"}
    };
    const route = routes[key];
    if (route) launchGame(route.url,route.title,route.kind);
  }));
  function renderExtraVersions() {
    const section = $("#other-versions-section");
    const grid = $("#other-versions-grid");
    if (!section || !grid) return;
    grid.replaceChildren();
    EXTRA_VERSIONS.forEach((entry,index) => {
      const card = document.createElement("article");
      card.className = "game-card extra-version-card";
      card.dataset.game = "Eaglercraft " + entry.version;
      const art = document.createElement("div");
      art.className = "game-art art-eagler";
      const chip = document.createElement("span");
      chip.className = "art-chip";
      chip.textContent = "EXTRA BUILD";
      const number = document.createElement("div");
      number.className = "art-title";
      number.textContent = entry.version;
      const foot = document.createElement("span");
      foot.className = "art-foot";
      foot.textContent = "EAGLERCRAFT / " + entry.version;
      art.append(chip,number,foot);
      const info = document.createElement("div");
      info.className = "game-info";
      const meta = document.createElement("div");
      meta.className = "game-meta";
      const status = document.createElement("span");
      status.className = "available-dot";
      status.textContent = "● CONFIGURED BUILD";
      meta.appendChild(status);
      const title = document.createElement("h3");
      title.textContent = "Eaglercraft " + entry.version;
      const description = document.createElement("p");
      description.textContent = "Launch this alternate build in its own game window.";
      const launch = document.createElement("button");
      launch.type = "button";
      launch.className = "button button-card";
      launch.innerHTML = 'LAUNCH VERSION <span>↗</span>';
      launch.addEventListener("click", () => launchGame("eaglercraft/" + entry.file,"Eaglercraft " + entry.version));
      info.append(meta,title,description,launch);
      card.append(art,info);
      grid.appendChild(card);
    });
    section.hidden = false;
  }

  function openDialog(dialog) {
    closeProfileMenu();
    if (dialog) {
      dialog.hidden = false;
      const close = $("[data-close-dialog]",dialog);
      close?.focus();
    }
  }
  function closeOverlays() {
    [settingsDialog,friendsDialog].forEach(dialog => { if (dialog) dialog.hidden = true; });
    closeProfileMenu();
  }
  function closeProfileMenu() { if (profileMenu) profileMenu.hidden = true; }
  $$("[data-close-dialog]").forEach(button => button.addEventListener("click",closeOverlays));
  [settingsDialog,friendsDialog].forEach(dialog => dialog.addEventListener("click",event => { if (event.target === dialog) closeOverlays(); }));
  document.addEventListener("keydown",event => {
    if (event.key === "Escape") {
      closeOverlays();
      if (!gameScreen.hidden) exitGame();
    }
  });
  $("#nav-friends").addEventListener("click",() => openDialog(friendsDialog));
  $("#top-friends").addEventListener("click",() => openDialog(friendsDialog));
  $("#nav-settings").addEventListener("click",() => openDialog(settingsDialog));
  $("#top-settings").addEventListener("click",() => openDialog(settingsDialog));
  $("#network-settings-button")?.addEventListener("click",() => openDialog(settingsDialog));
  $("#network-friends-button")?.addEventListener("click",() => openDialog(friendsDialog));
  $("#sidebar-profile").addEventListener("click",() => { profileMenu.hidden = !profileMenu.hidden; });
  $("#top-profile").addEventListener("click",() => { profileMenu.hidden = !profileMenu.hidden; });
  $("#edit-profile").addEventListener("click",() => { openDialog(settingsDialog); selectSettingsTab("profile"); });
  $("#open-profile-settings").addEventListener("click",() => { openDialog(settingsDialog); selectSettingsTab("profile"); });
  $("#profile-signout").addEventListener("click",signOut);
  $("#sign-out").addEventListener("click",signOut);
  function signOut() {
    closeOverlays();
    sessionStorage.removeItem("veyaoraArcadeLoggedIn");
    gameScreen.hidden = true;
    home.hidden = true;
    showLogin();
    setPlayerSelection(activePlayer);
  }

  function selectSettingsTab(tab) {
    $$(".settings-tab").forEach(button => button.classList.toggle("active",button.dataset.settingsTab === tab));
    $$(".settings-pane").forEach(pane => { pane.hidden = pane.dataset.settingsPane !== tab; });
    $("#settings-feedback").textContent = "";
    if (tab === "profile") applyProfileToUI();
  }
  $$(".settings-tab").forEach(button => button.addEventListener("click",() => selectSettingsTab(button.dataset.settingsTab)));
  $("#display-name-input").addEventListener("input",() => { $("#profile-edit-name").textContent = $("#display-name-input").value || activePlayer; });
  $("#avatar-options").addEventListener("click",event => {
    const button = event.target.closest("[data-avatar]");
    if (!button) return;
    $$("#avatar-options button").forEach(item => item.classList.toggle("selected",item === button));
    $("#profile-edit-avatar").textContent = button.dataset.avatar;
  });
  $("#save-profile").addEventListener("click",() => {
    const displayName = $("#display-name-input").value.trim().slice(0,18) || activePlayer;
    const avatar = $("[data-avatar].selected",$("#avatar-options"))?.dataset.avatar || getProfile(activePlayer).avatar;
    saveProfile(activePlayer,{displayName,avatar});
    applyProfileToUI();
    refreshProfilePicker();
    $("#settings-feedback").textContent = "PROFILE SAVED.";
  });

  const accentSetting = $("#accent-setting");
  const motionSetting = $("#motion-setting");
  const validAccents = ["green","cyan","blue","violet"];
  function applyAccent(value) {
    document.body.classList.remove("accent-cyan","accent-blue","accent-violet");
    if (validAccents.includes(value) && value !== "green") document.body.classList.add("accent-" + value);
    if (accentSetting) accentSetting.value = validAccents.includes(value) ? value : "green";
  }
  const savedAccent = store.get("veyaoraAccent","green");
  applyAccent(savedAccent);
  accentSetting.addEventListener("change",() => {
    applyAccent(accentSetting.value);
    store.set("veyaoraAccent",accentSetting.value);
    $("#settings-feedback").textContent = "APPEARANCE UPDATED.";
  });
  const savedMotion = Boolean(store.get("veyaoraReduceMotion",false));
  motionSetting.checked = savedMotion;
  document.body.classList.toggle("reduce-motion",savedMotion);
  motionSetting.addEventListener("change",() => {
    document.body.classList.toggle("reduce-motion",motionSetting.checked);
    store.set("veyaoraReduceMotion",motionSetting.checked);
    $("#settings-feedback").textContent = "MOTION PREFERENCE SAVED.";
  });
  $("#reset-settings").addEventListener("click",() => {
    store.set("veyaoraAccent","green");
    store.set("veyaoraReduceMotion",false);
    applyAccent("green");
    motionSetting.checked = false;
    document.body.classList.remove("reduce-motion");
    $("#settings-feedback").textContent = "APPEARANCE RESET.";
  });

  function exitGame() {
    gameScreen.hidden = true;
    home.hidden = false;
    document.body.style.overflow = "";
    $("#status-text").textContent = "SYSTEM READY";
    window.scrollTo({top:0,behavior:document.body.classList.contains("reduce-motion") ? "auto" : "smooth"});
  }
  $("#exit-game").addEventListener("click",exitGame);
  $("#reload-game").addEventListener("click",() => {
    $("#game-loader").hidden = false;
    $("#loader-text").textContent = "RESTARTING GAME";
    try { $("#game-frame").contentWindow.location.reload(); }
    catch (_) { $("#game-frame").src = activeGameUrl; }
  });
  $("#retry-game").addEventListener("click",() => {
    $("#game-loader").hidden = false;
    $("#loader-text").textContent = "RETRYING GAME";
    $("#game-frame").src = activeGameUrl;
  });
  $("#fullscreen-game").addEventListener("click",async () => {
    const target = $("#game-container");
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (target.requestFullscreen) await target.requestFullscreen();
      else $("#game-frame").requestFullscreen?.();
    } catch (_) {
      $("#loader-text").textContent = "USE YOUR BROWSER FULLSCREEN CONTROL";
      $("#game-loader").hidden = false;
    }
  });

  function setupLiveVisitors() {
    const config = window.VEYAORA_FIREBASE_CONFIG || null;
    const count = $("#live-visitors");
    if (!config || !config.apiKey || !config.databaseURL || !config.projectId || !config.appId || !window.firebase) return;
    try {
      if (!firebase.apps.length) firebase.initializeApp(config);
      const auth = firebase.auth();
      const presence = firebase.database().ref("presence/veyaora");
      auth.signInAnonymously().then(() => {
        const uid = auth.currentUser && auth.currentUser.uid;
        if (!uid) return;
        const mine = presence.child(uid);
        firebase.database().ref(".info/connected").on("value",snapshot => {
          if (snapshot.val() === true) mine.onDisconnect().remove().then(() => mine.set({since:firebase.database.ServerValue.TIMESTAMP}));
        });
        presence.on("value",snapshot => { if (count) count.textContent = String(snapshot.numChildren()); });
      }).catch(() => {});
    } catch (_) {}
  }

  renderExtraVersions();
  updateFavoriteButtons();
  renderRecents();
  applyGameFilters();
  refreshProfilePicker();
  setPlayerSelection("Colton");
  setupLiveVisitors();
  beginBoot();
})();
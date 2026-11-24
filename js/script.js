/* VEYΛORA ARCADE — console dashboard controller */
(() => {
  "use strict";
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const GAME_URL = "eaglercraft/index.html?v=26.2-restored-20261020";
  const EXTRA_VERSIONS = [
    {
      version: "Eagler26",
      file: "Eagler26.html",
      title: "Eagler26",
      url: "https://media.githubusercontent.com/media/Coolboy8297/idk/main/eaglercraft/Eagler26.html"
    },
    { version: "1.8.8", file: "1.8.8.html" },
    { version: "1.5.2", file: "1.5.2.html" },
    { version: "Beta 1.7.3", file: "b1.7.3.html" },
    { version: "Beta 1.3", file: "b1.3.html" },
    { version: "Indev", file: "indev.html" }
  ];
  const ALLOWED_PLAYERS = ["colton", "ethan", "john", "noah"];
  const DECEMBER_ACCESS_DATE = new Date(2026, 11, 1);
  const getRequiredLoginKey = () => new Date() >= DECEMBER_ACCESS_DATE ? "150130056" : "letmein";
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

  const login = $("#login-view");
  const home = $("#home-view");
  const gameScreen = $("#game-view");
  const loginForm = $("#login-form");
  const loginName = $("#login-name");
  const loginPassword = $("#login-password");
  const loginError = $("#login-error");
  const settingsDialog = $("#settings-dialog");
  const friendsDialog = $("#friends-dialog");
  const announcementDialog = $("#december-overhaul-dialog");
  const communityDialog = $("#community-dialog");
  const profileMenu = $("#profile-menu");
  let communityDb = null;
  let communityUser = null;
  let communityPresenceRef = null;
  let communityMessagesRef = null;
  let communityReady = null;
  let lastCommunitySend = 0;
  let notificationRef = null;
  let notificationInitializing = true;
  const knownMessageIds = new Set();
  const pendingMessageNotifications = new Map();
  let unreadCommunityMessages = 0;

  function showLogin() {
    home.hidden = true;
    gameScreen.hidden = true;
    login.hidden = false;
    loginError.textContent = "";
    loginPassword.value = "";
    document.body.style.overflow = "";
  }
  function showHome() {
    login.hidden = true;
    gameScreen.hidden = true;
    home.hidden = false;
    document.body.style.overflow = "";
    closeOverlays();
    applyProfileToUI();
    setView("discover");
    if (announcementDialog && sessionStorage.getItem("veyaoraDecemberOverhaulNotice") !== "shown") {
      sessionStorage.setItem("veyaoraDecemberOverhaulNotice", "shown");
      openDialog(announcementDialog);
    }
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
  const requestPanel = $("#account-request-panel");
  const requestStatus = $("#account-request-status");
  $("#open-account-request").addEventListener("click", () => {
    loginForm.hidden = true;
    requestPanel.hidden = false;
    requestStatus.textContent = "";
    $("#request-name").focus();
  });
  $("#back-to-login").addEventListener("click", () => {
    requestPanel.hidden = true;
    loginForm.hidden = false;
    loginError.textContent = "";
    loginName.focus();
  });
  $("#submit-account-request").addEventListener("click", async () => {
    const name = $("#request-name").value.trim();
    const invitedBy = $("#request-inviter").value.trim();
    const email = $("#request-email").value.trim().toLowerCase();
    if (name.length < 2 || name.length > 30 || invitedBy.length < 2 || invitedBy.length > 30 ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 120) {
      requestStatus.textContent = "PLEASE CHECK YOUR NAME, INVITER, AND EMAIL.";
      return;
    }
    const submit = $("#submit-account-request");
    submit.disabled = true;
    requestStatus.textContent = "SENDING REQUEST...";
    try {
      if (!communityReady) throw new Error("Community service is not ready.");
      await communityReady;
      if (!communityDb || !communityUser) throw new Error("Community service is unavailable.");
      await communityDb.ref("accountRequests").push().set({
        name,
        invitedBy,
        email,
        status: "pending",
        createdAt: firebase.database.ServerValue.TIMESTAMP
      });
      requestStatus.textContent = "REQUEST RECEIVED. THE SITE OWNER WILL REVIEW IT.";
      $("#request-name").value = "";
      $("#request-inviter").value = "";
      $("#request-email").value = "";
    } catch (_) {
      requestStatus.textContent = "COULDN’T SEND THE REQUEST. PLEASE TRY AGAIN LATER.";
    } finally {
      submit.disabled = false;
    }
  });

  loginForm.addEventListener("submit", event => {
    event.preventDefault();
    const submitted = loginName.value.trim();
    const player = ALLOWED_PLAYERS.find(name => name.toLowerCase() === submitted.toLowerCase());
    if (!player || loginPassword.value !== getRequiredLoginKey()) {
      loginError.textContent = "Access denied. Check the player name and password.";
      loginPassword.value = "";
      loginPassword.focus();
      return;
    }
    activePlayer = player;
    sessionStorage.setItem("veyaoraArcadeLoggedIn", player);
    showHome();
    updateCommunityPresence();
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

  function bindGameChatHotkey() {
    try {
      const frameDoc = $("#game-frame").contentDocument;
      if (!frameDoc || frameDoc.__veyaoraChatHotkeyBound) return;
      frameDoc.__veyaoraChatHotkeyBound = true;
      frameDoc.addEventListener("keydown",event => {
        if (event.key === "]" && !event.repeat) {
          event.preventDefault();
          event.stopPropagation();
          toggleCommunityChat();
        }
      },true);
    } catch (_) { /* Cross-origin game frames cannot expose their keyboard events. */ }
  }

  function toggleCommunityChat() {
    if (communityDialog && !communityDialog.hidden) closeOverlays();
    else openCommunityChat();
  }

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
      bindGameChatHotkey();
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
      yippie: {url:"games/new-game/Game.html",title:"Yippie",kind:"local"},
      "last-signal": {url:"the-last-signal/dist/index.html",title:"The Last Signal",kind:"local"},
      "project-echo": {url:"project%20echo/index.html",title:"PROJECT: ECHO",kind:"local"},
      android: {url:"https://github.com/Z3BOS/afterburner",title:"Android Lab",kind:"external"},
      xbox: {url:"/idk/xbox360/",title:"VEYΛORA Xbox Lab",kind:"local"},
      ssf2: {url:"ssf2-player.html?v=1",title:"Super Smash Flash 2 · Ruffle",kind:"local"}
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
      card.dataset.game = entry.title || ("Eaglercraft " + entry.version);
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
      title.textContent = entry.title || ("Eaglercraft " + entry.version);
      const description = document.createElement("p");
      description.textContent = "Launch this alternate build in its own game window.";
      const launch = document.createElement("button");
      launch.type = "button";
      launch.className = "button button-card";
      launch.innerHTML = 'LAUNCH VERSION <span>↗</span>';
      launch.addEventListener("click", () => launchGame(entry.url || ("eaglercraft/" + entry.file),entry.title || ("Eaglercraft " + entry.version)));
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
    [settingsDialog,friendsDialog,announcementDialog,communityDialog].forEach(dialog => { if (dialog) dialog.hidden = true; });
    if (communityMessagesRef) communityMessagesRef.off("value");
    closeProfileMenu();
  }

  function updateChatUnreadUI() {
    [$("#top-chat"),$("#nav-community")].forEach(button => {
      if (!button) return;
      let badge = $(".chat-unread-badge",button);
      if (!badge) {
        badge = document.createElement("span");
        badge.className = "chat-unread-badge";
        button.appendChild(badge);
      }
      badge.textContent = unreadCommunityMessages > 99 ? "99+" : String(unreadCommunityMessages);
      badge.hidden = unreadCommunityMessages === 0;
      button.classList.toggle("has-unread",unreadCommunityMessages > 0);
    });
  }

  function showChatNotification(message) {
    if (communityDialog && !communityDialog.hidden) return;
    unreadCommunityMessages++;
    updateChatUnreadUI();
    const profile = getProfile(activePlayer);
    if (message.uid === communityUser?.uid) return;
    const host = $("#chat-notification-stack");
    if (host) {
      const toast = document.createElement("button");
      toast.type = "button";
      toast.className = "chat-notification-toast";
      const title = document.createElement("strong");
      title.textContent = String(message.name || "Player").slice(0,18) + " sent a message";
      const body = document.createElement("span");
      body.textContent = String(message.text || "").slice(0,100);
      toast.append(title,body);
      toast.addEventListener("click",() => { openCommunityChat(); });
      host.appendChild(toast);
      window.setTimeout(() => toast.remove(),6500);
    }
    if ("Notification" in window && Notification.permission === "granted" && document.hidden) {
      try {
        const notification = new Notification("VEYΛORA · " + String(message.name || "Player").slice(0,18), {
          body:String(message.text || "New community message").slice(0,120),
          tag:"veyaora-community-chat",
          silent:true
        });
        notification.onclick = () => { window.focus(); openCommunityChat(); notification.close(); };
      } catch (_) {}
    }
  }

  function watchCommunityNotifications() {
    if (!communityDb || notificationRef) return;
    notificationInitializing = true;
    notificationRef = communityDb.ref("community/messages").limitToLast(50);
    notificationRef.on("child_added",snapshot => {
      if (notificationInitializing) {
        pendingMessageNotifications.set(snapshot.key,snapshot.val() || {});
        return;
      }
      if (knownMessageIds.has(snapshot.key)) return;
      knownMessageIds.add(snapshot.key);
      const message = snapshot.val() || {};
      if (message.uid !== communityUser?.uid) showChatNotification(message);
    });
    notificationRef.once("value").then(snapshot => {
      snapshot.forEach(child => knownMessageIds.add(child.key));
      notificationInitializing = false;
      pendingMessageNotifications.forEach((message,id) => {
        if (!knownMessageIds.has(id)) {
          knownMessageIds.add(id);
          if (message.uid !== communityUser?.uid) showChatNotification(message);
        }
      });
      pendingMessageNotifications.clear();
    }).catch(() => { notificationInitializing = false; });
  }
  function closeProfileMenu() { if (profileMenu) profileMenu.hidden = true; }
  $$("[data-close-dialog]").forEach(button => button.addEventListener("click",closeOverlays));
  [settingsDialog,friendsDialog,announcementDialog,communityDialog].forEach(dialog => dialog?.addEventListener("click",event => { if (event.target === dialog) closeOverlays(); }));
  document.addEventListener("keydown",event => {
    const target = event.target;
    const typing = target && (target.matches?.("input,textarea,select,[contenteditable='true']") || target.isContentEditable);
    if (event.key === "]" && !event.repeat && !typing && !event.ctrlKey && !event.metaKey && !event.altKey) {
      event.preventDefault();
      toggleCommunityChat();
      return;
    }
    if (event.key === "Escape") {
      closeOverlays();
      if (!gameScreen.hidden) exitGame();
    }
  });
  $("#nav-friends").addEventListener("click",() => openDialog(friendsDialog));
  $("#top-friends").addEventListener("click",() => openDialog(friendsDialog));
  $("#nav-community").addEventListener("click",openCommunityChat);
  $("#top-chat").addEventListener("click",openCommunityChat);
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
  async function openCommunityChat() {
    closeOverlays();
    communityDialog.hidden = false;
    if ("Notification" in window && Notification.permission === "default") {
      try { await Notification.requestPermission(); } catch (_) {}
    }
    unreadCommunityMessages = 0;
    updateChatUnreadUI();
    const status = $("#community-chat-status");
    const input = $("#community-chat-input");
    const send = $("#community-send");
    if (!communityReady) {
      status.textContent = "COMMUNITY CHAT NEEDS FIREBASE CONFIGURATION.";
      return;
    }
    status.textContent = "CONNECTING TO COMMUNITY...";
    try {
      await communityReady;
      if (!communityDb || !communityUser) throw new Error("Community service is not connected.");
      status.textContent = "CONNECTED · LIVE MESSAGES";
      input.disabled = false;
      send.disabled = false;
      if (!communityMessagesRef) communityMessagesRef = communityDb.ref("community/messages").limitToLast(50);
      communityMessagesRef.off("value");
      communityMessagesRef.on("value", snapshot => renderCommunityMessages(snapshot));
    } catch (error) {
      status.textContent = error && error.message ? error.message.toUpperCase() : "COMMUNITY CONNECTION FAILED.";
      input.disabled = true;
      send.disabled = true;
    }
  }

  function renderCommunityMessages(snapshot) {
    const list = $("#community-messages");
    if (!list) return;
    list.replaceChildren();
    if (!snapshot || !snapshot.exists()) {
      const empty = document.createElement("p");
      empty.className = "community-empty";
      empty.textContent = "No messages yet. Start the conversation.";
      list.appendChild(empty);
      return;
    }
    snapshot.forEach(child => {
      const message = child.val() || {};
      const row = document.createElement("article");
      row.className = "community-message";
      const meta = document.createElement("div");
      meta.className = "community-message-meta";
      const author = document.createElement("strong");
      author.textContent = String(message.name || "Player").slice(0,18);
      const time = document.createElement("time");
      const stamp = Number(message.createdAt);
      time.textContent = Number.isFinite(stamp) && stamp > 0 ? new Date(stamp).toLocaleTimeString([], {hour:"numeric",minute:"2-digit"}) : "JUST NOW";
      const body = document.createElement("p");
      body.textContent = String(message.text || "").slice(0,300);
      meta.append(author,time);
      row.append(meta,body);
      list.appendChild(row);
    });
    list.scrollTop = list.scrollHeight;
  }

  $("#community-chat-form").addEventListener("submit", async event => {
    event.preventDefault();
    const input = $("#community-chat-input");
    const send = $("#community-send");
    const message = input.value.trim();
    if (!message || message.length > 300 || !communityDb || !communityUser) return;
    const now = Date.now();
    if (now - lastCommunitySend < 1800) {
      $("#community-chat-status").textContent = "PLEASE WAIT A MOMENT BEFORE SENDING AGAIN.";
      return;
    }
    lastCommunitySend = now;
    send.disabled = true;
    const profile = getProfile(activePlayer);
    try {
      await communityDb.ref("community/messages").push().set({
        uid: communityUser.uid,
        player: activePlayer,
        name: profile.displayName,
        avatar: profile.avatar,
        text: message,
        createdAt: firebase.database.ServerValue.TIMESTAMP
      });
      input.value = "";
      $("#community-chat-status").textContent = "CONNECTED · LIVE MESSAGES";
    } catch (_) {
      $("#community-chat-status").textContent = "MESSAGE NOT SENT · CHECK FIREBASE DATABASE RULES.";
    } finally {
      send.disabled = false;
      input.focus();
    }
  });

  function updateCommunityPresence() {
    if (!communityPresenceRef || !communityUser) return;
    const profile = getProfile(activePlayer);
    communityPresenceRef.update({player:activePlayer,name:profile.displayName,avatar:profile.avatar}).catch(() => {});
  }

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
    updateCommunityPresence();
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
    const communityCount = $("#community-online-count");
    const validConfig = config && config.apiKey && config.databaseURL && config.projectId && config.appId &&
      !String(config.apiKey).startsWith("PASTE_") && !String(config.databaseURL).includes("PASTE_") &&
      !String(config.projectId).startsWith("PASTE_") && !String(config.appId).startsWith("PASTE_");
    if (!validConfig || !window.firebase) {
      if (count) count.textContent = "—";
      if (communityCount) communityCount.textContent = "—";
      return;
    }
    try {
      if (!firebase.apps.length) firebase.initializeApp(config);
      const auth = firebase.auth();
      const db = firebase.database();
      const presence = db.ref("presence/veyaora");
      communityReady = auth.signInAnonymously().then(() => {
        communityUser = auth.currentUser;
        if (!communityUser) throw new Error("Anonymous sign-in was not available.");
        communityDb = db;
        const mine = presence.child(communityUser.uid);
        communityPresenceRef = mine;
        db.ref(".info/connected").on("value",snapshot => {
          if (snapshot.val() === true) {
            mine.onDisconnect().remove().then(() => mine.set({
              since:firebase.database.ServerValue.TIMESTAMP,
              player:activePlayer,
              name:getProfile(activePlayer).displayName,
              avatar:getProfile(activePlayer).avatar
            }));
          }
        });
        watchCommunityNotifications();
        presence.on("value",snapshot => {
          const total = snapshot.numChildren();
          if (count) count.textContent = String(total);
          if (communityCount) communityCount.textContent = String(total);
        });
        updateCommunityPresence();
      }).catch(error => {
        if (count) count.textContent = "—";
        if (communityCount) communityCount.textContent = "—";
        throw error;
      });
    } catch (_) {
      communityReady = Promise.reject(new Error("Firebase community service is unavailable."));
      communityReady.catch(() => {});
    }
  }

  renderExtraVersions();
  updateFavoriteButtons();
  renderRecents();
  applyGameFilters();
  refreshProfilePicker();
  setPlayerSelection("Colton");
  setupLiveVisitors();
  const storedPlayer = sessionStorage.getItem("veyaoraArcadeLoggedIn");
  const restoredPlayer = ALLOWED_PLAYERS.find(name => name.toLowerCase() === String(storedPlayer || "").toLowerCase());
  if (restoredPlayer) {
    activePlayer = restoredPlayer;
    showHome();
  } else {
    sessionStorage.removeItem("veyaoraArcadeLoggedIn");
    showLogin();
  }
})();
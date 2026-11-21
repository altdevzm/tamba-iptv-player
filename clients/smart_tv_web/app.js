/**
 * Tamba IPTV – Smart TV (Samsung Tizen, LG webOS) & Browser Client
 * Connects directly to the same Xtream Codes API backend used by the Flutter app.
 * Supports D-pad remote control, Samsung Tizen keys, LG Magic Remote, keyboard, and mouse.
 */
(() => {
  const STORAGE_KEY = 'tamba_iptv_tv_config_v1';
  const FAV_KEY = 'tamba_iptv_tv_favorites_v1';

  const state = {
    route: 'home',
    config: JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null'),
    favorites: JSON.parse(localStorage.getItem(FAV_KEY) || '[]'),
    live: [],
    movies: [],
    series: [],
    currentIndex: -1,
    currentType: 'live',
    hls: null,
    hudTimer: null,
  };

  const mainEl = document.getElementById('main-content');
  const playerOverlay = document.getElementById('player-overlay');
  const videoEl = document.getElementById('video-element');
  const hudEl = document.getElementById('player-hud');
  const titleEl = document.getElementById('player-title');
  const badgeEl = document.getElementById('player-badge');
  const statusEl = document.getElementById('player-status');
  const drawerEl = document.getElementById('player-channel-drawer');
  const btnPlayPause = document.getElementById('btn-play-pause');
  const btnChannels = document.getElementById('btn-player-channels');

  // Register Samsung Tizen remote keys when running on Tizen TV
  if (window.tizen && window.tizen.tvinputdevice) {
    ['MediaPlayPause', 'MediaPlay', 'MediaPause', 'MediaFastForward', 'MediaRewind', 'ChannelUp', 'ChannelDown', 'ColorF0Red'].forEach((k) => {
      try { window.tizen.tvinputdevice.registerKey(k); } catch (_) {}
    });
  }

  function saveConfig(cfg) {
    state.config = cfg;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  }

  async function syncXtream() {
    if (!state.config || !state.config.serverUrl) return;
    const { serverUrl, username, password } = state.config;
    const base = `${serverUrl.replace(/\/+$/, '')}/player_api.php?username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    try {
      const [liveRes, vodRes, seriesRes] = await Promise.all([
        fetch(`${base}&action=get_live_streams`).then((r) => r.json()).catch(() => []),
        fetch(`${base}&action=get_vod_streams`).then((r) => r.json()).catch(() => []),
        fetch(`${base}&action=get_series`).then((r) => r.json()).catch(() => []),
      ]);
      state.live = Array.isArray(liveRes) ? liveRes.slice(0, 300) : [];
      state.movies = Array.isArray(vodRes) ? vodRes.slice(0, 200) : [];
      state.series = Array.isArray(seriesRes) ? seriesRes.slice(0, 200) : [];
    } catch (e) {
      console.error('Xtream sync failed', e);
    }
    render();
  }

  function buildStreamUrl(type, item) {
    const { serverUrl, username, password } = state.config;
    const base = serverUrl.replace(/\/+$/, '');
    if (type === 'live') {
      return `${base}/live/${username}/${password}/${item.stream_id}.m3u8`;
    }
    const ext = item.container_extension || 'mp4';
    return `${base}/movie/${username}/${password}/${item.stream_id}.${ext}`;
  }

  function openPlayer(type, index) {
    const list = type === 'live' ? state.live : state.movies;
    const item = list[index];
    if (!item) return;

    state.currentType = type;
    state.currentIndex = index;
    const url = buildStreamUrl(type, item);

    titleEl.textContent = item.name || item.title || 'Stream';
    badgeEl.classList.toggle('hidden', type !== 'live');
    btnChannels.classList.toggle('hidden', type !== 'live');
    drawerEl.classList.add('hidden');
    playerOverlay.classList.remove('hidden');
    statusEl.textContent = 'Connecting...';
    wakeHud();

    if (state.hls) {
      state.hls.destroy();
      state.hls = null;
    }

    if (window.Hls && window.Hls.isSupported() && url.endsWith('.m3u8')) {
      const hls = new window.Hls({ enableWorker: true, lowLatencyMode: true });
      hls.loadSource(url);
      hls.attachMedia(videoEl);
      hls.on(window.Hls.Events.MANIFEST_PARSED, () => {
        videoEl.play().catch(() => {});
        statusEl.textContent = type === 'live' ? 'Live' : 'Playing';
      });
      hls.on(window.Hls.Events.ERROR, (_, data) => {
        if (data.fatal) statusEl.textContent = 'Stream error – press Retry or switch channel';
      });
      state.hls = hls;
    } else {
      videoEl.src = url;
      videoEl.play().catch(() => {});
      statusEl.textContent = type === 'live' ? 'Live' : 'Playing';
    }
    btnPlayPause.focus();
  }

  function closePlayer() {
    if (state.hls) {
      state.hls.destroy();
      state.hls = null;
    }
    videoEl.pause();
    videoEl.removeAttribute('src');
    videoEl.load();
    drawerEl.classList.add('hidden');
    playerOverlay.classList.add('hidden');
  }

  function wakeHud() {
    hudEl.classList.remove('faded');
    clearTimeout(state.hudTimer);
    state.hudTimer = setTimeout(() => {
      if (drawerEl.classList.contains('hidden')) {
        hudEl.classList.add('faded');
      }
    }, 4500);
  }

  function toggleChannelDrawer() {
    if (state.currentType !== 'live') return;
    const isHidden = drawerEl.classList.toggle('hidden');
    if (!isHidden) {
      drawerEl.innerHTML = `<h3 style="margin-bottom:12px;">Live Channels</h3>` + state.live
        .slice(0, 80)
        .map((ch, idx) => `<button class="nav-item ${idx === state.currentIndex ? 'active' : ''}" data-drawer-ch="${idx}" tabindex="0"><span>${escapeHtml(ch.name || 'Channel')}</span></button>`)
        .join('');
      drawerEl.querySelectorAll('[data-drawer-ch]').forEach((btn) => {
        btn.addEventListener('click', () => openPlayer('live', Number(btn.dataset.drawerCh)));
      });
      const activeBtn = drawerEl.querySelector('.active') || drawerEl.querySelector('button');
      if (activeBtn) activeBtn.focus();
    }
  }

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
  }

  function render() {
    document.querySelectorAll('.nav-item[data-nav]').forEach((el) => {
      el.classList.toggle('active', el.dataset.nav === state.route);
    });

    if (!state.config || state.route === 'settings') {
      mainEl.innerHTML = `
        <h1 style="font-size:28px;margin-bottom:16px;">Connect Tamba IPTV Account</h1>
        <form id="xtream-form" class="form-card">
          <input class="input" id="f-url" placeholder="Server URL (http://host:port)" value="${escapeHtml(state.config?.serverUrl || '')}" required />
          <input class="input" id="f-user" placeholder="Username" value="${escapeHtml(state.config?.username || '')}" required />
          <input class="input" id="f-pass" type="password" placeholder="Password" value="${escapeHtml(state.config?.password || '')}" required />
          <button type="submit" class="btn btn-primary">Connect & Sync Playlist</button>
        </form>
      `;
      document.getElementById('xtream-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        saveConfig({
          serverUrl: document.getElementById('f-url').value.trim(),
          username: document.getElementById('f-user').value.trim(),
          password: document.getElementById('f-pass').value.trim(),
        });
        state.route = 'home';
        await syncXtream();
      });
      return;
    }

    if (state.route === 'live') {
      mainEl.innerHTML = `
        <h1 style="font-size:28px;margin-bottom:16px;">Live TV (${state.live.length})</h1>
        <div class="channel-grid">
          ${state.live.map((ch, idx) => `
            <button class="channel-card" data-play-live="${idx}" tabindex="0">
              <img class="channel-logo" src="${escapeHtml(ch.stream_icon || '')}" onerror="this.style.visibility='hidden'" />
              <div>
                <div style="font-weight:700;font-size:15px;">${escapeHtml(ch.name || 'Channel')}</div>
                <div style="color:#e50914;font-size:11px;font-weight:800;margin-top:4px;">● LIVE</div>
              </div>
            </button>
          `).join('')}
        </div>
      `;
    } else if (state.route === 'movies') {
      mainEl.innerHTML = `
        <h1 style="font-size:28px;margin-bottom:16px;">Movies (${state.movies.length})</h1>
        <div class="rail" style="flex-wrap:wrap;overflow:visible;">
          ${state.movies.map((m, idx) => `
            <button class="card" data-play-movie="${idx}" tabindex="0">
              <img src="${escapeHtml(m.stream_icon || '')}" alt="" loading="lazy" />
              <div class="card-label">${escapeHtml(m.name || 'Movie')}</div>
            </button>
          `).join('')}
        </div>
      `;
    } else if (state.route === 'search') {
      mainEl.innerHTML = `
        <h1 style="font-size:28px;margin-bottom:16px;">Search</h1>
        <input id="tv-search-input" class="input" style="max-width:480px;margin-bottom:20px;" placeholder="Search channels and movies..." />
        <div id="tv-search-results" class="channel-grid"></div>
      `;
      const input = document.getElementById('tv-search-input');
      input.addEventListener('input', () => {
        const q = input.value.trim().toLowerCase();
        const resEl = document.getElementById('tv-search-results');
        if (!q) { resEl.innerHTML = ''; return; }
        const liveHits = state.live.map((c, i) => ({ c, i })).filter(({ c }) => (c.name || '').toLowerCase().includes(q)).slice(0, 24);
        resEl.innerHTML = liveHits.map(({ c, i }) => `
          <button class="channel-card" data-play-live="${i}" tabindex="0">
            <div><div style="font-weight:700;">${escapeHtml(c.name)}</div><div style="color:#e50914;font-size:11px;">LIVE</div></div>
          </button>
        `).join('');
        bindPlayButtons();
      });
    } else {
      const hero = state.movies[0];
      mainEl.innerHTML = `
        ${hero ? `
          <section class="hero" style="background-image:url('${escapeHtml(hero.stream_icon || '')}')">
            <div class="hero-content">
              <div style="color:#e50914;font-weight:800;font-size:12px;letter-spacing:1.2px;margin-bottom:8px;">FEATURED</div>
              <h1 class="hero-title">${escapeHtml(hero.name || 'Featured')}</h1>
              <div class="hero-actions">
                <button class="btn btn-primary" data-play-movie="0" tabindex="0">▶ Play Now</button>
                <button class="btn btn-secondary" id="btn-hero-live" tabindex="0">Watch Live TV</button>
              </div>
            </div>
          </section>
        ` : ''}
        <h2 class="section-title">Live TV</h2>
        <div class="rail">
          ${state.live.slice(0, 18).map((ch, idx) => `
            <button class="channel-card" style="min-width:220px;" data-play-live="${idx}" tabindex="0">
              <img class="channel-logo" src="${escapeHtml(ch.stream_icon || '')}" onerror="this.style.visibility='hidden'" />
              <div>
                <div style="font-weight:700;font-size:14px;">${escapeHtml(ch.name || 'Channel')}</div>
                <div style="color:#e50914;font-size:11px;font-weight:800;">● LIVE</div>
              </div>
            </button>
          `).join('')}
        </div>
        <h2 class="section-title">Popular Movies</h2>
        <div class="rail">
          ${state.movies.slice(0, 24).map((m, idx) => `
            <button class="card" data-play-movie="${idx}" tabindex="0">
              <img src="${escapeHtml(m.stream_icon || '')}" alt="" loading="lazy" />
              <div class="card-label">${escapeHtml(m.name || 'Movie')}</div>
            </button>
          `).join('')}
        </div>
      `;
      const heroLiveBtn = document.getElementById('btn-hero-live');
      if (heroLiveBtn) heroLiveBtn.addEventListener('click', () => { state.route = 'live'; render(); });
    }
    bindPlayButtons();
  }

  function bindPlayButtons() {
    mainEl.querySelectorAll('[data-play-live]').forEach((el) => {
      el.addEventListener('click', () => openPlayer('live', Number(el.dataset.playLive)));
    });
    mainEl.querySelectorAll('[data-play-movie]').forEach((el) => {
      el.addEventListener('click', () => openPlayer('movie', Number(el.dataset.playMovie)));
    });
  }

  // Sidebar navigation
  document.querySelectorAll('.nav-item[data-nav]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.route = btn.dataset.nav;
      render();
    });
  });

  // Player controls
  document.getElementById('btn-player-back').addEventListener('click', closePlayer);
  btnChannels.addEventListener('click', toggleChannelDrawer);
  btnPlayPause.addEventListener('click', () => {
    if (videoEl.paused) { videoEl.play(); btnPlayPause.textContent = '⏸'; }
    else { videoEl.pause(); btnPlayPause.textContent = '▶'; }
    wakeHud();
  });
  document.getElementById('btn-prev').addEventListener('click', () => {
    if (state.currentType === 'live' && state.live.length > 0) {
      openPlayer('live', (state.currentIndex - 1 + state.live.length) % state.live.length);
    } else {
      videoEl.currentTime = Math.max(0, videoEl.currentTime - 10);
    }
    wakeHud();
  });
  document.getElementById('btn-next').addEventListener('click', () => {
    if (state.currentType === 'live' && state.live.length > 0) {
      openPlayer('live', (state.currentIndex + 1) % state.live.length);
    } else {
      videoEl.currentTime += 10;
    }
    wakeHud();
  });

  // Remote-control & keyboard handler (Samsung Tizen 10009, LG webOS 461, Escape/Backspace)
  window.addEventListener('keydown', (e) => {
    const inPlayer = !playerOverlay.classList.contains('hidden');
    const isBack = e.key === 'Escape' || e.keyCode === 10009 || e.keyCode === 461;

    if (inPlayer) {
      wakeHud();
      if (isBack) {
        e.preventDefault();
        if (!drawerEl.classList.contains('hidden')) {
          drawerEl.classList.add('hidden');
        } else {
          closePlayer();
        }
      } else if (e.key === 'MediaPlayPause' || e.keyCode === 10252) {
        btnPlayPause.click();
      } else if (e.key === 'ChannelUp' || e.keyCode === 427) {
        document.getElementById('btn-prev').click();
      } else if (e.key === 'ChannelDown' || e.keyCode === 428) {
        document.getElementById('btn-next').click();
      }
    }
  });

  if (state.config) {
    syncXtream();
  } else {
    render();
  }
})();

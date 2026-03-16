/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * ПУЛЬС ГОРОДА - Карта жалоб Нижневартовска v2.1
 * Полный список категорий + ЧП | Счётчики день/месяц/год | HDBSCAN-like clustering
 * ═══════════════════════════════════════════════════════════════════════════════
 */

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const CONFIG = {
  center: [60.9366, 76.5594],
  zoom: 13,
  minZoom: 11,
  maxZoom: 18,

  supabase: {
    url: 'https://xpainxohbdoruakcijyq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc'
  },

  tiles: {
    light: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    attribution: '&copy; OSM &copy; CARTO'
  },

  newMarkerZoom: 16,
  popupDuration: 10000,
  returnDelay: 500
};

// ═══════════════════════════════════════════════════════════════════════════════
// FULL CATEGORIES LIST (from project analysis)
// ═══════════════════════════════════════════════════════════════════════════════

const CATEGORIES = {
  // Приоритетные категории (ЧП первым!)
  'ЧП': { icon: '🚨', color: '#FF3D00', priority: 1 },

  // ЖКХ и инфраструктура
  'ЖКХ': { icon: '🏠', color: '#f97316', priority: 2 },
  'Дороги': { icon: '🛣️', color: '#ef4444', priority: 2 },
  'Благоустройство': { icon: '🌳', color: '#22c55e', priority: 3 },
  'Транспорт': { icon: '🚌', color: '#3b82f6', priority: 3 },
  'Освещение': { icon: '💡', color: '#eab308', priority: 3 },

  // Коммуникации
  'Газоснабжение': { icon: '🔥', color: '#f97316', priority: 1 },
  'Водоснабжение и канализация': { icon: '💧', color: '#0ea5e9', priority: 2 },
  'Отопление': { icon: '🌡️', color: '#f43f5e', priority: 2 },
  'Связь': { icon: '📡', color: '#6366f1', priority: 4 },

  // Мусор и экология
  'Мусор': { icon: '🗑️', color: '#84cc16', priority: 3 },
  'Бытовой мусор': { icon: '🗑️', color: '#84cc16', priority: 3 },
  'Экология': { icon: '🌿', color: '#00E676', priority: 3 },
  'Мероприятие': { icon: '🎭', color: '#eab308', priority: 3 },
  'Камеры': { icon: '📷', color: '#6366f1', priority: 4 },

  // Общественные пространства
  'Детские площадки': { icon: '🎠', color: '#ec4899', priority: 3 },
  'Спортивные площадки': { icon: '⚽', color: '#8b5cf6', priority: 4 },
  'Парки и скверы': { icon: '🌲', color: '#059669', priority: 4 },
  'Парковки': { icon: '🅿️', color: '#6366f1', priority: 4 },

  // Здания
  'Лифты и подъезды': { icon: '🏢', color: '#64748b', priority: 3 },
  'Строительство': { icon: '🚧', color: '#d97706', priority: 4 },

  // Безопасность и погода
  'Безопасность': { icon: '🛡️', color: '#FF3D00', priority: 2 },
  'Снег/Наледь': { icon: '❄️', color: '#38bdf8', priority: 2 },

  // Социальные
  'Медицина': { icon: '🏥', color: '#00E5FF', priority: 2 },
  'Здравоохранение': { icon: '🏥', color: '#00E5FF', priority: 2 },
  'Образование': { icon: '🎓', color: '#8b5cf6', priority: 3 },
  'Социальная сфера': { icon: '👥', color: '#6366f1', priority: 4 },

  // Другие
  'Животные': { icon: '🐶', color: '#f59e0b', priority: 4 },
  'Торговля': { icon: '🛒', color: '#00E676', priority: 4 },
  'Трудовое право': { icon: '📄', color: '#64748b', priority: 4 },

  // По умолчанию
  'Прочее': { icon: '📌', color: '#64748b', priority: 5 }
};

// Основные категории для фильтров (компактный набор)
const MAIN_CATEGORIES = [
  'ЧП', 'ЖКХ', 'Дороги', 'Благоустройство', 'Транспорт', 'Освещение',
  'Мусор', 'Детские площадки', 'Парковки', 'Безопасность', 'Снег/Наледь',
  'Медицина', 'Экология', 'Мероприятие', 'Камеры', 'Прочее'
];

const CAMERAS = [];

const STATUS_LABELS = {
  'open': 'Открыта',
  'in_progress': 'В работе',
  'resolved': 'Решена',
  'closed': 'Закрыта',
  'pending': 'На рассмотрении'
};

const DAY_FILTERS = [
  { id: 'all', label: 'Все' },
  { id: 'today', label: 'Сегодня' },
  { id: '3days', label: '3 дня' },
  { id: 'week', label: 'Неделя' },
  { id: 'month', label: 'Месяц' }
];

// ═══════════════════════════════════════════════════════════════════════════════
// APPLICATION STATE
// ═══════════════════════════════════════════════════════════════════════════════

const state = {
  map: null,
  supabase: null,
  markerCluster: null,
  cameraLayer: null,
  eventLayer: null,
  markers: new Map(),
  complaints: [],
  currentCategoryFilter: 'all',
  currentDayFilter: 'all',
  realtimeSubscription: null,
  isLoading: true,
  savedView: null,
  autoReturnTimeout: null,
  stats: {
    today: 0,
    month: 0,
    year: 0,
    total: 0
  },
  is3DMode: false,
  cameraMarkers: [],
  eventMarkers: [],
  splashAudioEnabled: true,
  splashProgress: 10,
  mapRefreshTimer: null
};

const SPLASH_MESSAGES = [
  'Подключаем карту...',
  'Загружаем обращения...',
  'Включаем live-обновления...',
  'Почти готово'
];

const SPLASH_VARIANTS = [
  {
    key: 'aurora',
    themeName: 'Aurora Mesh',
    kicker: 'Live civic signal',
    title: 'Пульс Города',
    subtitle: 'Мягкие градиенты, стеклянные слои и спокойный цифровой ритм города.',
    mode: 'Aurora',
    icon: '◉',
    audio: 'audio/splash-aurora.mp3'
  },
  {
    key: 'grid',
    themeName: 'Signal Grid',
    kicker: 'Urban scanline',
    title: 'Пульс Города',
    subtitle: 'Контрастная сетка, editorial-графика и острые акценты в духе kinetic UI.',
    mode: 'Grid',
    icon: '▲',
    audio: 'audio/splash-grid.mp3'
  },
  {
    key: 'pulse',
    themeName: 'Liquid Pulse',
    kicker: 'Motion chrome',
    title: 'Пульс Города',
    subtitle: 'Люминесцентные блики, жидкий металл и динамика современных launch screens.',
    mode: 'Pulse',
    icon: '◌',
    audio: 'audio/splash-pulse.mp3'
  }
];
let splashController = null;

// ═══════════════════════════════════════════════════════════════════════════════
// SUPABASE CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

async function initSupabase() {
  let supabaseLib = window.supabase;

  if (!supabaseLib || !supabaseLib.createClient) {
    setSplashStatus('Подключаем Supabase...', 24);
    console.log('⏳ Loading Supabase...');
    try {
      await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js');
      supabaseLib = window.supabase;
    } catch (e) {
      try {
        await loadScript('https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.min.js');
        supabaseLib = window.supabase;
      } catch (e2) {
        setSplashStatus('Работаем в демо-режиме', 38);
        console.error('❌ Supabase load failed');
        return false;
      }
    }
  }

  if (!supabaseLib?.createClient) return false;

  state.supabase = supabaseLib.createClient(CONFIG.supabase.url, CONFIG.supabase.anonKey);
  setSplashStatus('Supabase подключен', 46);
  console.log('✅ Supabase OK');
  return true;
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAP INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

function initMap() {
  if (typeof L === 'undefined') {
    document.getElementById('map').innerHTML = `
      <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;background:#f8fafc;color:#475569;font-family:system-ui;padding:24px;text-align:center;">
        <div style="font-size:48px;margin-bottom:16px;">🗺️</div>
        <div style="font-size:16px;font-weight:600;">Карта не загрузилась</div>
        <button onclick="location.reload()" style="margin-top:16px;padding:10px 20px;background:var(--primary);color:#020617;border:none;border-radius:8px;cursor:pointer;">↻ Обновить</button>
      </div>`;
    hideSplash();
    return false;
  }

  setSplashStatus('Инициализируем карту...', 58);

  state.map = L.map('map', {
    center: CONFIG.center,
    zoom: CONFIG.zoom,
    minZoom: CONFIG.minZoom,
    maxZoom: CONFIG.maxZoom,
    zoomControl: true
  });

  L.tileLayer(CONFIG.tiles.light, {
    attribution: CONFIG.tiles.attribution,
    maxZoom: 19
  }).addTo(state.map);

  state.map.zoomControl.setPosition('bottomright');

  // HDBSCAN-like clustering
  state.markerCluster = L.markerClusterGroup({
    showCoverageOnHover: false,
    maxClusterRadius: (zoom) => Math.max(30, 80 - zoom * 4),
    spiderfyOnMaxZoom: true,
    disableClusteringAtZoom: 17,
    animate: true,
    animateAddingMarkers: true,
    iconCreateFunction: createClusterIcon,
    spiderfyDistanceMultiplier: 1.5,
    chunkedLoading: true
  });

  state.map.addLayer(state.markerCluster);
  state.cameraLayer = L.layerGroup().addTo(state.map);
  state.eventLayer = L.layerGroup().addTo(state.map);
  setSplashStatus('Карта готова', 72);
  console.log('✅ Map OK');
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKER & CLUSTER CREATION
// ═══════════════════════════════════════════════════════════════════════════════

function createClusterIcon(cluster) {
  const count = cluster.getChildCount();
  const children = cluster.getAllChildMarkers();

  // Get dominant category and check for ЧП
  const catCounts = {};
  let hasEmergency = false;

  children.forEach(m => {
    const cat = m.complaintData?.category || 'Прочее';
    if (cat === 'ЧП') hasEmergency = true;
    catCounts[cat] = (catCounts[cat] || 0) + 1;
  });

  let maxCat = 'Прочее', maxCount = 0;
  Object.entries(catCounts).forEach(([cat, cnt]) => {
    if (cnt > maxCount) { maxCat = cat; maxCount = cnt; }
  });

  // ЧП cluster has priority color
  const color = hasEmergency ? '#FF3D00' : (CATEGORIES[maxCat]?.color || '#64748b');
  let size = count > 25 ? 48 : count > 10 ? 42 : 36;

  return L.divIcon({
    html: `<div style="background:${color};width:${size}px;height:${size}px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:${size > 42 ? 14 : 12}px;box-shadow:0 3px 12px ${color}66;${hasEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}">${count}</div>`,
    className: 'custom-cluster',
    iconSize: L.point(size, size)
  });
}

function getMarkerBadge(complaint) {
  const source = (complaint.source || '').toLowerCase();
  if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') return 'AF';
  if (source.startsWith('vk:')) return 'VK';
  if (source.startsWith('tg:') || source.startsWith('telegram:')) return 'TG';
  return '';
}

function createMarkerIcon(complaint) {
  const status = complaint.status || 'open';
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  const badge = getMarkerBadge(complaint);

  if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') {
    return L.divIcon({
      className: 'event-cyber-marker',
      html: `
        <div class="cyber-pulse-ring"></div>
        <div class="cyber-pulse-ring-inner"></div>
        <div class="cyber-hexagon">
          <div class="cyber-icon">${cat.icon}</div>
        </div>
        ${badge ? `<div style="position:absolute;bottom:-6px;right:-8px;min-width:20px;height:20px;padding:0 4px;border-radius:2px;background:#39FF14;color:#0f172a;font-size:10px;font-weight:900;z-index:10;transform:skewX(-10deg);border:1px solid #020617;">${badge}</div>` : ''}
      `,
      iconSize: [44, 44],
      iconAnchor: [22, 22],
      popupAnchor: [0, -22]
    });
  }

  return L.divIcon({
    className: 'custom-marker',
    html: `
      <div class="marker-pulse" style="background:${cat.color}33;${isEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}"></div>
      <div class="marker-pin status-${status}" style="border-color:${cat.color};">
        <span style="transform:rotate(45deg);font-size:14px;">${cat.icon}</span>
      </div>
      ${badge ? `<div style="position:absolute;top:-6px;right:-6px;min-width:20px;height:20px;padding:0 5px;border-radius:999px;background:#0f172a;color:#fff;font-size:9px;font-weight:800;display:flex;align-items:center;justify-content:center;border:2px solid #fff;box-shadow:0 4px 12px rgba(15,23,42,0.24);">${badge}</div>` : ''}`,
    iconSize: [32, 32],
    iconAnchor: [16, 32],
    popupAnchor: [0, -32]
  });
}


// Popup creation was removed in favor of Bottom Sheet

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET UI LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

let currentComplaintId = null;
const CAMERA_HUD_STATE = {
  timer: null,
  weather: null,
  weatherFetchedAt: 0,
  pendingWeatherPromise: null
};
const CAMERA_HUD_TIMEZONE = 'Asia/Yekaterinburg';
const CAMERA_HUD_WEATHER_TTL_MS = 10 * 60 * 1000;

function openBottomSheet(complaint) {
  currentComplaintId = complaint.id;
  const sheet = document.getElementById('marker-bottom-sheet');
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  const status = complaint.status || 'open';
  const isActionable = complaint.source_table === 'complaints' && complaint.category !== 'Мероприятие';
  const actionsEl = document.querySelector('.sheet-actions');
  const commentsSectionEl = document.querySelector('.sheet-comments-section');
  const descEl = document.getElementById('sheet-desc');

  // Update Header
  document.getElementById('sheet-icon').textContent = cat.icon;
  document.getElementById('sheet-icon').style.background = `${cat.color}22`;
  document.getElementById('sheet-icon').style.color = cat.color;

  const titleEl = document.getElementById('sheet-title');
  titleEl.textContent = `${isEmergency ? '⚠️ ' : ''}${complaint.summary || complaint.title || complaint.category}`;
  if (isEmergency) titleEl.style.color = 'var(--danger)';
  else titleEl.style.color = 'var(--text)';

  const statusEl = document.getElementById('sheet-status');
  statusEl.textContent = complaint.category === 'Мероприятие' ? 'Событие' : (STATUS_LABELS[status] || status);
  statusEl.className = `sheet-status ${status}`;

  // Update Body
  document.getElementById('sheet-address').textContent = complaint.address ? `📍 ${complaint.address}` : '📍 Нет адреса';
  document.getElementById('sheet-time').textContent = formatMarkerTime(complaint);
  descEl.innerHTML = `<div>${escapeHtml(complaint.description || 'Описание не указано.').replace(/\n/g, '<br>')}</div>${complaint.link ? `<div style="margin-top:12px;"><a href="${complaint.link}" target="_blank" rel="noopener" style="color:var(--primary);font-weight:600;">Открыть источник</a></div>` : ''}`;

  // Counters
  document.getElementById('sheet-count-join').textContent = complaint.supporters || 0;
  document.getElementById('sheet-count-like').textContent = complaint.likes_count || 0;
  document.getElementById('sheet-count-dislike').textContent = complaint.dislikes_count || 0;

  // Gallery
  const gallery = document.getElementById('sheet-gallery');
  if (complaint.images && complaint.images.length > 0) {
    gallery.style.display = 'flex';
    gallery.innerHTML = complaint.images.map(img => `<img src="${img}" alt="Фото проблемы" onclick="window.open('${img}', '_blank')">`).join('');
  } else {
    gallery.style.display = 'none';
  }

  // Open Sheet
  sheet.classList.add('open');
  if (actionsEl) actionsEl.style.display = isActionable ? 'flex' : 'none';
  if (commentsSectionEl) commentsSectionEl.style.display = isActionable ? 'block' : 'none';
  if (isActionable) {
    loadComments(complaint.id);
  } else {
    const countEl = document.getElementById('sheet-comments-count');
    const listEl = document.getElementById('sheet-comments-list');
    if (countEl) countEl.textContent = '0';
    if (listEl) listEl.innerHTML = '';
  }

  // Setup Buttons
  if (isActionable) {
    document.getElementById('sheet-btn-join').onclick = () => handleAction(complaint.id, 'join');
    document.getElementById('sheet-btn-like').onclick = () => handleAction(complaint.id, 'like');
    document.getElementById('sheet-btn-dislike').onclick = () => handleAction(complaint.id, 'dislike');

    document.getElementById('desc-btn-good').onclick = () => handleAction(complaint.id, 'good');
    document.getElementById('desc-btn-bad').onclick = () => handleAction(complaint.id, 'bad');
  }
}

function closeBottomSheet() {
  const sheet = document.getElementById('marker-bottom-sheet');
  if (sheet) sheet.classList.remove('open');
  const video = document.getElementById('live-camera-player');
  if (video) {
    video.pause();
    video.removeAttribute('src');
    video.load();
  }
  stopCameraHud();
  destroyCameraPlayback();
  currentComplaintId = null;
}

function initBottomSheet() {
  const sheet = document.getElementById('marker-bottom-sheet');
  const overlay = document.getElementById('sheet-overlay');
  const closeBtn = document.getElementById('sheet-close');
  const dragHandle = document.querySelector('.sheet-drag-handle');
  const content = document.getElementById('sheet-content');

  if (!sheet) return;

  overlay.addEventListener('click', closeBottomSheet);
  closeBtn.addEventListener('click', closeBottomSheet);

  let startY, currentY;
  let isDragging = false;

  dragHandle.addEventListener('touchstart', (e) => {
    startY = e.touches[0].clientY;
    isDragging = true;
    content.style.transition = 'none';
  }, { passive: true });

  document.addEventListener('touchmove', (e) => {
    if (!isDragging) return;
    currentY = e.touches[0].clientY;
    const diff = currentY - startY;
    if (diff > 0) {
      content.style.transform = `translateY(${diff}px)`;
    }
  }, { passive: true });

  document.addEventListener('touchend', (e) => {
    if (!isDragging) return;
    isDragging = false;
    content.style.transition = 'transform 0.4s cubic-bezier(0.32, 0.72, 0, 1)';

    if (currentY - startY > 80) {
      closeBottomSheet();
    }
    content.style.transform = '';
  });
}

async function loadComments(complaintId) {
  const list = document.getElementById('sheet-comments-list');
  const countEl = document.getElementById('sheet-comments-count');
  list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-secondary)">Загрузка комментариев...</div>';

  if (!state.supabase) return;

  try {
    const { data: comments, error } = await state.supabase
      .from('comments')
      .select('*')
      .eq('complaint_id', complaintId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    countEl.textContent = comments.length;

    if (comments.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-secondary)">Пока нет комментариев</div>';
      return;
    }

    list.innerHTML = comments.map(c => `
      <div class="sheet-comment">
        <div class="sheet-comment-header">
          <span class="sheet-comment-author">${c.author_name || 'Житель'}</span>
          <span class="sheet-comment-date">${getTimeAgo(c.created_at)}</span>
        </div>
        <div class="sheet-comment-text">${c.content}</div>
      </div>
    `).join('');

  } catch (e) {
    console.error('Error loading comments', e);
    list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--danger)">Ошибка загрузки</div>';
  }
}

window.handleAction = async function (id, action) {
  if (!state.supabase) return;

  try {
    const { data: currentData } = await state.supabase
      .from('complaints')
      .select('supporters, likes_count, dislikes_count')
      .eq('id', id)
      .single();

    if (!currentData) return;

    let updates = {};
    if (action === 'join') updates.supporters = (currentData.supporters || 0) + 1;
    if (action === 'like') updates.likes_count = (currentData.likes_count || 0) + 1;
    if (action === 'dislike') updates.dislikes_count = (currentData.dislikes_count || 0) + 1;

    const { error } = await state.supabase
      .from('complaints')
      .update(updates)
      .eq('id', id);

    if (!error) {
      // Update local state
      const marker = state.markers.get(id);
      if (marker && marker.complaintData) {
        if (action === 'join') marker.complaintData.supporters = updates.supporters;
        if (action === 'like') marker.complaintData.likes = updates.likes_count;
        if (action === 'dislike') marker.complaintData.dislikes = updates.dislikes_count;
      }

      // Update bottom sheet if open
      if (currentComplaintId === id) {
        if (action === 'join') document.getElementById('sheet-count-join').textContent = updates.supporters;
        if (action === 'like') document.getElementById('sheet-count-like').textContent = updates.likes_count;
        if (action === 'dislike') document.getElementById('sheet-count-dislike').textContent = updates.dislikes_count;
      }

      // If joins >= 10, trigger collective email (via backend/supabase edge function)
      if (action === 'join' && updates.supporters === 10) {
        fetch('https://xpainxohbdoruakcijyq.supabase.co/functions/v1/api/collective-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ complaint_id: id })
        }).catch(e => console.error('Error triggering email', e));
      }
    }
  } catch (e) {
    console.error('Action DB error', e);
  }

  if (action === 'good') {
    const btn = document.getElementById('desc-btn-good');
    if (btn) {
      btn.classList.toggle('active');
      btn.classList.toggle('good');
      if (typeof showToast === 'function') showToast('Оценка "Решено" принята!', 'success');
    }
  }
  if (action === 'bad') {
    const btn = document.getElementById('desc-btn-bad');
    if (btn) {
      btn.classList.toggle('active');
      btn.classList.toggle('bad');
      if (typeof showToast === 'function') showToast('Оценка "Плохо" принята', 'error');
    }
  }
};
function addMarker(complaint, animate = false) {
  if (complaint.lat == null || complaint.lng == null) return null;
  if (state.markers.has(complaint.id)) return state.markers.get(complaint.id);

  const marker = L.marker([complaint.lat, complaint.lng], {
    icon: createMarkerIcon(complaint)
  });

  marker.on('click', () => {
    openBottomSheet(complaint);
    state.map.setView([complaint.lat, complaint.lng], Math.max(state.map.getZoom(), 15), {
      animate: true,
      duration: 0.5
    });
  });
  marker.complaintData = complaint;
  state.markers.set(complaint.id, marker);
  if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') {
    state.eventMarkers.push(marker);
  }

  if (matchesFilters(complaint)) {
    if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') {
      state.eventLayer.addLayer(marker);
    } else {
      state.markerCluster.addLayer(marker);
    }

    if (animate) {
      focusOnNewMarker(marker, complaint);
    }
  }

  return marker;
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-ZOOM & POPUP FOR NEW MARKERS
// ═══════════════════════════════════════════════════════════════════════════════

function focusOnNewMarker(marker, complaint) {
  state.savedView = {
    center: state.map.getCenter(),
    zoom: state.map.getZoom()
  };

  if (state.autoReturnTimeout) {
    clearTimeout(state.autoReturnTimeout);
  }

  state.map.flyTo([complaint.lat, complaint.lng], CONFIG.newMarkerZoom, {
    duration: 1.2,
    easeLinearity: 0.25
  });

  setTimeout(() => {
    openBottomSheet(complaint);
    const isEmergency = complaint.category === 'ЧП';
    showNotification(`${isEmergency ? '🚨 ЧП: ' : '🆕 '}${complaint.summary || complaint.category}`, isEmergency ? 'emergency' : 'new');
  }, 1300);

  state.autoReturnTimeout = setTimeout(() => {
    closeBottomSheet();

    setTimeout(() => {
      if (state.savedView) {
        state.map.flyTo(state.savedView.center, state.savedView.zoom, {
          duration: 1,
          easeLinearity: 0.25
        });
        state.savedView = null;
      }
    }, CONFIG.returnDelay);
  }, CONFIG.popupDuration);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS CALCULATION
// ═══════════════════════════════════════════════════════════════════════════════

function calculateStats() {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const yearStart = new Date(now.getFullYear(), 0, 1);

  state.stats = {
    today: 0,
    month: 0,
    year: 0,
    total: state.complaints.length
  };

  state.complaints.forEach(c => {
    const created = new Date(c.created_at);
    if (created >= todayStart) state.stats.today++;
    if (created >= monthStart) state.stats.month++;
    if (created >= yearStart) state.stats.year++;
  });

  console.log(`📊 Stats: today=${state.stats.today}, month=${state.stats.month}, year=${state.stats.year}, total=${state.stats.total}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA LOADING
// ═══════════════════════════════════════════════════════════════════════════════

function clearMapData() {
  state.markerCluster?.clearLayers();
  state.eventLayer?.clearLayers();
  state.markers.clear();
  state.eventMarkers = [];
}

function replaceMapData(items) {
  clearMapData();
  state.complaints = items;
  items.forEach(item => addMarker(item));
  calculateStats();
  updateUI();
  sync3DData();
  applyFilters();
  return items;
}

function normalizeReportMarker(item) {
  if (item.lat == null || item.lng == null) return null;
  const source = item.source || '';
  let sourceLabel = source || 'Источник';
  if (source.startsWith('vk:')) sourceLabel = `VK · ${source.split(':', 2)[1]}`;
  if (source.startsWith('tg:') || source.startsWith('telegram:')) sourceLabel = `Telegram · ${source.split(':', 2)[1]}`;

  return {
    id: `report-${item.id}`,
    origin_id: item.id,
    summary: item.title || item.summary || item.category || 'Сообщение',
    description: item.description || '',
    lat: Number(item.lat),
    lng: Number(item.lng),
    address: item.address || null,
    category: item.category || 'Прочее',
    status: item.status || 'open',
    source,
    source_label: sourceLabel,
    source_kind: (source.startsWith('vk:') || source.startsWith('tg:') || source.startsWith('telegram:')) ? 'public' : 'report',
    source_table: 'reports',
    created_at: item.created_at || new Date().toISOString(),
    updated_at: item.updated_at || item.created_at || new Date().toISOString(),
    images: item.images || [],
    likes_count: item.likes_count || 0,
    dislikes_count: item.dislikes_count || 0,
    supporters: item.supporters || 0,
    link: item.post_link || null
  };
}

async function fetchBackendMapFeed() {
  const response = await fetch('/api/map/feed?limit=250&event_days=7', { cache: 'no-store' });
  if (!response.ok) {
    throw new Error(`Map feed HTTP ${response.status}`);
  }
  const payload = await response.json();
  return Array.isArray(payload.markers) ? payload.markers : [];
}

async function fetchSupabaseReportsFallback() {
  if (!state.supabase) return [];

  const { data, error } = await state.supabase
    .from('reports')
    .select('*')
    .not('lat', 'is', null)
    .not('lng', 'is', null)
    .order('created_at', { ascending: false })
    .limit(1000);

  if (error) throw error;
  return data.map(normalizeReportMarker).filter(Boolean);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK CYBER EVENTS
// ═══════════════════════════════════════════════════════════════════════════════
const MOCK_EVENTS = [
  { id: 'evt1', title: 'CyberJam 2026: Код и Неон', summary: 'CyberJam 2026: Код и Неон', category: 'Мероприятие', status: 'open', lat: 60.9410, lng: 76.5680, address: 'Кванториум', supporters: 154, likes_count: 55, created_at: new Date(Date.now() + 86400000).toISOString(), description: 'Взлом, кодинг и неон. 48 часов на создание лучшего кибер-проекта.', source_kind: 'event', source_label: 'CyberHub', link: 'https://nv-events.ru' },
  { id: 'evt2', title: 'Голографическая выставка', summary: 'Голографическая выставка', category: 'Мероприятие', status: 'open', lat: 60.9320, lng: 76.5510, address: 'Дворец Искусств', supporters: 320, likes_count: 140, created_at: new Date(Date.now() + 86400000 * 3).toISOString(), description: 'Иммерсивное искусство нового поколения. Виртуальные инсталляции.', source_kind: 'event', source_label: 'ArtSpace', link: 'https://nv-events.ru' },
  { id: 'evt3', title: 'Дрон-рейсинг', summary: 'Дрон-рейсинг', category: 'Мероприятие', status: 'open', lat: 60.9380, lng: 76.5400, address: 'Стадион', supporters: 42, likes_count: 12, created_at: new Date(Date.now() + 86400000 * 5).toISOString(), description: 'Соревнования по полетам на скоростных FPV-дронах. Неоновые трассы.', source_kind: 'event', source_label: 'DroneNV', link: 'https://nv-events.ru' },
  { id: 'evt4', title: 'Night City Market', summary: 'Night City Market', category: 'Мероприятие', status: 'open', lat: 60.9450, lng: 76.5550, address: 'Парк Победы', supporters: 88, likes_count: 40, created_at: new Date(Date.now() + 86400000 * 2).toISOString(), description: 'Гастрономия уличных киосков в неоновом свете. Фестиваль уличной еды.', source_kind: 'event', source_label: 'CityFood', link: 'https://nv-events.ru' },
  { id: 'evt5', title: 'Лекторий: ИИ-Сингулярность', summary: 'Лекторий: ИИ-Сингулярность', category: 'Мероприятие', status: 'open', lat: 60.9300, lng: 76.5700, address: 'Библиотека им. Пушкина', supporters: 105, likes_count: 22, created_at: new Date(Date.now() + 86400000 * 6).toISOString(), description: 'Обсуждение будущего сильного ИИ с ведущими инженерами.', source_kind: 'event', source_label: 'TechTalks', link: 'https://nv-events.ru' }
];

function injectMockEvents(markers) {
  const existingIds = new Set(markers.map(m => String(m.id)));
  MOCK_EVENTS.forEach(evt => {
    if (!existingIds.has(String(evt.id))) {
      markers.push(evt);
    }
  });
  return markers;
}

async function loadComplaints() {
  console.log('📥 Loading...');
  setSplashStatus('Загружаем обращения...', 82);

  try {
    const feedMarkers = await fetchBackendMapFeed();
    if (feedMarkers.length > 0) {
      console.log(`✅ Loaded ${feedMarkers.length} map markers from backend feed`);
      return replaceMapData(injectMockEvents(feedMarkers));
    }
  } catch (error) {
    console.warn('Backend map feed unavailable, falling back to Supabase reports', error);
  }

  try {
    const fallbackMarkers = await fetchSupabaseReportsFallback();
    if (fallbackMarkers.length > 0) {
      console.log(`✅ Loaded ${fallbackMarkers.length} report markers from Supabase`);
      return replaceMapData(injectMockEvents(fallbackMarkers));
    }
  } catch (error) {
    console.error('❌ Supabase reports fallback error:', error);
  }

  return loadDemoComplaints();
}

function loadDemoComplaints() {
  console.log('📦 Demo mode');
  const now = Date.now();
  const demoData = [
    { id: 'd1', summary: 'Прорыв трубы на улице', category: 'ЧП', status: 'open', lat: 60.9400, lng: 76.5650, address: 'ул. Ленина, 45', supporters: 45, created_at: new Date(now - 3600000).toISOString() },
    { id: 'd2', summary: 'Яма на дороге', category: 'Дороги', status: 'open', lat: 60.9380, lng: 76.5550, address: 'ул. Мира, 22', supporters: 15, created_at: new Date(now).toISOString() },
    { id: 'd3', summary: 'Протечка в подъезде', category: 'ЖКХ', status: 'in_progress', lat: 60.9350, lng: 76.5500, address: 'ул. Нефтяников, 10', supporters: 8, created_at: new Date(now - 86400000).toISOString() },
    { id: 'd4', summary: 'Сломанные качели', category: 'Детские площадки', status: 'open', lat: 60.9360, lng: 76.5700, address: 'ул. Чапаева, 5', supporters: 23, created_at: new Date(now - 172800000).toISOString() },
    { id: 'd5', summary: 'Не горит фонарь', category: 'Освещение', status: 'resolved', lat: 60.9320, lng: 76.5480, address: 'ул. 60 лет Октября', supporters: 5, created_at: new Date(now - 604800000).toISOString() },
    { id: 'd6', summary: 'Мусор у контейнеров', category: 'Мусор', status: 'open', lat: 60.9410, lng: 76.5600, address: 'мкр. 10П', supporters: 31, created_at: new Date(now - 2592000000).toISOString() },
    { id: 'd7', summary: 'Снег не убран', category: 'Снег/Наледь', status: 'open', lat: 60.9330, lng: 76.5520, address: 'пр. Победы', supporters: 12, created_at: new Date(now - 86400000 * 15).toISOString() }
  ];

  return replaceMapData(injectMockEvents(demoData));
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME SUBSCRIPTION
// ═══════════════════════════════════════════════════════════════════════════════

function startDataRefreshLoop() {
  if (state.mapRefreshTimer) clearInterval(state.mapRefreshTimer);
  state.mapRefreshTimer = setInterval(() => {
    loadComplaints().catch(error => console.error('Map refresh error', error));
  }, 60000);
}

function subscribeToRealtime() {
  if (!state.supabase) return;

  console.log('📡 Subscribing to realtime...');

  state.realtimeSubscription = state.supabase
    .channel('complaints-realtime')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'complaints' }, (payload) => {
      console.log('🆕 New:', payload.new);
      handleNewComplaint(payload.new);
    })
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'complaints' }, (payload) => {
      handleUpdatedComplaint(payload.new);
    })
    .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'complaints' }, (payload) => {
      handleDeletedComplaint(payload.old);
    })
    .subscribe((status) => {
      console.log(`📡 Realtime: ${status}`);
    });
}

function handleNewComplaint(complaint) {
  state.complaints.unshift(complaint);
  addMarker(complaint, true);
  calculateStats();
  updateUI();
  sync3DData();
}

function handleUpdatedComplaint(complaint) {
  const idx = state.complaints.findIndex(c => c.id === complaint.id);
  if (idx !== -1) state.complaints[idx] = complaint;

  const marker = state.markers.get(complaint.id);
  if (marker) {
    marker.setIcon(createMarkerIcon(complaint));
    marker.complaintData = complaint;

    if (currentComplaintId === complaint.id) {
      openBottomSheet(complaint);
    }
  }

  sync3DData();
}

function handleDeletedComplaint(complaint) {
  state.complaints = state.complaints.filter(c => c.id !== complaint.id);
  const marker = state.markers.get(complaint.id);
  if (marker) {
    state.markerCluster.removeLayer(marker);
    state.markers.delete(complaint.id);
  }
  calculateStats();
  updateUI();
  sync3DData();
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERS
// ═══════════════════════════════════════════════════════════════════════════════

function matchesDayFilter(complaint) {
  const created = new Date(complaint.created_at);
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') {
    const targetDate = new Date(created.getFullYear(), created.getMonth(), created.getDate());
    const diffMs = targetDate.getTime() - todayStart.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    // Убираем мероприятия, которые уже прошли
    if (diffDays < 0) return false;

    if (state.currentDayFilter === 'all') return true;

    switch (state.currentDayFilter) {
      case 'today': return diffDays === 0;
      case '3days': return diffDays >= 0 && diffDays <= 2;
      case 'week': return diffDays >= 0 && diffDays <= 7;
      case 'month': return diffDays >= 0 && diffDays <= 30;
      default: return true;
    }
  }

  if (state.currentDayFilter === 'all') return true;

  const diffDays = (now - created) / (1000 * 60 * 60 * 24);
  switch (state.currentDayFilter) {
    case 'today': return diffDays <= 1;
    case '3days': return diffDays <= 3;
    case 'week': return diffDays <= 7;
    case 'month': return diffDays <= 30;
    default: return true;
  }
}

function matchesFilters(complaint) {
  if (state.currentCategoryFilter !== 'all' && complaint.category !== state.currentCategoryFilter) {
    return false;
  }
  return matchesDayFilter(complaint);
}

function applyFilters() {
  state.markerCluster.clearLayers();
  if (state.cameraLayer) state.cameraLayer.clearLayers();
  if (state.eventLayer) state.eventLayer.clearLayers();

  const isCameraMode = state.currentCategoryFilter === 'Камеры';

  if (isCameraMode) {
    state.cameraMarkers.forEach(cm => cm.marker.addTo(state.cameraLayer));
  }

  state.complaints.forEach(complaint => {
    const marker = state.markers.get(complaint.id);
    if (marker && matchesFilters(complaint)) {
      if (complaint.category === 'Мероприятие' || complaint.source_kind === 'event') {
        state.eventLayer.addLayer(marker);
      } else {
        state.markerCluster.addLayer(marker);
      }
    }
  });

  updateUI();
}

function initFilters() {
  const catPanel = document.getElementById('category-filters');
  if (catPanel) {
    catPanel.addEventListener('click', (e) => {
      const btn = e.target.closest('.filter-btn');
      if (!btn) return;

      state.currentCategoryFilter = btn.dataset.filter;
      catPanel.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });
  }

  const dayPanel = document.getElementById('day-filters');
  if (dayPanel) {
    dayPanel.addEventListener('click', (e) => {
      const btn = e.target.closest('.day-btn');
      if (!btn) return;

      state.currentDayFilter = btn.dataset.day;
      dayPanel.querySelectorAll('.day-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

function updateUI() {
  const filteredCount = state.complaints.filter(matchesFilters).length;

  // Update main counter
  const countEl = document.getElementById('complaint-count');
  if (countEl) countEl.textContent = filteredCount;

  // Update stats counters
  const todayEl = document.getElementById('stat-today');
  const monthEl = document.getElementById('stat-month');
  const yearEl = document.getElementById('stat-year');

  if (todayEl) todayEl.textContent = state.stats.today;
  if (monthEl) monthEl.textContent = state.stats.month;
  if (yearEl) yearEl.textContent = state.stats.year;
}

function hideSplash() {
  splashController?.hide();
  state.isLoading = false;
}

function setSplashStatus(text, progress = null) {
  if (splashController) {
    splashController.setStatus(text, progress);
    return;
  }

  const statusEl = document.getElementById('splash-status');
  if (statusEl) statusEl.textContent = text;
}

function startSplashTicker() {
  splashController?.startTicker();
}

function stopSplashTicker() {
  splashController?.stopTicker();
}

function initSplashInteractions() {
  if (!window.SplashSystem) {
    console.warn('SplashSystem module is not available');
    return;
  }

  splashController = window.SplashSystem.create({
    rootId: 'splash',
    messages: SPLASH_MESSAGES,
    variants: SPLASH_VARIANTS,
    initialProgress: state.splashProgress,
    audioEnabled: state.splashAudioEnabled,
    onAudioChange: (enabled) => {
      state.splashAudioEnabled = enabled;
    },
    onProgress: (progress) => {
      state.splashProgress = progress;
    },
    onHidden: () => {
      state.isLoading = false;
    }
  }).init();
}

function showNotification(message, type = 'info') {
  const colors = {
    emergency: '#FF3D00',
    new: '#00E676',
    info: '#3b82f6',
    error: '#ef4444'
  };

  const notification = document.createElement('div');
  notification.style.cssText = `
    position:fixed;top:70px;left:50%;transform:translateX(-50%);
    padding:10px 18px;background:white;border-radius:20px;
    box-shadow:0 4px 20px rgba(0,0,0,0.15);font-size:13px;font-weight:500;
    color:#0f172a;z-index:9999;border-left:4px solid ${colors[type] || colors.info};
    animation:slideDown 0.3s ease;max-width:90%;text-align:center;
  `;
  notification.textContent = message;
  document.body.appendChild(notification);

  setTimeout(() => {
    notification.style.animation = 'slideUp 0.3s ease';
    setTimeout(() => notification.remove(), 300);
  }, type === 'emergency' ? 6000 : 4000);
}

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('ru-RU', {
    day: 'numeric', month: 'short', year: 'numeric'
  });
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function getTimeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(mins / 60);
  const days = Math.floor(hours / 24);

  if (mins < 1) return 'сейчас';
  if (mins < 60) return `${mins} мин`;
  if (hours < 24) return `${hours} ч`;
  if (days < 7) return `${days} дн`;
  return formatDate(dateStr);
}

function formatMarkerTime(item) {
  if (item.category === 'Мероприятие' || item.source_kind === 'event') {
    const dt = new Date(item.created_at);
    return `🗓 ${dt.toLocaleString('ru-RU', { day: '2-digit', month: 'long', hour: '2-digit', minute: '2-digit' })}${item.source_label ? ` · ${item.source_label}` : ''}`;
  }
  return `🕒 ${getTimeAgo(item.created_at)}${item.source_label ? ` · ${item.source_label}` : ''}`;
}

// Animation keyframes
const style = document.createElement('style');
style.textContent = `
  @keyframes slideDown { from{transform:translateX(-50%) translateY(-20px);opacity:0} to{transform:translateX(-50%) translateY(0);opacity:1} }
  @keyframes slideUp { from{transform:translateX(-50%) translateY(0);opacity:1} to{transform:translateX(-50%) translateY(-20px);opacity:0} }
  @keyframes emergency-pulse { 0%,100%{box-shadow:0 0 0 0 rgba(220,38,38,0.4)} 50%{box-shadow:0 0 0 8px rgba(220,38,38,0)} }
  .custom-cluster{background:transparent!important;border:none!important;}
  .popup-card.emergency{border:2px solid #FF3D00;background:rgba(255,61,0,0.14)!important;}
  
  /* CYBER HUD EVENT MARKER CSS */
  @keyframes HUDspin { 100% { transform: rotate(405deg); } }
  @keyframes HUDspin-reverse { 100% { transform: rotate(-375deg); } }
  .event-cyber-marker { display:flex; align-items:center; justify-content:center; width:44px; height:44px; position:relative; z-index:1000; }
  .cyber-pulse-ring { position:absolute; inset:-4px; border:1px dashed #39FF14; border-radius:10%; transform:rotate(45deg); animation:HUDspin 6s linear infinite; mix-blend-mode:screen; }
  .cyber-pulse-ring-inner { position:absolute; inset:2px; border:2px solid rgba(57,255,20,0.5); border-radius:10%; transform:rotate(-15deg); animation:HUDspin-reverse 8s linear infinite; }
  .cyber-hexagon { position:relative; width:26px; height:26px; background:#020617; border:2px solid #39FF14; transform:rotate(45deg); display:flex; align-items:center; justify-content:center; box-shadow:0 0 16px rgba(57,255,20,0.6), inset 0 0 8px rgba(57,255,20,0.4); z-index:2; }
  .cyber-icon { transform:rotate(-45deg); font-size:14px; line-height:1; filter:drop-shadow(0 0 4px #39FF14); }
`;
document.head.appendChild(style);

// ═══════════════════════════════════════════════════════════════════════════════
// ADD COMPLAINT
// ═══════════════════════════════════════════════════════════════════════════════

function initAddComplaintButton() {
  const btn = document.getElementById('add-complaint-btn');
  if (!btn) return;

  btn.addEventListener('click', () => {
    const center = state.map.getCenter();
    alert(`Добавление жалобы:\n${center.lat.toFixed(6)}, ${center.lng.toFixed(6)}`);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

async function init() {
  console.log('🚀 Init...');
  initSplashInteractions();
  initBottomSheet();

  const supabaseOk = await initSupabase();
  if (!supabaseOk) console.warn('⚠️ Demo mode');

  if (!initMap()) return;

  initFilters();
  initAddComplaintButton();
  initToggle3D();

  await loadComplaints();
  initCameraLayer();
  startCameraAiMonitor();
  startDataRefreshLoop();

  setSplashStatus('Готово', 100);
  setTimeout(hideSplash, 550);
  console.log('✅ Ready');
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

window.addEventListener('beforeunload', () => {
  if (state.mapRefreshTimer) clearInterval(state.mapRefreshTimer);
  if (state.realtimeSubscription) {
    state.supabase.removeChannel(state.realtimeSubscription);
  }
});


const MapPulse = {
  bpm: 72,
  targetBpm: 72,
  canvas: null,
  ctx: null,
  history: [],
  frameCount: 0,

  init() {
    this.canvas = document.getElementById('mapPulseCanvas');
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.history = new Array(50).fill(0);
    this.animate();
    setInterval(() => this.updatePulse(), 2000);
  },

  updatePulse() {
    if (!state.complaints) return;

    // Calculate pulse based on today's complaints and categories
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let todaysCount = 0;
    let emergencyCount = 0;

    state.complaints.forEach(c => {
      const created = new Date(c.created_at);
      if (created >= today) {
        todaysCount++;
        if (c.category === 'ЧП') emergencyCount++;
      }
    });

    let newBpm = 60 + (todaysCount * 0.5) + (emergencyCount * 10);
    if (newBpm > 160) newBpm = 160;

    this.targetBpm = newBpm;

    let mood = 'Спокойно';
    let color = '#00E676';
    if (this.targetBpm > 120 || emergencyCount > 0) {
      mood = 'ЧП / Тревога';
      color = '#FF3D00';
    } else if (this.targetBpm > 90) {
      mood = 'Активно';
      color = '#f59e0b';
    } else if (this.targetBpm > 75) {
      mood = 'Умеренно';
      color = '#0ea5e9';
    }

    const bpmEl = document.getElementById('pulse-bpm');
    const moodEl = document.getElementById('pulse-mood');

    if (bpmEl) bpmEl.textContent = Math.round(this.targetBpm);
    if (moodEl) {
      moodEl.textContent = mood;
      moodEl.style.color = color;
    }
  },

  animate() {
    if (!this.canvas || !this.ctx) return;
    this.frameCount++;

    this.bpm += (this.targetBpm - this.bpm) * 0.05;

    const time = Date.now();
    const beatInterval = 60000 / this.bpm;
    const phase = (time % beatInterval) / beatInterval;

    let y = 0;
    if (phase < 0.1) y = Math.sin(phase * Math.PI * 10) * 15;
    else if (phase < 0.2) y = -Math.sin((phase - 0.1) * Math.PI * 10) * 8;
    else if (phase > 0.8 && phase < 0.9) y = Math.sin((phase - 0.8) * Math.PI * 10) * 5;

    // Add noise
    y += (Math.random() - 0.5) * 2;

    this.history.push(y);
    this.history.shift();

    const width = this.canvas.width;
    const height = this.canvas.height;

    this.ctx.clearRect(0, 0, width, height);
    this.ctx.beginPath();

    let color = '#00E676';
    if (this.bpm > 120) color = '#FF3D00';
    else if (this.bpm > 90) color = '#f59e0b';

    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 2;

    for (let i = 0; i < this.history.length; i++) {
      const x = (i / (this.history.length - 1)) * width;
      const val = height / 2 - this.history[i];
      if (i === 0) this.ctx.moveTo(x, val);
      else this.ctx.lineTo(x, val);
    }
    this.ctx.stroke();

    requestAnimationFrame(() => this.animate());
  }
};

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * 3D LAYER LOGIC
 * ═══════════════════════════════════════════════════════════════════════════════
 */

function initToggle3D() {
  const btn = document.getElementById('toggle-3d-btn');
  const map3d = document.getElementById('map-3d');
  const iframe = document.getElementById('iframe-3d');
  const mapLeaflet = document.getElementById('map');

  if (!btn || !map3d) return;

  btn.addEventListener('click', () => {
    state.is3DMode = !state.is3DMode;

    if (state.is3DMode) {
      btn.innerHTML = '🌍';
      btn.style.background = 'var(--primary)';
      btn.style.color = 'white';
      map3d.style.display = 'block';
      mapLeaflet.style.opacity = '0';
      mapLeaflet.style.pointerEvents = 'none';

      if (!iframe.dataset.bound) {
        iframe.addEventListener('load', () => {
          sync3DData();
        });
        iframe.dataset.bound = 'true';
      }

      if (!iframe.src || iframe.src.endsWith('/')) {
        iframe.src = 'cesium_view.html';
      } else {
        sync3DData();
      }
      showNotification('3D Режим активирован', 'info');
    } else {
      btn.innerHTML = '🏙️';
      btn.style.background = 'white';
      btn.style.color = 'var(--text)';
      map3d.style.display = 'none';
      mapLeaflet.style.opacity = '1';
      mapLeaflet.style.pointerEvents = 'auto';
      showNotification('Возврат к плоской карте', 'info');
    }
  });
}

function get3DFrameWindow() {
  const iframe = document.getElementById('iframe-3d');
  return iframe?.contentWindow || null;
}

function postTo3DFrame(message) {
  const frameWindow = get3DFrameWindow();
  if (!frameWindow) return false;
  frameWindow.postMessage(message, '*');
  return true;
}

function sync3DData() {
  const complaintsPayload = state.complaints
    .filter(item => item.lat != null && item.lng != null)
    .map(item => ({
      id: item.id,
      lat: item.lat,
      lng: item.lng,
      title: item.summary || item.title || item.category || 'Объект',
      type: item.category === 'Строительство' ? 'construction' : (item.category === 'Мероприятие' ? 'event' : 'complaint'),
      color: CATEGORIES[item.category]?.color || '#00E5FF',
      description: item.description || '',
      developer: item.author_name || '',
      deadline: item.deadline || '',
      floors: item.floors || '',
      height: item.height || 12
    }));

  const cameraPayload = CAMERAS.map(item => ({
    lat: item.lat,
    lng: item.lon,
    n: item.name,
    s: item.url
  }));

  postTo3DFrame({ type: 'citypulse:setCameras', payload: cameraPayload });
  postTo3DFrame({ type: 'citypulse:setMarkers', payload: complaintsPayload });
}

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * CITY CAMERAS LAYER
 * ═══════════════════════════════════════════════════════════════════════════════
 */

function initCameraLayer() {
  fetch('cameras_nv.json')
    .then(response => response.json())
    .then(cameras => {
      CAMERAS.length = 0;
      state.cameraMarkers = [];

      cameras.forEach((cam, index) => {
        const lat = Number(cam.lat);
        const lon = Number(cam.lng);
        const url = typeof cam.s === 'string' ? cam.s.trim() : '';
        if (!Number.isFinite(lat) || !Number.isFinite(lon) || !url || cam.active === false) return;

        CAMERAS.push({
          id: `cam_${index + 1}`,
          name: cam.n,
          lat,
          lon,
          url,
          peopleCount: Number.isFinite(Number(cam.peopleCount ?? cam.people_count))
            ? Number(cam.peopleCount ?? cam.people_count)
            : null,
          detectorEnabled: cam.detectorEnabled === true || cam.detector_ready === true,
          desc: `Камера наблюдения: ${cam.n}`
        });
      });

      CAMERAS.forEach(cam => {
        const icon = L.divIcon({
          className: 'camera-marker',
          html: `<div style="background:var(--primary); width:32px; height:32px; border-radius:50%; display:flex; align-items:center; justify-content:center; box-shadow:0 4px 10px rgba(0,0,0,0.3); border:2px solid white; transform: rotate(-45deg);">
                   <span style="transform: rotate(45deg); font-size:16px;">📷</span>
                 </div>`,
          iconSize: [32, 32],
          iconAnchor: [16, 32]
        });

        const marker = L.marker([cam.lat, cam.lon], { icon });
        marker.on('click', () => openCameraDetails(cam));
        state.cameraMarkers.push({ marker, id: cam.id, lat: cam.lat, lon: cam.lon, name: cam.name, url: cam.url });
      });

      sync3DData();
      applyFilters();
    })
    .catch(error => console.error('Camera layer load error', error));
}

function destroyCameraPlayback() {
  stopCameraHud();
  const video = document.getElementById('live-camera-player');
  if (!video) return;
  try {
    video.pause();
    video.removeAttribute('src');
    video.load();
  } catch (e) {
    console.warn('Camera player cleanup error', e);
  }
}

function getCameraHudTimeLabel() {
  return new Date().toLocaleTimeString('ru-RU', {
    timeZone: CAMERA_HUD_TIMEZONE,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

function getCameraHudDateLabel() {
  return new Date().toLocaleDateString('ru-RU', {
    timeZone: CAMERA_HUD_TIMEZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  });
}

function mapCameraWeatherCode(code, isDay) {
  if (code === 0) {
    return {
      icon: isDay ? '☀️' : '🌙',
      label: isDay ? 'Ясно' : 'Ясная ночь',
      accent: '#7DE7FF'
    };
  }

  if ([1, 2].includes(code)) {
    return {
      icon: isDay ? '⛅' : '☁️',
      label: 'Переменная облачность',
      accent: '#8BE7FF'
    };
  }

  if (code === 3) {
    return { icon: '☁️', label: 'Пасмурно', accent: '#86B7DA' };
  }

  if ([45, 48].includes(code)) {
    return { icon: '🌫️', label: 'Туман', accent: '#B8D7EA' };
  }

  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return { icon: '🌧️', label: 'Дождь', accent: '#3DA8FF' };
  }

  if (code >= 71 && code <= 77) {
    return { icon: '❄️', label: 'Снег', accent: '#C8F4FF' };
  }

  if (code >= 95) {
    return { icon: '⚡', label: 'Гроза', accent: '#FFC857' };
  }

  return { icon: '☁️', label: 'Нет данных', accent: '#FFC857' };
}

function ensureCameraHudWeather(force = false) {
  const isFresh = CAMERA_HUD_STATE.weather &&
    (Date.now() - CAMERA_HUD_STATE.weatherFetchedAt) < CAMERA_HUD_WEATHER_TTL_MS;
  if (!force && isFresh) return Promise.resolve(CAMERA_HUD_STATE.weather);
  if (CAMERA_HUD_STATE.pendingWeatherPromise) {
    return CAMERA_HUD_STATE.pendingWeatherPromise;
  }

  const params = new URLSearchParams({
    latitude: String(CONFIG.center[0]),
    longitude: String(CONFIG.center[1]),
    current: 'temperature_2m,apparent_temperature,weather_code,is_day',
    timezone: 'auto',
    forecast_days: '1'
  });

  CAMERA_HUD_STATE.pendingWeatherPromise = fetch(`https://api.open-meteo.com/v1/forecast?${params.toString()}`)
    .then(response => {
      if (!response.ok) {
        throw new Error(`Weather request failed: ${response.status}`);
      }
      return response.json();
    })
    .then(payload => {
      const current = payload && payload.current ? payload.current : {};
      const code = Number.isFinite(Number(current.weather_code))
        ? Number(current.weather_code)
        : -1;
      const isDay = Number(current.is_day || 0) === 1;
      const mapped = mapCameraWeatherCode(code, isDay);
      const temperature = Number(current.temperature_2m);
      const apparent = Number(current.apparent_temperature);
      CAMERA_HUD_STATE.weather = {
        ...mapped,
        temperatureLabel: Number.isFinite(temperature) ? `${Math.round(temperature)}°` : '--°',
        feelsLikeLabel: Number.isFinite(apparent)
          ? `Ощущается ${Math.round(apparent)}°`
          : 'Погодный канал...'
      };
      CAMERA_HUD_STATE.weatherFetchedAt = Date.now();
      return CAMERA_HUD_STATE.weather;
    })
    .catch(error => {
      console.warn('Camera HUD weather error', error);
      CAMERA_HUD_STATE.weather = {
        icon: '☁️',
        label: 'Нет данных',
        accent: '#FFC857',
        temperatureLabel: '--°',
        feelsLikeLabel: 'Погода недоступна'
      };
      CAMERA_HUD_STATE.weatherFetchedAt = Date.now();
      return CAMERA_HUD_STATE.weather;
    })
    .finally(() => {
      CAMERA_HUD_STATE.pendingWeatherPromise = null;
    });

  return CAMERA_HUD_STATE.pendingWeatherPromise;
}

function renderCameraHud(cam) {
  const weather = CAMERA_HUD_STATE.weather || {
    icon: '⌛',
    label: 'Синхронизация',
    accent: '#9AF8FF',
    temperatureLabel: '--°',
    feelsLikeLabel: 'Погодный канал...'
  };
  const peopleCountRaw = cam.peopleCount;
  const peopleCount = peopleCountRaw == null ? Number.NaN : Number(peopleCountRaw);
  const hasPeopleCount = Number.isFinite(peopleCount);
  const detectorEnabled = cam.detectorEnabled === true || hasPeopleCount;

  const iconEl = document.getElementById('live-camera-weather-icon');
  const weatherValueEl = document.getElementById('live-camera-weather');
  const weatherLabelEl = document.getElementById('live-camera-weather-label');
  const weatherMetaEl = document.getElementById('live-camera-weather-meta');
  const timeValueEl = document.getElementById('live-camera-time');
  const timeLabelEl = document.getElementById('live-camera-time-label');
  const peopleValueEl = document.getElementById('live-camera-people');
  const peopleLabelEl = document.getElementById('live-camera-people-label');
  const detectorEl = document.getElementById('live-camera-detector');
  const weatherChipEl = document.getElementById('live-camera-weather-chip');

  if (iconEl) iconEl.textContent = weather.icon;
  if (weatherValueEl) weatherValueEl.textContent = weather.temperatureLabel;
  if (weatherLabelEl) weatherLabelEl.textContent = weather.label;
  if (weatherMetaEl) weatherMetaEl.textContent = weather.feelsLikeLabel;
  if (timeValueEl) timeValueEl.textContent = getCameraHudTimeLabel();
  if (timeLabelEl) timeLabelEl.textContent = getCameraHudDateLabel();
  if (peopleValueEl) peopleValueEl.textContent = hasPeopleCount ? String(peopleCount) : '--';
  if (peopleLabelEl) {
    peopleLabelEl.textContent = detectorEnabled ? 'AI counter online' : 'Detector standby';
  }
  if (detectorEl) {
    detectorEl.textContent = detectorEnabled
      ? `AI VISION · ${hasPeopleCount ? 'People telemetry synced' : 'People counter online'}`
      : 'AI VISION · Vision channel pending';
  }
  if (weatherChipEl) {
    weatherChipEl.style.borderColor = weather.accent;
    weatherChipEl.style.boxShadow = `0 0 24px ${weather.accent}33`;
  }
}

function startCameraHud(cam) {
  stopCameraHud();
  renderCameraHud(cam);
  ensureCameraHudWeather().then(() => renderCameraHud(cam));
  CAMERA_HUD_STATE.timer = setInterval(() => {
    renderCameraHud(cam);
    const stale = !CAMERA_HUD_STATE.weatherFetchedAt ||
      (Date.now() - CAMERA_HUD_STATE.weatherFetchedAt) > CAMERA_HUD_WEATHER_TTL_MS;
    if (stale) {
      ensureCameraHudWeather().then(() => renderCameraHud(cam));
    }
  }, 1000);
}

function stopCameraHud() {
  if (CAMERA_HUD_STATE.timer) {
    clearInterval(CAMERA_HUD_STATE.timer);
    CAMERA_HUD_STATE.timer = null;
  }
}

async function attachCameraPlayback(url) {
  const video = document.getElementById('live-camera-player');
  const fallbackLink = document.getElementById('live-camera-fallback-link');
  if (!video) return;

  destroyCameraPlayback();
  if (fallbackLink) fallbackLink.style.display = 'none';
  video.src = url;
  video.load();
  const started = await video.play().then(() => true).catch(() => false);
  if (!started && fallbackLink) fallbackLink.style.display = 'inline';
}

function openCameraDetails(cam) {
  const sheet = document.getElementById('marker-bottom-sheet');
  if (!sheet) return;

  document.getElementById('sheet-title').textContent = cam.name;
  document.getElementById('sheet-icon').textContent = '📷';
  document.getElementById('sheet-status').textContent = 'В ПРЯМОМ ЭФИРЕ';
  document.getElementById('sheet-status').className = 'sheet-status resolved';
  document.getElementById('sheet-address').textContent = 'Координаты: ' + cam.lat + ', ' + cam.lon;
  document.getElementById('sheet-desc').innerHTML = `
    <div style="margin-bottom:12px;">${cam.desc}</div>
    <div style="width:100%; height:200px; background:#000; border-radius:12px; overflow:hidden; position:relative; border:1px solid rgba(125,231,255,0.22); box-shadow:0 18px 42px rgba(0,0,0,0.38);">
      <video id="live-camera-player" style="width:100%; height:100%; border:none; object-fit:cover;" controls autoplay muted playsinline></video>
      <button onclick="document.getElementById('live-camera-player').requestFullscreen()" style="position:absolute; bottom:10px; right:10px; background:rgba(0,0,0,0.6); color:white; border:none; padding:8px 12px; border-radius:8px; cursor:pointer; font-size:12px; z-index:10; backdrop-filter: blur(4px);">⛶ На весь экран</button>
      <div id="live-camera-fallback-link" style="display:none; position:absolute; inset:0; background:rgba(0,0,0,0.8); color:white; padding:20px; text-align:center; align-items:center; justify-content:center; flex-direction:column; z-index:20;">
        <span style="font-size:24px; margin-bottom:10px;">⚠️</span>
        <div style="margin-bottom: 12px;">Видеопоток недоступен на этом устройстве</div>
        <a href="${cam.url}" target="_blank" style="color:var(--primary); display:inline-block; padding:8px 16px; border:1px solid var(--primary); border-radius:8px; text-decoration:none;">Открыть источник</a>
      </div>
    </div>
  `;

  // Hide support/reactions for cameras
  const gallery = document.getElementById('sheet-gallery');
  gallery.style.display = 'none';

  sheet.classList.add('open');
  startCameraHud(cam);
  attachCameraPlayback(cam.url);
}

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * AI CAMERA MONITOR (Simulation)
 * ═══════════════════════════════════════════════════════════════════════════════
 */

function startCameraAiMonitor() {
  console.log('🤖 AI Camera Monitor started...');

  // Simulate monitoring every 30-60 seconds
  setInterval(() => {
    const r = Math.random();
    if (r > 0.95) { // 5% chance of an event
      const cam = CAMERAS[Math.floor(Math.random() * CAMERAS.length)];
      const events = ['ДТП зафиксировано', 'Затор на перекрестке', 'Подозрительная активность'];
      const event = events[Math.floor(Math.random() * events.length)];

      showNotification(`🤖 AI Монитор (${cam.name}): ${event}`, 'emergency');

      // Auto-focus map to that camera if not in 3D mode
      if (!state.is3DMode) {
        state.map.setView([cam.lat, cam.lon], 16);
      }
    }
  }, 45000);
}

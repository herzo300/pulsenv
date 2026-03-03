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
  'ЧП': { icon: '🚨', color: '#dc2626', priority: 1 },
  
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
  'Экология': { icon: '🌿', color: '#10b981', priority: 3 },
  
  // Общественные пространства
  'Детские площадки': { icon: '🎠', color: '#ec4899', priority: 3 },
  'Спортивные площадки': { icon: '⚽', color: '#8b5cf6', priority: 4 },
  'Парки и скверы': { icon: '🌲', color: '#059669', priority: 4 },
  'Парковки': { icon: '🅿️', color: '#6366f1', priority: 4 },
  
  // Здания
  'Лифты и подъезды': { icon: '🏢', color: '#64748b', priority: 3 },
  'Строительство': { icon: '🚧', color: '#d97706', priority: 4 },
  
  // Безопасность и погода
  'Безопасность': { icon: '🛡️', color: '#dc2626', priority: 2 },
  'Снег/Наледь': { icon: '❄️', color: '#38bdf8', priority: 2 },
  
  // Социальные
  'Медицина': { icon: '🏥', color: '#14b8a6', priority: 2 },
  'Здравоохранение': { icon: '🏥', color: '#14b8a6', priority: 2 },
  'Образование': { icon: '🎓', color: '#8b5cf6', priority: 3 },
  'Социальная сфера': { icon: '👥', color: '#6366f1', priority: 4 },
  
  // Другие
  'Животные': { icon: '🐶', color: '#f59e0b', priority: 4 },
  'Торговля': { icon: '🛒', color: '#10b981', priority: 4 },
  'Трудовое право': { icon: '📄', color: '#64748b', priority: 4 },
  
  // По умолчанию
  'Прочее': { icon: '📌', color: '#64748b', priority: 5 }
};

// Основные категории для фильтров (компактный набор)
const MAIN_CATEGORIES = [
  'ЧП', 'ЖКХ', 'Дороги', 'Благоустройство', 'Транспорт', 'Освещение',
  'Мусор', 'Детские площадки', 'Парковки', 'Безопасность', 'Снег/Наледь',
  'Медицина', 'Экология', 'Прочее'
];

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
  }
};

const SPLASH_MESSAGES = [
  'Подключаем карту...',
  'Загружаем обращения...',
  'Включаем live-обновления...',
  'Почти готово'
];

let splashMessageIndex = 0;
let splashMessageInterval = null;

// ═══════════════════════════════════════════════════════════════════════════════
// SUPABASE CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

async function initSupabase() {
  let supabaseLib = window.supabase;
  
  if (!supabaseLib || !supabaseLib.createClient) {
    setSplashStatus('Подключаем Supabase...');
    console.log('⏳ Loading Supabase...');
    try {
      await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js');
      supabaseLib = window.supabase;
    } catch (e) {
      try {
        await loadScript('https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.min.js');
        supabaseLib = window.supabase;
      } catch (e2) {
      setSplashStatus('Работаем в демо-режиме');
      console.error('❌ Supabase load failed');
        return false;
      }
    }
  }
  
  if (!supabaseLib?.createClient) return false;
  
  state.supabase = supabaseLib.createClient(CONFIG.supabase.url, CONFIG.supabase.anonKey);
  setSplashStatus('Supabase подключен');
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
        <button onclick="location.reload()" style="margin-top:16px;padding:10px 20px;background:#0d9488;color:white;border:none;border-radius:8px;cursor:pointer;">↻ Обновить</button>
      </div>`;
    hideSplash();
    return false;
  }
  
  setSplashStatus('Инициализируем карту...');
  
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
  setSplashStatus('Карта готова');
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
  const color = hasEmergency ? '#dc2626' : (CATEGORIES[maxCat]?.color || '#64748b');
  let size = count > 25 ? 48 : count > 10 ? 42 : 36;
  
  return L.divIcon({
    html: `<div style="background:${color};width:${size}px;height:${size}px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:${size > 42 ? 14 : 12}px;box-shadow:0 3px 12px ${color}66;${hasEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}">${count}</div>`,
    className: 'custom-cluster',
    iconSize: L.point(size, size)
  });
}

function createMarkerIcon(complaint) {
  const status = complaint.status || 'open';
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  
  return L.divIcon({
    className: 'custom-marker',
    html: `
      <div class="marker-pulse" style="background:${cat.color}33;${isEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}"></div>
      <div class="marker-pin status-${status}" style="border-color:${cat.color};">
        <span style="transform:rotate(45deg);font-size:14px;">${cat.icon}</span>
      </div>`,
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

function openBottomSheet(complaint) {
  currentComplaintId = complaint.id;
  const sheet = document.getElementById('marker-bottom-sheet');
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  const status = complaint.status || 'open';
  
  // Update Header
  document.getElementById('sheet-icon').textContent = cat.icon;
  document.getElementById('sheet-icon').style.background = `${cat.color}22`;
  document.getElementById('sheet-icon').style.color = cat.color;
  
  const titleEl = document.getElementById('sheet-title');
  titleEl.textContent = `${isEmergency ? '⚠️ ' : ''}${complaint.summary || complaint.category}`;
  if (isEmergency) titleEl.style.color = 'var(--danger)';
  else titleEl.style.color = 'var(--text)';
  
  const statusEl = document.getElementById('sheet-status');
  statusEl.textContent = STATUS_LABELS[status] || status;
  statusEl.className = `sheet-status ${status}`;
  
  // Update Body
  document.getElementById('sheet-address').textContent = complaint.address ? `📍 ${complaint.address}` : '📍 Нет адреса';
  document.getElementById('sheet-time').textContent = `🕒 ${getTimeAgo(complaint.created_at)}`;
  document.getElementById('sheet-desc').textContent = complaint.description || 'Описание не указано.';
  
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
  loadComments(complaint.id);
  
  // Setup Buttons
  document.getElementById('sheet-btn-join').onclick = () => handleAction(complaint.id, 'join');
  document.getElementById('sheet-btn-like').onclick = () => handleAction(complaint.id, 'like');
  document.getElementById('sheet-btn-dislike').onclick = () => handleAction(complaint.id, 'dislike');
}

function closeBottomSheet() {
  const sheet = document.getElementById('marker-bottom-sheet');
  if (sheet) sheet.classList.remove('open');
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

window.handleAction = async function(id, action) {
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
    console.error('Action error', e);
  }
};
function addMarker(complaint, animate = false) {
  if (!complaint.lat || !complaint.lng) return null;
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
  
  if (matchesFilters(complaint)) {
    state.markerCluster.addLayer(marker);
    
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

async function loadComplaints() {
  console.log('📥 Loading...');
  setSplashStatus('Загружаем обращения...');
  
  if (state.supabase) {
    try {
      const { data, error } = await state.supabase
        .from('complaints')
        .select('*')
        .not('lat', 'is', null)
        .not('lng', 'is', null)
        .order('created_at', { ascending: false })
        .limit(1000);
      
      if (error) {
        console.error('❌ Load error:', error);
        return loadDemoComplaints();
      }
      
      console.log(`✅ Loaded ${data.length} complaints`);
      state.complaints = data;
      data.forEach(c => addMarker(c));
      calculateStats();
      updateUI();
      return data;
    } catch (err) {
      console.error('❌ Exception:', err);
      return loadDemoComplaints();
    }
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
  
  state.complaints = demoData;
  demoData.forEach(c => addMarker(c));
  calculateStats();
  updateUI();
  return demoData;
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME SUBSCRIPTION
// ═══════════════════════════════════════════════════════════════════════════════

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
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERS
// ═══════════════════════════════════════════════════════════════════════════════

function matchesFilters(complaint) {
  if (state.currentCategoryFilter !== 'all' && complaint.category !== state.currentCategoryFilter) {
    return false;
  }
  
  if (state.currentDayFilter !== 'all') {
    const created = new Date(complaint.created_at);
    const now = new Date();
    const diffDays = (now - created) / (1000 * 60 * 60 * 24);
    
    switch (state.currentDayFilter) {
      case 'today': if (diffDays > 1) return false; break;
      case '3days': if (diffDays > 3) return false; break;
      case 'week': if (diffDays > 7) return false; break;
      case 'month': if (diffDays > 30) return false; break;
    }
  }
  
  return true;
}

function applyFilters() {
  state.markerCluster.clearLayers();
  
  state.complaints.forEach(complaint => {
    const marker = state.markers.get(complaint.id);
    if (marker && matchesFilters(complaint)) {
      state.markerCluster.addLayer(marker);
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
  stopSplashTicker();
  const splash = document.getElementById('splash');
  if (splash) {
    splash.classList.add('hidden');
    setTimeout(() => splash.remove(), 500);
  }
  state.isLoading = false;
}

function setSplashStatus(text) {
  const statusEl = document.getElementById('splash-status');
  if (statusEl) statusEl.textContent = text;
}

function startSplashTicker() {
  stopSplashTicker();
  setSplashStatus(SPLASH_MESSAGES[0]);
  splashMessageInterval = setInterval(() => {
    splashMessageIndex = (splashMessageIndex + 1) % SPLASH_MESSAGES.length;
    setSplashStatus(SPLASH_MESSAGES[splashMessageIndex]);
  }, 1300);
}

function stopSplashTicker() {
  if (splashMessageInterval) {
    clearInterval(splashMessageInterval);
    splashMessageInterval = null;
  }
}

function initSplashInteractions() {
  const splash = document.getElementById('splash');
  const skipBtn = document.getElementById('splash-start-btn');
  if (!splash) return;

  if (skipBtn) {
    skipBtn.addEventListener('click', () => {
      setSplashStatus('Открываем карту...');
      hideSplash();
    });
  }

  splash.addEventListener('pointerdown', (event) => {
    const ripple = document.createElement('span');
    ripple.className = 'splash-ripple';
    ripple.style.left = `${event.clientX}px`;
    ripple.style.top = `${event.clientY}px`;
    splash.appendChild(ripple);
    setTimeout(() => ripple.remove(), 850);
  });

  startSplashTicker();
}

function showNotification(message, type = 'info') {
  const colors = {
    emergency: '#dc2626',
    new: '#10b981',
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

// Animation keyframes
const style = document.createElement('style');
style.textContent = `
  @keyframes slideDown { from{transform:translateX(-50%) translateY(-20px);opacity:0} to{transform:translateX(-50%) translateY(0);opacity:1} }
  @keyframes slideUp { from{transform:translateX(-50%) translateY(0);opacity:1} to{transform:translateX(-50%) translateY(-20px);opacity:0} }
  @keyframes emergency-pulse { 0%,100%{box-shadow:0 0 0 0 rgba(220,38,38,0.4)} 50%{box-shadow:0 0 0 8px rgba(220,38,38,0)} }
  .custom-cluster{background:transparent!important;border:none!important;}
  .popup-card.emergency{border:2px solid #dc2626;background:rgba(254,226,226,0.9)!important;}
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
  
  await loadComplaints();
  subscribeToRealtime();
  
  setSplashStatus('Готово');
  setTimeout(hideSplash, 550);
  console.log('✅ Ready');
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

window.addEventListener('beforeunload', () => {
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
    today.setHours(0,0,0,0);
    
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
    let color = '#10b981';
    if (this.targetBpm > 120 || emergencyCount > 0) {
      mood = 'ЧП / Тревога';
      color = '#dc2626';
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
    
    let color = '#10b981';
    if (this.bpm > 120) color = '#dc2626';
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


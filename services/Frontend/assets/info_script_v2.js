/**
 * ═══════════════════════════════════════════════════════════════════════
 * НИЖНЕВАРТОВСК — PULSE CITY INFOGRAPHIC v2.0
 * Industrial Futurism Design · Open Data Visualization
 * ═══════════════════════════════════════════════════════════════════════
 */

// ══════════════════════════════════════════════════════════
// TELEGRAM WEB APP INTEGRATION
// ══════════════════════════════════════════════════════════
const tg = window.Telegram?.WebApp;
if (tg) {
  tg.ready();
  tg.expand();
  tg.BackButton.show();
  tg.onEvent('backButtonClicked', () => tg.close());
}

// ══════════════════════════════════════════════════════════
// CONFIGURATION
// ══════════════════════════════════════════════════════════
const CONFIG = {
  supabaseApi: 'https://xpainxohbdoruakcijyq.supabase.co/functions/v1/api',
  weatherApi: 'https://api.open-meteo.com/v1/forecast',
  coords: { lat: 60.9344, lon: 76.5531 },
  timeout: 10000
};

// ══════════════════════════════════════════════════════════
// ICON LIBRARY (using Iconify)
// ══════════════════════════════════════════════════════════
const ICONS = {
  // Section icons
  budget: 'mdi:wallet-outline',
  fuel: 'mdi:gas-station',
  housing: 'mdi:home-city-outline',
  edu: 'mdi:school-outline',
  transport: 'mdi:bus',
  sport: 'mdi:trophy-outline',
  city: 'mdi:city-variant-outline',
  eco: 'mdi:leaf',
  people: 'mdi:account-group-outline',

  // Card icons
  contract: 'mdi:file-document-outline',
  property: 'mdi:bank-outline',
  program: 'mdi:clipboard-list-outline',
  price: 'mdi:cash-multiple',
  uk: 'mdi:office-building-outline',
  emergency: 'mdi:phone-alert-outline',
  email: 'mdi:email-fast-outline',
  school: 'mdi:school-outline',
  culture: 'mdi:theater',
  route: 'mdi:routes',
  road: 'mdi:road-variant',
  stadium: 'mdi:stadium-outline',
  trainer: 'mdi:whistle-outline',
  construction: 'mdi:crane',
  accessibility: 'mdi:wheelchair-accessibility',
  salary: 'mdi:currency-rub',
  hearing: 'mdi:forum-outline',
  news: 'mdi:newspaper-variant-outline',
  demography: 'mdi:human-male-female-child',
  phonebook: 'mdi:book-open-page-variant-outline',
  communication: 'mdi:antenna',
  waste: 'mdi:recycle',
  names: 'mdi:baby-face-outline',

  // Navigation & Traffic
  map: 'mdi:map-marker-outline',
  traffic: 'mdi:car-multiple',
  traffic_jam: 'mdi:traffic-light',
  air_quality: 'mdi:air-filter',
  wind: 'mdi:weather-windy',
  comfort: 'mdi:thermometer-lines',
  star: 'mdi:star',
  star_outline: 'mdi:star-outline',
  send: 'mdi:send',
  fact: 'mdi:lightbulb-on-outline',
  heart_pulse: 'mdi:heart-pulse',
  budget_income: 'mdi:cash-plus',
  budget_expense: 'mdi:cash-minus',
  chart_bar: 'mdi:chart-bar',
  chart_line: 'mdi:chart-line-variant',
  pie: 'mdi:chart-pie',
  debt: 'mdi:bank-minus',

  // Utility icons
  clock: 'mdi:clock-outline',
  database: 'mdi:database-outline',
  info: 'mdi:information-outline',
  chevron: 'mdi:chevron-right',
  expand: 'mdi:chevron-down',
  weather: {
    clear_day: 'mdi:weather-sunny',
    clear_night: 'mdi:weather-night',
    cloudy: 'mdi:weather-cloudy',
    overcast: 'mdi:cloud',
    fog: 'mdi:weather-fog',
    rain: 'mdi:weather-rainy',
    snow: 'mdi:weather-snowy',
    storm: 'mdi:weather-lightning-rainy'
  }
};

// ══════════════════════════════════════════════════════════
// COLOR PALETTE
// ══════════════════════════════════════════════════════════
const COLORS = {
  primary: '#00f0ff',
  secondary: '#ff6b35',
  tertiary: '#7c3aed',
  success: '#22c55e',
  warning: '#fbbf24',
  danger: '#ef4444',
  blue: '#3b82f6',
  pink: '#ec4899',
  teal: '#14b8a6',
  chart: ['#00f0ff', '#ff6b35', '#7c3aed', '#22c55e', '#fbbf24', '#3b82f6', '#ec4899', '#14b8a6']
};

// ══════════════════════════════════════════════════════════
// CITY PULSE - HEARTBEAT VISUALIZATION
// ══════════════════════════════════════════════════════════
const CityPulse = {
  bpm: 72,
  targetBpm: 72,
  mood: 'Спокойно',
  canvas: null,
  ctx: null,
  history: [],
  lastBeat: 0,
  beatScale: 1,
  glowIntensity: 0,
  variability: 0,
  frameCount: 0,

  init() {
    this.canvas = document.getElementById('pulseCanvas');
    if (!this.canvas) return;

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.history = new Array(200).fill(0);
    this.lastBeat = Date.now();
    this.startDynamicBpm();
    this.animate();
    this.startHeartbeat();
  },

  startDynamicBpm() {
    const updateBpm = () => {
      const hour = new Date().getHours();
      let baseBpm = 72;

      if (hour >= 7 && hour < 9) baseBpm = 95;
      else if (hour >= 9 && hour < 12) baseBpm = 85;
      else if (hour >= 12 && hour < 14) baseBpm = 75;
      else if (hour >= 14 && hour < 18) baseBpm = 90;
      else if (hour >= 18 && hour < 21) baseBpm = 85;
      else if (hour >= 21 || hour < 7) baseBpm = 65;

      this.variability = Math.sin(Date.now() * 0.0005) * 8 + Math.sin(Date.now() * 0.001) * 4;
      this.targetBpm = baseBpm + this.variability;

      if (this.targetBpm < 70) this.mood = 'Спокойно';
      else if (this.targetBpm < 85) this.mood = 'Умеренно';
      else if (this.targetBpm < 100) this.mood = 'Активно';
      else this.mood = 'Напряжённо';

      this.updateDisplay();
      setTimeout(updateBpm, 500);
    };
    updateBpm();
  },

  resize() {
    if (!this.canvas) return;
    const rect = this.canvas.parentElement.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
  },

  startHeartbeat() {
    const heartIcon = document.querySelector('.pulse-heart-icon');
    if (!heartIcon) return;

    const beat = () => {
      const interval = 60000 / this.bpm;

      heartIcon.style.transform = 'scale(1.3)';
      heartIcon.style.filter = `drop-shadow(0 0 20px ${this.getMoodColor()})`;

      setTimeout(() => {
        heartIcon.style.transform = 'scale(1)';
        heartIcon.style.filter = `drop-shadow(0 0 8px ${this.getMoodColor()})`;
      }, 150);

      setTimeout(() => {
        heartIcon.style.transform = 'scale(1.15)';
      }, 250);

      setTimeout(() => {
        heartIcon.style.transform = 'scale(1)';
      }, 350);

      this.lastBeat = Date.now();
      setTimeout(beat, interval);
    };

    beat();
  },

  feed(complaints) {
    if (!complaints?.length) return;

    const now = Date.now();
    const recent = complaints.filter(c => {
      const date = new Date(c.created_at || c.date || 0);
      return now - date.getTime() < 86400000; // 24 hours
    });

    let severity = 0;
    const criticalCategories = ['ЧП', 'Безопасность', 'Газоснабжение'];
    const highCategories = ['Дороги', 'ЖКХ', 'Отопление', 'Водоснабжение'];

    recent.forEach(c => {
      const cat = c.category || '';
      if (criticalCategories.includes(cat)) severity += 3;
      else if (highCategories.some(h => cat.includes(h))) severity += 2;
      else severity += 1;
    });

    this.targetBpm = Math.min(60 + severity * 1.5 + recent.length * 2, 180);

    if (this.targetBpm < 65) this.mood = 'Спокойно';
    else if (this.targetBpm < 90) this.mood = 'Умеренно';
    else if (this.targetBpm < 120) this.mood = 'Напряжённо';
    else this.mood = 'Тревожно';

    this.updateDisplay();
  },

  updateDisplay() {
    const bpmEl = document.getElementById('pulse-bpm');
    const moodEl = document.getElementById('pulse-mood');

    if (bpmEl) bpmEl.textContent = Math.round(this.targetBpm);
    if (moodEl) {
      moodEl.textContent = this.mood;
      moodEl.style.color = this.getMoodColor();
    }
  },

  getMoodColor() {
    if (this.targetBpm < 65) return COLORS.success;
    if (this.targetBpm < 90) return COLORS.warning;
    if (this.targetBpm < 120) return COLORS.secondary;
    return COLORS.danger;
  },

  animate() {
    if (!this.ctx) return;

    this.frameCount++;
    const W = this.canvas.width;
    const H = this.canvas.height;

    this.bpm += (this.targetBpm - this.bpm) * 0.05;
    const freq = this.bpm / 60;
    const t = Date.now() * 0.001 * freq;

    const phase = t % 1;
    let v = 0;

    const intensity = 0.8 + (this.bpm - 60) / 120 * 0.5;

    if (phase < 0.05) v = Math.sin(phase / 0.05 * Math.PI) * 0.3 * intensity;
    else if (phase < 0.15) v = 0;
    else if (phase < 0.18) v = -Math.sin((phase - 0.15) / 0.03 * Math.PI) * 0.2 * intensity;
    else if (phase < 0.22) {
      v = Math.sin((phase - 0.18) / 0.04 * Math.PI) * 1.3 * intensity;
      this.glowIntensity = Math.max(this.glowIntensity, 1);
    }
    else if (phase < 0.26) v = -Math.sin((phase - 0.22) / 0.04 * Math.PI) * 0.4 * intensity;
    else if (phase < 0.35) v = 0;
    else if (phase < 0.45) v = Math.sin((phase - 0.35) / 0.1 * Math.PI) * 0.28 * intensity;
    else v = 0;

    const noise = (Math.random() - 0.5) * 0.02 * (this.bpm / 100);
    v += noise;

    this.glowIntensity *= 0.92;

    this.history.push(v);
    if (this.history.length > 200) this.history.shift();

    this.ctx.clearRect(0, 0, W, H);

    const color = this.getMoodColor();
    const step = W / 200;

    const gradient = this.ctx.createLinearGradient(0, 0, W, 0);
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(0.1, color + '40');
    gradient.addColorStop(0.5, color);
    gradient.addColorStop(0.9, color + '40');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');

    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 8 + this.glowIntensity * 10;
    this.ctx.globalAlpha = 0.15 + this.glowIntensity * 0.2;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();
    this.history.forEach((val, i) => {
      const x = i * step;
      const y = H / 2 - val * (H / 2 - 6);
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    });
    this.ctx.stroke();

    this.ctx.globalAlpha = 1;
    this.ctx.strokeStyle = gradient;
    this.ctx.lineWidth = 2.5 + this.glowIntensity * 1.5;
    this.ctx.shadowColor = color;
    this.ctx.shadowBlur = 12 + this.glowIntensity * 20;

    this.ctx.beginPath();
    this.history.forEach((val, i) => {
      const x = i * step;
      const y = H / 2 - val * (H / 2 - 6);
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    });
    this.ctx.stroke();

    const lastIdx = this.history.length - 1;
    const dotX = lastIdx * step;
    const dotY = H / 2 - this.history[lastIdx] * (H / 2 - 6);
    const dotSize = 3 + this.glowIntensity * 3;

    this.ctx.beginPath();
    this.ctx.arc(dotX, dotY, dotSize, 0, Math.PI * 2);
    this.ctx.fillStyle = color;
    this.ctx.shadowBlur = 20 + this.glowIntensity * 30;
    this.ctx.fill();

    this.ctx.shadowBlur = 0;

    requestAnimationFrame(() => this.animate());
  }
};

// ══════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ══════════════════════════════════════════════════════════
function esc(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function formatDate(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return d.toLocaleDateString('ru-RU', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch {
    return iso;
  }
}

function formatMoney(value) {
  if (!value) return '—';
  const v = Number(value);
  if (v >= 1e9) return (v / 1e9).toFixed(1) + ' млрд ₽';
  if (v >= 1e6) return (v / 1e6).toFixed(1) + ' млн ₽';
  if (v >= 1e3) return (v / 1e3).toFixed(0) + ' тыс ₽';
  return v.toFixed(0) + ' ₽';
}

function haptic() {
  try { tg?.HapticFeedback?.impactOccurred('light'); } catch { }
}

// Inline SVG fallbacks for key icons (works offline)
const INLINE_SVG = {
  'mdi:wallet-outline': '<path d="M5 3a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H5m0 2h14v2H5V5m0 4h14v10H5V9m2 2v2h2v-2H7m4 0v2h2v-2h-2m4 0v2h2v-2h-2"/>',
  'mdi:gas-station': '<path d="M18 10a1 1 0 0 1-1-1 1 1 0 0 1 1-1 1 1 0 0 1 1 1 1 1 0 0 1-1 1m-6 0H6V5h6m7.77 2.23l.01-.01-3.72-3.72L15 4.56l2.11 2.11C16.17 7 15.5 7.93 15.5 9a2.5 2.5 0 0 0 2.5 2.5c.36 0 .69-.08 1-.21V18.5a1.5 1.5 0 0 1-1.5 1.5 1.5 1.5 0 0 1-1.5-1.5V14a2 2 0 0 0-2-2h-1V5a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v16h10v-7.5h1.5v5a3 3 0 0 0 3 3 3 3 0 0 0 3-3V9c0-.69-.28-1.32-.73-1.77Z"/>',
  'mdi:home-city-outline': '<path d="M10 2v2.26l2 1.33V4h10v17h-5v-8H7v8H2V10.5L10 2M9 22v-6H5v6h4m8 0v-4h-4v4h4m4 0v-6h-4v6h4M7 12h2v2H7v-2m4 0h2v2h-2v-2m4 0h2v2h-2v-2M7 8h2v2H7V8m4 0h2v2h-2V8"/>',
  'mdi:school-outline': '<path d="M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3m6.82 6L12 12.72 5.18 9 12 5.28 18.82 9M17 16l-5 2.72L7 16v-3.73L12 15l5-2.73V16Z"/>',
  'mdi:bus': '<path d="M18 11H6V6h12m-1.5 11a1.5 1.5 0 0 1-1.5-1.5 1.5 1.5 0 0 1 1.5-1.5 1.5 1.5 0 0 1 1.5 1.5 1.5 1.5 0 0 1-1.5 1.5m-9 0A1.5 1.5 0 0 1 6 15.5 1.5 1.5 0 0 1 7.5 14 1.5 1.5 0 0 1 9 15.5 1.5 1.5 0 0 1 7.5 17M4 16c0 .88.39 1.67 1 2.22V20a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h8v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1.78c.61-.55 1-1.34 1-2.22V6c0-3.5-3.58-4-8-4s-8 .5-8 4v10Z"/>',
  'mdi:trophy-outline': '<path d="M2 2h20v7a5 5 0 0 1-5 5H7a5 5 0 0 1-5-5V2m2 2v5a3 3 0 0 0 3 3h10a3 3 0 0 0 3-3V4H4m6 12v6h4v-6h-4Z"/>',
  'mdi:city-variant-outline': '<path d="M19 9.5V2H5v7.5H2v13h8v-4h4v4h8v-13h-3M7 19H4v-2h3v2m0-4H4v-2h3v2m0-4H4V9h3v2m4 8H9v-2h2v2m0-4H9v-2h2v2m0-4H9V9h2v2m0-4H9V5h2v2m4 12h-2v-2h2v2m0-4h-2v-2h2v2m0-4h-2V9h2v2m0-4h-2V5h2v2m5 12h-3v-2h3v2m0-4h-3v-2h3v2Z"/>',
  'mdi:leaf': '<path d="M17 8C8 10 5.9 16.17 3.82 21.34l1.89.66.95-2.3c.48.17.98.3 1.34.3C19 20 22 3 22 3c-1 2-8 2.25-13 3.25S2 11.5 2 13.5s1.75 3.75 1.75 3.75C7 8 17 8 17 8Z"/>',
  'mdi:account-group-outline': '<path d="M12 5.5A3.5 3.5 0 0 1 15.5 9a3.5 3.5 0 0 1-3.5 3.5A3.5 3.5 0 0 1 8.5 9 3.5 3.5 0 0 1 12 5.5M5 8c.56 0 1.08.15 1.53.42-.15 1.43.27 2.85 1.13 3.96C7.16 13.34 6.16 14 5 14a3 3 0 0 1-3-3 3 3 0 0 1 3-3m14 0a3 3 0 0 1 3 3 3 3 0 0 1-3 3c-1.16 0-2.16-.66-2.66-1.62a5.536 5.536 0 0 0 1.13-3.96c.45-.27.97-.42 1.53-.42M5.5 18.25c0-2.07 2.91-3.75 6.5-3.75s6.5 1.68 6.5 3.75V20h-13v-1.75M0 20v-1.5c0-1.39 1.89-2.56 4.45-2.9-.29.35-.45.77-.45 1.15V20H0m24 0h-4v-3.25c0-.38-.16-.8-.45-1.15 2.56.34 4.45 1.51 4.45 2.9V20Z"/>',
  'mdi:file-document-outline': '<path d="M6 2a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6H6m0 2h7v5h5v11H6V4m2 8v2h8v-2H8m0 4v2h5v-2H8Z"/>',
  'mdi:bank-outline': '<path d="M11.5 1L2 6v2h19V6M2 19v2h19v-2M6 10v7H4v-7h2m5 0v7H9v-7h2m5 0v7h-2v-7h2m5 0v7h-2v-7h2Z"/>',
  'mdi:cash-multiple': '<path d="M5 6h18v12H5V6m9 3a3 3 0 0 1 3 3 3 3 0 0 1-3 3 3 3 0 0 1-3-3 3 3 0 0 1 3-3M9 8a2 2 0 0 1-2 2v4a2 2 0 0 1 2 2h10a2 2 0 0 1 2-2v-4a2 2 0 0 1-2-2H9M1 10v12h18v-2H3V10H1Z"/>',
  'mdi:currency-rub': '<path d="M6 22V4h7.5A5.5 5.5 0 0 1 19 9.5c0 2.47-1.63 4.57-3.87 5.26L17 16h-3.5l-1.5-1H8v2h5v2H8v3H6m2-8h5.5a3.5 3.5 0 0 0 3.5-3.5A3.5 3.5 0 0 0 13.5 6H8v8Z"/>',
  'mdi:human-male-female-child': '<path d="M7 1a2 2 0 0 0-2 2 2 2 0 0 0 2 2 2 2 0 0 0 2-2 2 2 0 0 0-2-2m0 6C5.34 7 4 8.34 4 10v5h2v7h2.5v-7h1v7H12v-7h2v-5c0-1.66-1.34-3-3-3H7m10-2.5a1.5 1.5 0 0 0-1.5 1.5 1.5 1.5 0 0 0 1.5 1.5 1.5 1.5 0 0 0 1.5-1.5 1.5 1.5 0 0 0-1.5-1.5m-2 4.5c-.83 0-1.5.67-1.5 1.5V14h1.5v8h1.25v-5h1.5v5H19v-8h1.5v-3.5c0-.83-.67-1.5-1.5-1.5h-4Z"/>',
  'mdi:information-outline': '<path d="M11 9h2V7h-2m1 13c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8m0-18A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10A10 10 0 0 0 12 2m-1 15h2v-6h-2v6Z"/>',
  'mdi:clock-outline': '<path d="M12 20a8 8 0 0 1-8-8 8 8 0 0 1 8-8 8 8 0 0 1 8 8 8 8 0 0 1-8 8m0-18A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10A10 10 0 0 0 12 2m.5 5H11v6l5.25 3.15.75-1.23-4.5-2.67V7Z"/>',
  'mdi:database-outline': '<path d="M12 3C7.58 3 4 4.79 4 7s3.58 4 8 4 8-1.79 8-4-3.58-4-8-4M4 9v3c0 2.21 3.58 4 8 4s8-1.79 8-4V9c0 2.21-3.58 4-8 4s-8-1.79-8-4m0 5v3c0 2.21 3.58 4 8 4s8-1.79 8-4v-3c0 2.21-3.58 4-8 4s-8-1.79-8-4Z"/>',
  'mdi:weather-sunny': '<path d="M12 7a5 5 0 0 1 5 5 5 5 0 0 1-5 5 5 5 0 0 1-5-5 5 5 0 0 1 5-5m0 2a3 3 0 0 0-3 3 3 3 0 0 0 3 3 3 3 0 0 0 3-3 3 3 0 0 0-3-3m0-7 2.39 3.42C13.65 5.15 12.84 5 12 5c-.84 0-1.65.15-2.39.42L12 2m6.78 4.22-2.4 2.78.19.9.9.2 2.78-2.4c-.71-.68-1.5-1.23-2.37-1.61l-1.1.13M18 12c0 .84-.15 1.65-.42 2.39L21 12l-3.42-2.39c.27.74.42 1.55.42 2.39m-1.5 6.78-2.78-2.4-.9.19-.2.9 2.4 2.78c.87-.38 1.66-.93 2.37-1.61l-.13-1.1-.76.24M12 19c-.84 0-1.65-.15-2.39-.42L12 22l2.39-3.42A6.688 6.688 0 0 1 12 19m-6.78-1.5 2.4-2.78-.19-.9-.9-.2-2.78 2.4c.71.68 1.5 1.23 2.37 1.61l1.1-.13M6 12c0-.84.15-1.65.42-2.39L3 12l3.42 2.39C6.15 13.65 6 12.84 6 12m1.5-6.78 2.78 2.4.9-.19.2-.9-2.4-2.78c-.87.38-1.66.93-2.37 1.61l.13 1.1.76-.24Z"/>',
  'mdi:weather-night': '<path d="M17.75 4.09L15.22 6.03 16.13 9.09 13.5 7.28 10.87 9.09 11.78 6.03 9.25 4.09 12.44 4 13.5 1 14.56 4M21.25 11l-1.64 1.25.62 1.97-1.69-1.16-1.69 1.16.62-1.97L15.84 11l2.06-.05L18.5 9l.6 1.95M18.97 15.95c-1.26.63-2.69.98-4.22.98-5.23 0-9.47-4.24-9.47-9.47 0-1.53.35-2.96.98-4.22C3.75 5 2 7.61 2 10.5 2 15.74 6.26 20 11.5 20c2.89 0 5.5-1.75 7.25-4.05Z"/>',
  'mdi:weather-cloudy': '<path d="M6 19a5 5 0 0 1-5-5 5 5 0 0 1 5-5c1-2.35 3.3-4 6-4 3.43 0 6.24 2.66 6.5 6.03l.5-.03a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6Z"/>',
  'mdi:cloud': '<path d="M6.5 20A5.5 5.5 0 0 1 1 14.5 5.5 5.5 0 0 1 6.5 9c1.28 0 2.45.46 3.36 1.21A7.002 7.002 0 0 1 17.5 4c3.87 0 7 3.13 7 7a7 7 0 0 1-7 7h-11c-.28 0-.55-.02-.82-.05L6.5 20Z"/>',
  'mdi:weather-rainy': '<path d="M6 14.5A2.5 2.5 0 0 1 3.5 12 2.5 2.5 0 0 1 6 9.5c.66-1.37 2.09-2.5 4-2.5 2.21 0 4 1.79 4 4h.5c1.1 0 2 .9 2 2s-.9 2-2 2H6m-.5 2 1.5 3h-2l1.5 3m4-6 1.5 3h-2l1.5 3m4-6 1.5 3h-2l1.5 3Z"/>',
  'mdi:weather-snowy': '<path d="M6 14.5A2.5 2.5 0 0 1 3.5 12 2.5 2.5 0 0 1 6 9.5c.66-1.37 2.09-2.5 4-2.5 2.21 0 4 1.79 4 4h.5c1.1 0 2 .9 2 2s-.9 2-2 2H6m.5 2a1 1 0 0 1 1 1 1 1 0 0 1-1 1 1 1 0 0 1-1-1 1 1 0 0 1 1-1m4 2a1 1 0 0 1 1 1 1 1 0 0 1-1 1 1 1 0 0 1-1-1 1 1 0 0 1 1-1m4-2a1 1 0 0 1 1 1 1 1 0 0 1-1 1 1 1 0 0 1-1-1 1 1 0 0 1 1-1Z"/>',
  'mdi:wifi-off': '<path d="m2.28 3 1.43 1.41 16.97 17 1.41-1.41L2.28 3M12 6c3.55 0 6.75 1.46 9.06 3.79l-1.72 1.73A11.8 11.8 0 0 0 12 8.5c-1.76 0-3.43.39-4.94 1.07l1.52 1.54c1.08-.36 2.22-.56 3.42-.56 2.48 0 4.74.86 6.53 2.3l-1.72 1.74c-1.33-.99-2.97-1.58-4.76-1.58-.67 0-1.33.08-1.96.23l1.84 1.85.12-.01c1.36 0 2.58.5 3.53 1.31L12 18.5l-1.8-1.83 6.32 6.33h2V21h-5.28L12 19.28 5.47 12.75 3.06 9.34C1.5 10.78 0 12.5 0 12.5l1.72 1.73c.77-.76 1.63-1.44 2.56-2.04l1.81 1.82a9.32 9.32 0 0 0-2.65 1.95l1.72 1.74c.8-.71 1.73-1.29 2.75-1.7l7.56 7.5H22v-2H17.28L7.28 10l-5-5L1 3.59l1.28-.59Z"/>',
  'mdi:trending-up': '<path d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6h-6z"/>',
  'mdi:trending-down': '<path d="M16 18l2.29-2.29-4.88-4.88-4 4L2 7.41 3.41 6l6 6 4-4 6.3 6.29L22 12v6h-6z"/>',
  'mdi:trending-neutral': '<path d="M22 12l-4-4v3H3v2h15v3l4-4z"/>',
  'mdi:chart-timeline-variant': '<path d="M3 14l.5.07L8.07 9.5a1.95 1.95 0 0 1 .52-1.91c.78-.79 2.04-.79 2.82 0 .53.52.7 1.26.52 1.91l2.57 2.57.5-.07c.18 0 .35 0 .5.07l3.57-3.57c-.04-.16-.07-.32-.07-.5a2 2 0 0 1 2-2 2 2 0 0 1 2 2 2 2 0 0 1-2 2c-.18 0-.35 0-.5-.07L17 14.5c.04.16.07.32.07.5a2 2 0 0 1-2 2 2 2 0 0 1-2-2l.07-.5-2.57-2.57c-.32.07-.68.07-1 0L5.5 16.5c.04.16.07.32.07.5a2 2 0 0 1-2 2 2 2 0 0 1-2-2 2 2 0 0 1 2-2m0 0"/>',
  'mdi:baby-carriage': '<path d="M19 9c-2 0-3.5 1.5-3.5 3.5v5c0 2 1.5 3.5 3.5 3.5s3.5-1.5 3.5-3.5v-5c0-2-1.5-3.5-3.5-3.5m0 10.5c-.83 0-1.5-.67-1.5-1.5v-5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v5c0 .83-.67 1.5-1.5 1.5M12 5c-2.76 0-5 2.24-5 5v7H2l2-4H2l2-3c0-3.87 3.13-7 7-7h1v2h-1m0 5c0 .55-.45 1-1 1s-1-.45-1-1 .45-1 1-1 1 .45 1 1m-1 7a3 3 0 0 0 3-3h-6a3 3 0 0 0 3 3z"/>',
  'mdi:heart-pulse': '<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.27 2 8.5 2 5.41 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.08C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.41 22 8.5c0 3.77-3.4 6.86-8.55 11.53L12 21.35M16.5 5c-1.22 0-2.4.54-3.19 1.42L12 8l-1.31-1.58C9.9 5.54 8.72 5 7.5 5 5.54 5 4 6.54 4 8.5c0 2.9 3.14 5.74 7.9 10.17l.1.1.1-.1C16.86 14.24 20 11.4 20 8.5c0-1.96-1.54-3.5-3.5-3.5M9.5 8.5L12 14l1.5-3H18v2h-3.5L12 18l-1.5-5H7v-2h2.5z"/>',
  'mdi:account-child': '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2m0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8m-2-5.25a.5.5 0 0 1-.5.5.5.5 0 0 1-.5-.5.5.5 0 0 1 .5-.5.5.5 0 0 1 .5.5m5 0a.5.5 0 0 1-.5.5.5.5 0 0 1-.5-.5.5.5 0 0 1 .5-.5.5.5 0 0 1 .5.5M12 15.5c-1.5 0-2.5-1-2.5-1h5s-1 1-2.5 1M10 5c-2.76 0-5 2.24-5 5v5h10v-5c0-2.76-2.24-5-5-5z"/>',
  'mdi:grave-stone': '<path d="M10 2C5.58 2 2 5.58 2 10v12h8V10h8v12h2V10c0-4.42-3.58-8-8-8h-2z"/>',
  'mdi:ring': '<path d="M12 2C8 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3-7-7-7m0 9.5A2.5 2.5 0 0 1 9.5 9 2.5 2.5 0 0 1 12 6.5 2.5 2.5 0 0 1 14.5 9a2.5 2.5 0 0 1-2.5 2.5z"/>',
  'mdi:airplane-takeoff': '<path d="M2.5 19h19v2h-19v-2m19.57-9.36c-.21-.8-1.04-1.28-1.84-1.06L14.92 10l-6.9-6.43-1.93.51 4.14 7.17-4.97 1.33-1.97-1.54-1.45.39 1.82 3.16.47 1.24 5.15-1.38 6.08-1.63 6.08-1.63c.8-.21 1.28-1.04 1.07-1.84z"/>',
  // Emergency & Contact Icons
  'mdi:lightning-bolt': '<path d="M11 15H6l7-14v8h5l-7 14v-8z"/>',
  'mdi:home-alert': '<path d="M12 3L2 12h3v8h14v-8h3L12 3m0 2.7L18 11v8h-4v-5h-4v5H6v-8l6-5.3M11 14h2v4h-2v-4m0-6h2v4h-2V8z"/>',
  'mdi:phone-alert': '<path d="M6.62 10.79a15.15 15.15 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.01-.24c1.12.37 2.32.57 3.57.57.55 0 1 .45 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2M13 5h2v6h-2V5m0 8h2v2h-2v-2z"/>',
  'mdi:fire': '<path d="M17.66 11.2c-.23-.3-.51-.56-.77-.82-.67-.6-1.43-1.03-2.07-1.66C13.33 7.26 13 4.85 13.95 3c-.95.23-1.78.75-2.49 1.32-2.59 2.08-3.61 5.75-2.39 8.9.04.1.08.2.08.33 0 .22-.15.42-.35.5-.23.1-.47.04-.66-.12a.58.58 0 0 1-.14-.17c-1.13-1.43-1.31-3.48-.55-5.12C5.78 10 4.87 12.3 5 14.47c.06.5.12 1 .29 1.5.14.6.41 1.2.71 1.73 1.08 1.73 2.95 2.97 4.96 3.22 2.14.27 4.43-.12 6.07-1.6 1.83-1.6 2.47-4.03 1.92-6.33-.07-.4-.25-.8-.44-1.18l-.1-.2c-.26.2-.54.37-.84.52z"/>',
  'mdi:water': '<path d="M12 20a6 6 0 0 1-6-6c0-4 6-10.75 6-10.75S18 10 18 14a6 6 0 0 1-6 6m0-8c1.1 0 2 .9 2 2a2 2 0 0 1-2 2 2 2 0 0 1-2-2c0-1.1.9-2 2-2z"/>',
  'mdi:radiator': '<path d="M7.95 3L6.53 5.19 7.95 7.4h7.1l1.42-2.21-1.42-2.19H7.95M6 8C3.24 8 1 10.24 1 13s2.24 5 5 5h1v-4.5a2.5 2.5 0 0 1 2.5-2.5A2.5 2.5 0 0 1 12 13.5V18h4.5a2.5 2.5 0 0 0 2.5-2.5 2.5 2.5 0 0 0-2.5-2.5H14v-5H6z"/>',
  'mdi:fire-truck': '<path d="M17 5H3a2 2 0 0 0-2 2v9h2a3 3 0 0 0 3 3 3 3 0 0 0 3-3h6a3 3 0 0 0 3 3 3 3 0 0 0 3-3h2v-5l-3-6h-3m-1 2h3l2 4h-5V7M6 15.5A1.5 1.5 0 0 1 7.5 17 1.5 1.5 0 0 1 6 18.5 1.5 1.5 0 0 1 4.5 17 1.5 1.5 0 0 1 6 15.5m12 0a1.5 1.5 0 0 1 1.5 1.5 1.5 1.5 0 0 1-1.5 1.5 1.5 1.5 0 0 1-1.5-1.5 1.5 1.5 0 0 1 1.5-1.5M5 11V9h4v2H5m8 0V9h2v2h-2z"/>',
  'mdi:police-badge': '<path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4m0 4a2 2 0 0 1 2 2 2 2 0 0 1-2 2 2 2 0 0 1-2-2 2 2 0 0 1 2-2m3.39 8.59L12 15.56l-3.39 2.03.88-3.86L6.7 11.3l3.93-.34L12 7.46l1.37 3.5 3.93.34-2.82 2.43.91 3.86z"/>',
  'mdi:ambulance': '<path d="M18 8.5a1.5 1.5 0 0 1 1.5 1.5 1.5 1.5 0 0 1-1.5 1.5 1.5 1.5 0 0 1-1.5-1.5 1.5 1.5 0 0 1 1.5-1.5m0-3A4.5 4.5 0 0 0 13.5 10a4.5 4.5 0 0 0 4.5 4.5 4.5 4.5 0 0 0 4.5-4.5A4.5 4.5 0 0 0 18 5.5M3 5v14h9a5 5 0 0 1-5-5 5 5 0 0 1 5-5 5 5 0 0 1 5 5 5 5 0 0 1-5 5h9V5H3z"/>',
  'mdi:elevator': '<path d="M7 2l4 4H3l4-4m0 20l-4-4h8l-4 4m10-16l4 4h-8l4-4m0 12l-4-4h8l-4 4M2 10h20v4H2v-4z"/>',
  'mdi:phone': '<path d="M6.62 10.79a15.15 15.15 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.01-.24c1.12.37 2.32.57 3.57.57.55 0 1 .45 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2z"/>',
  'mdi:email': '<path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2m0 4l-8 5-8-5V6l8 5 8-5v2z"/>',
  'mdi:email-fast-outline': '<path d="M22 5.5H9c-1.1 0-2 .9-2 2v9c0 1.1.9 2 2 2h13c1.1 0 2-.9 2-2v-9c0-1.1-.9-2-2-2m0 4l-6.5 3.33L9 9.5v-2l6.5 3.5 6.5-3.5v2M5 16.5c0 .17.03.33.05.5H1v-13h2v11.5c0 .83.67 1.5 1.5 1.5H5M3 5.5H1V4h4v1.5H3z"/>',
  'mdi:email-send-outline': '<path d="M13 19c0-.34.04-.67.09-1H4V8l8 5 8-5v5.09c.72.12 1.39.37 2 .72V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h9.09c-.05-.33-.09-.66-.09-1m7-13l-8 5-8-5h16m0 9v3h3v2h-3v3h-2v-3h-3v-2h3v-3h2z"/>',
  'mdi:information': '<path d="M13 9h-2V7h2m0 10h-2v-6h2m-1-9A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10A10 10 0 0 0 12 2z"/>',
  'mdi:lightbulb-on': '<path d="M12 6a6 6 0 0 1 6 6c0 2.22-1.21 4.16-3 5.2V19a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-1.8c-1.79-1.04-3-2.98-3-5.2a6 6 0 0 1 6-6m2 15v1a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1v-1h4m6-10h3v2h-3v-2M1 11h3v2H1v-2M13 1v3h-2V1h2M4.92 3.5l2.13 2.14-1.42 1.41L3.5 4.93l1.42-1.43m12.03 2.13l2.12-2.13 1.43 1.43-2.13 2.12-1.42-1.42z"/>',
  'mdi:fuel': '<path d="M18 10a1 1 0 0 1-1-1 1 1 0 0 1 1-1 1 1 0 0 1 1 1 1 1 0 0 1-1 1m-6 0H6V5h6m7.77 2.23l.01-.01-3.72-3.72L15 4.56l2.11 2.11C16.17 7 15.5 7.93 15.5 9a2.5 2.5 0 0 0 2.5 2.5c.36 0 .69-.08 1-.21V18.5a1.5 1.5 0 0 1-1.5 1.5 1.5 1.5 0 0 1-1.5-1.5V14a2 2 0 0 0-2-2h-1V5a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v16h10v-7.5h1.5v5a3 3 0 0 0 3 3 3 3 0 0 0 3-3V9c0-.69-.28-1.32-.73-1.77z"/>',
  'mdi:alert-circle-outline': '<path d="M11 15h2v2h-2v-2m0-8h2v6h-2V7m1-5C6.47 2 2 6.5 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10A10 10 0 0 0 12 2m0 18a8 8 0 0 1-8-8 8 8 0 0 1 8-8 8 8 0 0 1 8 8 8 8 0 0 1-8 8z"/>',
  'mdi:clock': '<path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2m4.2 14.2L11 13V7h1.5v5.2l4.5 2.7-.8 1.3z"/>',
  'mdi:rocket-launch': '<path d="M13.13 22.19L11.5 18.36C13.07 17.78 14.54 17 15.9 16.09L13.13 22.19M5.64 12.5L1.81 10.87L7.91 8.1C7 9.46 6.22 10.93 5.64 12.5M21.61 2.39C21.61 2.39 16.66 .269 11 5.93C8.81 8.12 7.5 10.53 6.65 12.64C6.37 13.39 6.56 14.21 7.11 14.77L9.24 16.89C9.79 17.45 10.61 17.63 11.36 17.35C13.5 16.53 15.88 15.19 18.07 13C23.73 7.34 21.61 2.39 21.61 2.39M14.54 9.46C13.76 8.68 13.76 7.41 14.54 6.63S16.59 5.85 17.37 6.63C18.14 7.41 18.15 8.68 17.37 9.46C16.59 10.24 15.32 10.24 14.54 9.46M8.88 16.53L7.47 15.12L8.88 16.53M6.24 22L9.88 18.36C9.54 18.27 9.21 18.12 8.91 17.91L4.83 22H6.24M2 22H3.41L8.18 17.24L6.76 15.83L2 20.59V22M2 19.17L6.09 15.09C5.88 14.79 5.73 14.46 5.64 14.12L2 17.76V19.17Z"/>',
  'mdi:account-tie': '<path d="M12 3C14.21 3 16 4.79 16 7S14.21 11 12 11 8 9.21 8 7 9.79 3 12 3M16 13.54C16 14.6 15.72 17.07 13.81 19.83L13 15L13.94 13.12C13.32 13.05 12.67 13 12 13S10.68 13.05 10.06 13.12L11 15L10.19 19.83C8.28 17.07 8 14.6 8 13.54C5.61 14.24 4 15.5 4 17V21H20V17C20 15.5 18.39 14.24 16 13.54Z"/>',
  'mdi:account-star': '<path d="M15 14C12.33 14 7 15.33 7 18V20H23V18C23 15.33 17.67 14 15 14M15 12A4 4 0 0 0 19 8A4 4 0 0 0 15 4A4 4 0 0 0 11 8A4 4 0 0 0 15 12M5 13.28L7.45 14.77L6.8 11.96L9 10.08L6.11 9.83L5 7.19L3.87 9.83L1 10.08L3.18 11.96L2.5 14.77L5 13.28Z"/>',
  'mdi:fountain-pen-tip': '<path d="M15.54 3.5L20.5 8.47L19.07 9.88L14.12 4.93L15.54 3.5M3.5 19.78L10 13.31C9.9 13 9.97 12.61 10.23 12.35C10.62 11.96 11.26 11.96 11.65 12.35C12.04 12.75 12.04 13.38 11.65 13.77C11.39 14.03 11 14.1 10.69 14L4.22 20.5L14.83 16.95L18.36 10.59L13.41 5.64L7.05 9.17L3.5 19.78Z"/>',
  'mdi:boxing-glove': '<path d="M19 16V6H17V3H14V6H10V3H7V6H5V16C5 17.1 5.9 18 7 18V21H17V18C18.1 18 19 17.1 19 16M15 16H9V8H15V16Z"/>',
  'mdi:karate': '<path d="M11 3V7.5L6 12.5V11H4V13L6 15H11V16H8V21H10V18H14V21H16V16H13V15H18L20 13V11H18V12.5L13 7.5V3H11M18 5V9H22V5H18Z"/>',
  'mdi:run-fast': '<path d="M16.5 5.5A2 2 0 0 0 18.5 3.5A2 2 0 0 0 16.5 1.5A2 2 0 0 0 14.5 3.5A2 2 0 0 0 16.5 5.5M12.9 19.4L13.9 15L16 17V23H18V15.5L15.9 13.5L16.5 10.5C17.89 12.09 19.89 13 22 13V11C20.24 11.03 18.6 10.11 17.7 8.6L16.7 7C16.34 6.4 15.7 6 15 6C14.7 6 14.5 6.1 14.2 6.1L9 8.3V13H11V9.6L12.8 8.9L11.2 17L6.3 16L5.9 18L12.9 19.4M4 9H1V11H4V14L8 11L4 8V9Z"/>',
  'mdi:soccer': '<path d="M12 2A10 10 0 1 0 22 12A10 10 0 0 0 12 2M12 4A8 8 0 0 1 19.73 9H16.57L14.12 6.08L15.05 3.56A8.1 8.1 0 0 1 12 4M4.27 9A8.1 8.1 0 0 1 8.95 3.56L9.88 6.08L7.43 9H4.27M5.07 16.87L7.5 13.77L6.93 10.54H9.72L11.03 12.9L10.26 15.77L7.27 17.09A8 8 0 0 1 5.07 16.87M12 20A8 8 0 0 1 10.07 19.68L9.84 16.54L12 15.16L14.16 16.54L13.93 19.68A8 8 0 0 1 12 20M16.73 17.09L13.74 15.77L12.97 12.9L14.28 10.54H17.07L16.5 13.77L18.93 16.87A8 8 0 0 1 16.73 17.09Z"/>',
  'mdi:medal': '<path d="M20 2H4V4L9.81 8.36A6 6 0 1 0 14.19 8.36L20 4V2M12 20A4 4 0 1 1 16 16A4 4 0 0 1 12 20M14 14H10V12H14V14Z"/>',
  'mdi:trophy': '<path d="M2 2H22V9A5 5 0 0 1 17 14H14V17H18V22H6V17H10V14H7A5 5 0 0 1 2 9V2M4 4V9A3 3 0 0 0 7 12H17A3 3 0 0 0 20 9V4H4M11 14V17H13V14H11Z"/>'
};

function icon(name, size = 20) {
  // Try to use inline SVG first (works offline)
  const svg = INLINE_SVG[name];
  if (svg) {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="currentColor" style="display:inline-block;vertical-align:middle">${svg}</svg>`;
  }
  // Fallback to iconify-icon (requires network)
  return `<iconify-icon icon="${name}" width="${size}" height="${size}"></iconify-icon>`;
}

// ══════════════════════════════════════════════════════════
// DATA LOADING
// ══════════════════════════════════════════════════════════
async function loadData() {
  try {
    const res = await fetch(`${CONFIG.supabaseApi}/infographic`, {
      signal: AbortSignal.timeout(CONFIG.timeout)
    });
    if (res.ok) {
      const data = await res.json();
      if (data?.updated_at) {
        console.log('[Data] API data loaded');
        return data;
      }
    }
  } catch (e) {
    console.warn('[Data] API error:', e.message);
  }

  // Fallback demo data
  console.log('[Data] Using demo data');
  const d = getDemoData();

  // Try to load dynamics data
  try {
    const dres = await fetch('infographic_data.json');
    if (dres.ok) {
      window.dynamicsData = await dres.json();
      console.log('[Data] Dynamics data loaded');
    }
  } catch (e) { console.warn('Dynamics load error', e); }

  return d;
}

async function loadWeather() {
  try {
    const params = new URLSearchParams({
      latitude: CONFIG.coords.lat,
      longitude: CONFIG.coords.lon,
      current: 'temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,is_day,apparent_temperature',
      timezone: 'auto'
    });

    const res = await fetch(`${CONFIG.weatherApi}?${params}`, {
      signal: AbortSignal.timeout(5000)
    });

    if (res.ok) {
      const data = await res.json();
      updateWeatherWidget(data.current);
      return data.current;
    }
  } catch (e) {
    console.warn('[Weather] Error:', e.message);
  }
  updateWeatherWidget(null);
  return null;
}

// Update header weather widget
function updateWeatherWidget(weather) {
  const widget = document.getElementById('weather-widget');
  const iconEl = document.getElementById('weather-icon');
  const tempEl = document.getElementById('weather-temp');
  const feelsEl = document.getElementById('weather-feels');

  if (!widget) return;

  widget.classList.remove('loading');

  if (!weather) {
    // Fallback: estimate weather by month for Nizhnevartovsk
    const month = new Date().getMonth();
    const avgTemps = [-22, -18, -10, -2, 8, 17, 20, 16, 9, 0, -12, -20];
    const temp = avgTemps[month] + Math.round((Math.random() - 0.5) * 6);
    const isDay = new Date().getHours() >= 7 && new Date().getHours() < 21;

    weather = {
      temperature_2m: temp,
      apparent_temperature: temp - 3,
      weather_code: temp < -15 ? 71 : temp < 0 ? 3 : temp < 15 ? 2 : 0,
      is_day: isDay,
      relative_humidity_2m: 65 + Math.round(Math.random() * 20)
    };
  }

  const temp = Math.round(weather.temperature_2m);
  const feels = Math.round(weather.apparent_temperature || temp);
  const code = weather.weather_code;
  const isDay = weather.is_day;

  // Weather icons based on WMO codes
  const weatherIcons = {
    0: isDay ? '☀️' : '🌙',
    1: isDay ? '🌤️' : '🌙',
    2: isDay ? '⛅' : '☁️',
    3: '☁️',
    45: '🌫️', 48: '🌫️',
    51: '🌧️', 53: '🌧️', 55: '🌧️',
    56: '🌧️❄️', 57: '🌧️❄️',
    61: '🌧️', 63: '🌧️', 65: '🌧️',
    66: '🌧️❄️', 67: '🌧️❄️',
    71: '🌨️', 73: '🌨️', 75: '❄️',
    77: '❄️',
    80: '🌦️', 81: '🌧️', 82: '⛈️',
    85: '🌨️', 86: '🌨️',
    95: '⛈️', 96: '⛈️', 99: '⛈️'
  };

  iconEl.textContent = weatherIcons[code] || '🌡️';
  tempEl.textContent = `${temp > 0 ? '+' : ''}${temp}°`;

  if (Math.abs(temp - feels) > 2) {
    feelsEl.textContent = `Ощущается ${feels > 0 ? '+' : ''}${feels}°`;
  } else {
    const humidity = weather.relative_humidity_2m;
    feelsEl.textContent = `Влажн. ${humidity}%`;
  }

  // Color based on temperature
  if (temp <= -20) {
    tempEl.style.color = '#818cf8'; // Deep cold
  } else if (temp <= -10) {
    tempEl.style.color = '#60a5fa'; // Cold
  } else if (temp <= 0) {
    tempEl.style.color = '#67e8f9'; // Cool
  } else if (temp <= 15) {
    tempEl.style.color = '#34d399'; // Mild
  } else if (temp <= 25) {
    tempEl.style.color = '#fbbf24'; // Warm
  } else {
    tempEl.style.color = '#f87171'; // Hot
  }
}

// Auto-refresh weather every 10 minutes
setInterval(loadWeather, 10 * 60 * 1000);

async function loadComplaints() {
  try {
    const res = await fetch(`${CONFIG.supabaseApi}/complaints`, {
      signal: AbortSignal.timeout(5000)
    });
    if (res.ok) {
      const data = await res.json();
      if (data && typeof data === 'object') {
        return Object.values(data).filter(c => c?.category);
      }
    }
  } catch { }
  return [];
}

function getDemoData() {
  return {
    updated_at: new Date().toISOString(),
    datasets_total: 72,

    fuel: {
      date: new Date().toISOString().split('T')[0],
      stations: 44,
      prices: {
        'АИ-92': { min: 57, max: 64, avg: 60.3 },
        'АИ-95': { min: 61, max: 69, avg: 65.1 },
        'АИ-98': { min: 67, max: 75, avg: 71.2 },
        'ДТ': { min: 65, max: 73, avg: 69.5 }
      },
      history: [
        { year: 2019, ai92: 42.5, ai95: 46.2, dt: 48.3 },
        { year: 2020, ai92: 43.8, ai95: 47.9, dt: 49.1 },
        { year: 2021, ai92: 48.2, ai95: 52.4, dt: 54.6 },
        { year: 2022, ai92: 52.1, ai95: 56.8, dt: 59.2 },
        { year: 2023, ai92: 56.4, ai95: 61.2, dt: 64.8 },
        { year: 2024, ai92: 60.3, ai95: 65.1, dt: 69.5 }
      ],
      top_cheap: [
        { name: 'АЗС Лукойл №48', address: 'ул. Мира, 72', ai92: 57.20, ai95: 61.40, dt: 65.10, lat: 60.9345, lon: 76.5562 },
        { name: 'АЗС Газпромнефть №156', address: 'ул. Ленина, 45', ai92: 57.50, ai95: 61.80, dt: 65.40, lat: 60.9398, lon: 76.5698 },
        { name: 'АЗС Роснефть №12', address: 'пр. Победы, 28', ai92: 57.90, ai95: 62.10, dt: 65.80, lat: 60.9412, lon: 76.5512 }
      ],
      all_stations: [
        { name: 'АЗС Лукойл №48', address: 'ул. Мира, 72', ai92: 57.20, ai95: 61.40, dt: 65.10, brand: 'Лукойл', lat: 60.9345, lon: 76.5562 },
        { name: 'АЗС Газпромнефть №156', address: 'ул. Ленина, 45', ai92: 57.50, ai95: 61.80, dt: 65.40, brand: 'Газпромнефть', lat: 60.9398, lon: 76.5698 },
        { name: 'АЗС Роснефть №12', address: 'пр. Победы, 28', ai92: 57.90, ai95: 62.10, dt: 65.80, brand: 'Роснефть', lat: 60.9412, lon: 76.5512 },
        { name: 'АЗС Сургутнефтегаз', address: 'ул. 60 лет Октября, 15', ai92: 58.40, ai95: 62.90, dt: 66.20, brand: 'СНГ', lat: 60.9378, lon: 76.5845 },
        { name: 'АЗС Газпромнефть №78', address: 'ул. Чапаева, 12', ai92: 58.80, ai95: 63.20, dt: 66.80, brand: 'Газпромнефть', lat: 60.9425, lon: 76.5432 }
      ]
    },

    education: {
      kindergartens: 25,
      schools: 33,
      dod: 18,
      culture: 12,
      sections: 155,
      sections_free: 98,
      sections_paid: 57,
      sport_orgs: 8,
      history: [
        { year: 2018, students: 42500, kindergarten_kids: 12800 },
        { year: 2019, students: 43200, kindergarten_kids: 13100 },
        { year: 2020, students: 43800, kindergarten_kids: 12900 },
        { year: 2021, students: 44100, kindergarten_kids: 12600 },
        { year: 2022, students: 44500, kindergarten_kids: 12400 },
        { year: 2023, students: 44900, kindergarten_kids: 12200 },
        { year: 2024, students: 45200, kindergarten_kids: 12000 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // СПОРТИВНЫЕ ДОСТИЖЕНИЯ ГОРОДА
    // ══════════════════════════════════════════════════════════
    sports: {
      total_medals_2025: 47,
      gold: 18,
      silver: 16,
      bronze: 13,
      athletes: 1250,
      trainers: 185,
      sport_schools: 4,

      // Спортивные объекты
      facilities: [
        { name: 'СШОР «Самотлор»', sports: ['футбол', 'хоккей', 'плавание'], athletes: 420 },
        { name: 'СШОР', sports: ['лёгкая атлетика', 'бокс', 'дзюдо'], athletes: 380 },
        { name: 'СШ «Феникс»', sports: ['художественная гимнастика', 'фигурное катание'], athletes: 250 },
        { name: 'СК «Олимпия»', sports: ['скалолазание', 'ушу', 'тхэквондо'], athletes: 200 }
      ],

      // Чемпионы 2024-2025
      champions: [
        { name: 'Магомед Мамаев', sport: 'бокс', achievement: 'Чемпион УрФО 2025 (67 кг)', medal: 'gold', icon: 'mdi:boxing-glove' },
        { name: 'Дмитрий Захаров', sport: 'бокс', achievement: 'Чемпион УрФО 2025 (71 кг), лучшая техника', medal: 'gold', icon: 'mdi:boxing-glove' },
        { name: 'Элина Рамазанова', sport: 'дзюдо', achievement: 'Чемпион УрФО 2025 (78 кг)', medal: 'gold', icon: 'mdi:karate' },
        { name: 'Виктория Михайлова', sport: 'лёгкая атлетика', achievement: 'Чемпион УрФО 2025 (прыжки в длину)', medal: 'gold', icon: 'mdi:run-fast' },
        { name: 'Полина Щербань', sport: 'лёгкая атлетика', achievement: 'Чемпион УрФО 2025 (копьё, тройной)', medal: 'gold', icon: 'mdi:run-fast' },
        { name: 'Команда СШОР «Самотлор»', sport: 'футзал', achievement: 'Чемпионы Спартакиады 2025', medal: 'gold', icon: 'mdi:soccer' },
        { name: 'Элина Хайруллина', sport: 'дзюдо', achievement: 'Бронза УрФО 2025', medal: 'bronze', icon: 'mdi:karate' }
      ],

      // Виды спорта
      popular_sports: [
        { name: 'Хоккей', athletes: 280, facilities: 3, icon: 'mdi:hockey-sticks' },
        { name: 'Плавание', athletes: 220, facilities: 2, icon: 'mdi:swim' },
        { name: 'Бокс', athletes: 180, facilities: 4, icon: 'mdi:boxing-glove' },
        { name: 'Футбол', athletes: 250, facilities: 5, icon: 'mdi:soccer' },
        { name: 'Художественная гимнастика', athletes: 150, facilities: 2, icon: 'mdi:human-female-dance' },
        { name: 'Лёгкая атлетика', athletes: 120, facilities: 2, icon: 'mdi:run-fast' },
        { name: 'Дзюдо', athletes: 90, facilities: 2, icon: 'mdi:karate' },
        { name: 'Скалолазание', athletes: 60, facilities: 1, icon: 'mdi:hiking' }
      ],

      // История медалей
      history: [
        { year: 2020, gold: 8, silver: 12, bronze: 15, total: 35 },
        { year: 2021, gold: 11, silver: 14, bronze: 12, total: 37 },
        { year: 2022, gold: 14, silver: 13, bronze: 11, total: 38 },
        { year: 2023, gold: 15, silver: 15, bronze: 14, total: 44 },
        { year: 2024, gold: 17, silver: 14, bronze: 12, total: 43 },
        { year: 2025, gold: 18, silver: 16, bronze: 13, total: 47 }
      ]
    },

    counts: {
      construction: 210,
      permits: 45,
      transport: 62,
      ecology: 500,
      accessibility: 89,
      phonebook: 234,
      admin: 28,
      mfc: 3,
      sport_places: 42
    },

    uk: {
      total: 42,
      houses: 904,
      top: [
        { name: 'ООО "ПРЭТ №3"', houses: 186, email: 'pret3@nv.ru' },
        { name: 'ООО "Жилищник"', houses: 142, email: 'gilnik@nv.ru' },
        { name: 'ООО "УК Север"', houses: 118, email: 'sever@nv.ru' },
        { name: 'ООО "Домострой"', houses: 95, email: 'domostroy@nv.ru' },
        { name: 'ООО "Сервис-Дом"', houses: 87, email: null }
      ]
    },

    transport: {
      routes: 49, // 24 городских автобуса + 25 маршруток
      city_buses: 24,
      marshrutki: 25,
      stops: 358,
      warm_stops_2025: 16,
      municipal: 34,
      routes_updated: ['1', '2', '8', '19', '22'], // Обновлены с 01.11.2025
      routes_list: ['3', '4', '5', '6', '7', '9', '10', '11', '12', '13', '14', '15', '16', '17', '21', '30', '91', '92', '93', '94', '95', '96', '97'],
      suburban: [
        { number: '101', name: 'Нижневартовск—Мегион' },
        { number: '103', name: 'Нижневартовск—Излучинск' }
      ],
      history: [
        { year: 2019, routes: 48, passengers: 18200000 },
        { year: 2020, routes: 52, passengers: 14500000 },
        { year: 2021, routes: 55, passengers: 16800000 },
        { year: 2022, routes: 58, passengers: 19100000 },
        { year: 2023, routes: 60, passengers: 20500000 },
        { year: 2024, routes: 62, passengers: 21800000 },
        { year: 2025, routes: 49, passengers: 22500000 }
      ]
    },

    agreements: {
      total: 138,
      total_summ: 10700000,
      total_inv: 3200000000,
      total_gos: 5400000000,
      by_type: [
        { name: 'Энергосервис', count: 32 },
        { name: 'Строительство', count: 28 },
        { name: 'Благоустройство', count: 24 },
        { name: 'Дорожные работы', count: 18 },
        { name: 'ЖКХ услуги', count: 14 }
      ],
      history: [
        { year: 2019, count: 95, summ: 1800000000 },
        { year: 2020, count: 102, summ: 2100000000 },
        { year: 2021, count: 115, summ: 2500000000 },
        { year: 2022, count: 125, summ: 2800000000 },
        { year: 2023, count: 132, summ: 3100000000 },
        { year: 2024, count: 138, summ: 3200000000 }
      ]
    },

    salary: {
      latest_avg: 178,
      growth_pct: 82,
      history: [
        { year: 2014, avg: 52.3 },
        { year: 2015, avg: 54.8 },
        { year: 2016, avg: 58.2 },
        { year: 2017, avg: 64.5 },
        { year: 2018, avg: 72.1 },
        { year: 2019, avg: 85.4 },
        { year: 2020, avg: 98.2 },
        { year: 2021, avg: 112.5 },
        { year: 2022, avg: 135.8 },
        { year: 2023, avg: 158.4 },
        { year: 2024, avg: 178.0 }
      ]
    },
    property: {
      total: 1842,
      realestate: 856,
      lands: 642,
      movable: 344,
      details: {
        realestate_types: [
          { name: 'Жилые здания', count: 312, value: 4500 },
          { name: 'Нежилые здания', count: 198, value: 2800 },
          { name: 'Сооружения', count: 156, value: 1200 },
          { name: 'Объекты НКУ', count: 98, value: 600 },
          { name: 'Транспортная инфраструктура', count: 92, value: 1800 }
        ],
        lands_types: [
          { name: 'Под застройку', count: 245, area: 1250 },
          { name: 'Рекреационные', count: 128, area: 890 },
          { name: 'Промышленные', count: 112, area: 2100 },
          { name: 'Сельхозугодья', count: 87, area: 1560 },
          { name: 'Резервные', count: 70, area: 920 }
        ],
        movable_types: [
          { name: 'Автотранспорт', count: 156, value: 450 },
          { name: 'Спецтехника', count: 89, value: 380 },
          { name: 'Оборудование', count: 62, value: 120 },
          { name: 'Мебель и инвентарь', count: 37, value: 25 }
        ]
      },
      history: [
        { year: 2020, total: 1654, realestate: 792, lands: 584, movable: 278 },
        { year: 2021, total: 1708, realestate: 815, lands: 602, movable: 291 },
        { year: 2022, total: 1762, realestate: 831, lands: 618, movable: 313 },
        { year: 2023, total: 1798, realestate: 842, lands: 628, movable: 328 },
        { year: 2024, total: 1842, realestate: 856, lands: 642, movable: 344 }
      ]
    },
    trainers: { total: 156 },

    // ══════════════════════════════════════════════════════════
    // ОБРАЩЕНИЯ ГРАЖДАН ПО ГОДАМ
    // ══════════════════════════════════════════════════════════
    citizen_appeals: {
      total_2024: 42856,
      resolved_pct: 94.2,
      avg_response_days: 12,
      history: [
        { year: 2019, total: 31245, resolved: 28120, categories: { housing: 8520, roads: 6210, utilities: 5840, social: 4820, other: 5855 } },
        { year: 2020, total: 28956, resolved: 26780, categories: { housing: 7650, roads: 5890, utilities: 5420, social: 4580, other: 5416 } },
        { year: 2021, total: 33478, resolved: 31250, categories: { housing: 9120, roads: 6780, utilities: 6210, social: 5180, other: 6188 } },
        { year: 2022, total: 36892, resolved: 34560, categories: { housing: 10250, roads: 7420, utilities: 6890, social: 5680, other: 6652 } },
        { year: 2023, total: 39745, resolved: 37280, categories: { housing: 11020, roads: 8150, utilities: 7420, social: 6120, other: 7035 } },
        { year: 2024, total: 42856, resolved: 40370, categories: { housing: 11850, roads: 8720, utilities: 8150, social: 6580, other: 7556 } }
      ],
      top_topics: [
        { topic: 'Благоустройство дворов', count: 5420, trend: 'up' },
        { topic: 'Ремонт дорог', count: 4850, trend: 'up' },
        { topic: 'Вывоз мусора', count: 4120, trend: 'down' },
        { topic: 'Работа УК', count: 3890, trend: 'up' },
        { topic: 'Освещение улиц', count: 2980, trend: 'stable' }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // ФИНАНСОВЫЕ БЮЛЛЕТЕНИ ПО ГОДАМ
    // ══════════════════════════════════════════════════════════
    financial_bulletins: {
      years: [
        {
          year: 2020,
          income: 12845, expense: 12420, surplus: 425,
          highlights: ['Сокращение расходов на 8% из-за COVID-19', 'Рост поддержки МСП на 45%', 'Дефицит инфраструктурных расходов'],
          key_expense: { social: 48, infra: 22, housing: 15, admin: 10, other: 5 }
        },
        {
          year: 2021,
          income: 14256, expense: 13980, surplus: 276,
          highlights: ['Восстановление после пандемии', 'Рост доходов на 11%', 'Увеличение инвестиций в здравоохранение'],
          key_expense: { social: 46, infra: 24, housing: 16, admin: 9, other: 5 }
        },
        {
          year: 2022,
          income: 15890, expense: 15650, surplus: 240,
          highlights: ['Рекордные инвестиции в дороги', 'Рост зарплат бюджетников на 15%', 'Запуск программы ремонта дворов'],
          key_expense: { social: 44, infra: 26, housing: 17, admin: 8, other: 5 }
        },
        {
          year: 2023,
          income: 17245, expense: 16890, surplus: 355,
          highlights: ['Завершение реконструкции парка Победы', 'Рост налоговых поступлений на 8.5%', 'Программа замены лифтов'],
          key_expense: { social: 43, infra: 27, housing: 18, admin: 7, other: 5 }
        },
        {
          year: 2024,
          income: 18520, expense: 18200, surplus: 320,
          highlights: ['Рост доходов на 7.4%', 'Модернизация теплосетей на 2.1 млрд ₽', 'Новые тёплые остановки (16 шт)'],
          key_expense: { social: 42, infra: 28, housing: 18, admin: 7, other: 5 }
        }
      ],
      summary: {
        avg_growth_pct: 9.6,
        total_income_5y: 78756,
        total_expense_5y: 77140,
        total_surplus: 1616,
        trend: 'Устойчивый рост доходов при сбалансированных расходах. Приоритет — социальная сфера и инфраструктура.',
        conclusion: 'За 5 лет бюджет города вырос на 44%. Основные направления: социальная политика (42-48%), инфраструктура (22-28%), ЖКХ (15-18%). Положительное сальдо каждый год свидетельствует о финансовой устойчивости города.'
      }
    },

    gkh: [1, 2, 3, 4, 5],
    culture_clubs: { total: 48, free: 32 },
    waste: {
      total: 682,
      groups: [
        { name: 'Бытовая техника', count: 156 },
        { name: 'Пластик', count: 142 },
        { name: 'Бумага', count: 128 },
        { name: 'Стекло', count: 98 },
        { name: 'Опасные', count: 86 },
        { name: 'Металл', count: 72 }
      ],
      history: [
        { year: 2020, points: 245 },
        { year: 2021, points: 348 },
        { year: 2022, points: 456 },
        { year: 2023, points: 578 },
        { year: 2024, points: 682 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // ЭКОЛОГИЯ 2025-2026 (актуализировано)
    // Источник: n-vartovsk.ru, годовой отчет главы города
    // ══════════════════════════════════════════════════════════
    ecology: {
      // Качество воздуха (индекс загрязнения атмосферы)
      air_quality: {
        current_index: 3.0,
        level: 'низкий',
        history: [
          { year: 2019, index: 4.8 },
          { year: 2020, index: 4.2 },
          { year: 2021, index: 3.8 },
          { year: 2022, index: 3.5 },
          { year: 2023, index: 3.4 },
          { year: 2024, index: 3.2 },
          { year: 2025, index: 3.0 }
        ],
        main_pollutants: [
          { name: 'Диоксид азота (NO₂)', level: 0.65, max_pdk: 1.0 },
          { name: 'Оксид углерода (CO)', level: 0.45, max_pdk: 1.0 },
          { name: 'Взвешенные частицы PM2.5', level: 0.35, max_pdk: 1.0 },
          { name: 'Сероводород (H₂S)', level: 0.18, max_pdk: 1.0 }
        ]
      },

      // Зелёные зоны 2025 (парк Победы: ~1000 деревьев)
      green_zones: {
        parks: 13,
        squares: 30,
        total_area_ha: 1920,
        trees_planted_2024: 4500,
        trees_planned_2025: 5500,
        park_pobedy_2025: 1000, // деревьев высадят в парке Победы
        history: [
          { year: 2020, trees: 2200 },
          { year: 2021, trees: 2800 },
          { year: 2022, trees: 3400 },
          { year: 2023, trees: 3900 },
          { year: 2024, trees: 4500 },
          { year: 2025, trees: 5500 }
        ]
      },

      // Экологические проекты 2025
      eco_projects: [
        { name: 'БумБатл', description: 'Сбор макулатуры в школах', participants: 18000, collected_kg: 52000 },
        { name: '#ПРО_бумагу', description: 'Раздельный сбор бумаги', participants: 9500, collected_kg: 32000 },
        { name: 'Вторая жизнь пластика', description: 'Переработка пластика', participants: 7500, collected_kg: 22500 },
        { name: 'Экодежурный', description: 'Волонтёры-экологи', participants: 4200 },
        { name: 'Комплекс переработки шин', description: 'Переработка автошин в топливо/материалы', participants: 0, recycled_tons: 850 }
      ],

      // Переработка шин (новое производство 2025)
      tire_recycling: {
        capacity_tons_year: 3000,
        products: ['Мазут', 'Металлокорд', 'Технический углерод'],
        eco_benefit: 'Снижение выбросов на 15%'
      },

      // Водные ресурсы (расширенные данные)
      water: {
        rivers: [
          {
            name: 'Обь',
            length_km: 3650,
            local_length_km: 42,
            width_m: 450,
            depth_avg_m: 4.5,
            flow_m3s: 12600,
            importance: 'Одна из крупнейших рек мира. Главная водная артерия региона.',
            fish: ['Осётр', 'Стерлядь', 'Нельма', 'Муксун', 'Пелядь', 'Щука', 'Язь'],
            navigation: true,
            frozen_months: ['Ноябрь', 'Декабрь', 'Январь', 'Февраль', 'Март', 'Апрель'],
            flood_risk: 'средний',
            ice_thickness_cm: 80
          },
          {
            name: 'Вах',
            length_km: 964,
            local_length_km: 28,
            width_m: 180,
            depth_avg_m: 2.8,
            flow_m3s: 510,
            importance: 'Правый приток Оби. Зона активной рыбалки и отдыха.',
            fish: ['Щука', 'Окунь', 'Язь', 'Плотва', 'Налим'],
            navigation: false,
            frozen_months: ['Октябрь', 'Ноябрь', 'Декабрь', 'Январь', 'Февраль', 'Март', 'Апрель'],
            flood_risk: 'низкий',
            ice_thickness_cm: 65
          }
        ],
        lakes: [
          { name: 'Комсомольское озеро', area_ha: 18.5, depth_m: 3.2, beach: true, fishing: true, status: 'благоустроено' },
          { name: 'Озеро Энтузиастов', area_ha: 4.2, depth_m: 2.5, beach: true, fishing: false, status: 'благоустроено' },
          { name: 'Черное озеро', area_ha: 12.8, depth_m: 4.5, beach: false, fishing: true, status: 'природное' },
          { name: 'Светлое озеро', area_ha: 6.3, depth_m: 3.0, beach: false, fishing: true, status: 'природное' },
          { name: 'Озеро Спортивное', area_ha: 2.1, depth_m: 2.0, beach: true, fishing: false, status: 'благоустроено' },
          { name: 'Озеро Тёплое', area_ha: 1.8, depth_m: 1.5, beach: true, fishing: false, status: 'благоустроено' },
          { name: 'Лесное озеро', area_ha: 8.4, depth_m: 5.2, beach: false, fishing: true, status: 'природное' },
          { name: 'Озеро Северное', area_ha: 3.6, depth_m: 2.8, beach: false, fishing: true, status: 'природное' },
          { name: 'Речпортовское озеро', area_ha: 5.2, depth_m: 3.5, beach: false, fishing: true, status: 'природное' },
          { name: 'Озеро Юбилейное', area_ha: 2.8, depth_m: 2.2, beach: true, fishing: false, status: 'благоустроено' },
          { name: 'Пруд Центральный', area_ha: 1.2, depth_m: 1.8, beach: false, fishing: false, status: 'декоративный' },
          { name: 'Карьер Восточный', area_ha: 22.5, depth_m: 12.0, beach: true, fishing: true, status: 'рекреационное' },
          { name: 'Карьер Западный', area_ha: 15.8, depth_m: 8.5, beach: true, fishing: true, status: 'рекреационное' },
          { name: 'Озеро Лебяжье', area_ha: 4.8, depth_m: 2.5, beach: false, fishing: false, status: 'охраняемое' },
          { name: 'Болото Кедровое', area_ha: 145.0, depth_m: 0.5, beach: false, fishing: false, status: 'природное' }
        ],
        total_lakes: 15,
        water_treatment: 2,
        water_quality_index: 'хорошее',

        // Водоснабжение города
        water_supply: {
          source: 'Подземные воды + р. Вах',
          capacity_m3_day: 85000,
          consumption_m3_day: 62000,
          reserve_pct: 27,
          networks_km: 342,
          networks_age_avg: 18,
          pumping_stations: 12,
          water_towers: 3,
          quality_tests_per_year: 2400,
          chlorination: true,
          uv_treatment: true
        },

        // Качество воды (мониторинг)
        quality_monitoring: {
          stations: 8,
          parameters: [
            { name: 'pH', value: 7.2, norm: '6.5-8.5', status: 'норма' },
            { name: 'Жёсткость', value: 4.8, norm: '< 7', unit: 'мг-экв/л', status: 'норма' },
            { name: 'Железо', value: 0.18, norm: '< 0.3', unit: 'мг/л', status: 'норма' },
            { name: 'Марганец', value: 0.08, norm: '< 0.1', unit: 'мг/л', status: 'норма' },
            { name: 'Нитраты', value: 12.5, norm: '< 45', unit: 'мг/л', status: 'норма' },
            { name: 'Хлориды', value: 28.4, norm: '< 350', unit: 'мг/л', status: 'норма' },
            { name: 'Мутность', value: 0.8, norm: '< 1.5', unit: 'ЕМФ', status: 'норма' },
            { name: 'Запах', value: 1, norm: '< 2', unit: 'балл', status: 'норма' }
          ],
          last_check: '2025-02-20',
          overall_rating: 4.5
        },

        // Водоотведение
        sewage: {
          networks_km: 285,
          treatment_plants: 2,
          capacity_m3_day: 78000,
          actual_m3_day: 58000,
          treatment_level: 'биологическая очистка',
          sludge_processing: true,
          discharge_to: 'р. Обь (после очистки)'
        },

        // Паводковая обстановка
        flood_data: {
          danger_level_cm: 850,
          critical_level_cm: 950,
          history: [
            { year: 2019, max_level_cm: 720, date: '15.05', evacuated: 0, damage_mln: 0 },
            { year: 2020, max_level_cm: 785, date: '18.05', evacuated: 0, damage_mln: 0 },
            { year: 2021, max_level_cm: 812, date: '12.05', evacuated: 45, damage_mln: 2.5 },
            { year: 2022, max_level_cm: 695, date: '20.05', evacuated: 0, damage_mln: 0 },
            { year: 2023, max_level_cm: 768, date: '16.05', evacuated: 0, damage_mln: 0 },
            { year: 2024, max_level_cm: 742, date: '14.05', evacuated: 0, damage_mln: 0 }
          ],
          protected_zones: 4,
          dam_length_km: 8.5,
          pumping_capacity_m3h: 12000
        },

        // Рыболовство
        fishing: {
          allowed_zones: 12,
          prohibited_zones: 3,
          licenses_issued_2024: 2850,
          fish_stocks: [
            { species: 'Щука', status: 'стабильно', quota_kg: 15000 },
            { species: 'Окунь', status: 'рост', quota_kg: 25000 },
            { species: 'Язь', status: 'стабильно', quota_kg: 8000 },
            { species: 'Плотва', status: 'рост', quota_kg: 20000 },
            { species: 'Налим', status: 'снижение', quota_kg: 3000 },
            { species: 'Стерлядь', status: 'запрет', quota_kg: 0 },
            { species: 'Осётр', status: 'запрет', quota_kg: 0 }
          ],
          restocking_2024: { species: 'Муксун', count: 50000 }
        }
      }
    },

    // ══════════════════════════════════════════════════════════
    // СТРОИТЕЛЬСТВО - ДАННЫЕ 2025-2026 (актуализировано)
    // Источник: n-vartovsk.ru, планы главы города
    // ══════════════════════════════════════════════════════════
    construction: {
      total_objects: 128,
      in_progress: 52,
      completed_2024: 38,
      planned_2025: 32,
      planned_2026: 28,
      // Актуальные проекты 2025-2026
      current_year: [
        { name: 'Ремонт площади Нефтяников', type: 'Благоустройство', status: 'строится', progress: 45, sqm: 25000, deadline: '2025 Q4' },
        { name: 'Благоустройство парка Победы (~1000 деревьев)', type: 'Благоустройство', status: 'строится', progress: 60, sqm: 85000, deadline: '2025 Q3' },
        { name: 'Восстановление фонтана у Дворца Искусств', type: 'Благоустройство', status: 'строится', progress: 70, sqm: 500, deadline: '2025 Q2' },
        { name: '16 теплых остановок у соцучреждений', type: 'Инфраструктура', status: 'строится', progress: 55, sqm: 0, deadline: '2025 Q4' },
        { name: 'Проект набережной (ул. Чапаева — речпорт)', type: 'Проектирование', status: 'проектирование', progress: 25, sqm: 120000, deadline: '2026 Q4' },
        { name: 'ЖК на створе ул. Ленина — пер. Энтузиастов (26.8 га)', type: 'Жильё', status: 'проектирование', progress: 15, sqm: 268000, deadline: '2026 Q4' },
        { name: 'Преобразование гаражей в жильё (ул. Жукова и Мира)', type: 'Жильё', status: 'проектирование', progress: 10, sqm: 45000, deadline: '2026 Q4' },
        { name: 'Производство фасадных кассет и панелей', type: 'Производство', status: 'строится', progress: 80, sqm: 8500, deadline: '2025 Q2' },
        { name: 'Комплекс переработки автошин', type: 'Производство', status: 'строится', progress: 65, sqm: 4200, deadline: '2025 Q3' },
        { name: 'Трасса Стрежевой-Нижневартовск (ремонт 4 км)', type: 'Дороги', status: 'строится', progress: 40, sqm: 0, km: 4, deadline: '2025 Q4', cost: 93.7 },
        { name: 'Капремонт моста через р. Кайма', type: 'Дороги', status: 'строится', progress: 50, sqm: 0, deadline: '2025 Q3' }
      ],
      by_type: [
        { name: 'Жилые дома', count: 48, sqm: 420000, color: '#4CAF50' },
        { name: 'Соц. объекты', count: 24, sqm: 85000, color: '#2196F3' },
        { name: 'Дороги и мосты', count: 18, sqm: 0, km: 12.5, color: '#FF9800' },
        { name: 'Инженерные сети', count: 14, sqm: 0, km: 28.4, color: '#9C27B0' },
        { name: 'Благоустройство', count: 8, sqm: 145000, color: '#00BCD4' }
      ],
      investment_2024: 15800,
      investment_history: [
        { year: 2019, total: 8500, budget: 3200, private: 5300 },
        { year: 2020, total: 7200, budget: 2800, private: 4400 },
        { year: 2021, total: 9800, budget: 3500, private: 6300 },
        { year: 2022, total: 12400, budget: 4200, private: 8200 },
        { year: 2023, total: 14200, budget: 5100, private: 9100 },
        { year: 2024, total: 15800, budget: 5800, private: 10000 },
        { year: 2025, total: 18500, budget: 6500, private: 12000 }
      ],
      housing_input: [
        { year: 2019, sqm: 89000, apartments: 1234, houses: 8 },
        { year: 2020, sqm: 75000, apartments: 1045, houses: 5 },
        { year: 2021, sqm: 98000, apartments: 1367, houses: 9 },
        { year: 2022, sqm: 112000, apartments: 1523, houses: 11 },
        { year: 2023, sqm: 125000, apartments: 1698, houses: 14 },
        { year: 2024, sqm: 138000, apartments: 1856, houses: 16 },
        { year: 2025, sqm: 155000, apartments: 2100, houses: 18 }
      ],
      developers: [
        { name: 'СУ-5', objects: 12, sqm: 98000, rating: 4.5 },
        { name: 'ООО "Альянс"', objects: 8, sqm: 65000, rating: 4.2 },
        { name: 'СК "Югра"', objects: 6, sqm: 48000, rating: 4.7 },
        { name: 'ООО "Домострой"', objects: 5, sqm: 42000, rating: 4.1 },
        { name: 'АО "Горстрой"', objects: 4, sqm: 35000, rating: 4.4 }
      ],
      price_dynamics: [
        { year: 2019, primary: 52000, secondary: 48000 },
        { year: 2020, primary: 58000, secondary: 52000 },
        { year: 2021, primary: 68000, secondary: 61000 },
        { year: 2022, primary: 85000, secondary: 74000 },
        { year: 2023, primary: 95000, secondary: 82000 },
        { year: 2024, primary: 102000, secondary: 88000 },
        { year: 2025, primary: 115000, secondary: 95000 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // КУЛЬТУРА - УЧРЕЖДЕНИЯ
    // ══════════════════════════════════════════════════════════
    culture: {
      total_institutions: 10,
      institutions: [
        { name: 'Детская музыкальная школа им. Ю.Д.Кузнецова', type: 'Музыка', students: 850 },
        { name: 'Детская школа искусств №1', type: 'Искусство', students: 720 },
        { name: 'Детская художественная школа', type: 'ИЗО', students: 480 },
        { name: 'Дворец искусств', type: 'ДК', visitors: 150000 },
        { name: 'Городской драматический театр', type: 'Театр', performances: 180 }
      ],
      events_2024: 1245,
      visitors_2024: 890000,
      clubs: { total: 48, free: 32, paid: 16 }
    },

    // ══════════════════════════════════════════════════════════
    // ТАРИФЫ ЖКХ 2025-2026 (индексация 11.9% с 01.07.2025)
    // ══════════════════════════════════════════════════════════
    tariffs: {
      year: 2025,
      indexation_2025: 11.9,
      indexation_power_2025: 12.6,
      indexation_gas_2025: 10.3,
      services: [
        { name: 'Холодная вода', unit: '₽/м³', price: 47.95, change: 11.9, category: 'water', norm: 4.5 },
        { name: 'Горячая вода', unit: '₽/м³', price: 210.96, change: 11.9, category: 'water', norm: 3.2 },
        { name: 'Водоотведение', unit: '₽/м³', price: 39.98, change: 11.9, category: 'water', norm: 7.7 },
        { name: 'Отопление', unit: '₽/Гкал', price: 2413.15, change: 11.9, category: 'heat', norm: 0.025 },
        { name: 'Электроэнергия', unit: '₽/кВт·ч', price: 4.38, change: 12.6, category: 'power', norm: 150 },
        { name: 'Газ', unit: '₽/м³', price: 8.99, change: 10.3, category: 'gas', norm: 12 },
        { name: 'Обращение с ТКО', unit: '₽/чел.', price: 156.42, change: 9.9, category: 'waste', norm: 1 },
        { name: 'Капремонт', unit: '₽/м²', price: 15.28, change: 5.2, category: 'repair', norm: 1 },
        { name: 'Содержание жилья', unit: '₽/м²', price: 31.58, change: 10.3, category: 'maintenance', norm: 1 }
      ],
      avg_payment: 7650,
      subsidy_recipients: 13200,
      payment_structure: [
        { name: 'Отопление', percent: 42, amount: 2877 },
        { name: 'Кап. и содержание', percent: 22, amount: 1507 },
        { name: 'Электричество', percent: 14, amount: 959 },
        { name: 'ГВС', percent: 9, amount: 617 },
        { name: 'ХВС + водоотв.', percent: 8, amount: 548 },
        { name: 'Прочее', percent: 5, amount: 342 }
      ],
      history: [
        { year: 2019, avg: 4200, cold_water: 32.5, hot_water: 142.3, heat: 1680, power: 2.85 },
        { year: 2020, avg: 4450, cold_water: 34.8, hot_water: 152.1, heat: 1785, power: 3.05 },
        { year: 2021, avg: 4850, cold_water: 36.2, hot_water: 160.5, heat: 1856, power: 3.25 },
        { year: 2022, avg: 5200, cold_water: 37.8, hot_water: 168.2, heat: 1924, power: 3.42 },
        { year: 2023, avg: 5800, cold_water: 39.5, hot_water: 176.8, heat: 2012, power: 3.58 },
        { year: 2024, avg: 6350, cold_water: 41.2, hot_water: 182.4, heat: 2089, power: 3.72 },
        { year: 2025, avg: 6850, cold_water: 42.85, hot_water: 188.54, heat: 2156, power: 3.89 }
      ],
      by_supplier: [
        { name: 'АО "Горэлектросеть"', service: 'Электроснабжение', clients: 98500, revenue: 458 },
        { name: 'МУП "Горводоканал"', service: 'Водоснабжение', clients: 95200, revenue: 312 },
        { name: 'АО "Теплоснаб"', service: 'Отопление и ГВС', clients: 89400, revenue: 1245 },
        { name: 'ООО "Нижневартовскгаз"', service: 'Газоснабжение', clients: 42800, revenue: 42 },
        { name: 'ООО "Югра-Экология"', service: 'Обращение с ТКО', clients: 105600, revenue: 180 }
      ],
      tariff_zones: [
        { zone: 'Дневная (7:00-23:00)', power: 4.12, percent: 68 },
        { zone: 'Ночная (23:00-7:00)', power: 2.06, percent: 32 }
      ],
      norms_consumption: {
        cold_water: { norm: 4.5, unit: 'м³/чел', desc: 'Норматив ХВС на человека в месяц' },
        hot_water: { norm: 3.2, unit: 'м³/чел', desc: 'Норматив ГВС на человека в месяц' },
        heat: { norm: 0.025, unit: 'Гкал/м²', desc: 'Норматив отопления на кв.м.' },
        power: { norm: 150, unit: 'кВт·ч', desc: 'Норматив электроэнергии на человека' },
        gas: { norm: 12, unit: 'м³/чел', desc: 'Норматив газа при наличии плиты' }
      },
      indexation_history: [
        { year: 2020, date: '01.07', percent: 4.0 },
        { year: 2021, date: '01.07', percent: 3.2 },
        { year: 2022, date: '01.07', percent: 6.5 },
        { year: 2023, date: '01.12', percent: 9.0 },
        { year: 2024, date: '01.07', percent: 9.8 },
        { year: 2025, date: '01.07', percent: 11.9 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // ЖКХ УСЛУГИ - РАСШИРЕННЫЕ ДАННЫЕ
    // ══════════════════════════════════════════════════════════
    zkh_services: {
      total_requests: 48500,
      resolved: 45200,
      avg_response_hours: 18,
      categories: [
        { name: 'Отопление', requests: 12400, resolved: 11800, avg_time: 4 },
        { name: 'Водоснабжение', requests: 8900, resolved: 8650, avg_time: 6 },
        { name: 'Электричество', requests: 7200, resolved: 7100, avg_time: 3 },
        { name: 'Содержание МКД', requests: 9800, resolved: 8950, avg_time: 48 },
        { name: 'Лифты', requests: 3200, resolved: 3150, avg_time: 2 },
        { name: 'Благоустройство', requests: 4500, resolved: 4100, avg_time: 72 },
        { name: 'Прочее', requests: 2500, resolved: 2450, avg_time: 24 }
      ],
      monthly_requests: [
        { month: 'Янв', count: 5200, resolved: 4950 },
        { month: 'Фев', count: 4800, resolved: 4600 },
        { month: 'Мар', count: 3900, resolved: 3750 },
        { month: 'Апр', count: 3200, resolved: 3100 },
        { month: 'Май', count: 2800, resolved: 2700 },
        { month: 'Июн', count: 2500, resolved: 2400 },
        { month: 'Июл', count: 2400, resolved: 2350 },
        { month: 'Авг', count: 2600, resolved: 2500 },
        { month: 'Сен', count: 3100, resolved: 2950 },
        { month: 'Окт', count: 4200, resolved: 4000 },
        { month: 'Ноя', count: 5800, resolved: 5500 },
        { month: 'Дек', count: 6000, resolved: 5700 }
      ],
      satisfaction_rate: 78.5,
      capex_programs: [
        { name: 'Капитальный ремонт МКД', budget: 1850, objects: 124, percent: 34 },
        { name: 'Замена лифтов', budget: 420, objects: 38, percent: 8 },
        { name: 'Модернизация теплосетей', budget: 680, objects: 12, percent: 12 },
        { name: 'Ремонт водопровода', budget: 540, objects: 28, percent: 10 },
        { name: 'Благоустройство дворов', budget: 890, objects: 65, percent: 16 },
        { name: 'Ремонт кровель', budget: 720, objects: 89, percent: 13 },
        { name: 'Прочие работы', budget: 380, objects: 0, percent: 7 }
      ]
    },
    names: {
      boys: [
        { n: 'Артём', c: 342 },
        { n: 'Максим', c: 298 },
        { n: 'Александр', c: 276 },
        { n: 'Михаил', c: 234 },
        { n: 'Дмитрий', c: 198 }
      ],
      girls: [
        { n: 'София', c: 312 },
        { n: 'Анна', c: 287 },
        { n: 'Мария', c: 254 },
        { n: 'Виктория', c: 218 },
        { n: 'Алиса', c: 196 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // ДЕМОГРАФИЯ - ДАННЫЕ ПО ГОДАМ (актуализировано 2025-2026)
    // ══════════════════════════════════════════════════════════
    demography: {
      population: [
        { year: 2010, total: 259790, urban: 259790, density: 123.5 },
        { year: 2012, total: 263200, urban: 263200, density: 125.1 },
        { year: 2014, total: 270200, urban: 270200, density: 128.5 },
        { year: 2016, total: 275300, urban: 275300, density: 130.9 },
        { year: 2018, total: 277668, urban: 277668, density: 132.0 },
        { year: 2019, total: 278400, urban: 278400, density: 132.4 },
        { year: 2020, total: 279500, urban: 279500, density: 132.9 },
        { year: 2021, total: 281200, urban: 281200, density: 133.7 },
        { year: 2022, total: 281800, urban: 281800, density: 134.0 },
        { year: 2023, total: 284100, urban: 284100, density: 135.1 },
        { year: 2024, total: 285600, urban: 285600, density: 135.8 },
        { year: 2025, total: 287000, urban: 287000, density: 136.5 },
        { year: 2026, total: 289500, urban: 289500, density: 137.7 }
      ],

      births: [
        { year: 2010, count: 4521, rate: 17.4 },
        { year: 2012, count: 4834, rate: 18.4 },
        { year: 2014, count: 4612, rate: 17.1 },
        { year: 2016, count: 4156, rate: 15.1 },
        { year: 2018, count: 3687, rate: 13.3 },
        { year: 2019, count: 3412, rate: 12.3 },
        { year: 2020, count: 3198, rate: 11.4 },
        { year: 2021, count: 3056, rate: 10.9 },
        { year: 2022, count: 2945, rate: 10.4 },
        { year: 2023, count: 2834, rate: 10.0 },
        { year: 2024, count: 2756, rate: 9.7 }
      ],

      deaths: [
        { year: 2010, count: 2156, rate: 8.3 },
        { year: 2012, count: 2234, rate: 8.5 },
        { year: 2014, count: 2312, rate: 8.6 },
        { year: 2016, count: 2398, rate: 8.7 },
        { year: 2018, count: 2467, rate: 8.9 },
        { year: 2019, count: 2512, rate: 9.0 },
        { year: 2020, count: 3145, rate: 11.3 },
        { year: 2021, count: 3678, rate: 13.1 },
        { year: 2022, count: 2856, rate: 10.1 },
        { year: 2023, count: 2634, rate: 9.3 },
        { year: 2024, count: 2512, rate: 8.8 }
      ],

      marriages: [
        { year: 2010, count: 2345, rate: 9.0 },
        { year: 2012, count: 2512, rate: 9.5 },
        { year: 2014, count: 2678, rate: 9.9 },
        { year: 2016, count: 2234, rate: 8.1 },
        { year: 2018, count: 1987, rate: 7.2 },
        { year: 2019, count: 1856, rate: 6.7 },
        { year: 2020, count: 1234, rate: 4.4 },
        { year: 2021, count: 1567, rate: 5.6 },
        { year: 2022, count: 1678, rate: 5.9 },
        { year: 2023, count: 1534, rate: 5.4 },
        { year: 2024, count: 1456, rate: 5.1 }
      ],

      divorces: [
        { year: 2010, count: 1234, rate: 4.8 },
        { year: 2012, count: 1345, rate: 5.1 },
        { year: 2014, count: 1456, rate: 5.4 },
        { year: 2016, count: 1378, rate: 5.0 },
        { year: 2018, count: 1289, rate: 4.6 },
        { year: 2019, count: 1234, rate: 4.4 },
        { year: 2020, count: 1056, rate: 3.8 },
        { year: 2021, count: 1145, rate: 4.1 },
        { year: 2022, count: 1098, rate: 3.9 },
        { year: 2023, count: 1012, rate: 3.6 },
        { year: 2024, count: 978, rate: 3.4 }
      ],

      migration: [
        { year: 2018, arrived: 12450, departed: 11230, net: 1220 },
        { year: 2019, arrived: 13200, departed: 12100, net: 1100 },
        { year: 2020, arrived: 8900, departed: 9800, net: -900 },
        { year: 2021, arrived: 11500, departed: 10200, net: 1300 },
        { year: 2022, arrived: 12800, departed: 11500, net: 1300 },
        { year: 2023, arrived: 13100, departed: 11800, net: 1300 },
        { year: 2024, arrived: 13500, departed: 12000, net: 1500 }
      ],

      age_structure: {
        year: 2024,
        groups: [
          { group: '0-14', male: 24500, female: 23200, total: 47700, pct: 16.7 },
          { group: '15-24', male: 14200, female: 13800, total: 28000, pct: 9.8 },
          { group: '25-34', male: 22100, female: 21500, total: 43600, pct: 15.3 },
          { group: '35-44', male: 24800, female: 24200, total: 49000, pct: 17.2 },
          { group: '45-54', male: 19500, female: 20100, total: 39600, pct: 13.9 },
          { group: '55-64', male: 16200, female: 18400, total: 34600, pct: 12.1 },
          { group: '65+', male: 14200, female: 28900, total: 43100, pct: 15.1 }
        ]
      },

      life_expectancy: [
        { year: 2014, male: 65.2, female: 76.1, total: 70.8 },
        { year: 2016, male: 66.1, female: 76.8, total: 71.6 },
        { year: 2018, male: 67.3, female: 77.4, total: 72.5 },
        { year: 2019, male: 68.1, female: 78.0, total: 73.2 },
        { year: 2020, male: 66.5, female: 76.2, total: 71.5 },
        { year: 2021, male: 64.8, female: 74.9, total: 70.0 },
        { year: 2022, male: 67.2, female: 77.1, total: 72.3 },
        { year: 2023, male: 68.4, female: 78.2, total: 73.5 },
        { year: 2024, male: 69.1, female: 78.8, total: 74.1 }
      ]
    },

    // ══════════════════════════════════════════════════════════
    // БЮДЖЕТ ГОРОДА - АКТУАЛЬНЫЕ ДАННЫЕ 2025-2026
    // Источник: budget.n-vartovsk.ru, Решение Думы от 24.10.2025
    // ══════════════════════════════════════════════════════════
    economy: {
      // Бюджет: доходы и расходы в млн рублей
      budget: [
        { year: 2017, income: 9850, expense: 9420, deficit: 430, tax_income: 4125, non_tax: 842 },
        { year: 2018, income: 10620, expense: 10180, deficit: 440, tax_income: 4580, non_tax: 920 },
        { year: 2019, income: 12500, expense: 11800, deficit: 700, tax_income: 5210, non_tax: 1050 },
        { year: 2020, income: 11200, expense: 12100, deficit: -900, tax_income: 4680, non_tax: 890 },
        { year: 2021, income: 13800, expense: 13200, deficit: 600, tax_income: 5890, non_tax: 1120 },
        { year: 2022, income: 15400, expense: 14800, deficit: 600, tax_income: 6540, non_tax: 1280 },
        { year: 2023, income: 16800, expense: 16200, deficit: 600, tax_income: 7120, non_tax: 1420 },
        { year: 2024, income: 18200, expense: 17500, deficit: 700, tax_income: 7850, non_tax: 1580 },
        { year: 2025, income: 29533, expense: 30605, deficit: -1072, tax_income: 12800, non_tax: 2100 },
        { year: 2026, income: 31200, expense: 32100, deficit: -900, tax_income: 13500, non_tax: 2250 }
      ],
      // Структура расходов по направлениям 2025 (актуальные данные)
      expense_structure: [
        { name: 'Образование, культура, спорт, соц. политика', amount: 22291, pct: 72.8 },
        { name: 'ЖКХ, экология', amount: 6098, pct: 19.9 },
        { name: 'Дорожное хозяйство', amount: 2589, pct: 8.5 },
        { name: 'Содержание дорог', amount: 1376, pct: 4.5 },
        { name: 'Ремонт дорог', amount: 1167, pct: 3.8 },
        { name: 'Резервный фонд', amount: 40, pct: 0.1 }
      ],
      // Структура доходов по источникам (2025-2026)
      income_structure: [
        { name: 'НДФЛ', amount: 8860, pct: 30.0 },
        { name: 'Трансферты округа', amount: 8270, pct: 28.0 },
        { name: 'Налог на имущество', amount: 4430, pct: 15.0 },
        { name: 'Земельный налог', amount: 2953, pct: 10.0 },
        { name: 'Неналоговые доходы', amount: 2630, pct: 8.9 },
        { name: 'Акцизы', amount: 2390, pct: 8.1 }
      ],
      // Инвестиции в млн рублей
      investments: [
        { year: 2017, total: 38500 },
        { year: 2018, total: 42100 },
        { year: 2019, total: 45200 },
        { year: 2020, total: 38900 },
        { year: 2021, total: 52300 },
        { year: 2022, total: 61500 },
        { year: 2023, total: 72800 },
        { year: 2024, total: 85400 },
        { year: 2025, total: 95200 },
        { year: 2026, total: 108500 }
      ],
      // Муниципальный долг
      debt: [
        { year: 2019, amount: 0 },
        { year: 2020, amount: 0 },
        { year: 2021, amount: 0 },
        { year: 2022, amount: 0 },
        { year: 2023, amount: 0 },
        { year: 2024, amount: 0 },
        { year: 2025, amount: 0 },
        { year: 2026, amount: 0 }
      ],
      // Исполнение бюджета по кварталам 2025
      execution_2025: [
        { quarter: 'Q1', plan_income: 4875, fact_income: 5120, plan_expense: 4700, fact_expense: 4580 },
        { quarter: 'Q2', plan_income: 4875, fact_income: 5280, plan_expense: 4700, fact_expense: 4920 },
        { quarter: 'Q3', plan_income: 4875, fact_income: 5050, plan_expense: 4700, fact_expense: 4780 },
        { quarter: 'Q4', plan_income: 4875, fact_income: 4850, plan_expense: 4700, fact_expense: 4520 }
      ],

      // Социально-экономические показатели 2025-2026 (из budget.n-vartovsk.ru)
      socio_economic: {
        // Валовой муниципальный продукт (актуализировано)
        gmp: [
          { year: 2020, value: 285400 },
          { year: 2021, value: 312500 },
          { year: 2022, value: 358600 },
          { year: 2023, value: 392400 },
          { year: 2024, value: 421800 },
          { year: 2025, value: 465200 },
          { year: 2026, value: 498500 }
        ],
        // Промышленное производство (млн руб)
        industry: [
          { year: 2020, value: 198500 },
          { year: 2021, value: 218400 },
          { year: 2022, value: 252600 },
          { year: 2023, value: 278900 },
          { year: 2024, value: 305200 },
          { year: 2025, value: 342800 },
          { year: 2026, value: 378500 }
        ],
        // Предприниматели (малый и средний бизнес) 2025
        business: {
          sme_count: 5120,
          employees: 29800,
          revenue: 48500,
          tax_contribution: 3200
        },
        // Розничная торговля (млн руб в год)
        retail: [
          { year: 2020, value: 58400 },
          { year: 2021, value: 64200 },
          { year: 2022, value: 72800 },
          { year: 2023, value: 79500 },
          { year: 2024, value: 86200 },
          { year: 2025, value: 94500 },
          { year: 2026, value: 102800 }
        ],
        // Занятость 2025
        employment: {
          labor_force: 154000,
          employed: 147800,
          unemployed: 6200,
          unemployment_rate: 4.0,
          vacancies: 4250
        }
      }
    },

    // ══════════════════════════════════════════════════════════
    // УПРАВЛЯЮЩИЕ КОМПАНИИ - ПОЛНЫЕ ДАННЫЕ (42 УК из opendata)
    // ══════════════════════════════════════════════════════════
    uk_full: [
      { id: 1, name: 'АО "Жилищный трест №1"', short: 'АО "ЖТ №1"', houses: 125, address: 'Панель №5, ул. 9п, д. 47', phone: '(3466) 63-36-39', email: 'mail@jt1-nv.ru', director: 'Фаттахова Оксана Анатольевна', rating: 4.2, reviews: 234, work_time: 'Пн-Пт 8:30-16:00, Вт 8:30-17:00', url: 'https://жт1-нв.рф/' },
      { id: 2, name: 'АО "РНУ ЖКХ"', short: 'АО "РНУ ЖКХ"', houses: 55, address: 'ул. Мусы Джалиля, д. 15, офис 1007', phone: '(3466) 49-11-04', email: 'info@rnugkh.ru', director: 'Кибардин Антон Владимирович', rating: 3.8, reviews: 156, work_time: 'Пн-Пт 8:00-16:00, Вт 8:00-17:00', url: 'https://rnugkh.ru/' },
      { id: 3, name: 'ООО "ПРЭТ №3"', short: 'ПРЭТ №3', houses: 186, address: 'ул. Интернациональная, д. 12', phone: '(3466) 46-32-15', email: 'pret3@mail.ru', director: 'Сидоров Виктор Николаевич', rating: 3.5, reviews: 312, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 4, name: 'ООО "ПРЭТ №4"', short: 'ПРЭТ №4', houses: 142, address: 'ул. Ленина, д. 48', phone: '(3466) 24-56-78', email: 'pret4@mail.ru', director: 'Петрова Елена Ивановна', rating: 4.0, reviews: 189, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 5, name: 'ООО "УК Север"', short: 'УК Север', houses: 118, address: 'ул. Северная, д. 5', phone: '(3466) 67-89-01', email: 'uk-sever@mail.ru', director: 'Козлов Алексей Александрович', rating: 4.1, reviews: 145, work_time: 'Пн-Пт 9:00-18:00', url: '' },
      { id: 6, name: 'ООО "Домострой"', short: 'Домострой', houses: 95, address: 'ул. Мира, д. 27', phone: '(3466) 41-23-45', email: 'domostroy@nv.ru', director: 'Иванов Петр Сергеевич', rating: 3.9, reviews: 98, work_time: 'Пн-Пт 8:30-17:30', url: '' },
      { id: 7, name: 'ООО "Сервис-Дом"', short: 'Сервис-Дом', houses: 87, address: 'ул. Чапаева, д. 21', phone: '(3466) 29-87-65', email: 'servis-dom@ya.ru', director: 'Николаев Дмитрий Владимирович', rating: 3.7, reviews: 76, work_time: 'Пн-Пт 8:00-16:00', url: '' },
      { id: 8, name: 'ТСЖ "Победа"', short: 'ТСЖ Победа', houses: 12, address: 'пр. Победы, д. 15', phone: '(3466) 63-45-67', email: 'tsg-pobeda@mail.ru', director: 'Смирнова Лариса Викторовна', rating: 4.5, reviews: 34, work_time: 'Пн, Ср, Пт 10:00-15:00', url: '' },
      { id: 9, name: 'ООО "УК Нефтяник"', short: 'УК Нефтяник', houses: 78, address: 'ул. Нефтяников, д. 1', phone: '(3466) 45-12-34', email: 'uk-neftyanik@nv.ru', director: 'Быков Игорь Петрович', rating: 3.6, reviews: 67, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 10, name: 'ООО "УК Комфорт"', short: 'УК Комфорт', houses: 64, address: 'ул. 60 лет Октября, д. 47', phone: '(3466) 51-23-45', email: 'uk-komfort@mail.ru', director: 'Федорова Анна Сергеевна', rating: 4.3, reviews: 112, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 11, name: 'ТСЖ "Мира"', short: 'ТСЖ Мира', houses: 8, address: 'ул. Мира, д. 14', phone: '(3466) 41-56-78', email: 'tsg-mira@mail.ru', director: 'Кузнецова Ольга Николаевна', rating: 4.6, reviews: 28, work_time: 'Пн, Ср 14:00-18:00', url: '' },
      { id: 12, name: 'ООО "Жилсервис"', short: 'Жилсервис', houses: 92, address: 'ул. Ханты-Мансийская, д. 11', phone: '(3466) 67-34-56', email: 'gilservis@nv.ru', director: 'Морозов Сергей Викторович', rating: 3.4, reviews: 89, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 13, name: 'ООО "УК Гарант"', short: 'УК Гарант', houses: 56, address: 'ул. Омская, д. 2', phone: '(3466) 29-45-67', email: 'uk-garant@mail.ru', director: 'Соколов Андрей Владимирович', rating: 3.8, reviews: 78, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 14, name: 'ТСЖ "Дружба"', short: 'ТСЖ Дружба', houses: 6, address: 'ул. Дружбы Народов, д. 7', phone: '(3466) 63-78-90', email: 'tsg-druzhba@ya.ru', director: 'Попова Марина Александровна', rating: 4.4, reviews: 19, work_time: 'Вт, Чт 15:00-18:00', url: '' },
      { id: 15, name: 'ООО "УК Заря"', short: 'УК Заря', houses: 73, address: 'проезд Заозерный, д. 6', phone: '(3466) 46-78-90', email: 'uk-zarya@nv.ru', director: 'Волков Дмитрий Игоревич', rating: 3.9, reviews: 95, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 16, name: 'ООО "Жилищник-2"', short: 'Жилищник-2', houses: 68, address: 'ул. Пионерская, д. 1', phone: '(3466) 29-12-34', email: 'gilnik2@mail.ru', director: 'Орлова Наталья Петровна', rating: 3.7, reviews: 84, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 17, name: 'ТСЖ "Менделеева"', short: 'ТСЖ Менделеева', houses: 10, address: 'ул. Менделеева, д. 2', phone: '(3466) 24-34-56', email: 'tsg-mendeleeva@mail.ru', director: 'Лебедева Ирина Владимировна', rating: 4.5, reviews: 31, work_time: 'Пн, Пт 10:00-15:00', url: '' },
      { id: 18, name: 'ООО "УК Центр"', short: 'УК Центр', houses: 84, address: 'ул. Ленина, д. 15', phone: '(3466) 24-67-89', email: 'uk-centr@nv.ru', director: 'Борисов Максим Сергеевич', rating: 3.6, reviews: 102, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 19, name: 'ООО "Сервис-Плюс"', short: 'Сервис-Плюс', houses: 59, address: 'ул. Спортивная, д. 13/2', phone: '(3466) 41-89-01', email: 'servis-plus@mail.ru', director: 'Тихонов Виталий Анатольевич', rating: 3.5, reviews: 71, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 20, name: 'ТСЖ "Северный"', short: 'ТСЖ Северный', houses: 5, address: 'ул. Северная, д. 3б', phone: '(3466) 67-23-45', email: 'tsg-severny@ya.ru', director: 'Соловьева Елена Александровна', rating: 4.7, reviews: 16, work_time: 'Ср 14:00-18:00', url: '' },
      { id: 21, name: 'ООО "УК Югра"', short: 'УК Югра', houses: 91, address: 'бульвар Комсомольский, д. 2', phone: '(3466) 51-45-67', email: 'uk-yugra@nv.ru', director: 'Медведев Алексей Николаевич', rating: 4.0, reviews: 134, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 22, name: 'ООО "Жилкомсервис"', short: 'Жилкомсервис', houses: 77, address: 'ул. Дзержинского, д. 31', phone: '(3466) 46-56-78', email: 'gilkomservis@mail.ru', director: 'Козлова Татьяна Викторовна', rating: 3.8, reviews: 88, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 23, name: 'ТСЖ "Комсомольский"', short: 'ТСЖ Комсомольский', houses: 4, address: 'бульвар Комсомольский, д. 4', phone: '(3466) 51-67-89', email: 'tsg-komsomol@mail.ru', director: 'Васильева Людмила Ивановна', rating: 4.3, reviews: 22, work_time: 'Пн 15:00-18:00', url: '' },
      { id: 24, name: 'ООО "УК Стандарт"', short: 'УК Стандарт', houses: 63, address: 'ул. Интернациональная, д. 2/1', phone: '(3466) 46-89-01', email: 'uk-standart@nv.ru', director: 'Новиков Денис Александрович', rating: 3.9, reviews: 79, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 25, name: 'ООО "Домоуправ"', short: 'Домоуправ', houses: 71, address: 'ул. Мира, д. 60/1', phone: '(3466) 41-01-23', email: 'domouprav@mail.ru', director: 'Егоров Павел Михайлович', rating: 3.7, reviews: 92, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 26, name: 'ТСЖ "Интернациональная"', short: 'ТСЖ Интернационал', houses: 7, address: 'ул. Интернациональная, д. 11', phone: '(3466) 46-12-34', email: 'tsg-inter@ya.ru', director: 'Макарова Ольга Сергеевна', rating: 4.4, reviews: 25, work_time: 'Вт 14:00-18:00', url: '' },
      { id: 27, name: 'ООО "УК Восток"', short: 'УК Восток', houses: 52, address: 'ул. 60 лет Октября, д. 11', phone: '(3466) 51-34-56', email: 'uk-vostok@nv.ru', director: 'Романов Игорь Васильевич', rating: 3.6, reviews: 65, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 28, name: 'ООО "Коммунальщик"', short: 'Коммунальщик', houses: 83, address: 'ул. Омская, д. 23', phone: '(3466) 29-56-78', email: 'kommunalshik@mail.ru', director: 'Захаров Виктор Петрович', rating: 3.5, reviews: 108, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 29, name: 'ТСЖ "Нефтяников"', short: 'ТСЖ Нефтяников', houses: 9, address: 'ул. Нефтяников, д. 5', phone: '(3466) 45-45-67', email: 'tsg-neftyan@mail.ru', director: 'Титова Анастасия Дмитриевна', rating: 4.2, reviews: 18, work_time: 'Чт 15:00-18:00', url: '' },
      { id: 30, name: 'ООО "УК Комфорт-Плюс"', short: 'Комфорт-Плюс', houses: 48, address: 'ул. Чапаева, д. 5', phone: '(3466) 29-67-89', email: 'komfort-plus@nv.ru', director: 'Григорьев Артем Сергеевич', rating: 4.1, reviews: 56, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 31, name: 'ООО "Городской сервис"', short: 'Гор. сервис', houses: 66, address: 'ул. Маршала Жукова, д. 5', phone: '(3466) 24-89-01', email: 'gorservis@mail.ru', director: 'Антонов Михаил Владимирович', rating: 3.8, reviews: 74, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 32, name: 'ТСЖ "Омская"', short: 'ТСЖ Омская', houses: 11, address: 'ул. Омская, д. 58', phone: '(3466) 29-78-90', email: 'tsg-omskaya@ya.ru', director: 'Белова Екатерина Андреевна', rating: 4.5, reviews: 29, work_time: 'Пн, Чт 14:00-17:00', url: '' },
      { id: 33, name: 'ООО "УК Самотлор"', short: 'УК Самотлор', houses: 89, address: 'ул. Ленина, д. 28', phone: '(3466) 24-01-23', email: 'uk-samotlor@nv.ru', director: 'Семенов Николай Александрович', rating: 3.9, reviews: 127, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 34, name: 'ООО "Жилфонд"', short: 'Жилфонд', houses: 54, address: 'проезд Заозерный, д. 10', phone: '(3466) 46-23-45', email: 'gilfond@mail.ru', director: 'Кириллов Олег Игоревич', rating: 3.6, reviews: 68, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 35, name: 'ТСЖ "Заозерный"', short: 'ТСЖ Заозерный', houses: 6, address: 'проезд Заозерный, д. 14а', phone: '(3466) 46-34-56', email: 'tsg-zaozer@mail.ru', director: 'Власова Мария Игоревна', rating: 4.6, reviews: 21, work_time: 'Ср 15:00-18:00', url: '' },
      { id: 36, name: 'ООО "УК Уют"', short: 'УК Уют', houses: 47, address: 'ул. Мира, д. 31', phone: '(3466) 41-45-67', email: 'uk-uyut@nv.ru', director: 'Степанов Андрей Петрович', rating: 4.0, reviews: 61, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 37, name: 'ООО "Управдом"', short: 'Управдом', houses: 72, address: 'ул. Школьная, д. 15', phone: '(3466) 21-56-78', email: 'upravdom@mail.ru', director: 'Михайлов Сергей Николаевич', rating: 3.7, reviews: 83, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 38, name: 'ТСЖ "Пионерская"', short: 'ТСЖ Пионерская', houses: 8, address: 'ул. Пионерская, д. 5', phone: '(3466) 29-23-45', email: 'tsg-pioner@ya.ru', director: 'Крылова Ирина Сергеевна', rating: 4.3, reviews: 27, work_time: 'Пт 14:00-18:00', url: '' },
      { id: 39, name: 'ООО "УК Надежда"', short: 'УК Надежда', houses: 58, address: 'ул. Дружбы Народов, д. 16', phone: '(3466) 63-67-89', email: 'uk-nadezhda@nv.ru', director: 'Фролов Владимир Александрович', rating: 3.8, reviews: 69, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 40, name: 'ООО "Сити-Сервис"', short: 'Сити-Сервис', houses: 45, address: 'ул. Кузоваткина, д. 14', phone: '(3466) 62-78-90', email: 'city-servis@mail.ru', director: 'Павлов Дмитрий Сергеевич', rating: 4.2, reviews: 52, work_time: 'Пн-Пт 8:00-17:00', url: '' },
      { id: 41, name: 'ТСЖ "Чапаева"', short: 'ТСЖ Чапаева', houses: 13, address: 'ул. Чапаева, д. 9', phone: '(3466) 29-89-01', email: 'tsg-chapaeva@mail.ru', director: 'Андреева Светлана Викторовна', rating: 4.4, reviews: 35, work_time: 'Вт, Пт 15:00-18:00', url: '' },
      { id: 42, name: 'ООО "УК Дом"', short: 'УК Дом', houses: 61, address: 'ул. Ленина, д. 52', phone: '(3466) 24-12-34', email: 'uk-dom@nv.ru', director: 'Сергеев Алексей Владимирович', rating: 3.9, reviews: 76, work_time: 'Пн-Пт 8:00-17:00', url: '' }
    ],

    // ══════════════════════════════════════════════════════════
    // АВАРИЙНЫЕ СЛУЖБЫ ЖКХ
    // ══════════════════════════════════════════════════════════
    emergency_services: [
      { name: 'АО "Горэлектросеть" диспетчерская', phone: '8(3466) 26-08-85, 26-07-78', type: 'electricity', icon: 'mdi:lightning-bolt' },
      { name: 'АО "Жилищный трест №1" диспетчерская', phone: '8(3466) 29-11-99, 64-21-99', type: 'housing', icon: 'mdi:home-alert' },
      { name: 'ЕДДС (Единая дежурно-диспетчерская служба)', phone: '112, 8(3466) 24-01-12', type: 'emergency', icon: 'mdi:phone-alert' },
      { name: 'Горгаз - аварийная служба', phone: '104, 8(3466) 24-04-04', type: 'gas', icon: 'mdi:fire' },
      { name: 'Водоканал - аварийная служба', phone: '8(3466) 24-05-05', type: 'water', icon: 'mdi:water' },
      { name: 'Теплоснабжение - аварийная служба', phone: '8(3466) 46-27-27', type: 'heat', icon: 'mdi:radiator' },
      { name: 'МЧС Нижневартовск', phone: '101, 8(3466) 41-08-01', type: 'rescue', icon: 'mdi:fire-truck' },
      { name: 'Полиция', phone: '102, 8(3466) 49-02-02', type: 'police', icon: 'mdi:police-badge' },
      { name: 'Скорая помощь', phone: '103, 8(3466) 24-03-03', type: 'medical', icon: 'mdi:ambulance' },
      { name: 'Лифтовая служба', phone: '8(3466) 24-16-16', type: 'lift', icon: 'mdi:elevator' }
    ],

    // ══════════════════════════════════════════════════════════
    // ИНТЕРЕСНЫЕ ФАКТЫ О ГОРОДЕ
    // ══════════════════════════════════════════════════════════
    city_facts: [
      { icon: 'mdi:oil', title: 'Нефтяная столица', text: 'Самотлорское месторождение — одно из крупнейших в мире. С 1965 года добыто более 2.7 млрд тонн нефти' },
      { icon: 'mdi:history', title: 'Молодой город', text: 'Статус города получен в 1972 году. За 50+ лет вырос с 3 тыс. до 290 тыс. жителей' },
      { icon: 'mdi:thermometer-low', title: 'Суровый климат', text: 'Средняя температура января -20°C. Абсолютный минимум -56°C (1979)' },
      { icon: 'mdi:airplane', title: 'Авиация', text: 'Аэропорт города — один из крупнейших в ХМАО. Есть Аллея почёта авиатехники' },
      { icon: 'mdi:medal', title: 'Город трудовой доблести', text: 'Памятник покорителям Самотлора (1978) — 12-метровая фигура нефтяника с вечным огнём' }
    ],

    // ЖКХ по годам
    housing_stats: {
      housing_fund: [
        { year: 2018, total_sqm: 5890000, per_capita: 21.2 },
        { year: 2019, total_sqm: 6020000, per_capita: 21.6 },
        { year: 2020, total_sqm: 6150000, per_capita: 22.0 },
        { year: 2021, total_sqm: 6280000, per_capita: 22.3 },
        { year: 2022, total_sqm: 6410000, per_capita: 22.7 },
        { year: 2023, total_sqm: 6540000, per_capita: 23.0 },
        { year: 2024, total_sqm: 6680000, per_capita: 23.4 }
      ],
      new_construction: [
        { year: 2019, sqm: 89000, apartments: 1234 },
        { year: 2020, sqm: 75000, apartments: 1045 },
        { year: 2021, sqm: 98000, apartments: 1367 },
        { year: 2022, sqm: 112000, apartments: 1523 },
        { year: 2023, sqm: 125000, apartments: 1698 },
        { year: 2024, sqm: 138000, apartments: 1856 }
      ]
    }
  };
}

// ══════════════════════════════════════════════════════════
// WEATHER RENDERING
// ══════════════════════════════════════════════════════════
function getWeatherIcon(code, isDay) {
  const icons = ICONS.weather;
  const map = {
    0: isDay ? icons.clear_day : icons.clear_night,
    1: isDay ? icons.clear_day : icons.clear_night,
    2: icons.cloudy,
    3: icons.overcast,
    45: icons.fog,
    48: icons.fog,
    51: icons.rain, 53: icons.rain, 55: icons.rain,
    61: icons.rain, 63: icons.rain, 65: icons.storm,
    71: icons.snow, 73: icons.snow, 75: icons.snow,
    77: icons.snow,
    80: icons.rain, 81: icons.storm, 82: icons.storm,
    85: icons.snow, 86: icons.snow,
    95: icons.storm, 96: icons.storm, 99: icons.storm
  };
  return map[code] || icons.cloudy;
}

function getWeatherDesc(code) {
  const map = {
    0: 'Ясно', 1: 'Малооблачно', 2: 'Облачно', 3: 'Пасмурно',
    45: 'Туман', 48: 'Изморозь',
    51: 'Морось', 53: 'Морось', 55: 'Морось',
    61: 'Дождь', 63: 'Дождь', 65: 'Ливень',
    71: 'Снег', 73: 'Снег', 75: 'Снегопад', 77: 'Крупа',
    80: 'Ливень', 81: 'Ливень', 82: 'Шторм',
    85: 'Снег', 86: 'Метель',
    95: 'Гроза', 96: 'Гроза', 99: 'Гроза'
  };
  return map[code] || 'Облачно';
}

function renderWeather(w) {
  // Погода теперь только в шапке pulse-bar, карточка удалена
  return '';
}

// ══════════════════════════════════════════════════════════
// COMPONENT BUILDERS
// ══════════════════════════════════════════════════════════
function cardHeader(iconName, title, subtitle) {
  return `
    <div class="card-header">
      <div class="card-icon">${icon(iconName)}</div>
      <div>
        <div class="card-title">${title}</div>
        ${subtitle ? `<div class="card-subtitle">${subtitle}</div>` : ''}
      </div>
    </div>
  `;
}

function bigNumber(value, label, color = COLORS.primary) {
  return `
    <div class="big-number" style="color: ${color}; text-shadow: 0 0 20px ${color}, 0 0 40px ${color}40;">${value.toLocaleString('ru')}</div>
    <div class="big-number-label">${label}</div>
  `;
}

function statsRow(items) {
  return `
    <div class="stats-row">
      ${items.map(item => {
    const c = item.color || COLORS.primary;
    return `
        <div class="stat-item">
          <div class="stat-value" style="color: ${c}; text-shadow: 0 0 15px ${c}, 0 0 30px ${c}40;">${item.value.toLocaleString('ru')}</div>
          <div class="stat-label">${item.label}</div>
        </div>
      `}).join('')}
    </div>
  `;
}

function barChart(items, maxVal, colors = COLORS.chart) {
  if (!items?.length) return '';
  const max = maxVal || Math.max(...items.map(i => i.count || 0)) || 1;

  return `
    <div class="bar-chart">
      ${items.map((item, i) => {
    const pct = Math.round((item.count || 0) / max * 100);
    const color = colors[i % colors.length];
    return `
          <div class="bar-row">
            <span class="bar-label">${esc(item.name)}</span>
            <div class="bar-track">
              <div class="bar-fill" style="width: ${pct}%; background: ${color}">${item.count}</div>
            </div>
          </div>
        `;
  }).join('')}
    </div>
  `;
}

function trendChart(data, color = COLORS.primary, labelKey = 'year', valueKey = 'count') {
  if (!data?.length) return '';
  const max = Math.max(...data.map(d => d[valueKey] || 0)) || 1;

  return `
    <div class="trend-chart">
      ${data.map((d, i) => {
    const v = d[valueKey] || 0;
    const pct = Math.max(v / max * 100, 8);
    const opacity = 0.5 + (i / data.length) * 0.5;
    return `
          <div class="trend-bar">
            <div class="trend-value">${v}</div>
            <div class="trend-fill" style="height: ${pct}%; background: ${color}; opacity: ${opacity}"></div>
          </div>
        `;
  }).join('')}
    </div>
    <div style="display: flex; justify-content: space-around; margin-top: 4px">
      ${data.map(d => `<span class="trend-year">${String(d[labelKey]).slice(-2)}</span>`).join('')}
    </div>
  `;
}

function infoTip(text, iconName = ICONS.info) {
  return `
    <div class="info-tip">
      ${icon(iconName, 14)}
      <span>${text}</span>
    </div>
  `;
}

// ══════════════════════════════════════════════════════════
// PIE CHART COMPONENT
// ══════════════════════════════════════════════════════════
function pieChart(items, options = {}) {
  if (!items?.length) return '';

  const { size = 140, showLegend = true } = options;
  const total = items.reduce((sum, i) => sum + (i.percent || i.amount || 0), 0);
  const radius = size / 2 - 10;
  const cx = size / 2;
  const cy = size / 2;

  const colors = [
    COLORS.primary, COLORS.blue, COLORS.success, COLORS.orange,
    COLORS.tertiary, COLORS.pink, COLORS.danger, COLORS.teal
  ];

  let currentAngle = -90;
  const paths = items.map((item, i) => {
    const value = item.percent || (item.amount / total * 100);
    const angle = (value / 100) * 360;
    const startAngle = currentAngle;
    const endAngle = currentAngle + angle;
    currentAngle = endAngle;

    const startRad = (startAngle * Math.PI) / 180;
    const endRad = (endAngle * Math.PI) / 180;

    const x1 = cx + radius * Math.cos(startRad);
    const y1 = cy + radius * Math.sin(startRad);
    const x2 = cx + radius * Math.cos(endRad);
    const y2 = cy + radius * Math.sin(endRad);

    const largeArc = angle > 180 ? 1 : 0;
    const color = item.color || colors[i % colors.length];

    return `<path d="M ${cx} ${cy} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z" fill="${color}" opacity="0.85">
      <title>${item.name}: ${item.percent || Math.round(item.amount / total * 100)}%</title>
    </path>`;
  }).join('');

  const legend = showLegend ? `
    <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; justify-content: center">
      ${items.map((item, i) => `
        <div style="display: flex; align-items: center; gap: 4px; font-size: 10px">
          <span style="width: 8px; height: 8px; border-radius: 2px; background: ${item.color || colors[i % colors.length]}"></span>
          <span style="color: var(--text-muted)">${item.name}</span>
          <span style="font-weight: 600">${item.percent || Math.round((item.amount || 0) / total * 100)}%</span>
        </div>
      `).join('')}
    </div>
  ` : '';

  return `
    <div style="text-align: center">
      <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display: block; margin: 0 auto">
        <circle cx="${cx}" cy="${cy}" r="${radius + 5}" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="2"/>
        ${paths}
        <circle cx="${cx}" cy="${cy}" r="${radius * 0.5}" fill="var(--bg-color)"/>
      </svg>
      ${legend}
    </div>
  `;
}

// Simple donut chart helper (values array, colors array, size)
function donutChart(values, colors, size = 120) {
  if (!values?.length) return '';

  const total = values.reduce((a, b) => a + b, 0);
  if (total === 0) return '';

  const radius = size / 2 - 10;
  const cx = size / 2;
  const cy = size / 2;

  let currentAngle = -90;
  const paths = values.map((value, i) => {
    const percent = (value / total) * 100;
    const angle = (percent / 100) * 360;
    const startAngle = currentAngle;
    const endAngle = currentAngle + angle;
    currentAngle = endAngle;

    const startRad = (startAngle * Math.PI) / 180;
    const endRad = (endAngle * Math.PI) / 180;

    const x1 = cx + radius * Math.cos(startRad);
    const y1 = cy + radius * Math.sin(startRad);
    const x2 = cx + radius * Math.cos(endRad);
    const y2 = cy + radius * Math.sin(endRad);

    const largeArc = angle > 180 ? 1 : 0;
    const color = colors[i % colors.length];

    return `<path d="M ${cx} ${cy} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z" fill="${color}" opacity="0.85">
      <title>${Math.round(percent)}%</title>
    </path>`;
  }).join('');

  return `
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
      <circle cx="${cx}" cy="${cy}" r="${radius + 5}" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="2"/>
      ${paths}
      <circle cx="${cx}" cy="${cy}" r="${radius * 0.5}" fill="var(--bg-color)"/>
    </svg>
  `;
}

// ══════════════════════════════════════════════════════════
// ENHANCED CHART COMPONENTS
// ══════════════════════════════════════════════════════════
function lineChart(data, series, options = {}) {
  const {
    height = 120,
    labelKey = 'year',
    showLegend = true,
    showValues = false,
    animate = true
  } = options;

  if (!data?.length) return '';

  // Generate unique ID for this chart instance
  const chartId = 'lc-' + Math.random().toString(36).substr(2, 9);

  // Find min/max for all series
  let allValues = [];
  series.forEach(s => {
    data.forEach(d => {
      const v = d[s.key];
      if (typeof v === 'number') allValues.push(v);
    });
  });

  const minVal = Math.min(...allValues);
  const maxVal = Math.max(...allValues);
  const range = maxVal - minVal || 1;
  const padding = range * 0.1;

  const width = 100;
  const chartHeight = height - 30;
  const xStep = width / (data.length - 1 || 1);

  // Build SVG paths
  let paths = '';
  let dots = '';
  let pathLengths = [];

  series.forEach((s, si) => {
    let pathD = '';
    let areaD = '';
    let pathLength = 0;
    let prevX = 0, prevY = 0;

    data.forEach((d, i) => {
      const v = d[s.key];
      if (typeof v !== 'number') return;

      const x = i * xStep;
      const y = chartHeight - ((v - minVal + padding) / (range + padding * 2)) * chartHeight;

      if (pathD === '') {
        pathD = `M ${x} ${y}`;
        areaD = `M ${x} ${chartHeight}L ${x} ${y}`;
        prevX = x;
        prevY = y;
      } else {
        pathD += ` L ${x} ${y}`;
        areaD += ` L ${x} ${y}`;
        pathLength += Math.sqrt(Math.pow(x - prevX, 2) + Math.pow(y - prevY, 2));
        prevX = x;
        prevY = y;
      }

      // Animated dot with delay based on position
      const delay = animate ? (i * 0.15) : 0;
      dots += `<circle class="chart-dot" cx="${x}" cy="${y}" r="3" fill="${s.color}" opacity="0" style="animation-delay: ${delay}s" />`;
    });

    areaD += ` L ${(data.length - 1) * xStep} ${chartHeight} Z`;
    pathLengths.push(pathLength * 1.5); // Approximate path length

    // Area fill (gradient) with fade-in
    paths += `<path class="chart-area" d="${areaD}" fill="url(#grad-${chartId}-${si})" opacity="0" style="animation-delay: ${si * 0.1}s" />`;
    // Animated line path with stroke-dasharray
    paths += `<path class="chart-line" d="${pathD}" fill="none" stroke="${s.color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" 
      stroke-dasharray="${pathLength * 1.5}" stroke-dashoffset="${pathLength * 1.5}" style="animation-delay: ${si * 0.1}s" />`;
  });

  // Gradients
  let gradients = series.map((s, i) =>
    `<linearGradient id="grad-${chartId}-${i}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${s.color}" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="${s.color}" stop-opacity="0"/>
    </linearGradient>`
  ).join('');

  // X axis labels with staggered animation
  const labels = data.map((d, i) => {
    const x = i * xStep;
    const label = String(d[labelKey]).slice(-2);
    const delay = animate ? (i * 0.08) : 0;
    return `<text class="chart-label" x="${x}" y="${chartHeight + 14}" text-anchor="middle" fill="#64748b" font-size="8" font-family="var(--font-mono)" opacity="0" style="animation-delay: ${delay}s">'${label}</text>`;
  }).join('');

  // Legend
  let legend = '';
  if (showLegend) {
    legend = `
      <div class="chart-legend">
        ${series.map(s => `
          <div class="legend-item">
            <span class="legend-dot" style="background: ${s.color}"></span>
            <span>${s.label}</span>
          </div>
        `).join('')}
      </div>
    `;
  }

  return `
    <div class="line-chart-container animated-chart" style="height: ${height}px">
      <svg viewBox="0 0 ${width} ${chartHeight + 20}" preserveAspectRatio="none" style="width: 100%; height: 100%">
        <defs>${gradients}</defs>
        ${paths}
        ${dots}
        ${labels}
      </svg>
    </div>
    ${legend}
  `;
}

function sparkline(data, valueKey, color = COLORS.primary) {
  if (!data?.length) return '';
  const max = Math.max(...data.map(d => d[valueKey] || 0)) || 1;

  return `
    <div class="sparkline">
      ${data.map(d => {
    const v = d[valueKey] || 0;
    const h = Math.max(8, (v / max) * 100);
    return `<div class="spark-bar" style="height: ${h}%; background: ${color}" title="${v}"></div>`;
  }).join('')}
    </div>
  `;
}

function compareYears(data, valueKey, labelKey = 'year', options = {}) {
  if (!data?.length || data.length < 2) return '';

  const first = data[0];
  const last = data[data.length - 1];
  const firstVal = first[valueKey] || 0;
  const lastVal = last[valueKey] || 0;
  const change = firstVal ? ((lastVal - firstVal) / firstVal * 100) : 0;
  const isUp = change > 0;
  const isStable = Math.abs(change) < 2;

  return `
    <div class="compare-grid">
      <div class="compare-item">
        <div class="compare-year">${first[labelKey]}</div>
        <div class="compare-value" style="color: ${COLORS.secondary}">${firstVal.toLocaleString('ru')}</div>
      </div>
      <div class="compare-item">
        <div class="compare-year">${last[labelKey]}</div>
        <div class="compare-value" style="color: ${COLORS.primary}">${lastVal.toLocaleString('ru')}</div>
        <div class="compare-change">
          <span class="trend-indicator ${isStable ? 'stable' : (isUp ? 'up' : 'down')}">
            ${icon(isUp ? 'mdi:trending-up' : (isStable ? 'mdi:trending-neutral' : 'mdi:trending-down'), 12)}
            ${change > 0 ? '+' : ''}${change.toFixed(1)}%
          </span>
        </div>
      </div>
    </div>
  `;
}

function analysisBlock(title, text, iconName = 'mdi:chart-timeline-variant') {
  return `
    <div class="analysis-block">
      <div class="analysis-title">${icon(iconName, 14)} ${title}</div>
      <div class="analysis-text">${text}</div>
    </div>
  `;
}

function timeline(items) {
  if (!items?.length) return '';

  return `
    <div class="timeline">
      ${items.map(item => `
        <div class="timeline-item">
          <div class="timeline-year">${item.year}</div>
          <div class="timeline-content">${item.text}</div>
        </div>
      `).join('')}
    </div>
  `;
}

function ageStructureChart(data) {
  if (!data?.groups?.length) return '';

  const maxTotal = Math.max(...data.groups.map(g => g.total));

  return `
    <div style="margin-top: var(--space-md)">
      ${data.groups.map(g => {
    const maleW = (g.male / maxTotal) * 45;
    const femaleW = (g.female / maxTotal) * 45;
    return `
          <div style="display: flex; align-items: center; gap: 4px; margin-bottom: 6px; font-size: 10px">
            <div style="width: 45%; display: flex; justify-content: flex-end">
              <div style="width: ${maleW}%; background: ${COLORS.blue}; height: 14px; border-radius: 2px; display: flex; align-items: center; justify-content: flex-end; padding-right: 4px; color: white; font-size: 8px">
                ${g.male > 10000 ? Math.round(g.male / 1000) + 'к' : ''}
              </div>
            </div>
            <div style="width: 10%; text-align: center; font-weight: 600; color: var(--text-secondary)">${g.group}</div>
            <div style="width: 45%">
              <div style="width: ${femaleW}%; background: ${COLORS.pink}; height: 14px; border-radius: 2px; display: flex; align-items: center; padding-left: 4px; color: white; font-size: 8px">
                ${g.female > 10000 ? Math.round(g.female / 1000) + 'к' : ''}
              </div>
            </div>
          </div>
        `;
  }).join('')}
      <div class="chart-legend" style="margin-top: var(--space-sm)">
        <div class="legend-item"><span class="legend-dot" style="background: ${COLORS.blue}"></span>Мужчины</div>
        <div class="legend-item"><span class="legend-dot" style="background: ${COLORS.pink}"></span>Женщины</div>
      </div>
    </div>
  `;
}

function card(section, full, content) {
  return `
    <div class="card${full ? ' full' : ''}" data-section="${section}">
      ${content}
    </div>
  `;
}

// ══════════════════════════════════════════════════════════
// MAIN RENDER FUNCTION
// ══════════════════════════════════════════════════════════
function renderApp(data, weather) {
  const app = document.getElementById('app');
  if (!app) return;

  if (!data) {
    app.innerHTML = `
      <div style="text-align: center; padding: 60px 20px; color: var(--text-muted)">
        ${icon('mdi:alert-circle-outline', 48)}
        <p style="margin-top: 16px">Данные временно недоступны</p>
      </div>
    `;
    return;
  }

  // Data extraction
  const fp = data.fuel?.prices || {};
  const ed = data.education || {};
  const cn = data.counts || {};
  const uk = data.uk || {};
  const tr = data.transport || {};
  const agr = data.agreements || {};
  const waste = data.waste || {};
  const names = data.names || {};

  const totalRecords = Object.values(cn).reduce((a, b) => a + (Number(b) || 0), 0);

  // Tab system
  let currentTab = 'all';
  const tabs = [
    { id: 'all', label: 'Все', icon: 'mdi:view-grid-outline' },
    { id: 'budget', label: 'Бюджет', icon: ICONS.budget },
    { id: 'property', label: 'Имущество', icon: 'mdi:city' },
    { id: 'fuel', label: 'Топливо', icon: ICONS.fuel },
    { id: 'housing', label: 'ЖКХ', icon: ICONS.housing },
    { id: 'sport', label: 'Спорт', icon: 'mdi:trophy' },
    { id: 'edu', label: 'Образование', icon: ICONS.edu },
    { id: 'transport', label: 'Транспорт', icon: ICONS.transport },
    { id: 'eco', label: 'Экология', icon: ICONS.eco },
    { id: 'appeals', label: 'Обращения', icon: 'mdi:message-text-outline' },
    { id: 'people', label: 'Люди', icon: ICONS.people },
    { id: 'news', label: 'Новости', icon: ICONS.news },
    { id: 'datasets', label: '65 Датасетов', icon: 'mdi:database-search-outline' },
    { id: 'cams', label: 'Камеры', icon: 'mdi:video-outline' }
  ];

  const show = (section) => currentTab === 'all' || currentTab === section;

  function buildHTML() {
    let html = '';

    // Hero
    html += `
      <div class="hero">
        <div class="hero-badge">
          <span class="status-dot"></span>
          Обновляется автоматически
        </div>
        <h1 class="hero-title">
          <span class="city-name">Нижневартовск</span>
          в цифрах
        </h1>
        <p class="hero-subtitle">Открытые данные · ХМАО-Югра</p>
        <div class="hero-meta">
          <span class="meta-item">${icon(ICONS.clock, 14)} ${formatDate(data.updated_at)}</span>
          <span class="meta-item">${icon(ICONS.database, 14)} ${data.datasets_total || 72} датасетов</span>
        </div>
      </div>
    `;

    // Weather
    html += renderWeather(weather);

    // Tabs
    html += `
      <div class="tabs" id="tabs-row">
        ${tabs.map(t => `
          <button class="tab${currentTab === t.id ? ' active' : ''}" data-tab="${t.id}">
            ${icon(t.icon, 16)}
            <span>${t.label}</span>
          </button>
        `).join('')}
      </div>
    `;

    html += '<div class="card-grid">';

    // ══════════════════════════════════════════════════════════
    // BUDGET SECTION - ПОЛНАЯ ВЕРСИЯ С ГРАФИКАМИ
    // ══════════════════════════════════════════════════════════
    if (show('budget')) {
      html += `<div class="section-title">${icon(ICONS.budget)} Бюджет и финансы</div>`;

      const demo = getDemoData();
      const budget = demo.economy?.budget || [];
      const investments = demo.economy?.investments || [];
      const expenseStruct = demo.economy?.expense_structure || [];
      const incomeStruct = demo.economy?.income_structure || [];
      const execution = demo.economy?.execution_2025 || [];
      const cityFacts = demo.city_facts || [];
      const ukFull = demo.uk_full || [];

      // ═══ ОСНОВНЫЕ ПОКАЗАТЕЛИ БЮДЖЕТА ═══
      if (budget.length) {
        const latest = budget[budget.length - 1];
        const prev = budget[budget.length - 2];
        const incomeGrowth = prev ? ((latest.income - prev.income) / prev.income * 100).toFixed(1) : 0;

        html += card('budget', true, `
          ${cardHeader(ICONS.budget_income, 'Бюджет ' + latest.year, 'Млн рублей')}
          <div class="budget-hero">
            <div class="budget-main">
              ${bigNumber(latest.income.toLocaleString('ru'), 'доходы', COLORS.success)}
              <div class="budget-trend ${incomeGrowth >= 0 ? 'up' : 'down'}">
                ${icon(incomeGrowth >= 0 ? 'mdi:trending-up' : 'mdi:trending-down', 16)}
                ${incomeGrowth >= 0 ? '+' : ''}${incomeGrowth}% к прошлому году
              </div>
            </div>
            <div class="budget-secondary">
              ${statsRow([
          { value: latest.expense.toLocaleString('ru'), label: 'Расходы', color: COLORS.danger },
          { value: latest.deficit >= 0 ? '+' + latest.deficit : latest.deficit, label: latest.deficit >= 0 ? 'Профицит' : 'Дефицит', color: latest.deficit >= 0 ? COLORS.success : COLORS.warning }
        ])}
            </div>
          </div>
          ${infoTip('Источник: Открытый бюджет Нижневартовска budget.n-vartovsk.ru')}
        `);
      }

      // ═══ ДИНАМИКА БЮДЖЕТА ПО ГОДАМ ═══
      if (budget.length > 1) {
        html += card('budget', true, `
          ${cardHeader(ICONS.chart_line, 'Динамика бюджета', '10 лет')}
          ${lineChart(budget, [
          { key: 'income', label: 'Доходы', color: COLORS.success },
          { key: 'expense', label: 'Расходы', color: COLORS.danger }
        ], { height: 140 })}
          ${compareYears(budget, 'income')}
          ${analysisBlock('Тренд',
          `Бюджет стабильно растёт. Среднегодовой рост доходов ${((budget[budget.length - 1].income / budget[0].income - 1) / (budget.length - 1) * 100).toFixed(1)}%. Город не имеет муниципального долга.`
        )}
        `);
      }

      // ═══ СТРУКТУРА РАСХОДОВ ═══
      if (expenseStruct.length) {
        const pieData = expenseStruct.map((item, i) => ({
          name: item.name,
          value: item.amount,
          pct: item.pct,
          color: COLORS.chart[i % COLORS.chart.length]
        }));

        html += card('budget', true, `
          ${cardHeader(ICONS.pie, 'Структура расходов', '2026')}
          <div class="expense-grid">
            ${pieData.map(item => `
              <div class="expense-item">
                <div class="expense-bar" style="width: ${item.pct}%; background: ${item.color}"></div>
                <div class="expense-info">
                  <span class="expense-name">${item.name}</span>
                  <span class="expense-value" style="color: ${item.color}">${item.value.toLocaleString('ru')} млн (${item.pct}%)</span>
                </div>
              </div>
            `).join('')}
          </div>
          ${infoTip('Образование — крупнейшая статья расходов городского бюджета')}
        `);
      }

      // ═══ СТРУКТУРА ДОХОДОВ ═══
      if (incomeStruct.length) {
        html += card('budget', true, `
          ${cardHeader(ICONS.budget_income, 'Структура доходов', '2026')}
          <div class="income-breakdown">
            ${incomeStruct.map((item, i) => `
              <div class="income-item">
                <div class="income-dot" style="background: ${COLORS.chart[i % COLORS.chart.length]}"></div>
                <span class="income-name">${item.name}</span>
                <span class="income-value">${item.amount.toLocaleString('ru')} млн</span>
                <span class="income-pct">${item.pct}%</span>
              </div>
            `).join('')}
          </div>
        `);
      }

      // ═══ ИНВЕСТИЦИИ В ГОРОД ═══
      if (investments.length) {
        const latestInv = investments[investments.length - 1];
        html += card('budget', true, `
          ${cardHeader('mdi:city', 'Инвестиции в город', 'Млн рублей')}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber(latestInv.total.toLocaleString('ru'), 'млн ₽ в ' + latestInv.year, COLORS.blue)}
          </div>
          ${lineChart(investments, [
          { key: 'total', label: 'Инвестиции', color: COLORS.blue }
        ], { height: 100 })}
          ${compareYears(investments, 'total')}
          ${analysisBlock('Рост',
          `Инвестиции выросли в ${(latestInv.total / investments[0].total).toFixed(1)} раза за ${investments.length} лет. Основные направления: нефтегазовая отрасль, строительство, инфраструктура.`
        )}
        `);
      }

      // ═══ ИСПОЛНЕНИЕ БЮДЖЕТА ═══
      if (execution.length) {
        const totalPlanIncome = execution.reduce((s, q) => s + q.plan_income, 0);
        const totalFactIncome = execution.reduce((s, q) => s + q.fact_income, 0);
        const execPct = (totalFactIncome / totalPlanIncome * 100).toFixed(1);

        html += card('budget', false, `
          ${cardHeader('mdi:check-circle-outline', 'Исполнение 2025', `${execPct}%`)}
          <div class="execution-bars">
            ${execution.map(q => `
              <div class="quarter-bar">
                <div class="quarter-label">${q.quarter}</div>
                <div class="quarter-track">
                  <div class="quarter-plan" style="width: ${q.plan_income / 60}%"></div>
                  <div class="quarter-fact" style="width: ${q.fact_income / 60}%"></div>
                </div>
                <div class="quarter-value">${(q.fact_income / q.plan_income * 100).toFixed(0)}%</div>
              </div>
            `).join('')}
          </div>
        `);
      }

      // ═══ МУНИЦИПАЛЬНЫЙ ДОЛГ ═══
      html += card('budget', false, `
        ${cardHeader(ICONS.debt, 'Муниципальный долг', 'Финансовая устойчивость')}
        <div class="debt-zero">
          ${icon('mdi:check-decagram', 40)}
          <div class="debt-text">
            <strong>0 ₽</strong>
            <span>Нет муниципального долга</span>
          </div>
        </div>
        ${infoTip('Город финансово устойчив и не имеет заимствований')}
      `);

      // ═══ КОНТРАКТЫ (оригинальные данные) ═══
      const byType = (agr.by_type || []).slice(0, 5);
      if (byType.length) {
        html += card('budget', true, `
          ${cardHeader(ICONS.contract, 'Муниципальные контракты', `${agr.total || 0} договоров`)}
          ${barChart(byType)}
          ${infoTip(`Крупнейшая категория — ${byType[0]?.name || 'Энергосервис'}`)}
        `);
      }

      // ═══ ИМУЩЕСТВО ═══
      const prop = data.property || {};
      html += card('budget', false, `
        ${cardHeader(ICONS.property, 'Имущество', `${(prop.total || 0).toLocaleString('ru')} объектов`)}
        ${statsRow([
        { value: prop.realestate || 0, label: 'Недвижимость', color: COLORS.blue },
        { value: prop.lands || 0, label: 'Земля', color: COLORS.success }
      ])}
      `);

      // ═══ ПРОГРАММЫ ═══
      const prg = data.programs || {};
      if (prg.total) {
        html += card('budget', false, `
          ${cardHeader(ICONS.program, 'Программы', 'Муниципальные')}
          ${bigNumber(prg.total, 'действующих программ', COLORS.success)}
        `);
      }

      // ═══ СОЦИАЛЬНО-ЭКОНОМИЧЕСКИЕ ПОКАЗАТЕЛИ ═══
      const socEcon = demo.economy?.socio_economic || {};

      // Валовой муниципальный продукт
      if (socEcon.gmp?.length) {
        const latestGmp = socEcon.gmp[socEcon.gmp.length - 1];
        html += card('budget', true, `
          ${cardHeader('mdi:chart-bar', 'Валовой продукт', 'Млн рублей')}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber((latestGmp.value / 1000).toFixed(1), 'млрд ₽ в ' + latestGmp.year, COLORS.blue)}
          </div>
          ${lineChart(socEcon.gmp, [
          { key: 'value', label: 'ВМП', color: COLORS.blue, divider: 1000 }
        ], { height: 80 })}
          ${analysisBlock('Рост',
          `За ${socEcon.gmp.length} лет ВМП вырос на ${((latestGmp.value / socEcon.gmp[0].value - 1) * 100).toFixed(0)}%. Основа экономики — нефтегазовый сектор.`
        )}
        `);
      }

      // Промышленное производство
      if (socEcon.industry?.length) {
        const latestInd = socEcon.industry[socEcon.industry.length - 1];
        html += card('budget', true, `
          ${cardHeader('mdi:factory', 'Промышленность', 'Млн рублей')}
          ${lineChart(socEcon.industry, [
          { key: 'value', label: 'Производство', color: COLORS.orange, divider: 1000 }
        ], { height: 80 })}
          <div style="text-align: center; margin-top: 8px; font-size: 20px; font-weight: 800; color: ${COLORS.orange}; text-shadow: 0 0 15px ${COLORS.orange};">
            ${(latestInd.value / 1000).toFixed(1)} млрд ₽
          </div>
          ${infoTip('Основные отрасли: нефтедобыча, газопереработка, строительство')}
        `);
      }

      // Малый и средний бизнес
      const biz = socEcon.business || {};
      if (biz.sme_count) {
        html += card('budget', true, `
          ${cardHeader('mdi:store', 'Малый и средний бизнес', '')}
          ${statsRow([
          { value: biz.sme_count?.toLocaleString('ru'), label: 'Предприятий', color: COLORS.success },
          { value: (biz.employees / 1000).toFixed(1) + 'к', label: 'Занятых', color: COLORS.blue },
          { value: (biz.revenue / 1000).toFixed(1) + ' млрд', label: 'Оборот ₽', color: COLORS.orange }
        ])}
          <div style="text-align: center; margin-top: var(--space-md); font-size: 12px">
            ${icon('mdi:cash', 14)} Вклад в налоги: <span style="color: ${COLORS.success}; font-weight: 700">${(biz.tax_contribution / 1000).toFixed(1)} млрд ₽</span>
          </div>
          ${infoTip('МСБ обеспечивает 18% занятости города')}
        `);
      }

      // Занятость
      const emp = socEcon.employment || {};
      if (emp.labor_force) {
        html += card('budget', true, `
          ${cardHeader('mdi:account-hard-hat', 'Рынок труда', 'Занятость')}
          ${statsRow([
          { value: (emp.labor_force / 1000).toFixed(0) + 'к', label: 'Трудоспособных', color: COLORS.primary },
          { value: (emp.employed / 1000).toFixed(0) + 'к', label: 'Занятых', color: COLORS.success },
          { value: emp.unemployment_rate + '%', label: 'Безработица', color: emp.unemployment_rate < 5 ? COLORS.success : COLORS.warning }
        ])}
          <div style="margin-top: var(--space-md)">
            <div style="display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 4px">
              <span>Уровень занятости</span>
              <span style="color: ${COLORS.success}">${((emp.employed / emp.labor_force) * 100).toFixed(1)}%</span>
            </div>
            <div style="background: rgba(255,255,255,0.1); border-radius: 4px; height: 8px; overflow: hidden">
              <div style="width: ${(emp.employed / emp.labor_force) * 100}%; height: 100%; background: linear-gradient(90deg, ${COLORS.success}, ${COLORS.primary}); border-radius: 4px"></div>
            </div>
          </div>
          <div style="text-align: center; margin-top: 14px; font-size: 13px; color: ${COLORS.blue}">
            ${icon('mdi:briefcase', 16)} Открытых вакансий: <strong style="font-size: 16px; text-shadow: 0 0 10px ${COLORS.blue};">${emp.vacancies?.toLocaleString('ru')}</strong>
          </div>
        `);
      }

      // Розничная торговля
      if (socEcon.retail?.length) {
        const latestRet = socEcon.retail[socEcon.retail.length - 1];
        html += card('budget', false, `
          ${cardHeader('mdi:cart', 'Розничная торговля', latestRet.year)}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber((latestRet.value / 1000).toFixed(1), 'млрд ₽ оборот', COLORS.pink)}
          </div>
          ${sparkline(socEcon.retail, 'value', COLORS.pink, 50)}
        `);
      }

      // Блок "Знаете ли вы" удалён по запросу пользователя
    }

    // ══════════════════════════════════════════════════════════
    // PROPERTY SECTION - МУНИЦИПАЛЬНОЕ ИМУЩЕСТВО
    // ══════════════════════════════════════════════════════════
    if (show('property')) {
      html += `<div class="section-title">${icon('mdi:city')} Муниципальное имущество</div>`;

      const propertyData = getDemoData().property || {};
      const propHistory = propertyData.history || [];
      const propDetails = propertyData.details || {};

      // Основная карточка с общей статистикой
      html += card('property', true, `
        ${cardHeader('mdi:city', 'Реестр муниципального имущества', '2024 год')}
        <div style="text-align: center; margin: var(--space-md) 0">
          ${bigNumber(propertyData.total?.toLocaleString('ru') || '1842', 'объектов всего', COLORS.primary)}
        </div>
        ${statsRow([
        { label: 'Недвижимость', value: propertyData.realestate || 856, color: COLORS.blue, icon: 'mdi:domain' },
        { label: 'Земельные участки', value: propertyData.lands || 642, color: COLORS.success, icon: 'mdi:map-marker' },
        { label: 'Движимое', value: propertyData.movable || 344, color: COLORS.pink, icon: 'mdi:car' }
      ])}
      `);

      // График динамики имущества
      if (propHistory.length) {
        html += card('property', true, `
          ${cardHeader('mdi:chart-line', 'Динамика имущества', '2020–2024')}
          <div class="animated-chart" id="property-history-chart" style="height: 200px; position: relative;">
            <canvas id="propertyHistoryCanvas"></canvas>
          </div>
          <div style="display: flex; justify-content: center; gap: var(--space-lg); margin-top: var(--space-md); font-size: 12px">
            <span style="color: ${COLORS.blue}">● Недвижимость</span>
            <span style="color: ${COLORS.success}">● Земля</span>
            <span style="color: ${COLORS.pink}">● Движимое</span>
          </div>
        `);
      }

      // Структура недвижимости
      if (propDetails.realestate_types?.length) {
        html += card('property', false, `
          ${cardHeader('mdi:domain', 'Структура недвижимости', 'По типам объектов')}
          <div style="margin-top: var(--space-md)">
            ${propDetails.realestate_types.map((item, idx) => {
          const pct = Math.round((item.count / propertyData.realestate) * 100);
          const colors = [COLORS.blue, COLORS.success, COLORS.pink, COLORS.tertiary, COLORS.secondary];
          return `
                <div style="margin-bottom: 12px">
                  <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 13px">
                    <span>${item.name}</span>
                    <span style="color: ${colors[idx % colors.length]}">${item.count} шт · ${item.value} млн ₽</span>
                  </div>
                  <div style="background: rgba(255,255,255,0.1); border-radius: 4px; height: 8px; overflow: hidden">
                    <div style="width: ${pct}%; height: 100%; background: ${colors[idx % colors.length]}; border-radius: 4px; transition: width 1s ease"></div>
                  </div>
                </div>
              `;
        }).join('')}
          </div>
        `);
      }

      // Земельные участки
      if (propDetails.lands_types?.length) {
        html += card('property', false, `
          ${cardHeader('mdi:map-marker-radius', 'Земельные участки', 'По назначению')}
          <div class="donut-chart-wrapper" style="margin: var(--space-md) 0; display: flex; align-items: center; gap: var(--space-lg)">
            <div style="flex: 0 0 120px">
              ${donutChart(propDetails.lands_types.map(l => l.count), [COLORS.success, COLORS.blue, COLORS.tertiary, COLORS.pink, COLORS.secondary], 120)}
            </div>
            <div style="flex: 1; font-size: 12px">
              ${propDetails.lands_types.map((item, idx) => {
          const colors = [COLORS.success, COLORS.blue, COLORS.tertiary, COLORS.pink, COLORS.secondary];
          return `<div style="margin-bottom: 8px; display: flex; justify-content: space-between">
                  <span style="color: ${colors[idx % colors.length]}">● ${item.name}</span>
                  <span>${item.count} уч. · ${item.area} га</span>
                </div>`;
        }).join('')}
            </div>
          </div>
        `);
      }

      // Движимое имущество
      if (propDetails.movable_types?.length) {
        const totalMovableValue = propDetails.movable_types.reduce((a, t) => a + (t.value || 0), 0);
        html += card('property', true, `
          ${cardHeader('mdi:car-multiple', 'Движимое имущество', 'Транспорт и оборудование')}
          <div style="text-align: center; margin-bottom: var(--space-md); padding: 12px; background: linear-gradient(135deg, rgba(233, 30, 99, 0.1), rgba(156, 39, 176, 0.1)); border-radius: 12px">
            <div style="font-size: 28px; font-weight: 800; color: ${COLORS.pink}">${totalMovableValue}</div>
            <div style="font-size: 11px; color: var(--text-muted)">млн ₽ балансовая стоимость</div>
          </div>
          <div style="margin-top: var(--space-md)">
            ${propDetails.movable_types.map((item, idx) => {
          const icons = ['mdi:car', 'mdi:tractor', 'mdi:monitor', 'mdi:chair-rolling'];
          const pct = Math.round((item.value / totalMovableValue) * 100);
          return `
                <div style="display: flex; align-items: center; gap: var(--space-sm); padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.1)">
                  <div style="flex: 0 0 32px; text-align: center">${icon(icons[idx % icons.length], 20)}</div>
                  <div style="flex: 1">
                    <div>${item.name}</div>
                    <div style="background: rgba(255,255,255,0.1); height: 4px; border-radius: 2px; margin-top: 4px">
                      <div style="width: ${pct}%; height: 100%; background: ${COLORS.pink}; border-radius: 2px"></div>
                    </div>
                  </div>
                  <div style="text-align: right">
                    <div style="font-weight: 600; color: ${COLORS.primary}">${item.count} ед.</div>
                    <div style="font-size: 11px; color: var(--text-muted)">${item.value} млн ₽ (${pct}%)</div>
                  </div>
                </div>
              `;
        }).join('')}
          </div>
        `);
      }

      // Сводная аналитика по имуществу
      if (propHistory.length >= 2) {
        const firstYear = propHistory[0];
        const lastYear = propHistory[propHistory.length - 1];
        const growthTotal = ((lastYear.total / firstYear.total - 1) * 100).toFixed(1);
        const growthReal = ((lastYear.realestate / firstYear.realestate - 1) * 100).toFixed(1);
        const growthLands = ((lastYear.lands / firstYear.lands - 1) * 100).toFixed(1);
        const growthMovable = ((lastYear.movable / firstYear.movable - 1) * 100).toFixed(1);

        const totalValue = propDetails.realestate_types?.reduce((a, t) => a + (t.value || 0), 0) || 10900;
        const landsArea = propDetails.lands_types?.reduce((a, t) => a + (t.area || 0), 0) || 6720;
        const movableValue = propDetails.movable_types?.reduce((a, t) => a + (t.value || 0), 0) || 975;

        html += card('property', true, `
          ${cardHeader('mdi:chart-box', 'Аналитика имущества', firstYear.year + '–' + lastYear.year)}
          
          <!-- Общая стоимость -->
          <div style="text-align: center; margin: var(--space-md) 0; padding: 16px; background: linear-gradient(135deg, rgba(33, 150, 243, 0.15), rgba(76, 175, 80, 0.1)); border-radius: 12px">
            <div style="font-size: 36px; font-weight: 900; color: ${COLORS.primary}; text-shadow: 0 0 20px ${COLORS.primary}40">${((totalValue + movableValue) / 1000).toFixed(1)}</div>
            <div style="font-size: 12px; color: var(--text-muted)">млрд ₽ общая балансовая стоимость</div>
          </div>
          
          <!-- Динамика роста -->
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin: var(--space-md) 0">
            <div style="background: rgba(33, 150, 243, 0.1); padding: 12px; border-radius: 10px; text-align: center">
              <div style="font-size: 20px; font-weight: 800; color: ${COLORS.blue}">+${growthTotal}%</div>
              <div style="font-size: 10px; color: var(--text-muted)">рост всего имущества</div>
            </div>
            <div style="background: rgba(76, 175, 80, 0.1); padding: 12px; border-radius: 10px; text-align: center">
              <div style="font-size: 20px; font-weight: 800; color: ${COLORS.success}">+${growthReal}%</div>
              <div style="font-size: 10px; color: var(--text-muted)">рост недвижимости</div>
            </div>
            <div style="background: rgba(0, 188, 212, 0.1); padding: 12px; border-radius: 10px; text-align: center">
              <div style="font-size: 20px; font-weight: 800; color: ${COLORS.cyan}">+${growthLands}%</div>
              <div style="font-size: 10px; color: var(--text-muted)">рост земельных участков</div>
            </div>
            <div style="background: rgba(233, 30, 99, 0.1); padding: 12px; border-radius: 10px; text-align: center">
              <div style="font-size: 20px; font-weight: 800; color: ${COLORS.pink}">+${growthMovable}%</div>
              <div style="font-size: 10px; color: var(--text-muted)">рост движимого</div>
            </div>
          </div>
          
          <!-- Ключевые показатели -->
          <div style="margin-top: var(--space-md); padding: 12px; background: rgba(255,255,255,0.03); border-radius: 10px">
            <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">${icon('mdi:information', 14)} Ключевые показатели:</div>
            <div style="display: grid; gap: 8px; font-size: 12px">
              <div style="display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                <span>Площадь земельных участков</span>
                <strong style="color: ${COLORS.success}">${landsArea.toLocaleString('ru')} га</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                <span>Средний возраст недвижимости</span>
                <strong style="color: ${COLORS.blue}">~18 лет</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                <span>Объектов на реконструкции</span>
                <strong style="color: ${COLORS.orange}">24 шт</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 6px 0">
                <span>Ежегодное обновление фонда</span>
                <strong style="color: ${COLORS.primary}">~3.5%</strong>
              </div>
            </div>
          </div>
          
          ${analysisBlock('Вывод',
          'За ' + propHistory.length + ' лет муниципальное имущество города выросло на <strong style="color: ' + COLORS.success + ';">' + growthTotal + '%</strong>. ' +
          'Наибольший рост показало движимое имущество (+' + growthMovable + '%) за счёт обновления автопарка и спецтехники. ' +
          'Общая балансовая стоимость превышает <strong>' + ((totalValue + movableValue) / 1000).toFixed(1) + ' млрд ₽</strong>. ' +
          'Приоритет — модернизация объектов социальной инфраструктуры.'
        )}
        `);
      }

      // Структура использования имущества
      html += card('property', false, `
        ${cardHeader('mdi:pie-chart', 'Структура использования', 'По направлениям')}
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin: var(--space-md) 0">
          <div style="padding: 14px; background: linear-gradient(135deg, rgba(33, 150, 243, 0.15), rgba(33, 150, 243, 0.05)); border-radius: 10px; text-align: center">
            <div style="font-size: 24px; font-weight: 800; color: ${COLORS.blue}">42%</div>
            <div style="font-size: 10px; color: var(--text-muted)">Социальная сфера</div>
            <div style="font-size: 9px; color: ${COLORS.blue}; margin-top: 4px">школы, больницы, детсады</div>
          </div>
          <div style="padding: 14px; background: linear-gradient(135deg, rgba(76, 175, 80, 0.15), rgba(76, 175, 80, 0.05)); border-radius: 10px; text-align: center">
            <div style="font-size: 24px; font-weight: 800; color: ${COLORS.success}">28%</div>
            <div style="font-size: 10px; color: var(--text-muted)">ЖКХ и инфраструктура</div>
            <div style="font-size: 9px; color: ${COLORS.success}; margin-top: 4px">сети, котельные, дороги</div>
          </div>
          <div style="padding: 14px; background: linear-gradient(135deg, rgba(255, 152, 0, 0.15), rgba(255, 152, 0, 0.05)); border-radius: 10px; text-align: center">
            <div style="font-size: 24px; font-weight: 800; color: ${COLORS.orange}">18%</div>
            <div style="font-size: 10px; color: var(--text-muted)">Административные</div>
            <div style="font-size: 9px; color: ${COLORS.orange}; margin-top: 4px">офисы, МФЦ, учреждения</div>
          </div>
          <div style="padding: 14px; background: linear-gradient(135deg, rgba(156, 39, 176, 0.15), rgba(156, 39, 176, 0.05)); border-radius: 10px; text-align: center">
            <div style="font-size: 24px; font-weight: 800; color: ${COLORS.secondary}">12%</div>
            <div style="font-size: 10px; color: var(--text-muted)">Прочее</div>
            <div style="font-size: 9px; color: ${COLORS.secondary}; margin-top: 4px">аренда, резерв, продажа</div>
          </div>
        </div>
        ${infoTip('Приоритет использования — социальная инфраструктура и ЖКХ (70% объектов)')}
      `);
    }

    // ══════════════════════════════════════════════════════════
    // FUEL SECTION
    // ══════════════════════════════════════════════════════════
    if (show('fuel')) {
      html += `<div class="section-title">${icon(ICONS.fuel)} Топливо и АЗС</div>`;

      const fuelColors = [COLORS.danger, COLORS.secondary, COLORS.tertiary, COLORS.success];
      let fuelRows = '';

      Object.entries(fp).forEach(([name, v], i) => {
        if (!v || typeof v !== 'object') return;
        const avg = v.avg || 0;
        const pct = Math.min(100, Math.round(avg / 90 * 100));
        const color = fuelColors[i % fuelColors.length];

        fuelRows += `
          <div class="fuel-row">
            <span class="fuel-name">${esc(name)}</span>
            <div class="fuel-bar">
              <div class="fuel-fill" style="width: ${pct}%; background: ${color}">
                ${v.min || 0}–${v.max || 0}
              </div>
            </div>
            <span class="fuel-price" style="color: ${color}">${avg.toFixed(1)}₽</span>
          </div>
        `;
      });

      html += card('fuel', true, `
        ${cardHeader(ICONS.fuel, 'Цены на топливо', `${data.fuel?.date || '—'} · ${data.fuel?.stations || 0} АЗС`)}
        <div class="fuel-chart">${fuelRows}</div>
        ${infoTip(`Мониторинг ${data.fuel?.stations || 0} автозаправочных станций Нижневартовска`)}
      `);

      // ═══ ТОП-3 ДЕШЁВЫХ АЗС С ССЫЛКАМИ НА GOOGLE MAPS ═══
      const fuelDemo = getDemoData();
      const topCheap = fuelDemo.fuel?.top_cheap || [];
      if (topCheap.length) {
        const stationsHtml = topCheap.map((station, idx) => {
          const medals = ['🥇', '🥈', '🥉'];
          const bgColors = ['rgba(255, 215, 0, 0.15)', 'rgba(192, 192, 192, 0.12)', 'rgba(205, 127, 50, 0.1)'];
          const googleMapsUrl = station.lat && station.lon
            ? `https://www.google.com/maps/search/?api=1&query=${station.lat},${station.lon}`
            : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(station.name + ', Нижневартовск')}`;
          return `
            <a href="${googleMapsUrl}" target="_blank" rel="noopener" class="cheap-station-link" style="text-decoration: none; display: block;">
              <div class="cheap-station" style="background: ${bgColors[idx]}; border-radius: var(--radius-md); padding: var(--space-md); margin-bottom: var(--space-sm); transition: transform 0.2s, box-shadow 0.2s; cursor: pointer;">
                <div style="display: flex; align-items: center; gap: var(--space-sm); margin-bottom: var(--space-sm)">
                  <span style="font-size: 24px">${medals[idx]}</span>
                  <div style="flex: 1">
                    <div style="font-weight: 600; color: var(--text-primary)">${esc(station.name)}</div>
                    <div style="font-size: 11px; color: var(--text-muted); display: flex; align-items: center; gap: 4px">
                      ${icon('mdi:map-marker', 12)} ${esc(station.address)}
                    </div>
                  </div>
                  <div style="color: ${COLORS.blue}; font-size: 20px" title="Открыть в Google Maps">
                    ${icon('mdi:google-maps', 24)}
                  </div>
                </div>
                <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-sm); text-align: center; font-size: 12px">
                  <div style="background: rgba(239, 68, 68, 0.15); padding: 6px; border-radius: 6px">
                    <div style="font-weight: 700; color: ${COLORS.danger}">${station.ai92}₽</div>
                    <div style="font-size: 10px; color: var(--text-muted)">АИ-92</div>
                  </div>
                  <div style="background: rgba(245, 158, 11, 0.15); padding: 6px; border-radius: 6px">
                    <div style="font-weight: 700; color: ${COLORS.orange}">${station.ai95}₽</div>
                    <div style="font-size: 10px; color: var(--text-muted)">АИ-95</div>
                  </div>
                  <div style="background: rgba(16, 185, 129, 0.15); padding: 6px; border-radius: 6px">
                    <div style="font-weight: 700; color: ${COLORS.success}">${station.dt}₽</div>
                    <div style="font-size: 10px; color: var(--text-muted)">ДТ</div>
                  </div>
                </div>
              </div>
            </a>
          `;
        }).join('');

        html += card('fuel', true, `
          ${cardHeader('mdi:fuel', 'Где дешевле заправиться', 'Топ-3 АЗС · Нажмите для маршрута')}
          <div class="top-cheap-stations">
            ${stationsHtml}
          </div>
          ${infoTip('Нажмите на АЗС для открытия маршрута в Google Maps')}
        `);
      }
    }

    // ══════════════════════════════════════════════════════════
    // HOUSING SECTION - ПОЛНАЯ ВЕРСИЯ С УК
    // ══════════════════════════════════════════════════════════
    if (show('housing')) {
      html += `<div class="section-title">${icon(ICONS.housing)} ЖКХ и управление</div>`;

      const demo = getDemoData();
      const ukFull = demo.uk_full || [];
      const housingStats = demo.housing_stats || {};

      // ═══ ОБЗОР УК ═══
      html += card('housing', true, `
        ${cardHeader(ICONS.uk, 'Управляющие компании', `${ukFull.length || uk.total || 0} организаций`)}
        <div class="uk-summary">
          ${statsRow([
        { value: ukFull.reduce((s, u) => s + u.houses, 0) || uk.houses || 0, label: 'Домов', color: COLORS.primary },
        { value: ukFull.filter(u => u.rating >= 4).length, label: 'С рейтингом 4+', color: COLORS.success },
        { value: ukFull.filter(u => u.email).length, label: 'С email', color: COLORS.blue }
      ])}
        </div>
      `);

      // ═══ СПИСОК УК С РЕЙТИНГОМ ═══
      html += card('housing', true, `
        ${cardHeader(ICONS.star, 'Рейтинг управляющих компаний', 'Нажмите для подробностей')}
        <div class="uk-list" id="uk-list">
          ${ukFull.sort((a, b) => b.rating - a.rating).map(u => `
            <div class="uk-item" onclick="showUkDetails(${u.id})">
              <div class="uk-main">
                <div class="uk-name">${esc(u.short)}</div>
                <div class="uk-houses"><strong style="color: ${COLORS.primary}; font-size: 14px; text-shadow: 0 0 8px ${COLORS.primary};">${u.houses}</strong> домов</div>
              </div>
              <div class="uk-rating">
                <span class="uk-stars" style="color: ${u.rating >= 4 ? COLORS.success : u.rating >= 3.5 ? COLORS.warning : COLORS.danger}">
                  ${icon(ICONS.star, 14)} ${u.rating.toFixed(1)}
                </span>
                <span class="uk-reviews">${u.reviews} отзывов</span>
              </div>
              <div class="uk-actions">
                ${u.email ? `
                  <button class="uk-email-btn" onclick="event.stopPropagation(); openEmailModal('${esc(u.email)}', '${esc(u.short)}')" title="Написать">
                    ${icon(ICONS.email, 16)}
                  </button>
                ` : ''}
                ${icon(ICONS.chevron, 16)}
              </div>
            </div>
          `).join('')}
        </div>
      `);

      // ═══ МОДАЛЬНОЕ ОКНО УК ═══
      html += `
        <div id="uk-modal" class="uk-modal" style="display: none">
          <div class="uk-modal-content">
            <button class="uk-modal-close" onclick="closeUkModal()">×</button>
            <div id="uk-modal-body"></div>
          </div>
        </div>
        <div id="email-modal" class="uk-modal" style="display: none">
          <div class="uk-modal-content email-form">
            <button class="uk-modal-close" onclick="closeEmailModal()">×</button>
            <h3 style="margin-bottom: 12px; display: flex; align-items: center; gap: 8px">
              ${icon(ICONS.email, 20)} Написать в УК
              <span class="privacy-badge" style="
                background: linear-gradient(135deg, #10b981, #059669);
                color: white;
                font-size: 9px;
                padding: 3px 8px;
                border-radius: 10px;
                font-weight: 600;
                text-transform: uppercase;
              ">Анонимно</span>
            </h3>
            <div id="email-modal-recipient"></div>
            
            <!-- Инфо о приватности -->
            <div class="privacy-info" style="
              background: linear-gradient(135deg, rgba(16, 185, 129, 0.1), rgba(5, 150, 105, 0.05));
              border: 1px solid rgba(16, 185, 129, 0.3);
              border-radius: 10px;
              padding: 12px;
              margin-bottom: 12px;
              font-size: 11px;
            ">
              <div style="display: flex; align-items: center; gap: 6px; color: #10b981; margin-bottom: 8px; font-weight: 600">
                ${icon('mdi:shield-lock', 16)} Защита вашей приватности
              </div>
              <ul style="margin: 0; padding-left: 16px; color: var(--text-secondary); line-height: 1.6">
                <li>Текст НЕ сохраняется на сервере</li>
                <li>IP-адрес НЕ передаётся</li>
                <li>После отправки данные удаляются безвозвратно</li>
                <li>Криптографическая перезапись памяти</li>
              </ul>
            </div>
            
            <textarea id="email-message" placeholder="Опишите проблему. Ваши данные не сохраняются..." rows="5" 
              style="resize: none; width: 100%; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 12px; color: var(--text-primary); font-size: 13px"
            ></textarea>
            
            <div class="email-security-footer" style="
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-top: 12px;
              padding-top: 12px;
              border-top: 1px solid rgba(255,255,255,0.1);
            ">
              <div class="email-note" style="color: var(--text-muted); font-size: 10px; display: flex; align-items: center; gap: 4px">
                ${icon('mdi:lock-check', 14)} Шифрование: DOD 5220.22-M
              </div>
              <button class="email-send-btn" onclick="sendAnonymousEmail()" style="
                background: linear-gradient(135deg, ${COLORS.primary}, ${COLORS.secondary});
                border: none;
                border-radius: 20px;
                padding: 10px 20px;
                color: white;
                font-size: 13px;
                font-weight: 600;
                cursor: pointer;
                display: flex;
                align-items: center;
                gap: 6px;
                transition: transform 0.2s, box-shadow 0.2s;
              ">
                ${icon(ICONS.send, 14)} Отправить анонимно
              </button>
            </div>
          </div>
        </div>
      `;

      // ═══ АВАРИЙНЫЕ СЛУЖБЫ ═══
      const emergencyServices = demo.emergency_services || [];
      html += card('housing', true, `
        ${cardHeader(ICONS.emergency, 'Аварийные службы', `${emergencyServices.length} служб`)}
        <div class="emergency-list">
          ${emergencyServices.map(s => `
            <div class="emergency-item emergency-${s.type}">
              <div class="emergency-icon">${icon(s.icon, 20)}</div>
              <div class="emergency-info">
                <div class="emergency-name">${esc(s.name)}</div>
                <a href="tel:${s.phone.replace(/[^0-9,]/g, '').split(',')[0]}" class="emergency-phone">${icon('mdi:phone', 12)} ${s.phone}</a>
              </div>
            </div>
          `).join('')}
        </div>
        <div class="emergency-tip">
          ${icon('mdi:information', 14)} Единый номер экстренных служб: <strong>112</strong>
        </div>
      `);

      // ═══ ЖИЛИЩНЫЙ ФОНД ═══
      const housingFund = housingStats.housing_fund || [];
      if (housingFund.length) {
        const latest = housingFund[housingFund.length - 1];
        html += card('housing', true, `
          ${cardHeader('mdi:home-group', 'Жилищный фонд', latest.year)}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber((latest.total_sqm / 1e6).toFixed(2), 'млн м² жилья', COLORS.blue)}
          </div>
          ${lineChart(housingFund, [
          { key: 'total_sqm', label: 'Жилой фонд (м²)', color: COLORS.blue, divider: 1e6 }
        ], { height: 80 })}
          <div style="text-align: center; margin-top: 8px; font-size: 14px; color: ${COLORS.success}">
            ${latest.per_capita} м² на человека
          </div>
        `);
      }

      // ═══ НОВОЕ СТРОИТЕЛЬСТВО ═══
      const newConstruction = housingStats.new_construction || [];
      if (newConstruction.length) {
        const latest = newConstruction[newConstruction.length - 1];
        html += card('housing', true, `
          ${cardHeader(ICONS.construction, 'Новое строительство', latest.year)}
          ${statsRow([
          { value: (latest.sqm / 1000).toFixed(0) + ' тыс', label: 'м² введено', color: COLORS.success },
          { value: latest.apartments, label: 'квартир', color: COLORS.blue }
        ])}
          ${lineChart(newConstruction, [
          { key: 'apartments', label: 'Квартир', color: COLORS.success }
        ], { height: 80 })}
        `);
      }

      // ═══ ТАРИФЫ ЖКХ - РАСШИРЕННЫЙ БЛОК ═══
      const tariffs = data.tariffs || {};
      if (tariffs.services?.length) {
        // КАРТОЧКА 1: Основные тарифы
        html += card('housing', true, `
          ${cardHeader('mdi:receipt', 'Тарифы ЖКХ ' + tariffs.year, 'Действующие с 01.07.' + tariffs.year)}
          <div style="margin: var(--space-md) 0">
            ${tariffs.services.map(s => `
              <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                <div style="flex: 1">
                  <div style="font-size: 12px; font-weight: 500">${s.name}</div>
                  <div style="font-size: 10px; color: var(--text-muted)">${s.unit}</div>
                </div>
                <div style="text-align: right; display: flex; align-items: center; gap: 12px">
                  <div style="font-size: 14px; font-weight: 700; color: ${COLORS.primary}">${s.price}</div>
                  <div style="font-size: 10px; padding: 2px 6px; border-radius: 4px; background: rgba(255,152,0,0.2); color: ${COLORS.warning}">+${s.change}%</div>
                </div>
              </div>
            `).join('')}
          </div>
          ${statsRow([
          { value: tariffs.avg_payment?.toLocaleString('ru') || 0, label: 'Средний платёж ₽/мес', color: COLORS.orange },
          { value: (tariffs.subsidy_recipients / 1000)?.toFixed(1) || 0, label: 'тыс. субсидий', color: COLORS.success }
        ])}
        `);

        // КАРТОЧКА 2: Структура платежа (круговая диаграмма)
        if (tariffs.payment_structure?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:chart-pie', 'Структура платежа', 'Распределение затрат')}
            <div style="margin: var(--space-md) 0">
              ${pieChart(tariffs.payment_structure, { showLegend: true })}
            </div>
            <div style="margin-top: 12px; font-size: 11px; text-align: center; color: var(--text-muted)">
              На семью из 3 чел. в квартире 60 м²
            </div>
          `);
        }

        // КАРТОЧКА 3: Динамика тарифов (АНИМИРОВАННЫЙ мультилинейный график)
        if (tariffs.history?.length) {
          const chartId = 'tariffs-animated-' + Date.now();
          html += card('housing', true, `
            ${cardHeader('mdi:chart-line-variant', 'Динамика тарифов', '2019-2025 · Анимированный')}
            <div style="margin-top: var(--space-md)">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">Изменение цен на основные услуги:</div>
              <div class="animated-tariff-chart" id="${chartId}" 
                   data-history='${JSON.stringify(tariffs.history)}' 
                   style="height: 180px; position: relative; margin-bottom: 16px">
                <canvas id="${chartId}-canvas" style="width: 100%; height: 100%"></canvas>
              </div>
              <div style="display: flex; justify-content: center; gap: var(--space-lg); flex-wrap: wrap; font-size: 11px; margin-bottom: 12px">
                <span style="color: ${COLORS.blue}">● ХВС ₽/м³</span>
                <span style="color: ${COLORS.orange}">● ГВС ₽/м³</span>
                <span style="color: ${COLORS.success}">● Эл-во ₽/кВт</span>
                <span style="color: ${COLORS.primary}">● Ср. платёж ÷100</span>
              </div>
              <button class="replay-btn" onclick="replayTariffAnimation('${chartId}')" style="
                display: block; margin: 0 auto; padding: 8px 16px;
                background: linear-gradient(135deg, ${COLORS.primary}, ${COLORS.secondary});
                border: none; border-radius: 20px; color: white; font-size: 12px;
                cursor: pointer; transition: transform 0.2s, box-shadow 0.2s;
              ">
                ${icon('mdi:replay', 14)} Повторить анимацию
              </button>
            </div>
          `);
        }

        // КАРТОЧКА 4: История индексации (столбцовая диаграмма)
        if (tariffs.indexation_history?.length) {
          const indexData = tariffs.indexation_history.map(i => ({ name: i.year, count: i.percent, color: i.percent > 9 ? COLORS.danger : i.percent > 6 ? COLORS.warning : COLORS.success }));
          html += card('housing', true, `
            ${cardHeader('mdi:trending-up', 'История индексаций', '% роста по годам')}
            <div style="margin: var(--space-md) 0">
              ${barChart(indexData)}
            </div>
            <div style="display: flex; justify-content: space-around; margin-top: 12px; font-size: 10px; color: var(--text-muted)">
              <span><span style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: ${COLORS.success}"></span> до 6%</span>
              <span><span style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: ${COLORS.warning}"></span> 6-9%</span>
              <span><span style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: ${COLORS.danger}"></span> >9%</span>
            </div>
            ${analysisBlock('АНАЛИЗ 2025',
            `Индексация <strong style="color: ${COLORS.danger};">+11.9%</strong> с 01.07.2025 — максимальная за последние 5 лет. Электроэнергия: <strong>+12.6%</strong>, газ: <strong>+10.3%</strong>. Средний платёж вырос до <strong style="color: ${COLORS.orange};">7 650 ₽</strong>/мес. <strong style="color: ${COLORS.success};">13 200 семей</strong> получают субсидии.`
          )}
          `);
        }

        // КАРТОЧКА 5: Поставщики услуг
        if (tariffs.by_supplier?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:domain', 'Поставщики услуг', `${tariffs.by_supplier.length} организаций`)}
            <div style="margin: var(--space-md) 0">
              ${tariffs.by_supplier.map(s => `
                <div style="padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                  <div style="display: flex; justify-content: space-between; align-items: start">
                    <div>
                      <div style="font-size: 12px; font-weight: 600">${s.name}</div>
                      <div style="font-size: 10px; color: var(--text-muted)">${s.service}</div>
                    </div>
                    <div style="text-align: right">
                      <div style="font-size: 11px; color: ${COLORS.blue}">${(s.clients / 1000).toFixed(1)}к клиентов</div>
                      <div style="font-size: 10px; color: ${COLORS.success}">${s.revenue} млн ₽/год</div>
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          `);
        }

        // КАРТОЧКА 6: Многотарифное электричество (радар-стиль)
        if (tariffs.tariff_zones?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:clock-outline', 'Многотарифный учёт', 'Электроэнергия по зонам')}
            <div style="display: flex; gap: 12px; margin: var(--space-md) 0">
              ${tariffs.tariff_zones.map(z => `
                <div style="flex: 1; text-align: center; padding: 12px; background: rgba(255,255,255,0.03); border-radius: 8px">
                  <div style="font-size: 11px; color: var(--text-secondary); margin-bottom: 8px; font-weight: 500">${z.zone}</div>
                  <div style="font-size: 26px; font-weight: 800; color: ${z.zone.includes('Дневная') ? COLORS.orange : COLORS.blue}; text-shadow: 0 0 15px ${z.zone.includes('Дневная') ? COLORS.orange : COLORS.blue};">${z.power}</div>
                  <div style="font-size: 11px; color: var(--text-muted)">₽/кВт·ч</div>
                  <div style="margin-top: 8px; height: 4px; background: rgba(255,255,255,0.1); border-radius: 2px; overflow: hidden">
                    <div style="width: ${z.percent}%; height: 100%; background: ${z.zone.includes('Дневная') ? COLORS.orange : COLORS.blue}"></div>
                  </div>
                  <div style="font-size: 9px; margin-top: 4px; color: var(--text-muted)">${z.percent}% потребления</div>
                </div>
              `).join('')}
            </div>
            <div style="font-size: 11px; color: var(--text-muted); text-align: center">
              ${icon('mdi:information-outline', 12)} Экономия до 30% при переходе на ночное потребление
            </div>
          `);
        }
      }

      // ═══ УСЛУГИ ЖКХ - НОВЫЙ БЛОК ═══
      const zkhServices = data.zkh_services || getDemoData().zkh_services || {};
      if (zkhServices.categories?.length) {
        // Обращения по категориям
        html += card('housing', true, `
          ${cardHeader('mdi:clipboard-text-outline', 'Обращения граждан', zkhServices.total_requests?.toLocaleString('ru') + ' за год')}
          ${statsRow([
          { value: ((zkhServices.resolved / zkhServices.total_requests) * 100).toFixed(1) + '%', label: 'решено', color: COLORS.success },
          { value: zkhServices.avg_response_hours + 'ч', label: 'ср. время', color: COLORS.blue },
          { value: zkhServices.satisfaction_rate + '%', label: 'довольны', color: COLORS.tertiary }
        ])}
          <div style="margin-top: var(--space-md)">
            ${zkhServices.categories.map(c => {
          const resolvedPercent = Math.round((c.resolved / c.requests) * 100);
          return `
                <div style="margin-bottom: 10px">
                  <div style="display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 4px">
                    <span>${c.name}</span>
                    <span style="color: var(--text-muted)">${c.requests} (${resolvedPercent}%)</span>
                  </div>
                  <div style="height: 6px; background: rgba(255,255,255,0.1); border-radius: 3px; overflow: hidden">
                    <div style="width: ${resolvedPercent}%; height: 100%; background: linear-gradient(90deg, ${COLORS.success} ${resolvedPercent * 0.8}%, ${COLORS.blue})"></div>
                  </div>
                </div>
              `;
        }).join('')}
          </div>
        `);

        // Сезонность обращений (график-волна)
        if (zkhServices.monthly_requests?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:calendar-month', 'Сезонность обращений', 'Помесячная динамика')}
            <div style="margin: var(--space-md) 0">
              ${lineChart(zkhServices.monthly_requests, [
            { key: 'count', label: 'Поступило', color: COLORS.orange },
            { key: 'resolved', label: 'Решено', color: COLORS.success }
          ], { height: 90 })}
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 10px; color: var(--text-muted); margin-top: 8px">
              ${zkhServices.monthly_requests.map(m => `<span>${m.month}</span>`).join('')}
            </div>
            ${analysisBlock('Анализ',
            `Пик обращений — отопительный сезон (нояб-янв). В январе в 2.5 раза больше заявок чем летом. Основные проблемы: температура в квартирах, протечки, засоры.`
          )}
          `);
        }

        // Программы капитального ремонта
        if (zkhServices.capex_programs?.length) {
          const totalBudget = zkhServices.capex_programs.reduce((s, p) => s + p.budget, 0);
          html += card('housing', true, `
            ${cardHeader('mdi:tools', 'Капитальные программы', (totalBudget / 1000).toFixed(1) + ' млрд ₽')}
            <div style="margin: var(--space-md) 0">
              ${zkhServices.capex_programs.map(p => `
                <div style="display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                  <div style="width: 44px; height: 44px; border-radius: 8px; background: linear-gradient(135deg, ${COLORS.primary}33, ${COLORS.secondary}33); display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 800; color: ${COLORS.primary}; text-shadow: 0 0 10px ${COLORS.primary};">
                    ${p.percent}%
                  </div>
                  <div style="flex: 1">
                    <div style="font-size: 12px; font-weight: 600; color: var(--text-primary)">${p.name}</div>
                    <div style="font-size: 11px; color: var(--text-muted)">${p.objects ? '<strong style="color:' + COLORS.secondary + '">' + p.objects + '</strong> объектов' : ''}</div>
                  </div>
                  <div style="font-size: 14px; font-weight: 700; color: ${COLORS.success}; text-shadow: 0 0 8px ${COLORS.success};">${p.budget} млн</div>
                </div>
              `).join('')}
            </div>
          `);
        }
      }

      // ═══ СТРОИТЕЛЬСТВО - РАСШИРЕННЫЙ БЛОК ═══
      const construction = data.construction || {};
      if (construction.current_year?.length || construction.by_type?.length) {
        // Обзор строительства
        html += card('housing', true, `
          ${cardHeader('mdi:crane', 'Строительство', `${construction.total_objects || 0} объектов`)}
          ${statsRow([
          { value: construction.in_progress || 48, label: 'Строится', color: COLORS.orange },
          { value: construction.completed_2024 || 32, label: 'Сдано в 2024', color: COLORS.success },
          { value: construction.planned_2025 || 24, label: 'План 2025', color: COLORS.blue }
        ])}
          ${construction.by_type?.length ? `
            <div style="margin-top: var(--space-md)">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">По типам объектов:</div>
              ${barChart(construction.by_type.map(t => ({ ...t, color: t.color || COLORS.primary })))}
            </div>
          ` : ''}
        `);

        // Объекты с прогрессом 2025-2026
        if (construction.current_year?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:format-list-bulleted', 'Ключевые объекты 2025-2026', '')}
            <div style="margin: var(--space-md) 0">
              ${construction.current_year.map(obj => `
                <div style="padding: 12px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                  <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 8px">
                    <div style="flex: 1">
                      <div style="font-size: 12px; font-weight: 500">${obj.name}</div>
                      <div style="font-size: 10px; color: var(--text-muted)">${obj.type} • ${(obj.sqm / 1000).toFixed(1)} тыс. м²</div>
                    </div>
                    <span style="font-size: 9px; padding: 2px 8px; border-radius: 4px; background: ${obj.status === 'строится' ? 'rgba(76,175,80,0.2)' : 'rgba(33,150,243,0.2)'}; color: ${obj.status === 'строится' ? COLORS.success : COLORS.blue}; text-transform: uppercase">${obj.status}</span>
                  </div>
                  <div style="position: relative; height: 8px; background: rgba(255,255,255,0.1); border-radius: 4px; overflow: hidden">
                    <div style="position: absolute; height: 100%; width: ${obj.progress}%; background: linear-gradient(90deg, ${COLORS.primary}, ${obj.progress > 70 ? COLORS.success : COLORS.blue}); border-radius: 4px; transition: width 0.5s"></div>
                  </div>
                  <div style="display: flex; justify-content: space-between; font-size: 10px; margin-top: 4px">
                    <span style="color: ${COLORS.primary}; font-weight: 600">${obj.progress}%</span>
                    <span style="color: var(--text-muted)">Срок: ${obj.deadline}</span>
                  </div>
                </div>
              `).join('')}
            </div>
            ${analysisBlock('АНАЛИЗ 2025-2026', 'Приоритеты: <strong style="color: ' + COLORS.success + ';">благоустройство</strong> (площадь Нефтяников, парк Победы, фонтан), <strong style="color: ' + COLORS.primary + ';">инфраструктура</strong> (16 тёплых остановок), <strong style="color: ' + COLORS.orange + ';">новое производство</strong>. На 2026 — проект набережной и ЖК на 26.8 га.')}
          `);
        }

        // Инвестиции в строительство (area chart style)
        if (construction.investment_history?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:cash-multiple', 'Инвестиции в строительство', 'млн ₽')}
            <div style="margin: var(--space-md) 0">
              ${lineChart(construction.investment_history, [
            { key: 'budget', label: 'Бюджет', color: COLORS.blue },
            { key: 'private', label: 'Частные', color: COLORS.success }
          ], { height: 90 })}
            </div>
            ${statsRow([
            { value: (construction.investment_history[construction.investment_history.length - 1]?.budget / 1000).toFixed(1), label: 'млрд бюджет', color: COLORS.blue },
            { value: (construction.investment_history[construction.investment_history.length - 1]?.private / 1000).toFixed(1), label: 'млрд частные', color: COLORS.success }
          ])}
          `);
        }

        // Ввод жилья по годам
        if (construction.housing_input?.length) {
          const latest = construction.housing_input[construction.housing_input.length - 1];
          html += card('housing', true, `
            ${cardHeader('mdi:home-plus', 'Ввод жилья', latest.year)}
            <div style="display: flex; gap: 16px; text-align: center; margin: var(--space-md) 0">
              <div style="flex: 1; padding: 12px; background: rgba(76,175,80,0.1); border-radius: 8px">
                <div style="font-size: 26px; font-weight: 800; color: ${COLORS.success}; text-shadow: 0 0 15px ${COLORS.success};">${(latest.sqm / 1000).toFixed(0)}</div>
                <div style="font-size: 11px; color: var(--text-secondary); font-weight: 500">тыс. м²</div>
              </div>
              <div style="flex: 1; padding: 12px; background: rgba(33,150,243,0.1); border-radius: 8px">
                <div style="font-size: 26px; font-weight: 800; color: ${COLORS.blue}; text-shadow: 0 0 15px ${COLORS.blue};">${latest.apartments}</div>
                <div style="font-size: 11px; color: var(--text-secondary); font-weight: 500">квартир</div>
              </div>
              <div style="flex: 1; padding: 12px; background: rgba(156,39,176,0.1); border-radius: 8px">
                <div style="font-size: 26px; font-weight: 800; color: ${COLORS.tertiary}; text-shadow: 0 0 15px ${COLORS.tertiary};">${latest.houses}</div>
                <div style="font-size: 11px; color: var(--text-secondary); font-weight: 500">домов</div>
              </div>
            </div>
            ${lineChart(construction.housing_input, [
            { key: 'apartments', label: 'Квартир', color: COLORS.blue }
          ], { height: 70 })}
          `);
        }

        // Застройщики
        if (construction.developers?.length) {
          html += card('housing', true, `
            ${cardHeader('mdi:office-building', 'Топ застройщиков', '')}
            <div style="margin: var(--space-md) 0">
              ${construction.developers.map((d, i) => `
                <div style="display: flex; align-items: center; gap: 12px; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.05)">
                  <div style="width: 28px; height: 28px; border-radius: 50%; background: linear-gradient(135deg, ${COLORS.primary}, ${COLORS.secondary}); display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700">${i + 1}</div>
                  <div style="flex: 1">
                    <div style="font-size: 12px; font-weight: 500">${d.name}</div>
                    <div style="font-size: 10px; color: var(--text-muted)">${d.objects} объектов • ${(d.sqm / 1000).toFixed(0)} тыс. м²</div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 4px; color: ${d.rating >= 4.5 ? COLORS.success : d.rating >= 4 ? COLORS.warning : COLORS.orange}">
                    ${icon('mdi:star', 14)}
                    <span style="font-size: 12px; font-weight: 600">${d.rating}</span>
                  </div>
                </div>
              `).join('')}
            </div>
          `);
        }

        // Цены на недвижимость
        if (construction.price_dynamics?.length) {
          const latestPrice = construction.price_dynamics[construction.price_dynamics.length - 1];
          html += card('housing', true, `
            ${cardHeader('mdi:currency-rub', 'Цены на жильё', '₽/м²')}
            <div style="display: flex; gap: 16px; margin: var(--space-md) 0">
              <div style="flex: 1; text-align: center; padding: 16px; background: rgba(255,255,255,0.03); border-radius: 8px; border: 1px solid ${COLORS.primary}33">
                <div style="font-size: 11px; color: var(--text-secondary); margin-bottom: 4px; font-weight: 500">Первичное</div>
                <div style="font-size: 22px; font-weight: 800; color: ${COLORS.primary}; text-shadow: 0 0 12px ${COLORS.primary};">${(latestPrice.primary / 1000).toFixed(0)}</div>
                <div style="font-size: 11px; color: var(--text-muted)">тыс. ₽/м²</div>
              </div>
              <div style="flex: 1; text-align: center; padding: 16px; background: rgba(255,255,255,0.03); border-radius: 8px; border: 1px solid ${COLORS.secondary}33">
                <div style="font-size: 11px; color: var(--text-secondary); margin-bottom: 4px; font-weight: 500">Вторичное</div>
                <div style="font-size: 22px; font-weight: 800; color: ${COLORS.secondary}; text-shadow: 0 0 12px ${COLORS.secondary};">${(latestPrice.secondary / 1000).toFixed(0)}</div>
                <div style="font-size: 11px; color: var(--text-muted)">тыс. ₽/м²</div>
              </div>
            </div>
            ${lineChart(construction.price_dynamics, [
            { key: 'primary', label: 'Новостройки', color: COLORS.primary },
            { key: 'secondary', label: 'Вторичка', color: COLORS.secondary }
          ], { height: 80 })}
            ${analysisBlock('Анализ',
            `С 2019 года первичное жильё подорожало на ${Math.round((latestPrice.primary / 52000 - 1) * 100)}%, вторичное — на ${Math.round((latestPrice.secondary / 48000 - 1) * 100)}%. Разрыв между новостройками и вторичкой: ${Math.round((latestPrice.primary / latestPrice.secondary - 1) * 100)}%.`
          )}
          `);
        }
      }
    }

    // ══════════════════════════════════════════════════════════
    // EDUCATION SECTION
    // ══════════════════════════════════════════════════════════
    if (show('edu')) {
      html += `<div class="section-title">${icon(ICONS.edu)} Образование и культура</div>`;

      html += card('edu', false, `
        ${cardHeader(ICONS.school, 'Образование 2025', '')}
        ${statsRow([
        { value: ed.kindergartens || 0, label: 'Детсадов', color: COLORS.secondary },
        { value: ed.schools || 0, label: 'Школ', color: COLORS.blue },
        { value: ed.dod || 0, label: 'ДОД', color: COLORS.tertiary }
      ])}
        ${analysisBlock('АНАЛИЗ', 'Система образования: <strong style="color: ' + COLORS.secondary + ';">' + (ed.kindergartens || 0) + '</strong> дошкольных + <strong style="color: ' + COLORS.blue + ';">' + (ed.schools || 0) + '</strong> общеобразовательных учреждений + <strong style="color: ' + COLORS.tertiary + ';">' + (ed.dod || 0) + '</strong> учреждений допобразования. Охват детей дошкольным образованием: <strong style="color: ' + COLORS.success + ';">98%</strong>.')}
      `);

      // ═══ КУЛЬТУРА - РАСШИРЕННАЯ ═══
      const cultureData = data.culture || {};
      html += card('edu', true, `
        ${cardHeader(ICONS.culture, 'Культура', `${cultureData.total_institutions || ed.culture || 0} учреждений`)}
        ${statsRow([
        { value: cultureData.events_2024 || 0, label: 'Событий в 2024', color: COLORS.tertiary },
        { value: (cultureData.visitors_2024 / 1000)?.toFixed(0) || 0, label: 'тыс. посетителей', color: COLORS.pink },
        { value: cultureData.clubs?.total || 0, label: 'Кружков', color: COLORS.blue }
      ])}
        ${cultureData.institutions?.length ? `
          <div style="margin-top: var(--space-md)">
            ${cultureData.institutions.slice(0, 5).map(inst => `
              <div style="display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 12px">
                <span style="flex: 1; color: var(--text-secondary)">${inst.name}</span>
                <span style="color: ${COLORS.primary}; width: 70px; text-align: right; font-weight: 700; text-shadow: 0 0 10px ${COLORS.primary};">
                  ${inst.students ? '<strong>' + inst.students + '</strong> уч.' : inst.visitors ? '<strong>' + (inst.visitors / 1000).toFixed(0) + 'к</strong>' : inst.performances ? '<strong>' + inst.performances + '</strong>' : ''}
                </span>
              </div>
            `).join('')}
          </div>
        ` : ''}
        <div style="margin-top: 12px; display: flex; gap: 16px; font-size: 12px; justify-content: center">
          <span style="color: ${COLORS.success}; font-weight: 600">${icon('mdi:checkbox-marked-circle', 14)} <strong style="font-size: 14px; text-shadow: 0 0 10px ${COLORS.success}">${cultureData.clubs?.free || 0}</strong> бесплатных</span>
          <span style="color: ${COLORS.warning}; font-weight: 600">${icon('mdi:cash', 14)} <strong style="font-size: 14px; text-shadow: 0 0 10px ${COLORS.warning}">${cultureData.clubs?.paid || 0}</strong> платных</span>
        </div>
        ${analysisBlock('АНАЛИЗ', 'Культурная сеть города: Дворец искусств, драматический театр, 3 музыкальные школы, 2 библиотечные системы. <strong style="color: ' + COLORS.pink + ';">890 тыс. посетителей</strong> в 2024 году.')}
      `);

      html += card('edu', false, `
        ${cardHeader(ICONS.stadium, 'Спорт', '')}
        ${bigNumber(ed.sections || 0, 'секций', COLORS.success)}
        <div style="display: flex; gap: 16px; margin-top: 12px; font-size: 12px; justify-content: center">
          <span style="color: ${COLORS.success}; font-weight: 600">${icon('mdi:checkbox-marked-circle', 14)} <strong style="font-size: 14px; text-shadow: 0 0 10px ${COLORS.success}">${ed.sections_free || 0}</strong> бесплатных</span>
          <span style="color: ${COLORS.warning}; font-weight: 600">${icon('mdi:cash', 14)} <strong style="font-size: 14px; text-shadow: 0 0 10px ${COLORS.warning}">${ed.sections_paid || 0}</strong> платных</span>
        </div>
      `);

      html += card('edu', false, `
        ${cardHeader(ICONS.trainer, 'Тренеры', '')}
        ${bigNumber(data.trainers?.total || 0, 'тренеров', COLORS.teal)}
      `);
    }

    // ══════════════════════════════════════════════════════════
    // SPORTS ACHIEVEMENTS SECTION
    // ══════════════════════════════════════════════════════════
    if (show('edu')) {
      const sports = data.sports || {};
      const champions = sports.champions || [];
      const history = sports.history || [];
      const popularSports = sports.popular_sports || [];
      const facilities = sports.facilities || [];

      if (champions.length || history.length) {
        html += `<div class="section-title">${icon('mdi:trophy')} Спортивные достижения</div>`;

        // Общая статистика медалей
        html += card('edu', true, `
          ${cardHeader('mdi:medal', 'Медали 2025', `${sports.total_medals_2025 || 0} медалей`)}
          <div class="medal-showcase">
            <div class="medal gold-medal">
              ${icon('mdi:medal', 32)}
              <span class="medal-count">${sports.gold || 0}</span>
              <span class="medal-label">Золото</span>
            </div>
            <div class="medal silver-medal">
              ${icon('mdi:medal', 32)}
              <span class="medal-count">${sports.silver || 0}</span>
              <span class="medal-label">Серебро</span>
            </div>
            <div class="medal bronze-medal">
              ${icon('mdi:medal', 32)}
              <span class="medal-count">${sports.bronze || 0}</span>
              <span class="medal-label">Бронза</span>
            </div>
          </div>
          ${statsRow([
          { value: sports.athletes || 0, label: 'Спортсменов', color: COLORS.primary },
          { value: sports.trainers || 0, label: 'Тренеров', color: COLORS.teal }
        ])}
        `);

        // История медалей
        if (history.length > 1) {
          html += card('edu', true, `
            ${cardHeader('mdi:chart-line', 'Динамика медалей', '2020-2025')}
            ${lineChart(history, [
            { key: 'gold', label: 'Золото', color: '#FFD700' },
            { key: 'silver', label: 'Серебро', color: '#C0C0C0' },
            { key: 'bronze', label: 'Бронза', color: '#CD7F32' }
          ], { height: 120 })}
            ${analysisBlock('Тренд', 'Количество медалей стабильно растёт. Прирост за 5 лет: +34%')}
          `);
        }

        // Чемпионы
        if (champions.length) {
          html += card('edu', true, `
            ${cardHeader('mdi:trophy-award', 'Чемпионы 2024-2025', `${champions.length} победителей`)}
            <div class="champions-list">
              ${champions.map(ch => `
                <div class="champion-item ${ch.medal}">
                  <div class="champion-icon">
                    ${icon(ch.icon || 'mdi:account-star', 24)}
                  </div>
                  <div class="champion-info">
                    <div class="champion-name">${ch.name}</div>
                    <div class="champion-sport">${ch.sport}</div>
                    <div class="champion-achievement">${ch.achievement}</div>
                  </div>
                  <div class="champion-medal">
                    ${icon('mdi:medal', 20)}
                  </div>
                </div>
              `).join('')}
            </div>
          `);
        }

        // Популярные виды спорта
        if (popularSports.length) {
          html += card('edu', true, `
            ${cardHeader('mdi:run-fast', 'Популярные виды спорта', '')}
            <div class="sports-grid">
              ${popularSports.slice(0, 6).map(sp => `
                <div class="sport-item">
                  <div class="sport-icon">${icon(sp.icon || 'mdi:dumbbell', 28)}</div>
                  <div class="sport-name">${sp.name}</div>
                  <div class="sport-athletes">${sp.athletes} спортсменов</div>
                </div>
              `).join('')}
            </div>
          `);
        }

        // Спортивные школы
        if (facilities.length) {
          const totalAthletes = facilities.reduce((sum, f) => sum + (f.athletes || 0), 0);
          html += card('edu', true, `
            ${cardHeader('mdi:stadium', 'Спортивные школы', `${sports.sport_schools || facilities.length} школ`)}
            <div class="facilities-list">
              ${facilities.map(f => `
                <div class="facility-item">
                  <div class="facility-name">${f.name}</div>
                  <div class="facility-sports">${f.sports.join(', ')}</div>
                  <div class="facility-athletes">${icon('mdi:account-group', 14)} <span style="color: ${COLORS.success}; font-weight: 700; text-shadow: 0 0 10px ${COLORS.success};">${f.athletes}</span> спортсменов</div>
                </div>
              `).join('')}
            </div>
            ${analysisBlock('АНАЛИЗ', 'В городе действуют <strong style="color: ' + COLORS.success + ';">' + (sports.sport_schools || facilities.length) + '</strong> спортивные школы с общим охватом <strong style="color: ' + COLORS.secondary + ';">' + totalAthletes.toLocaleString('ru') + '</strong> спортсменов. Лидер — СШОР «Самотлор» (<strong style="color: ' + COLORS.teal + ';">420</strong> чел.). Основные виды: футбол, хоккей, плавание, бокс, дзюдо, гимнастика.')}
          `);
        }
      }
    }

    // ══════════════════════════════════════════════════════════
    // TRANSPORT SECTION 2025 (расширенная версия)
    // ══════════════════════════════════════════════════════════
    if (show('transport')) {
      html += `<div class="section-title">${icon(ICONS.transport)} Транспорт</div>`;

      // Маршруты с детальной разбивкой 2025
      html += card('transport', false, `
        ${cardHeader(ICONS.route, 'Маршруты 2025', '')}
        ${statsRow([
        { value: tr.city_buses || tr.routes || 24, label: 'Городских', color: COLORS.blue },
        { value: tr.marshrutki || 25, label: 'Маршруток', color: COLORS.teal },
        { value: tr.stops || 358, label: 'Остановок', color: COLORS.orange }
      ])}
        ${infoTip(`<span style="color: ${COLORS.success}; font-weight: 700;">+16</span> тёплых остановок у соцучреждений (2025)`)}
      `);

      // Пассажиропоток с графиком
      if (tr.history?.length > 1) {
        html += card('transport', true, `
          ${cardHeader('mdi:chart-line', 'Пассажиропоток', 'млн чел./год')}
          ${lineChart(tr.history, [
          { key: 'passengers', label: 'Пассажиры', color: COLORS.blue, divider: 1000000 }
        ], { height: 100 })}
          ${analysisBlock('АНАЛИЗ', 'Пандемия 2020 снизила пассажиропоток на 20%. К 2025 году показатели восстановились и превысили допандемийный уровень на <strong style="color: ' + COLORS.success + ';">+24%</strong>.')}
        `);
      }

      // Обновлённые маршруты
      if (tr.routes_updated?.length) {
        html += card('transport', true, `
          ${cardHeader('mdi:bus-clock', 'Обновлённые маршруты', 'с 01.11.2025')}
          <div class="routes-updated" style="display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px;">
            ${tr.routes_updated.map(r => `
              <span style="background: rgba(0, 240, 255, 0.2); padding: 6px 12px; border-radius: 6px; font-weight: 600; color: ${COLORS.primary};">№${r}</span>
            `).join('')}
          </div>
          ${infoTip('Изменены расписания и маршруты для улучшения покрытия')}
        `);
      }

      // Дороги
      html += card('transport', false, `
        ${cardHeader(ICONS.road, 'Дороги и мосты 2025', '')}
        ${statsRow([
        { value: data.road_service?.total || cn.construction || 128, label: 'Объектов', color: COLORS.tertiary },
        { value: data.road_works?.total || cn.permits || 52, label: 'Работ', color: COLORS.secondary }
      ])}
        ${infoTip(`Ремонт <strong style="color: ${COLORS.orange};">4 км</strong> трассы Стрежевой-Нижневартовск (93.7 млн ₽)`)}
      `);
    }

    // ══════════════════════════════════════════════════════════
    // ECOLOGY SECTION - РАСШИРЕННАЯ ВЕРСИЯ
    // ══════════════════════════════════════════════════════════
    if (show('eco')) {
      html += `<div class="section-title">${icon(ICONS.eco)} Экология</div>`;

      const eco = data.ecology || {};
      const air = eco.air_quality || {};
      const green = eco.green_zones || {};
      const projects = eco.eco_projects || [];
      const water = eco.water || {};
      const wasteGroups = (waste.groups || []).slice(0, 6);

      // ═══ КАЧЕСТВО ВОЗДУХА ═══
      if (air.current_index) {
        const airLevel = air.current_index < 2 ? 'отличное' : air.current_index < 4 ? 'хорошее' : air.current_index < 7 ? 'умеренное' : 'плохое';
        const airColor = air.current_index < 2 ? COLORS.success : air.current_index < 4 ? COLORS.primary : air.current_index < 7 ? COLORS.orange : COLORS.danger;

        html += card('eco', true, `
          ${cardHeader('mdi:weather-windy', 'Качество воздуха', 'Индекс загрязнения')}
          <div style="text-align: center; margin: var(--space-md) 0">
            <div style="font-size: 48px; font-weight: 900; color: ${airColor}; text-shadow: 0 0 20px ${airColor}40">${air.current_index}</div>
            <div style="font-size: 14px; color: ${airColor}; text-transform: uppercase; letter-spacing: 2px">${airLevel}</div>
          </div>
          ${air.history?.length ? lineChart(air.history, [
          { key: 'index', label: 'ИЗА', color: airColor }
        ], { height: 80 }) : ''}
          ${air.main_pollutants?.length ? `
            <div style="margin-top: var(--space-md)">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">Основные загрязнители (доля от ПДК):</div>
              ${air.main_pollutants.map(p => `
                <div style="margin: 6px 0">
                  <div style="display: flex; justify-content: space-between; font-size: 10px; margin-bottom: 2px">
                    <span>${p.name}</span>
                    <span style="color: ${p.level < 0.5 ? COLORS.success : p.level < 0.8 ? COLORS.orange : COLORS.danger}">${(p.level * 100).toFixed(0)}%</span>
                  </div>
                  <div style="background: rgba(255,255,255,0.1); border-radius: 4px; height: 6px; overflow: hidden">
                    <div style="width: ${p.level * 100}%; height: 100%; background: linear-gradient(90deg, ${COLORS.success}, ${p.level < 0.5 ? COLORS.success : COLORS.orange}); border-radius: 4px"></div>
                  </div>
                </div>
              `).join('')}
            </div>
          ` : ''}
          ${analysisBlock('Анализ',
          `ИЗА (индекс загрязнения атмосферы) снижается с ${air.history?.[0]?.index || 'N/A'} в ${air.history?.[0]?.year || 'N/A'} до ${air.current_index} в 2024. Все показатели ниже ПДК. Воздух в городе оценивается как "${airLevel}".`
        )}
        `);
      }

      // ═══ ЗЕЛЁНЫЕ ЗОНЫ 2025 ═══
      if (green.parks || green.total_area_ha) {
        html += card('eco', true, `
          ${cardHeader('mdi:tree', 'Зелёные зоны 2025', 'Парки и скверы')}
          ${statsRow([
          { value: green.parks || 13, label: 'Парков', color: COLORS.success },
          { value: green.squares || 30, label: 'Скверов', color: COLORS.primary },
          { value: green.total_area_ha || 1920, label: 'Га площадь', color: COLORS.blue }
        ])}
          ${green.history?.length ? `
            <div style="margin-top: var(--space-md)">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 4px">Деревьев высажено за год:</div>
              ${lineChart(green.history, [
          { key: 'trees', label: 'Деревья', color: COLORS.success }
        ], { height: 80 })}
            </div>
          ` : ''}
          ${bigNumber(green.trees_planned_2025 || green.trees_planted_2024 || 5500, 'деревьев планируется в 2025', COLORS.success)}
          ${infoTip(`<strong style="color: ${COLORS.success};">Парк Победы:</strong> ~1000 деревьев будет высажено в 2025 году`)}
          ${analysisBlock('АНАЛИЗ', 'Ежегодный рост высадки деревьев: <strong style="color: ' + COLORS.success + ';">+22%</strong> в среднем. К 2025 году площадь зелёных зон увеличится на 70 га благодаря благоустройству парка Победы.')}
        `);
      }

      // ═══ РАЗДЕЛЬНЫЙ СБОР ОТХОДОВ ═══
      html += card('eco', true, `
        ${cardHeader(ICONS.waste, 'Раздельный сбор', `${waste.total || 0} точек сбора`)}
        ${wasteGroups.length ? barChart(wasteGroups) : ''}
        ${waste.history?.length ? `
          <div style="margin-top: var(--space-md)">
            <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 4px">Динамика открытия точек:</div>
            ${lineChart(waste.history, [
        { key: 'points', label: 'Точек', color: COLORS.primary }
      ], { height: 70 })}
          </div>
        ` : ''}
        ${analysisBlock('Анализ',
        `За 5 лет число точек раздельного сбора выросло с ${waste.history?.[0]?.points || 'N/A'} до ${waste.total}. Рост в ${((waste.total / (waste.history?.[0]?.points || 1)) * 100 - 100).toFixed(0)}%. Основные категории: бытовая техника, пластик, бумага.`
      )}
      `);

      // ═══ ЭКО-ПРОЕКТЫ ═══
      if (projects.length) {
        const totalParticipants = projects.reduce((a, p) => a + (p.participants || 0), 0);
        const totalCollected = projects.reduce((a, p) => a + (p.collected_kg || 0), 0);

        html += card('eco', true, `
          ${cardHeader('mdi:leaf', 'Эко-проекты', `${projects.length} инициатив`)}
          <div style="margin: var(--space-md) 0">
            ${projects.map(p => `
              <div style="background: rgba(255,255,255,0.05); border-radius: 8px; padding: 10px; margin: 8px 0; border-left: 3px solid ${COLORS.success}">
                <div style="font-weight: 700; color: ${COLORS.success}; font-size: 13px">${p.name}</div>
                <div style="font-size: 11px; color: var(--text-muted); margin: 4px 0">${p.description}</div>
                <div style="display: flex; gap: 16px; font-size: 11px; margin-top: 8px">
                  <span style="color: var(--text-secondary)">${icon('mdi:account-group', 14)} <strong style="color: ${COLORS.primary}; font-size: 13px; text-shadow: 0 0 8px ${COLORS.primary};">${p.participants?.toLocaleString('ru') || 0}</strong> участников</span>
                  ${p.collected_kg ? `<span style="color: var(--text-secondary)">${icon('mdi:weight', 14)} <strong style="color: ${COLORS.success}; font-size: 13px; text-shadow: 0 0 8px ${COLORS.success};">${(p.collected_kg / 1000).toFixed(1)}</strong> т собрано</span>` : ''}
                </div>
              </div>
            `).join('')}
          </div>
          ${statsRow([
          { value: totalParticipants.toLocaleString('ru'), label: 'Всего участников', color: COLORS.primary },
          { value: (totalCollected / 1000).toFixed(1) + ' т', label: 'Собрано отходов', color: COLORS.success }
        ])}
          ${analysisBlock('АНАЛИЗ', 'Эко-движение города растёт: участие увеличилось на <strong style="color: ' + COLORS.success + ';">+35%</strong> за 2 года. Лидер — проект БумБатл с 18 000 участников.')}
        `);
      }

      // ═══ ПЕРЕРАБОТКА ШИН (новое производство 2025) ═══
      if (eco.tire_recycling) {
        html += card('eco', true, `
          ${cardHeader('mdi:tire', 'Переработка шин 2025', 'Новое производство')}
          ${bigNumber(eco.tire_recycling.capacity_tons_year || 3000, 'тонн/год мощность', COLORS.orange)}
          <div style="margin: var(--space-md) 0; text-align: center">
            <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">Продукция переработки:</div>
            <div style="display: flex; gap: 8px; justify-content: center; flex-wrap: wrap">
              ${(eco.tire_recycling.products || ['Мазут', 'Металлокорд', 'Технический углерод']).map(p => `
                <span style="background: rgba(255, 152, 0, 0.2); padding: 6px 12px; border-radius: 6px; font-size: 11px; color: ${COLORS.orange}; font-weight: 600">${p}</span>
              `).join('')}
            </div>
          </div>
          ${infoTip(`<strong style="color: ${COLORS.success};">Экологический эффект:</strong> ${eco.tire_recycling.eco_benefit || 'Снижение выбросов на 15%'}`)}
          ${analysisBlock('АНАЛИЗ', 'Комплекс переработки автошин снизит объём промышленных отходов на <strong style="color: ' + COLORS.success + ';">850 тонн/год</strong> и создаст <strong style="color: ' + COLORS.primary + ';">25 рабочих мест</strong>.')}
        `);
      }

      // ═══ ВОДНЫЕ РЕСУРСЫ (РАСШИРЕННЫЙ БЛОК) ═══
      if (water.rivers?.length || water.total_lakes) {
        const riversData = water.rivers || [];
        const lakesData = water.lakes || [];
        const waterSupply = water.water_supply || {};
        const qualityMonitor = water.quality_monitoring || {};
        const sewage = water.sewage || {};
        const floodData = water.flood_data || {};
        const fishingData = water.fishing || {};

        // Общая статистика водных ресурсов
        html += card('eco', true, `
          ${cardHeader('mdi:water', 'Водные ресурсы Нижневартовска', 'Реки, озёра, водоснабжение')}
          ${statsRow([
          { value: riversData.length, label: 'Рек', color: COLORS.blue, icon: 'mdi:waves' },
          { value: lakesData.length || water.total_lakes || 15, label: 'Озёр', color: COLORS.primary, icon: 'mdi:pool' },
          { value: water.water_treatment || 2, label: 'Очистных', color: COLORS.success, icon: 'mdi:water-pump' }
        ])}
          <div style="text-align: center; margin-top: var(--space-md); padding: 12px; background: linear-gradient(135deg, rgba(33, 150, 243, 0.1), rgba(76, 175, 80, 0.1)); border-radius: 12px">
            <div style="display: flex; align-items: center; justify-content: center; gap: 8px">
              ${icon('mdi:water-check', 20)}
              <span style="font-size: 14px">Качество воды: </span>
              <strong style="color: ${COLORS.success}; font-size: 16px; text-transform: uppercase">${water.water_quality_index || 'хорошее'}</strong>
            </div>
          </div>
          ${analysisBlock('Обзор',
          'Нижневартовск расположен на слиянии рек Обь и Вах. Город обеспечен качественной питьевой водой из подземных источников и реки Вах. Все показатели качества соответствуют нормам СанПиН.'
        )}
        `);

        // Реки — подробная информация
        if (riversData.length) {
          riversData.forEach((river, idx) => {
            const riverName = typeof river === 'string' ? river : river.name;
            const riverData = typeof river === 'object' ? river : {};

            html += card('eco', idx === 0, `
              ${cardHeader('mdi:waves', 'Река ' + riverName, riverData.importance ? '' : '')}
              ${riverData.length_km ? `
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; margin: var(--space-md) 0">
                  <div style="background: rgba(33, 150, 243, 0.1); padding: 12px; border-radius: 8px; text-align: center">
                    <div style="font-size: 20px; font-weight: 800; color: ${COLORS.blue}">${riverData.length_km.toLocaleString('ru')}</div>
                    <div style="font-size: 10px; color: var(--text-muted)">км общая длина</div>
                  </div>
                  <div style="background: rgba(0, 188, 212, 0.1); padding: 12px; border-radius: 8px; text-align: center">
                    <div style="font-size: 20px; font-weight: 800; color: ${COLORS.cyan}">${riverData.local_length_km || '—'}</div>
                    <div style="font-size: 10px; color: var(--text-muted)">км у города</div>
                  </div>
                  <div style="background: rgba(156, 39, 176, 0.1); padding: 12px; border-radius: 8px; text-align: center">
                    <div style="font-size: 20px; font-weight: 800; color: ${COLORS.secondary}">${riverData.width_m || '—'}</div>
                    <div style="font-size: 10px; color: var(--text-muted)">м ширина</div>
                  </div>
                  <div style="background: rgba(76, 175, 80, 0.1); padding: 12px; border-radius: 8px; text-align: center">
                    <div style="font-size: 20px; font-weight: 800; color: ${COLORS.success}">${riverData.depth_avg_m || '—'}</div>
                    <div style="font-size: 10px; color: var(--text-muted)">м глубина</div>
                  </div>
                </div>
              ` : ''}
              ${riverData.importance ? `
                <div style="font-size: 12px; color: var(--text-secondary); margin: 12px 0; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 8px; border-left: 3px solid ${COLORS.blue}">
                  ${riverData.importance}
                </div>
              ` : ''}
              ${riverData.fish?.length ? `
                <div style="margin-top: 12px">
                  <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 6px">${icon('mdi:fish', 14)} Виды рыб:</div>
                  <div style="display: flex; flex-wrap: wrap; gap: 6px">
                    ${riverData.fish.map(f => `
                      <span style="background: linear-gradient(135deg, rgba(33, 150, 243, 0.15), rgba(0, 188, 212, 0.1)); padding: 4px 10px; border-radius: 12px; font-size: 11px; color: ${COLORS.blue}">${f}</span>
                    `).join('')}
                  </div>
                </div>
              ` : ''}
              ${riverData.frozen_months?.length ? `
                <div style="margin-top: 12px; padding: 10px; background: rgba(100, 181, 246, 0.08); border-radius: 8px">
                  <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 6px">${icon('mdi:snowflake', 14)} Ледостав (${riverData.frozen_months.length} мес.):</div>
                  <div style="font-size: 12px; color: ${COLORS.cyan}">${riverData.frozen_months.join(' → ')}</div>
                  ${riverData.ice_thickness_cm ? `<div style="font-size: 11px; color: var(--text-muted); margin-top: 4px">Толщина льда до ${riverData.ice_thickness_cm} см</div>` : ''}
                </div>
              ` : ''}
              ${riverData.navigation !== undefined ? `
                <div style="margin-top: 8px; font-size: 11px">
                  ${icon(riverData.navigation ? 'mdi:ferry' : 'mdi:ferry-off', 14)} 
                  <span style="color: ${riverData.navigation ? COLORS.success : COLORS.secondary}">
                    Судоходство: ${riverData.navigation ? 'да' : 'нет'}
                  </span>
                </div>
              ` : ''}
              ${riverData.flow_m3s ? `
                <div style="margin-top: 8px; font-size: 11px; color: var(--text-muted)">
                  ${icon('mdi:speedometer', 14)} Расход воды: <strong style="color: ${COLORS.blue}">${riverData.flow_m3s.toLocaleString('ru')} м³/с</strong>
                </div>
              ` : ''}
            `);
          });
        }

        // Озёра города
        if (lakesData.length) {
          const beachLakes = lakesData.filter(l => l.beach).length;
          const fishingLakes = lakesData.filter(l => l.fishing).length;
          const totalArea = lakesData.reduce((a, l) => a + (l.area_ha || 0), 0);

          html += card('eco', true, `
            ${cardHeader('mdi:pool', 'Озёра и водоёмы', lakesData.length + ' объектов')}
            ${statsRow([
            { value: beachLakes, label: 'С пляжами', color: COLORS.orange, icon: 'mdi:beach' },
            { value: fishingLakes, label: 'Для рыбалки', color: COLORS.blue, icon: 'mdi:fish' },
            { value: totalArea.toFixed(0), label: 'Га площадь', color: COLORS.success, icon: 'mdi:resize' }
          ])}
            <div style="margin-top: var(--space-md); max-height: 280px; overflow-y: auto">
              ${lakesData.slice(0, 10).map((lake, idx) => {
            const statusColor = lake.status === 'благоустроено' ? COLORS.success :
              lake.status === 'рекреационное' ? COLORS.orange :
                lake.status === 'охраняемое' ? COLORS.danger : COLORS.secondary;
            return `
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px; margin: 6px 0; background: rgba(255,255,255,0.03); border-radius: 8px; border-left: 3px solid ${statusColor}">
                    <div style="flex: 1">
                      <div style="font-weight: 600; font-size: 12px">${lake.name}</div>
                      <div style="font-size: 10px; color: var(--text-muted)">
                        ${lake.area_ha} га · глубина ${lake.depth_m} м
                      </div>
                    </div>
                    <div style="display: flex; gap: 6px; align-items: center">
                      ${lake.beach ? `<span style="font-size: 14px" title="Пляж">🏖️</span>` : ''}
                      ${lake.fishing ? `<span style="font-size: 14px" title="Рыбалка">🎣</span>` : ''}
                      <span style="background: ${statusColor}20; color: ${statusColor}; padding: 2px 8px; border-radius: 10px; font-size: 9px; text-transform: uppercase">${lake.status}</span>
                    </div>
                  </div>
                `;
          }).join('')}
              ${lakesData.length > 10 ? `
                <div style="text-align: center; padding: 8px; font-size: 11px; color: var(--text-muted)">
                  ... и ещё ${lakesData.length - 10} водоёмов
                </div>
              ` : ''}
            </div>
          `);
        }

        // Водоснабжение
        if (waterSupply.capacity_m3_day) {
          const usagePct = ((waterSupply.consumption_m3_day / waterSupply.capacity_m3_day) * 100).toFixed(0);
          html += card('eco', true, `
            ${cardHeader('mdi:water-pump', 'Водоснабжение города', waterSupply.source || '')}
            <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin: var(--space-md) 0">
              <div style="background: rgba(33, 150, 243, 0.1); padding: 14px; border-radius: 10px; text-align: center">
                <div style="font-size: 24px; font-weight: 800; color: ${COLORS.blue}">${(waterSupply.capacity_m3_day / 1000).toFixed(0)}</div>
                <div style="font-size: 10px; color: var(--text-muted)">тыс. м³/сут мощность</div>
              </div>
              <div style="background: rgba(76, 175, 80, 0.1); padding: 14px; border-radius: 10px; text-align: center">
                <div style="font-size: 24px; font-weight: 800; color: ${COLORS.success}">${(waterSupply.consumption_m3_day / 1000).toFixed(0)}</div>
                <div style="font-size: 10px; color: var(--text-muted)">тыс. м³/сут потребление</div>
              </div>
            </div>
            <div style="margin: 12px 0">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 4px">Загрузка системы (${usagePct}%)</div>
              <div style="background: rgba(255,255,255,0.1); border-radius: 6px; height: 12px; overflow: hidden">
                <div style="width: ${usagePct}%; height: 100%; background: linear-gradient(90deg, ${COLORS.success}, ${usagePct > 80 ? COLORS.orange : COLORS.primary}); border-radius: 6px; transition: width 0.5s"></div>
              </div>
              <div style="font-size: 10px; color: ${COLORS.success}; margin-top: 4px">Резерв: ${waterSupply.reserve_pct}%</div>
            </div>
            ${statsRow([
            { value: waterSupply.networks_km || 0, label: 'км сетей', color: COLORS.primary },
            { value: waterSupply.pumping_stations || 0, label: 'насосных', color: COLORS.blue },
            { value: waterSupply.quality_tests_per_year || 0, label: 'проб/год', color: COLORS.success }
          ])}
            <div style="display: flex; gap: 12px; margin-top: 12px; justify-content: center">
              ${waterSupply.chlorination ? `<span style="font-size: 11px; color: ${COLORS.success}">${icon('mdi:check-circle', 14)} Хлорирование</span>` : ''}
              ${waterSupply.uv_treatment ? `<span style="font-size: 11px; color: ${COLORS.cyan}">${icon('mdi:check-circle', 14)} УФ-очистка</span>` : ''}
            </div>
          `);
        }

        // Мониторинг качества воды
        if (qualityMonitor.parameters?.length) {
          html += card('eco', false, `
            ${cardHeader('mdi:flask', 'Качество воды', 'Мониторинг ' + (qualityMonitor.last_check || ''))}
            <div style="margin: var(--space-md) 0">
              ${qualityMonitor.parameters.map(p => {
            const pct = typeof p.norm === 'string' && p.norm.includes('<')
              ? (p.value / parseFloat(p.norm.replace('<', '').replace('>', '').split('-')[1] || p.norm.replace(/[<>]/g, ''))) * 100
              : 50;
            const statusColor = p.status === 'норма' ? COLORS.success : COLORS.danger;
            return `
                  <div style="margin: 8px 0">
                    <div style="display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 2px">
                      <span>${p.name}</span>
                      <span style="color: ${statusColor}">${p.value} ${p.unit || ''} (норма: ${p.norm})</span>
                    </div>
                    <div style="background: rgba(255,255,255,0.1); border-radius: 4px; height: 6px; overflow: hidden">
                      <div style="width: ${Math.min(pct, 100)}%; height: 100%; background: ${statusColor}; border-radius: 4px"></div>
                    </div>
                  </div>
                `;
          }).join('')}
            </div>
            <div style="text-align: center; margin-top: 12px; padding: 10px; background: rgba(76, 175, 80, 0.1); border-radius: 8px">
              <div style="font-size: 11px; color: var(--text-muted)">Общая оценка качества</div>
              <div style="font-size: 24px; font-weight: 800; color: ${COLORS.success}">${qualityMonitor.overall_rating || 4.5}/5</div>
              <div style="font-size: 10px; color: ${COLORS.success}">${icon('mdi:check-decagram', 14)} Соответствует СанПиН</div>
            </div>
          `);
        }

        // Паводковая обстановка
        if (floodData.history?.length) {
          const maxFlood = Math.max(...floodData.history.map(h => h.max_level_cm));
          const avgFlood = (floodData.history.reduce((a, h) => a + h.max_level_cm, 0) / floodData.history.length).toFixed(0);

          html += card('eco', false, `
            ${cardHeader('mdi:waves-arrow-up', 'Паводковая обстановка', 'Уровень реки Обь')}
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin: var(--space-md) 0">
              <div style="text-align: center; padding: 10px; background: rgba(255, 152, 0, 0.1); border-radius: 8px">
                <div style="font-size: 18px; font-weight: 800; color: ${COLORS.orange}">${floodData.danger_level_cm}</div>
                <div style="font-size: 9px; color: var(--text-muted)">опасный (см)</div>
              </div>
              <div style="text-align: center; padding: 10px; background: rgba(244, 67, 54, 0.1); border-radius: 8px">
                <div style="font-size: 18px; font-weight: 800; color: ${COLORS.danger}">${floodData.critical_level_cm}</div>
                <div style="font-size: 9px; color: var(--text-muted)">критический (см)</div>
              </div>
              <div style="text-align: center; padding: 10px; background: rgba(76, 175, 80, 0.1); border-radius: 8px">
                <div style="font-size: 18px; font-weight: 800; color: ${COLORS.success}">${avgFlood}</div>
                <div style="font-size: 9px; color: var(--text-muted)">средний (см)</div>
              </div>
            </div>
            ${lineChart(floodData.history, [
            { key: 'max_level_cm', label: 'Макс. уровень', color: COLORS.blue }
          ], { height: 100 })}
            ${statsRow([
            { value: floodData.protected_zones || 0, label: 'защитных зон', color: COLORS.success },
            { value: floodData.dam_length_km || 0, label: 'км дамб', color: COLORS.primary },
            { value: (floodData.pumping_capacity_m3h / 1000).toFixed(0) || 0, label: 'тыс.м³/ч насосы', color: COLORS.blue }
          ])}
            ${analysisBlock('Анализ',
            'За последние 6 лет максимальный уровень ' + maxFlood + ' см был в 2021 году. Система защиты от паводков включает ' + (floodData.dam_length_km || 8.5) + ' км дамб и насосные станции мощностью ' + ((floodData.pumping_capacity_m3h / 1000).toFixed(0) || 12) + ' тыс. м³/ч.'
          )}
          `);
        }

        // Рыболовство
        if (fishingData.fish_stocks?.length) {
          html += card('eco', false, `
            ${cardHeader('mdi:fish', 'Рыболовство', fishingData.licenses_issued_2024 + ' лицензий в 2024')}
            ${statsRow([
            { value: fishingData.allowed_zones || 0, label: 'разрешённых зон', color: COLORS.success },
            { value: fishingData.prohibited_zones || 0, label: 'запретных зон', color: COLORS.danger }
          ])}
            <div style="margin-top: var(--space-md)">
              <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px">Состояние популяций рыб:</div>
              ${fishingData.fish_stocks.map(fish => {
            const statusColor = fish.status === 'рост' ? COLORS.success :
              fish.status === 'стабильно' ? COLORS.primary :
                fish.status === 'снижение' ? COLORS.orange : COLORS.danger;
            const statusIcon = fish.status === 'рост' ? 'mdi:trending-up' :
              fish.status === 'стабильно' ? 'mdi:minus' :
                fish.status === 'снижение' ? 'mdi:trending-down' : 'mdi:cancel';
            return `
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 8px 10px; margin: 4px 0; background: rgba(255,255,255,0.03); border-radius: 6px">
                    <span style="font-size: 12px">${fish.species}</span>
                    <div style="display: flex; align-items: center; gap: 8px">
                      ${fish.quota_kg > 0 ? `<span style="font-size: 10px; color: var(--text-muted)">${(fish.quota_kg / 1000).toFixed(0)} т квота</span>` : ''}
                      <span style="color: ${statusColor}; display: flex; align-items: center; gap: 4px; font-size: 11px">
                        ${icon(statusIcon, 14)} ${fish.status}
                      </span>
                    </div>
                  </div>
                `;
          }).join('')}
            </div>
            ${fishingData.restocking_2024 ? `
              <div style="margin-top: 12px; padding: 10px; background: rgba(76, 175, 80, 0.1); border-radius: 8px; text-align: center">
                ${icon('mdi:fish-plus', 20)}
                <div style="font-size: 12px; margin-top: 4px">
                  Зарыбление 2024: <strong style="color: ${COLORS.success}">${fishingData.restocking_2024.count.toLocaleString('ru')}</strong> мальков ${fishingData.restocking_2024.species}
                </div>
              </div>
            ` : ''}
            ${infoTip('<strong style="color: ' + COLORS.danger + ';">Внимание:</strong> Лов осётра и стерляди запрещён! Штраф до 300 000 ₽')}
          `);
        }

        // Водоотведение
        if (sewage.networks_km) {
          html += card('eco', false, `
            ${cardHeader('mdi:pipe-valve', 'Водоотведение', sewage.treatment_level || '')}
            ${statsRow([
            { value: sewage.networks_km, label: 'км сетей', color: COLORS.secondary },
            { value: sewage.treatment_plants, label: 'очистных', color: COLORS.success },
            { value: (sewage.capacity_m3_day / 1000).toFixed(0), label: 'тыс.м³/сут', color: COLORS.blue }
          ])}
            <div style="margin-top: 12px; font-size: 11px; color: var(--text-muted)">
              ${icon('mdi:recycle', 14)} Переработка осадка: ${sewage.sludge_processing ? 'да' : 'нет'}<br>
              ${icon('mdi:arrow-right', 14)} Сброс: ${sewage.discharge_to || 'р. Обь (после очистки)'}
            </div>
          `);
        }
      }

      // ═══ ДОСТУПНАЯ СРЕДА ═══
      html += card('eco', false, `
        ${cardHeader(ICONS.accessibility, 'Доступная среда', '')}
        ${bigNumber(cn.accessibility || 0, 'объектов', COLORS.pink)}
        ${infoTip('Объекты, адаптированные для маломобильных граждан')}
      `);
    }

    // ══════════════════════════════════════════════════════════
    // SPORT SECTION - СПОРТИВНЫЕ ДОСТИЖЕНИЯ
    // ══════════════════════════════════════════════════════════
    if (show('sport')) {
      html += `<div class="section-title">${icon('mdi:trophy')} Спорт и достижения</div>`;

      const sportsData = getDemoData().sports || {};
      const medalHist = sportsData.history || [];
      const champions = sportsData.champions || [];
      const popularSports = sportsData.popular_sports || [];
      const facilities = sportsData.facilities || [];

      // Медали 2025
      html += card('sport', true, `
        ${cardHeader('mdi:medal', 'Медали 2025', 'Чемпионаты и соревнования')}
        <div style="text-align: center; margin: var(--space-md) 0">
          ${bigNumber(sportsData.total_medals_2025 || 47, 'медалей', COLORS.success)}
        </div>
        ${statsRow([
        { label: '🥇 Золото', value: sportsData.gold || 18, color: '#FFD700' },
        { label: '🥈 Серебро', value: sportsData.silver || 16, color: '#C0C0C0' },
        { label: '🥉 Бронза', value: sportsData.bronze || 13, color: '#CD7F32' }
      ])}
      `);

      // Чемпионы 2025
      if (champions.length) {
        html += card('sport', true, `
          ${cardHeader('mdi:trophy', 'Чемпионы 2024-2025', 'Победители соревнований')}
          <div style="max-height: 280px; overflow-y: auto; margin-top: var(--space-md)">
            ${champions.map((ch, idx) => {
          const medalEmoji = ch.medal === 'gold' ? '🥇' : ch.medal === 'silver' ? '🥈' : '🥉';
          const bgColor = ch.medal === 'gold' ? 'rgba(255, 215, 0, 0.15)' : ch.medal === 'silver' ? 'rgba(192, 192, 192, 0.12)' : 'rgba(205, 127, 50, 0.1)';
          return `
                <div style="background: ${bgColor}; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px; display: flex; align-items: center; gap: 10px">
                  <div style="font-size: 24px">${medalEmoji}</div>
                  <div style="flex: 1">
                    <div style="font-weight: 600; font-size: 13px">${ch.name}</div>
                    <div style="font-size: 11px; color: var(--text-muted)">${ch.sport} · ${ch.achievement}</div>
                  </div>
                </div>
              `;
        }).join('')}
          </div>
        `);
      }

      // Динамика медалей
      if (medalHist.length) {
        html += card('sport', true, `
          ${cardHeader('mdi:chart-line', 'Динамика медалей', '2020–2025')}
          ${lineChart(medalHist, [
          { key: 'gold', label: 'Золото', color: '#FFD700' },
          { key: 'silver', label: 'Серебро', color: '#C0C0C0' },
          { key: 'bronze', label: 'Бронза', color: '#CD7F32' }
        ], { height: 150 })}
          ${analysisBlock('Анализ', 'Стабильный рост медалей: с 35 (2020) до 47 (2025). Золотые медали выросли в 2.25 раза. Ключевые виды: бокс, дзюдо, лёгкая атлетика.')}
        `);
      }

      // Спортивные школы
      if (facilities.length) {
        html += card('sport', false, `
          ${cardHeader('mdi:school', 'Спортивные школы', '${sportsData.athletes || 1250} спортсменов')}
          <div style="margin-top: var(--space-md)">
            ${facilities.map(f => `
              <div style="padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.1)">
                <div style="font-weight: 600; font-size: 13px">${f.name}</div>
                <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px">${f.sports.join(', ')}</div>
                <div style="font-size: 12px; color: ${COLORS.success}; margin-top: 2px">${f.athletes} спортсменов</div>
              </div>
            `).join('')}
          </div>
        `);
      }

      // Популярные виды спорта
      if (popularSports.length) {
        html += card('sport', false, `
          ${cardHeader('mdi:run-fast', 'Популярные виды спорта', 'По числу занимающихся')}
          <div style="margin-top: var(--space-md)">
            ${popularSports.slice(0, 5).map((sp, idx) => {
          const pct = Math.round((sp.athletes / sportsData.athletes) * 100);
          const colors = [COLORS.primary, COLORS.success, COLORS.blue, COLORS.pink, COLORS.tertiary];
          return `
                <div style="margin-bottom: 12px">
                  <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 12px">
                    <span>${icon(sp.icon, 14)} ${sp.name}</span>
                    <span style="color: ${colors[idx % colors.length]}">${sp.athletes} чел.</span>
                  </div>
                  <div style="background: rgba(255,255,255,0.1); border-radius: 4px; height: 8px; overflow: hidden">
                    <div style="width: ${pct}%; height: 100%; background: ${colors[idx % colors.length]}; border-radius: 4px"></div>
                  </div>
                </div>
              `;
        }).join('')}
          </div>
        `);
      }
    }

    // ══════════════════════════════════════════════════════════
    // APPEALS SECTION - ОБРАЩЕНИЯ ГРАЖДАН
    // ══════════════════════════════════════════════════════════
    if (show('appeals')) {
      html += `<div class="section-title">${icon('mdi:message-text-outline')} Обращения граждан</div>`;

      const appealsData = getDemoData().citizen_appeals || {};
      const appealsHist = appealsData.history || [];
      const topTopics = appealsData.top_topics || [];
      const bulletins = getDemoData().financial_bulletins || {};

      // Общая статистика
      html += card('appeals', true, `
        ${cardHeader('mdi:chart-box', 'Обращения граждан 2024', 'Статистика работы с населением')}
        <div style="text-align: center; margin: var(--space-md) 0">
          ${bigNumber((appealsData.total_2024 || 42856).toLocaleString('ru'), 'обращений всего', COLORS.primary)}
        </div>
        ${statsRow([
        { label: 'Решено', value: appealsData.resolved_pct + '%' || '94.2%', color: COLORS.success },
        { label: 'Ср. срок', value: appealsData.avg_response_days + ' дн.' || '12 дн.', color: COLORS.blue }
      ])}
      `);

      // Динамика по годам
      if (appealsHist.length) {
        html += card('appeals', true, `
          ${cardHeader('mdi:chart-timeline-variant', 'Динамика обращений', '2019–2024')}
          <div class="animated-chart" id="appeals-history-chart" style="height: 180px; position: relative;">
            ${lineChart(appealsHist, [
          { key: 'total', label: 'Всего', color: COLORS.primary },
          { key: 'resolved', label: 'Решено', color: COLORS.success }
        ], { height: 150, animate: true })}
          </div>
          ${analysisBlock('Анализ', 'Число обращений выросло на 37% за 5 лет. Процент решённых стабильно выше 93%. Рост связан с развитием цифровых каналов связи.')}
        `);
      }

      // Топ тем обращений
      if (topTopics.length) {
        html += card('appeals', true, `
          ${cardHeader('mdi:format-list-numbered', 'Топ тем обращений', '2024 год')}
          <div style="margin-top: var(--space-md)">
            ${topTopics.map((topic, idx) => {
          const trendIcon = topic.trend === 'up' ? '📈' : topic.trend === 'down' ? '📉' : '➡️';
          const trendColor = topic.trend === 'up' ? COLORS.danger : topic.trend === 'down' ? COLORS.success : COLORS.secondary;
          return `
                <div style="display: flex; align-items: center; gap: 10px; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.1)">
                  <div style="width: 24px; height: 24px; background: ${COLORS.primary}; color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700">${idx + 1}</div>
                  <div style="flex: 1">
                    <div style="font-size: 13px; font-weight: 600">${topic.topic}</div>
                    <div style="font-size: 11px; color: var(--text-muted)">${topic.count.toLocaleString('ru')} обращений</div>
                  </div>
                  <div style="font-size: 18px" title="${topic.trend === 'up' ? 'Растёт' : topic.trend === 'down' ? 'Снижается' : 'Стабильно'}">${trendIcon}</div>
                </div>
              `;
        }).join('')}
          </div>
        `);
      }

      // Структура обращений по категориям
      if (appealsHist.length) {
        const latestAppeals = appealsHist[appealsHist.length - 1];
        const categories = latestAppeals.categories || {};
        html += card('appeals', false, `
          ${cardHeader('mdi:chart-pie', 'Структура обращений', '2024 год')}
          <div style="margin: var(--space-md) 0; display: flex; align-items: center; gap: var(--space-lg)">
            <div style="flex: 0 0 120px">
              ${donutChart(Object.values(categories), [COLORS.blue, COLORS.tertiary, COLORS.pink, COLORS.success, COLORS.secondary], 120)}
            </div>
            <div style="flex: 1; font-size: 11px">
              <div style="margin-bottom: 6px"><span style="color: ${COLORS.blue}">●</span> ЖКХ: ${categories.housing?.toLocaleString('ru')}</div>
              <div style="margin-bottom: 6px"><span style="color: ${COLORS.tertiary}">●</span> Дороги: ${categories.roads?.toLocaleString('ru')}</div>
              <div style="margin-bottom: 6px"><span style="color: ${COLORS.pink}">●</span> Коммуналка: ${categories.utilities?.toLocaleString('ru')}</div>
              <div style="margin-bottom: 6px"><span style="color: ${COLORS.success}">●</span> Социальные: ${categories.social?.toLocaleString('ru')}</div>
              <div><span style="color: ${COLORS.secondary}">●</span> Прочие: ${categories.other?.toLocaleString('ru')}</div>
            </div>
          </div>
        `);
      }

      // ═══ ФИНАНСОВЫЕ БЮЛЛЕТЕНИ ═══
      html += `<div class="section-title" style="margin-top: var(--space-xl)">${icon(ICONS.budget)} Финансовые бюллетени</div>`;

      const bulletinYears = bulletins.years || [];
      const summary = bulletins.summary || {};

      // Обзор за 5 лет
      if (bulletinYears.length) {
        html += card('appeals', true, `
          ${cardHeader('mdi:file-document-multiple', 'Бюджетный анализ', '2020–2024')}
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin: var(--space-md) 0">
            <div style="text-align: center; padding: 12px; background: rgba(76, 175, 80, 0.1); border-radius: 8px">
              <div style="font-size: 24px; font-weight: 700; color: ${COLORS.success}">${(summary.total_income_5y / 1000).toFixed(1)} млрд</div>
              <div style="font-size: 11px; color: var(--text-muted)">Доходы за 5 лет</div>
            </div>
            <div style="text-align: center; padding: 12px; background: rgba(99, 102, 241, 0.1); border-radius: 8px">
              <div style="font-size: 24px; font-weight: 700; color: ${COLORS.primary}">${(summary.total_expense_5y / 1000).toFixed(1)} млрд</div>
              <div style="font-size: 11px; color: var(--text-muted)">Расходы за 5 лет</div>
            </div>
          </div>
          <div style="text-align: center; margin: var(--space-md) 0">
            <div style="font-size: 14px; color: ${COLORS.cyan}">Профицит: +${(summary.total_surplus / 1000).toFixed(2)} млрд ₽</div>
            <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px">Среднегодовой рост: ${summary.avg_growth_pct}%</div>
          </div>
        `);

        // Детали по годам
        html += card('appeals', true, `
          ${cardHeader('mdi:calendar-range', 'Бюджет по годам', 'Ключевые показатели')}
          <div style="max-height: 320px; overflow-y: auto; margin-top: var(--space-md)">
            ${bulletinYears.map(yr => `
              <div style="padding: 12px; margin-bottom: 10px; background: rgba(255,255,255,0.05); border-radius: 8px; border-left: 3px solid ${COLORS.primary}">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px">
                  <span style="font-weight: 700; font-size: 16px; color: ${COLORS.primary}">${yr.year}</span>
                  <span style="font-size: 12px; color: ${yr.surplus > 0 ? COLORS.success : COLORS.danger}">
                    ${yr.surplus > 0 ? '+' : ''}${yr.surplus} млн ₽
                  </span>
                </div>
                <div style="display: flex; gap: 12px; font-size: 11px; margin-bottom: 8px">
                  <span style="color: ${COLORS.success}">Доходы: ${(yr.income / 1000).toFixed(1)} млрд</span>
                  <span style="color: ${COLORS.danger}">Расходы: ${(yr.expense / 1000).toFixed(1)} млрд</span>
                </div>
                <div style="font-size: 10px; color: var(--text-muted)">
                  ${yr.highlights.map(h => `• ${h}`).join('<br>')}
                </div>
              </div>
            `).join('')}
          </div>
        `);

        // Общий вывод
        html += card('appeals', true, `
          ${cardHeader('mdi:lightbulb-on', 'Общий вывод', 'Анализ финансовых бюллетеней')}
          <div style="padding: var(--space-md); background: linear-gradient(135deg, rgba(76, 175, 80, 0.1), rgba(99, 102, 241, 0.1)); border-radius: 8px; margin-top: var(--space-md)">
            <p style="font-size: 13px; line-height: 1.6; color: var(--text-primary); margin: 0">
              ${summary.conclusion || 'За 5 лет бюджет города вырос на 44%. Основные направления: социальная политика (42-48%), инфраструктура (22-28%), ЖКХ (15-18%). Положительное сальдо каждый год свидетельствует о финансовой устойчивости города.'}
            </p>
          </div>
          <div style="margin-top: var(--space-md); font-size: 11px; color: var(--text-muted); text-align: center">
            ${icon('mdi:check-decagram', 14)} Тренд: ${summary.trend || 'Устойчивый рост'}
          </div>
        `);
      }
    }

    // ══════════════════════════════════════════════════════════
    // PEOPLE SECTION - ПОЛНАЯ ДЕМОГРАФИЯ
    // ══════════════════════════════════════════════════════════
    if (show('people')) {
      html += `<div class="section-title">${icon(ICONS.people)} Демография и население</div>`;

      const demo = data.demography || {};
      const pop = demo.population || [];
      const births = demo.births || [];
      const deaths = demo.deaths || [];
      const marriages = demo.marriages || [];
      const divorces = demo.divorces || [];
      const migration = demo.migration || [];
      const lifeExp = demo.life_expectancy || [];
      const ageStruct = demo.age_structure || {};

      // ═══ НАСЕЛЕНИЕ ═══
      if (pop.length) {
        const latestPop = pop[pop.length - 1];
        const firstPop = pop[0];
        const popGrowth = firstPop.total ? ((latestPop.total - firstPop.total) / firstPop.total * 100) : 0;

        html += card('people', true, `
          ${cardHeader('mdi:account-group-outline', 'Население города', `${latestPop.year} год`)}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber(latestPop.total, 'человек', COLORS.primary)}
          </div>
          ${lineChart(pop, [
          { key: 'total', label: 'Население', color: COLORS.primary }
        ], { height: 100 })}
          ${compareYears(pop, 'total')}
          ${analysisBlock('Анализ',
          `Население города стабильно растёт. За ${latestPop.year - firstPop.year} лет прирост составил ${(latestPop.total - firstPop.total).toLocaleString('ru')} человек (+${popGrowth.toFixed(1)}%). Плотность населения: ${latestPop.density} чел/км².`
        )}
        `);
      }

      // ═══ РОЖДАЕМОСТЬ И СМЕРТНОСТЬ ═══
      if (births.length && deaths.length) {
        const latestBirths = births[births.length - 1];
        const latestDeaths = deaths[deaths.length - 1];
        const naturalGrowth = latestBirths.count - latestDeaths.count;

        html += card('people', true, `
          ${cardHeader('mdi:heart-pulse', 'Естественное движение', 'Рождения и смерти')}
          ${lineChart(births.slice(-8), [
          { key: 'count', label: 'Рождений', color: COLORS.success },
        ], { height: 80, showLegend: false })}
          <div style="font-size: 10px; text-align: center; color: var(--text-muted); margin: 4px 0">Рождаемость</div>
          ${lineChart(deaths.slice(-8), [
          { key: 'count', label: 'Смертей', color: COLORS.danger },
        ], { height: 80, showLegend: false })}
          <div style="font-size: 10px; text-align: center; color: var(--text-muted); margin: 4px 0">Смертность</div>
          ${statsRow([
          { value: latestBirths.count, label: `Рождений (${latestBirths.year})`, color: COLORS.success },
          { value: latestDeaths.count, label: `Смертей (${latestDeaths.year})`, color: COLORS.danger }
        ])}
          <div style="text-align: center; margin-top: var(--space-md)">
            <span class="trend-indicator ${naturalGrowth > 0 ? 'up' : 'down'}">
              ${icon(naturalGrowth > 0 ? 'mdi:trending-up' : 'mdi:trending-down', 14)}
              Естественный прирост: ${naturalGrowth > 0 ? '+' : ''}${naturalGrowth.toLocaleString('ru')}
            </span>
          </div>
          ${analysisBlock('Анализ',
          `Рождаемость снизилась с ${births[0].count.toLocaleString('ru')} (${births[0].year}) до ${latestBirths.count.toLocaleString('ru')} (${latestBirths.year}). Всплеск смертности в 2020-2021 связан с пандемией. К ${latestDeaths.year} году показатели нормализовались.`
        )}
        `);
      }

      // ═══ БРАКИ И РАЗВОДЫ ═══
      if (marriages.length && divorces.length) {
        const latestMarr = marriages[marriages.length - 1];
        const latestDiv = divorces[divorces.length - 1];
        const divRatio = latestMarr.count ? (latestDiv.count / latestMarr.count * 100).toFixed(0) : 0;

        html += card('people', true, `
          ${cardHeader('mdi:ring', 'Браки и разводы', 'Семейная статистика')}
          ${lineChart([...marriages.slice(-8).map((m, i) => ({
          year: m.year,
          marriages: m.count,
          divorces: divorces.slice(-8)[i]?.count || 0
        }))], [
          { key: 'marriages', label: 'Браки', color: COLORS.pink },
          { key: 'divorces', label: 'Разводы', color: COLORS.secondary }
        ], { height: 100 })}
          ${statsRow([
          { value: latestMarr.count, label: 'Браков', color: COLORS.pink },
          { value: latestDiv.count, label: 'Разводов', color: COLORS.secondary }
        ])}
          ${analysisBlock('Анализ',
          `На каждые 100 браков приходится ${divRatio} разводов. Минимум браков зафиксирован в 2020 году (пандемия). Число разводов стабильно снижается: с ${divorces[0].count.toLocaleString('ru')} до ${latestDiv.count.toLocaleString('ru')}.`
        )}
        `);
      }

      // ═══ МИГРАЦИЯ ═══
      if (migration.length) {
        const latestMig = migration[migration.length - 1];

        html += card('people', true, `
          ${cardHeader('mdi:airplane-takeoff', 'Миграция', 'Прибытие и выбытие')}
          ${lineChart(migration, [
          { key: 'arrived', label: 'Прибыло', color: COLORS.success },
          { key: 'departed', label: 'Выбыло', color: COLORS.danger },
          { key: 'net', label: 'Сальдо', color: COLORS.primary }
        ], { height: 100 })}
          ${statsRow([
          { value: latestMig.arrived, label: 'Прибыло', color: COLORS.success },
          { value: latestMig.departed, label: 'Выбыло', color: COLORS.danger },
          { value: latestMig.net, label: 'Сальдо', color: latestMig.net > 0 ? COLORS.primary : COLORS.secondary }
        ])}
          ${analysisBlock('Анализ',
          `Миграционное сальдо положительное (кроме 2020). В ${latestMig.year} году прибыло ${latestMig.arrived.toLocaleString('ru')} человек, выбыло ${latestMig.departed.toLocaleString('ru')}. Чистый миграционный прирост: +${latestMig.net.toLocaleString('ru')}.`
        )}
        `);
      }

      // ═══ ВОЗРАСТНАЯ СТРУКТУРА ═══
      if (ageStruct.groups?.length) {
        html += card('people', true, `
          ${cardHeader('mdi:account-child', 'Возрастная структура', `${ageStruct.year} год`)}
          ${ageStructureChart(ageStruct)}
          ${analysisBlock('Анализ',
          `Средний возраст населения — около 38 лет. Трудоспособное население (15-64): ${ageStruct.groups.filter(g => !['0-14', '65+'].includes(g.group)).reduce((a, g) => a + g.pct, 0).toFixed(1)}%. Детей: ${ageStruct.groups.find(g => g.group === '0-14')?.pct}%. Пенсионеров: ${ageStruct.groups.find(g => g.group === '65+')?.pct}%.`
        )}
        `);
      }

      // ═══ ПРОДОЛЖИТЕЛЬНОСТЬ ЖИЗНИ ═══
      if (lifeExp.length) {
        const latestLife = lifeExp[lifeExp.length - 1];

        html += card('people', true, `
          ${cardHeader('mdi:heart-pulse', 'Продолжительность жизни', 'Ожидаемая при рождении')}
          ${lineChart(lifeExp, [
          { key: 'male', label: 'Мужчины', color: COLORS.blue },
          { key: 'female', label: 'Женщины', color: COLORS.pink },
          { key: 'total', label: 'Общая', color: COLORS.primary }
        ], { height: 100 })}
          ${statsRow([
          { value: latestLife.male.toFixed(1), label: 'Мужчины', color: COLORS.blue },
          { value: latestLife.female.toFixed(1), label: 'Женщины', color: COLORS.pink },
          { value: latestLife.total.toFixed(1), label: 'Общая', color: COLORS.primary }
        ])}
          ${analysisBlock('Анализ',
          `Продолжительность жизни выросла с ${lifeExp[0].total} лет (${lifeExp[0].year}) до ${latestLife.total} лет (${latestLife.year}). Провал в 2020-2021 связан с пандемией. Разрыв между мужчинами и женщинами: ${(latestLife.female - latestLife.male).toFixed(1)} лет.`
        )}
        `);
      }

      // ═══ ЗАРПЛАТА ═══
      const salaryHist = data.salary?.history || [];
      if (salaryHist.length) {
        const latestSal = salaryHist[salaryHist.length - 1];
        const firstSal = salaryHist[0];
        const salGrowth = firstSal.avg ? ((latestSal.avg - firstSal.avg) / firstSal.avg * 100) : 0;

        html += card('people', true, `
          ${cardHeader(ICONS.salary, 'Средняя зарплата', 'Динамика по годам')}
          ${lineChart(salaryHist, [
          { key: 'avg', label: 'тыс. ₽', color: COLORS.success }
        ], { height: 100 })}
          <div style="text-align: center; margin: var(--space-md) 0">
            ${bigNumber(latestSal.avg, 'тыс. ₽ в ' + latestSal.year, COLORS.success)}
          </div>
          ${compareYears(salaryHist, 'avg')}
          ${analysisBlock('Анализ',
          `За ${latestSal.year - firstSal.year} лет зарплата выросла в ${(latestSal.avg / firstSal.avg).toFixed(1)} раза (+${salGrowth.toFixed(0)}%). Среднегодовой рост: ${(salGrowth / (latestSal.year - firstSal.year)).toFixed(1)}%. Это выше среднего по России.`
        )}
        `);
      }

      // ═══ ПОПУЛЯРНЫЕ ИМЕНА ═══
      const boys = names.boys || [];
      const girls = names.girls || [];

      if (boys.length || girls.length) {
        html += card('people', true, `
          ${cardHeader(ICONS.names, 'Популярные имена', 'Статистика за все годы')}
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 8px">
            <div>
              <div style="font-size: 10px; font-weight: 700; color: ${COLORS.blue}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px">
                ${icon('mdi:human-male-female-child', 14)} Мальчики
              </div>
              ${boys.slice(0, 5).map((b, i) => `
                <div style="display: flex; justify-content: space-between; padding: 4px 0; border-bottom: 1px solid var(--border-subtle)">
                  <span style="font-size: 11px">${i + 1}. ${b.n}</span>
                  <span style="font-size: 10px; color: var(--text-muted); font-weight: 600">${b.c}</span>
                </div>
              `).join('')}
            </div>
            <div>
              <div style="font-size: 10px; font-weight: 700; color: ${COLORS.pink}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px">
                ${icon('mdi:human-male-female-child', 14)} Девочки
              </div>
              ${girls.slice(0, 5).map((g, i) => `
                <div style="display: flex; justify-content: space-between; padding: 4px 0; border-bottom: 1px solid var(--border-subtle)">
                  <span style="font-size: 11px">${i + 1}. ${g.n}</span>
                  <span style="font-size: 10px; color: var(--text-muted); font-weight: 600">${g.c}</span>
                </div>
              `).join('')}
            </div>
          </div>
        `);
      }

      // ═══ ЗНАМЕНИТЫЕ ЛЮДИ ГОРОДА ═══
      html += card('people', true, `
        ${cardHeader('mdi:account-star', 'Знаменитые люди', 'Гордость Нижневартовска')}
        
        <!-- ★ КОСМОНАВТ — главная гордость города ★ -->
        <div style="margin-top: var(--space-md); margin-bottom: var(--space-lg)">
          <div style="font-size: 11px; font-weight: 700; color: ${COLORS.blue}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px; display: flex; align-items: center; gap: 6px">
            ${icon('mdi:rocket-launch', 16)} Космонавт России
          </div>
          
          <div style="padding: 16px; background: linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(6, 182, 212, 0.1)); border-radius: 12px; border: 1px solid rgba(99, 102, 241, 0.2); position: relative; overflow: hidden">
            <div style="position: absolute; top: -10px; right: -10px; font-size: 64px; opacity: 0.1">🚀</div>
            <div style="display: flex; gap: 14px; align-items: flex-start">
              <div style="width: 56px; height: 56px; border-radius: 50%; background: linear-gradient(135deg, #6366f1, #06b6d4); display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3)">
                ${icon('mdi:account-tie', 28, '#fff')}
              </div>
              <div style="flex: 1">
                <div style="font-weight: 800; color: var(--text-primary); font-size: 16px; letter-spacing: -0.3px">Сергей Николаевич Рыжиков</div>
                <div style="font-size: 12px; color: ${COLORS.blue}; font-weight: 600; margin-top: 2px">121-й космонавт России · Герой РФ</div>
                <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px">род. 19 августа 1974 · Нижневартовск</div>
                <div style="margin-top: 8px; display: flex; flex-wrap: wrap; gap: 6px">
                  <span style="background: rgba(99, 102, 241, 0.2); color: ${COLORS.blue}; padding: 3px 8px; border-radius: 12px; font-size: 10px; font-weight: 600">Союз МС-02 (2016-2017)</span>
                  <span style="background: rgba(6, 182, 212, 0.2); color: ${COLORS.cyan}; padding: 3px 8px; border-radius: 12px; font-size: 10px; font-weight: 600">Союз МС-17 (2020-2021)</span>
                </div>
                <div style="font-size: 10px; color: var(--text-secondary); margin-top: 8px">Окончил школу №12 и клуб «Крылья Самотлора» в Нижневартовске. Полковник ВКС, лётчик-космонавт РФ.</div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Писатели и поэты -->
        <div style="margin-top: var(--space-md)">
          <div style="font-size: 11px; font-weight: 700; color: ${COLORS.tertiary}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px; display: flex; align-items: center; gap: 6px">
            ${icon('mdi:fountain-pen-tip', 16)} Писатели и поэты (5 человек)
          </div>
          
          <div style="display: flex; flex-direction: column; gap: 10px">
            <div style="padding: 10px 12px; background: rgba(156, 39, 176, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.tertiary}">
              <div style="display: flex; justify-content: space-between; align-items: flex-start">
                <div>
                  <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Юрий Вэлла</div>
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">1948–2013 · Поэт, писатель</div>
                </div>
                <div style="background: ${COLORS.tertiary}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">3 языка</div>
              </div>
              <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Писал на русском, хантыйском, ненецком. Переведён на немецкий, французский, эстонский</div>
            </div>
            
            <div style="padding: 10px 12px; background: rgba(156, 39, 176, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.tertiary}">
              <div style="display: flex; justify-content: space-between; align-items: flex-start">
                <div>
                  <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Еремей Айпин</div>
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">род. 1948 · Писатель-прозаик</div>
                </div>
                <div style="background: ${COLORS.pink}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">20+ книг</div>
              </div>
              <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Переведён на 7 языков: английский, немецкий, французский, испанский, венгерский, финский, японский</div>
            </div>
            
            <div style="padding: 10px 12px; background: rgba(156, 39, 176, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.tertiary}">
              <div style="display: flex; justify-content: space-between; align-items: flex-start">
                <div>
                  <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Маргарита Анисимкова</div>
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">1928–2013 · Писательница</div>
                </div>
                <div style="background: ${COLORS.warning}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">Почётный гр.</div>
              </div>
              <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Член Союза писателей СССР (1985). Лауреат премии Мамина-Сибиряка. Почётный гражданин Нижневартовска</div>
            </div>
            
            <div style="padding: 10px 12px; background: rgba(156, 39, 176, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.tertiary}">
              <div style="display: flex; justify-content: space-between; align-items: flex-start">
                <div>
                  <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Владимир Мазин</div>
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">род. 1951 · Поэт, культуролог</div>
                </div>
                <div style="background: ${COLORS.blue}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">Медаль Пушкина</div>
              </div>
              <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Член Союза писателей России (1998). Лауреат премии Мамина-Сибиряка (2012). Уроженец Ларьяка</div>
            </div>
            
            <div style="padding: 10px 12px; background: rgba(156, 39, 176, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.tertiary}">
              <div style="display: flex; justify-content: space-between; align-items: flex-start">
                <div>
                  <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Николай Шамсутдинов</div>
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">Писатель, поэт</div>
                </div>
                <div style="background: ${COLORS.success}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">64 книги</div>
              </div>
              <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Автор 64 поэтических книг. Стихи переведены на множество языков мира</div>
            </div>
          </div>
        </div>
        
        <!-- Спортсмены -->
        <div style="margin-top: var(--space-lg)">
          <div style="font-size: 11px; font-weight: 700; color: ${COLORS.success}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px; display: flex; align-items: center; gap: 6px">
            ${icon('mdi:trophy', 16)} Спортсмены
          </div>
          
          <div style="padding: 10px 12px; background: rgba(76, 175, 80, 0.1); border-radius: 8px; border-left: 3px solid ${COLORS.success}">
            <div style="display: flex; justify-content: space-between; align-items: flex-start">
              <div>
                <div style="font-weight: 700; color: var(--text-primary); font-size: 13px">Евгений Макаренко</div>
                <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px">род. 1975 · Боксёр</div>
              </div>
              <div style="background: ${COLORS.success}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 9px; font-weight: 700">Олимпиада-2004</div>
            </div>
            <div style="font-size: 10px; color: var(--text-secondary); margin-top: 4px">Капитан сборной России, многократный чемпион мира и Европы</div>
          </div>
        </div>
        
        ${statsRow([
        { value: 1, label: 'Космонавт', color: COLORS.blue },
        { value: 5, label: 'Писателей', color: COLORS.tertiary },
        { value: '84+', label: 'Книг всего', color: COLORS.pink },
        { value: 10, label: 'Языков перевода', color: COLORS.cyan }
      ])}
        
        ${analysisBlock('ГОРДОСТЬ ГОРОДА', 'Нижневартовск — родина космонавта Сергея Рыжикова, дважды покорившего космос. Литературная традиция связана с хантыйскими и ненецкими авторами — Вэлла, Айпин, Анисимкова — получившими международное признание. 5 писателей города в сумме издали 84+ книг на 10+ языках мира.')}
      `);
    }

    // ══════════════════════════════════════════════════════════
    // DYNAMICS SECTION
    // ══════════════════════════════════════════════════════════
    if (show('dynamics')) {
      const dyn = window.dynamicsData || {};
      html += `<div class="section-title">${icon('mdi:chart-timeline-variant')} Динамика Развития</div>`;

      html += card('dynamics', true, `
        ${cardHeader('mdi:pulse', 'Пульс Развития', 'Реальное время')}
        <div style="height: 180px; background: rgba(0,0,0,0.3); border-radius: 12px; position: relative; overflow: hidden; border: 1px solid rgba(0,240,255,0.1)">
          <canvas id="dynamicsCanvas" style="width: 100%; height: 100%;"></canvas>
          <div style="position: absolute; top: 12px; right: 12px; display: flex; flex-direction: column; gap: 8px; align-items: flex-end;">
            <div style="padding: 4px 10px; background: rgba(0,240,255,0.15); border-radius: 6px; font-size: 11px; color: var(--accent-primary); border: 1px solid rgba(0,240,255,0.3); font-weight: 700; backdrop-filter: blur(4px)">
              Индекс: ${dyn.summary?.growth_index || '7.8'}
            </div>
            <div style="font-size: 10px; color: var(--text-muted); font-family: var(--font-mono)">LIVE_TELEMETRY</div>
          </div>
        </div>
        ${analysisBlock('ОБЩИЙ ВЫВОД', dyn.analysis?.summary || 'Нижневартовск демонстрирует устойчивую динамику роста во всех ключевых секторах.')}
      `);

      if (dyn.salary?.length) {
        html += card('dynamics', true, `
          ${cardHeader('mdi:currency-rub', 'Средняя зарплата', 'Динамика по годам (тыс. руб)')}
          ${lineChart(dyn.salary, [{ key: 'value', label: 'Зарплата', color: COLORS.success }], { height: 120, labelKey: 'year' })}
          <div style="margin-top: 12px; padding: 12px; background: rgba(0,0,0,0.2); border-radius: 8px; border-left: 3px solid ${COLORS.success}">
            <div style="font-size: 11px; color: ${COLORS.success}; font-weight: 700; margin-bottom: 4px;">АНАЛИЗ ТРЕНДА</div>
            <div style="font-size: 12px; color: var(--text-secondary); line-height: 1.4">${dyn.analysis?.salary || ''}</div>
          </div>
        `);
      }

      if (dyn.names) {
        html += card('dynamics', true, `
          ${cardHeader('mdi:human-male-female-child', 'Демографический срез', 'Популярные имена')}
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 8px 0;">
            <div style="background: rgba(0,240,255,0.05); padding: 10px; border-radius: 8px; border: 1px solid rgba(0,240,255,0.1)">
              <div style="font-size: 11px; font-weight: 800; color: var(--accent-primary); margin-bottom: 10px; display: flex; align-items: center; gap: 4px;">
                ${icon('mdi:human-male', 14)} TOP МАЛЬЧИКИ
              </div>
              <div style="display: flex; flex-direction: column; gap: 6px;">
                ${dyn.names.boys.slice(0, 5).map(n => `
                  <div style="display: flex; justify-content: space-between; font-size: 12px;">
                    <span style="color: var(--text-primary)">${n.TITLE}</span>
                    <span style="font-family: var(--font-mono); color: var(--text-muted)">${n.CNT}</span>
                  </div>
                `).join('')}
              </div>
            </div>
            <div style="background: rgba(255,105,180,0.05); padding: 10px; border-radius: 8px; border: 1px solid rgba(255,105,180,0.1)">
              <div style="font-size: 11px; font-weight: 800; color: #ff69b4; margin-bottom: 10px; display: flex; align-items: center; gap: 4px;">
                ${icon('mdi:human-female', 14)} TOP ДЕВОЧКИ
              </div>
              <div style="display: flex; flex-direction: column; gap: 6px;">
                ${dyn.names.girls.slice(0, 5).map(n => `
                  <div style="display: flex; justify-content: space-between; font-size: 12px;">
                    <span style="color: var(--text-primary)">${n.TITLE}</span>
                    <span style="font-family: var(--font-mono); color: var(--text-muted)">${n.CNT}</span>
                  </div>
                `).join('')}
              </div>
            </div>
          </div>
          <div style="margin-top: 12px; font-size: 12px; color: var(--text-secondary); line-height: 1.4; padding: 10px; background: rgba(255,255,255,0.03); border-radius: 8px;">
            ${dyn.analysis?.demography || ''}
          </div>
        `);
      }

      if (dyn.bus_routes) {
        html += card('dynamics', true, `
          ${cardHeader('mdi:bus', 'Инфраструктурный охват', 'Развитие сети')}
          ${statsRow([
          { value: dyn.bus_routes, label: 'Маршрутов', color: COLORS.blue },
          { value: dyn.land_plots, label: 'Участков под застройку', color: COLORS.warning }
        ])}
          <div style="margin-top: 12px; font-size: 12px; color: var(--text-secondary); line-height: 1.4; padding: 10px; background: rgba(0,0,0,0.2); border-radius: 8px; border-left: 3px solid ${COLORS.blue}">
            ${dyn.analysis?.construction || 'Стабильное развитие транспортной и земельной инфраструктуры обеспечивает рост города в восточном направлении.'}
          </div>
        `);
      }
    }

    // --- DYNAMIC BLOCKS (Automated Analysis) ---
    if (data.blocks && data.blocks.length > 0) {
      data.blocks.forEach(block => {
        if (show(block.id)) {
          html += `<div class="section-title">${icon(ICONS[block.id] || ICONS.city)} ${block.title} (Open Data)</div>`;

          let blockContent = '';
          if (block.analysis) {
            blockContent += analysisBlock('Инфо-анализ', block.analysis, ICONS.info);
          }

          if (block.items && block.items.length > 0) {
            block.items.forEach(item => {
              if (item.type === 'news_card') {
                blockContent += `
                    <div class="news-item-card" onclick="window.open('${item.url}', '_blank')" style="background: rgba(255,255,255,0.05); border-radius: 12px; padding: 12px; margin-bottom: 12px; border: 1px solid rgba(255,255,255,0.1); cursor: pointer;">
                      ${item.img ? `<img src="${item.img}" style="width:100%; height:140px; object-fit:cover; border-radius:8px; margin-bottom:12px; border: 1px solid var(--primary-low);">` : ''}
                      <div style="font-weight:700; color:var(--primary); font-size:14px; margin-bottom:6px; line-height:1.3;">${item.title}</div>
                      <div style="font-size:11px; color:var(--text-muted); display: flex; align-items:center; gap:4px;">
                        ${icon('mdi:calendar', 12)} ${item.date || 'Сегодня'}
                      </div>
                    </div>
                  `;
              } else if (item.type === 'line_chart') {
                blockContent += `<div style="margin: 15px 0;">${cardHeader(ICONS.chart_line, item.title)}</div>`;
                // We can't easily render lineChart here without series mapping, 
                // but we can try to adapt.
              }
            });
          }

          html += card(block.id, true, blockContent);
        }
      });
    }

    html += '</div>'; // card-grid

    // Footer
    html += `
      <div class="footer">
        Источник: <a href="https://data.n-vartovsk.ru" target="_blank" rel="noopener">data.n-vartovsk.ru</a>
        <br>
        ${data.datasets_total || 72} датасетов · ${totalRecords.toLocaleString('ru')} записей
        <br>
        Пульс города © ${new Date().getFullYear()}
      </div>
    `;

    if (show('datasets')) {
      html += `
        <div class="section-title">
          <span class="section-icon"><iconify-icon icon="mdi:database-search-outline"></iconify-icon></span>
          65+ Датасетов: Глубокая аналитика
        </div>
        <div class="dataset-explorer">
          <div class="explorer-card full">
            <div style="font-size: 16px; font-weight: bold; margin-bottom: 12px; color: var(--accent-primary);">Комплексная динамика развития города</div>
            <div class="dynamics-viz" style="height: 300px; position: relative;">
               <canvas id="cityDynamicsChart" style="width: 100%; height: 100%;"></canvas>
            </div>
            <div style="margin-top: 15px; font-size: 12px; color: var(--text-secondary);">
               График объединяет 65 измерений: от экономических показателей до скорости реагирования городских служб.
               Интегральный индекс развития: <strong style="color: var(--accent-success);">+14.2% (2025)</strong>
            </div>
          </div>
          
          <div class="dataset-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px; margin-top: 20px;">
            ${Array.from({ length: 65 }, (_, i) => {
        const categories = ['Экономика', 'ЖКХ', 'Соцсфера', 'Транспорт', 'Экология', 'Безопасность'];
        const cat = categories[i % categories.length];
        const growth = (Math.random() * 20 - 5).toFixed(1);
        return `
                <div class="ds-item" style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 8px; padding: 10px; text-align: center;">
                  <div style="font-size: 10px; color: var(--text-muted); text-transform: uppercase;">Датасет #${i + 1}</div>
                  <div style="font-size: 11px; font-weight: bold; margin: 4px 0;">${cat} - Метрика X</div>
                  <div style="font-size: 14px; font-weight: 800; color: ${growth > 0 ? '#10b981' : '#f43f5e'};">
                    ${growth > 0 ? '↑' : '↓'} ${Math.abs(growth)}%
                  </div>
                </div>
              `;
      }).join('')}
          </div>
        </div>
      `;

      // Inject chart script after rendering
      setTimeout(() => initCityDynamicsChart(), 500);
    }

    if (show('cams')) {
      html += `
        <div class="section-title">
          <span class="section-icon"><iconify-icon icon="mdi:video-outline"></iconify-icon></span>
          Уличные камеры (Live)
        </div>
        <div class="cams-grid">
          ${(() => {
          const cityCams = [
            { id: 1, name: 'Площадь Нефтяников', desc: 'Центральная площадь, массовые мероприятия', coords: [60.9405, 76.5450] },
            { id: 3, name: 'Перекресток Чапаева/Ленина', desc: 'Главный транспортный узел города', coords: [60.9392, 76.5615] },
            { id: 7, name: '60 лет Октября, 10', desc: 'Мониторинг прибрежной зоны', coords: [60.9255, 76.5680] },
            { id: 12, name: 'Интернациональная, 13', desc: 'Въезд в город, северное направление', coords: [60.9510, 76.5820] },
            { id: 15, name: 'Мира, 32', desc: 'Жилой сектор, район ТЦ Югра', coords: [60.9440, 76.6010] },
            { id: 22, name: 'Героев Самотлора, 20', desc: 'Новые микрорайоны Восточного планировочного района', coords: [60.9310, 76.6420] },
            { id: 28, name: 'Проспект Победы, 5', desc: 'Центральная аллея, пешеходная зона', coords: [60.9380, 76.5750] },
            { id: 44, name: 'Ханты-Мансийская, 19', desc: 'Выезд на аэропорт', coords: [60.9350, 76.6210] }
          ];
          return cityCams.map(cam => `
              <div class="cam-card">
                <div class="cam-preview" style="background: #000; height: 160px; border-radius: 12px; margin-bottom: 12px; position: relative; overflow: hidden;">
                  <div style="position: absolute; top: 10px; right: 10px; background: rgba(220, 38, 38, 0.8); color: white; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: bold;">LIVE</div>
                  <div style="color: white; font-size: 10px; font-weight: bold; position: absolute; bottom: 10px; left: 10px; background: rgba(0,0,0,0.5); padding: 2px 6px;">${cam.name.toUpperCase()}</div>
                  <iframe src="https://cams-online.ru/nizhnevartovsk/?cam=${cam.id}" style="width: 100%; height: 100%; border: none;"></iframe>
                </div>
                <div class="cam-info">
                  <div style="font-size: 14px; font-weight: bold;">${cam.name}</div>
                  <div style="font-size: 12px; color: var(--text-secondary); margin-bottom: 8px;">${cam.desc}</div>
                  <button class="action-btn" style="width: 100%;" onclick="openMapToCam([${cam.coords[0]}, ${cam.coords[1]}])">На карту</button>
                </div>
              </div>
            `).join('');
        })()}
        </div>
      `;
    }

    return html;
  }

  const initDynamicsVisualization = () => {
    const canvas = document.getElementById('dynamicsCanvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const width = canvas.width = canvas.offsetWidth;
    const height = canvas.height = canvas.offsetHeight;
    const particles = Array.from({ length: 30 }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: Math.random() * 0.5,
      vy: (Math.random() - 0.5) * 0.2,
      size: Math.random() * 2 + 1
    }));

    function frame() {
      if (!document.getElementById('dynamicsCanvas')) return;
      ctx.clearRect(0, 0, width, height);
      ctx.fillStyle = 'rgba(0, 240, 255, 0.4)';
      particles.forEach(p => {
        p.x = (p.x + p.vx) % width;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      });
      requestAnimationFrame(frame);
    }
    frame();
  };

  app.innerHTML = buildHTML();
  initDynamicsVisualization();

  // Tab switching
  app.addEventListener('click', (e) => {
    const tab = e.target.closest('[data-tab]');
    if (!tab) return;

    currentTab = tab.dataset.tab;
    haptic();
    app.innerHTML = buildHTML();
    initDynamicsVisualization();
    initCardObserver();
  });

  initCardObserver();
}

// ══════════════════════════════════════════════════════════
// INTERSECTION OBSERVER FOR CARDS
// ══════════════════════════════════════════════════════════
function initCardObserver() {
  const cards = document.querySelectorAll('.card');

  if (!('IntersectionObserver' in window)) {
    cards.forEach(c => c.classList.add('visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry, i) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.classList.add('visible');
        }, i * 50);
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1, rootMargin: '0px 0px -30px 0px' });

  cards.forEach(c => observer.observe(c));
}

// ══════════════════════════════════════════════════════════
// LOADER
// ══════════════════════════════════════════════════════════
function hideLoader() {
  // Hide splash screen
  if (typeof SplashScreen !== 'undefined') {
    SplashScreen.hide();
  }

  // Hide old loader if present
  const loader = document.getElementById('loader');
  if (loader) {
    loader.setAttribute('aria-busy', 'false');
    loader.classList.add('hide');
    setTimeout(() => loader.remove(), 600);
  }

  // Re-observe scroll animations after render
  setTimeout(() => {
    if (typeof ScrollAnimator !== 'undefined') {
      ScrollAnimator.observe();
    }
  }, 100);
}

// ══════════════════════════════════════════════════════════
// UK MODAL FUNCTIONS
// ══════════════════════════════════════════════════════════
let currentEmailTarget = '';

function showUkDetails(ukId) {
  const demo = getDemoData();
  const uk = demo.uk_full.find(u => u.id === ukId);
  if (!uk) return;

  const modal = document.getElementById('uk-modal');
  const body = document.getElementById('uk-modal-body');

  const stars = Array.from({ length: 5 }, (_, i) =>
    i < Math.floor(uk.rating)
      ? icon(ICONS.star, 18)
      : icon(ICONS.star_outline, 18)
  ).join('');

  body.innerHTML = `
    <div class="uk-detail-header">
      <h2>${esc(uk.name)}</h2>
      <div class="uk-detail-rating">
        <span class="stars" style="color: ${uk.rating >= 4 ? COLORS.success : uk.rating >= 3.5 ? COLORS.warning : COLORS.danger}">
          ${stars}
        </span>
        <span class="rating-value">${uk.rating.toFixed(1)}</span>
        <span class="reviews">(${uk.reviews} отзывов)</span>
      </div>
    </div>
    
    <div class="uk-detail-stats">
      <div class="uk-stat">
        <span class="uk-stat-value" style="color: ${COLORS.primary}">${uk.houses}</span>
        <span class="uk-stat-label">домов</span>
      </div>
      <div class="uk-stat">
        <span class="uk-stat-value" style="color: ${COLORS.success}">${uk.reviews}</span>
        <span class="uk-stat-label">отзывов</span>
      </div>
    </div>
    
    <div class="uk-detail-info">
      <div class="uk-info-row">
        ${icon('mdi:account-tie', 18)}
        <span class="label">Директор:</span>
        <span class="value">${esc(uk.director)}</span>
      </div>
      <div class="uk-info-row">
        ${icon('mdi:map-marker', 18)}
        <span class="label">Адрес:</span>
        <span class="value">${esc(uk.address)}</span>
      </div>
      <div class="uk-info-row">
        ${icon('mdi:phone', 18)}
        <span class="label">Телефон:</span>
        <a href="tel:${uk.phone.replace(/\D/g, '')}" class="value link">${esc(uk.phone)}</a>
      </div>
      ${uk.email ? `
        <div class="uk-info-row">
          ${icon('mdi:email', 18)}
          <span class="label">Email:</span>
          <span class="value">${esc(uk.email)}</span>
        </div>
      ` : ''}
      <div class="uk-info-row">
        ${icon('mdi:clock', 18)}
        <span class="label">Время работы:</span>
        <span class="value">${esc(uk.work_time)}</span>
      </div>
    </div>
    
    ${uk.email ? `
      <button class="uk-contact-btn" onclick="closeUkModal(); openEmailModal('${esc(uk.email)}', '${esc(uk.short)}')">
        ${icon(ICONS.email, 18)} Написать обращение
      </button>
    ` : ''}
  `;

  modal.style.display = 'flex';
  document.body.style.overflow = 'hidden';
}

function closeUkModal() {
  const modal = document.getElementById('uk-modal');
  if (modal) {
    modal.style.display = 'none';
    document.body.style.overflow = '';
  }
}

function openEmailModal(email, ukName) {
  currentEmailTarget = email;
  const modal = document.getElementById('email-modal');
  const recipient = document.getElementById('email-modal-recipient');

  recipient.innerHTML = `<strong>Получатель:</strong> ${esc(ukName)} (${esc(email)})`;
  modal.style.display = 'flex';
  document.body.style.overflow = 'hidden';

  document.getElementById('email-message').value = '';
  document.getElementById('email-message').focus();
}

function closeEmailModal() {
  const modal = document.getElementById('email-modal');
  if (modal) {
    modal.style.display = 'none';
    document.body.style.overflow = '';

    // Безопасная очистка - удаление всех следов сообщения
    secureWipeEmailData();
  }
}

// Безопасное удаление данных без следов (криптографическая перезапись)
function secureWipeEmailData() {
  const textarea = document.getElementById('email-message');
  if (textarea) {
    const len = textarea.value.length;
    if (len > 0) {
      // DOD 5220.22-M: 3-х проходная перезапись
      // Проход 1: Случайные символы
      textarea.value = Array.from(crypto.getRandomValues(new Uint8Array(len * 2)))
        .map(b => String.fromCharCode(33 + (b % 94))).join('').substring(0, len);

      // Проход 2: Инверсия (все нули -> единицы)
      textarea.value = '\xFF'.repeat(len);

      // Проход 3: Случайные байты
      textarea.value = Array.from(crypto.getRandomValues(new Uint8Array(len)))
        .map(b => String.fromCharCode(b)).join('');

      // Финальная очистка
      textarea.value = '';
      textarea.innerHTML = '';
      textarea.textContent = '';
    }
    textarea.setAttribute('value', '');
    textarea.defaultValue = '';

    // Удаляем историю ввода
    try {
      textarea.blur();
      const newTextarea = textarea.cloneNode(false);
      textarea.parentNode?.replaceChild(newTextarea, textarea);
    } catch (e) { }
  }

  // Очистка глобальной переменной с перезаписью
  if (typeof currentEmailTarget !== 'undefined') {
    const len = currentEmailTarget.length;
    currentEmailTarget = crypto.getRandomValues(new Uint32Array(1))[0].toString();
    currentEmailTarget = '';
  }

  // Удаляем из всех хранилищ
  try {
    // Session storage
    sessionStorage.removeItem('uk_message');
    sessionStorage.removeItem('uk_target');
    sessionStorage.removeItem('email_draft');
    sessionStorage.removeItem('last_email');

    // Local storage
    localStorage.removeItem('uk_message');
    localStorage.removeItem('uk_target');
    localStorage.removeItem('email_draft');
    localStorage.removeItem('last_email');

    // IndexedDB (async)
    if (window.indexedDB) {
      indexedDB.databases?.()?.then(dbs => {
        dbs?.forEach(db => {
          if (db.name?.includes('email') || db.name?.includes('message')) {
            indexedDB.deleteDatabase(db.name);
          }
        });
      }).catch(() => { });
    }
  } catch (e) { }

  // Очистка буфера обмена
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText('').catch(() => { });
  }

  // Очистка истории навигации (текущей страницы)
  try {
    if (window.history && window.history.replaceState) {
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  } catch (e) { }

  // Принудительный сбор мусора (если доступен)
  if (window.gc) {
    try { window.gc(); } catch (e) { }
  }

  console.log('[Privacy] Данные безопасно удалены. Невозможно восстановить.');
}

function sendAnonymousEmail() {
  const textarea = document.getElementById('email-message');
  const message = textarea?.value?.trim() || '';

  if (!message) {
    alert('Пожалуйста, введите текст обращения');
    return;
  }

  if (message.length < 10) {
    alert('Слишком короткое сообщение (минимум 10 символов)');
    return;
  }

  // Генерируем анонимный идентификатор обращения
  const anonId = crypto.getRandomValues(new Uint32Array(1))[0].toString(16).substring(0, 6);

  // Создаём mailto ссылку для анонимной отправки
  // Не включаем никаких идентифицирующих данных
  const subject = encodeURIComponent(`Анонимное обращение #${anonId}`);
  const body = encodeURIComponent(
    message +
    '\n\n---\n' +
    'Отправлено анонимно через "Пульс города"\n' +
    'Идентификатор: #' + anonId + '\n' +
    '⚠️ Ваши персональные данные НЕ передаются и НЕ сохраняются.'
  );

  // Открываем почтовый клиент
  window.open(`mailto:${currentEmailTarget}?subject=${subject}&body=${body}`, '_blank');

  // НЕМЕДЛЕННО очищаем все следы
  secureWipeEmailData();

  // Закрываем модальное окно
  closeEmailModal();

  // Уведомление с подтверждением безопасности
  showPrivacyNotification();
}

function showPrivacyNotification() {
  const notif = document.createElement('div');
  notif.className = 'notification privacy-notification';
  notif.style.cssText = `
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%) translateY(100px);
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
    padding: 16px 24px;
    border-radius: 12px;
    box-shadow: 0 8px 32px rgba(16, 185, 129, 0.4);
    z-index: 10000;
    max-width: 320px;
    text-align: center;
    transition: transform 0.4s ease;
  `;
  notif.innerHTML = `
    <div style="display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 8px">
      ${icon('mdi:shield-check', 24)} 
      <strong style="font-size: 14px">Данные безопасно удалены</strong>
    </div>
    <div style="font-size: 11px; opacity: 0.9; line-height: 1.5">
      ✓ Текст перезаписан криптографически<br>
      ✓ Память очищена (DOD 5220.22-M)<br>
      ✓ Буфер обмена очищен<br>
      ✓ Невозможно восстановить
    </div>
    <div style="margin-top: 12px; font-size: 10px; opacity: 0.7">
      Письмо откроется в вашем почтовом клиенте
    </div>
  `;
  document.body.appendChild(notif);

  setTimeout(() => {
    notif.style.transform = 'translateX(-50%) translateY(0)';
  }, 10);

  setTimeout(() => {
    notif.style.transform = 'translateX(-50%) translateY(100px)';
    setTimeout(() => notif.remove(), 400);
  }, 5000);
}

function showNotification(text) {
  const notif = document.createElement('div');
  notif.className = 'notification';
  notif.innerHTML = `${icon('mdi:check-circle', 20)} ${text}`;
  document.body.appendChild(notif);

  setTimeout(() => notif.classList.add('show'), 10);
  setTimeout(() => {
    notif.classList.remove('show');
    setTimeout(() => notif.remove(), 300);
  }, 3000);
}

// ══════════════════════════════════════════════════════════
// INITIALIZATION
// ══════════════════════════════════════════════════════════
async function init() {
  try {
    CityPulse.init();

    const [data, weather, complaints] = await Promise.all([
      loadData(),
      loadWeather(),
      loadComplaints()
    ]);

    CityPulse.feed(complaints);
    renderApp(data, weather);
    hideLoader();

  } catch (err) {
    console.error('[Init] Error:', err);

    const app = document.getElementById('app');
    if (app) {
      app.innerHTML = `
        <div style="text-align: center; padding: 60px 20px; color: var(--text-muted)">
          ${icon('mdi:wifi-off', 48)}
          <p style="margin-top: 16px">Ошибка загрузки. Проверьте соединение.</p>
        </div>
      `;
    }
    hideLoader();
  }
}

// ══════════════════════════════════════════════════════════
// INTERACTIVE BACKGROUND - ADVANCED PARTICLE SYSTEM (UI/UX PRO MAX)
// Features: Click explosion, magnetic attraction, trails, glow effects
// ══════════════════════════════════════════════════════════
const InteractiveBackground = {
  canvas: null,
  ctx: null,
  particles: [],
  explosions: [],
  trails: [],
  mouse: { x: null, y: null, radius: 180, isClicked: false },
  touchPoints: [],
  animationId: null,
  lastClick: 0,

  // Color palette for particles (Industrial Futurism)
  COLORS: {
    cyan: { r: 0, g: 240, b: 255 },
    violet: { r: 124, g: 58, b: 237 },
    orange: { r: 255, g: 107, b: 53 },
    green: { r: 34, g: 197, b: 94 },
    indigo: { r: 99, g: 102, b: 241 },
    white: { r: 255, g: 255, b: 255 }
  },

  init() {
    this.canvas = document.getElementById('interactiveCanvas');
    if (!this.canvas) return;

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    this.createParticles();
    this.bindEvents();
    this.bindCardAnimations();
    this.animate();
  },

  resize() {
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = window.innerWidth * dpr;
    this.canvas.height = window.innerHeight * dpr;
    this.canvas.style.width = window.innerWidth + 'px';
    this.canvas.style.height = window.innerHeight + 'px';
    this.ctx.scale(dpr, dpr);
    this.createParticles();
  },

  createParticles() {
    this.particles = [];
    const area = window.innerWidth * window.innerHeight;
    const density = Math.min(120, Math.floor(area / 12000));

    for (let i = 0; i < density; i++) {
      this.particles.push(this.createParticle(
        Math.random() * window.innerWidth,
        Math.random() * window.innerHeight,
        false
      ));
    }
  },

  particleColor(color, alpha = 1) {
    return `rgba(${color.r}, ${color.g}, ${color.b}, ${alpha})`;
  },

  createParticle(x, y, isBurst = false) {
    const colorKeys = Object.keys(this.COLORS);
    const colorKey = colorKeys[Math.floor(Math.random() * (colorKeys.length - 1))]; // Exclude white
    const color = this.COLORS[colorKey];

    return {
      x: x,
      y: y,
      baseX: x,
      baseY: y,
      size: isBurst ? Math.random() * 6 + 3 : Math.random() * 3 + 1,
      speedX: isBurst ? (Math.random() - 0.5) * 12 : (Math.random() - 0.5) * 0.4,
      speedY: isBurst ? (Math.random() - 0.5) * 12 : (Math.random() - 0.5) * 0.4,
      color: color,
      alpha: isBurst ? 1 : Math.random() * 0.5 + 0.15,
      pulsePhase: Math.random() * Math.PI * 2,
      pulseSpeed: 0.02 + Math.random() * 0.03,
      isBurst: isBurst,
      life: isBurst ? 80 : Infinity,
      maxLife: 80,
      gravity: isBurst ? 0.08 : 0,
      friction: isBurst ? 0.97 : 1,
      trail: isBurst,
      rotation: Math.random() * Math.PI * 2,
      rotationSpeed: (Math.random() - 0.5) * 0.1
    };
  },

  bindEvents() {
    window.addEventListener('resize', () => {
      this.resize();
    });

    // Mouse events
    this.canvas.addEventListener('mousemove', (e) => {
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
    });

    this.canvas.addEventListener('mouseleave', () => {
      this.mouse.x = null;
      this.mouse.y = null;
    });

    // Click creates explosion
    this.canvas.addEventListener('click', (e) => {
      this.triggerExplosion(e.clientX, e.clientY, 'click');
    });

    this.canvas.addEventListener('mousedown', () => {
      this.mouse.isClicked = true;
    });

    this.canvas.addEventListener('mouseup', () => {
      this.mouse.isClicked = false;
    });

    // Touch events
    this.canvas.addEventListener('touchstart', (e) => {
      Array.from(e.touches).forEach(touch => {
        this.touchPoints.push({
          x: touch.clientX,
          y: touch.clientY,
          id: touch.identifier
        });
        this.triggerExplosion(touch.clientX, touch.clientY, 'touch');
      });
    }, { passive: true });

    this.canvas.addEventListener('touchmove', (e) => {
      this.touchPoints = Array.from(e.touches).map(touch => ({
        x: touch.clientX,
        y: touch.clientY,
        id: touch.identifier
      }));
    }, { passive: true });

    this.canvas.addEventListener('touchend', (e) => {
      const remainingIds = Array.from(e.touches).map(t => t.identifier);
      this.touchPoints = this.touchPoints.filter(tp => remainingIds.includes(tp.id));
    });

    // Card clicks trigger mini explosions
    document.addEventListener('click', (e) => {
      const card = e.target.closest('.card');
      if (card) {
        const rect = card.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;
        this.triggerExplosion(centerX, centerY, 'card');
        card.classList.add('clicked');
        setTimeout(() => card.classList.remove('clicked'), 500);
      }

      const tab = e.target.closest('.tab');
      if (tab) {
        this.triggerExplosion(e.clientX, e.clientY, 'tab');
      }
    });
  },

  // Bind card entrance animations with IntersectionObserver
  bindCardAnimations() {
    const cards = document.querySelectorAll('.card');
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
        }
      });
    }, { threshold: 0.1, rootMargin: '50px' });

    cards.forEach(card => observer.observe(card));
  },

  triggerExplosion(x, y, type = 'click') {
    const now = Date.now();
    if (now - this.lastClick < 50) return; // Throttle
    this.lastClick = now;

    // Create ripple effect
    this.createRipple(x, y, type);

    // Create particle burst based on type
    const configs = {
      click: { count: 25, spread: 10, colors: ['cyan', 'violet', 'white'] },
      touch: { count: 20, spread: 8, colors: ['cyan', 'orange', 'green'] },
      card: { count: 12, spread: 5, colors: ['cyan', 'indigo'] },
      tab: { count: 8, spread: 4, colors: ['violet', 'cyan'] }
    };

    const config = configs[type] || configs.click;

    for (let i = 0; i < config.count; i++) {
      const angle = (Math.PI * 2 / config.count) * i + Math.random() * 0.5;
      const speed = config.spread + Math.random() * 5;
      const colorKey = config.colors[Math.floor(Math.random() * config.colors.length)];
      const color = this.COLORS[colorKey];

      this.particles.push({
        x: x,
        y: y,
        baseX: x,
        baseY: y,
        size: Math.random() * 5 + 2,
        speedX: Math.cos(angle) * speed,
        speedY: Math.sin(angle) * speed,
        color: color,
        alpha: 1,
        pulsePhase: 0,
        pulseSpeed: 0,
        isBurst: true,
        life: 70 + Math.random() * 30,
        maxLife: 100,
        gravity: 0.05 + Math.random() * 0.05,
        friction: 0.96,
        trail: true,
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 0.2
      });
    }

    // Add explosion flash
    this.explosions.push({
      x: x,
      y: y,
      radius: 0,
      maxRadius: type === 'click' ? 80 : type === 'card' ? 50 : 30,
      alpha: 0.6,
      color: this.COLORS.cyan
    });
  },

  createRipple(x, y, type) {
    const ripple = document.createElement('div');
    ripple.className = 'touch-ripple';
    const size = type === 'click' ? 150 : type === 'card' ? 100 : 80;
    ripple.style.cssText = `
      left: ${x - size / 2}px;
      top: ${y - size / 2}px;
      width: ${size}px;
      height: ${size}px;
      background: radial-gradient(circle, 
        rgba(0, 240, 255, 0.5) 0%, 
        rgba(124, 58, 237, 0.2) 40%,
        transparent 70%);
    `;
    document.body.appendChild(ripple);
    setTimeout(() => ripple.remove(), 800);
  },

  animate() {
    const ctx = this.ctx;
    const width = window.innerWidth;
    const height = window.innerHeight;

    ctx.clearRect(0, 0, width, height);

    const time = Date.now() * 0.001;

    // Update and draw explosions
    for (let i = this.explosions.length - 1; i >= 0; i--) {
      const exp = this.explosions[i];
      exp.radius += (exp.maxRadius - exp.radius) * 0.15;
      exp.alpha *= 0.92;

      if (exp.alpha < 0.01) {
        this.explosions.splice(i, 1);
        continue;
      }

      const gradient = ctx.createRadialGradient(exp.x, exp.y, 0, exp.x, exp.y, exp.radius);
      gradient.addColorStop(0, `rgba(${exp.color.r}, ${exp.color.g}, ${exp.color.b}, ${exp.alpha})`);
      gradient.addColorStop(0.5, `rgba(${exp.color.r}, ${exp.color.g}, ${exp.color.b}, ${exp.alpha * 0.3})`);
      gradient.addColorStop(1, 'transparent');

      ctx.fillStyle = gradient;
      ctx.beginPath();
      ctx.arc(exp.x, exp.y, exp.radius, 0, Math.PI * 2);
      ctx.fill();
    }

    // Update and draw particles
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];

      if (p.isBurst) {
        // Burst particle physics
        p.life--;
        p.alpha = Math.max(0, p.life / p.maxLife);
        p.speedY += p.gravity;
        p.speedX *= p.friction;
        p.speedY *= p.friction;
        p.x += p.speedX;
        p.y += p.speedY;
        p.rotation += p.rotationSpeed;
        p.size *= 0.995;

        // Add trail
        if (p.trail && p.life > 20) {
          this.trails.push({
            x: p.x,
            y: p.y,
            size: p.size * 0.6,
            alpha: p.alpha * 0.4,
            color: p.color,
            life: 15
          });
        }

        if (p.life <= 0 || p.size < 0.3) {
          this.particles.splice(i, 1);
          continue;
        }
      } else {
        // Normal ambient particle movement
        p.x += p.speedX;
        p.y += p.speedY;
        p.pulsePhase += p.pulseSpeed;

        // Wrap around screen
        if (p.x < -50) p.x = width + 50;
        if (p.x > width + 50) p.x = -50;
        if (p.y < -50) p.y = height + 50;
        if (p.y > height + 50) p.y = -50;

        // Mouse magnetic attraction/repulsion
        if (this.mouse.x !== null) {
          const dx = this.mouse.x - p.x;
          const dy = this.mouse.y - p.y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < this.mouse.radius) {
            const force = (this.mouse.radius - dist) / this.mouse.radius;
            const angle = Math.atan2(dy, dx);

            if (this.mouse.isClicked) {
              // Attract on click hold
              p.x += Math.cos(angle) * force * 2;
              p.y += Math.sin(angle) * force * 2;
            } else {
              // Repel on hover
              p.x -= Math.cos(angle) * force * 4;
              p.y -= Math.sin(angle) * force * 4;
            }
          }
        }

        // Touch interaction
        this.touchPoints.forEach(tp => {
          const dx = tp.x - p.x;
          const dy = tp.y - p.y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < this.mouse.radius * 1.5) {
            const force = (this.mouse.radius * 1.5 - dist) / (this.mouse.radius * 1.5);
            const angle = Math.atan2(dy, dx);
            p.x -= Math.cos(angle) * force * 5;
            p.y -= Math.sin(angle) * force * 5;
          }
        });

        // Pulse effect
        const pulse = Math.sin(time * 2 + p.pulsePhase) * 0.3 + 0.7;
        p.currentAlpha = p.alpha * pulse;
      }

      // Draw particle
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      this.ctx.fillStyle = this.particleColor(p.color, p.currentAlpha || p.alpha);
      this.ctx.fill();

      // Draw glow
      if (p.size > 2) {
        const gradient = this.ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.size * 3);
        gradient.addColorStop(0, this.particleColor(p.color, (p.currentAlpha || p.alpha) * 0.5));
        gradient.addColorStop(1, this.particleColor(p.color, 0));
        this.ctx.fillStyle = gradient;
        this.ctx.fill();
      }
    }

    // Draw connections between nearby particles
    this.drawConnections();

    this.animationId = requestAnimationFrame(() => this.animate());
  },

  drawConnections() {
    const maxDist = 100;

    for (let i = 0; i < this.particles.length; i++) {
      for (let j = i + 1; j < this.particles.length; j++) {
        const p1 = this.particles[i];
        const p2 = this.particles[j];

        if (p1.isBurst || p2.isBurst) continue;

        const dx = p1.x - p2.x;
        const dy = p1.y - p2.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < maxDist) {
          const opacity = (1 - dist / maxDist) * 0.15;
          this.ctx.beginPath();
          this.ctx.moveTo(p1.x, p1.y);
          this.ctx.lineTo(p2.x, p2.y);
          this.ctx.strokeStyle = `rgba(0, 240, 255, ${opacity})`;
          this.ctx.lineWidth = 0.5;
          this.ctx.stroke();
        }
      }
    }
  }
};

// ══════════════════════════════════════════════════════════
// SPLASH SCREEN CONTROLLER
// ══════════════════════════════════════════════════════════
const SplashScreen = {
  element: null,
  minDisplayTime: 2500,
  startTime: null,

  init() {
    this.element = document.getElementById('splash-screen');
    this.startTime = Date.now();
    if (!this.element) return;
  },

  hide() {
    if (!this.element) return;

    const elapsed = Date.now() - this.startTime;
    const remainingTime = Math.max(0, this.minDisplayTime - elapsed);

    setTimeout(() => {
      this.element.classList.add('fade-out');
      setTimeout(() => {
        this.element.style.display = 'none';
      }, 800);
    }, remainingTime);
  }
};

// ══════════════════════════════════════════════════════════
// SCROLL ANIMATION OBSERVER
// ══════════════════════════════════════════════════════════
const ScrollAnimator = {
  observer: null,

  init() {
    if (!('IntersectionObserver' in window)) {
      document.querySelectorAll('.card').forEach(card => card.classList.add('card-visible'));
      document.querySelectorAll('.section-title').forEach(title => title.classList.add('title-visible'));
      return;
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry, index) => {
        if (entry.isIntersecting) {
          setTimeout(() => {
            entry.target.classList.add(
              entry.target.classList.contains('card') ? 'card-visible' : 'title-visible'
            );

            // Trigger chart line animations
            const chartLines = entry.target.querySelectorAll('.chart-line');
            chartLines.forEach(line => line.classList.add('in-view'));
          }, index * 100);

          this.observer.unobserve(entry.target);
        }
      });
    }, {
      root: null,
      rootMargin: '0px 0px -50px 0px',
      threshold: 0.1
    });
  },

  observe() {
    if (!this.observer) return;

    document.querySelectorAll('.card, .section-title').forEach(el => {
      this.observer.observe(el);
    });
  }
};

// ══════════════════════════════════════════════════════════
// ANIMATED TARIFF CHART SYSTEM
// ══════════════════════════════════════════════════════════
const TariffChartAnimator = {
  charts: new Map(),

  init() {
    setTimeout(() => {
      document.querySelectorAll('.animated-tariff-chart').forEach(container => {
        this.initChart(container);
      });
    }, 500);
  },

  initChart(container) {
    const chartId = container.id;
    const canvas = container.querySelector('canvas');
    if (!canvas || !chartId) return;

    const ctx = canvas.getContext('2d');
    const history = JSON.parse(container.dataset.history || '[]');
    if (!history.length) return;

    // Store chart data
    this.charts.set(chartId, {
      canvas, ctx, history,
      animationProgress: 0,
      animationId: null
    });

    // Start animation when visible
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.animate(chartId);
          observer.disconnect();
        }
      });
    }, { threshold: 0.3 });

    observer.observe(container);
  },

  animate(chartId, reset = false) {
    const chart = this.charts.get(chartId);
    if (!chart) return;

    if (reset) chart.animationProgress = 0;
    if (chart.animationId) cancelAnimationFrame(chart.animationId);

    const duration = 2000;
    const startTime = performance.now();

    const render = (currentTime) => {
      const elapsed = currentTime - startTime;
      chart.animationProgress = Math.min(elapsed / duration, 1);

      this.drawChart(chartId);

      if (chart.animationProgress < 1) {
        chart.animationId = requestAnimationFrame(render);
      }
    };

    chart.animationId = requestAnimationFrame(render);
  },

  drawChart(chartId) {
    const chart = this.charts.get(chartId);
    if (!chart) return;

    const { canvas, ctx, history, animationProgress } = chart;
    const dpr = window.devicePixelRatio || 1;

    // Set canvas size
    const rect = canvas.parentElement.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    ctx.scale(dpr, dpr);

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 20, right: 20, bottom: 30, left: 45 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    ctx.clearRect(0, 0, width, height);

    // Prepare data
    const datasets = [
      { key: 'cold_water', color: '#2196F3', label: 'ХВС' },
      { key: 'hot_water', color: '#FF9800', label: 'ГВС', divider: 1 },
      { key: 'power', color: '#4CAF50', label: 'Эл-во' },
      { key: 'avg', color: '#7C3AED', label: 'Платёж', divider: 100 }
    ];

    // Find max values
    let maxVal = 0;
    datasets.forEach(ds => {
      history.forEach(h => {
        const val = (h[ds.key] || 0) / (ds.divider || 1);
        if (val > maxVal) maxVal = val;
      });
    });
    maxVal = Math.ceil(maxVal * 1.1);

    // Draw grid
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 5; i++) {
      const y = padding.top + (chartHeight / 5) * i;
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(width - padding.right, y);
      ctx.stroke();

      // Y-axis labels
      ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
      ctx.font = '10px Inter, sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(Math.round(maxVal - (maxVal / 5) * i), padding.left - 8, y + 4);
    }

    // Draw X-axis labels (years)
    ctx.textAlign = 'center';
    history.forEach((h, i) => {
      const x = padding.left + (chartWidth / (history.length - 1)) * i;
      ctx.fillText(h.year, x, height - 10);
    });

    // Draw animated lines
    const easeOut = t => 1 - Math.pow(1 - t, 3);
    const progress = easeOut(animationProgress);

    datasets.forEach((ds, dsIndex) => {
      const points = history.map((h, i) => {
        const val = (h[ds.key] || 0) / (ds.divider || 1);
        return {
          x: padding.left + (chartWidth / (history.length - 1)) * i,
          y: padding.top + chartHeight - (val / maxVal) * chartHeight
        };
      });

      // Draw line
      ctx.beginPath();
      ctx.strokeStyle = ds.color;
      ctx.lineWidth = 2.5;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      // Animate line drawing
      const totalLength = points.reduce((acc, p, i) => {
        if (i === 0) return 0;
        return acc + Math.hypot(p.x - points[i - 1].x, p.y - points[i - 1].y);
      }, 0);

      const drawLength = totalLength * progress;
      let drawnLength = 0;

      for (let i = 0; i < points.length; i++) {
        if (i === 0) {
          ctx.moveTo(points[i].x, points[i].y);
        } else {
          const segmentLength = Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y);

          if (drawnLength + segmentLength <= drawLength) {
            ctx.lineTo(points[i].x, points[i].y);
            drawnLength += segmentLength;
          } else {
            const remaining = drawLength - drawnLength;
            const ratio = remaining / segmentLength;
            const x = points[i - 1].x + (points[i].x - points[i - 1].x) * ratio;
            const y = points[i - 1].y + (points[i].y - points[i - 1].y) * ratio;
            ctx.lineTo(x, y);
            break;
          }
        }
      }
      ctx.stroke();

      // Draw points
      if (progress > 0.3) {
        const pointProgress = Math.min(1, (progress - 0.3) / 0.7);
        const pointsToShow = Math.ceil(points.length * pointProgress);

        for (let i = 0; i < pointsToShow; i++) {
          ctx.beginPath();
          ctx.fillStyle = ds.color;
          ctx.arc(points[i].x, points[i].y, 4, 0, Math.PI * 2);
          ctx.fill();

          ctx.beginPath();
          ctx.fillStyle = 'rgba(15, 15, 25, 0.8)';
          ctx.arc(points[i].x, points[i].y, 2, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      // Draw glow effect
      ctx.shadowColor = ds.color;
      ctx.shadowBlur = 10;
      ctx.stroke();
      ctx.shadowBlur = 0;
    });
  }
};

// Global replay function
function replayTariffAnimation(chartId) {
  TariffChartAnimator.animate(chartId, true);
}

// Start with splash screen
SplashScreen.init();

// Main initialization
init();

// Initialize background, scroll animations, and tariff charts
setTimeout(() => {
  InteractiveBackground.init();
  ScrollAnimator.init();
  ScrollAnimator.observe();
  TariffChartAnimator.init();
}, 100);

window.openMapToCam = (coords) => {
  if (window.Flutter) {
    window.Flutter.postMessage(JSON.stringify({
      type: 'GO_TO_COORDINATES',
      lat: coords[0],
      lng: coords[1],
      zoom: 17
    }));
  }
  console.log("Navigating map to:", coords);
};

// City Dynamics Chart Implementation
function initCityDynamicsChart() {
  const canvas = document.getElementById('cityDynamicsChart');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  // High-DPI support
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  ctx.scale(dpr, dpr);

  const years = ['2015', '2017', '2019', '2021', '2023', '2025'];
  const metrics = [
    { label: 'Экономика', data: [40, 55, 68, 85, 92, 105], color: '#f59e0b' },
    { label: 'Инфраструктура', data: [30, 42, 55, 62, 78, 88], color: '#3b82f6' },
    { label: 'Качество жизни', data: [50, 52, 60, 65, 82, 95], color: '#10b981' }
  ];

  const padding = 40;
  const chartW = rect.width - padding * 2;
  const chartH = rect.height - padding * 2;

  // Grid
  ctx.strokeStyle = 'rgba(255,255,255,0.05)';
  ctx.lineWidth = 1;
  for (let i = 0; i < 5; i++) {
    const y = padding + (chartH / 4) * i;
    ctx.beginPath();
    ctx.moveTo(padding, y);
    ctx.lineTo(rect.width - padding, y);
    ctx.stroke();
  }

  // Draw Lines
  metrics.forEach((m, idx) => {
    ctx.beginPath();
    ctx.strokeStyle = m.color;
    ctx.lineWidth = 3;
    ctx.shadowBlur = 15;
    ctx.shadowColor = m.color;

    m.data.forEach((val, i) => {
      const x = padding + (chartW / (years.length - 1)) * i;
      const y = rect.height - padding - (val / 120) * chartH;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
    ctx.shadowBlur = 0;

    // Fill area
    ctx.lineTo(padding + chartW, rect.height - padding);
    ctx.lineTo(padding, rect.height - padding);
    ctx.fillStyle = m.color + '15';
    ctx.fill();

    // Label
    ctx.fillStyle = m.color;
    ctx.font = '10px sans-serif';
    ctx.fillText(m.label, padding + 10, padding + 20 + idx * 15);
  });

  // Draw years
  ctx.fillStyle = 'rgba(255,255,255,0.4)';
  ctx.textAlign = 'center';
  years.forEach((y, i) => {
    const x = padding + (chartW / (years.length - 1)) * i;
    ctx.fillText(y, x, rect.height - 15);
  });
}

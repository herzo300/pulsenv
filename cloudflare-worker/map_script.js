// ═══════════════════════════════════════════════════════
// Пульс города — Карта v6.0 (Капля нефти + Ритм города)
// ═══════════════════════════════════════════════════════

const tg = window.Telegram?.WebApp;
if (tg) {
  tg.ready();
  tg.expand();
  tg.BackButton.show();
  tg.onEvent('backButtonClicked', () => tg.close());
}

// ═══ CONFIGURATION ═══
const CONFIG = {
  firebase: 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase',
  center: [60.9344, 76.5531],
  zoom: 13,
  categories: {
    'ЖКХ': { emoji: '🏘️', color: '#14b8a6', icon: 'mdi:home-city' },
    'Дороги': { emoji: '🛣️', color: '#ef4444', icon: 'mdi:road' },
    'Благоустройство': { emoji: '🌳', color: '#10b981', icon: 'mdi:tree' },
    'Транспорт': { emoji: '🚌', color: '#3b82f6', icon: 'mdi:bus' },
    'Экология': { emoji: '♻️', color: '#22c55e', icon: 'mdi:recycle' },
    'Безопасность': { emoji: '🚨', color: '#dc2626', icon: 'mdi:shield-alert' },
    'Освещение': { emoji: '💡', color: '#f59e0b', icon: 'mdi:lightbulb' },
    'Снег/Наледь': { emoji: '❄️', color: '#06b6d4', icon: 'mdi:snowflake' },
    'Медицина': { emoji: '🏥', color: '#ec4899', icon: 'mdi:hospital-box' },
    'Образование': { emoji: '🏫', color: '#8b5cf6', icon: 'mdi:school' },
    'Парковки': { emoji: '🅿️', color: '#6366f1', icon: 'mdi:parking' },
    'Прочее': { emoji: '❔', color: '#64748b', icon: 'mdi:help-circle' }
  },
  statuses: {
    'open': { label: 'Открыто', color: '#ef4444', icon: 'mdi:alert-circle' },
    'pending': { label: 'Новые', color: '#f59e0b', icon: 'mdi:clock-alert' },
    'in_progress': { label: 'В работе', color: '#f97316', icon: 'mdi:progress-clock' },
    'resolved': { label: 'Решено', color: '#10b981', icon: 'mdi:check-circle' }
  }
};

// ═══ STATE ═══
const state = {
  complaints: [],
  filteredComplaints: [],
  filters: { category: null, status: null, dateRange: null },
  map: null,
  cluster: null,
  loading: true,
  cityRhythm: { bpm: 60, targetBpm: 60, mood: 'Спокойно', severity: 0 }
};

// ═══ STYLES ═══
const styles = `
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #0a0e1a; --surface: rgba(15, 23, 42, 0.95); --text: #e2e8f0;
  --primary: #6366f1; --primary-light: #818cf8; --primary-dark: #4f46e5;
  --success: #10b981; --danger: #ef4444; --warning: #f59e0b; --info: #3b82f6;
  --oil: #1a1a2e; --oil-light: #16213e; --oil-dark: #0f3460;
  --border: rgba(255, 255, 255, 0.1); --shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
  --radius: 16px; --radius-sm: 8px; --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); overflow: hidden; }

/* Particles Background */
#particles-js { position: fixed; inset: 0; z-index: 0; opacity: 0.3; }

/* Splash Screen */
#splash { position: fixed; inset: 0; z-index: 9999; background: linear-gradient(135deg, #0a0e1a 0%, #1e1b4b 50%, #0f3460 100%); display: flex; align-items: center; justify-content: center; transition: opacity 0.6s, transform 0.6s; }
#splash.hide { opacity: 0; transform: scale(1.15); pointer-events: none; }
.splash-content { position: relative; z-index: 1; text-align: center; max-width: 360px; padding: 20px; }

/* Oil Drop Logo */
.oil-drop-container { position: relative; width: 140px; height: 170px; margin: 0 auto 20px; }
.oil-drop { width: 100%; height: 100%; filter: drop-shadow(0 0 20px rgba(99, 102, 241, 0.4)); animation: oilFloat 4s ease-in-out infinite; }
@keyframes oilFloat { 0%, 100% { transform: translateY(0) scale(1); } 50% { transform: translateY(-10px) scale(1.05); } }
.drop-main { animation: oilPulse 2s ease-in-out infinite; }
@keyframes oilPulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.85; } }
.drop-shine { animation: shineMove 3s ease-in-out infinite; }
@keyframes shineMove { 0%, 100% { transform: translate(0, 0); } 50% { transform: translate(5px, -5px); } }
.drop-bubble { animation: bubbleFloat 2.5s ease-in-out infinite; }
@keyframes bubbleFloat { 0%, 100% { transform: translateY(0); opacity: 0.1; } 50% { transform: translateY(-15px); opacity: 0.3; } }
.pulse-rings { position: absolute; inset: -20px; }
.pulse-ring { position: absolute; inset: 0; border-radius: 50%; border: 2px solid var(--primary); opacity: 0; animation: ringPulse 3s ease-out infinite; }
.pulse-ring:nth-child(2) { animation-delay: 1s; }
.pulse-ring:nth-child(3) { animation-delay: 2s; }
@keyframes ringPulse { 0% { transform: scale(0.8); opacity: 0.6; } 100% { transform: scale(1.5); opacity: 0; } }

/* Title */
.splash-title { font-size: 32px; font-weight: 900; background: linear-gradient(135deg, #818cf8, #6366f1, #a78bfa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 8px; animation: titleSlide 0.8s ease 0.3s both; display: flex; align-items: center; justify-content: center; gap: 12px; }
.title-icon { font-size: 36px; color: var(--primary-light); animation: iconSpin 3s ease-in-out infinite; }
@keyframes iconSpin { 0%, 100% { transform: rotate(0deg); } 50% { transform: rotate(10deg); } }
@keyframes titleSlide { from { opacity: 0; transform: translateX(-30px); } to { opacity: 1; transform: translateX(0); } }
.splash-subtitle { font-size: 11px; letter-spacing: 4px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; font-weight: 700; margin-bottom: 24px; animation: fadeIn 0.8s ease 0.5s both; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }

/* City Rhythm Visualizer */
.rhythm-container { position: relative; margin: 0 auto 20px; animation: fadeIn 0.8s ease 0.7s both; }
#rhythmCanvas { display: block; margin: 0 auto; opacity: 0.9; }
.rhythm-info { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 12px; }
.rhythm-bpm { font-size: 36px; font-weight: 900; color: var(--success); line-height: 1; font-variant-numeric: tabular-nums; transition: color 0.5s; animation: bpmPulse 1s ease-in-out infinite; }
@keyframes bpmPulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.05); } }
.rhythm-label { font-size: 9px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; letter-spacing: 1px; }
.rhythm-mood { font-size: 13px; font-weight: 700; color: var(--success); transition: color 0.5s; padding: 4px 12px; background: rgba(16, 185, 129, 0.15); border-radius: 12px; }

/* Stats Cards */
.splash-stats { display: flex; justify-content: center; gap: 12px; margin-bottom: 20px; animation: fadeIn 0.8s ease 0.9s both; }
.stat-card { text-align: center; background: rgba(15, 23, 42, 0.8); border-radius: var(--radius-sm); padding: 12px; min-width: 80px; box-shadow: 4px 4px 12px rgba(0, 0, 0, 0.6), -2px -2px 8px rgba(255, 255, 255, 0.02); backdrop-filter: blur(10px); border: 1px solid var(--border); transition: var(--transition); }
.stat-card:hover { transform: translateY(-2px); box-shadow: 6px 6px 16px rgba(0, 0, 0, 0.7), -3px -3px 10px rgba(255, 255, 255, 0.03); }
.stat-icon { display: block; font-size: 24px; margin-bottom: 6px; opacity: 0.7; }
.stat-num { display: block; font-size: 24px; font-weight: 900; color: var(--primary-light); line-height: 1; }
.stat-label { display: block; font-size: 8px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px; font-weight: 600; }

/* Progress */
.splash-progress { animation: fadeIn 0.8s ease 1.1s both; }
.progress-bar { position: relative; width: 220px; height: 6px; background: rgba(255, 255, 255, 0.1); border-radius: 3px; margin: 0 auto 10px; overflow: hidden; }
.progress-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--primary), var(--success)); border-radius: 3px; transition: width 0.3s; position: relative; z-index: 1; }
.progress-glow { position: absolute; inset: 0; background: linear-gradient(90deg, transparent, rgba(99, 102, 241, 0.5), transparent); animation: progressGlow 2s ease-in-out infinite; }
@keyframes progressGlow { 0%, 100% { transform: translateX(-100%); } 50% { transform: translateX(100%); } }
.progress-text { font-size: 10px; color: rgba(255, 255, 255, 0.3); font-weight: 500; }

/* Main App */
#app { position: relative; width: 100%; height: 100vh; }
#map { position: absolute; inset: 0; z-index: 0; }

/* Top Bar */
#topBar { position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: var(--surface); backdrop-filter: blur(20px); border-bottom: 1px solid var(--border); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between; box-shadow: var(--shadow); }
.tb-left { display: flex; align-items: center; gap: 10px; }
.oil-pulse-mini { width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; color: var(--primary-light); animation: oilPulseMini 2s ease-in-out infinite; }
@keyframes oilPulseMini { 0%, 100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.1); opacity: 0.8; } }
.tb-title { font-size: 15px; font-weight: 800; }
.tb-right { display: flex; gap: 10px; }
.stat-mini { text-align: center; min-width: 42px; }
.stat-mini .num { display: block; font-size: 16px; font-weight: 800; line-height: 1; }
.stat-mini .lbl { display: block; font-size: 7px; color: rgba(255, 255, 255, 0.5); text-transform: uppercase; letter-spacing: 0.5px; margin-top: 2px; }
.stat-mini.red .num { color: var(--danger); }
.stat-mini.green .num { color: var(--success); }

/* Filter Panel */
#filterPanel { position: fixed; top: 54px; left: 0; right: 0; z-index: 999; background: linear-gradient(to bottom, var(--surface) 80%, transparent); backdrop-filter: blur(20px); padding: 8px 10px; border-bottom: 1px solid var(--border); }
.filter-row { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; padding: 4px 0; }
.filter-row::-webkit-scrollbar { display: none; }
.filter-chip { flex-shrink: 0; padding: 7px 14px; border-radius: 20px; font-size: 11px; font-weight: 600; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border); color: rgba(255, 255, 255, 0.6); cursor: pointer; transition: var(--transition); white-space: nowrap; user-select: none; display: flex; align-items: center; gap: 6px; }
.filter-chip:active { transform: scale(0.95); }
.filter-chip.active { background: var(--primary); color: #fff; border-color: var(--primary); box-shadow: 0 2px 10px rgba(99, 102, 241, 0.4); }
.filter-chip.status-open.active { background: var(--danger); border-color: var(--danger); }
.filter-chip.status-pending.active { background: var(--warning); border-color: var(--warning); color: #000; }
.filter-chip.status-resolved.active { background: var(--success); border-color: var(--success); }

/* Action Buttons */
.action-btn { position: fixed; z-index: 1001; width: 50px; height: 50px; border-radius: var(--radius); background: var(--surface); backdrop-filter: blur(20px); border: 1px solid var(--border); color: var(--primary-light); font-size: 24px; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: var(--shadow); transition: var(--transition); }
.action-btn:active { transform: scale(0.9) rotate(-5deg); }
.action-btn:hover { box-shadow: 0 0 20px rgba(99, 102, 241, 0.5); }
.stats-btn { top: 10px; right: 68px; }
.uk-btn { top: 10px; right: 10px; }

/* FAB - Oil Drop */
.fab { position: fixed; bottom: 80px; right: 14px; z-index: 1001; width: 64px; height: 64px; border: none; background: transparent; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: var(--transition); }
.fab:active { transform: scale(0.9); }
.fab-drop { position: relative; width: 56px; height: 68px; }
.fab-drop svg { width: 100%; height: 100%; filter: drop-shadow(0 4px 16px rgba(99, 102, 241, 0.6)); animation: fabFloat 3s ease-in-out infinite; }
@keyframes fabFloat { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-6px); } }
.fab-icon { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 28px; font-weight: 900; color: #fff; z-index: 1; text-shadow: 0 2px 8px rgba(0, 0, 0, 0.4); }
.fab-ripples { position: absolute; inset: -10px; }
.fab-ripple { position: absolute; inset: 0; border-radius: 50%; border: 2px solid var(--primary); opacity: 0; animation: fabRipple 2.5s ease-out infinite; }
.fab-ripple:nth-child(2) { animation-delay: 1.25s; }
@keyframes fabRipple { 0% { transform: scale(0.8); opacity: 0.6; } 100% { transform: scale(1.6); opacity: 0; } }

/* Timeline */
.timeline-panel { position: fixed; bottom: 0; left: 0; right: 0; z-index: 999; height: 70px; background: var(--surface); backdrop-filter: blur(20px); border-top: 1px solid var(--border); padding: 10px; box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.3); }
#timelineCanvas { width: 100%; height: 50px; display: block; }

/* Overlays */
.overlay { position: fixed; top: 0; right: -100%; width: 340px; height: 100%; z-index: 2500; background: var(--surface); backdrop-filter: blur(20px); border-left: 1px solid var(--border); box-shadow: -4px 0 20px rgba(0, 0, 0, 0.5); transition: right 0.4s cubic-bezier(0.4, 0, 0.2, 1); overflow-y: auto; }
.overlay.left { right: auto; left: -100%; border-left: none; border-right: 1px solid var(--border); box-shadow: 4px 0 20px rgba(0, 0, 0, 0.5); transition: left 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
.overlay.open { right: 0; }
.overlay.left.open { left: 0; }
.overlay-header { position: sticky; top: 0; background: var(--surface); padding: 18px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; z-index: 1; }
.overlay-header h3 { font-size: 17px; font-weight: 800; display: flex; align-items: center; gap: 8px; }
.close-btn { background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border); color: rgba(255, 255, 255, 0.6); font-size: 20px; cursor: pointer; padding: 0; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 50%; transition: var(--transition); }
.close-btn:hover { background: rgba(255, 255, 255, 0.1); transform: rotate(90deg); }
.overlay-content { padding: 18px; }

/* Modal */
.modal { position: fixed; inset: 0; z-index: 3000; display: none; align-items: center; justify-content: center; padding: 20px; }
.modal.show { display: flex; }
.modal-backdrop { position: absolute; inset: 0; background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(8px); }
.modal-content { position: relative; background: var(--surface); border-radius: var(--radius); max-width: 420px; width: 100%; max-height: 90vh; overflow: hidden; box-shadow: 0 8px 40px rgba(0, 0, 0, 0.6); border: 1px solid var(--border); animation: modalIn 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
@keyframes modalIn { from { opacity: 0; transform: scale(0.9) translateY(30px); } to { opacity: 1; transform: scale(1) translateY(0); } }
.modal-header { padding: 20px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; }
.modal-header h3 { font-size: 18px; font-weight: 800; display: flex; align-items: center; gap: 10px; }
.modal-body { padding: 20px; max-height: calc(90vh - 140px); overflow-y: auto; }
.modal-footer { padding: 20px; border-top: 1px solid var(--border); display: flex; gap: 12px; }
.form-group { margin-bottom: 16px; }
.form-group label { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.7); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
.form-group input, .form-group textarea, .form-group select { width: 100%; padding: 12px 14px; border-radius: var(--radius-sm); border: 1px solid var(--border); background: rgba(255, 255, 255, 0.05); color: var(--text); font-size: 14px; font-family: inherit; outline: none; transition: var(--transition); }
.form-group input:focus, .form-group textarea:focus, .form-group select:focus { border-color: var(--primary); background: rgba(255, 255, 255, 0.08); box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1); }
.form-group textarea { resize: vertical; min-height: 90px; }
.form-row { display: flex; gap: 12px; }
.form-row .form-group { flex: 1; }
.gps-btn { margin-left: auto; font-size: 11px; color: var(--primary); cursor: pointer; font-weight: 600; display: flex; align-items: center; gap: 4px; padding: 4px 8px; border-radius: 6px; background: rgba(99, 102, 241, 0.1); transition: var(--transition); }
.gps-btn:hover { background: rgba(99, 102, 241, 0.2); }
.btn { flex: 1; padding: 12px 20px; border-radius: var(--radius-sm); border: none; font-size: 14px; font-weight: 700; cursor: pointer; transition: var(--transition); display: flex; align-items: center; justify-content: center; gap: 8px; }
.btn-primary { background: var(--primary); color: #fff; }
.btn-primary:hover { background: var(--primary-dark); box-shadow: 0 4px 12px rgba(99, 102, 241, 0.4); }
.btn-primary:active { transform: scale(0.97); }
.btn-secondary { background: rgba(255, 255, 255, 0.1); color: rgba(255, 255, 255, 0.8); }
.btn-secondary:hover { background: rgba(255, 255, 255, 0.15); }
.btn-secondary:active { transform: scale(0.97); }

/* Toast */
.toast { position: fixed; top: 80px; left: 50%; transform: translateX(-50%); z-index: 4000; background: var(--success); color: #fff; padding: 14px 24px; border-radius: var(--radius-sm); font-size: 14px; font-weight: 600; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4); opacity: 0; pointer-events: none; transition: opacity 0.3s, transform 0.3s; display: flex; align-items: center; gap: 10px; }
.toast.show { opacity: 1; transform: translateX(-50%) translateY(0); pointer-events: auto; animation: toastIn 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
@keyframes toastIn { from { transform: translateX(-50%) translateY(-20px); } to { transform: translateX(-50%) translateY(0); } }
.toast.error { background: var(--danger); }
.toast.warning { background: var(--warning); color: #000; }
.toast-icon { font-size: 20px; }

/* Leaflet Popup */
.leaflet-popup-content-wrapper { background: var(--surface) !important; color: var(--text) !important; border: 1px solid var(--border) !important; border-radius: var(--radius) !important; backdrop-filter: blur(20px) !important; box-shadow: 0 8px 40px rgba(0, 0, 0, 0.6) !important; }
.leaflet-popup-tip { background: var(--surface) !important; }
.leaflet-popup-content { margin: 14px !important; min-width: 220px; }
.popup-header { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.popup-icon { font-size: 22px; }
.popup-title { font-size: 15px; font-weight: 700; flex: 1; }
.popup-badge { display: inline-block; padding: 4px 10px; border-radius: 12px; font-size: 10px; font-weight: 700; color: #fff; }
.popup-desc { font-size: 13px; color: rgba(255, 255, 255, 0.7); line-height: 1.5; margin-bottom: 10px; }
.popup-meta { font-size: 11px; color: rgba(255, 255, 255, 0.5); margin-bottom: 6px; display: flex; align-items: center; gap: 6px; }
.popup-actions { display: flex; gap: 8px; margin-top: 10px; flex-wrap: wrap; }
.popup-btn { flex: 1; min-width: 100px; padding: 8px 12px; border-radius: var(--radius-sm); border: 1px solid var(--border); background: rgba(255, 255, 255, 0.05); color: rgba(255, 255, 255, 0.8); font-size: 12px; font-weight: 600; cursor: pointer; transition: var(--transition); text-align: center; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 6px; }
.popup-btn:hover { background: rgba(255, 255, 255, 0.1); transform: translateY(-1px); }
.popup-btn:active { transform: translateY(0) scale(0.98); }
`;

const styleEl = document.createElement('style');
styleEl.textContent = styles;
document.head.appendChild(styleEl);

// ═══ CITY RHYTHM — Ритм города (реагирует на жалобы) ═══
const CityRhythm = {
  canvas: null,
  ctx: null,
  bpm: 60,
  targetBpm: 60,
  mood: 'Спокойно',
  severity: 0,
  history: [],
  time: 0,
  
  init() {
    this.canvas = document.getElementById('rhythmCanvas');
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.history = new Array(160).fill(0);
    this.animate();
  },
  
  feed(complaints) {
    if (!complaints || !complaints.length) return;
    
    const now = Date.now();
    const recent = complaints.filter(c => {
      const d = new Date(c.created_at || c.date || 0);
      return now - d.getTime() < 86400000; // Last 24h
    });
    
    const count = recent.length;
    let severity = 0;
    
    // Calculate severity based on categories
    recent.forEach(c => {
      const cat = c.category || '';
      if (['ЧП', 'Безопасность', 'Газоснабжение'].includes(cat)) severity += 3;
      else if (['Дороги', 'ЖКХ', 'Отопление', 'Водоснабжение и канализация'].includes(cat)) severity += 2;
      else severity += 1;
    });
    
    this.severity = Math.min(severity, 100);
    
    // BPM calculation: base 60 + severity factor + count factor
    this.targetBpm = Math.min(60 + this.severity * 0.8 + count * 1.5, 150);
    
    // Mood determination
    if (this.targetBpm < 70) {
      this.mood = 'Спокойно';
    } else if (this.targetBpm < 90) {
      this.mood = 'Умеренно';
    } else if (this.targetBpm < 120) {
      this.mood = 'Напряжённо';
    } else {
      this.mood = 'Тревожно';
    }
    
    // Update UI
    const bpmEl = document.getElementById('rhythmBpm');
    const moodEl = document.getElementById('rhythmMood');
    
    if (bpmEl) {
      bpmEl.textContent = Math.round(this.targetBpm);
      bpmEl.style.color = this.getColor();
    }
    
    if (moodEl) {
      moodEl.textContent = this.mood;
      moodEl.style.color = this.getColor();
      moodEl.style.background = this.getColor() + '22';
    }
  },
  
  getColor() {
    if (this.bpm < 70) return '#10b981'; // green
    if (this.bpm < 90) return '#f59e0b'; // yellow
    if (this.bpm < 120) return '#f97316'; // orange
    return '#ef4444'; // red
  },
  
  animate() {
    if (!this.ctx) return;
    
    const ctx = this.ctx;
    const W = this.canvas.width;
    const H = this.canvas.height;
    
    // Smooth BPM transition
    this.bpm += (this.targetBpm - this.bpm) * 0.02;
    
    // Time progression
    this.time += this.bpm / 3600; // Adjust speed based on BPM
    
    // Generate oil drop wave pattern
    const phase = (this.time % 1);
    let value = 0;
    
    // Oil drop pulse pattern (more organic than ECG)
    if (phase < 0.1) {
      value = Math.sin(phase / 0.1 * Math.PI) * 0.4;
    } else if (phase < 0.2) {
      value = Math.sin((phase - 0.1) / 0.1 * Math.PI) * 0.8;
    } else if (phase < 0.3) {
      value = -Math.sin((phase - 0.2) / 0.1 * Math.PI) * 0.3;
    } else if (phase < 0.5) {
      value = Math.sin((phase - 0.3) / 0.2 * Math.PI) * 0.2;
    } else {
      value = 0;
    }
    
    // Add noise for organic feel
    value += (Math.random() - 0.5) * 0.05;
    
    this.history.push(value);
    if (this.history.length > 160) this.history.shift();
    
    // Clear canvas
    ctx.clearRect(0, 0, W, H);
    
    // Draw gradient background
    const grad = ctx.createLinearGradient(0, 0, W, 0);
    grad.addColorStop(0, 'rgba(99, 102, 241, 0.05)');
    grad.addColorStop(0.5, 'rgba(99, 102, 241, 0.1)');
    grad.addColorStop(1, 'rgba(99, 102, 241, 0.05)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);
    
    // Draw waveform
    const color = this.getColor();
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.shadowColor = color;
    ctx.shadowBlur = 8;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    
    ctx.beginPath();
    const step = W / 160;
    
    for (let i = 0; i < this.history.length; i++) {
      const x = i * step;
      const y = H / 2 - this.history[i] * (H / 2 - 10);
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Draw oil drops at peaks
    this.history.forEach((val, i) => {
      if (Math.abs(val) > 0.6) {
        const x = i * step;
        const y = H / 2 - val * (H / 2 - 10);
        
        ctx.fillStyle = color + '44';
        ctx.beginPath();
        ctx.arc(x, y, 4, 0, Math.PI * 2);
        ctx.fill();
      }
    });
    
    requestAnimationFrame(() => this.animate());
  }
};

// ═══ PARTICLES INIT ═══
function initParticles() {
  if (typeof particlesJS === 'undefined') return;
  
  particlesJS('particles-js', {
    particles: {
      number: { value: 50, density: { enable: true, value_area: 800 } },
      color: { value: '#6366f1' },
      shape: { type: 'circle' },
      opacity: { value: 0.3, random: true },
      size: { value: 3, random: true },
      line_linked: {
        enable: true,
        distance: 150,
        color: '#6366f1',
        opacity: 0.2,
        width: 1
      },
      move: {
        enable: true,
        speed: 1,
        direction: 'none',
        random: true,
        straight: false,
        out_mode: 'out',
        bounce: false
      }
    },
    interactivity: {
      detect_on: 'canvas',
      events: {
        onhover: { enable: false },
        onclick: { enable: false },
        resize: true
      }
    },
    retina_detect: true
  });
}

// ═══ OIL DROP ANIMATION (Splash) ═══
function animateOilDrop() {
  const drop = document.querySelector('.oil-drop');
  if (!drop || typeof anime === 'undefined') return;
  
  // Animate oil drop with anime.js
  anime({
    targets: '.drop-main',
    d: [
      { value: 'M100 20 C100 20, 40 80, 40 140 C40 180, 65 220, 100 220 C135 220, 160 180, 160 140 C160 80, 100 20, 100 20 Z' },
      { value: 'M100 20 C100 20, 45 85, 45 140 C45 175, 68 215, 100 215 C132 215, 155 175, 155 140 C155 85, 100 20, 100 20 Z' },
      { value: 'M100 20 C100 20, 40 80, 40 140 C40 180, 65 220, 100 220 C135 220, 160 180, 160 140 C160 80, 100 20, 100 20 Z' }
    ],
    duration: 3000,
    easing: 'easeInOutQuad',
    loop: true
  });
  
  // Animate bubbles
  anime({
    targets: '.drop-bubble',
    cy: [120, 80, 120],
    opacity: [0.1, 0.3, 0.1],
    duration: 2500,
    easing: 'easeInOutSine',
    loop: true
  });
}

// ═══ SPLASH SCREEN ═══
async function showSplash() {
  initParticles();
  animateOilDrop();
  CityRhythm.init();
  
  const progressFill = document.getElementById('progressFill');
  const progressText = document.getElementById('progressText');
  
  // Simulate loading
  const steps = [
    { progress: 20, text: 'Подключение к серверу...' },
    { progress: 40, text: 'Загрузка данных...' },
    { progress: 60, text: 'Анализ жалоб...' },
    { progress: 80, text: 'Инициализация карты...' },
    { progress: 100, text: 'Готово!' }
  ];
  
  for (const step of steps) {
    if (progressFill) progressFill.style.width = step.progress + '%';
    if (progressText) progressText.textContent = step.text;
    await new Promise(resolve => setTimeout(resolve, 400));
  }
  
  // Load actual data
  await loadData();
  
  // Hide splash
  setTimeout(() => {
    const splash = document.getElementById('splash');
    if (splash) {
      splash.classList.add('hide');
      setTimeout(() => {
        splash.style.display = 'none';
        document.getElementById('app').style.display = 'block';
        initMap();
      }, 600);
    }
  }, 500);
}

// ═══ DATA LOADING ═══
async function loadData() {
  try {
    const response = await fetch(CONFIG.firebase + '/complaints.json', {
      signal: AbortSignal.timeout(8000)
    });
    
    if (!response.ok) throw new Error('Failed to load data');
    
    const data = await response.json();
    
    if (data) {
      state.complaints = Object.entries(data).map(([id, complaint]) => ({
        id,
        ...complaint
      }));
      
      state.filteredComplaints = [...state.complaints];
      
      // Update splash stats
      const total = state.complaints.length;
      const open = state.complaints.filter(c => c.status === 'open').length;
      const resolved = state.complaints.filter(c => c.status === 'resolved').length;
      
      document.getElementById('statTotal').textContent = total;
      document.getElementById('statOpen').textContent = open;
      document.getElementById('statResolved').textContent = resolved;
      
      // Feed to City Rhythm
      CityRhythm.feed(state.complaints);
    }
  } catch (error) {
    console.error('Error loading data:', error);
    showToast('Ошибка загрузки данных', 'error');
  }
}

// ═══ MAP INITIALIZATION ═══
function initMap() {
  // Initialize Leaflet map
  state.map = L.map('map', {
    center: CONFIG.center,
    zoom: CONFIG.zoom,
    zoomControl: false
  });
  
  // Add tile layer (Shortbread OSM)
  L.tileLayer('https://tiles.openfreemap.org/styles/liberty/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap',
    maxZoom: 19
  }).addTo(state.map);
  
  // Initialize marker cluster
  state.cluster = L.markerClusterGroup({
    maxClusterRadius: 50,
    spiderfyOnMaxZoom: true,
    showCoverageOnHover: false,
    zoomToBoundsOnClick: true
  });
  
  // Render markers
  renderMarkers();
  
  // Initialize filters
  initFilters();
  
  // Initialize timeline
  initTimeline();
  
  // Setup event listeners
  setupEventListeners();
}

// ═══ HELPERS ═══
function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  const toastText = document.getElementById('toastText');
  const toastIcon = document.getElementById('toastIcon');
  
  if (!toast) return;
  
  const icons = {
    success: 'mdi:check-circle',
    error: 'mdi:alert-circle',
    warning: 'mdi:alert'
  };
  
  toast.className = 'toast ' + type;
  toastText.textContent = message;
  toastIcon.setAttribute('data-icon', icons[type] || icons.success);
  
  toast.classList.add('show');
  
  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

function closeOverlay(id) {
  const overlay = document.getElementById(id);
  if (overlay) overlay.classList.remove('open');
}

function closeModal() {
  const modal = document.getElementById('complaintModal');
  if (modal) modal.classList.remove('show');
}

// ═══ INITIALIZATION ═══
document.addEventListener('DOMContentLoaded', () => {
  showSplash();
});

// ═══ RENDER MARKERS ═══
function renderMarkers() {
  if (!state.map || !state.cluster) return;
  
  state.cluster.clearLayers();
  
  let total = 0, open = 0, resolved = 0;
  
  state.filteredComplaints.forEach(complaint => {
    if (!complaint.lat || !complaint.lng) return;
    
    total++;
    if (complaint.status === 'open') open++;
    if (complaint.status === 'resolved') resolved++;
    
    const category = CONFIG.categories[complaint.category] || CONFIG.categories['Прочее'];
    const icon = L.divIcon({
      html: `<div style="width:32px;height:32px;border-radius:50%;background:${category.color};display:flex;align-items:center;justify-content:center;font-size:16px;border:2px solid rgba(255,255,255,0.3);box-shadow:0 2px 8px ${category.color}66">${category.emoji}</div>`,
      className: '',
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -18]
    });
    
    const marker = L.marker([complaint.lat, complaint.lng], { icon });
    
    const popupContent = `
      <div class="popup-header">
        <span class="popup-icon">${category.emoji}</span>
        <span class="popup-title">${complaint.category}</span>
      </div>
      <div class="popup-badge" style="background:${CONFIG.statuses[complaint.status]?.color || '#64748b'}">${CONFIG.statuses[complaint.status]?.label || complaint.status}</div>
      <div class="popup-desc">${(complaint.summary || complaint.text || '').substring(0, 150)}</div>
      ${complaint.address ? `<div class="popup-meta"><span data-icon="mdi:map-marker"></span> ${complaint.address}</div>` : ''}
      <div class="popup-meta"><span data-icon="mdi:calendar"></span> ${new Date(complaint.created_at).toLocaleDateString('ru-RU')}</div>
      <div class="popup-actions">
        <a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${complaint.lat},${complaint.lng}" target="_blank" class="popup-btn">
          <span data-icon="mdi:google-street-view"></span> Street View
        </a>
        <a href="https://yandex.ru/maps/?pt=${complaint.lng},${complaint.lat}&z=17&l=map" target="_blank" class="popup-btn">
          <span data-icon="mdi:map"></span> Яндекс
        </a>
      </div>
    `;
    
    marker.bindPopup(popupContent, { maxWidth: 280 });
    state.cluster.addLayer(marker);
  });
  
  state.map.addLayer(state.cluster);
  
  // Update stats
  document.getElementById('totalNum').textContent = total;
  document.getElementById('openNum').textContent = open;
  document.getElementById('resolvedNum').textContent = resolved;
}

// ═══ FILTERS ═══
function initFilters() {
  // Category filter
  const catFilter = document.getElementById('categoryFilter');
  if (catFilter) {
    const allChip = document.createElement('div');
    allChip.className = 'filter-chip active';
    allChip.innerHTML = '<span data-icon="mdi:filter-variant"></span> Все';
    allChip.onclick = () => {
      state.filters.category = null;
      applyFilters();
    };
    catFilter.appendChild(allChip);
    
    Object.entries(CONFIG.categories).forEach(([name, cat]) => {
      const chip = document.createElement('div');
      chip.className = 'filter-chip';
      chip.innerHTML = `<span data-icon="${cat.icon}"></span> ${name}`;
      chip.onclick = () => {
        state.filters.category = name;
        applyFilters();
      };
      catFilter.appendChild(chip);
    });
  }
  
  // Status filter
  const statusFilter = document.getElementById('statusFilter');
  if (statusFilter) {
    const allChip = document.createElement('div');
    allChip.className = 'filter-chip active';
    allChip.innerHTML = '<span data-icon="mdi:filter"></span> Все';
    allChip.onclick = () => {
      state.filters.status = null;
      applyFilters();
    };
    statusFilter.appendChild(allChip);
    
    Object.entries(CONFIG.statuses).forEach(([key, status]) => {
      const chip = document.createElement('div');
      chip.className = `filter-chip status-${key}`;
      chip.innerHTML = `<span data-icon="${status.icon}"></span> ${status.label}`;
      chip.onclick = () => {
        state.filters.status = key;
        applyFilters();
      };
      statusFilter.appendChild(chip);
    });
  }
}

function applyFilters() {
  state.filteredComplaints = state.complaints.filter(c => {
    if (state.filters.category && c.category !== state.filters.category) return false;
    if (state.filters.status && c.status !== state.filters.status) return false;
    return true;
  });
  
  renderMarkers();
  updateFilterUI();
}

function updateFilterUI() {
  document.querySelectorAll('.filter-chip').forEach(chip => {
    chip.classList.remove('active');
  });
  
  const catFilter = document.getElementById('categoryFilter');
  const statusFilter = document.getElementById('statusFilter');
  
  if (catFilter) {
    const chips = catFilter.querySelectorAll('.filter-chip');
    if (state.filters.category) {
      chips.forEach(chip => {
        if (chip.textContent.includes(state.filters.category)) {
          chip.classList.add('active');
        }
      });
    } else {
      chips[0].classList.add('active');
    }
  }
  
  if (statusFilter) {
    const chips = statusFilter.querySelectorAll('.filter-chip');
    if (state.filters.status) {
      chips.forEach(chip => {
        if (chip.className.includes(state.filters.status)) {
          chip.classList.add('active');
        }
      });
    } else {
      chips[0].classList.add('active');
    }
  }
}

// ═══ TIMELINE ═══
function initTimeline() {
  const canvas = document.getElementById('timelineCanvas');
  if (!canvas) return;
  
  const ctx = canvas.getContext('2d');
  canvas.width = canvas.offsetWidth * 2;
  canvas.height = 50 * 2;
  ctx.scale(2, 2);
  
  drawTimeline(ctx, canvas.offsetWidth, 50);
}

function drawTimeline(ctx, W, H) {
  ctx.clearRect(0, 0, W, H);
  
  // Group by date
  const dates = {};
  state.filteredComplaints.forEach(c => {
    const date = new Date(c.created_at).toISOString().split('T')[0];
    dates[date] = (dates[date] || 0) + 1;
  });
  
  const sortedDates = Object.keys(dates).sort();
  if (sortedDates.length === 0) return;
  
  const maxCount = Math.max(...Object.values(dates));
  const barWidth = Math.max(2, Math.min(8, (W - 20) / sortedDates.length - 1));
  const startX = (W - sortedDates.length * (barWidth + 1)) / 2;
  
  sortedDates.forEach((date, i) => {
    const count = dates[date];
    const height = (count / maxCount) * (H - 10);
    const x = startX + i * (barWidth + 1);
    const y = H - height - 5;
    
    ctx.fillStyle = 'rgba(99, 102, 241, 0.6)';
    ctx.fillRect(x, y, barWidth, height);
  });
}

// ═══ EVENT LISTENERS ═══
function setupEventListeners() {
  // Stats button
  const statsBtn = document.getElementById('statsBtn');
  if (statsBtn) {
    statsBtn.onclick = () => {
      const overlay = document.getElementById('statsOverlay');
      if (overlay) overlay.classList.toggle('open');
    };
  }
  
  // UK button
  const ukBtn = document.getElementById('ukBtn');
  if (ukBtn) {
    ukBtn.onclick = () => {
      const overlay = document.getElementById('ukOverlay');
      if (overlay) overlay.classList.toggle('open');
    };
  }
  
  // FAB button
  const fabBtn = document.getElementById('fabBtn');
  if (fabBtn) {
    fabBtn.onclick = () => {
      const modal = document.getElementById('complaintModal');
      if (modal) modal.classList.add('show');
    };
  }
  
  // GPS button
  const gpsBtn = document.getElementById('gpsBtn');
  if (gpsBtn) {
    gpsBtn.onclick = () => {
      if (navigator.geolocation) {
        gpsBtn.innerHTML = '<span data-icon="mdi:loading"></span> Определение...';
        navigator.geolocation.getCurrentPosition(
          (position) => {
            document.getElementById('formLat').value = position.coords.latitude.toFixed(4);
            document.getElementById('formLng').value = position.coords.longitude.toFixed(4);
            gpsBtn.innerHTML = '<span data-icon="mdi:check"></span> Определено';
            setTimeout(() => {
              gpsBtn.innerHTML = '<span data-icon="mdi:crosshairs-gps"></span> Определить';
            }, 2000);
          },
          (error) => {
            showToast('Не удалось определить местоположение', 'error');
            gpsBtn.innerHTML = '<span data-icon="mdi:crosshairs-gps"></span> Определить';
          }
        );
      } else {
        showToast('Геолокация не поддерживается', 'error');
      }
    };
  }
}

// ═══ SUBMIT COMPLAINT ═══
function submitComplaint() {
  const category = document.getElementById('formCategory').value;
  const description = document.getElementById('formDescription').value;
  const address = document.getElementById('formAddress').value;
  const lat = document.getElementById('formLat').value;
  const lng = document.getElementById('formLng').value;
  
  if (!category || !description) {
    showToast('Заполните все обязательные поля', 'warning');
    return;
  }
  
  const complaint = {
    category,
    text: description,
    address,
    lat: lat ? parseFloat(lat) : null,
    lng: lng ? parseFloat(lng) : null,
    created_at: new Date().toISOString(),
    status: 'open',
    source: 'webapp'
  };
  
  // Send to Firebase
  fetch(CONFIG.firebase + '/complaints.json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(complaint)
  })
  .then(response => response.json())
  .then(data => {
    showToast('Жалоба отправлена!', 'success');
    closeModal();
    // Reload data
    loadData().then(() => renderMarkers());
  })
  .catch(error => {
    console.error('Error submitting complaint:', error);
    showToast('Ошибка отправки жалобы', 'error');
  });
}

// ═══ INITIALIZATION ═══
document.addEventListener('DOMContentLoaded', () => {
  showSplash();
});

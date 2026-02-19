// ═══════════════════════════════════════════════════════
// Пульс города — Карта v6.0 (Капля нефти + Ритм города)
// ═══════════════════════════════════════════════════════

const tg = window.Telegram?.WebApp;
if (tg) {
  tg.ready();
  tg.expand();
  tg.BackButton.show();
  tg.onEvent('backButtonClicked', () => tg.close());
  
  // Enable haptic feedback
  tg.enableClosingConfirmation();
}

// ═══ CONFIGURATION ═══
const CONFIG = {
  // Множественные источники данных (fallback chain)
  dataSources: [
    {
      name: 'proxy',
      url: 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase/complaints.json',
      timeout: 8000,
      priority: 1
    },
    {
      name: 'firebase-direct',
      url: 'https://soobshio-default-rtdb.europe-west1.firebasedatabase.app/complaints.json',
      timeout: 10000,
      priority: 2
    },
    {
      name: 'local-api',
      url: 'http://127.0.0.1:8000/api/reports',
      timeout: 5000,
      priority: 3
    }
  ],
  firebase: 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase', // Для обратной совместимости
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
  cityRhythm: { bpm: 60, targetBpm: 60, mood: 'Спокойно', severity: 0 },
  lastUpdateTime: null,
  realtimeInterval: null,
  knownComplaintIds: new Set(),
  connectionStatus: 'checking', // 'online', 'offline', 'checking', 'cached'
  activeDataSource: null,
  cacheEnabled: true,
  cacheKey: 'soobshio_complaints_cache',
  cacheTimestampKey: 'soobshio_cache_timestamp',
  cacheMaxAge: 3600000 // 1 час в миллисекундах
};

// ═══ STYLES ═══
const styles = `
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #0a0a0f; --surface: rgba(10, 15, 30, 0.98); --text: #e0e7ff;
  --primary: #00f0ff; --primary-light: #33f3ff; --primary-dark: #00c8d4;
  --success: #00ff88; --danger: #ff3366; --warning: #ffaa00; --info: #00aaff;
  --neon-cyan: #00f0ff; --neon-pink: #ff00ff; --neon-green: #00ff88; --neon-blue: #0066ff;
  --oil: #0a0a1a; --oil-light: #1a1a2e; --oil-dark: #050510;
  --border: rgba(0, 240, 255, 0.2); --shadow: 0 0 30px rgba(0, 240, 255, 0.3), 0 4px 20px rgba(0, 0, 0, 0.8);
  --radius: 16px; --radius-sm: 8px; --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  --glow: 0 0 20px rgba(0, 240, 255, 0.5), 0 0 40px rgba(0, 240, 255, 0.3);
}
body { font-family: 'Space Grotesk', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); overflow: hidden; line-height: 1.6; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
h1, h2, h3, .tb-title, .splash-title, .modal-header h3 { font-family: 'Rajdhani', sans-serif; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }

/* Aurora Canvas (Северное сияние) */
#auroraCanvas { position: fixed; inset: 0; z-index: 0; }

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
#map { position: absolute; inset: 0; z-index: 1; background: #0a0a0f; }
#map.leaflet-container { background: #0a0a0f !important; }

/* Hi-tech map tile overlay */
#map::before {
  content: '';
  position: absolute;
  inset: 0;
  background: 
    linear-gradient(0deg, transparent 0%, rgba(0, 240, 255, 0.03) 50%, transparent 100%),
    radial-gradient(circle at 50% 50%, rgba(0, 240, 255, 0.05) 0%, transparent 70%);
  pointer-events: none;
  z-index: 1000;
  mix-blend-mode: screen;
}

/* Marker pulse animation */
@keyframes markerPulse {
  0% { transform: scale(0); opacity: 0; box-shadow: 0 0 0 0 rgba(0, 240, 255, 0.7); }
  50% { transform: scale(1.2); opacity: 1; box-shadow: 0 0 30px 10px rgba(0, 240, 255, 0.5); }
  100% { transform: scale(1); opacity: 1; box-shadow: 0 0 20px rgba(0, 240, 255, 0.3); }
}

.marker-container-new { animation: none !important; }
.popup-new-badge {
  display: inline-block;
  padding: 2px 8px;
  background: linear-gradient(135deg, #00f0ff, #00ff88);
  color: #000;
  font-size: 9px;
  font-weight: 900;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 1px;
  animation: neonFlicker 2s ease-in-out infinite;
  box-shadow: 0 0 10px rgba(0, 240, 255, 0.8);
}

@keyframes neonFlicker {
  0%, 100% { opacity: 1; filter: brightness(1); }
  50% { opacity: 0.8; filter: brightness(1.2); }
}

@keyframes pulse-ring {
  0% { transform: scale(1); opacity: 0.5; }
  100% { transform: scale(1.5); opacity: 0; }
}

/* Hi-tech marker glow */
.hi-tech-marker {
  filter: drop-shadow(0 0 8px rgba(0, 240, 255, 0.6));
}

/* Cluster markers hi-tech style */
.marker-cluster {
  background: linear-gradient(135deg, rgba(0, 240, 255, 0.8), rgba(0, 255, 136, 0.6)) !important;
  border: 2px solid rgba(0, 240, 255, 0.9) !important;
  box-shadow: 0 0 20px rgba(0, 240, 255, 0.6), inset 0 0 10px rgba(0, 240, 255, 0.3) !important;
  color: #000 !important;
  font-weight: 900 !important;
  animation: clusterPulse 2s ease-in-out infinite;
}

@keyframes clusterPulse {
  0%, 100% { box-shadow: 0 0 20px rgba(0, 240, 255, 0.6), inset 0 0 10px rgba(0, 240, 255, 0.3); }
  50% { box-shadow: 0 0 30px rgba(0, 240, 255, 0.9), inset 0 0 15px rgba(0, 240, 255, 0.5); }
}

/* Top Bar */
#topBar { 
  position: fixed; top: 0; left: 0; right: 0; z-index: 1000; 
  background: linear-gradient(180deg, rgba(10, 15, 30, 0.98) 0%, rgba(10, 15, 30, 0.85) 100%);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid rgba(0, 240, 255, 0.3);
  padding: 10px 14px; 
  display: flex; 
  align-items: center; 
  justify-content: space-between; 
  box-shadow: 0 4px 30px rgba(0, 0, 0, 0.8), 0 0 20px rgba(0, 240, 255, 0.2);
}
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
#filterPanel { 
  position: fixed; top: 54px; left: 0; right: 0; z-index: 999; 
  background: linear-gradient(to bottom, rgba(10, 15, 30, 0.95) 0%, rgba(10, 15, 30, 0.7) 80%, transparent 100%);
  backdrop-filter: blur(20px);
  padding: 8px 10px; 
  border-bottom: 1px solid rgba(0, 240, 255, 0.2);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}
.filter-row { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; padding: 4px 0; }
.filter-row::-webkit-scrollbar { display: none; }
.filter-chip { flex-shrink: 0; padding: 7px 14px; border-radius: 20px; font-size: 11px; font-weight: 600; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border); color: rgba(255, 255, 255, 0.6); cursor: pointer; transition: var(--transition); white-space: nowrap; user-select: none; display: flex; align-items: center; gap: 6px; }
.filter-chip:active { transform: scale(0.95); }
.filter-chip.active { 
  background: linear-gradient(135deg, var(--primary), var(--primary-dark)); 
  color: #000; 
  border-color: var(--primary); 
  box-shadow: 0 0 15px rgba(0, 240, 255, 0.6), 0 2px 10px rgba(0, 240, 255, 0.4);
  font-weight: 700;
  text-shadow: 0 0 10px rgba(0, 240, 255, 0.8);
}
.filter-chip.status-open.active { background: var(--danger); border-color: var(--danger); }
.filter-chip.status-pending.active { background: var(--warning); border-color: var(--warning); color: #000; }
.filter-chip.status-resolved.active { background: var(--success); border-color: var(--success); }

/* Action Buttons */
.action-btn { 
  position: fixed; z-index: 1001; width: 50px; height: 50px; border-radius: var(--radius); 
  background: linear-gradient(135deg, rgba(10, 15, 30, 0.95), rgba(15, 25, 45, 0.95)); 
  backdrop-filter: blur(20px); 
  border: 1px solid rgba(0, 240, 255, 0.4); 
  color: var(--primary); 
  font-size: 24px; 
  cursor: pointer; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.6), 0 0 15px rgba(0, 240, 255, 0.3); 
  transition: var(--transition);
}
.action-btn:active { transform: scale(0.9) rotate(-5deg); }
.action-btn:hover { 
  box-shadow: 0 0 30px rgba(0, 240, 255, 0.6), 0 4px 20px rgba(0, 0, 0, 0.6);
  border-color: rgba(0, 240, 255, 0.8);
  color: var(--primary-light);
}
.stats-btn { top: 10px; right: 68px; }
.uk-btn { top: 10px; right: 10px; }

/* FAB - Oil Drop */
.fab { position: fixed; bottom: 20px; right: 14px; z-index: 1001; width: 64px; height: 64px; border: none; background: transparent; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: var(--transition); }
.fab:active { transform: scale(0.9); }
.fab-drop { position: relative; width: 56px; height: 68px; }
.fab-drop svg { width: 100%; height: 100%; filter: drop-shadow(0 0 20px rgba(0, 240, 255, 0.8)) drop-shadow(0 4px 16px rgba(0, 240, 255, 0.6)); animation: fabFloat 3s ease-in-out infinite; }
@keyframes fabFloat { 0%, 100% { transform: translateY(0); filter: drop-shadow(0 0 20px rgba(0, 240, 255, 0.8)); } 50% { transform: translateY(-6px); filter: drop-shadow(0 0 30px rgba(0, 240, 255, 1)); } }
.fab-icon { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 28px; font-weight: 900; color: #00f0ff; z-index: 1; text-shadow: 0 0 15px rgba(0, 240, 255, 0.8), 0 2px 8px rgba(0, 0, 0, 0.6); }
.fab-ripples { position: absolute; inset: -10px; }
.fab-ripple { position: absolute; inset: 0; border-radius: 50%; border: 2px solid var(--primary); opacity: 0; animation: fabRipple 2.5s ease-out infinite; }
.fab-ripple:nth-child(2) { animation-delay: 1.25s; }
@keyframes fabRipple { 0% { transform: scale(0.8); opacity: 0.6; box-shadow: 0 0 0 0 rgba(0, 240, 255, 0.7); } 100% { transform: scale(1.6); opacity: 0; box-shadow: 0 0 0 20px rgba(0, 240, 255, 0); } }

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
.btn-location { background: linear-gradient(135deg, #00ff88, #00f0ff); color: #000; font-weight: 700; }
.btn-location:hover { background: linear-gradient(135deg, #00f0ff, #00ff88); box-shadow: 0 4px 12px rgba(0, 255, 136, 0.4); }
.btn-location:active { transform: scale(0.97); }
.btn-location:disabled { opacity: 0.6; cursor: not-allowed; }
@keyframes pulse-marker { 0%, 100% { transform: scale(1); box-shadow: 0 0 20px rgba(0,240,255,0.8); } 50% { transform: scale(1.1); box-shadow: 0 0 30px rgba(0,240,255,1); } }

/* ═══ ACCESSIBILITY IMPROVEMENTS (UI/UX Pro Max Skill) ═══ */
button:focus-visible, a:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
  box-shadow: 0 0 0 4px rgba(0, 240, 255, 0.2);
}
button:focus-visible { border-color: var(--primary); }
.action-btn, .fab, .filter-chip, .btn, .close-btn {
  min-width: 44px;
  min-height: 44px;
  cursor: pointer;
}
.filter-chip, .btn, .action-btn, .fab, .close-btn, .popup-btn, .gps-btn {
  cursor: pointer;
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
body, .modal-body { line-height: 1.6; }
p, .popup-desc, .form-group label {
  line-height: 1.6;
  max-width: 75ch;
}

/* Toast */
.toast { 
  position: fixed; top: 80px; left: 50%; transform: translateX(-50%); z-index: 4000; 
  background: linear-gradient(135deg, var(--success), var(--primary-dark)); 
  color: #000; 
  padding: 14px 24px; 
  border-radius: var(--radius-sm); 
  font-size: 14px; 
  font-weight: 700; 
  box-shadow: 0 0 30px rgba(0, 255, 136, 0.6), 0 4px 20px rgba(0, 0, 0, 0.6); 
  border: 1px solid rgba(0, 255, 136, 0.5);
  opacity: 0; 
  pointer-events: none; 
  transition: opacity 0.3s, transform 0.3s; 
  display: flex; 
  align-items: center; 
  gap: 10px;
  text-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
}
.toast.show { opacity: 1; transform: translateX(-50%) translateY(0); pointer-events: auto; animation: toastIn 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
@keyframes toastIn { from { transform: translateX(-50%) translateY(-20px); opacity: 0; } to { transform: translateX(-50%) translateY(0); opacity: 1; } }
.toast.error { background: linear-gradient(135deg, var(--danger), #cc0000); box-shadow: 0 0 30px rgba(255, 51, 102, 0.6), 0 4px 20px rgba(0, 0, 0, 0.6); border-color: rgba(255, 51, 102, 0.5); }
.toast.warning { background: linear-gradient(135deg, var(--warning), #cc8800); color: #000; box-shadow: 0 0 30px rgba(255, 170, 0, 0.6), 0 4px 20px rgba(0, 0, 0, 0.6); border-color: rgba(255, 170, 0, 0.5); }
.toast-icon { font-size: 20px; filter: drop-shadow(0 0 5px rgba(0, 0, 0, 0.8)); }

/* Leaflet Popup */
.leaflet-popup-content-wrapper { 
  background: linear-gradient(135deg, rgba(10, 15, 30, 0.98), rgba(15, 25, 45, 0.98)) !important; 
  color: var(--text) !important; 
  border: 1px solid rgba(0, 240, 255, 0.4) !important; 
  border-radius: var(--radius) !important; 
  backdrop-filter: blur(20px) !important; 
  box-shadow: 0 8px 40px rgba(0, 0, 0, 0.8), 0 0 30px rgba(0, 240, 255, 0.3) !important;
  position: relative;
}
.leaflet-popup-content-wrapper::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: var(--radius);
  padding: 1px;
  background: linear-gradient(135deg, rgba(0, 240, 255, 0.5), rgba(0, 255, 136, 0.3));
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
.leaflet-popup-tip { background: rgba(10, 15, 30, 0.98) !important; border: 1px solid rgba(0, 240, 255, 0.4) !important; }
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

// ═══ AURORA BACKGROUND — Северное сияние ═══
function initAurora() {
  const canvas = document.getElementById('auroraCanvas');
  if (!canvas) return;
  
  const ctx = canvas.getContext('2d');
  let W, H;
  let time = 0;
  
  function resize() {
    W = canvas.width = window.innerWidth;
    H = canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);
  
  function drawAurora() {
    ctx.clearRect(0, 0, W, H);
    time += 0.005;
    
    const layers = [
      { color: 'rgba(0, 240, 255, 0.15)', offset: 0, speed: 0.3, height: H * 0.4 },
      { color: 'rgba(0, 255, 136, 0.12)', offset: Math.PI / 3, speed: 0.4, height: H * 0.35 },
      { color: 'rgba(99, 102, 241, 0.1)', offset: Math.PI / 1.5, speed: 0.25, height: H * 0.3 }
    ];
    
    layers.forEach((layer) => {
      ctx.beginPath();
      ctx.moveTo(0, H);
      for (let x = 0; x <= W; x += 2) {
        const wave = Math.sin((x / W) * Math.PI * 4 + time * layer.speed + layer.offset) * 30;
        const wave2 = Math.sin((x / W) * Math.PI * 8 + time * layer.speed * 2) * 15;
        const y = H - layer.height + wave + wave2 + Math.sin(time + x * 0.01) * 10;
        ctx.lineTo(x, y);
      }
      ctx.lineTo(W, H);
      ctx.closePath();
      const gradient = ctx.createLinearGradient(0, H - layer.height, 0, H);
      gradient.addColorStop(0, layer.color);
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fill();
    });
    
    for (let i = 0; i < 20; i++) {
      const x = (Math.sin(time * 0.5 + i) * 0.5 + 0.5) * W;
      const y = (Math.cos(time * 0.3 + i * 0.7) * 0.5 + 0.5) * H;
      const size = Math.sin(time * 2 + i) * 3 + 4;
      const alpha = Math.sin(time * 3 + i) * 0.3 + 0.4;
      ctx.beginPath();
      const grad = ctx.createRadialGradient(x, y, 0, x, y, size * 2);
      grad.addColorStop(0, `rgba(0, 240, 255, ${alpha})`);
      grad.addColorStop(1, 'transparent');
      ctx.fillStyle = grad;
      ctx.arc(x, y, size * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    requestAnimationFrame(drawAurora);
  }
  drawAurora();
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
  initAurora();
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

// ═══ DATA LOADING WITH FALLBACK ═══

// Проверка доступности источника данных
async function checkDataSource(source) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), source.timeout);
    
    const response = await fetch(source.url, {
      signal: controller.signal,
      method: 'HEAD' // Быстрая проверка доступности
    });
    
    clearTimeout(timeoutId);
    return response.ok;
  } catch (error) {
    return false;
  }
}

// Загрузка данных из источника
async function fetchFromSource(source) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), source.timeout);
    
    const response = await fetch(source.url, {
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache'
      }
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    return { success: true, data, source: source.name };
  } catch (error) {
    console.warn(`[${source.name}] Ошибка загрузки:`, error.message);
    return { success: false, error: error.message, source: source.name };
  }
}

// Сохранение в кэш
function saveToCache(complaints) {
  if (!state.cacheEnabled || !window.localStorage) return;
  
  try {
    const cacheData = {
      complaints,
      timestamp: Date.now(),
      version: '1.0'
    };
    localStorage.setItem(state.cacheKey, JSON.stringify(cacheData));
    localStorage.setItem(state.cacheTimestampKey, Date.now().toString());
    console.log('[Cache] Данные сохранены в кэш');
  } catch (error) {
    console.warn('[Cache] Ошибка сохранения в кэш:', error);
  }
}

// Загрузка из кэша
function loadFromCache() {
  if (!state.cacheEnabled || !window.localStorage) return null;
  
  try {
    const cacheDataStr = localStorage.getItem(state.cacheKey);
    const cacheTimestamp = localStorage.getItem(state.cacheTimestampKey);
    
    if (!cacheDataStr || !cacheTimestamp) return null;
    
    const cacheAge = Date.now() - parseInt(cacheTimestamp, 10);
    if (cacheAge > state.cacheMaxAge) {
      console.log('[Cache] Кэш устарел, очищаем');
      localStorage.removeItem(state.cacheKey);
      localStorage.removeItem(state.cacheTimestampKey);
      return null;
    }
    
    const cacheData = JSON.parse(cacheDataStr);
    if (cacheData.complaints && Array.isArray(cacheData.complaints)) {
      console.log(`[Cache] Загружено ${cacheData.complaints.length} жалоб из кэша (возраст: ${Math.round(cacheAge / 1000)}с)`);
      return cacheData.complaints;
    }
  } catch (error) {
    console.warn('[Cache] Ошибка загрузки из кэша:', error);
  }
  
  return null;
}

// Тестовые данные для полного fallback
function getTestData() {
  return [
    {
      id: 'test-1',
      lat: 60.9388,
      lng: 76.5778,
      title: 'Яма на дороге',
      category: 'Дороги',
      address: 'ул. Ленина 15',
      status: 'pending',
      description: 'Большая яма, опасно для автомобилей',
      created_at: new Date().toISOString()
    },
    {
      id: 'test-2',
      lat: 60.9300,
      lng: 76.5500,
      title: 'Сломанный фонарь',
      category: 'Освещение',
      address: 'пр. Победы 20',
      status: 'open',
      description: 'Фонарь не работает уже неделю',
      created_at: new Date(Date.now() - 86400000).toISOString()
    },
    {
      id: 'test-3',
      lat: 60.9400,
      lng: 76.5600,
      title: 'Протечка в подъезде',
      category: 'ЖКХ',
      address: 'ул. Мира 5',
      status: 'in_progress',
      description: 'Течет с потолка в подъезде',
      created_at: new Date(Date.now() - 172800000).toISOString()
    }
  ];
}

// Обработка данных из разных источников
function processComplaintsData(data, sourceName) {
  let complaints = [];
  
  // Firebase формат (объект с ключами)
  if (data && typeof data === 'object' && !Array.isArray(data)) {
    complaints = Object.entries(data).map(([id, complaint]) => ({
      id,
      ...complaint
    }));
  }
  // Массив
  else if (Array.isArray(data)) {
    complaints = data.map((complaint, index) => ({
      id: complaint.id || `item-${index}`,
      ...complaint
    }));
  }
  
  return complaints;
}

// Обновление статуса подключения в UI
function updateConnectionStatus(status, source = null) {
  state.connectionStatus = status;
  state.activeDataSource = source;
  
  const statusEl = document.getElementById('connection-status');
  if (statusEl) {
    const statusMap = {
      'online': { text: 'Онлайн', color: '#10b981', icon: '✓' },
      'offline': { text: 'Офлайн', color: '#ef4444', icon: '✗' },
      'checking': { text: 'Проверка...', color: '#f59e0b', icon: '⟳' },
      'cached': { text: 'Кэш', color: '#6366f1', icon: '💾' }
    };
    
    const statusInfo = statusMap[status] || statusMap['checking'];
    statusEl.textContent = `${statusInfo.icon} ${statusInfo.text}${source ? ` (${source})` : ''}`;
    statusEl.style.color = statusInfo.color;
  }
  
  console.log(`[Status] ${status}${source ? ` via ${source}` : ''}`);
}

// Основная функция загрузки данных с fallback
async function loadData() {
  updateConnectionStatus('checking');
  
  // Попытка загрузки из всех источников по приоритету
  let loadedComplaints = null;
  let loadedSource = null;
  
  for (const source of CONFIG.dataSources.sort((a, b) => a.priority - b.priority)) {
    console.log(`[Load] Пробуем источник: ${source.name} (${source.url})`);
    
    const result = await fetchFromSource(source);
    
    if (result.success && result.data) {
      loadedComplaints = processComplaintsData(result.data, result.source);
      
      if (loadedComplaints && loadedComplaints.length > 0) {
        loadedSource = result.source;
        console.log(`[Load] ✓ Успешно загружено ${loadedComplaints.length} жалоб из ${result.source}`);
        break;
      }
    }
  }
  
  // Fallback 1: Загрузка из кэша
  if (!loadedComplaints || loadedComplaints.length === 0) {
    console.log('[Load] Источники недоступны, пробуем кэш...');
    const cachedComplaints = loadFromCache();
    
    if (cachedComplaints && cachedComplaints.length > 0) {
      loadedComplaints = cachedComplaints;
      loadedSource = 'cache';
      updateConnectionStatus('cached', 'cache');
      showToast('Загружено из кэша', 'warning');
    }
  }
  
  // Fallback 2: Тестовые данные
  if (!loadedComplaints || loadedComplaints.length === 0) {
    console.log('[Load] Кэш пуст, используем тестовые данные');
    loadedComplaints = getTestData();
    loadedSource = 'test';
    updateConnectionStatus('offline', 'test');
    showToast('Используются тестовые данные', 'warning');
  }
  
  // Обработка загруженных данных
  if (loadedComplaints && loadedComplaints.length > 0) {
    // Track known IDs for real-time updates
    loadedComplaints.forEach(c => state.knownComplaintIds.add(c.id));
    
    state.complaints = loadedComplaints;
    state.filteredComplaints = [...state.complaints];
    state.lastUpdateTime = Date.now();
    
    // Сохраняем в кэш если данные из онлайн источника
    if (loadedSource !== 'cache' && loadedSource !== 'test') {
      saveToCache(loadedComplaints);
      updateConnectionStatus('online', loadedSource);
    }
    
    // Update splash stats
    const total = state.complaints.length;
    const open = state.complaints.filter(c => c.status === 'open').length;
    const resolved = state.complaints.filter(c => c.status === 'resolved').length;
    
    const statTotalEl = document.getElementById('statTotal');
    const statOpenEl = document.getElementById('statOpen');
    const statResolvedEl = document.getElementById('statResolved');
    
    if (statTotalEl) statTotalEl.textContent = total;
    if (statOpenEl) statOpenEl.textContent = open;
    if (statResolvedEl) statResolvedEl.textContent = resolved;
    
    // Feed to City Rhythm
    CityRhythm.feed(state.complaints);
    
    // Обновляем маркеры на карте
    if (state.map && state.cluster) {
      renderMarkers();
    }
  } else {
    console.error('[Load] Не удалось загрузить данные ни из одного источника');
    showToast('Не удалось загрузить данные', 'error');
    updateConnectionStatus('offline');
  }
}

// ═══ REALTIME UPDATES ═══
async function checkForNewComplaints() {
  if (!state.map || !state.cluster) return;
  
  try {
    const response = await fetch(CONFIG.firebase + '/complaints.json', {
      signal: AbortSignal.timeout(5000)
    });
    
    if (!response.ok) return;
    
    const data = await response.json();
    if (!data) return;
    
    const currentComplaints = Object.entries(data).map(([id, complaint]) => ({
      id,
      ...complaint
    }));
    
    // Find new complaints with addresses
    const newComplaints = currentComplaints.filter(c => {
      const isNew = !state.knownComplaintIds.has(c.id);
      const hasAddress = c.lat && c.lng && c.address;
      return isNew && hasAddress;
    });
    
    if (newComplaints.length > 0) {
      // Add new complaints
      newComplaints.forEach(c => {
        state.knownComplaintIds.add(c.id);
        state.complaints.push(c);
      });
      
      state.filteredComplaints = [...state.complaints];
      
      // Animate new markers
      newComplaints.forEach(complaint => {
        addMarkerWithAnimation(complaint);
      });
      
      // Update stats
      const total = state.complaints.length;
      const open = state.complaints.filter(c => c.status === 'open').length;
      const resolved = state.complaints.filter(c => c.status === 'resolved').length;
      
      document.getElementById('totalNum').textContent = total;
      document.getElementById('openNum').textContent = open;
      document.getElementById('resolvedNum').textContent = resolved;
      
      // Show notification
      showToast(`Новая жалоба: ${newComplaints[0].category}`, 'success');
      
      // Feed to City Rhythm
      CityRhythm.feed(state.complaints);
    }
    
    // Update existing complaints status changes
    currentComplaints.forEach(newComplaint => {
      const existing = state.complaints.find(c => c.id === newComplaint.id);
      if (existing && existing.status !== newComplaint.status) {
        existing.status = newComplaint.status;
        // Re-render affected marker
        renderMarkers();
      }
    });
    
  } catch (error) {
    console.error('Realtime check error:', error);
  }
}

function addMarkerWithAnimation(complaint) {
  if (!complaint.lat || !complaint.lng) return;
  
  const category = CONFIG.categories[complaint.category] || CONFIG.categories['Прочее'];
  
  // Create animated marker icon
  const icon = L.divIcon({
    html: `<div class="marker-new" style="width:40px;height:40px;border-radius:50%;background:${category.color};display:flex;align-items:center;justify-content:center;font-size:18px;border:3px solid rgba(255,255,255,0.5);box-shadow:0 0 20px ${category.color}, 0 0 40px ${category.color}88;animation: markerPulse 1s ease-out;">${category.emoji}</div>`,
    className: 'marker-container-new',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
    popupAnchor: [0, -20]
  });
  
  const marker = L.marker([complaint.lat, complaint.lng], { icon });
  
  const popupContent = `
    <div class="popup-header">
      <span class="popup-icon">${category.emoji}</span>
      <span class="popup-title">${complaint.category}</span>
      <span class="popup-new-badge">НОВОЕ</span>
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
  
  // Remove animation class after animation completes
  setTimeout(() => {
    const iconEl = marker._icon;
    if (iconEl) {
      const markerDiv = iconEl.querySelector('.marker-new');
      if (markerDiv) {
        markerDiv.style.animation = 'none';
        markerDiv.style.width = '32px';
        markerDiv.style.height = '32px';
        markerDiv.style.fontSize = '16px';
        markerDiv.style.borderWidth = '2px';
      }
    }
  }, 1000);
}

function startRealtimeUpdates() {
  // Check every 3 seconds for new complaints
  state.realtimeInterval = setInterval(() => {
    checkForNewComplaints();
  }, 3000);
  
  console.log('✅ Real-time updates started (3s interval)');
}

// ═══ MAP INITIALIZATION ═══
function initMap() {
  // Проверяем параметр marker из URL
  const urlParams = new URLSearchParams(window.location.search);
  const markerParam = urlParams.get('marker');
  let initialCenter = CONFIG.center;
  let initialZoom = CONFIG.zoom;
  
  if (markerParam) {
    const [lat, lon] = markerParam.split(',').map(parseFloat);
    if (!isNaN(lat) && !isNaN(lon)) {
      initialCenter = [lat, lon];
      initialZoom = 17; // Увеличенный зум для маркера
    }
  }
  
  // Initialize Leaflet map
  state.map = L.map('map', {
    center: initialCenter,
    zoom: initialZoom,
    zoomControl: false
  });
  
  // OpenStreetMap tiles (free, no API key) + markers
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19,
    className: 'hi-tech-tiles'
  }).addTo(state.map);
  
  // Add CSS filter for hi-tech look
  const style = document.createElement('style');
  style.textContent = `
    .hi-tech-tiles { 
      filter: brightness(0.6) contrast(1.2) saturate(0.8) invert(0.05) hue-rotate(180deg);
      opacity: 0.9;
    }
    .leaflet-container { background: #0a0a0f !important; }
  `;
  document.head.appendChild(style);
  
  // Initialize marker cluster
  state.cluster = L.markerClusterGroup({
    maxClusterRadius: 50,
    spiderfyOnMaxZoom: true,
    showCoverageOnHover: false,
    zoomToBoundsOnClick: true
  });
  
  // Render markers
  renderMarkers();
  
  // Если есть параметр marker, открываем соответствующий маркер
  if (markerParam) {
    const [lat, lon] = markerParam.split(',').map(parseFloat);
    if (!isNaN(lat) && !isNaN(lon)) {
      setTimeout(() => {
        // Ищем маркер с такими координатами
        state.cluster.eachLayer((layer) => {
          const markerLat = layer.getLatLng().lat;
          const markerLon = layer.getLatLng().lng;
          if (Math.abs(markerLat - lat) < 0.0001 && Math.abs(markerLon - lon) < 0.0001) {
            layer.openPopup();
            state.map.setView([lat, lon], 17);
          }
        });
      }, 1000);
    }
  }
  
  // Initialize filters
  initFilters();
  
  // Initialize timeline
  initTimeline();
  
  // Setup event listeners
  setupEventListeners();
  
  // Start real-time updates
  startRealtimeUpdates();
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
      html: `<div style="width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg, ${category.color}, ${category.color}88);display:flex;align-items:center;justify-content:center;font-size:18px;border:2px solid rgba(255,255,255,0.5);box-shadow:0 0 15px ${category.color}99, 0 4px 12px rgba(0,0,0,0.6);position:relative;">
        ${category.emoji}
        <div style="position:absolute;inset:-2px;border-radius:50%;border:1px solid ${category.color};opacity:0.5;animation:pulse-ring 2s ease-out infinite;"></div>
      </div>`,
      className: 'hi-tech-marker',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -20]
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
  
  // Date range filter
  const dateFilter = document.getElementById('dateFilter');
  if (!dateFilter) {
    // Создаем контейнер для фильтра дат если его нет
    const filterPanel = document.getElementById('filterPanel');
    if (filterPanel) {
      const dateFilterContainer = document.createElement('div');
      dateFilterContainer.id = 'dateFilter';
      dateFilterContainer.className = 'filter-row';
      dateFilterContainer.innerHTML = '<div class="filter-label">Период:</div>';
      filterPanel.appendChild(dateFilterContainer);
    }
  }
  
  const dateFilterEl = document.getElementById('dateFilter');
  if (dateFilterEl) {
    const allChip = document.createElement('div');
    allChip.className = 'filter-chip active';
    allChip.innerHTML = '<span data-icon="mdi:calendar"></span> Все время';
    allChip.onclick = () => {
      state.filters.dateRange = null;
      applyFilters();
    };
    dateFilterEl.appendChild(allChip);
    
    const dateRanges = [
      { key: 'today', label: 'Сегодня', icon: 'mdi:calendar-today' },
      { key: 'week', label: 'Неделя', icon: 'mdi:calendar-week' },
      { key: 'month', label: 'Месяц', icon: 'mdi:calendar-month' },
      { key: '3months', label: '3 месяца', icon: 'mdi:calendar-range' }
    ];
    
    dateRanges.forEach(({ key, label, icon }) => {
      const chip = document.createElement('div');
      chip.className = `filter-chip date-${key}`;
      chip.innerHTML = `<span data-icon="${icon}"></span> ${label}`;
      chip.onclick = () => {
        state.filters.dateRange = key;
        applyFilters();
      };
      dateFilterEl.appendChild(chip);
    });
  }
}

function applyFilters() {
  const now = Date.now();
  state.filteredComplaints = state.complaints.filter(c => {
    if (state.filters.category && c.category !== state.filters.category) return false;
    if (state.filters.status && c.status !== state.filters.status) return false;
    
    // Фильтрация по датам
    if (state.filters.dateRange) {
      const complaintDate = new Date(c.created_at || c.date || 0).getTime();
      const rangeMs = {
        'today': 86400000,      // 24 часа
        'week': 604800000,      // 7 дней
        'month': 2592000000,    // 30 дней
        '3months': 7776000000   // 90 дней
      }[state.filters.dateRange];
      
      if (rangeMs && (now - complaintDate) > rangeMs) return false;
    }
    
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
  const dateFilter = document.getElementById('dateFilter');
  
  if (catFilter) {
    const chips = catFilter.querySelectorAll('.filter-chip');
    if (state.filters.category) {
      chips.forEach(chip => {
        if (chip.textContent.includes(state.filters.category)) {
          chip.classList.add('active');
        }
      });
    } else {
      chips[0]?.classList.add('active');
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
      chips[0]?.classList.add('active');
    }
  }
  
  if (dateFilter) {
    const chips = dateFilter.querySelectorAll('.filter-chip');
    if (state.filters.dateRange) {
      chips.forEach(chip => {
        if (chip.className.includes(`date-${state.filters.dateRange}`)) {
          chip.classList.add('active');
        }
      });
    } else {
      chips[0]?.classList.add('active');
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
// ═══ STATS RENDERING ═══
function renderStats() {
  const el = document.getElementById('statsContent');
  if (!el) return;
  const c = state.complaints;
  const total = c.length;
  const open = c.filter(x => x.status === 'open').length;
  const resolved = c.filter(x => x.status === 'resolved').length;
  const pending = c.filter(x => x.status === 'pending').length;
  const inProgress = c.filter(x => x.status === 'in_progress').length;

  // Category breakdown
  const cats = {};
  c.forEach(x => { const cat = x.category || 'Прочее'; cats[cat] = (cats[cat] || 0) + 1; });
  const sortedCats = Object.entries(cats).sort((a, b) => b[1] - a[1]);

  // Last 7 days activity
  const now = Date.now();
  const days = {};
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now - i * 86400000);
    days[d.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' })] = 0;
  }
  c.forEach(x => {
    const d = new Date(x.created_at || x.date || 0);
    const key = d.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
    if (key in days) days[key]++;
  });
  const maxDay = Math.max(...Object.values(days), 1);

  let html = `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:18px">
      <div style="background:rgba(99,102,241,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#818cf8">${total}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Всего</div>
      </div>
      <div style="background:rgba(239,68,68,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#ef4444">${open}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Открыто</div>
      </div>
      <div style="background:rgba(249,115,22,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#f97316">${inProgress + pending}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">В работе</div>
      </div>
      <div style="background:rgba(16,185,129,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#10b981">${resolved}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Решено</div>
      </div>
    </div>
    <div style="font-size:13px;font-weight:700;margin-bottom:10px;color:rgba(255,255,255,0.8)">📊 По категориям</div>
  `;

  sortedCats.forEach(([cat, count]) => {
    const pct = Math.round(count / total * 100);
    const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
    html += `
      <div style="margin-bottom:8px">
        <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:3px">
          <span>${cfg.emoji} ${cat}</span><span style="color:rgba(255,255,255,0.5)">${count} (${pct}%)</span>
        </div>
        <div style="height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:${pct}%;background:${cfg.color};border-radius:3px;transition:width 0.5s"></div>
        </div>
      </div>`;
  });

  html += `<div style="font-size:13px;font-weight:700;margin:18px 0 10px;color:rgba(255,255,255,0.8)">📈 Активность (7 дней)</div>`;
  Object.entries(days).forEach(([day, count]) => {
    const pct = Math.round(count / maxDay * 100);
    html += `
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
        <span style="font-size:11px;min-width:40px;color:rgba(255,255,255,0.5)">${day}</span>
        <div style="flex:1;height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:${pct}%;background:#6366f1;border-radius:3px"></div>
        </div>
        <span style="font-size:11px;min-width:20px;text-align:right;color:rgba(255,255,255,0.5)">${count}</span>
      </div>`;
  });

  el.innerHTML = html;
}

// ═══ UK RATING RENDERING ═══
const UK_CACHE_KEY = 'uk_rating_cache';
const UK_CACHE_TTL = 86400000; // 24 hours

function getUkRatingCache() {
  try {
    const raw = localStorage.getItem(UK_CACHE_KEY);
    if (!raw) return null;
    const cache = JSON.parse(raw);
    if (Date.now() - cache.ts > UK_CACHE_TTL) return null;
    return cache.data;
  } catch { return null; }
}

function setUkRatingCache(data) {
  try {
    localStorage.setItem(UK_CACHE_KEY, JSON.stringify({ ts: Date.now(), data }));
  } catch {}
}

function computeUkRating() {
  const cached = getUkRatingCache();
  if (cached) return cached;

  const uks = {};
  state.complaints.forEach(c => {
    // Extract UK from address or use a default grouping
    let uk = c.uk || c.management_company || '';
    if (!uk && c.address) {
      // Try to extract district/area from address for grouping
      const addr = c.address.toLowerCase();
      if (addr.includes('мира') || addr.includes('ленин')) uk = 'УК Центр';
      else if (addr.includes('нефтяник') || addr.includes('индустриальн')) uk = 'УК Нефтяник';
      else if (addr.includes('дружб') || addr.includes('интернационал')) uk = 'УК Дружба';
      else if (addr.includes('комсомольск') || addr.includes('пионер')) uk = 'УК Комсомольский';
      else if (addr.includes('чапаев') || addr.includes('куйбышев')) uk = 'УК Западный';
      else uk = 'Прочие';
    }
    if (!uk) uk = 'Не определено';

    if (!uks[uk]) uks[uk] = { total: 0, resolved: 0, open: 0, categories: {} };
    uks[uk].total++;
    if (c.status === 'resolved') uks[uk].resolved++;
    if (c.status === 'open') uks[uk].open++;
    const cat = c.category || 'Прочее';
    uks[uk].categories[cat] = (uks[uk].categories[cat] || 0) + 1;
  });

  // Calculate rating: higher resolved % = better, more open = worse
  const result = Object.entries(uks).map(([name, data]) => {
    const resolvedPct = data.total > 0 ? data.resolved / data.total : 0;
    const rating = Math.max(1, Math.min(5, Math.round(resolvedPct * 5 + (data.total < 3 ? 1 : 0))));
    return { name, ...data, resolvedPct, rating };
  }).sort((a, b) => b.rating - a.rating || a.open - b.open);

  setUkRatingCache(result);
  return result;
}

function renderUkRating() {
  const el = document.getElementById('ukContent');
  if (!el) return;

  const ratings = computeUkRating();
  if (!ratings.length) {
    el.innerHTML = '<div style="text-align:center;padding:40px;color:rgba(255,255,255,0.4)">Нет данных для рейтинга</div>';
    return;
  }

  let html = `<div style="font-size:11px;color:rgba(255,255,255,0.4);margin-bottom:14px">Обновляется раз в сутки • На основе ${state.complaints.length} обращений</div>`;

  ratings.forEach((uk, i) => {
    const stars = '★'.repeat(uk.rating) + '☆'.repeat(5 - uk.rating);
    const starColor = uk.rating >= 4 ? '#10b981' : uk.rating >= 3 ? '#f59e0b' : '#ef4444';
    const topCats = Object.entries(uk.categories).sort((a, b) => b[1] - a[1]).slice(0, 3);

    html += `
      <div style="background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="font-size:16px;font-weight:900;color:rgba(255,255,255,0.3);min-width:24px">#${i + 1}</span>
            <span style="font-size:14px;font-weight:700">${uk.name}</span>
          </div>
          <span style="font-size:14px;color:${starColor};letter-spacing:2px">${stars}</span>
        </div>
        <div style="display:flex;gap:12px;margin-bottom:8px">
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Всего: <b style="color:#818cf8">${uk.total}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Решено: <b style="color:#10b981">${uk.resolved}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Открыто: <b style="color:#ef4444">${uk.open}</b></span>
        </div>
        <div style="height:4px;background:rgba(255,255,255,0.08);border-radius:2px;overflow:hidden;margin-bottom:8px">
          <div style="height:100%;width:${Math.round(uk.resolvedPct * 100)}%;background:linear-gradient(90deg,#10b981,#6366f1);border-radius:2px"></div>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          ${topCats.map(([cat, cnt]) => {
            const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
            return `<span style="font-size:10px;padding:3px 8px;border-radius:10px;background:${cfg.color}22;color:${cfg.color}">${cfg.emoji} ${cat}: ${cnt}</span>`;
          }).join('')}
        </div>
      </div>`;
  });

  el.innerHTML = html;
}

function setupEventListeners() {
  // Stats button
  const statsBtn = document.getElementById('statsBtn');
  if (statsBtn) {
    statsBtn.onclick = () => {
      const overlay = document.getElementById('statsOverlay');
      if (overlay) {
        overlay.classList.toggle('open');
        if (overlay.classList.contains('open')) renderStats();
      }
    };
  }
  
  // UK button
  const ukBtn = document.getElementById('ukBtn');
  if (ukBtn) {
    ukBtn.onclick = () => {
      const overlay = document.getElementById('ukOverlay');
      if (overlay) {
        overlay.classList.toggle('open');
        if (overlay.classList.contains('open')) renderUkRating();
      }
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

// ═══ LOCATION SHARING & MARKING ═══
function shareLocationAndMark() {
  const shareBtn = document.getElementById('shareLocationBtn');
  if (!shareBtn) return;
  
  if (navigator.geolocation) {
    shareBtn.innerHTML = '<span data-icon="mdi:loading"></span> Определение...';
    shareBtn.disabled = true;
    
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude.toFixed(6);
        const lng = position.coords.longitude.toFixed(6);
        
        // Fill form fields
        document.getElementById('formLat').value = lat;
        document.getElementById('formLng').value = lng;
        
        // Mark on map immediately
        if (state.map) {
          // Remove existing marker if any
          if (window.locationMarker) {
            state.map.removeLayer(window.locationMarker);
          }
          
          // Add marker at current location
          const marker = L.marker([lat, lng], {
            icon: L.divIcon({
              html: '<div style="width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg, #00f0ff, #00ff88);display:flex;align-items:center;justify-content:center;font-size:20px;border:3px solid rgba(255,255,255,0.8);box-shadow:0 0 20px rgba(0,240,255,0.8), 0 4px 12px rgba(0,0,0,0.6);animation:pulse-marker 2s ease-in-out infinite;"><span data-icon="mdi:map-marker"></span></div>',
              className: 'location-share-marker',
              iconSize: [40, 40],
              iconAnchor: [20, 20]
            }),
            draggable: true
          }).addTo(state.map);
          
          // Center map on marker
          state.map.setView([lat, lng], 17);
          
          // Store marker reference
          window.locationMarker = marker;
          
          // Update marker position when dragged
          marker.on('dragend', function() {
            const pos = marker.getLatLng();
            document.getElementById('formLat').value = pos.lat.toFixed(6);
            document.getElementById('formLng').value = pos.lng.toFixed(6);
          });
        }
        
        // Reverse geocoding for address
        shareBtn.innerHTML = '<span data-icon="mdi:loading"></span> Адрес...';
        try {
          const geoUrl = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&addressdetails=1&accept-language=ru`;
          const response = await fetch(geoUrl, {
            headers: { 'User-Agent': 'SoobshioApp/1.0' }
          });
          
          if (response.ok) {
            const data = await response.json();
            if (data && data.address) {
              const addr = data.address;
              let addressParts = [];
              if (addr.road) addressParts.push(addr.road);
              if (addr.house_number) addressParts.push(addr.house_number);
              if (addressParts.length === 0 && addr.suburb) addressParts.push(addr.suburb);
              const fullAddress = addressParts.length > 0 
                ? addressParts.join(', ') + (addr.city === 'Нижневартовск' ? '' : ', Нижневартовск')
                : data.display_name || '';
              if (fullAddress) {
                document.getElementById('formAddress').value = fullAddress;
              }
            }
          }
        } catch (error) {
          console.log('Reverse geocoding failed:', error);
        }
        
        shareBtn.innerHTML = '<span data-icon="mdi:check"></span> Отмечено';
        shareBtn.disabled = false;
        showToast('Местоположение отмечено на карте', 'success');
        
        // Haptic feedback
        if (tg && tg.HapticFeedback) {
          tg.HapticFeedback.impactOccurred('medium');
        }
      },
      (error) => {
        showToast('Не удалось определить местоположение', 'error');
        shareBtn.innerHTML = '<span data-icon="mdi:map-marker-radius"></span> Поделиться геолокацией';
        shareBtn.disabled = false;
      }
    );
  } else {
    showToast('Геолокация не поддерживается', 'error');
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
    // Haptic feedback for error
    if (tg && tg.HapticFeedback) {
      tg.HapticFeedback.notificationOccurred('error');
    }
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
    // Haptic feedback on success
    if (tg && tg.HapticFeedback) {
      tg.HapticFeedback.notificationOccurred('success');
      tg.HapticFeedback.impactOccurred('heavy');
    }
    
    showToast('Жалоба отправлена!', 'success');
    closeModal();
    
    // Remove location marker
    if (window.locationMarker) {
      state.map.removeLayer(window.locationMarker);
      window.locationMarker = null;
    }
    
    // Reload data
    loadData().then(() => renderMarkers());
  })
  .catch(error => {
    console.error('Error submitting complaint:', error);
    showToast('Ошибка отправки жалобы', 'error');
    // Haptic feedback for error
    if (tg && tg.HapticFeedback) {
      tg.HapticFeedback.notificationOccurred('error');
    }
  });
}
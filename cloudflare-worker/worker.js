// Cloudflare Worker — прокси для AI API (Anthropic + OpenAI)
// Роутинг: /anthropic/* → api.anthropic.com, /openai/* → api.openai.com
// Без префикса → api.anthropic.com (обратная совместимость)

export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "*",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    const url = new URL(request.url);
    let path = url.pathname;

    // --- Email endpoint ---
    if (path === "/send-email" && request.method === "POST") {
      return handleSendEmail(request);
    }

    // --- Join complaint (присоединиться к жалобе) ---
    if (path === "/api/join" && request.method === "POST") {
      return handleJoinComplaint(request);
    }

    // --- Map Web App (для Telegram) ---
    if (path === "/map" || path === "/map/") {
      return new Response(MAP_HTML, {
        headers: { "Content-Type": "text/html;charset=utf-8", "Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache, no-store, must-revalidate" },
      });
    }

    // --- Infographic Web App ---
    if (path === "/info" || path === "/info/") {
      return new Response(INFO_HTML, {
        headers: { "Content-Type": "text/html;charset=utf-8", "Access-Control-Allow-Origin": "*" },
      });
    }

    let targetHost;

    if (path.startsWith("/openai/")) {
      targetHost = "https://api.openai.com";
      path = path.replace("/openai", "");
    } else if (path.startsWith("/anthropic/")) {
      targetHost = "https://api.anthropic.com";
      path = path.replace("/anthropic", "");
    } else if (path.startsWith("/firebase/")) {
      targetHost = "https://soobshio-default-rtdb.europe-west1.firebasedatabase.app";
      path = path.replace("/firebase", "");
    } else {
      targetHost = "https://api.anthropic.com";
    }

    const targetUrl = targetHost + path + url.search;

    const headers = new Headers(request.headers);
    headers.set("Host", new URL(targetHost).host);

    const response = await fetch(targetUrl, {
      method: request.method,
      headers: headers,
      body: request.method !== "GET" ? request.body : undefined,
    });

    const newHeaders = new Headers(response.headers);
    newHeaders.set("Access-Control-Allow-Origin", "*");

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders,
    });
  },
};


// --- Отправка email через Resend API (бесплатно 100/день) ---
async function handleSendEmail(request) {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  };

  try {
    const data = await request.json();
    const { to_email, to_name, subject, body, from_name } = data;

    if (!to_email || !subject || !body) {
      return new Response(
        JSON.stringify({ ok: false, error: "Missing to_email, subject, or body" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const brevoKey = typeof BREVO_API_KEY !== "undefined" ? BREVO_API_KEY : null;
    if (brevoKey) {
      const mailResp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "Content-Type": "application/json", "api-key": brevoKey },
        body: JSON.stringify({
          sender: { name: from_name || "Пульс города", email: "pulsgoroda@noreply.ru" },
          to: [{ email: to_email, name: to_name || "" }],
          subject: subject, textContent: body,
        }),
      });
      if (mailResp.ok) {
        return new Response(JSON.stringify({ ok: true, method: "brevo" }), { status: 200, headers: corsHeaders });
      }
    }

    const resendKey = typeof RESEND_API_KEY !== "undefined" ? RESEND_API_KEY : null;
    if (resendKey) {
      const mailResp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${resendKey}` },
        body: JSON.stringify({
          from: `${from_name || "Пульс города"} <onboarding@resend.dev>`,
          to: [to_email], subject: subject, text: body,
        }),
      });
      if (mailResp.ok) {
        return new Response(JSON.stringify({ ok: true, method: "resend" }), { status: 200, headers: corsHeaders });
      }
    }

    return new Response(
      JSON.stringify({
        ok: false, fallback: true,
        error: "No email provider configured.",
        mailto: `mailto:${to_email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body.substring(0, 500))}`,
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: e.message }), { status: 500, headers: corsHeaders });
  }
}

// --- Присоединиться к жалобе ---
async function handleJoinComplaint(request) {
  const corsHeaders = {"Access-Control-Allow-Origin": "*", "Content-Type": "application/json"};
  try {
    const data = await request.json();
    const id = data.id;
    if (!id) return new Response(JSON.stringify({ok:false,error:"no id"}), {status:400, headers:corsHeaders});
    const fbBase = "https://soobshio-default-rtdb.europe-west1.firebasedatabase.app";
    // Get current complaint
    const r = await fetch(fbBase + "/complaints/" + id + ".json");
    if (!r.ok) return new Response(JSON.stringify({ok:false,error:"not found"}), {status:404, headers:corsHeaders});
    const complaint = await r.json();
    if (!complaint) return new Response(JSON.stringify({ok:false,error:"not found"}), {status:404, headers:corsHeaders});
    const oldS = complaint.supporters || 0;
    const newS = oldS + 1;
    // Update supporters count
    await fetch(fbBase + "/complaints/" + id + "/supporters.json", {
      method: "PUT", body: JSON.stringify(newS),
      headers: {"Content-Type": "application/json"}
    });
    // If reached 10 and not yet notified, send email
    let emailSent = false;
    if (newS >= 10 && !complaint.supporters_notified && complaint.uk_email) {
      const subject = "Коллективная жалоба: " + (complaint.category || "Проблема") + " — " + (complaint.address || "Нижневартовск");
      const body = "Уважаемая " + (complaint.uk_name || "Управляющая компания") + "!\n\n" +
        "На платформе «Пульс города — Нижневартовск» зарегистрирована жалоба, к которой присоединились " + newS + " жителей.\n\n" +
        "Категория: " + (complaint.category || "—") + "\n" +
        "Адрес: " + (complaint.address || "—") + "\n" +
        "Описание: " + (complaint.summary || complaint.description || complaint.title || "—").substring(0, 500) + "\n" +
        "Дата: " + (complaint.created_at || "—") + "\n" +
        "Количество присоединившихся: " + newS + "\n\n" +
        "Просим принять меры и сообщить о результатах.\n\n" +
        "С уважением,\nПлатформа «Пульс города — Нижневартовск»\nhttps://t.me/pulsenvbot";
      try {
        const emailResp = await handleSendEmail(new Request("https://dummy/send-email", {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify({to_email: complaint.uk_email, subject: subject, body: body, from_name: "Пульс города"})
        }));
        const emailData = await emailResp.json();
        emailSent = emailData.ok || false;
      } catch(e) { emailSent = false; }
      // Mark as notified
      await fetch(fbBase + "/complaints/" + id + "/supporters_notified.json", {
        method: "PUT", body: JSON.stringify(1),
        headers: {"Content-Type": "application/json"}
      });
    }
    return new Response(JSON.stringify({ok:true, supporters:newS, emailSent:emailSent}), {status:200, headers:corsHeaders});
  } catch(e) {
    return new Response(JSON.stringify({ok:false, error:e.message}), {status:500, headers:corsHeaders});
  }
}

// ===== Встроенная карта (Telegram Web App) =====
const MAP_HTML = `<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Пульс города — Карта</title>
<script src="https://telegram.org/js/telegram-web-app.js"><\/script>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css"/>
<!-- Anime.js для продвинутых анимаций -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/animejs/3.2.2/anime.min.js"><\/script>
<!-- Particles.js для фона -->
<script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"><\/script>
<!-- Iconify для иконок -->
<script src="https://code.iconify.design/3/3.1.0/iconify.min.js"><\/script>
</head>
<body>
<!-- Particles Background -->
<div id="particles-js"></div>

<!-- Splash Screen -->
<div id="splash">
  <div class="splash-content">
    <!-- Oil Drop Logo -->
    <div class="oil-drop-container">
      <svg class="oil-drop" viewBox="0 0 200 240">
        <defs>
          <linearGradient id="oilGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:#1a1a2e;stop-opacity:1" />
            <stop offset="50%" style="stop-color:#16213e;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#0f3460;stop-opacity:1" />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="4" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>
        <path class="drop-main" d="M100 20 C100 20, 40 80, 40 140 C40 180, 65 220, 100 220 C135 220, 160 180, 160 140 C160 80, 100 20, 100 20 Z" 
              fill="url(#oilGradient)" filter="url(#glow)"/>
        <ellipse class="drop-shine" cx="80" cy="80" rx="20" ry="30" fill="rgba(255,255,255,0.15)"/>
        <circle class="drop-bubble" cx="100" cy="120" r="8" fill="rgba(255,255,255,0.1)"/>
      </svg>
      <div class="pulse-rings">
        <div class="pulse-ring"></div>
        <div class="pulse-ring"></div>
        <div class="pulse-ring"></div>
      </div>
    </div>
    
    <h1 class="splash-title">
      <span class="title-icon" data-icon="mdi:oil"></span>
      Пульс города
    </h1>
    <div class="splash-subtitle">НИЖНЕВАРТОВСК</div>
    
    <!-- City Rhythm Visualizer -->
    <div class="rhythm-container">
      <canvas id="rhythmCanvas" width="320" height="80"></canvas>
      <div class="rhythm-info">
        <div class="rhythm-bpm" id="rhythmBpm">72</div>
        <div class="rhythm-label">ударов/мин</div>
        <div class="rhythm-mood" id="rhythmMood">Спокойно</div>
      </div>
    </div>
    
    <div class="splash-stats">
      <div class="stat-card">
        <span class="stat-icon" data-icon="mdi:alert-circle"></span>
        <span class="stat-num" id="statTotal">—</span>
        <span class="stat-label">проблем</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon" data-icon="mdi:alert"></span>
        <span class="stat-num" id="statOpen">—</span>
        <span class="stat-label">открыто</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon" data-icon="mdi:check-circle"></span>
        <span class="stat-num" id="statResolved">—</span>
        <span class="stat-label">решено</span>
      </div>
    </div>
    
    <div class="splash-progress">
      <div class="progress-bar">
        <div class="progress-fill" id="progressFill"></div>
        <div class="progress-glow"></div>
      </div>
      <div class="progress-text" id="progressText">Загрузка данных...</div>
    </div>
  </div>
</div>

<!-- Main App -->
<div id="app" style="display:none">
  <div id="map"></div>
  
  <!-- Top Bar -->
  <div id="topBar">
    <div class="tb-left">
      <div class="oil-pulse-mini">
        <svg viewBox="0 0 24 24" width="20" height="20">
          <path d="M12 2C12 2 6 10 6 15C6 18.31 8.69 21 12 21C15.31 21 18 18.31 18 15C18 10 12 2 12 2Z" 
                fill="currentColor" opacity="0.8"/>
        </svg>
      </div>
      <span class="tb-title">Пульс города</span>
    </div>
    <div class="tb-right">
      <div class="stat-mini">
        <span class="num" id="totalNum">0</span>
        <span class="lbl">всего</span>
      </div>
      <div class="stat-mini red">
        <span class="num" id="openNum">0</span>
        <span class="lbl">открыто</span>
      </div>
      <div class="stat-mini green">
        <span class="num" id="resolvedNum">0</span>
        <span class="lbl">решено</span>
      </div>
    </div>
  </div>

  <!-- Filter Panel -->
  <div id="filterPanel">
    <div class="filter-row" id="categoryFilter"></div>
    <div class="filter-row" id="statusFilter"></div>
    <div class="filter-row" id="dateFilter"></div>
  </div>

  <!-- Action Buttons -->
  <button class="action-btn stats-btn" id="statsBtn" title="Статистика">
    <span data-icon="mdi:chart-box"></span>
  </button>
  <button class="action-btn uk-btn" id="ukBtn" title="Рейтинг УК">
    <span data-icon="mdi:office-building"></span>
  </button>
  
  <!-- FAB - Oil Drop -->
  <button class="fab" id="fabBtn" title="Подать жалобу">
    <div class="fab-drop">
      <svg viewBox="0 0 56 68">
        <defs>
          <linearGradient id="fabOilGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:#6366f1"/>
            <stop offset="100%" style="stop-color:#4f46e5"/>
          </linearGradient>
        </defs>
        <path d="M28 4C28 4 12 20 12 32C12 42 18.5 50 28 50C37.5 50 44 42 44 32C44 20 28 4 28 4Z" 
              fill="url(#fabOilGrad)"/>
      </svg>
      <span class="fab-icon">+</span>
    </div>
    <div class="fab-ripples">
      <div class="fab-ripple"></div>
      <div class="fab-ripple"></div>
    </div>
  </button>

  <!-- Timeline -->
  <div class="timeline-panel">
    <canvas id="timelineCanvas"></canvas>
  </div>

  <!-- Stats Overlay -->
  <div class="overlay" id="statsOverlay">
    <div class="overlay-header">
      <h3><span data-icon="mdi:chart-box"></span> Статистика</h3>
      <button class="close-btn" onclick="closeOverlay('statsOverlay')">
        <span data-icon="mdi:close"></span>
      </button>
    </div>
    <div class="overlay-content" id="statsContent"></div>
  </div>

  <!-- UK Rating Overlay -->
  <div class="overlay left" id="ukOverlay">
    <div class="overlay-header">
      <h3><span data-icon="mdi:office-building"></span> Рейтинг УК</h3>
      <button class="close-btn" onclick="closeOverlay('ukOverlay')">
        <span data-icon="mdi:close"></span>
      </button>
    </div>
    <div class="overlay-content" id="ukContent"></div>
  </div>

  <!-- Complaint Form -->
  <div class="modal" id="complaintModal">
    <div class="modal-backdrop" onclick="closeModal()"></div>
    <div class="modal-content">
      <div class="modal-header">
        <h3><span data-icon="mdi:file-document-edit"></span> Подать жалобу</h3>
        <button class="close-btn" onclick="closeModal()">
          <span data-icon="mdi:close"></span>
        </button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label><span data-icon="mdi:tag"></span> Категория</label>
          <select id="formCategory"></select>
        </div>
        <div class="form-group">
          <label><span data-icon="mdi:text"></span> Описание проблемы</label>
          <textarea id="formDescription" rows="4" placeholder="Опишите проблему подробно..."></textarea>
        </div>
        <div class="form-group">
          <label>
            <span data-icon="mdi:map-marker"></span> Адрес
            <span class="gps-btn" id="gpsBtn">
              <span data-icon="mdi:crosshairs-gps"></span> Определить
            </span>
          </label>
          <input type="text" id="formAddress" placeholder="ул. Ленина, 15"/>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label><span data-icon="mdi:latitude"></span> Широта</label>
            <input type="number" id="formLat" step="0.0001" placeholder="60.9344"/>
          </div>
          <div class="form-group">
            <label><span data-icon="mdi:longitude"></span> Долгота</label>
            <input type="number" id="formLng" step="0.0001" placeholder="76.5531"/>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick="closeModal()">
          <span data-icon="mdi:close"></span> Отмена
        </button>
        <button class="btn btn-primary" onclick="submitComplaint()">
          <span data-icon="mdi:send"></span> Отправить
        </button>
      </div>
    </div>
  </div>

  <!-- Toast -->
  <div class="toast" id="toast">
    <span class="toast-icon" id="toastIcon"></span>
    <span class="toast-text" id="toastText"></span>
  </div>
</div>
<script>
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
const styles = \`
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
\`;

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
      html: \`<div style="width:32px;height:32px;border-radius:50%;background:\${category.color};display:flex;align-items:center;justify-content:center;font-size:16px;border:2px solid rgba(255,255,255,0.3);box-shadow:0 2px 8px \${category.color}66">\${category.emoji}</div>\`,
      className: '',
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -18]
    });
    
    const marker = L.marker([complaint.lat, complaint.lng], { icon });
    
    const popupContent = \`
      <div class="popup-header">
        <span class="popup-icon">\${category.emoji}</span>
        <span class="popup-title">\${complaint.category}</span>
      </div>
      <div class="popup-badge" style="background:\${CONFIG.statuses[complaint.status]?.color || '#64748b'}">\${CONFIG.statuses[complaint.status]?.label || complaint.status}</div>
      <div class="popup-desc">\${(complaint.summary || complaint.text || '').substring(0, 150)}</div>
      \${complaint.address ? \`<div class="popup-meta"><span data-icon="mdi:map-marker"></span> \${complaint.address}</div>\` : ''}
      <div class="popup-meta"><span data-icon="mdi:calendar"></span> \${new Date(complaint.created_at).toLocaleDateString('ru-RU')}</div>
      <div class="popup-actions">
        <a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=\${complaint.lat},\${complaint.lng}" target="_blank" class="popup-btn">
          <span data-icon="mdi:google-street-view"></span> Street View
        </a>
        <a href="https://yandex.ru/maps/?pt=\${complaint.lng},\${complaint.lat}&z=17&l=map" target="_blank" class="popup-btn">
          <span data-icon="mdi:map"></span> Яндекс
        </a>
      </div>
    \`;
    
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
      chip.innerHTML = \`<span data-icon="\${cat.icon}"></span> \${name}\`;
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
      chip.className = \`filter-chip status-\${key}\`;
      chip.innerHTML = \`<span data-icon="\${status.icon}"></span> \${status.label}\`;
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

<\/script>
</body>
</html>
`;

// ===== Инфографика — открытые данные Нижневартовска =====
const INFO_HTML = `<!DOCTYPE html><html lang="ru"><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Нижневартовск · Пульс города</title>
<script src="https://telegram.org/js/telegram-web-app.js"><\/script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"><\/script>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
</head>
<body>
<canvas id="bgCanvas"></canvas>
<div id="pulse-bar"><canvas id="pulseCanvas"></canvas><div id="pulse-info"><span id="pulse-bpm">72</span><span class="pulse-label">BPM</span><span id="pulse-mood">Спокойно</span></div></div>
<div id="app"></div>
<div id="loader"><div class="ld-ring"><div></div><div></div><div></div></div><span>Загрузка…</span></div>
<script>
// ═══════════════════════════════════════════════════════
// Пульс города Нижневартовск — HTML5/CSS/JS + Animated BG + City Pulse
// ═══════════════════════════════════════════════════════

const tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}
const isDark=!tg||tg.colorScheme==='dark';

// ═══ ANIMATED BACKGROUND ═══
(function initBG(){
  const c=document.getElementById('bgCanvas');if(!c)return;
  const ctx=c.getContext('2d');
  let W,H,particles=[];
  function resize(){W=c.width=window.innerWidth;H=c.height=window.innerHeight}
  resize();window.addEventListener('resize',resize);
  const colors=isDark?['rgba(99,102,241,.15)','rgba(16,185,129,.12)','rgba(245,158,11,.1)','rgba(236,72,153,.08)']:
    ['rgba(15,118,110,.1)','rgba(37,99,235,.08)','rgba(234,88,12,.06)','rgba(124,58,237,.06)'];
  for(let i=0;i<40;i++)particles.push({x:Math.random()*W,y:Math.random()*H,r:Math.random()*60+20,
    vx:(Math.random()-.5)*.3,vy:(Math.random()-.5)*.3,c:colors[i%colors.length],phase:Math.random()*Math.PI*2});
  function draw(){
    ctx.clearRect(0,0,W,H);
    const t=Date.now()*.001;
    particles.forEach(p=>{
      p.x+=p.vx;p.y+=p.vy;
      if(p.x<-80)p.x=W+80;if(p.x>W+80)p.x=-80;
      if(p.y<-80)p.y=H+80;if(p.y>H+80)p.y=-80;
      const s=1+Math.sin(t+p.phase)*.3;
      ctx.beginPath();
      const g=ctx.createRadialGradient(p.x,p.y,0,p.x,p.y,p.r*s);
      g.addColorStop(0,p.c);g.addColorStop(1,'transparent');
      ctx.fillStyle=g;ctx.arc(p.x,p.y,p.r*s,0,Math.PI*2);ctx.fill();
    });
    requestAnimationFrame(draw);
  }
  draw();
})();

// ═══ CITY PULSE — heartbeat that reacts to complaints ═══
const CityPulse={
  bpm:60,targetBpm:60,mood:'Спокойно',canvas:null,ctx:null,history:[],
  severity:0,count:0,lastUpdate:0,
  init(){
    this.canvas=document.getElementById('pulseCanvas');
    if(!this.canvas)return;
    this.ctx=this.canvas.getContext('2d');
    this.canvas.width=this.canvas.parentElement.offsetWidth;
    this.canvas.height=48;
    this.history=new Array(200).fill(0);
    this.animate();
  },
  feed(complaints){
    if(!complaints||!complaints.length)return;
    const now=Date.now();
    const recent=complaints.filter(c=>{
      const d=new Date(c.created_at||c.date||0);
      return now-d.getTime()<3600000*24;
    });
    this.count=recent.length;
    let sev=0;
    recent.forEach(c=>{
      const cat=c.category||'';
      if(['ЧП','Безопасность','Газоснабжение'].includes(cat))sev+=3;
      else if(['Дороги','ЖКХ','Отопление','Водоснабжение и канализация'].includes(cat))sev+=2;
      else sev+=1;
    });
    this.severity=Math.min(sev,100);
    // BPM: 60 base + severity + count factor
    this.targetBpm=Math.min(60+this.severity*1.5+this.count*2,180);
    if(this.targetBpm<65)this.mood='Спокойно';
    else if(this.targetBpm<90)this.mood='Умеренно';
    else if(this.targetBpm<120)this.mood='Напряжённо';
    else this.mood='Тревожно';
    const el=document.getElementById('pulse-bpm');
    const ml=document.getElementById('pulse-mood');
    if(el)el.textContent=Math.round(this.targetBpm);
    if(ml){ml.textContent=this.mood;
      ml.style.color=this.targetBpm<65?'#10b981':this.targetBpm<90?'#f59e0b':this.targetBpm<120?'#f97316':'#ef4444'}
  },
  animate(){
    if(!this.ctx)return;
    const ctx=this.ctx,W=this.canvas.width,H=this.canvas.height;
    this.bpm+=(this.targetBpm-this.bpm)*.02;
    const freq=this.bpm/60;
    const t=Date.now()*.001*freq;
    // Generate ECG-like waveform
    const phase=t%1;
    let v=0;
    if(phase<.05)v=Math.sin(phase/.05*Math.PI)*.3;
    else if(phase<.15)v=0;
    else if(phase<.2)v=-Math.sin((phase-.15)/.05*Math.PI)*.15;
    else if(phase<.25)v=Math.sin((phase-.2)/.05*Math.PI)*1;
    else if(phase<.3)v=-Math.sin((phase-.25)/.05*Math.PI)*.4;
    else if(phase<.4)v=Math.sin((phase-.3)/.1*Math.PI)*.15;
    else v=0;
    this.history.push(v);if(this.history.length>200)this.history.shift();
    ctx.clearRect(0,0,W,H);
    const color=this.bpm<65?'#10b981':this.bpm<90?'#f59e0b':this.bpm<120?'#f97316':'#ef4444';
    ctx.strokeStyle=color;ctx.lineWidth=2;ctx.shadowColor=color;ctx.shadowBlur=6;
    ctx.beginPath();
    const step=W/200;
    for(let i=0;i<this.history.length;i++){
      const x=i*step,y=H/2-this.history[i]*(H/2-4);
      i===0?ctx.moveTo(x,y):ctx.lineTo(x,y);
    }
    ctx.stroke();ctx.shadowBlur=0;
    requestAnimationFrame(()=>this.animate());
  }
};


// ═══ CSS ═══
const S=document.createElement('style');
S.textContent=\`
*{margin:0;padding:0;box-sizing:border-box}
:root{
--bg:#0c1222;--surface:rgba(12,18,34,.95);--surfaceS:rgba(12,18,34,.98);
--primary:#14b8a6;--primaryL:#2dd4bf;--primaryBg:rgba(20,184,166,.1);
--accent:#e8804c;--accentBg:rgba(232,128,76,.08);
--text:#e2e8f0;--textSec:#94a3b8;--textMuted:#64748b;
--border:rgba(255,255,255,.04);
--shadow:6px 6px 16px rgba(0,0,0,.5),-4px -4px 12px rgba(255,255,255,.02);
--shadowInset:inset 3px 3px 8px rgba(0,0,0,.4),inset -2px -2px 6px rgba(255,255,255,.02);
--green:#10b981;--greenBg:rgba(16,185,129,.12);--red:#ef4444;--redBg:rgba(239,68,68,.12);
--orange:#f97316;--orangeBg:rgba(249,115,22,.1);--blue:#3b82f6;--blueBg:rgba(59,130,246,.1);
--purple:#a855f7;--purpleBg:rgba(168,85,247,.1);--teal:#14b8a6;--tealBg:rgba(20,184,166,.1);
--pink:#ec4899;--pinkBg:rgba(236,72,153,.1);--indigo:#6366f1;--indigoBg:rgba(99,102,241,.1);
--yellow:#f59e0b;--yellowBg:rgba(245,158,11,.1);
--r:16px;--rs:10px;
}
body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);
overflow-x:hidden;min-height:100vh;-webkit-font-smoothing:antialiased}
#bgCanvas{position:fixed;inset:0;z-index:0;pointer-events:none}
#app{position:relative;z-index:1;max-width:480px;margin:0 auto;padding:0 10px 40px}

/* Pulse bar */
#pulse-bar{position:sticky;top:0;z-index:100;display:flex;align-items:center;gap:8px;
padding:6px 12px;background:rgba(12,18,34,.92);backdrop-filter:blur(16px);
border-bottom:1px solid var(--border);margin:0 -10px}
#pulseCanvas{flex:1;height:48px;border-radius:8px}
#pulse-info{display:flex;flex-direction:column;align-items:center;min-width:60px}
#pulse-bpm{font-size:28px;font-weight:900;color:var(--green);line-height:1;
font-variant-numeric:tabular-nums;transition:color .5s}
.pulse-label{font-size:7px;color:var(--textMuted);text-transform:uppercase;letter-spacing:1px}
#pulse-mood{font-size:9px;font-weight:700;color:var(--green);transition:color .5s}

/* Animations */
@keyframes fadeUp{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
@keyframes scaleIn{from{opacity:0;transform:scale(.92)}to{opacity:1;transform:scale(1)}}
@keyframes slideR{from{opacity:0;transform:translateX(-20px)}to{opacity:1;transform:translateX(0)}}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-4px)}}
@keyframes shimmer{0%{background-position:-200% 0}100%{background-position:200% 0}}
@keyframes barGrow{from{width:0}to{width:var(--w)}}
@keyframes countUp{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
@keyframes rideIn{from{opacity:0;transform:translateX(-100%)}to{opacity:1;transform:translateX(0)}}
@keyframes breathe{0%,100%{transform:scale(1)}50%{transform:scale(1.02)}}
@keyframes glow{0%,100%{box-shadow:0 0 8px rgba(20,184,166,.2)}50%{box-shadow:0 0 20px rgba(20,184,166,.4)}}

/* Hero */
.hero{text-align:center;padding:20px 16px 8px;animation:fadeUp .6s ease both}
.hero-pill{display:inline-flex;align-items:center;gap:6px;background:var(--primaryBg);
color:var(--primary);font-size:10px;font-weight:700;padding:5px 14px;border-radius:20px;
letter-spacing:.5px;text-transform:uppercase;margin-bottom:10px}
.hero-pill .dot{width:6px;height:6px;border-radius:50%;background:var(--green);animation:pulse 2s infinite}
.hero h1{font-size:24px;font-weight:900;line-height:1.2}
.hero h1 em{font-style:normal;color:var(--primary)}
.hero .sub{font-size:12px;color:var(--textSec);margin-top:4px}
.hero .upd{font-size:10px;color:var(--textMuted);margin-top:8px}
.hero .ds-count{display:inline-flex;align-items:center;gap:4px;background:var(--tealBg);
color:var(--teal);font-size:9px;font-weight:700;padding:3px 10px;border-radius:12px;margin-top:6px}

/* Tabs */
.tabs{display:flex;gap:6px;padding:8px 0;overflow-x:auto;scrollbar-width:none}
.tabs::-webkit-scrollbar{display:none}
.tab{flex-shrink:0;padding:7px 14px;border-radius:12px;font-size:11px;font-weight:600;
background:var(--surface);border:none;color:var(--textSec);cursor:pointer;
box-shadow:4px 4px 10px rgba(0,0,0,.4),-3px -3px 8px rgba(255,255,255,.02);
transition:all .25s;white-space:nowrap}
.tab.active{background:var(--primary);color:#fff;
box-shadow:inset 3px 3px 8px rgba(0,0,0,.3),inset -2px -2px 6px rgba(255,255,255,.05);transform:scale(1.04)}
.tab:active{box-shadow:var(--shadowInset);transform:scale(.95)}

/* Grid & Cards */
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding-top:6px}
.card{background:var(--surface);border:1px solid var(--border);
border-radius:var(--r);padding:14px;position:relative;overflow:hidden;
box-shadow:var(--shadow);
opacity:0;transform:translateY(24px);transition:all .5s cubic-bezier(.4,0,.2,1);cursor:pointer}
.card.visible{opacity:1;transform:translateY(0)}
.card:hover{box-shadow:8px 8px 20px rgba(0,0,0,.6),-6px -6px 16px rgba(255,255,255,.03)}
.card:active{transform:scale(.97)!important;box-shadow:var(--shadowInset)}
.card.full{grid-column:1/-1}
.card[data-section="budget"]{border-left:3px solid var(--orange)}
.card[data-section="fuel"]{border-left:3px solid var(--red)}
.card[data-section="housing"]{border-left:3px solid var(--teal)}
.card[data-section="edu"]{border-left:3px solid var(--blue)}
.card[data-section="transport"]{border-left:3px solid var(--indigo)}
.card[data-section="sport"]{border-left:3px solid var(--green)}
.card[data-section="city"]{border-left:3px solid var(--purple)}
.card[data-section="eco"]{border-left:3px solid var(--teal)}
.card[data-section="people"]{border-left:3px solid var(--pink)}
.card .ride{animation:rideIn .6s ease both}

.card-head{display:flex;align-items:center;gap:8px;margin-bottom:10px}
.card-icon{width:38px;height:38px;border-radius:12px;display:flex;align-items:center;
justify-content:center;font-size:18px;flex-shrink:0;transition:transform .3s;
box-shadow:3px 3px 8px rgba(0,0,0,.3),-2px -2px 6px rgba(255,255,255,.02)}
.card:hover .card-icon{transform:scale(1.1) rotate(-3deg)}
.card-title{font-size:13px;font-weight:700;line-height:1.2}
.card-sub{font-size:10px;color:var(--textMuted);font-weight:500;margin-top:1px}

.tip{display:flex;align-items:flex-start;gap:6px;margin-top:10px;padding:8px 10px;
border-radius:var(--rs);font-size:10px;line-height:1.4;color:var(--textSec)}
.tip-icon{font-size:13px;flex-shrink:0;animation:float 3s ease infinite}
.tip.green{background:var(--greenBg)}.tip.orange{background:var(--orangeBg)}
.tip.blue{background:var(--blueBg)}.tip.purple{background:var(--purpleBg)}
.tip.teal{background:var(--tealBg)}.tip.red{background:var(--redBg)}
.tip.pink{background:var(--pinkBg)}.tip.indigo{background:var(--indigoBg)}

.big{font-size:34px;font-weight:900;line-height:1}
.big small{font-size:10px;font-weight:500;color:var(--textMuted);display:block;margin-top:3px}

.stat-row{display:flex;justify-content:space-around;text-align:center;padding:4px 0}
.stat-item .num{font-size:22px;font-weight:800;animation:countUp .5s ease both}
.stat-item .lbl{font-size:8px;color:var(--textMuted);text-transform:uppercase;letter-spacing:.3px;margin-top:2px;font-weight:600}

.bar-row{display:flex;align-items:center;gap:6px;margin:3px 0}
.bar-label{font-size:9px;color:var(--textSec);width:65px;text-align:right;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:500}
.bar-track{flex:1;height:18px;background:rgba(255,255,255,.05);border-radius:9px;overflow:hidden}
.bar-fill{height:100%;border-radius:9px;display:flex;align-items:center;justify-content:flex-end;
padding-right:5px;font-size:8px;font-weight:700;color:#fff;animation:barGrow 1s cubic-bezier(.4,0,.2,1) both}

.section-title{font-size:11px;font-weight:700;color:var(--textMuted);text-transform:uppercase;
letter-spacing:.8px;padding:16px 4px 6px;grid-column:1/-1;animation:slideR .5s ease both}

.expand-content{max-height:0;overflow:hidden;transition:max-height .5s cubic-bezier(.4,0,.2,1)}
.card.expanded .expand-content{max-height:3000px}
.card.expanded::after{opacity:0}
.expand-btn{display:flex;align-items:center;justify-content:center;gap:4px;margin-top:8px;
padding:6px;border-radius:10px;background:var(--primaryBg);color:var(--primary);
font-size:10px;font-weight:600;cursor:pointer;transition:all .25s;border:none}
.expand-btn:active{transform:scale(.95)}

.fuel-row{display:flex;align-items:center;padding:5px 0;border-bottom:1px solid var(--border)}
.fuel-row:last-child{border:none}
.fuel-name{font-size:10px;color:var(--textSec);width:50px;flex-shrink:0;font-weight:600}
.fuel-bar{flex:1;height:22px;background:rgba(255,255,255,.05);border-radius:11px;overflow:hidden;margin:0 6px}
.fuel-fill{height:100%;border-radius:11px;display:flex;align-items:center;justify-content:center;
font-size:8px;font-weight:700;color:#fff;animation:barGrow 1s cubic-bezier(.4,0,.2,1) both}
.fuel-avg{font-size:14px;font-weight:800;width:48px;text-align:right}

.trend-bar{display:flex;align-items:flex-end;gap:2px;height:40px;margin-top:6px}
.trend-col{flex:1;display:flex;flex-direction:column;align-items:center;gap:1px}

.footer{text-align:center;padding:24px 16px;font-size:10px;color:var(--textMuted)}
.footer a{color:var(--primary);text-decoration:none;font-weight:600}

#loader{position:fixed;inset:0;z-index:99;background:var(--bg);display:flex;flex-direction:column;
align-items:center;justify-content:center;transition:opacity .5s}
#loader.hide{opacity:0;pointer-events:none}
.ld-ring{width:40px;height:40px;position:relative}
.ld-ring div{width:32px;height:32px;border-radius:50%;border:3px solid transparent;
border-top-color:var(--primary);position:absolute;animation:spin .8s linear infinite}
.ld-ring div:nth-child(2){width:24px;height:24px;top:4px;left:4px;border-top-color:var(--accent);animation-duration:1.2s}
.ld-ring div:nth-child(3){width:16px;height:16px;top:8px;left:8px;border-top-color:var(--primaryL);animation-duration:.6s}
@keyframes spin{to{transform:rotate(360deg)}}

/* Weather */
.weather-bar{display:flex;align-items:center;gap:10px;padding:10px 16px;margin:8px 0;
border-radius:var(--r);background:var(--surface);border:1px solid var(--border);
box-shadow:var(--shadow);animation:fadeUp .5s ease both}
.weather-icon{font-size:32px;animation:breathe 3s ease infinite}
.weather-temp{font-size:22px;font-weight:800}
.weather-desc{font-size:11px;color:var(--textSec);text-transform:capitalize}
.weather-extra{font-size:9px;color:var(--textMuted);margin-top:2px}

/* UK Email card */
.uk-email-item{padding:5px 0;border-bottom:1px solid var(--border);font-size:11px}
.uk-email-item:last-child{border:none}
.uk-email-btn{font-size:9px;color:var(--primary);cursor:pointer;text-decoration:underline;font-weight:600;background:none;border:none}
\`;
document.head.appendChild(S);


// ═══ HELPERS ═══
function esc(s){return s?s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'):'';}
function fmtDate(iso){if(!iso)return'—';try{const d=new Date(iso);return d.toLocaleDateString('ru-RU',{day:'2-digit',month:'short',year:'numeric'})+' '+d.toLocaleTimeString('ru-RU',{hour:'2-digit',minute:'2-digit'})}catch(e){return iso}}
function fmtMoney(v){if(!v||v===0)return'—';if(v>=1e9)return(v/1e9).toFixed(1)+' млрд ₽';if(v>=1e6)return(v/1e6).toFixed(1)+' млн ₽';if(v>=1e3)return(v/1e3).toFixed(0)+' тыс ₽';return v.toFixed(0)+' ₽'}
function haptic(){try{tg?.HapticFeedback?.impactOccurred('light')}catch(e){}}

function animateNum(el,target,dur){
  if(!el)return;let start=0;const t0=performance.now();
  function step(t){const p=Math.min((t-t0)/dur,1);el.textContent=Math.round(start+(target-start)*p).toLocaleString('ru');
    if(p<1)requestAnimationFrame(step)}
  requestAnimationFrame(step);
}

function makeTip(color,icon,text){
  return '<div class="tip '+color+'"><span class="tip-icon">'+icon+'</span><span>'+text+'</span></div>';
}

function makeStatRow(items){
  let h='<div class="stat-row">';
  items.forEach(it=>{h+='<div class="stat-item"><div class="num" style="color:'+it.color+'">'+
    (it.value||0).toLocaleString('ru')+'</div><div class="lbl">'+it.label+'</div></div>'});
  return h+'</div>';
}

function makeTrendBar(data,color,label,valueKey){
  if(!data||!data.length)return'';
  valueKey=valueKey||'count';
  const max=Math.max(...data.map(d=>d[valueKey]||0),1);
  let h='';if(label)h+='<div style="font-size:9px;color:var(--textMuted);margin-bottom:4px;font-weight:600;text-transform:uppercase;letter-spacing:.3px">'+label+'</div>';
  h+='<div class="trend-bar">';
  data.forEach((d,i)=>{const v=d[valueKey]||0;const pct=Math.max(v/max*100,4);
    h+='<div class="trend-col"><div style="font-size:7px;color:var(--textMuted);font-weight:600">'+v+'</div>'+
    '<div style="width:100%;height:'+pct+'%;min-height:2px;background:'+(color||'var(--primary)')+';border-radius:3px;opacity:'+(0.7+i/data.length*.3)+'"></div></div>'});
  h+='</div><div style="display:flex;justify-content:space-between;margin-top:2px">';
  data.forEach(d=>{h+='<div style="flex:1;text-align:center;font-size:7px;color:var(--textMuted)">'+String(d.year).slice(-2)+'</div>'});
  return h+'</div>';
}

function makeBarRows(items,maxVal,colors){
  let h='';
  items.forEach((t,i)=>{const pct=Math.round((t.count||0)/(maxVal||1)*100);
    h+='<div class="bar-row"><span class="bar-label">'+esc(t.name)+'</span><div class="bar-track">'+
    '<div class="bar-fill" style="--w:'+pct+'%;width:'+pct+'%;background:'+(colors[i%colors.length])+'">'+t.count+'</div></div></div>'});
  return h;
}

// ═══ CARD BUILDER ═══
function card(section,full,content,expandContent,expandLabel){
  const cls='card'+(full?' full':'')+' '+(expandContent?'expandable':'');
  let h='<div class="'+cls+'" data-section="'+section+'">';
  h+='<div class="ride">'+content+'</div>';
  if(expandContent){
    h+='<div class="expand-content">'+expandContent+'</div>';
    h+='<button class="expand-btn" onclick="this.parentElement.classList.toggle(\\'expanded\\');haptic()">'+
      (expandLabel||'Подробнее')+'</button>';
  }
  h+='</div>';return h;
}

function cardHead(icon,iconBg,title,sub){
  return '<div class="card-head"><div class="card-icon" style="background:'+iconBg+'">'+icon+'</div>'+
    '<div><div class="card-title">'+title+'</div>'+(sub?'<div class="card-sub">'+sub+'</div>':'')+'</div></div>';
}

function bigNum(value,label,color){
  return '<div class="big" style="color:'+(color||'var(--primary)')+'">'+
    (value||0).toLocaleString('ru')+'<small>'+label+'</small></div>';
}


// ═══ WEATHER ═══
async function loadWeather(){
  try{
    const r=await fetch('https://api.open-meteo.com/v1/forecast?latitude=60.9344&longitude=76.5531&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,is_day',{signal:AbortSignal.timeout(5000)});
    const d=await r.json();return d.current||null;
  }catch(e){return null}
}

function weatherInfo(code,isDay){
  const map={0:['Ясно',isDay?'☀️':'🌙'],1:['Малооблачно',isDay?'🌤️':'🌙'],2:['Облачно','⛅'],3:['Пасмурно','☁️'],
    45:['Туман','🌫️'],48:['Изморозь','🌫️'],51:['Морось','🌦️'],53:['Морось','🌦️'],55:['Морось','🌧️'],
    61:['Дождь','🌧️'],63:['Дождь','🌧️'],65:['Ливень','⛈️'],71:['Снег','🌨️'],73:['Снег','❄️'],75:['Снегопад','❄️'],
    77:['Крупа','🌨️'],80:['Ливень','🌧️'],81:['Ливень','⛈️'],82:['Шторм','⛈️'],85:['Снег','❄️'],86:['Метель','❄️'],
    95:['Гроза','⛈️'],96:['Гроза','⛈️'],99:['Гроза','⛈️']};
  return map[code]||['Облачно','☁️'];
}

function renderWeather(w){
  if(!w)return'';
  const[desc,icon]=weatherInfo(w.weather_code,w.is_day);
  return '<div class="weather-bar"><div class="weather-icon">'+icon+'</div><div style="flex:1">'+
    '<div class="weather-temp">'+Math.round(w.temperature_2m)+'°C</div>'+
    '<div class="weather-desc">'+desc+'</div>'+
    '<div class="weather-extra">💨 '+Math.round(w.wind_speed_10m)+' км/ч · 💧 '+w.relative_humidity_2m+'%</div>'+
    '</div></div>';
}

// ═══ DATA LOADER ═══
const CF='https://anthropic-proxy.uiredepositionherzo.workers.dev';
const FB=CF+'/firebase';


async function loadData(){
  try{
    const r=await fetch(FB+'/opendata_infographic.json',{signal:AbortSignal.timeout(8000)});
    if(r.ok){const d=await r.json();if(d&&d.updated_at)return d}
  }catch(e){}
  // Fallback: try direct
  try{
    const r2=await fetch(CF+'/infographic-data',{signal:AbortSignal.timeout(5000)});
    if(r2.ok)return await r2.json();
  }catch(e){}
  return null;
}

// ═══ RENDER APP ═══
function renderApp(data,weather){
  if(!data){document.getElementById('app').innerHTML='<div style="text-align:center;padding:40px;color:var(--textMuted)">Данные недоступны</div>';return}
  const app=document.getElementById('app');
  const fp=data.fuel?.prices||{};
  const ed=data.education||{};
  const cn=data.counts||{};
  const uk=data.uk||{};
  const tr=data.transport||{};
  const cc=data.culture_clubs||{};
  const totalRecords=Object.values(cn).reduce((a,b)=>a+b,0);
  const updStr=fmtDate(data.updated_at);

  let currentTab='all';
  const tabs=[
    {id:'all',label:'Все'},{id:'budget',label:'💰 Бюджет'},{id:'fuel',label:'⛽ Топливо'},{id:'housing',label:'🏢 ЖКХ'},
    {id:'edu',label:'🎓 Образование'},{id:'transport',label:'🚌 Транспорт'},
    {id:'sport',label:'⚽ Спорт'},{id:'city',label:'🏙️ Город'},
    {id:'eco',label:'♻️ Экология'},{id:'people',label:'👶 Люди'}
  ];

  function show(s){return currentTab==='all'||currentTab===s}

  function buildHTML(){
    let h='';
    // Hero
    h+='<div class="hero">';
    h+='<div class="hero-pill"><span class="dot"></span>Обновляется автоматически</div>';
    h+='<h1>📊 <em>Нижневартовск</em><br>в цифрах</h1>';
    h+='<div class="sub">Открытые данные · ХМАО-Югра</div>';
    h+='<div class="upd">🕐 '+updStr+'</div>';
    h+='<div class="ds-count">📦 '+(data.datasets_total||72)+' датасетов · '+totalRecords.toLocaleString('ru')+' записей</div>';
    h+='</div>';

    // Weather
    h+=renderWeather(weather);

    // Tabs
    h+='<div class="tabs" id="tabsRow">';
    tabs.forEach(t=>{h+='<div class="tab'+(currentTab===t.id?' active':'')+'" data-tab="'+t.id+'">'+t.label+'</div>'});
    h+='</div>';

    // Grid
    h+='<div class="grid">';

    // BUDGET
    if(show('budget')){
      h+='<div class="section-title">💰 Бюджет и контракты</div>';
      const agr=data.agreements||{};
      const byType=(agr.by_type||[]).slice(0,10);
      const maxC=byType[0]?.count||1;
      const ukC=['#dc2626','#ea580c','#0f766e','#2563eb','#7c3aed','#16a34a','#0d9488','#d946ef','#4f46e5','#64748b'];

      // 1. Overview card — key budget numbers
      const totalInv=(agr.total_inv||0);
      const totalGos=(agr.total_gos||0);
      const totalSumm=(agr.total_summ||0);
      h+=card('budget',true,
        cardHead('💰','var(--orangeBg)','Бюджет города','Обзор финансов')+
        makeStatRow([
          {value:Math.round(totalSumm),label:'тыс ₽ контракты',color:'var(--orange)'},
          {value:Math.round(totalInv/1e3),label:'тыс ₽ инвестиции',color:'var(--blue)'},
          {value:Math.round(totalGos/1e3),label:'тыс ₽ госрасходы',color:'var(--red)'}
        ])+
        '<div style="margin-top:8px;display:flex;gap:6px">'+
        '<div style="flex:1;padding:8px;border-radius:10px;background:var(--blueBg);text-align:center">'+
        '<div style="font-size:18px;font-weight:900;color:var(--blue)">'+fmtMoney(totalInv)+'</div>'+
        '<div style="font-size:8px;color:var(--textMuted);margin-top:2px">ИНВЕСТИЦИИ</div></div>'+
        '<div style="flex:1;padding:8px;border-radius:10px;background:var(--redBg);text-align:center">'+
        '<div style="font-size:18px;font-weight:900;color:var(--red)">'+fmtMoney(totalGos)+'</div>'+
        '<div style="font-size:8px;color:var(--textMuted);margin-top:2px">ГОСРАСХОДЫ</div></div></div>'+
        (totalInv>0&&totalGos>0?'<div style="margin-top:6px;height:8px;border-radius:4px;overflow:hidden;display:flex">'+
        '<div style="width:'+Math.round(totalInv/(totalInv+totalGos)*100)+'%;background:var(--blue)"></div>'+
        '<div style="width:'+Math.round(totalGos/(totalInv+totalGos)*100)+'%;background:var(--red)"></div></div>'+
        '<div style="display:flex;justify-content:space-between;font-size:8px;color:var(--textMuted);margin-top:2px">'+
        '<span>Инвестиции '+Math.round(totalInv/(totalInv+totalGos)*100)+'%</span>'+
        '<span>Госрасходы '+Math.round(totalGos/(totalInv+totalGos)*100)+'%</span></div>':'')+
        makeTip('orange','💡','Соотношение инвестиций и госрасходов показывает приоритеты бюджетной политики'),
        null);

      // 2. Agreements by type
      h+=card('budget',true,
        cardHead('📋','var(--redBg)','Муниципальные контракты',(agr.total||0)+' договоров')+
        makeBarRows(byType,maxC,ukC)+
        makeTip('red','📊','Энергосервис — '+((byType[0]?.count||0))+' из '+(agr.total||0)+' договоров ('+Math.round((byType[0]?.count||0)/(agr.total||1)*100)+'%)'),
        null);

      // 3. Top contracts
      const topContracts=(agr.top||[]).slice(0,5);
      if(topContracts.length){
        let tcRows='';
        topContracts.forEach(function(tc,i){
          const s=tc.summ||0;const inv=tc.vol_inv||0;const gos=tc.vol_gos||0;
          tcRows+='<div style="padding:6px 0;border-bottom:1px solid var(--border)">';
          tcRows+='<div style="display:flex;justify-content:space-between;align-items:flex-start">';
          tcRows+='<div style="flex:1"><div style="font-size:10px;font-weight:700">'+(i+1)+'. '+esc((tc.title||'').substring(0,60))+'</div>';
          tcRows+='<div style="font-size:8px;color:var(--textMuted);margin-top:1px">'+esc(tc.type||'')+' · '+esc(tc.org||'')+' · '+esc(tc.date||'')+'</div></div>';
          tcRows+='<div style="text-align:right;min-width:60px">';
          if(s>0)tcRows+='<div style="font-size:11px;font-weight:800;color:var(--orange)">'+fmtMoney(s*1000)+'</div>';
          if(gos>0)tcRows+='<div style="font-size:9px;color:var(--red)">гос: '+fmtMoney(gos*1000)+'</div>';
          if(inv>0)tcRows+='<div style="font-size:9px;color:var(--blue)">инв: '+fmtMoney(inv)+'</div>';
          tcRows+='</div></div>';
          if(tc.desc)tcRows+='<div style="font-size:8px;color:var(--textMuted);margin-top:2px;line-height:1.3">'+esc((tc.desc||'').substring(0,120))+'</div>';
          tcRows+='</div>';
        });
        h+=card('budget',true,
          cardHead('🏆','var(--yellowBg)','Крупнейшие контракты','Топ-5 по сумме')+tcRows+
          makeTip('orange','🏗️','Строительство дорог (КЖЦ) — крупнейшие контракты города'),
          null);
      }

      // 4. Budget bulletins trend
      const bb=data.budget_bulletins||{};
      const bi=data.budget_info||{};
      if(bb.total||bi.total){
        const bbYears=(bb.items||[]).map(function(b){return{year:parseInt(b.title)||0,count:1}}).filter(function(b){return b.year>0}).reverse();
        h+=card('budget',false,
          cardHead('📰','var(--indigoBg)','Бюджетные бюллетени',(bb.total||0)+' выпусков')+
          makeStatRow([{value:bb.total||0,label:'Бюллетеней',color:'var(--indigo)'},{value:bi.total||0,label:'Отчётов',color:'var(--teal)'}])+
          '<div style="margin-top:6px;font-size:9px;color:var(--textMuted)">Публикуются ежеквартально с 2015 года</div>'+
          makeTip('indigo','📊','Финансовая отчётность доступна на data.n-vartovsk.ru'),
          null);
      }

      // 5. Property
      const p=data.property||{};
      h+=card('budget',true,
        cardHead('🏛️','var(--blueBg)','Муниципальное имущество',(p.total||0).toLocaleString('ru')+' объектов')+
        makeStatRow([{value:p.realestate||0,label:'Недвижимость',color:'var(--blue)'},{value:p.lands||0,label:'Земля',color:'var(--green)'},
          {value:p.movable||0,label:'Движимое',color:'var(--teal)'}])+
        '<div style="margin-top:6px;display:flex;gap:4px;flex-wrap:wrap">'+
        '<div style="padding:4px 8px;border-radius:8px;background:var(--purpleBg);font-size:9px"><span style="font-weight:700;color:var(--purple)">'+(p.privatization||0)+'</span> приватизировано</div>'+
        '<div style="padding:4px 8px;border-radius:8px;background:var(--tealBg);font-size:9px"><span style="font-weight:700;color:var(--teal)">'+(p.rent||0)+'</span> в аренде</div>'+
        '<div style="padding:4px 8px;border-radius:8px;background:var(--blueBg);font-size:9px"><span style="font-weight:700;color:var(--blue)">'+(p.stoks||0)+'</span> акций</div></div>'+
        makeTip('blue','🏛️','Общий реестр: '+(p.total||0).toLocaleString('ru')+' объектов муниципальной собственности'),
        null);

      // 6. Municipal programs
      const prg=data.programs||{};
      if(prg.total){
        h+=card('budget',false,
          cardHead('📜','var(--greenBg)','Муниципальные программы',prg.total+' программ')+
          bigNum(prg.total,'действующих программ','var(--green)')+
          '<div style="margin-top:4px;font-size:9px;color:var(--textMuted)">Стратегия развития до 2036 года</div>'+
          makeTip('green','📜','Включая план мероприятий и госпрограммы ХМАО-Югры'),
          null);
      }
    }

    // FUEL
    if(show('fuel')){
      h+='<div class="section-title">⛽ Топливо и АЗС</div>';
      let fuelRows='';
      const fuelC=['#dc2626','#ea580c','#2563eb','#16a34a'];
      Object.entries(fp).forEach(([name,v],i)=>{
        const pct=Math.round(v.avg/90*100);
        fuelRows+='<div class="fuel-row"><span class="fuel-name">'+name+'</span>'+
          '<div class="fuel-bar"><div class="fuel-fill" style="--w:'+pct+'%;width:'+pct+'%;background:'+fuelC[i%4]+'">'+v.min+'-'+v.max+'</div></div>'+
          '<span class="fuel-avg" style="color:'+fuelC[i%4]+'">'+v.avg+'₽</span></div>';
      });
      h+=card('fuel',true,
        cardHead('⛽','var(--redBg)','Цены на топливо','Дата: '+(data.fuel?.date||'—')+' · '+(data.fuel?.stations||0)+' АЗС')+
        fuelRows+makeTip('orange','⛽','Средние цены по '+(data.fuel?.stations||0)+' АЗС Нижневартовска'),
        null);
    }

    // HOUSING
    if(show('housing')){
      h+='<div class="section-title">🏢 ЖКХ и управление</div>';
      h+=card('housing',false,
        cardHead('🏢','var(--tealBg)','УК города','')+
        bigNum(uk.total||0,'управляющих компаний','var(--primary)')+
        '<div style="margin-top:6px;font-size:14px;font-weight:700;color:var(--teal)">'+(uk.houses||0)+' <span style="font-size:10px;color:var(--textMuted)">домов</span></div>'+
        makeTip('teal','🏢',(uk.total||0)+' УК обслуживают '+(uk.houses||0)+' домов. В среднем '+Math.round((uk.houses||0)/(uk.total||1))+' домов на компанию'),
        null);
      h+=card('housing',false,
        cardHead('📞','var(--redBg)','Аварийные','')+
        bigNum((data.gkh||[]).length,'служб ЖКХ','var(--red)')+
        '<div style="margin-top:4px;font-size:10px;color:var(--textMuted)">112 — единый номер</div>'+
        makeTip('red','📞','При авариях звоните 112 или в диспетчерскую вашей УК'),
        null);
      // UK Email card
      const allUks=uk.top||[];
      let ukList='';
      allUks.slice(0,10).forEach((u,i)=>{
        ukList+='<div class="uk-email-item"><div style="display:flex;justify-content:space-between;align-items:center">'+
          '<span style="font-weight:600;flex:1">'+esc(u.name)+'</span>'+
          '<span style="font-size:9px;color:var(--textMuted)">'+u.houses+' домов</span></div>'+
          (u.email?'<div style="display:flex;gap:6px;margin-top:3px;align-items:center">'+
          '<span style="font-size:9px;color:var(--textMuted)">'+u.email+'</span>'+
          '<button class="uk-email-btn" onclick="sendUkEmail(\\''+esc(u.name).replace(/'/g,"\\\\'")+'\\',\\''+u.email+'\\')">✉️ Написать</button></div>':
          '<div style="font-size:9px;color:var(--textMuted)">Email не указан</div>')+'</div>';
      });
      h+=card('housing',true,
        cardHead('✉️','var(--indigoBg)','Написать в УК анонимно','Все '+(allUks.length||42)+' управляющих компаний')+ukList+
        makeTip('indigo','🔒','Анонимная жалоба отправляется напрямую в УК'),
        allUks.slice(10).map((u,i)=>'<div class="uk-email-item"><span style="font-weight:600;font-size:10px">'+esc(u.name)+'</span>'+
          (u.email?' <button class="uk-email-btn" onclick="sendUkEmail(\\''+esc(u.name).replace(/'/g,"\\\\'")+'\\',\\''+u.email+'\\')">✉️</button>':'')+'</div>').join(''),
        'Все УК ('+allUks.length+')');
    }

    // EDUCATION
    if(show('edu')){
      h+='<div class="section-title">🎓 Образование</div>';
      h+=card('edu',false,
        cardHead('🎓','var(--blueBg)','Образование','')+
        makeStatRow([{value:ed.kindergartens||0,label:'Детсадов',color:'var(--orange)'},{value:ed.schools||0,label:'Школ',color:'var(--blue)'},{value:ed.dod||0,label:'ДОД',color:'var(--purple)'}])+
        makeTip('blue','🎓','Сеть образования покрывает все районы Нижневартовска'),null);
      h+=card('edu',false,
        cardHead('🎭','var(--purpleBg)','Культура','')+
        bigNum(ed.culture||0,'учреждений','var(--purple)')+
        '<div style="margin-top:4px;font-size:10px;color:var(--textMuted)">'+(cc.total||0)+' кружков · '+(cc.free||0)+' бесплатных</div>'+
        makeTip('purple','🎭',(cc.free||0)+' бесплатных кружков из '+(cc.total||0)+' ('+(Math.round((cc.free||0)/(cc.total||1)*100))+'%)'),null);
    }

    // TRANSPORT
    if(show('transport')){
      h+='<div class="section-title">🚌 Транспорт</div>';
      h+=card('transport',false,
        cardHead('🚌','var(--blueBg)','Транспорт','')+
        makeStatRow([{value:tr.routes||0,label:'Маршрутов',color:'var(--blue)'},{value:tr.stops||0,label:'Остановок',color:'var(--teal)'}])+
        makeTip('blue','🚌',(tr.municipal||0)+' муниципальных и '+((tr.routes||0)-(tr.municipal||0))+' коммерческих маршрутов'),null);
      h+=card('transport',false,
        cardHead('🛣️','var(--indigoBg)','Дороги','')+
        makeStatRow([{value:data.road_service?.total||0,label:'Объектов',color:'var(--indigo)'},{value:data.road_works?.total||0,label:'Работ',color:'var(--orange)'}])+
        makeTip('indigo','🛣️',(data.road_works?.total||0)+' дорожных работ на '+(data.road_service?.total||0)+' объектах'),null);
    }

    // SPORT
    if(show('sport')){
      h+='<div class="section-title">⚽ Спорт</div>';
      h+=card('sport',false,
        cardHead('🏅','var(--greenBg)','Спорт','')+
        bigNum(ed.sections||0,'спортивных секций','var(--green)')+
        '<div style="margin-top:6px;font-size:11px"><span style="color:var(--green)">● </span>'+(ed.sections_free||0)+' бесплатных<br><span style="color:var(--orange)">● </span>'+(ed.sections_paid||0)+' платных</div>'+
        makeTip('green','🎯',Math.round((ed.sections_free||0)/(ed.sections||1)*100)+'% секций бесплатные'),null);
      h+=card('sport',false,
        cardHead('👨‍🏫','var(--tealBg)','Тренеры','')+
        bigNum(data.trainers?.total||0,'тренеров','var(--teal)')+
        '<div style="margin-top:4px;font-size:10px;color:var(--textMuted)">'+(cn.sport_places||0)+' площадок · '+(ed.sport_orgs||0)+' организаций</div>',null);
    }

    // CITY
    if(show('city')){
      h+='<div class="section-title">🏙️ Город</div>';
      h+=card('city',false,
        cardHead('🏗️','var(--orangeBg)','Строительство','')+
        makeStatRow([{value:cn.construction||0,label:'Объектов',color:'var(--orange)'},{value:cn.permits||0,label:'Разрешений',color:'var(--blue)'}])+
        makeTrendBar(data.building?.permits_trend||[],'var(--orange)','Разрешения по годам'),null);
      h+=card('city',false,
        cardHead('♿','var(--pinkBg)','Доступная среда','')+
        bigNum(cn.accessibility||0,'объектов','var(--pink)')+
        makeTip('pink','♿','Пандусы, звуковые светофоры, дорожные знаки'),null);
      h+=card('city',false,
        cardHead('💵','var(--greenBg)','Зарплаты служащих','')+
        bigNum(data.salary?.latest_avg||0,'тыс. ₽ средняя','var(--green)')+
        makeTrendBar(data.salary?.trend||[],'var(--green)','Динамика по годам','avg')+
        (data.salary?.growth_pct?makeTip('green','📈','Рост за '+(data.salary?.trend?.length||0)+' лет: +'+data.salary.growth_pct+'%'):''),null);
      h+=card('city',false,
        cardHead('🗣️','var(--indigoBg)','Публичные слушания','')+
        bigNum(data.hearings?.total||0,'слушаний','var(--indigo)')+
        makeTrendBar(data.hearings?.trend||[],'var(--indigo)','Слушания по годам'),null);
      h+=card('city',false,
        cardHead('📰','var(--blueBg)','Новости','')+
        makeStatRow([{value:data.news?.total||0,label:'Публикаций',color:'var(--blue)'},{value:data.news?.rubrics||0,label:'Рубрик',color:'var(--teal)'}])+
        makeTrendBar(data.news?.trend||[],'var(--blue)','Публикации по годам'),null);
      h+=card('city',false,
        cardHead('👥','var(--greenBg)','Демография','')+
        (data.demography&&data.demography[0]?
          makeStatRow([{value:parseInt(data.demography[0].birth)||0,label:'Рождений',color:'var(--green)'},{value:parseInt(data.demography[0].marriages)||0,label:'Браков',color:'var(--pink)'}]):
          '<div style="font-size:10px;color:var(--textMuted)">Данные обновляются</div>'),null);
      h+=card('city',false,
        cardHead('📋','var(--blueBg)','Справочник','')+
        bigNum(cn.phonebook||0,'телефонов','var(--blue)')+
        '<div style="margin-top:4px;font-size:10px;color:var(--textMuted)">'+(cn.admin||0)+' подразделений · '+(cn.mfc||0)+' МФЦ</div>',null);
      h+=card('city',false,
        cardHead('📡','var(--tealBg)','Связь','')+
        bigNum(data.communication?.total||0,'объектов связи','var(--teal)'),null);
    }

    // ECO
    if(show('eco')){
      h+='<div class="section-title">♻️ Экология</div>';
      const wg=data.waste?.groups||[];
      const wC=['#16a34a','#dc2626','#0d9488','#ea580c','#7c3aed','#64748b','#78716c'];
      let wasteItems='';
      wg.forEach((w,i)=>{wasteItems+='<div style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:11px">'+
        '<div style="width:10px;height:10px;border-radius:50%;background:'+wC[i%7]+';flex-shrink:0"></div>'+w.name+
        '<span style="font-weight:700;margin-left:auto;font-size:12px;color:'+wC[i%7]+'">'+w.count+'</span></div>'});
      h+=card('eco',true,
        cardHead('♻️','var(--greenBg)','Раздельный сбор отходов',(data.waste?.total||0)+' точек')+wasteItems+
        makeTip('green','🌱','Опасные отходы — самая большая категория. Город развивает раздельный сбор'),null);
    }

    // PEOPLE
    if(show('people')){
      h+='<div class="section-title">👶 Люди</div>';
      const boys=data.names?.boys||[];
      const girls=data.names?.girls||[];
      let nameGrid='<div style="display:grid;grid-template-columns:1fr 1fr;gap:0 12px">';
      nameGrid+='<div><h3 style="font-size:9px;color:var(--textMuted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:4px;text-align:center;font-weight:700">👦 Мальчики</h3>';
      boys.forEach((b,i)=>{nameGrid+='<div style="display:flex;justify-content:space-between;padding:3px 0;font-size:11px;border-bottom:1px solid var(--border)"><span><span style="color:var(--primary);font-weight:700;font-size:10px;margin-right:4px">'+(i+1)+'</span>'+b.n+'</span><span style="color:var(--textMuted);font-weight:600;font-size:10px">'+b.c+'</span></div>'});
      nameGrid+='</div><div><h3 style="font-size:9px;color:var(--textMuted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:4px;text-align:center;font-weight:700">👧 Девочки</h3>';
      girls.forEach((g,i)=>{nameGrid+='<div style="display:flex;justify-content:space-between;padding:3px 0;font-size:11px;border-bottom:1px solid var(--border)"><span><span style="color:var(--primary);font-weight:700;font-size:10px;margin-right:4px">'+(i+1)+'</span>'+g.n+'</span><span style="color:var(--textMuted);font-weight:600;font-size:10px">'+g.c+'</span></div>'});
      nameGrid+='</div></div>';
      h+=card('people',true,
        cardHead('👶','var(--accentBg)','Популярные имена','Статистика за все годы')+nameGrid+
        makeTip('purple','👼',(boys[0]?boys[0].n:'')+' и '+(girls[0]?.n||'')+' — самые популярные имена'),null);
    }

    h+='</div>'; // grid

    // Footer
    h+='<div class="footer">Источник: <a href="https://data.n-vartovsk.ru" target="_blank">data.n-vartovsk.ru</a> · '+(data.datasets_total||72)+' датасетов<br>Пульс города · Нижневартовск © 2026</div>';

    return h;
  }

  app.innerHTML=buildHTML();

  // Tab switching
  app.addEventListener('click',function(e){
    const tab=e.target.closest('[data-tab]');
    if(!tab)return;
    currentTab=tab.dataset.tab;
    haptic();
    app.innerHTML=buildHTML();
    initObserver();
  });

  initObserver();
}

// ═══ IntersectionObserver for card animations ═══
function initObserver(){
  const cards=document.querySelectorAll('.card');
  if(!('IntersectionObserver' in window)){cards.forEach(c=>c.classList.add('visible'));return}
  const obs=new IntersectionObserver(entries=>{
    entries.forEach(e=>{if(e.isIntersecting){e.target.classList.add('visible');obs.unobserve(e.target)}});
  },{threshold:.08,rootMargin:'0px 0px -20px 0px'});
  cards.forEach(c=>obs.observe(c));
}

// ═══ Send UK Email ═══
function sendUkEmail(ukName,ukEmail){
  const desc=prompt('Опишите проблему для '+ukName+':');
  if(!desc||!desc.trim())return;
  const addr=prompt('Адрес (необязательно):','');
  const body='Уважаемая '+ukName+',\\n\\nЧерез систему Пульс города поступила анонимная жалоба:\\n\\n'+desc+(addr?'\\n\\nАдрес: '+addr:'')+'\\n\\nПросим рассмотреть.\\nС уважением, Пульс города';
  fetch(CF+'/send-email',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({to_email:ukEmail,to_name:ukName,subject:'Анонимная жалоба — Пульс города',body:body,from_name:'Пульс города'})
  }).then(r=>r.json()).then(d=>{alert(d.ok?'Отправлено в '+ukName:'Ошибка отправки')}).catch(()=>alert('Ошибка сети'));
}

// ═══ INIT ═══
Promise.all([loadData(),loadWeather()]).then(([data,weather])=>{
  CityPulse.init();
  renderApp(data,weather);
  // Feed pulse with complaint data from Firebase
  fetch(FB+'/complaints.json',{signal:AbortSignal.timeout(5000)})
    .then(r=>r.json()).then(d=>{
      if(d){const arr=Object.values(d).filter(c=>c&&c.category);CityPulse.feed(arr)}
    }).catch(()=>{});
  // Hide loader
  const ld=document.getElementById('loader');
  if(ld){ld.classList.add('hide');setTimeout(()=>ld.remove(),600)}
});


<\/script>
</body></html>
`;

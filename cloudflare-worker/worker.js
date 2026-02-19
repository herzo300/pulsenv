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
    let path = url.pathname.replace(/\/+$/, "") || "/";

    // --- Health / status (для мониторинга) ---
    if (path === "/health" || path === "/status") {
      return new Response(JSON.stringify({
        ok: true,
        service: "soobshio-worker",
        endpoints: ["/app", "/map", "/info", "/infographic-data", "/send-email", "/api/join", "/health"],
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // --- Email endpoint ---
    if (path === "/send-email" && request.method === "POST") {
      return handleSendEmail(request);
    }

    // --- Join complaint (присоединиться к жалобе) ---
    if (path === "/api/join" && request.method === "POST") {
      return handleJoinComplaint(request);
    }

    // --- Unified Web App Script ---
    if (path === "/app_script.js") {
      // Return app_script.js content - in production, this should be read from file or embedded
      // For now, return a redirect or fetch from external source
      return new Response("// App script loaded from external source\nconsole.log('App script placeholder');", {
        headers: { "Content-Type": "application/javascript;charset=utf-8", "Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache" },
      });
    }

    // --- Unified Web App (для Telegram) ---
    if (path === "/app" || path === "/app/") {
      // Версионирование через параметр v= для обхода кэша
      const version = url.searchParams.get("v") || Date.now();
      // Добавляем версию в HTML для отслеживания
      // Удаляем старую версию если есть и добавляем новую
      let htmlWithVersion = APP_HTML.replace(
        /<meta name="app-version" content="[^"]*">/g,
        ''
      );
      htmlWithVersion = htmlWithVersion.replace(
        '<title>Пульс города — Нижневартовск</title>',
        `<title>Пульс города — Нижневартовск</title>\n<meta name="app-version" content="${version}">`
      );
      return new Response(htmlWithVersion, {
        headers: { 
          "Content-Type": "text/html;charset=utf-8", 
          "Access-Control-Allow-Origin": "*", 
          "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
          "Pragma": "no-cache",
          "Expires": "0"
        },
      });
    }

    // --- Map Web App (для Telegram) - backward compatibility ---
    if (path === "/map" || path === "/map/") {
      // Версионирование для карты - всегда используем timestamp для обхода кэша
      const version = url.searchParams.get("v") || Date.now();
      let mapWithVersion = MAP_HTML.replace(
        /<meta name="app-version" content="[^"]*">/g,
        ''
      );
      mapWithVersion = mapWithVersion.replace(
        '<title>🗺️ Карта проблем Нижневартовска — Пульс города</title>',
        `<title>🗺️ Карта проблем Нижневартовска — Пульс города</title>\n<meta name="app-version" content="${version}">`
      );
      return new Response(mapWithVersion, {
        headers: { 
          "Content-Type": "text/html;charset=utf-8", 
          "Access-Control-Allow-Origin": "*", 
          "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
          "Pragma": "no-cache",
          "Expires": "0"
        },
      });
    }

    // --- Infographic Data API ---
    if (path === "/infographic-data") {
      return new Response(INFOGRAPHIC_DATA, {
        headers: { "Content-Type": "application/json;charset=utf-8", "Access-Control-Allow-Origin": "*", "Cache-Control": "public, max-age=3600" },
      });
    }

    // --- Infographic Web App ---
    if (path === "/info" || path === "/info/") {
      // Версионирование для инфографики
      const version = url.searchParams.get("v") || Date.now();
      // Удаляем старую версию если есть и добавляем новую
      let infoWithVersion = INFO_HTML.replace(
        /<meta name="app-version" content="[^"]*">/g,
        ''
      );
      // Удаляем старую версию если есть
      infoWithVersion = infoWithVersion.replace(
        /<meta name="app-version" content="[^"]*">/g,
        ''
      );
      // Добавляем новую версию
      if (!infoWithVersion.includes('<meta name="app-version"')) {
        infoWithVersion = infoWithVersion.replace(
          '<title>📊 Инфографика Нижневартовска — Пульс города</title>',
          `<title>📊 Инфографика Нижневартовска — Пульс города</title>\n<meta name="app-version" content="${version}">`
        );
      }
      return new Response(infoWithVersion, {
        headers: { 
          "Content-Type": "text/html;charset=utf-8", 
          "Access-Control-Allow-Origin": "*",
          "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
          "Pragma": "no-cache",
          "Expires": "0"
        },
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


const MAX_BODY_LENGTH = 50000;
const MAX_SUBJECT_LENGTH = 200;
const MAX_FROM_NAME_LENGTH = 100;
const VALID_COMPLAINT_ID = /^[a-zA-Z0-9_-]{1,64}$/;

// --- Отправка email через Resend API (бесплатно 100/день) ---
async function handleSendEmail(request) {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  };

  try {
    const text = await request.text();
    if (text.length > 100 * 1024) {
      return new Response(
        JSON.stringify({ ok: false, error: "Request body too large" }),
        { status: 413, headers: corsHeaders }
      );
    }
    const data = JSON.parse(text);
    let { to_email, to_name, subject, body, from_name } = data;

    if (!to_email || !subject || !body) {
      return new Response(
        JSON.stringify({ ok: false, error: "Missing to_email, subject, or body" }),
        { status: 400, headers: corsHeaders }
      );
    }
    if (typeof to_email !== "string" || typeof subject !== "string" || typeof body !== "string") {
      return new Response(
        JSON.stringify({ ok: false, error: "Invalid field types" }),
        { status: 400, headers: corsHeaders }
      );
    }
    to_email = String(to_email).trim().slice(0, 254);
    subject = String(subject).trim().slice(0, MAX_SUBJECT_LENGTH);
    body = String(body).slice(0, MAX_BODY_LENGTH);
    from_name = from_name ? String(from_name).trim().slice(0, MAX_FROM_NAME_LENGTH) : "Пульс города";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to_email)) {
      return new Response(
        JSON.stringify({ ok: false, error: "Invalid to_email format" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const brevoKey = typeof BREVO_API_KEY !== "undefined" ? BREVO_API_KEY : null;
    if (brevoKey) {
      const mailResp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "Content-Type": "application/json", "api-key": brevoKey },
        body: JSON.stringify({
          sender: { name: from_name, email: "pulsgoroda@noreply.ru" },
          to: [{ email: to_email, name: (to_name && String(to_name).slice(0, 100)) || "" }],
          subject, textContent: body,
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
          from: `${from_name} <onboarding@resend.dev>`,
          to: [to_email], subject, text: body,
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
    const text = await request.text();
    if (text.length > 4096) {
      return new Response(JSON.stringify({ ok: false, error: "Request body too large" }), { status: 413, headers: corsHeaders });
    }
    const data = JSON.parse(text);
    const rawId = data && data.id;
    if (rawId == null || rawId === "") {
      return new Response(JSON.stringify({ ok: false, error: "no id" }), { status: 400, headers: corsHeaders });
    }
    const id = String(rawId).trim();
    if (!VALID_COMPLAINT_ID.test(id)) {
      return new Response(JSON.stringify({ ok: false, error: "Invalid id format" }), { status: 400, headers: corsHeaders });
    }
    const fbBase = "https://soobshio-default-rtdb.europe-west1.firebasedatabase.app";
    // Get current complaint
    const r = await fetch(fbBase + "/complaints/" + encodeURIComponent(id) + ".json");
    if (!r.ok) return new Response(JSON.stringify({ok:false,error:"not found"}), {status:404, headers:corsHeaders});
    const complaint = await r.json();
    if (!complaint) return new Response(JSON.stringify({ok:false,error:"not found"}), {status:404, headers:corsHeaders});
    const oldS = complaint.supporters || 0;
    const newS = oldS + 1;
    // Update supporters count
    await fetch(fbBase + "/complaints/" + encodeURIComponent(id) + "/supporters.json", {
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
      await fetch(fbBase + "/complaints/" + encodeURIComponent(id) + "/supporters_notified.json", {
        method: "PUT", body: JSON.stringify(1),
        headers: {"Content-Type": "application/json"}
      });
    }
    return new Response(JSON.stringify({ok:true, supporters:newS, emailSent:emailSent}), {status:200, headers:corsHeaders});
  } catch(e) {
    return new Response(JSON.stringify({ok:false, error:e.message}), {status:500, headers:corsHeaders});
  }
}

// ===== Unified Web App (Telegram Web App) =====
const APP_HTML = `<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Пульс города — Нижневартовск</title>
<script src="https://telegram.org/js/telegram-web-app.js"><\/script>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"><\/script>
<script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"><\/script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/animejs/3.2.2/anime.min.js"><\/script>
<script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"><\/script>
<script src="https://code.iconify.design/3/3.1.0/iconify.min.js"><\/script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"><\/script>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
</head>
<body>
<!-- Aurora Background -->
<canvas id="auroraCanvas"></canvas>

<!-- Splash Screen -->
<div id="splash">
  <div class="splash-content">
    <div class="oil-drop-container">
      <svg class="oil-drop" viewBox="0 0 200 240">
        <defs>
          <linearGradient id="oilGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:#0a0a1a;stop-opacity:1" />
            <stop offset="50%" style="stop-color:#1a1a2e;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#16213e;stop-opacity:1" />
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
        <ellipse class="drop-shine" cx="80" cy="80" rx="20" ry="30" fill="rgba(0,240,255,0.2)"/>
        <circle class="drop-bubble" cx="100" cy="120" r="8" fill="rgba(0,255,136,0.15)"/>
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
  <!-- Tab Navigation -->
  <div id="tabNav">
    <button class="tab-btn active" data-tab="map">
      <span data-icon="mdi:map"></span>
      <span>Карта</span>
    </button>
    <button class="tab-btn" data-tab="stats">
      <span data-icon="mdi:chart-box"></span>
      <span>Статистика</span>
    </button>
    <button class="tab-btn" data-tab="rating">
      <span data-icon="mdi:office-building"></span>
      <span>Рейтинг УК</span>
    </button>
  </div>

  <!-- Map Tab -->
  <div id="mapTab" class="tab-content active">
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
    </div>

    <!-- FAB -->
    <button class="fab" id="fabBtn" title="Подать жалобу">
      <div class="fab-drop">
        <svg viewBox="0 0 56 68">
          <defs>
            <linearGradient id="fabOilGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#00f0ff"/>
              <stop offset="100%" style="stop-color:#00c8d4"/>
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
  </div>

  <!-- Stats Tab -->
  <div id="statsTab" class="tab-content">
    <div class="stats-container">
      <div id="statsContent"></div>
    </div>
  </div>

  <!-- Rating Tab -->
  <div id="ratingTab" class="tab-content">
    <div class="rating-container">
      <div id="ratingContent"></div>
    </div>
  </div>

  <!-- Complaint Form Modal -->
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
<script>
// ═══════════════════════════════════════════════════════
// Пульс города — Объединенное приложение v7.0
// Нефтяной край + Северное сияние
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
  cityRhythm: { bpm: 60, targetBpm: 60, mood: 'Спокойно', severity: 0 },
  lastUpdateTime: null,
  realtimeInterval: null,
  knownComplaintIds: new Set(),
  currentTab: 'map'
};

// ═══ AURORA BACKGROUND — Северное сияние ═══
(function initAurora() {
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
    
    // Северное сияние — волны зеленого и синего
    const layers = [
      { color: 'rgba(0, 240, 255, 0.15)', offset: 0, speed: 0.3, height: H * 0.4 },
      { color: 'rgba(0, 255, 136, 0.12)', offset: Math.PI / 3, speed: 0.4, height: H * 0.35 },
      { color: 'rgba(99, 102, 241, 0.1)', offset: Math.PI / 1.5, speed: 0.25, height: H * 0.3 }
    ];
    
    layers.forEach((layer, i) => {
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
    
    // Нефтяные блики — мерцающие точки
    for (let i = 0; i < 20; i++) {
      const x = (Math.sin(time * 0.5 + i) * 0.5 + 0.5) * W;
      const y = (Math.cos(time * 0.3 + i * 0.7) * 0.5 + 0.5) * H;
      const size = Math.sin(time * 2 + i) * 3 + 4;
      const alpha = Math.sin(time * 3 + i) * 0.3 + 0.4;
      
      ctx.beginPath();
      const grad = ctx.createRadialGradient(x, y, 0, x, y, size * 2);
      grad.addColorStop(0, \`rgba(0, 240, 255, \${alpha})\`);
      grad.addColorStop(1, 'transparent');
      ctx.fillStyle = grad;
      ctx.arc(x, y, size * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    
    requestAnimationFrame(drawAurora);
  }
  
  drawAurora();
})();

// ═══ STYLES — Нефтяной край + Северное сияние ═══
const styles = \`
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #0a0a0f; --surface: rgba(10, 15, 30, 0.95); --text: #e0e7ff;
  --primary: #00f0ff; --primary-light: #33f3ff; --primary-dark: #00c8d4;
  --success: #00ff88; --danger: #ff3366; --warning: #ffaa00; --info: #00aaff;
  --neon-cyan: #00f0ff; --neon-green: #00ff88; --neon-blue: #0066ff;
  --oil-dark: #0a0a1a; --oil-light: #1a1a2e; --aurora-green: rgba(0, 255, 136, 0.3);
  --border: rgba(0, 240, 255, 0.2); 
  --shadow: 0 0 30px rgba(0, 240, 255, 0.3), 0 4px 20px rgba(0, 0, 0, 0.8);
  --shadow-glow: 0 0 40px rgba(0, 240, 255, 0.5), 0 0 80px rgba(0, 255, 136, 0.3);
  --radius: 16px; --radius-sm: 8px; --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
body { 
  font-family: 'Inter', 'SF Pro Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; 
  background: var(--bg); 
  color: var(--text); 
  overflow: hidden; 
}

/* Aurora Canvas */
#auroraCanvas { 
  position: fixed; 
  inset: 0; 
  z-index: 0; 
  pointer-events: none;
  opacity: 0.6;
}

/* Splash Screen */
#splash { 
  position: fixed; 
  inset: 0; 
  z-index: 9999; 
  background: linear-gradient(135deg, #0a0e1a 0%, #1e1b4b 50%, #0f3460 100%); 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  transition: opacity 0.6s, transform 0.6s; 
}
#splash.hide { opacity: 0; transform: scale(1.15); pointer-events: none; }
.splash-content { position: relative; z-index: 1; text-align: center; max-width: 360px; padding: 20px; }

/* Oil Drop Logo */
.oil-drop-container { position: relative; width: 140px; height: 170px; margin: 0 auto 20px; }
.oil-drop { width: 100%; height: 100%; filter: drop-shadow(0 0 20px rgba(0, 240, 255, 0.6)); animation: oilFloat 4s ease-in-out infinite; }
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
.splash-title { 
  font-size: 32px; 
  font-weight: 900; 
  background: linear-gradient(135deg, #00f0ff, #00ff88, #00aaff); 
  -webkit-background-clip: text; 
  -webkit-text-fill-color: transparent; 
  margin-bottom: 8px; 
  animation: titleSlide 0.8s ease 0.3s both; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  gap: 12px; 
}
.title-icon { font-size: 36px; color: var(--primary-light); animation: iconSpin 3s ease-in-out infinite; }
@keyframes iconSpin { 0%, 100% { transform: rotate(0deg); } 50% { transform: rotate(10deg); } }
@keyframes titleSlide { from { opacity: 0; transform: translateX(-30px); } to { opacity: 1; transform: translateX(0); } }
.splash-subtitle { 
  font-size: 11px; 
  letter-spacing: 4px; 
  color: rgba(0, 240, 255, 0.6); 
  text-transform: uppercase; 
  font-weight: 700; 
  margin-bottom: 24px; 
  animation: fadeIn 0.8s ease 0.5s both; 
  text-shadow: 0 0 10px rgba(0, 240, 255, 0.5);
}
@keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }

/* City Rhythm Visualizer */
.rhythm-container { position: relative; margin: 0 auto 20px; animation: fadeIn 0.8s ease 0.7s both; }
#rhythmCanvas { display: block; margin: 0 auto; opacity: 0.9; }
.rhythm-info { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 12px; }
.rhythm-bpm { font-size: 36px; font-weight: 900; color: var(--success); line-height: 1; font-variant-numeric: tabular-nums; transition: color 0.5s; animation: bpmPulse 1s ease-in-out infinite; text-shadow: 0 0 15px rgba(0, 255, 136, 0.6); }
@keyframes bpmPulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.05); } }
.rhythm-label { font-size: 9px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; letter-spacing: 1px; }
.rhythm-mood { font-size: 13px; font-weight: 700; color: var(--success); transition: color 0.5s; padding: 4px 12px; background: rgba(0, 255, 136, 0.15); border-radius: 12px; border: 1px solid rgba(0, 255, 136, 0.3); }

/* Stats Cards */
.splash-stats { display: flex; justify-content: center; gap: 12px; margin-bottom: 20px; animation: fadeIn 0.8s ease 0.9s both; }
.stat-card { 
  text-align: center; 
  background: rgba(10, 15, 30, 0.8); 
  border-radius: var(--radius-sm); 
  padding: 12px; 
  min-width: 80px; 
  box-shadow: 4px 4px 12px rgba(0, 0, 0, 0.6), 0 0 20px rgba(0, 240, 255, 0.2); 
  backdrop-filter: blur(10px); 
  border: 1px solid rgba(0, 240, 255, 0.3); 
  transition: var(--transition); 
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 6px 6px 16px rgba(0, 0, 0, 0.7), 0 0 30px rgba(0, 240, 255, 0.4); }
.stat-icon { display: block; font-size: 24px; margin-bottom: 6px; opacity: 0.7; }
.stat-num { display: block; font-size: 24px; font-weight: 900; color: var(--primary-light); line-height: 1; text-shadow: 0 0 10px rgba(0, 240, 255, 0.5); }
.stat-label { display: block; font-size: 8px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px; font-weight: 600; }

/* Progress */
.splash-progress { animation: fadeIn 0.8s ease 1.1s both; }
.progress-bar { position: relative; width: 220px; height: 6px; background: rgba(255, 255, 255, 0.1); border-radius: 3px; margin: 0 auto 10px; overflow: hidden; }
.progress-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--primary), var(--success)); border-radius: 3px; transition: width 0.3s; position: relative; z-index: 1; box-shadow: 0 0 10px rgba(0, 240, 255, 0.6); }
.progress-glow { position: absolute; inset: 0; background: linear-gradient(90deg, transparent, rgba(0, 240, 255, 0.5), transparent); animation: progressGlow 2s ease-in-out infinite; }
@keyframes progressGlow { 0%, 100% { transform: translateX(-100%); } 50% { transform: translateX(100%); } }
.progress-text { font-size: 10px; color: rgba(255, 255, 255, 0.3); font-weight: 500; }

/* Main App */
#app { position: relative; width: 100%; height: 100vh; display: none; }
#app.show { display: block; }

/* Tab Navigation */
#tabNav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 2000;
  display: flex;
  background: linear-gradient(180deg, rgba(10, 15, 30, 0.98) 0%, rgba(10, 15, 30, 0.95) 100%);
  backdrop-filter: blur(20px);
  border-top: 1px solid rgba(0, 240, 255, 0.3);
  box-shadow: 0 -4px 30px rgba(0, 0, 0, 0.8), 0 0 20px rgba(0, 240, 255, 0.2);
  padding: 8px;
  gap: 8px;
}
.tab-btn {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 12px;
  border-radius: var(--radius-sm);
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(0, 240, 255, 0.2);
  color: rgba(255, 255, 255, 0.6);
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: var(--transition);
}
.tab-btn span[data-icon] { font-size: 20px; }
.tab-btn.active {
  background: linear-gradient(135deg, rgba(0, 240, 255, 0.2), rgba(0, 255, 136, 0.15));
  border-color: var(--primary);
  color: var(--primary-light);
  box-shadow: 0 0 20px rgba(0, 240, 255, 0.4), inset 0 0 10px rgba(0, 240, 255, 0.1);
}
.tab-btn:active { transform: scale(0.95); }

/* Tab Content */
.tab-content {
  display: none;
  position: relative;
  width: 100%;
  height: calc(100vh - 70px);
  overflow: hidden;
}
.tab-content.active {
  display: block;
}

/* Map Tab */
#mapTab { height: calc(100vh - 70px); }
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

/* Top Bar */
#topBar { 
  position: fixed; 
  top: 0; 
  left: 0; 
  right: 0; 
  z-index: 1000; 
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
  position: fixed; 
  top: 54px; 
  left: 0; 
  right: 0; 
  z-index: 999; 
  background: linear-gradient(to bottom, rgba(10, 15, 30, 0.95) 0%, rgba(10, 15, 30, 0.7) 80%, transparent 100%);
  backdrop-filter: blur(20px);
  padding: 8px 10px; 
  border-bottom: 1px solid rgba(0, 240, 255, 0.2);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}
.filter-row { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; padding: 4px 0; }
.filter-row::-webkit-scrollbar { display: none; }
.filter-chip { 
  flex-shrink: 0; 
  padding: 7px 14px; 
  border-radius: 20px; 
  font-size: 11px; 
  font-weight: 600; 
  background: rgba(255, 255, 255, 0.05); 
  border: 1px solid var(--border); 
  color: rgba(255, 255, 255, 0.6); 
  cursor: pointer; 
  transition: var(--transition); 
  white-space: nowrap; 
  user-select: none; 
  display: flex; 
  align-items: center; 
  gap: 6px; 
}
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

/* FAB - Oil Drop */
.fab { 
  position: fixed; 
  bottom: 90px; 
  right: 14px; 
  z-index: 1001; 
  width: 64px; 
  height: 64px; 
  border: none; 
  background: transparent; 
  cursor: pointer; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  transition: var(--transition); 
}
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
.timeline-panel { 
  position: fixed; 
  bottom: 70px; 
  left: 0; 
  right: 0; 
  z-index: 999; 
  height: 70px; 
  background: var(--surface); 
  backdrop-filter: blur(20px); 
  border-top: 1px solid var(--border); 
  padding: 10px; 
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.3); 
}
#timelineCanvas { width: 100%; height: 50px; display: block; }

/* Stats & Rating Tabs */
.stats-container, .rating-container {
  position: relative;
  width: 100%;
  height: 100%;
  overflow-y: auto;
  padding: 60px 16px 80px;
  background: rgba(10, 15, 30, 0.5);
}

/* Modal */
.modal { position: fixed; inset: 0; z-index: 3000; display: none; align-items: center; justify-content: center; padding: 20px; }
.modal.show { display: flex; }
.modal-backdrop { position: absolute; inset: 0; background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(8px); }
.modal-content { 
  position: relative; 
  background: var(--surface); 
  border-radius: var(--radius); 
  max-width: 420px; 
  width: 100%; 
  max-height: 90vh; 
  overflow: hidden; 
  box-shadow: 0 8px 40px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 240, 255, 0.3); 
  border: 1px solid var(--border); 
  animation: modalIn 0.4s cubic-bezier(0.4, 0, 0.2, 1); 
}
@keyframes modalIn { from { opacity: 0; transform: scale(0.9) translateY(30px); } to { opacity: 1; transform: scale(1) translateY(0); } }
.modal-header { padding: 20px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; }
.modal-header h3 { font-size: 18px; font-weight: 800; display: flex; align-items: center; gap: 10px; }
.close-btn { background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border); color: rgba(255, 255, 255, 0.6); font-size: 20px; cursor: pointer; padding: 0; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 50%; transition: var(--transition); }
.close-btn:hover { background: rgba(255, 255, 255, 0.1); transform: rotate(90deg); }
.modal-body { padding: 20px; max-height: calc(90vh - 140px); overflow-y: auto; }
.modal-footer { padding: 20px; border-top: 1px solid var(--border); display: flex; gap: 12px; }
.form-group { margin-bottom: 16px; }
.form-group label { display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.7); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
.form-group input, .form-group textarea, .form-group select { width: 100%; padding: 12px 14px; border-radius: var(--radius-sm); border: 1px solid var(--border); background: rgba(255, 255, 255, 0.05); color: var(--text); font-size: 14px; font-family: inherit; outline: none; transition: var(--transition); }
.form-group input:focus, .form-group textarea:focus, .form-group select:focus { border-color: var(--primary); background: rgba(255, 255, 255, 0.08); box-shadow: 0 0 0 3px rgba(0, 240, 255, 0.1); }
.form-group textarea { resize: vertical; min-height: 90px; }
.form-row { display: flex; gap: 12px; }
.form-row .form-group { flex: 1; }
.gps-btn { margin-left: auto; font-size: 11px; color: var(--primary); cursor: pointer; font-weight: 600; display: flex; align-items: center; gap: 4px; padding: 4px 8px; border-radius: 6px; background: rgba(0, 240, 255, 0.1); transition: var(--transition); }
.gps-btn:hover { background: rgba(0, 240, 255, 0.2); }
.btn { flex: 1; padding: 12px 20px; border-radius: var(--radius-sm); border: none; font-size: 14px; font-weight: 700; cursor: pointer; transition: var(--transition); display: flex; align-items: center; justify-content: center; gap: 8px; }
.btn-primary { background: var(--primary); color: #fff; }
.btn-primary:hover { background: var(--primary-dark); box-shadow: 0 4px 12px rgba(0, 240, 255, 0.4); }
.btn-primary:active { transform: scale(0.97); }
.btn-secondary { background: rgba(255, 255, 255, 0.1); color: rgba(255, 255, 255, 0.8); }
.btn-secondary:hover { background: rgba(255, 255, 255, 0.15); }
.btn-secondary:active { transform: scale(0.97); }

/* Toast */
.toast { 
  position: fixed; 
  top: 80px; 
  left: 50%; 
  transform: translateX(-50%); 
  z-index: 4000; 
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
    
    recent.forEach(c => {
      const cat = c.category || '';
      if (['ЧП', 'Безопасность', 'Газоснабжение'].includes(cat)) severity += 3;
      else if (['Дороги', 'ЖКХ', 'Отопление', 'Водоснабжение и канализация'].includes(cat)) severity += 2;
      else severity += 1;
    });
    
    this.severity = Math.min(severity, 100);
    this.targetBpm = Math.min(60 + this.severity * 0.8 + count * 1.5, 150);
    
    if (this.targetBpm < 70) this.mood = 'Спокойно';
    else if (this.targetBpm < 90) this.mood = 'Умеренно';
    else if (this.targetBpm < 120) this.mood = 'Напряжённо';
    else this.mood = 'Тревожно';
    
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
    if (this.bpm < 70) return '#00ff88';
    if (this.bpm < 90) return '#ffaa00';
    if (this.bpm < 120) return '#f97316';
    return '#ff3366';
  },
  
  animate() {
    if (!this.ctx) return;
    
    const ctx = this.ctx;
    const W = this.canvas.width;
    const H = this.canvas.height;
    
    this.bpm += (this.targetBpm - this.bpm) * 0.02;
    this.time += this.bpm / 3600;
    
    const phase = (this.time % 1);
    let value = 0;
    
    if (phase < 0.1) value = Math.sin(phase / 0.1 * Math.PI) * 0.4;
    else if (phase < 0.2) value = Math.sin((phase - 0.1) / 0.1 * Math.PI) * 0.8;
    else if (phase < 0.3) value = -Math.sin((phase - 0.2) / 0.1 * Math.PI) * 0.3;
    else if (phase < 0.5) value = Math.sin((phase - 0.3) / 0.2 * Math.PI) * 0.2;
    else value = 0;
    
    value += (Math.random() - 0.5) * 0.05;
    this.history.push(value);
    if (this.history.length > 160) this.history.shift();
    
    ctx.clearRect(0, 0, W, H);
    
    const grad = ctx.createLinearGradient(0, 0, W, 0);
    grad.addColorStop(0, 'rgba(0, 240, 255, 0.05)');
    grad.addColorStop(0.5, 'rgba(0, 240, 255, 0.1)');
    grad.addColorStop(1, 'rgba(0, 240, 255, 0.05)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);
    
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
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    requestAnimationFrame(() => this.animate());
  }
};

// ═══ OIL DROP ANIMATION ═══
function animateOilDrop() {
  const drop = document.querySelector('.oil-drop');
  if (!drop || typeof anime === 'undefined') return;
  
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
  animateOilDrop();
  CityRhythm.init();
  
  const progressFill = document.getElementById('progressFill');
  const progressText = document.getElementById('progressText');
  
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
  
  await loadData();
  
  setTimeout(() => {
    const splash = document.getElementById('splash');
    if (splash) {
      splash.classList.add('hide');
      setTimeout(() => {
        splash.style.display = 'none';
        const app = document.getElementById('app');
        app.style.display = 'block';
        app.classList.add('show');
        initMap();
        initTabs();
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
      const newComplaints = Object.entries(data).map(([id, complaint]) => ({
        id,
        ...complaint
      }));
      
      newComplaints.forEach(c => state.knownComplaintIds.add(c.id));
      
      state.complaints = newComplaints;
      state.filteredComplaints = [...state.complaints];
      state.lastUpdateTime = Date.now();
      
      const total = state.complaints.length;
      const open = state.complaints.filter(c => c.status === 'open').length;
      const resolved = state.complaints.filter(c => c.status === 'resolved').length;
      
      document.getElementById('statTotal').textContent = total;
      document.getElementById('statOpen').textContent = open;
      document.getElementById('statResolved').textContent = resolved;
      
      CityRhythm.feed(state.complaints);
    }
  } catch (error) {
    console.error('Error loading data:', error);
    showToast('Ошибка загрузки данных', 'error');
  }
}

// ═══ TAB SYSTEM ═══
function initTabs() {
  const tabBtns = document.querySelectorAll('.tab-btn');
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      switchTab(tab);
    });
  });
}

function switchTab(tabName) {
  state.currentTab = tabName;
  
  // Update buttons
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tabName);
  });
  
  // Update content
  document.querySelectorAll('.tab-content').forEach(content => {
    content.classList.toggle('active', content.id === tabName + 'Tab');
  });
  
  // Load tab-specific content
  if (tabName === 'stats') {
    renderStats();
  } else if (tabName === 'rating') {
    renderUkRating();
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
    
    const newComplaints = currentComplaints.filter(c => {
      const isNew = !state.knownComplaintIds.has(c.id);
      const hasAddress = c.lat && c.lng && c.address;
      return isNew && hasAddress;
    });
    
    if (newComplaints.length > 0) {
      newComplaints.forEach(c => {
        state.knownComplaintIds.add(c.id);
        state.complaints.push(c);
      });
      
      state.filteredComplaints = [...state.complaints];
      
      newComplaints.forEach(complaint => {
        addMarkerWithAnimation(complaint);
      });
      
      const total = state.complaints.length;
      const open = state.complaints.filter(c => c.status === 'open').length;
      const resolved = state.complaints.filter(c => c.status === 'resolved').length;
      
      document.getElementById('totalNum').textContent = total;
      document.getElementById('openNum').textContent = open;
      document.getElementById('resolvedNum').textContent = resolved;
      
      showToast(\`Новая жалоба: \${newComplaints[0].category}\`, 'success');
      CityRhythm.feed(state.complaints);
    }
    
    currentComplaints.forEach(newComplaint => {
      const existing = state.complaints.find(c => c.id === newComplaint.id);
      if (existing && existing.status !== newComplaint.status) {
        existing.status = newComplaint.status;
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
  
  const icon = L.divIcon({
    html: \`<div class="marker-new" style="width:40px;height:40px;border-radius:50%;background:\${category.color};display:flex;align-items:center;justify-content:center;font-size:18px;border:3px solid rgba(255,255,255,0.5);box-shadow:0 0 20px \${category.color}, 0 0 40px \${category.color}88;animation: markerPulse 1s ease-out;">\${category.emoji}</div>\`,
    className: 'marker-container-new',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
    popupAnchor: [0, -20]
  });
  
  const marker = L.marker([complaint.lat, complaint.lng], { icon });
  
  const popupContent = \`
    <div class="popup-header">
      <span class="popup-icon">\${category.emoji}</span>
      <span class="popup-title">\${complaint.category}</span>
      <span class="popup-new-badge">НОВОЕ</span>
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
  state.realtimeInterval = setInterval(() => {
    checkForNewComplaints();
  }, 3000);
  
  console.log('✅ Real-time updates started (3s interval)');
}

// ═══ MAP INITIALIZATION ═══
function initMap() {
  state.map = L.map('map', {
    center: CONFIG.center,
    zoom: CONFIG.zoom,
    zoomControl: false
  });
  
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19,
    className: 'hi-tech-tiles'
  }).addTo(state.map);
  
  const style = document.createElement('style');
  style.textContent = \`
    .hi-tech-tiles { 
      filter: brightness(0.6) contrast(1.2) saturate(0.8) invert(0.05) hue-rotate(180deg);
      opacity: 0.9;
    }
    .leaflet-container { background: #0a0a0f !important; }
  \`;
  document.head.appendChild(style);
  
  state.cluster = L.markerClusterGroup({
    maxClusterRadius: 50,
    spiderfyOnMaxZoom: true,
    showCoverageOnHover: false,
    zoomToBoundsOnClick: true
  });
  
  renderMarkers();
  initFilters();
  initTimeline();
  setupEventListeners();
  startRealtimeUpdates();
}

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
      html: \`<div style="width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg, \${category.color}, \${category.color}88);display:flex;align-items:center;justify-content:center;font-size:18px;border:2px solid rgba(255,255,255,0.5);box-shadow:0 0 15px \${category.color}99, 0 4px 12px rgba(0,0,0,0.6);position:relative;">
        \${category.emoji}
        <div style="position:absolute;inset:-2px;border-radius:50%;border:1px solid \${category.color};opacity:0.5;animation:pulse-ring 2s ease-out infinite;"></div>
      </div>\`,
      className: 'hi-tech-marker',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -20]
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
  
  document.getElementById('totalNum').textContent = total;
  document.getElementById('openNum').textContent = open;
  document.getElementById('resolvedNum').textContent = resolved;
}

// ═══ FILTERS ═══
function initFilters() {
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
    
    ctx.fillStyle = 'rgba(0, 240, 255, 0.6)';
    ctx.fillRect(x, y, barWidth, height);
  });
}

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

  const cats = {};
  c.forEach(x => { const cat = x.category || 'Прочее'; cats[cat] = (cats[cat] || 0) + 1; });
  const sortedCats = Object.entries(cats).sort((a, b) => b[1] - a[1]);

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

  let html = \`
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:18px">
      <div style="background:rgba(0,240,255,0.15);border-radius:12px;padding:14px;text-align:center;border:1px solid rgba(0,240,255,0.3);box-shadow:0 0 20px rgba(0,240,255,0.2)">
        <div style="font-size:28px;font-weight:900;color:#00f0ff;text-shadow:0 0 10px rgba(0,240,255,0.5)">\${total}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Всего</div>
      </div>
      <div style="background:rgba(255,51,102,0.15);border-radius:12px;padding:14px;text-align:center;border:1px solid rgba(255,51,102,0.3);box-shadow:0 0 20px rgba(255,51,102,0.2)">
        <div style="font-size:28px;font-weight:900;color:#ff3366;text-shadow:0 0 10px rgba(255,51,102,0.5)">\${open}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Открыто</div>
      </div>
      <div style="background:rgba(255,170,0,0.15);border-radius:12px;padding:14px;text-align:center;border:1px solid rgba(255,170,0,0.3);box-shadow:0 0 20px rgba(255,170,0,0.2)">
        <div style="font-size:28px;font-weight:900;color:#ffaa00;text-shadow:0 0 10px rgba(255,170,0,0.5)">\${inProgress + pending}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">В работе</div>
      </div>
      <div style="background:rgba(0,255,136,0.15);border-radius:12px;padding:14px;text-align:center;border:1px solid rgba(0,255,136,0.3);box-shadow:0 0 20px rgba(0,255,136,0.2)">
        <div style="font-size:28px;font-weight:900;color:#00ff88;text-shadow:0 0 10px rgba(0,255,136,0.5)">\${resolved}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Решено</div>
      </div>
    </div>
    <div style="font-size:13px;font-weight:700;margin-bottom:10px;color:rgba(255,255,255,0.8)">📊 По категориям</div>
  \`;

  sortedCats.forEach(([cat, count]) => {
    const pct = Math.round(count / total * 100);
    const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
    html += \`
      <div style="margin-bottom:8px">
        <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:3px">
          <span>\${cfg.emoji} \${cat}</span><span style="color:rgba(255,255,255,0.5)">\${count} (\${pct}%)</span>
        </div>
        <div style="height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:\${pct}%;background:\${cfg.color};border-radius:3px;transition:width 0.5s;box-shadow:0 0 10px \${cfg.color}88"></div>
        </div>
      </div>\`;
  });

  html += \`<div style="font-size:13px;font-weight:700;margin:18px 0 10px;color:rgba(255,255,255,0.8)">📈 Активность (7 дней)</div>\`;
  Object.entries(days).forEach(([day, count]) => {
    const pct = Math.round(count / maxDay * 100);
    html += \`
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
        <span style="font-size:11px;min-width:40px;color:rgba(255,255,255,0.5)">\${day}</span>
        <div style="flex:1;height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:\${pct}%;background:linear-gradient(90deg,#00f0ff,#00ff88);border-radius:3px;box-shadow:0 0 10px rgba(0,240,255,0.5)"></div>
        </div>
        <span style="font-size:11px;min-width:20px;text-align:right;color:rgba(255,255,255,0.5)">\${count}</span>
      </div>\`;
  });

  el.innerHTML = html;
}

// ═══ UK RATING RENDERING ═══
const UK_CACHE_KEY = 'uk_rating_cache';
const UK_CACHE_TTL = 86400000;

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
    let uk = c.uk || c.management_company || '';
    if (!uk && c.address) {
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

  const result = Object.entries(uks).map(([name, data]) => {
    const resolvedPct = data.total > 0 ? data.resolved / data.total : 0;
    const rating = Math.max(1, Math.min(5, Math.round(resolvedPct * 5 + (data.total < 3 ? 1 : 0))));
    return { name, ...data, resolvedPct, rating };
  }).sort((a, b) => b.rating - a.rating || a.open - b.open);

  setUkRatingCache(result);
  return result;
}

function renderUkRating() {
  const el = document.getElementById('ratingContent');
  if (!el) return;

  const ratings = computeUkRating();
  if (!ratings.length) {
    el.innerHTML = '<div style="text-align:center;padding:40px;color:rgba(255,255,255,0.4)">Нет данных для рейтинга</div>';
    return;
  }

  let html = \`<div style="font-size:11px;color:rgba(255,255,255,0.4);margin-bottom:14px">Обновляется раз в сутки • На основе \${state.complaints.length} обращений</div>\`;

  ratings.forEach((uk, i) => {
    const stars = '★'.repeat(uk.rating) + '☆'.repeat(5 - uk.rating);
    const starColor = uk.rating >= 4 ? '#00ff88' : uk.rating >= 3 ? '#ffaa00' : '#ff3366';
    const topCats = Object.entries(uk.categories).sort((a, b) => b[1] - a[1]).slice(0, 3);

    html += \`
      <div style="background:rgba(255,255,255,0.04);border:1px solid rgba(0,240,255,0.2);border-radius:12px;padding:14px;margin-bottom:10px;box-shadow:0 0 20px rgba(0,240,255,0.1)">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="font-size:16px;font-weight:900;color:rgba(255,255,255,0.3);min-width:24px">#\${i + 1}</span>
            <span style="font-size:14px;font-weight:700">\${uk.name}</span>
          </div>
          <span style="font-size:14px;color:\${starColor};letter-spacing:2px;text-shadow:0 0 10px \${starColor}88">\${stars}</span>
        </div>
        <div style="display:flex;gap:12px;margin-bottom:8px">
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Всего: <b style="color:#00f0ff">\${uk.total}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Решено: <b style="color:#00ff88">\${uk.resolved}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Открыто: <b style="color:#ff3366">\${uk.open}</b></span>
        </div>
        <div style="height:4px;background:rgba(255,255,255,0.08);border-radius:2px;overflow:hidden;margin-bottom:8px">
          <div style="height:100%;width:\${Math.round(uk.resolvedPct * 100)}%;background:linear-gradient(90deg,#00ff88,#00f0ff);border-radius:2px;box-shadow:0 0 10px rgba(0,255,136,0.5)"></div>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          \${topCats.map(([cat, cnt]) => {
            const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
            return \`<span style="font-size:10px;padding:3px 8px;border-radius:10px;background:\${cfg.color}22;color:\${cfg.color};border:1px solid \${cfg.color}44">\${cfg.emoji} \${cat}: \${cnt}</span>\`;
          }).join('')}
        </div>
      </div>\`;
  });

  el.innerHTML = html;
}

// ═══ EVENT LISTENERS ═══
function setupEventListeners() {
  const fabBtn = document.getElementById('fabBtn');
  if (fabBtn) {
    fabBtn.onclick = () => {
      const modal = document.getElementById('complaintModal');
      if (modal) modal.classList.add('show');
      populateCategorySelect();
    };
  }
  
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

function populateCategorySelect() {
  const select = document.getElementById('formCategory');
  if (!select) return;
  
  select.innerHTML = '<option value="">Выберите категорию</option>';
  Object.entries(CONFIG.categories).forEach(([name, cat]) => {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = \`\${cat.emoji} \${name}\`;
    select.appendChild(option);
  });
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
  
  fetch(CONFIG.firebase + '/complaints.json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(complaint)
  })
  .then(response => response.json())
  .then(data => {
    showToast('Жалоба отправлена!', 'success');
    closeModal();
    loadData().then(() => renderMarkers());
  })
  .catch(error => {
    console.error('Error submitting complaint:', error);
    showToast('Ошибка отправки жалобы', 'error');
  });
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

function closeModal() {
  const modal = document.getElementById('complaintModal');
  if (modal) modal.classList.remove('show');
}

// ═══ INITIALIZATION ═══
document.addEventListener('DOMContentLoaded', () => {
  showSplash();
  
  // Initialize Iconify icons
  if (typeof Iconify !== 'undefined') {
    Iconify.scan();
  }
});

<\/script>
</body>
</html>
`;

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
<!-- Leaflet JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"><\/script>
<script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"><\/script>
<!-- Anime.js для продвинутых анимаций -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/animejs/3.2.2/anime.min.js"><\/script>
<!-- Particles.js для фона -->
<script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"><\/script>
<!-- Iconify для иконок -->
<script src="https://code.iconify.design/3/3.1.0/iconify.min.js"><\/script>
<!-- Fonts: Rajdhani (display) + Space Grotesk (body) -->
<link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@300;400;500;600;700&family=Space+Grotesk:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
<!-- Aurora Background (Северное сияние) -->
<canvas id="auroraCanvas"></canvas>

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
  
  <!-- City Pulse Overlay -->
  <canvas id="cityPulseOverlay"></canvas>
  
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
        <button class="btn btn-location" id="shareLocationBtn" onclick="shareLocationAndMark()">
          <span data-icon="mdi:map-marker-radius"></span> Поделиться геолокацией
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
    'ЖКХ': { emoji: '🏘️', color: '#14b8a6', icon: 'mdi:home-city', dangerLevel: 2 },
    'Дороги': { emoji: '🛣️', color: '#ef4444', icon: 'mdi:road', dangerLevel: 3 },
    'Благоустройство': { emoji: '🌳', color: '#10b981', icon: 'mdi:tree', dangerLevel: 1 },
    'Транспорт': { emoji: '🚌', color: '#3b82f6', icon: 'mdi:bus', dangerLevel: 2 },
    'Экология': { emoji: '♻️', color: '#22c55e', icon: 'mdi:recycle', dangerLevel: 2 },
    'Безопасность': { emoji: '🚨', color: '#dc2626', icon: 'mdi:shield-alert', dangerLevel: 5 },
    'Освещение': { emoji: '💡', color: '#f59e0b', icon: 'mdi:lightbulb', dangerLevel: 2 },
    'Снег/Наледь': { emoji: '❄️', color: '#06b6d4', icon: 'mdi:snowflake', dangerLevel: 3 },
    'Медицина': { emoji: '🏥', color: '#ec4899', icon: 'mdi:hospital-box', dangerLevel: 4 },
    'Образование': { emoji: '🏫', color: '#8b5cf6', icon: 'mdi:school', dangerLevel: 2 },
    'Парковки': { emoji: '🅿️', color: '#6366f1', icon: 'mdi:parking', dangerLevel: 1 },
    'ЧП': { emoji: '⚠️', color: '#dc2626', icon: 'mdi:alert', dangerLevel: 5 },
    'Газоснабжение': { emoji: '🔥', color: '#dc2626', icon: 'mdi:fire', dangerLevel: 5 },
    'Отопление': { emoji: '🔥', color: '#f97316', icon: 'mdi:radiator', dangerLevel: 4 },
    'Водоснабжение и канализация': { emoji: '💧', color: '#3b82f6', icon: 'mdi:water', dangerLevel: 3 },
    'Прочее': { emoji: '❔', color: '#64748b', icon: 'mdi:help-circle', dangerLevel: 1 }
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
const styles = \`
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  /* Нижневартовск: природные цвета северного города */
  --bg: #f5f7fa; --surface: rgba(255, 255, 255, 0.98); --text: #1e293b;
  --primary: #1e3a5f; --primary-light: #2d4a6b; --primary-dark: #0f2540;
  --success: #2d5016; --success-light: #4a7c3a; --danger: #dc2626; --warning: #d97706; --info: #0369a1;
  --gold: #d4af37; --gold-light: #f4c430; --snow: #ffffff; --taiga: #2d5016;
  --border: rgba(30, 58, 95, 0.15); --shadow: 0 2px 12px rgba(0, 0, 0, 0.08), 0 1px 4px rgba(0, 0, 0, 0.04);
  --radius: 12px; --radius-sm: 8px; --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  --accent-blue: #1e40af; --accent-green: #166534; --accent-gold: #d4af37;
}
body { font-family: 'Space Grotesk', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); overflow: hidden; line-height: 1.6; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
h1, h2, h3, .tb-title, .splash-title, .modal-header h3 { font-family: 'Rajdhani', sans-serif; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }

/* Aurora Canvas (Северное сияние) */
#auroraCanvas { position: fixed; inset: 0; z-index: 0; }

/* Splash Screen */
#splash { position: fixed; inset: 0; z-index: 9999; background: linear-gradient(135deg, #f5f7fa 0%, #e2e8f0 50%, #cbd5e1 100%); display: flex; align-items: center; justify-content: center; transition: opacity 0.6s, transform 0.6s; }
#splash.hide { opacity: 0; transform: scale(1.05); pointer-events: none; }
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
.splash-title { font-size: 32px; font-weight: 900; background: linear-gradient(135deg, var(--primary), var(--primary-light), var(--accent-gold)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 8px; animation: titleSlide 0.8s ease 0.3s both; display: flex; align-items: center; justify-content: center; gap: 12px; }
.title-icon { font-size: 36px; color: var(--primary); animation: iconSpin 3s ease-in-out infinite; }
@keyframes iconSpin { 0%, 100% { transform: rotate(0deg); } 50% { transform: rotate(10deg); } }
@keyframes titleSlide { from { opacity: 0; transform: translateX(-30px); } to { opacity: 1; transform: translateX(0); } }
.splash-subtitle { font-size: 11px; letter-spacing: 4px; color: rgba(30, 58, 95, 0.6); text-transform: uppercase; font-weight: 700; margin-bottom: 24px; animation: fadeIn 0.8s ease 0.5s both; }
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
.stat-card { text-align: center; background: rgba(255, 255, 255, 0.9); border-radius: var(--radius-sm); padding: 12px; min-width: 80px; box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1); backdrop-filter: blur(10px); border: 1px solid var(--border); transition: var(--transition); }
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15); }
.stat-icon { display: block; font-size: 24px; margin-bottom: 6px; opacity: 0.8; }
.stat-num { display: block; font-size: 24px; font-weight: 900; color: var(--primary); line-height: 1; }
.stat-label { display: block; font-size: 8px; color: rgba(30, 58, 95, 0.6); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px; font-weight: 600; }

/* Progress */
.splash-progress { animation: fadeIn 0.8s ease 1.1s both; }
.progress-bar { position: relative; width: 220px; height: 6px; background: rgba(30, 58, 95, 0.1); border-radius: 3px; margin: 0 auto 10px; overflow: hidden; }
.progress-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--primary), var(--primary-light)); border-radius: 3px; transition: width 0.3s; position: relative; z-index: 1; }
.progress-text { font-size: 10px; color: rgba(30, 58, 95, 0.6); font-weight: 500; }

/* Main App */
#app { position: relative; width: 100%; height: 100vh; }
#map { position: absolute; inset: 0; z-index: 1; background: #f5f7fa; }
#map.leaflet-container { background: #f5f7fa !important; }

/* City Pulse Overlay */
#cityPulseOverlay {
  position: absolute;
  inset: 0;
  z-index: 500;
  pointer-events: none;
  mix-blend-mode: screen;
  opacity: 0.8;
}

/* Modern map tile overlay (Nizhnevartovsk style) */
#map::before {
  content: '';
  position: absolute;
  inset: 0;
  background: 
    linear-gradient(0deg, transparent 0%, rgba(30, 58, 95, 0.02) 50%, transparent 100%);
  pointer-events: none;
  z-index: 1000;
}

/* Marker pulse animation (modern style) */
@keyframes markerPulse {
  0% { transform: scale(0); opacity: 0; box-shadow: 0 0 0 0 rgba(30, 58, 95, 0.4); }
  50% { transform: scale(1.15); opacity: 1; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2), 0 0 0 8px rgba(30, 58, 95, 0.1); }
  100% { transform: scale(1); opacity: 1; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15); }
}

.marker-container-new { animation: none !important; }
.popup-new-badge {
  display: inline-block;
  padding: 2px 8px;
  background: linear-gradient(135deg, var(--accent-gold), #f4c430);
  color: #1e293b;
  font-size: 9px;
  font-weight: 900;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 1px;
  box-shadow: 0 2px 8px rgba(212, 175, 55, 0.3);
}

@keyframes pulse-ring {
  0% { transform: scale(1); opacity: 0.5; }
  100% { transform: scale(1.5); opacity: 0; }
}

/* Modern marker style */
.hi-tech-marker {
  filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.15));
}

/* Cluster markers modern style */
.marker-cluster {
  background: linear-gradient(135deg, var(--primary), var(--primary-light)) !important;
  border: 2px solid white !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2) !important;
  color: white !important;
  font-weight: 700 !important;
}

/* Top Bar */
#topBar { 
  position: fixed; top: 0; left: 0; right: 0; z-index: 1000; 
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.98) 0%, rgba(255, 255, 255, 0.95) 100%);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--border);
  padding: 10px 14px; 
  display: flex; 
  align-items: center; 
  justify-content: space-between; 
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
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
  background: linear-gradient(to bottom, rgba(255, 255, 255, 0.98) 0%, rgba(255, 255, 255, 0.9) 80%, transparent 100%);
  backdrop-filter: blur(20px);
  padding: 8px 10px; 
  border-bottom: 1px solid var(--border);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}
.filter-row { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; padding: 4px 0; }
.filter-row::-webkit-scrollbar { display: none; }
.filter-chip { flex-shrink: 0; padding: 7px 14px; border-radius: 20px; font-size: 11px; font-weight: 600; background: rgba(30, 58, 95, 0.08); border: 1px solid var(--border); color: var(--text); cursor: pointer; transition: var(--transition); white-space: nowrap; user-select: none; display: flex; align-items: center; gap: 6px; }
.filter-chip:active { transform: scale(0.95); }
.filter-chip.active { 
  background: linear-gradient(135deg, var(--primary), var(--primary-light)); 
  color: white; 
  border-color: var(--primary); 
  box-shadow: 0 2px 8px rgba(30, 58, 95, 0.3);
  font-weight: 700;
}
.filter-chip.status-open.active { background: var(--danger); border-color: var(--danger); }
.filter-chip.status-pending.active { background: var(--warning); border-color: var(--warning); color: #000; }
.filter-chip.status-resolved.active { background: var(--success); border-color: var(--success); }

/* Action Buttons */
.action-btn { 
  position: fixed; z-index: 1001; width: 50px; height: 50px; border-radius: var(--radius); 
  background: rgba(255, 255, 255, 0.95); 
  backdrop-filter: blur(20px); 
  border: 1px solid var(--border); 
  color: var(--primary); 
  font-size: 24px; 
  cursor: pointer; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1); 
  transition: var(--transition);
}
.action-btn:active { transform: scale(0.95); }
.action-btn:hover { 
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  border-color: var(--primary);
  color: var(--primary-dark);
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
  background: rgba(255, 255, 255, 0.98) !important; 
  color: var(--text) !important; 
  border: 1px solid var(--border) !important; 
  border-radius: var(--radius) !important; 
  backdrop-filter: blur(20px) !important; 
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12) !important;
  position: relative;
}
.leaflet-popup-tip { background: rgba(255, 255, 255, 0.98) !important; border: 1px solid var(--border) !important; }
.leaflet-popup-content { margin: 14px !important; min-width: 220px; }
.popup-header { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.popup-icon { font-size: 22px; }
.popup-title { font-size: 15px; font-weight: 700; flex: 1; }
.popup-badge { display: inline-block; padding: 4px 10px; border-radius: 12px; font-size: 10px; font-weight: 700; color: #fff; }
.popup-desc { font-size: 13px; color: var(--text); line-height: 1.5; margin-bottom: 10px; }
.popup-meta { font-size: 11px; color: rgba(30, 41, 59, 0.7); margin-bottom: 6px; display: flex; align-items: center; gap: 6px; }
.popup-actions { display: flex; gap: 8px; margin-top: 10px; flex-wrap: wrap; }
.popup-btn { flex: 1; min-width: 100px; padding: 8px 12px; border-radius: var(--radius-sm); border: 1px solid var(--border); background: rgba(30, 58, 95, 0.05); color: var(--text); font-size: 12px; font-weight: 600; cursor: pointer; transition: var(--transition); text-align: center; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 6px; }
.popup-btn:hover { background: rgba(30, 58, 95, 0.1); }
.popup-btn:hover { background: rgba(255, 255, 255, 0.1); transform: translateY(-1px); }
.popup-btn:active { transform: translateY(0) scale(0.98); }

/* AI Analysis Popup */
.ai-analysis-popup {
  position: fixed;
  top: 80px;
  left: 50%;
  transform: translateX(-50%) translateY(-20px);
  z-index: 5000;
  max-width: 90%;
  width: 380px;
  background: var(--surface);
  border-radius: var(--radius);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15), 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid var(--border);
  opacity: 0;
  transition: opacity 0.3s, transform 0.3s;
  overflow: hidden;
}
.ai-popup-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  background: linear-gradient(135deg, var(--primary), var(--primary-light));
  color: white;
  border-bottom: 1px solid var(--border);
}
.ai-popup-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 16px;
  font-weight: 700;
  font-family: 'Rajdhani', sans-serif;
}
.ai-icon {
  font-size: 20px;
}
.ai-popup-close {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s;
}
.ai-popup-close:hover {
  background: rgba(255, 255, 255, 0.3);
}
.ai-popup-content {
  padding: 20px;
  max-height: 60vh;
  overflow-y: auto;
}
.ai-popup-section {
  margin-bottom: 20px;
}
.ai-popup-section:last-child {
  margin-bottom: 0;
}
.ai-popup-label {
  font-size: 12px;
  font-weight: 700;
  color: var(--primary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
  font-family: 'Rajdhani', sans-serif;
}
.ai-popup-text {
  font-size: 14px;
  color: var(--text);
  line-height: 1.6;
  background: rgba(30, 58, 95, 0.05);
  padding: 12px;
  border-radius: var(--radius-sm);
  border-left: 3px solid var(--primary);
}
.ai-popup-recommendations {
  list-style: none;
  padding: 0;
  margin: 0;
}
.ai-popup-recommendations li {
  font-size: 13px;
  color: var(--text);
  line-height: 1.6;
  padding: 8px 0;
  padding-left: 24px;
  position: relative;
}
.ai-popup-recommendations li::before {
  content: '✓';
  position: absolute;
  left: 0;
  color: var(--success-light);
  font-weight: 700;
}
.ai-popup-footer {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
  margin-top: 16px;
}
.ai-popup-category {
  display: inline-block;
  padding: 4px 12px;
  background: var(--primary);
  color: white;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 700;
  width: fit-content;
}
.ai-popup-address {
  font-size: 12px;
  color: rgba(30, 41, 59, 0.7);
  display: flex;
  align-items: center;
  gap: 6px;
}

/* Updated marker animation */
@keyframes markerAppear {
  0% {
    transform: scale(0) rotate(-180deg);
    opacity: 0;
  }
  60% {
    transform: scale(1.15) rotate(10deg);
  }
  100% {
    transform: scale(1) rotate(0deg);
    opacity: 1;
  }
}
\`;

const styleEl = document.createElement('style');
styleEl.textContent = styles;
document.head.appendChild(styleEl);

// ═══ CITY PULSE OVERLAY — Пульс города на карте ═══
const CityPulseOverlay = {
  canvas: null,
  ctx: null,
  bpm: 60,
  targetBpm: 60,
  pulseHistory: [],
  pulseEvents: [], // События пульсации от новых жалоб
  intensity: 0, // Интенсивность пульсации (0-1)
  time: 0,
  lastComplaintTime: 0,
  
  init() {
    this.canvas = document.getElementById('cityPulseOverlay');
    if (!this.canvas) return;
    
    this.ctx = this.canvas.getContext('2d');
    this.pulseHistory = new Array(200).fill(0);
    
    // Resize handler
    const resize = () => {
      this.canvas.width = window.innerWidth;
      this.canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);
    
    this.animate();
  },
  
  // Реакция на новую жалобу
  reactToComplaint(complaint) {
    const category = CONFIG.categories[complaint.category] || CONFIG.categories['Прочее'];
    const dangerLevel = category.dangerLevel || 1;
    
    // Создаем событие пульсации
    const pulseEvent = {
      time: Date.now(),
      intensity: dangerLevel / 5, // Нормализуем к 0-1
      category: complaint.category,
      dangerLevel: dangerLevel,
      x: complaint.lng ? null : Math.random() * this.canvas.width, // Если есть координаты, используем их
      y: complaint.lat ? null : Math.random() * this.canvas.height,
      lat: complaint.lat,
      lng: complaint.lng
    };
    
    this.pulseEvents.push(pulseEvent);
    
    // Ограничиваем количество событий
    if (this.pulseEvents.length > 50) {
      this.pulseEvents.shift();
    }
    
    // Увеличиваем интенсивность пульсации
    this.intensity = Math.min(this.intensity + dangerLevel * 0.1, 1);
    
    // Обновляем целевой BPM
    this.updateBPM();
  },
  
  // Обновление BPM на основе жалоб
  updateBPM() {
    const now = Date.now();
    const recentEvents = this.pulseEvents.filter(e => now - e.time < 60000); // Последняя минута
    
    if (recentEvents.length === 0) {
      this.targetBpm = 60;
      return;
    }
    
    // Вычисляем среднюю опасность
    const avgDanger = recentEvents.reduce((sum, e) => sum + e.dangerLevel, 0) / recentEvents.length;
    
    // BPM зависит от опасности и количества событий
    this.targetBpm = Math.min(60 + avgDanger * 8 + recentEvents.length * 2, 150);
  },
  
  // Получить цвет пульса на основе BPM
  getPulseColor() {
    if (this.bpm < 70) return { r: 45, g: 212, b: 191, a: 0.3 }; // Зеленый (спокойно)
    if (this.bpm < 90) return { r: 245, g: 158, b: 11, a: 0.4 }; // Желтый (умеренно)
    if (this.bpm < 120) return { r: 249, g: 115, b: 22, a: 0.5 }; // Оранжевый (напряженно)
    return { r: 239, g: 68, b: 68, a: 0.6 }; // Красный (тревожно)
  },
  
  animate() {
    if (!this.ctx || !this.canvas) return;
    
    const ctx = this.ctx;
    const W = this.canvas.width;
    const H = this.canvas.height;
    
    // Плавное изменение BPM
    this.bpm += (this.targetBpm - this.bpm) * 0.05;
    
    // Уменьшаем интенсивность со временем
    this.intensity *= 0.98;
    
    // Очищаем canvas с прозрачностью для эффекта следа
    ctx.fillStyle = 'rgba(245, 247, 250, 0.1)';
    ctx.fillRect(0, 0, W, H);
    
    // Получаем цвет пульса
    const pulseColor = this.getPulseColor();
    
    // Рисуем основной пульс (концентрические круги от центра)
    const centerX = W / 2;
    const centerY = H / 2;
    
    // Генерируем волну пульсации
    this.time += this.bpm / 3600;
    const pulsePhase = (this.time % 1);
    
    // Основной пульс от центра карты
    const baseRadius = Math.min(W, H) * 0.1;
    const pulseRadius = baseRadius + Math.sin(pulsePhase * Math.PI * 2) * (baseRadius * this.intensity * 2);
    
    // Градиент для пульса
    const gradient = ctx.createRadialGradient(centerX, centerY, 0, centerX, centerY, pulseRadius);
    gradient.addColorStop(0, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, \${pulseColor.a})\`);
    gradient.addColorStop(0.5, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, \${pulseColor.a * 0.5})\`);
    gradient.addColorStop(1, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, 0)\`);
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(centerX, centerY, pulseRadius, 0, Math.PI * 2);
    ctx.fill();
    
    // Рисуем события пульсации от новых жалоб
    const now = Date.now();
    this.pulseEvents.forEach((event, index) => {
      const age = (now - event.time) / 1000; // Возраст в секундах
      if (age > 3) return; // Показываем только последние 3 секунды
      
      let x, y;
      
      // Если есть координаты жалобы, конвертируем их в пиксели
      if (event.lat && event.lng && state.map) {
        const point = state.map.latLngToContainerPoint([event.lat, event.lng]);
        x = point.x;
        y = point.y;
      } else {
        // Иначе используем случайные координаты
        x = event.x || centerX;
        y = event.y || centerY;
      }
      
      // Интенсивность уменьшается со временем
      const fade = 1 - (age / 3);
      const radius = 30 + age * 20; // Радиус увеличивается со временем
      
      // Градиент для события
      const eventGradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
      const alpha = event.intensity * fade * 0.6;
      eventGradient.addColorStop(0, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, \${alpha})\`);
      eventGradient.addColorStop(0.5, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, \${alpha * 0.5})\`);
      eventGradient.addColorStop(1, \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, 0)\`);
      
      ctx.fillStyle = eventGradient;
      ctx.beginPath();
      ctx.arc(x, y, radius, 0, Math.PI * 2);
      ctx.fill();
      
      // Удаляем старые события
      if (age > 3) {
        this.pulseEvents.splice(index, 1);
      }
    });
    
    // Рисуем волновую форму пульса внизу экрана (опционально)
    this.drawWaveform(ctx, W, H);
    
    requestAnimationFrame(() => this.animate());
  },
  
  // Рисует волновую форму пульса
  drawWaveform(ctx, W, H) {
    const waveHeight = 60;
    const waveY = H - waveHeight;
    
    // Генерируем значение волны
    const phase = (this.time % 1);
    let value = 0;
    
    // Паттерн пульсации
    if (phase < 0.1) {
      value = Math.sin(phase / 0.1 * Math.PI) * 0.6;
    } else if (phase < 0.2) {
      value = Math.sin((phase - 0.1) / 0.1 * Math.PI) * 1.0;
    } else if (phase < 0.3) {
      value = -Math.sin((phase - 0.2) / 0.1 * Math.PI) * 0.4;
    } else {
      value = 0;
    }
    
    // Добавляем шум для органичности
    value += (Math.random() - 0.5) * 0.1;
    
    this.pulseHistory.push(value);
    if (this.pulseHistory.length > 200) this.pulseHistory.shift();
    
    // Рисуем волну
    const pulseColor = this.getPulseColor();
    ctx.strokeStyle = \`rgba(\${pulseColor.r}, \${pulseColor.g}, \${pulseColor.b}, 0.6)\`;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    
    ctx.beginPath();
    const step = W / 200;
    
    for (let i = 0; i < this.pulseHistory.length; i++) {
      const x = i * step;
      const y = waveY + waveHeight / 2 - this.pulseHistory[i] * (waveHeight / 2 - 10);
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    
    ctx.stroke();
  }
};

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
    
    // Calculate severity based on categories and danger levels
    recent.forEach(c => {
      const cat = c.category || '';
      const categoryInfo = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
      const dangerLevel = categoryInfo.dangerLevel || 1;
      severity += dangerLevel;
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
      grad.addColorStop(0, \`rgba(0, 240, 255, \${alpha})\`);
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
      throw new Error(\`HTTP \${response.status}: \${response.statusText}\`);
    }
    
    const data = await response.json();
    return { success: true, data, source: source.name };
  } catch (error) {
    console.warn(\`[\${source.name}] Ошибка загрузки:\`, error.message);
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
      console.log(\`[Cache] Загружено \${cacheData.complaints.length} жалоб из кэша (возраст: \${Math.round(cacheAge / 1000)}с)\`);
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
      id: complaint.id || \`item-\${index}\`,
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
    statusEl.textContent = \`\${statusInfo.icon} \${statusInfo.text}\${source ? \` (\${source})\` : ''}\`;
    statusEl.style.color = statusInfo.color;
  }
  
  console.log(\`[Status] \${status}\${source ? \` via \${source}\` : ''}\`);
}

// Основная функция загрузки данных с fallback
async function loadData() {
  updateConnectionStatus('checking');
  
  // Попытка загрузки из всех источников по приоритету
  let loadedComplaints = null;
  let loadedSource = null;
  
  for (const source of CONFIG.dataSources.sort((a, b) => a.priority - b.priority)) {
    console.log(\`[Load] Пробуем источник: \${source.name} (\${source.url})\`);
    
    const result = await fetchFromSource(source);
    
    if (result.success && result.data) {
      loadedComplaints = processComplaintsData(result.data, result.source);
      
      if (loadedComplaints && loadedComplaints.length > 0) {
        loadedSource = result.source;
        console.log(\`[Load] ✓ Успешно загружено \${loadedComplaints.length} жалоб из \${result.source}\`);
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
    
    // Обновляем пульс города
    if (CityPulseOverlay.canvas) {
      CityPulseOverlay.updateBPM();
      // Реагируем на все новые жалобы
      state.complaints.forEach(complaint => {
        const complaintTime = new Date(complaint.created_at || complaint.date || 0).getTime();
        if (complaintTime > CityPulseOverlay.lastComplaintTime) {
          CityPulseOverlay.reactToComplaint(complaint);
        }
      });
      CityPulseOverlay.lastComplaintTime = Date.now();
    }
    
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
      
      // Animate new markers and trigger pulse reactions
      newComplaints.forEach(complaint => {
        addMarkerWithAnimation(complaint);
        // Реакция пульса на новую жалобу
        if (CityPulseOverlay.canvas) {
          CityPulseOverlay.reactToComplaint(complaint);
        }
      });
      
      // Update stats
      const total = state.complaints.length;
      const open = state.complaints.filter(c => c.status === 'open').length;
      const resolved = state.complaints.filter(c => c.status === 'resolved').length;
      
      document.getElementById('totalNum').textContent = total;
      document.getElementById('openNum').textContent = open;
      document.getElementById('resolvedNum').textContent = resolved;
      
      // Show notification
      showToast(\`Новая жалоба: \${newComplaints[0].category}\`, 'success');
      
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

// ═══ AI ANALYSIS ═══
async function getAIAnalysis(complaint) {
  try {
    const text = complaint.text || complaint.summary || complaint.description || '';
    if (!text) return null;
    
    // Try to get analysis from backend API
    const apiUrl = 'https://anthropic-proxy.uiredepositionherzo.workers.dev/ai/proxy/analyze';
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: text,
        provider: 'zai',
        model: 'haiku',
        context: 'Нижневартовск'
      }),
      signal: AbortSignal.timeout(10000)
    });
    
    if (!response.ok) return null;
    
    const data = await response.json();
    
    // Generate recommendations based on analysis and Nizhnevartovsk context
    const recommendations = generateRecommendations(complaint.category, data.summary || text);
    
    return {
      analysis: data.summary || text.substring(0, 200),
      recommendations: recommendations,
      category: data.category || complaint.category
    };
  } catch (error) {
    console.error('AI analysis error:', error);
    // Fallback: generate basic recommendations
    return {
      analysis: (complaint.text || complaint.summary || '').substring(0, 200),
      recommendations: generateRecommendations(complaint.category, complaint.text || ''),
      category: complaint.category
    };
  }
}

function generateRecommendations(category, text) {
  const recommendations = [];
  const lowerText = (text || '').toLowerCase();
  
  // Category-specific recommendations for Nizhnevartovsk
  if (category === 'Дороги' || lowerText.includes('дорог') || lowerText.includes('яма')) {
    recommendations.push('Обратитесь в МКУ "Дорожное хозяйство" по тел. (3466) 41-00-00');
    recommendations.push('Учитывая климат Нижневартовска, ямы часто появляются из-за перепадов температур. Рекомендуется оперативный ремонт до наступления морозов.');
    recommendations.push('Проверьте наличие аналогичных проблем на соседних участках для комплексного ремонта.');
  } else if (category === 'ЖКХ' || lowerText.includes('отопл') || lowerText.includes('вод')) {
    recommendations.push('Свяжитесь с управляющей компанией или МУП "Теплоэнерго" по тел. (3466) 25-00-00');
    recommendations.push('В условиях северного климата проблемы с отоплением критичны. При аварии звоните в аварийную службу 112.');
    recommendations.push('Документируйте проблему фотографиями для ускорения решения вопроса.');
  } else if (category === 'Освещение' || lowerText.includes('свет') || lowerText.includes('фонар')) {
    recommendations.push('Сообщите в МКУ "Городское хозяйство" по тел. (3466) 41-00-00');
    recommendations.push('Учитывая полярную ночь в регионе, освещение критично для безопасности. Проблема будет рассмотрена в приоритетном порядке.');
  } else if (category === 'Снег/Наледь' || lowerText.includes('снег') || lowerText.includes('лед')) {
    recommendations.push('Обратитесь в МКУ "Дорожное хозяйство" для уборки снега и наледи');
    recommendations.push('В зимний период уборка снега в Нижневартовске проводится регулярно. Если проблема не решена в течение суток, обратитесь повторно.');
  } else if (category === 'Экология' || lowerText.includes('экологи') || lowerText.includes('загрязн')) {
    recommendations.push('Сообщите в Департамент экологии и природопользования ХМАО-Югры');
    recommendations.push('Учитывая нефтедобывающую промышленность региона, экологические проблемы требуют особого внимания.');
  } else {
    recommendations.push('Обратитесь в единую диспетчерскую службу по тел. 112 или через портал "Активный гражданин"');
    recommendations.push('Документируйте проблему фотографиями и сохраните номер обращения для отслеживания статуса.');
  }
  
  return recommendations;
}

// ═══ AI ANALYSIS POPUP ═══
function showAIAnalysisPopup(complaint, analysis) {
  // Remove existing popup if any
  const existingPopup = document.getElementById('aiAnalysisPopup');
  if (existingPopup) {
    existingPopup.remove();
  }
  
  const popup = document.createElement('div');
  popup.id = 'aiAnalysisPopup';
  popup.className = 'ai-analysis-popup';
  popup.innerHTML = \`
    <div class="ai-popup-header">
      <div class="ai-popup-title">
        <span data-icon="mdi:robot" class="ai-icon"></span>
        <span>Анализ ИИ</span>
      </div>
      <button class="ai-popup-close" onclick="this.closest('.ai-analysis-popup').remove()">
        <span data-icon="mdi:close"></span>
      </button>
    </div>
    <div class="ai-popup-content">
      <div class="ai-popup-section">
        <div class="ai-popup-label">Анализ проблемы:</div>
        <div class="ai-popup-text">\${analysis.analysis || 'Анализ выполняется...'}</div>
      </div>
      <div class="ai-popup-section">
        <div class="ai-popup-label">Рекомендации по решению:</div>
        <ul class="ai-popup-recommendations">
          \${analysis.recommendations.map(rec => \`<li>\${rec}</li>\`).join('')}
        </ul>
      </div>
      <div class="ai-popup-footer">
        <span class="ai-popup-category">\${complaint.category}</span>
        \${complaint.address ? \`<span class="ai-popup-address"><span data-icon="mdi:map-marker"></span> \${complaint.address}</span>\` : ''}
      </div>
    </div>
  \`;
  
  document.body.appendChild(popup);
  
  // Auto-remove after 10 seconds
  setTimeout(() => {
    if (popup.parentNode) {
      popup.style.opacity = '0';
      popup.style.transform = 'translateY(-20px)';
      setTimeout(() => popup.remove(), 300);
    }
  }, 10000);
  
  // Animate in
  setTimeout(() => {
    popup.style.opacity = '1';
    popup.style.transform = 'translateY(0)';
  }, 10);
}

function addMarkerWithAnimation(complaint) {
  if (!complaint.lat || !complaint.lng) return;
  
  const category = CONFIG.categories[complaint.category] || CONFIG.categories['Прочее'];
  
  // Create animated marker icon with modern design
  const icon = L.divIcon({
    html: \`<div class="marker-new" style="width:40px;height:40px;border-radius:50%;background:\${category.color};display:flex;align-items:center;justify-content:center;font-size:18px;border:3px solid rgba(255,255,255,0.9);box-shadow:0 4px 12px rgba(0,0,0,0.2), 0 0 0 4px rgba(255,255,255,0.3);animation: markerAppear 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);">\${category.emoji}</div>\`,
    className: 'marker-container-new',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
    popupAnchor: [0, -20]
  });
  
  const marker = L.marker([complaint.lat, complaint.lng], { icon });
  
  const popupContent = \`
    <div class="popup-header">
      <span class="popup-icon">\${category.emoji}</span>
      <span class="popup-title">\${complaint.category}</span>
      <span class="popup-new-badge">НОВОЕ</span>
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
  
  // Get AI analysis and show popup
  getAIAnalysis(complaint).then(analysis => {
    if (analysis) {
      showAIAnalysisPopup(complaint, analysis);
    }
  });
  
  // Remove animation class after animation completes
  setTimeout(() => {
    const iconEl = marker._icon;
    if (iconEl) {
      const markerDiv = iconEl.querySelector('.marker-new');
      if (markerDiv) {
        markerDiv.style.animation = 'none';
        markerDiv.style.width = '36px';
        markerDiv.style.height = '36px';
        markerDiv.style.fontSize = '16px';
        markerDiv.style.borderWidth = '2px';
      }
    }
  }, 600);
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
  
  // Initialize City Pulse Overlay
  CityPulseOverlay.init();
  
  // OpenStreetMap tiles (free, no API key) + markers
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19,
    className: 'hi-tech-tiles'
  }).addTo(state.map);
  
  // Add CSS filter for modern clean look (Nizhnevartovsk style)
  const style = document.createElement('style');
  style.textContent = \`
    .hi-tech-tiles { 
      filter: brightness(1.05) contrast(1.05) saturate(1.1);
      opacity: 1;
    }
    .leaflet-container { background: #f5f7fa !important; }
  \`;
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
      html: \`<div style="width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg, \${category.color}, \${category.color}88);display:flex;align-items:center;justify-content:center;font-size:18px;border:2px solid rgba(255,255,255,0.5);box-shadow:0 0 15px \${category.color}99, 0 4px 12px rgba(0,0,0,0.6);position:relative;">
        \${category.emoji}
        <div style="position:absolute;inset:-2px;border-radius:50%;border:1px solid \${category.color};opacity:0.5;animation:pulse-ring 2s ease-out infinite;"></div>
      </div>\`,
      className: 'hi-tech-marker',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -20]
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
      chip.className = \`filter-chip date-\${key}\`;
      chip.innerHTML = \`<span data-icon="\${icon}"></span> \${label}\`;
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
        if (chip.className.includes(\`date-\${state.filters.dateRange}\`)) {
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

  let html = \`
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:18px">
      <div style="background:rgba(99,102,241,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#818cf8">\${total}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Всего</div>
      </div>
      <div style="background:rgba(239,68,68,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#ef4444">\${open}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Открыто</div>
      </div>
      <div style="background:rgba(249,115,22,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#f97316">\${inProgress + pending}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">В работе</div>
      </div>
      <div style="background:rgba(16,185,129,0.15);border-radius:12px;padding:14px;text-align:center">
        <div style="font-size:28px;font-weight:900;color:#10b981">\${resolved}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Решено</div>
      </div>
    </div>
    <div style="font-size:13px;font-weight:700;margin-bottom:10px;color:rgba(255,255,255,0.8)">📊 По категориям</div>
  \`;

  sortedCats.forEach(([cat, count]) => {
    const pct = Math.round(count / total * 100);
    const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
    html += \`
      <div style="margin-bottom:8px">
        <div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:3px">
          <span>\${cfg.emoji} \${cat}</span><span style="color:rgba(255,255,255,0.5)">\${count} (\${pct}%)</span>
        </div>
        <div style="height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:\${pct}%;background:\${cfg.color};border-radius:3px;transition:width 0.5s"></div>
        </div>
      </div>\`;
  });

  html += \`<div style="font-size:13px;font-weight:700;margin:18px 0 10px;color:rgba(255,255,255,0.8)">📈 Активность (7 дней)</div>\`;
  Object.entries(days).forEach(([day, count]) => {
    const pct = Math.round(count / maxDay * 100);
    html += \`
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
        <span style="font-size:11px;min-width:40px;color:rgba(255,255,255,0.5)">\${day}</span>
        <div style="flex:1;height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden">
          <div style="height:100%;width:\${pct}%;background:#6366f1;border-radius:3px"></div>
        </div>
        <span style="font-size:11px;min-width:20px;text-align:right;color:rgba(255,255,255,0.5)">\${count}</span>
      </div>\`;
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

  let html = \`<div style="font-size:11px;color:rgba(255,255,255,0.4);margin-bottom:14px">Обновляется раз в сутки • На основе \${state.complaints.length} обращений</div>\`;

  ratings.forEach((uk, i) => {
    const stars = '★'.repeat(uk.rating) + '☆'.repeat(5 - uk.rating);
    const starColor = uk.rating >= 4 ? '#10b981' : uk.rating >= 3 ? '#f59e0b' : '#ef4444';
    const topCats = Object.entries(uk.categories).sort((a, b) => b[1] - a[1]).slice(0, 3);

    html += \`
      <div style="background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="font-size:16px;font-weight:900;color:rgba(255,255,255,0.3);min-width:24px">#\${i + 1}</span>
            <span style="font-size:14px;font-weight:700">\${uk.name}</span>
          </div>
          <span style="font-size:14px;color:\${starColor};letter-spacing:2px">\${stars}</span>
        </div>
        <div style="display:flex;gap:12px;margin-bottom:8px">
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Всего: <b style="color:#818cf8">\${uk.total}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Решено: <b style="color:#10b981">\${uk.resolved}</b></span>
          <span style="font-size:11px;color:rgba(255,255,255,0.5)">Открыто: <b style="color:#ef4444">\${uk.open}</b></span>
        </div>
        <div style="height:4px;background:rgba(255,255,255,0.08);border-radius:2px;overflow:hidden;margin-bottom:8px">
          <div style="height:100%;width:\${Math.round(uk.resolvedPct * 100)}%;background:linear-gradient(90deg,#10b981,#6366f1);border-radius:2px"></div>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          \${topCats.map(([cat, cnt]) => {
            const cfg = CONFIG.categories[cat] || CONFIG.categories['Прочее'];
            return \`<span style="font-size:10px;padding:3px 8px;border-radius:10px;background:\${cfg.color}22;color:\${cfg.color}">\${cfg.emoji} \${cat}: \${cnt}</span>\`;
          }).join('')}
        </div>
      </div>\`;
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
          const geoUrl = \`https://nominatim.openstreetmap.org/reverse?lat=\${lat}&lon=\${lng}&format=json&addressdetails=1&accept-language=ru\`;
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
  const colors=isDark?['rgba(0,217,255,.2)','rgba(0,255,153,.18)','rgba(255,184,0,.15)','rgba(236,72,153,.12)']:
    ['rgba(0,217,255,.15)','rgba(0,255,153,.12)','rgba(255,184,0,.1)','rgba(124,58,237,.08)'];
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
--bg:#050508;--surface:rgba(10,15,30,.92);--surfaceS:rgba(10,15,30,.95);
--primary:#00d9ff;--primaryL:#4de6ff;--primaryBg:rgba(0,217,255,.15);
--accent:#ffb800;--accentBg:rgba(255,184,0,.12);
--text:#e0e7ff;--textSec:#a0a8c0;--textMuted:#64748b;
--border:rgba(0,217,255,.2);
--shadow:0 0 40px rgba(0,217,255,.4),0 0 60px rgba(0,255,153,.2),6px 6px 16px rgba(0,0,0,.5);
--shadowInset:inset 3px 3px 8px rgba(0,0,0,.4),inset 0 0 20px rgba(0,217,255,.1);
--green:#00ff99;--greenBg:rgba(0,255,153,.15);--red:#ff2d5f;--redBg:rgba(255,45,95,.15);
--orange:#ffb800;--orangeBg:rgba(255,184,0,.12);--blue:#00aaff;--blueBg:rgba(0,170,255,.12);
--purple:#a855f7;--purpleBg:rgba(168,85,247,.1);--teal:#00d9ff;--tealBg:rgba(0,217,255,.15);
--pink:#ec4899;--pinkBg:rgba(236,72,153,.1);--indigo:#6366f1;--indigoBg:rgba(99,102,241,.1);
--yellow:#ffb800;--yellowBg:rgba(255,184,0,.12);
--r:16px;--rs:10px;
}
body{font-family:'Space Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--text);
overflow-x:hidden;min-height:100vh;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;line-height:1.6}
h1,h2,h3,.hero h1{font-family:'Rajdhani',sans-serif;font-weight:700;letter-spacing:-0.02em;line-height:1.2}
#bgCanvas{position:fixed;inset:0;z-index:0;pointer-events:none}
#app{position:relative;z-index:1;max-width:480px;margin:0 auto;padding:0 10px 40px}

/* Pulse bar */
#pulse-bar{position:sticky;top:0;z-index:100;display:flex;align-items:center;gap:8px;
padding:6px 12px;background:rgba(12,18,34,.92);backdrop-filter:blur(16px);
border-bottom:1px solid var(--border);margin:0 -10px}
#pulseCanvas{flex:1;height:48px;border-radius:8px}
#pulse-info{display:flex;flex-direction:column;align-items:center;min-width:60px}
#pulse-bpm{font-size:28px;font-weight:900;color:var(--green);line-height:1;
font-variant-numeric:tabular-nums;transition:color .5s;text-shadow:0 0 15px rgba(0,255,153,.6)}
.pulse-label{font-size:7px;color:var(--textMuted);text-transform:uppercase;letter-spacing:1px}
#pulse-mood{font-size:9px;font-weight:700;color:var(--green);transition:color .5s;text-shadow:0 0 10px rgba(0,255,153,.5)}

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

/* ═══ ACCESSIBILITY IMPROVEMENTS (UI/UX Pro Max Skill) ═══ */
button:focus-visible,a:focus-visible,input:focus-visible{outline:2px solid var(--primary);outline-offset:2px;box-shadow:0 0 0 4px rgba(0,217,255,.2)}
.tab,.card,.expand-btn{min-width:44px;min-height:44px;cursor:pointer}
@media (prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}}
body,p{line-height:1.6;max-width:75ch}

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
  // 1. Try CF Worker built-in data
  try{
    const r=await fetch(CF+'/infographic-data',{signal:AbortSignal.timeout(5000)});
    if(r.ok){const d=await r.json();if(d&&d.updated_at)return d}
  }catch(e){}
  // 2. Fallback: Firebase
  try{
    const r2=await fetch(FB+'/opendata_infographic.json',{signal:AbortSignal.timeout(8000)});
    if(r2.ok){const d=await r2.json();if(d&&d.updated_at)return d}
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

// ===== Данные инфографики (JSON) =====
const INFOGRAPHIC_DATA = `{"updated_at":"2026-02-14","fuel":{"date":"13.02.2026","stations":44,"prices":{"АИ-92":{"min":57,"max":63.7,"avg":60.3,"count":38},"АИ-95":{"min":62,"max":69.9,"avg":65.3,"count":37},"ДТ зимнее":{"min":74,"max":84.1,"avg":79.4,"count":26},"Газ":{"min":23,"max":32.9,"avg":24.2,"count":19}}},"azs":[{"name":"АЗС ОкиС","address":"РЭБ 2П2 №52","org":"ЗАО \\"ОкиС\\", ИП Зипенкова Влада Владимировна ","tel":"89825333444"},{"name":"АЗС","address":"автодорога Нижневартовск - Мегион, 2 ","org":"ООО \\"Фактор\\"","tel":"8 (3466) 480455"},{"name":"АЗС  ОКИС-С","address":"Кузоваткина,41","org":"ООО \\"ОКИС-С\\", ИП Афрасов Анатолий Афрасович","tel":"8 (3466) 55-51-43"},{"name":"АЗС ОКИС-С","address":"Ленина, 3а/П","org":"ЗАО \\"ОкиС\\", ИП Узюма А.А. ","tel":"8 (3466) 41-31-64, 8 (3466) 41-65-65"},{"name":"АЗС ОКИС-С","address":"2П2 ЗПУ, 2","org":"ООО \\"СОДКОР\\", ИП Афрасов А.А.","tel":"(8-3466) 41-31-64,(8-3466) 41-65-65"},{"name":"АЗС ОКИС-С","address":"Северная, 37а","org":"ООО \\"СОДКОР\\", ИП Касаткин Н.Н.","tel":"(8-3466) 41-31-64,(8-3466) 41-65-65"},{"name":"АЗС №42","address":"Авиаторов, 8","org":"АО \\"Томскнефтепродукт\\" ВНК","tel":"(3466) 63-31-95, 67-13-66, 63-35-02; 64-12-83"},{"name":"АЗС №43","address":"Индустриальная, 2","org":"АО \\"Томскнефтепродукт\\" ВНК","tel":"(3466) 63-31-95, 67-13-66, 63-35-02; 64-12-83"},{"name":"АЗС GN","address":"п. Магистраль,2","org":"ИП А.В. Саратников","tel":"(83466) 56-06-90"},{"name":"АЗС 40","address":"2П2 ЗПУ, 10 ст1","org":"ООО \\"ЛУКОЙЛ-Уралнефтепродукт\\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 43","address":"Индустриальная, 119","org":"ООО \\"ЛУКОЙЛ-Уралнефтепродукт\\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 41","address":"Ханты-Мансийская,20","org":"ООО \\"ЛУКОЙЛ-Уралнефтепродукт\\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 42","address":"М.Жукова, 27П","org":"ООО \\"ЛУКОЙЛ-Уралнефтепродукт\\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 444","address":"Индустриальная, 111б","org":"ОАО \\"Газпромнефть-Урал\\"","tel":"(83462) 94-11-95"},{"name":"АЗС 445","address":"Интернациональная, 62","org":"ОАО \\"Газпромнефть-Урал\\"","tel":"(83462) 94-11-95"}],"uk":{"total":42,"houses":904,"top":[{"name":"ООО \\"ПРЭТ №3\\"","houses":186,"email":"mup@pret3.ru","phone":"(3466) 27-01-89","address":"ул. Северная, д. 28б","director":"Коростелёв Максим Викторович","url":"https://www.pret3.ru/"},{"name":"ООО \\"УК \\"Диалог\\"","houses":170,"email":"dialog.nv@mail.ru","phone":"(3466) 42‒21‒62","address":"ул. Мира, д. 36, пом.1001","director":"Марталлер Кристина Владимировна","url":"https://dialog.uk-site.ru/"},{"name":"АО \\"ЖТ №1\\"","houses":125,"email":"mail@jt1-nv.ru","phone":"(3466) 63-36-39","address":"Панель №5, ул. 9п, д. 47","director":"Фаттахова Оксана Анатольевна","url":"https://жт1-нв.рф/"},{"name":"ООО \\"УК МЖК - Ладья\\"","houses":73,"email":"info@mgk-ladya.com","phone":"(3466) 31-13-11","address":"ул. Мира, д. 96, офис 1005","director":"Зятин Леонид Николаевич","url":"https://mgk-ladya.com/"},{"name":"АО \\"УК №1\\"","houses":65,"email":"mail@uk1-nv.ru","phone":"(3466) 61-33-01","address":"ул. Омская, д. 12а","director":"Чудов Дмитрий Сергеевич","url":"https://uk1-nv.ru/"},{"name":"АО \\"РНУ ЖКХ\\"","houses":55,"email":"info@rnugkh.ru","phone":"(3466) 49-11-04","address":"ул. Мусы Джалиля, д. 15, офис 1007","director":"Кибардин Антон Владимирович","url":"https://rnugkh.ru/"},{"name":"ООО \\"УК Пирс\\"","houses":39,"email":"uk-pirs@yandex.ru","phone":"(3466) 56-16-77","address":"ул. Омская, д. 38, офис 1002","director":"Шипицкий Андрей Николаевич","url":"https://ук-пирс.рф/ "},{"name":"ООО \\"УК-Квартал\\"","houses":33,"email":"kvartal451855@mail.ru","phone":"(3466) 45-18-55","address":"ул. Мусы Джалиля, д. 20А, офис 1001","director":"Елина Ольга Сергеевна","url":"http://kvartal-nv.ru/"},{"name":"ООО \\"Данко\\"","houses":28,"email":"info@ukdanko.ru","phone":"(3466) 29-16-91","address":"ул. Спортивная, д. 17​, помещение 1076","director":"Кадочкин Павел Анатольевич","url":"https://ukdanko.ru/"},{"name":"ООО \\"Ренако-плюс\\"","houses":21,"email":"renako55@mail.ru","phone":"(3466) 65‒20‒80","address":"ул. Дружбы Народов, д. 34","director":"Аристова  Евгения Валерьевна","url":null},{"name":"ООО \\"УК \\"НВ Град\\"","houses":19,"email":"ooouknvgrad@yandex.ru","phone":"(3466) 20‒00‒09","address":"ул. Дружбы Народов, д. 7​, пом. 1006 ","director":"Ларина Екатерина Игоревна","url":null},{"name":"ООО УК \\"Крепость\\"","houses":14,"email":"ukkrep@mail.ru","phone":"(3466) 54‒86‒86","address":"​ул. Омская, д. 14​, офис 1003","director":"Вахрушев Валерий Викторович","url":null},{"name":"ООО \\"УК-Квадратные метры\\"","houses":11,"email":"uk-kvmetr@yandex.ru","phone":"7(912) 939‒45‒45","address":"ул. 60 лет Октября, д. 80а​, каб. 428","director":"Шугаев Айрат Фанисович","url":null},{"name":"ООО \\"УК \\"Жилище-Сервис\\"","houses":11,"email":"office@comfort-nv.ru","phone":"(3466) 42-26-47","address":"ул. 60 лет Октября, д. 27, офис 1018","director":"Юрьев Константин Петрович","url":"https://comfort-nv.ru/"},{"name":"ООО \\"УК\\"","houses":10,"email":"uk.ooo.n-v@yandex.ru","phone":"(3466) 49-15-90","address":"ул. Северная, д. 19г","director":"Дунская Светлана Валериановна","url":"https://uk-nv.ru/  "},{"name":"ООО \\"КОМПАНИЯ ЛИДЕР\\"","houses":7,"email":"nv-office@uk-lider86.ru","phone":"(3466) 49-05-59","address":"ул. Дружбы Народов, д. 36, Офис центр, каб. 303","director":"Кузнецов Даниил Александрович","url":"https://uk-lider86.ru/"},{"name":"ООО УК \\"Пилот\\"","houses":4,"email":"uk-pilot.crona@yandex.ru","phone":"(3467) 35-34-10","address":"г. Ханты-Мансийск, ул. Гагарина, д. 134","director":"Шарыгин Павел Игоревич","url":null},{"name":"ЖК \\"Белые ночи\\"","houses":3,"email":"info@tkvegas.com","phone":"7(922) 252-81-23","address":"ул. Школьная, д. 29а","director":"Шихшабеков Кадырбек Идрисович","url":null},{"name":"ТСЖ \\"Сосна","houses":3,"email":"tsj-sosna@mail.ru","phone":"(3466) 42-27-02","address":"ул. Ленина, д. 19","director":"Басырова Роза Асгатовна","url":null},{"name":"ТСН \\"ТСЖ \\"Северная звезда\\"","houses":3,"email":"bondarenko-chts@mail.ru","phone":"7(912) 902-24-27","address":"ул. Нефтяников, д. 37","director":"Бондаренко Ирина Яковлевна","url":null},{"name":"ТСН \\"ТСЖ Север\\"","houses":3,"email":"tsj-sever@inbox.ru","phone":"7(922) 655-77-29","address":"ул. Ленина, д. 17/1","director":"Колесова Анна Сергеевна","url":null},{"name":"ЖК \\"Мир\\"","houses":1,"email":"JKMir@mail.ru","phone":"(3466) 44-44-30","address":"ул. Ханты-Мансийская, д. 21/3","director":"Теплякова Ольга Николаевна","url":null},{"name":"ТСЖ \\"Единение\\"","houses":1,"email":"Vartovsk.tsg.edinenie@bk.ru","phone":"(3466) 24-12-46","address":"ул. 60 лет Октября, д. 19","director":"Акаева Лариса Амарбековна","url":null},{"name":"ТСЖ \\"Кедр\\"","houses":1,"email":"kedr.nv@mail.ru","phone":"(3466) 41-07-11","address":"ул. 60 лет Октября, д. 19а","director":"Шенцова Елена Федоровна","url":"https://kedr-nv.ru/"},{"name":"ТСЖ \\"Ладья\\"","houses":1,"email":"tsg.ladja@gmail.com","phone":"(3466) 44-90-45","address":"ул. Интернациональная, д. 7","director":"Меньшенин Александр Васильевич","url":null},{"name":"ТСЖ \\"Маяк\\"","houses":1,"email":"tczmayak@mail.ru","phone":"7(932) 253-84-63","address":"ул. Дружбы Народов, д. 25","director":"Щепеткова Любовь Витальевна","url":null},{"name":"ТСЖ \\"Молодежный\\"","houses":1,"email":"tsg44nv@gmail.com","phone":"(3466) 48-04-51","address":"ул. Нефтяников, д. 44","director":"Лапцевич Елена Анатольевна","url":"http://tsg-nv.ru/"},{"name":"ТСЖ \\"Спутник\\"","houses":1,"email":"sputnik.tsg@gmail.com","phone":"7(919) 532-30-00","address":"ул. Ленина, д. 7/2","director":"Бухарова Наталья Анатольевна","url":null},{"name":"ТСН \\"Единство\\"","houses":1,"email":"edinstvo71@yandex.ru","phone":"(3466) 49-18-36","address":"ул. Ленина, д. 7/1","director":"Мойсей Виталий Михайлович","url":"https://tsn-edinstvo.ru/"},{"name":"ТСН \\"Союз\\"","houses":1,"email":"60-9-33@mail.ru","phone":"7(982) 505-66-75","address":"ул. 60 лет Октября, д. 9","director":"Макиенко Юлия Вениаминовна","url":null},{"name":"ТСН \\"ТСЖ Брусника\\"","houses":1,"email":"sovetdoma85@internet.ru","phone":"7(995) 493-27-02","address":"ул. Нефтяников, д. 85","director":"Борисова Лилия Нигматьяновна","url":null},{"name":"ТСН \\"ТСЖ Дружба\\"","houses":1,"email":"druzhba.tsg@gmail.com","phone":"7(922) 252-81-23","address":"ул. Дружбы Народов, д. 22/1","director":"Цвиренко Ольга Леонидовна","url":null},{"name":"ТСН \\"ТСЖ Мира 23\\"","houses":1,"email":"tsjmira23@mail.ru","phone":"7(902) 858-14-96","address":"ул. Мира, д. 23","director":"Починок Ольга Викторовна","url":null},{"name":"ТСН \\"ТСЖ Надежда\\"","houses":1,"email":"tsj-nadezhda@mail.ru","phone":"7(912) 906-79-98","address":"ул. 60 лет Октября, д. 76","director":"Рой Елена Александровна","url":null},{"name":"ТСН \\"ТСЖ Наш уютный дом\\"","houses":1,"email":"tsg.uytnidom@gmail.com","phone":"7(982) 566-05-88","address":"ул. Чапаева, д. 13/1","director":"Нотова Наталья Анатольевна","url":null},{"name":"ТСН \\"ТСЖ Пик 31\\"","houses":1,"email":"pic_31@ro.ru","phone":"7(922)781-95-62","address":"ул. Пикмана, д. 31","director":"Арапов Иван Петрович","url":null},{"name":"ТСН \\"ТСЖ Премьер\\"","houses":1,"email":"premier.tsn@gmail.com","phone":"7(922) 255-49-89","address":"ул. Нововартовская, д. 5","director":"Хазиев Артур Галинурович","url":"http://premier-tsn.ru/"},{"name":"ТСН \\"ТСЖ Содружество\\"","houses":1,"email":"souztsg.86@gmail.com","phone":"7(922) 252-81-23","address":"ул. Дружбы Народов, д. 28б","director":"Губанов Евгений Сергеевич","url":null},{"name":"ТСН \\"ТСЖ \\"Успех\\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Чапаева, д. 13/2","director":"Газизова Альфия Ахметжановна","url":null},{"name":"ТСН \\"ТСЖ Феникс\\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Ленина, д. 46","director":"Пермитин Александр Владимирович","url":null},{"name":"ТСН \\"ТСЖ Черногорка\\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Дзержинского, д. 9","director":"Малышев Даниил Валерьевич","url":null},{"name":"ТСН ТСЖ \\"Осенняя 3\\"","houses":1,"email":"osennyaya3@mail.ru","phone":"7(922) 794-63-46","address":"ул. Осенняя, д. 3","director":"Верина Ирина Анатольевна","url":null}]},"education":{"kindergartens":25,"schools":33,"culture":10,"sport_orgs":4,"sections":155,"sections_free":102,"sections_paid":53,"dod":3},"waste":{"total":500,"groups":[{"name":"Опасные отходы (лампы, термометры, батарейки)","count":289},{"name":"Пластик","count":174},{"name":"Бумага","count":18},{"name":"Лом цветных и черных металлов","count":7},{"name":"Бытовая техника. Оргтехника","count":5},{"name":"Аккумуляторы","count":5},{"name":"Автомобильные шины","count":2}]},"names":{"boys":[{"n":"Артём","c":530},{"n":"Максим","c":428},{"n":"Александр","c":392},{"n":"Дмитрий","c":385},{"n":"Иван","c":311},{"n":"Михаил","c":290},{"n":"Кирилл","c":289},{"n":"Роман","c":273},{"n":"Матвей","c":243},{"n":"Алексей","c":207}],"girls":[{"n":"Виктория","c":392},{"n":"Анна","c":367},{"n":"София","c":356},{"n":"Мария","c":349},{"n":"Анастасия","c":320},{"n":"Дарья","c":308},{"n":"Полина","c":292},{"n":"Алиса","c":290},{"n":"Арина","c":284},{"n":"Ксения","c":279}]},"gkh":[{"name":"АО \\"Горэлектросеть\\" диспетчерская","phone":"8(3466) 26-08-85, 26-07-78"},{"name":"АО \\"Жилищный трест №1\\" диспетчерская","phone":"8(3466) 29-11-99, 64-21-99"},{"name":"АО \\"УК  №1\\" диспетчерская","phone":"8(3466) 24-69-50, 64-20-53"},{"name":"Единая Дежурная Диспетчерская Служба (ЕДДС)","phone":"8(3466) 29-72-50, 112"},{"name":"ООО \\"Нижневартовскгаз\\" диспетчерская","phone":"8(3466) 61-26-12, 61-30-34"},{"name":"ООО \\"Нижневартовские коммунальные системы\\" диспетчерская","phone":"8(3466) 44-77-44, 40-66-88"},{"name":"ООО \\"ПРЭТ №3\\" диспетчерская","phone":"8(3466)27-25-71, 27-33-32"},{"name":"Филиал АО \\"Горэлектросеть\\" Управление теплоснабжением города Нижневартовска диспетчерская","phone":"8(3466) 67-15-03, 24-78-63"}],"tariffs":[{"title":"Полезная информация","desc":""},{"title":"Размер платы за жилое помещение","desc":"Постановления администрации города от 21.12.2012 №1586 &quot;Об утверждении размера платы за содержа"},{"title":"Электроэнергия","desc":""},{"title":"Газоснабжение","desc":""},{"title":"Индексы изменения размера платы граждан за коммунальные услуги","desc":""},{"title":"Услуги в сфере по обращению с твердыми коммунальными отходами","desc":"Постановление администрации города от 19.01.2018 №56 &quot;Об установлении нормативов накопления тве"},{"title":"Водоснабжение, водоотведение","desc":""},{"title":"Тепловая энергия","desc":""}],"transport":{"routes":62,"stops":344,"municipal":34,"commercial":28,"routes_list":[{"num":"1","title":"Железнодорожный вокзал - поселок Дивный","start":"Железнодорожный вокзал","end":"Поселок Дивный(конечная)"},{"num":"2","title":"Поселок Энтузиастов - АСУНефть","start":"Поселок Энтузиастов (конечная)","end":"АСУнефть (в направлении ТК &quot;СЛАВТЭК&quot;)"},{"num":"3","title":"Поселок у северной рощи – МЖК","start":"Поселок у северной рощи","end":"МЖК (конечная)"},{"num":"4","title":"Аэропорт-поселок у северной рощи","start":"Аэропорт (конечная)","end":"Поселок у северной рощи"},{"num":"5К","title":"ДРСУ - СОНТ У озера","start":"ДРСУ","end":"СОНТ &quot;У озера&quot;"},{"num":"5","title":"ДРСУ-поселок у северной рощи","start":"ДРСУ (конечная)","end":"Поселок у северной рощи"},{"num":"6К","title":"Железнодорожный вокзал - Улица 6П","start":"Железнодорожный вокзал","end":"Улица 6П"},{"num":"6","title":"ПАТП №2 - железнодорожный вокзал","start":"ПАТП-2 (конечная)","end":"Железнодорожный вокзал"},{"num":"7","title":"ПАТП №2 –городская больница №3","start":"ПАТП-2 (конечная)","end":"Городская поликлиника №3 (конечная)"},{"num":"8","title":"Авторынок-АСУнефть","start":"Авторынок (конечная)","end":"АСУнефть (в направлении ТК &quot;СЛАВТЭК&quot;)"},{"num":"9","title":"Аэропорт -Старовартовская","start":"Аэропорт (конечная)","end":"Старовартовская (конечная)"},{"num":"10","title":"ПАТП №2 – авторынок","start":"ПАТП-2 (конечная)","end":"Авторынок (конечная)"},{"num":"11К","title":"ДРСУ-СОНТ «Авиатор»- Управление социальной защиты населения","start":"ДРСУ (конечная)","end":"Управление социальной защиты населения (в направлении Хоккейный корт)"},{"num":"11","title":"Управление социальной защиты населения - ДРСУ","start":"ДРСУ (конечная)","end":"Управление социальной защиты населения (в направлении Хоккейный корт)"},{"num":"12","title":"ПАТП №2 –авторынок","start":"ПАТП-2 (конечная)","end":"Авторынок (конечная)"}]},"road_service":{"total":107,"types":[{"name":"АЗС","count":59},{"name":"Парковка","count":48}]},"road_works":{"total":24,"items":[{"title":"Обустройство разделительного (отбойного) ограждения для разделения транспортных потоков на участке а"},{"title":"улица Интернациональная (на участке от улицы Дзержинского до улицы Нефтяников) - устранение колейнос"},{"title":"улица Интернациональная (в районе дома 74/1 улицы Индустриальная (при движении от «САТУ» на кольцо) "},{"title":"улица Интернациональная (в районе пересечения с улицей Зимней) - устранение колейности"},{"title":"улица Ханты–Мансийская (на участке от улицы Омская до улицы Профсоюзная) - устранение колейности"},{"title":"улица Маршала Жукова (в районе пересечения с улицей Зимняя, около МУП «Горводоканал») - устранение к"},{"title":"улица Г.И. Пикмана (от проспекта Победы до улицы Мусы Джалиля) - устранение колейности"},{"title":"улица 60 лет Октября, 23 - ремонт тротуара на улично-дорожной сети города "}]},"building":{"permits":210,"objects":112,"reestr":3,"permits_trend":[{"year":2008,"count":20},{"year":2009,"count":18},{"year":2010,"count":19},{"year":2011,"count":22},{"year":2012,"count":25},{"year":2013,"count":18},{"year":2014,"count":30},{"year":2015,"count":21},{"year":2016,"count":26},{"year":2017,"count":9}]},"land_plots":{"total":7,"items":[{"address":"Ханты-Мансийский автономный округ – Югра, г. Нижневартовск, район Нижневартовско","square":"108508"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, западный промышленны","square":"300000"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, северо-западный пром","square":"165000"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, северный промышленны","square":"255000"},{"address":"Ханты-Мансийский автономный округ- Югра, г. Нижневартовск, квартал 20 Восточного","square":"12000"}]},"accessibility":{"total":136,"groups":[{"name":"Учреждения образования","count":30},{"name":"Светофоры со звуковыми сигналами","count":18},{"name":"Дорожный знак «Слепые пешеходы»","count":16},{"name":"Пандусы","count":16},{"name":"Учреждения культуры","count":13},{"name":"Дорожный знак «Инвалиды»","count":12},{"name":"Учреждения физической культуры и спорта","count":12},{"name":"Учреждения здравоохранения и социальной защиты населения","count":11},{"name":"Здания структурных подразделений администрации города","count":6},{"name":"Учреждения транспорта и связи","count":2}]},"culture_clubs":{"total":148,"free":125,"paid":23,"items":[{"name":"вокальный коллектив","age":"5-14","pay":"бесплатно"},{"name":"Студия  авторской  песни  «Рио-Рита»","age":"25-29","pay":"бесплатно"},{"name":"Кружок класссического вокала","age":"18-0","pay":"бесплатно"},{"name":"вокальная шоу-группа «Джулия»","age":"8-14","pay":"бесплатно"},{"name":"Ансамбль «Северяне»","age":"18-0","pay":"бесплатно"},{"name":"Почетный коллектив народного творчества, народный самодеятельный коллектив, хор  ветеранов труда «Красная  гвоздика» им. В. Салтысова","age":"45-0","pay":"бесплатно"},{"name":"Народный самодеятельный коллектив, хор русской песни  «Сибирские зори» Ансамбль-спутник «Девчата» ","age":"18-0","pay":"бесплатно"},{"name":"ДЖАЗ-БАЛЕТ","age":"14-35","pay":"бесплатно"},{"name":"Детский  джаз-балет","age":"7-14","pay":"бесплатно"},{"name":"Народный самодеятельный коллектив, хореографический ансамбль «Кавказ» младшая группа","age":"7-16","pay":"бесплатно"},{"name":"Образцовый художественный коллектив, хореографический ансамбль «Альянс»","age":"10-14","pay":"бесплатно"},{"name":"Хореографический  ансамбль «Искорки»","age":"5-12","pay":"платно"}]},"trainers":{"total":191},"salary":{"total":4332,"years":[2017,2018,2019,2020,2021,2022,2023,2024],"trend":[{"year":2017,"avg":98.6,"count":558},{"year":2018,"avg":106.9,"count":563},{"year":2019,"avg":121.9,"count":584},{"year":2020,"avg":127.5,"count":546},{"year":2021,"avg":134.0,"count":527},{"year":2022,"avg":149.5,"count":517},{"year":2023,"avg":162.4,"count":515},{"year":2024,"avg":177.8,"count":519}],"growth_pct":80.3,"latest_avg":177.8},"hearings":{"total":543,"trend":[{"year":2019,"count":56},{"year":2020,"count":49},{"year":2021,"count":36},{"year":2022,"count":64},{"year":2023,"count":66},{"year":2024,"count":72},{"year":2025,"count":75},{"year":2026,"count":11}],"recent":[{"date":"12.02.2026","title":"О проведении общественных обсуждений по проекту планировки территории улично-дорожной сети в части у"},{"date":"11.02.2026","title":"О проведении общественных обсуждений по проекту межевания территории планировочного района 30 города"},{"date":"06.02.2026","title":"О проведении общественных обсуждений по проектам о предоставлении разрешения на отклонение от предел"},{"date":"28.01.2026","title":"О проведении общественных обсуждений по проекту внесения изменений в проект межевания территории пла"},{"date":"28.01.2026","title":"О проведении общественных обсуждений по проекту внесения изменений в проект планировки территории и "}]},"gmu_phones":[{"org":"Предоставление сведений из реестра муниципального имущества","tel":"(3466) 41-06-26\\r\\n(3466) 24-19-10"},{"org":"Проведение муниципальной экспертизы проектов освоения лесов,","tel":"(3466) 41-20-26"},{"org":"Предоставление водных объектов, находящихся в собственности ","tel":"(3466) 41-20-26"},{"org":"Предоставление водных объектов, находящихся в собственности ","tel":"(3466) 41-20-26"},{"org":"Государственная регистрация заявлений о проведении обществен","tel":"(3466) 41-53-04"},{"org":"Организация общественных обсуждений среди населения о намеча","tel":"(3466) 41-53-04"},{"org":"Выдача разрешений на снос или пересадку зеленых насаждений н","tel":"(3466) 41-20-26"},{"org":"Предоставление информации о реализации программ начального о","tel":"(3466) 43-75-81\\r\\n(3466) 43-75-24\\r\\n(3466) 42-24-10"},{"org":"Предоставление информации об образовательных программах и уч","tel":"(3466) 43-75-24\\r\\n(3466) 43-76-24\\r\\n(3466) 42-24-10"},{"org":"Предоставление информации о текущей успеваемости обучающегос","tel":"(3466) 43-75-24"}],"demography":[{"marriages":"366","birth":"200","boys":"100","girls":"100","date":"09.11.2018"}],"budget_bulletins":{"total":15,"items":[{"title":"2024 год","desc":"1 квартал 2024 года","url":"https://www.n-vartovsk.ru/upload/iblock/f4f/iyrnf9utmz2wl7pvk1a3jcob8dldt5iq/4grze2d6pziz3bzf3vvtbg9iloss6gtg.docx"},{"title":"2023 год","desc":"1 квартал 2023 года","url":"https://www.n-vartovsk.ru/upload/iblock/7d9/vblnpmi1vh1gf1qcrv20kwrbnxilg3sr/9c3zax3mx13yyb3zxncdhhj7zwxi7up4.docx"},{"title":"2022 год","desc":"Финансовый бюллетень за 1 квартал 2022 года","url":"https://www.n-vartovsk.ru/upload/iblock/4a3/i356g0vkyyqft80yschznahxlrx0zeb7/oycg03f3crsrhu7mum89jkyvrap4c6oz.docx"},{"title":"2021 год","desc":"Финансовый бюллетень за 1 квартал 2021 года","url":"https://www.n-vartovsk.ru/upload/iblock/8b6/qxglhnbp9sk9b68gvo5pazs4v16bcplj/5553ffcd956c733ad2b403318d6403a4.docx"},{"title":"2020 год","desc":"Финансовый бюллетень за 1 квартал 2020 года","url":"https://www.n-vartovsk.ru/upload/iblock/232/c03d912c9586247c9703d656b4c32879.docx"},{"title":"2019 год","desc":"Финансовый бюллетень 1 квартал 2019 года","url":"https://www.n-vartovsk.ru/upload/iblock/055/f16691e345f7816323423dfeb8ba7e0e.doc"},{"title":"2018 год","desc":"Финансовый бюллетень за 1 квартал 2018 года","url":"https://www.n-vartovsk.ru/upload/iblock/dcd/2621bcc26bbc8d8fffbcb5d6ecf90d0e.doc"},{"title":"2017 год","desc":"Финансовый бюллетень за 1 квартал 2017 года","url":"https://www.n-vartovsk.ru/upload/iblock/21f/d28d3kuziakrt01ie0o99ntar7lg3nuy/6361178c8521c5647a4c3c3ca5e60ee8.doc"},{"title":"2016 год","desc":"Финансовый бюллетень за 1 квартал 2016 года","url":"https://www.n-vartovsk.ru/upload/iblock/d18/7f7c4e392c3d6414ad3d0f84dd0b6479.doc"},{"title":"2015 год","desc":"Финансовый бюллетень за 1 полугодие 2015 года","url":"https://www.n-vartovsk.ru/upload/iblock/592/vfg070q95hablw163enhamzztljx9kaj/ca01446ccc0784a99f5f313515ec94c3.doc"}]},"budget_info":{"total":14,"items":[{"title":"2024 год","desc":"январь 2024 года","url":"https://www.n-vartovsk.ru/upload/iblock/3b0/nx0kerqbqi96emliwgctiup4e6cgz4cf/nhvc1qw6m5rxxj63vd4dmlsv55luyp4f.xls"},{"title":"2023 год","desc":"январь 2023 года","url":"https://www.n-vartovsk.ru/upload/iblock/636/ijxbpxgusrszdxfp2ko65lg3v70uiced/cv3z10xzcw7tcj2qudzz3qorlkuhvmz2.xls"},{"title":"2022 год","desc":"Январь 2022 года","url":"https://www.n-vartovsk.ru/upload/iblock/947/qr7plqmr98mqdvpggnbpwylvwsgibkuo/ghafnfiadko3pb3x9qmaxy6cyh0ek50q.xls"},{"title":"2021 год","desc":"январь 2021 года","url":"https://www.n-vartovsk.ru/upload/iblock/ec1/esrcxgu7itynh7sdgr1yz8pgpsqde34d/ccac4fa312a21129efd8600d42cd7c8a.xls"},{"title":"2020 год","desc":"Январь 2020 год","url":"https://www.n-vartovsk.ru/upload/iblock/7ae/1b2f8416e003a9a2010e49640f824378.xls"},{"title":"2019 год","desc":"январь","url":"https://www.n-vartovsk.ru/upload/iblock/456/feacd041fe9023571aba0c13cd1dd630.xls"},{"title":"2018 год","desc":"Январь","url":"https://www.n-vartovsk.ru/upload/iblock/6c6/c4821cbae84703542927dce0c154f0c7.xlsx"},{"title":"2017 год","desc":"январь","url":"https://www.n-vartovsk.ru/upload/iblock/58b/d6vly8vwdtfeq2sep5auphz6c714b13c/4b106f646e745a1e9f46d8f6789bffe7.xlsx"},{"title":"2016 год","desc":"январь 2016","url":"https://www.n-vartovsk.ru/upload/iblock/69d/1fde18917556cb2940ef9a9ea5af57f0.xlsx"},{"title":"2015 год","desc":"на 01.02.2015 год","url":"https://www.n-vartovsk.ru/upload/iblock/3bd/3a0c4a60d04dacc4ebf3856162e31b9d.xlsx"}]},"agreements":{"total":138,"total_summ":107801.9,"total_inv":15603995.88,"total_gos":3919554.51,"by_type":[{"name":"Энергосервис","count":123},{"name":"ГЧП","count":5},{"name":"КЖЦ","count":3},{"name":"Аренда имущества","count":1},{"name":"Капремонт","count":1},{"name":"Инвестпроекты","count":1},{"name":"Инвестконтракты","count":1},{"name":"РИП","count":1},{"name":"Соцпартнёрство","count":1},{"name":"ЗПК","count":1}],"top":[{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по строительству объекта и сдаче результата работ Заказчику по Акту приемки за-конченного с","org":"строительство","date":"25.09.2020","summ":41350.7,"vol_inv":0.0,"vol_gos":248104.4,"year":"10"},{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по разработке проектной документации, в соответствии с Заданием на внесение изменений в про","org":"строительство","date":"12.11.2019","summ":39837.3,"vol_inv":0.0,"vol_gos":239023.8,"year":"9"},{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по разработке проектной документации, в соответствии с Заданием на внесение изменений в про","org":"строительство","date":"03.06.2019","summ":26076.9,"vol_inv":0.0,"vol_gos":156461.8,"year":"9"},{"type":"Соцпартнёрство","title":"ООО &quot;Пилипака и компания&quot;","desc":"Реализация инвестиционного проекта &quot;Строительство ТК &quot;Станция&quot;","org":"Торговля","date":"15.12.2020","summ":537.0,"vol_inv":1600000.0,"vol_gos":0.0,"year":"6"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"07.08.2023","summ":0.0,"vol_inv":5048.008,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":2028.98661,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":10507.55601,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":3255.55993,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"31.07.2023","summ":0.0,"vol_inv":4476.34425,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"07.08.2023","summ":0.0,"vol_inv":5728.50495,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"15.05.2023","summ":0.0,"vol_inv":2828.58625,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"15.05.2023","summ":0.0,"vol_inv":5134.71,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":908.232,"vol_gos":0.0,"year":"5"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":313.248,"vol_gos":0.0,"year":"5"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":876.915,"vol_gos":0.0,"year":"5"}]},"property":{"lands":688,"movable":978,"realestate":8449,"stoks":13,"privatization":471,"rent":148,"total":10128},"business":{"info":1995,"smp_messages":0,"events":0},"advertising":{"total":128},"communication":{"total":25},"archive":{"expertise":0,"list":1500},"documents":{"docs":35385,"links":38500,"texts":35385},"programs":{"total":5,"items":[{"title":"ПЕРЕЧЕНЬ МУНИЦИПАЛЬНЫХ ПРОГРАММ ГОРОДА НИЖНЕВАРТОВСКА, ДЕЙСТВУЮЩИХ В 2026 ГОДУ"},{"title":"ПЕРЕЧЕНЬ МУНИЦИПАЛЬНЫХ ПРОГРАММ ГОРОДА НИЖНЕВАРТОВСКА, ДЕЙСТВОВАВШИХ В 2025 ГОДУ"},{"title":"ПЛАН МЕРОПРИЯТИЙ ПО РЕАЛИЗАЦИИ СТРАТЕГИИ СОЦИАЛЬНО-ЭКОНОМИЧЕСКОГО РАЗВИТИЯ ГОРОДА НИЖНЕВАРТОВСКА ДО "},{"title":"СТРАТЕГИЯ СОЦИАЛЬНО-ЭКОНОМИЧЕСКОГО РАЗВИТИЯ ГОРОДА НИЖНЕВАРТОВСКА ДО 2036 ГОДА"},{"title":"ПЕРЕЧЕНЬ ГОСУДАРСТВЕННЫХ ПРОГРАММ ХАНТЫ-МАНСИЙСКОГО АВТОНОМНОГО ОКРУГА – ЮГРЫ"}]},"news":{"total":1018,"rubrics":1332,"photos":0,"trend":[{"year":2020,"count":15},{"year":2021,"count":3},{"year":2025,"count":867},{"year":2026,"count":133}]},"ad_places":{"total":414},"territory_plans":{"total":87},"labor_safety":{"total":29},"appeals":{"total":8},"msp":{"total":14,"items":[{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""}]},"counts":{"construction":112,"phonebook":576,"admin":157,"sport_places":30,"mfc":11,"msp":14,"trainers":191,"bus_routes":62,"bus_stops":344,"accessibility":136,"culture_clubs":148,"hearings":543,"permits":210,"property_total":10128,"agreements_total":138,"budget_docs":29,"privatization":471,"rent":148,"advertising":128,"documents":35385,"archive":1500,"business_info":1995,"smp_messages":0,"news":1018,"territory_plans":87},"datasets_total":72,"datasets_with_data":67}`;

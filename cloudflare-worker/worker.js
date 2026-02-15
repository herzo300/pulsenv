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
</head>
<body>
<!-- Splash -->
<div id="splash">
  <div class="splash-bg"><canvas id="pulseCanvas"></canvas></div>
  <div class="splash-content">
    <div class="city-emblem">
      <svg viewBox="0 0 120 120" class="emblem-svg">
        <polygon points="60,8 52,50 68,50" fill="none" stroke="currentColor" stroke-width="2" opacity=".7"/>
        <line x1="56" y1="28" x2="64" y2="28" stroke="currentColor" stroke-width="1.5" opacity=".5"/>
        <line x1="54" y1="38" x2="66" y2="38" stroke="currentColor" stroke-width="1.5" opacity=".5"/>
      </svg>
    </div>
    <div class="splash-pulse-ring" id="pulseRing">
      <div class="ring r1"></div><div class="ring r2"></div><div class="ring r3"></div>
      <div class="pulse-core" id="pulseCore"></div>
    </div>
    <h1 class="splash-title">Пульс города</h1>
    <div class="splash-city">НИЖНЕВАРТОВСК</div>
    <div class="splash-mood" id="moodText">Анализ настроения...</div>
    <div class="splash-stats" id="splashStats">
      <div class="ss-item"><span class="ss-num" id="ssTotal">—</span><span class="ss-label">проблем</span></div>
      <div class="ss-item"><span class="ss-num" id="ssOpen">—</span><span class="ss-label">открыто</span></div>
      <div class="ss-item"><span class="ss-num" id="ssResolved">—</span><span class="ss-label">решено</span></div>
    </div>
    <div class="splash-loader"><div class="sl-bar"><div class="sl-fill" id="slFill"></div></div><div class="sl-text" id="slText">Загрузка...</div></div>
  </div>
</div>
<!-- Main -->
<div id="app" style="display:none">
  <div id="map"></div>
  <!-- Top bar -->
  <div id="topBar">
    <div class="tb-header">
      <div class="tb-pulse"></div>
      <div class="tb-title">Пульс города</div>
    </div>
    <div class="tb-stats">
      <div class="tb-stat"><span class="tb-num" id="st">0</span><span class="tb-lbl">всего</span></div>
      <div class="tb-stat"><span class="tb-num red" id="so">0</span><span class="tb-lbl">открыто</span></div>
      <div class="tb-stat"><span class="tb-num yellow" id="sw">0</span><span class="tb-lbl">новые</span></div>
      <div class="tb-stat"><span class="tb-num green" id="sr">0</span><span class="tb-lbl">решено</span></div>
    </div>
  </div>
  <!-- Filters -->
  <div id="filterPanel">
    <div class="fp-row" id="dayFilters"></div>
    <div class="fp-row" id="catFilters"></div>
    <div class="fp-row" id="statusFilters"></div>
  </div>
  <!-- Timeline -->
  <div class="tl-panel"><canvas id="tlCanvas" height="42"></canvas></div>
  <!-- Toast -->
  <div class="toast" id="newToast" style="display:none">
    <span class="toast-icon">🔔</span><span class="toast-text" id="toastText"></span>
  </div>
  <!-- Stats button + overlay -->
  <button class="stats-btn" id="statsBtn" title="Статистика">📊</button>
  <div class="stats-overlay" id="statsOverlay"></div>
  <!-- UK Rating button + overlay -->
  <button class="uk-btn" id="ukBtn" title="Рейтинг УК">🏢</button>
  <div class="uk-overlay" id="ukOverlay"></div>
  <!-- FAB — oil drop with pulse -->
  <button class="fab" id="fabNew" title="Подать жалобу">
    <div class="fab-drop">
      <div class="fab-ring"></div><div class="fab-ring2"></div>
      <svg viewBox="0 0 56 56"><defs><linearGradient id="oilGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#1a1a2e"/><stop offset="50%" stop-color="#16213e"/>
        <stop offset="100%" stop-color="#0f3460"/></linearGradient></defs>
        <path class="drop-fill" d="M28 4C28 4 12 22 12 34C12 42.8 19.2 50 28 50C36.8 50 44 42.8 44 34C44 22 28 4 28 4Z"/></svg>
      <span class="fab-icon">+</span>
    </div>
  </button>
  <!-- Complaint form -->
  <div class="cf-overlay" id="cfOverlay">
    <div class="cf-sheet">
      <h3>📝 Подать жалобу</h3>
      <div class="cf-field"><label>Категория</label>
        <select id="cfCat"></select></div>
      <div class="cf-field"><label>Описание</label>
        <textarea id="cfDesc" placeholder="Опишите проблему..." rows="3"></textarea></div>
      <div class="cf-field"><label>Адрес <span class="cf-gps" id="cfGps">📍 GPS</span></label>
        <input id="cfAddr" placeholder="ул. Ленина, 5" /></div>
      <div class="cf-field" style="display:flex;gap:6px">
        <div style="flex:1"><label>Широта</label><input id="cfLat" type="number" step="0.0001" placeholder="60.9344" /></div>
        <div style="flex:1"><label>Долгота</label><input id="cfLng" type="number" step="0.0001" placeholder="76.5531" /></div>
      </div>
      <div class="cf-btns">
        <button class="cf-btn secondary" id="cfCancel">Отмена</button>
        <button class="cf-btn primary" id="cfSubmit">Отправить</button>
      </div>
    </div>
  </div>
</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"><\/script>
<script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"><\/script>
<link href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" rel="stylesheet"/>
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"><\/script>
<script src="https://unpkg.com/@maplibre/maplibre-gl-leaflet@0.0.22/leaflet-maplibre-gl.js"><\/script>
<script>
// ═══════════════════════════════════════════════════════
// Пульс города — Карта v4: новая заставка, рейтинг УК, статистика
// ═══════════════════════════════════════════════════════
var tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',function(){tg.close()})}

var S=document.createElement('style');
S.textContent=\`
*{margin:0;padding:0;box-sizing:border-box}
:root{
--bg:#0a0e1a;--text:#e2e8f0;--hint:rgba(255,255,255,.4);
--accent:#6366f1;--accentL:#818cf8;--accentD:#4f46e5;
--surface:rgba(12,16,30,.92);--glass:blur(18px) saturate(1.8);
--green:#10b981;--red:#ef4444;--yellow:#f59e0b;--orange:#f97316;
--purple:#a855f7;--teal:#14b8a6;--pink:#ec4899;
--r:14px;--rs:8px;--shadow:0 2px 16px rgba(0,0,0,.35);
}
body{font-family:Inter,-apple-system,BlinkMacSystemFont,sans-serif;
background:var(--bg);color:var(--text);overflow:hidden;-webkit-font-smoothing:antialiased}

/* ═══ SPLASH ═══ */
#splash{position:fixed;inset:0;z-index:9999;background:#060a14;
display:flex;align-items:center;justify-content:center;transition:opacity .8s,transform .5s}
#splash.hide{opacity:0;transform:scale(1.05);pointer-events:none}
#splashCanvas{position:absolute;inset:0;width:100%;height:100%}
.splash-content{position:relative;z-index:1;text-align:center;padding:20px;width:100%;max-width:360px}

.logo-wrap{position:relative;width:140px;height:140px;margin:0 auto 8px}
.logo-glow{position:absolute;inset:-20px;border-radius:50%;
background:radial-gradient(circle,rgba(99,102,241,.25) 0%,transparent 70%);
animation:glowPulse 3s ease-in-out infinite}
@keyframes glowPulse{0%,100%{opacity:.6;transform:scale(.9)}50%{opacity:1;transform:scale(1.1)}}

.logo-ring{position:absolute;inset:10px;border-radius:50%;animation:ringRotate 8s linear infinite}
@keyframes ringRotate{to{transform:rotate(360deg)}}
.ring-seg{position:absolute;inset:0;border-radius:50%;border:2px solid transparent}
.ring-seg.s1{border-top-color:rgba(99,102,241,.7);border-right-color:rgba(99,102,241,.3)}
.ring-seg.s2{border-bottom-color:rgba(16,185,129,.5);transform:rotate(120deg)}
.ring-seg.s3{border-left-color:rgba(245,158,11,.4);transform:rotate(240deg)}

.logo-core{position:absolute;inset:24px;border-radius:50%;
background:radial-gradient(circle at 40% 35%,#1a1f3a,#0d1020);
box-shadow:inset 0 2px 12px rgba(0,0,0,.6),0 0 30px rgba(99,102,241,.2);
display:flex;align-items:center;justify-content:center;
animation:coreBreathe 2.5s ease-in-out infinite}
@keyframes coreBreathe{0%,100%{transform:scale(1)}50%{transform:scale(1.04)}}
.logo-svg{width:50px;height:50px}

.ecg-wrap{width:100%;height:48px;margin:4px 0 8px;opacity:.8}
#ecgCanvas{width:100%;height:48px;display:block}

.sp-title{font-size:28px;font-weight:900;
background:linear-gradient(135deg,#818cf8 0%,#6366f1 40%,#a78bfa 100%);
-webkit-background-clip:text;-webkit-text-fill-color:transparent;
animation:titleIn .8s ease .3s both;letter-spacing:-.5px}
@keyframes titleIn{from{opacity:0;transform:translateY(12px) scale(.95)}to{opacity:1;transform:translateY(0) scale(1)}}

.sp-city{font-size:10px;letter-spacing:5px;color:rgba(255,255,255,.3);
text-transform:uppercase;font-weight:700;margin-top:2px;animation:titleIn .8s ease .5s both}

.sp-mood{font-size:12px;font-weight:700;margin-top:10px;min-height:18px;
animation:titleIn .8s ease .7s both;transition:color .5s}

.sp-stats{display:flex;justify-content:center;gap:14px;margin-top:14px;animation:titleIn .8s ease .9s both}
.sp-stat{text-align:center}
.sp-num{display:block;font-size:22px;font-weight:900;
background:#0c1020;border-radius:12px;padding:6px 12px;min-width:52px;
box-shadow:6px 6px 14px rgba(0,0,0,.6),-4px -4px 10px rgba(255,255,255,.02);
font-variant-numeric:tabular-nums}
.sp-lbl{font-size:7px;color:rgba(255,255,255,.3);text-transform:uppercase;letter-spacing:1.5px;margin-top:3px;display:block;font-weight:600}

.sp-loader{margin-top:18px;animation:titleIn .8s ease 1.1s both}
.sp-bar{width:180px;height:3px;border-radius:2px;margin:0 auto;background:rgba(255,255,255,.06);overflow:hidden}
.sp-fill{height:100%;width:0;border-radius:2px;background:linear-gradient(90deg,var(--accent),var(--green));transition:width .3s}
.sp-text{font-size:8px;color:rgba(255,255,255,.25);margin-top:5px;font-weight:500}

/* ═══ MAP ═══ */
#map{position:fixed;inset:0;z-index:0}
#topBar{position:fixed;top:0;left:0;right:0;z-index:1000;
background:var(--surface);backdrop-filter:var(--glass);
border-bottom:1px solid rgba(255,255,255,.05);padding:5px 10px;display:flex;align-items:center;gap:8px}
.tb-header{display:flex;align-items:center;gap:5px;flex-shrink:0}
.tb-pulse{width:7px;height:7px;border-radius:50%;background:var(--green);animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
.tb-title{font-size:13px;font-weight:800;white-space:nowrap}
.tb-stats{display:flex;gap:6px;margin-left:auto;flex-shrink:0}
.tb-stat{text-align:center;min-width:32px}
.tb-num{font-size:14px;font-weight:800;display:block;line-height:1.1}
.tb-lbl{font-size:6px;color:var(--hint);text-transform:uppercase;letter-spacing:.5px}
.red{color:var(--red)}.green{color:var(--green)}.yellow{color:var(--yellow)}.blue{color:var(--accent)}
#filterPanel{position:fixed;top:42px;left:0;right:0;z-index:999;
padding:3px 6px 2px;background:linear-gradient(var(--surface) 80%,transparent);backdrop-filter:var(--glass)}
.fp-row{display:flex;gap:3px;overflow-x:auto;scrollbar-width:none;padding:2px 0;-webkit-overflow-scrolling:touch}
.fp-row::-webkit-scrollbar{display:none}
.chip{flex-shrink:0;padding:3px 8px;border-radius:16px;font-size:9px;font-weight:600;
cursor:pointer;transition:all .2s;white-space:nowrap;user-select:none;
background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.07);color:var(--hint)}
.chip:active{transform:scale(.94)}
.chip.active{background:var(--accent);color:#fff;border-color:var(--accent);box-shadow:0 2px 8px rgba(99,102,241,.3)}
.chip.st-open.active{background:var(--red);border-color:var(--red)}
.chip.st-pending.active{background:var(--yellow);border-color:var(--yellow);color:#000}
.chip.st-progress.active{background:var(--orange);border-color:var(--orange)}
.chip.st-resolved.active{background:var(--green);border-color:var(--green)}
.chip.day{font-size:8px;padding:2px 7px}
.chip.day .dn{font-weight:800;font-size:10px;display:block;line-height:1}
.chip.day .dd{font-size:6px;opacity:.7}
.chip.day.active{background:var(--accentD);border-color:var(--accent)}
.chip.day.today{border-color:var(--accent);border-width:2px}
.tl-panel{position:fixed;bottom:0;left:0;right:0;z-index:999;height:50px;
background:var(--surface);backdrop-filter:var(--glass);border-top:1px solid rgba(255,255,255,.05);padding:3px 6px}
#tlCanvas{width:100%;height:42px;display:block}
\`;
document.head.appendChild(S);

// ═══ More styles (popups, stats overlay, UK rating, FAB, complaint form) ═══
var S2=document.createElement('style');
S2.textContent=\`
.leaflet-popup-content-wrapper{background:var(--surface)!important;color:var(--text)!important;
border:1px solid rgba(255,255,255,.07)!important;border-radius:12px!important;max-width:280px!important;
backdrop-filter:var(--glass)!important;box-shadow:0 8px 32px rgba(0,0,0,.4)!important}
.leaflet-popup-tip{background:var(--surface)!important}
.leaflet-popup-content{margin:8px 10px!important}
.pp{min-width:170px}
.pp h3{margin:0 0 3px;font-size:12px;line-height:1.2}
.pp .desc{margin:2px 0;font-size:10px;color:var(--hint);line-height:1.3}
.pp .meta{margin:2px 0;font-size:9px;color:var(--hint)}
.pp .meta b{color:var(--text);font-weight:600}
.pp a{color:var(--accentL);text-decoration:none;font-size:9px}
.pp .links{margin-top:3px;display:flex;gap:5px;flex-wrap:wrap}
.pp .vote-row{display:flex;align-items:center;gap:8px;margin-top:5px}
.pp .vote-btn{padding:3px 10px;border-radius:14px;border:1px solid rgba(255,255,255,.1);
background:rgba(255,255,255,.04);color:var(--hint);font-size:10px;font-weight:700;cursor:pointer;
transition:all .2s;display:flex;align-items:center;gap:3px}
.pp .vote-btn:active{transform:scale(.9)}
.pp .vote-btn.liked{background:rgba(16,185,129,.15);border-color:var(--green);color:var(--green)}
.pp .vote-btn.disliked{background:rgba(239,68,68,.15);border-color:var(--red);color:var(--red)}
.badge{display:inline-block;padding:2px 6px;border-radius:5px;font-size:7px;font-weight:700;color:#fff;margin-top:2px}
.pp .src{display:inline-block;padding:1px 4px;border-radius:3px;font-size:7px;
background:rgba(99,102,241,.12);color:var(--accentL);margin-top:2px;margin-left:3px}
.toast{position:fixed;top:46px;left:50%;transform:translateX(-50%);z-index:2000;
background:rgba(16,185,129,.92);color:#fff;padding:6px 12px;border-radius:10px;
font-size:10px;display:flex;align-items:center;gap:4px;backdrop-filter:blur(8px);
box-shadow:0 4px 16px rgba(0,0,0,.3);animation:tin .3s ease;cursor:pointer}
.toast.hide{animation:tout .3s ease forwards}
@keyframes tin{from{opacity:0;transform:translateX(-50%) translateY(-14px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}
@keyframes tout{to{opacity:0;transform:translateX(-50%) translateY(-14px)}}
@keyframes mpop{0%{transform:scale(0)}60%{transform:scale(1.3)}100%{transform:scale(1)}}
.new-marker{animation:mpop .5s ease}
.stats-btn{position:fixed;top:4px;right:52px;z-index:1001;width:42px;height:42px;border-radius:14px;
background:var(--surface);backdrop-filter:var(--glass);border:1px solid rgba(255,255,255,.08);
color:var(--accentL);font-size:20px;cursor:pointer;display:flex;align-items:center;justify-content:center;
box-shadow:var(--shadow);transition:all .25s}
.stats-btn:active{transform:scale(.85) rotate(-8deg)}
.stats-btn:hover{box-shadow:0 0 16px rgba(99,102,241,.4)}
.stats-overlay{position:fixed;top:0;right:-320px;width:300px;height:100%;z-index:2500;
background:var(--surface);backdrop-filter:var(--glass);border-left:1px solid rgba(255,255,255,.06);
transition:right .3s ease;overflow-y:auto;padding:50px 14px 20px}
.stats-overlay.open{right:0}
.stats-overlay h3{font-size:13px;font-weight:800;margin-bottom:8px}
.stats-overlay .so-close{position:absolute;top:10px;right:10px;background:none;border:none;
color:var(--hint);font-size:18px;cursor:pointer}
.so-row{display:flex;justify-content:space-between;padding:4px 0;font-size:11px;border-bottom:1px solid rgba(255,255,255,.04)}
.so-row .so-label{color:var(--hint)}.so-row .so-val{font-weight:700}
.so-section{margin-top:12px}
.so-section h4{font-size:10px;color:var(--hint);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px}
.so-bar-wrap{margin:3px 0}
.so-bar-label{font-size:9px;color:var(--hint);display:flex;justify-content:space-between}
.so-bar{height:4px;border-radius:2px;background:rgba(255,255,255,.06);margin-top:1px;overflow:hidden}
.so-bar-fill{height:100%;border-radius:2px;transition:width .5s}
.uk-btn{position:fixed;top:4px;right:8px;z-index:1001;width:42px;height:42px;border-radius:14px;
background:var(--surface);backdrop-filter:var(--glass);border:1px solid rgba(255,255,255,.08);
color:var(--accentL);font-size:20px;cursor:pointer;display:flex;align-items:center;justify-content:center;
box-shadow:var(--shadow);transition:all .25s}
.uk-btn:active{transform:scale(.85) rotate(8deg)}
.uk-btn:hover{box-shadow:0 0 16px rgba(99,102,241,.4)}
.uk-overlay{position:fixed;top:0;left:-320px;width:300px;height:100%;z-index:2500;
background:var(--surface);backdrop-filter:var(--glass);border-right:1px solid rgba(255,255,255,.06);
transition:left .3s ease;overflow-y:auto;padding:50px 14px 20px}
.uk-overlay.open{left:0}
.uk-overlay h3{font-size:13px;font-weight:800;margin-bottom:8px}
.uk-overlay .uk-close{position:absolute;top:10px;left:10px;background:none;border:none;
color:var(--hint);font-size:18px;cursor:pointer}
.uk-item{padding:6px 0;border-bottom:1px solid rgba(255,255,255,.04)}
.uk-item .uk-name{font-size:11px;font-weight:700}
.uk-item .uk-info{font-size:9px;color:var(--hint);margin-top:1px}
.uk-item .uk-bar{height:4px;border-radius:2px;background:rgba(255,255,255,.06);margin-top:3px;overflow:hidden}
.uk-item .uk-bar-fill{height:100%;border-radius:2px;background:var(--red);transition:width .5s}
.uk-item .uk-count{font-size:10px;font-weight:800;color:var(--red);float:right}
.fab{position:fixed;bottom:60px;right:8px;z-index:1001;width:56px;height:56px;border:none;
cursor:pointer;display:flex;align-items:center;justify-content:center;
background:transparent;padding:0;transition:transform .2s}
.fab:active{transform:scale(.88)}
.fab-drop{width:56px;height:56px;position:relative;display:flex;align-items:center;justify-content:center}
.fab-drop svg{width:56px;height:56px;filter:drop-shadow(0 4px 12px rgba(0,0,0,.5))}
.fab-drop .drop-fill{fill:url(#oilGrad)}
.fab-ring{position:absolute;inset:-6px;border-radius:50%;border:2px solid var(--accent);
opacity:0;animation:fabPulse 2s ease-out infinite}
.fab-ring2{position:absolute;inset:-12px;border-radius:50%;border:1.5px solid var(--accent);
opacity:0;animation:fabPulse 2s ease-out .5s infinite}
.fab-icon{position:absolute;font-size:22px;color:#fff;font-weight:900;text-shadow:0 1px 4px rgba(0,0,0,.4)}
@keyframes fabPulse{0%{transform:scale(.8);opacity:.6}100%{transform:scale(1.3);opacity:0}}
.cf-overlay{position:fixed;inset:0;z-index:3000;background:rgba(0,0,0,.6);backdrop-filter:blur(4px);
display:none;align-items:flex-end;justify-content:center}
.cf-overlay.show{display:flex}
.cf-sheet{width:100%;max-width:400px;background:var(--surface);backdrop-filter:var(--glass);
border-radius:18px 18px 0 0;padding:14px 14px 20px;border:1px solid rgba(255,255,255,.07);
max-height:80vh;overflow-y:auto;animation:sheetUp .3s ease}
@keyframes sheetUp{from{transform:translateY(100%)}to{transform:translateY(0)}}
.cf-sheet h3{font-size:14px;font-weight:700;margin-bottom:8px;text-align:center}
.cf-sheet .cf-field{margin-bottom:6px}
.cf-sheet label{font-size:8px;color:var(--hint);text-transform:uppercase;letter-spacing:1px;display:block;margin-bottom:2px}
.cf-sheet input,.cf-sheet textarea,.cf-sheet select{width:100%;padding:7px 9px;border-radius:8px;
border:1px solid rgba(255,255,255,.08);background:rgba(255,255,255,.04);color:var(--text);
font-size:11px;font-family:inherit;outline:none;transition:.2s}
.cf-sheet input:focus,.cf-sheet textarea:focus,.cf-sheet select:focus{border-color:var(--accent)}
.cf-sheet textarea{resize:vertical;min-height:50px}
.cf-sheet select{appearance:none;padding-right:24px}
.cf-sheet select option{background:#1a1f2e;color:#e2e8f0}
.cf-btns{display:flex;gap:6px;margin-top:8px}
.cf-btn{flex:1;padding:9px;border-radius:10px;border:none;font-size:11px;font-weight:700;cursor:pointer;transition:.2s}
.cf-btn.primary{background:var(--accent);color:#fff}
.cf-btn.secondary{background:rgba(255,255,255,.05);color:var(--hint)}
.cf-btn:active{transform:scale(.96)}
.cf-gps{font-size:9px;color:var(--accent);cursor:pointer;display:inline-flex;align-items:center;gap:3px}
.cf-gps:hover{text-decoration:underline}
\`;
document.head.appendChild(S2);


// ═══ Helpers ═══
function mkIcon(cat,isNew){
  var col=CC[cat]||'#6366f1';var e=CE[cat]||'📌';
  var cls=isNew?'new-marker':'';
  return L.divIcon({html:'<div style="width:28px;height:28px;border-radius:50%;background:'+col+';display:flex;align-items:center;justify-content:center;font-size:13px;border:2px solid rgba(255,255,255,.3);box-shadow:0 2px 8px '+col+'66" class="'+cls+'">'+e+'</div>',
    className:'',iconSize:[28,28],iconAnchor:[14,14],popupAnchor:[0,-16]})}
function fmtDate(s){if(!s)return'—';try{var d=new Date(s);return d.toLocaleDateString('ru-RU',{day:'2-digit',month:'short'})+' '+d.toLocaleTimeString('ru-RU',{hour:'2-digit',minute:'2-digit'})}catch(e){return String(s).substring(0,16)}}
function esc(s){return s?s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'):''}
function dateKey(d){return d.toISOString().slice(0,10)}
function parseDate(s){try{return new Date(s)}catch(e){return null}}
function showToast(t){var el=document.getElementById('newToast'),tx=document.getElementById('toastText');if(!el)return;
  tx.textContent=t;el.style.display='flex';el.classList.remove('hide');
  setTimeout(function(){el.classList.add('hide');setTimeout(function(){el.style.display='none'},300)},3000)}
function monthKey(d){return d.toISOString().slice(0,7)}

// ═══ Day filters ═══
function buildDayFilters(){
  var bar=document.getElementById('dayFilters');if(!bar)return;bar.innerHTML='';
  var months={};
  allItems.forEach(function(c){var d=parseDate(c.created_at);if(d){var mk=monthKey(d);months[mk]=(months[mk]||0)+1}});
  var sorted=Object.keys(months).sort().reverse().slice(0,12).reverse();
  if(!sorted.length)return;
  var all=document.createElement('span');all.className='chip day'+(filterMonth===null&&filterDay===null?' active':'');
  all.innerHTML='<span class="dn">Все</span>';
  all.onclick=function(){filterMonth=null;filterDay=null;buildDayFilters();render();drawTimeline()};
  bar.appendChild(all);
  sorted.forEach(function(mk){
    var ch=document.createElement('span');
    var parts=mk.split('-');var mIdx=parseInt(parts[1])-1;
    ch.className='chip day'+(filterMonth===mk?' active':'');
    ch.innerHTML='<span class="dn">'+MON_RU[mIdx]+'</span><span class="dd">'+months[mk]+'</span>';
    ch.onclick=function(){
      if(filterMonth===mk){filterMonth=null;filterDay=null}else{filterMonth=mk;filterDay=null}
      buildDayFilters();render();drawTimeline()};
    bar.appendChild(ch);
  });
  if(filterMonth){
    var dayBar=document.createElement('div');dayBar.className='fp-row';dayBar.style.marginTop='2px';
    var days={};
    allItems.forEach(function(c){var d=parseDate(c.created_at);if(d&&monthKey(d)===filterMonth){var dk=dateKey(d);days[dk]=(days[dk]||0)+1}});
    var sortedDays=Object.keys(days).sort().reverse();
    sortedDays.forEach(function(dk){
      var ch=document.createElement('span');var dd=new Date(dk);
      ch.className='chip day'+(filterDay===dk?' active':'');
      ch.innerHTML='<span class="dn">'+dd.getDate()+'</span><span class="dd">'+days[dk]+'</span>';
      ch.onclick=function(){filterDay=filterDay===dk?null:dk;buildDayFilters();render();drawTimeline()};
      dayBar.appendChild(ch);
    });
    bar.parentNode.insertBefore(dayBar,bar.nextSibling);
  }
}

// ═══ Category filters ═══
function buildCatFilters(){
  var bar=document.getElementById('catFilters');if(!bar)return;bar.innerHTML='';
  var cats={};allItems.forEach(function(c){if(c.category)cats[c.category]=(cats[c.category]||0)+1});
  var sorted=Object.entries(cats).sort(function(a,b){return b[1]-a[1]});
  var wrap=document.createElement('div');wrap.style.cssText='position:relative;display:inline-block';
  var btn=document.createElement('span');
  btn.className='chip'+(filterCat?' active':'');
  btn.textContent=filterCat?((CE[filterCat]||'')+' '+filterCat):'🏷️ Категория';
  var menu=document.createElement('div');
  menu.style.cssText='display:none;position:absolute;top:100%;left:0;z-index:2000;background:rgba(12,16,30,.96);backdrop-filter:blur(16px);border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:4px 0;max-height:260px;overflow-y:auto;min-width:200px;box-shadow:0 8px 32px rgba(0,0,0,.5)';
  var allOpt=document.createElement('div');
  allOpt.style.cssText='padding:5px 10px;font-size:10px;cursor:pointer;color:'+(filterCat?'var(--hint)':'var(--accentL)');
  allOpt.textContent='Все категории';
  allOpt.onclick=function(){filterCat=null;menu.style.display='none';buildCatFilters();render();drawTimeline()};
  menu.appendChild(allOpt);
  sorted.forEach(function(e){
    var opt=document.createElement('div');
    opt.style.cssText='padding:4px 10px;font-size:10px;cursor:pointer;display:flex;align-items:center;gap:5px;color:'+(filterCat===e[0]?'var(--accentL)':'var(--hint)');
    var dot=document.createElement('span');dot.style.cssText='width:6px;height:6px;border-radius:50%;background:'+(CC[e[0]]||'#666');
    opt.appendChild(dot);opt.appendChild(document.createTextNode((CE[e[0]]||'')+' '+e[0]+' ('+e[1]+')'));
    opt.onclick=function(){filterCat=e[0];menu.style.display='none';buildCatFilters();render();drawTimeline()};
    menu.appendChild(opt);
  });
  btn.onclick=function(ev){ev.stopPropagation();menu.style.display=menu.style.display==='none'?'block':'none'};
  document.addEventListener('click',function(){menu.style.display='none'});
  wrap.appendChild(btn);wrap.appendChild(menu);bar.appendChild(wrap);
}

// ═══ Status filters ═══
function buildStatusFilters(){
  var bar=document.getElementById('statusFilters');if(!bar)return;bar.innerHTML='';
  var all=document.createElement('span');all.className='chip'+(filterStatus===null?' active':'');
  all.textContent='Все';all.onclick=function(){filterStatus=null;buildStatusFilters();render();drawTimeline()};
  bar.appendChild(all);
  Object.entries(SL).forEach(function(e){
    var ch=document.createElement('span');
    var cls='chip st-'+e[0].replace('in_progress','progress');
    ch.className=cls+(filterStatus===e[0]?' active':'');
    ch.textContent=e[1];
    ch.onclick=function(){filterStatus=filterStatus===e[0]?null:e[0];buildStatusFilters();render();drawTimeline()};
    bar.appendChild(ch);
  });
}
function buildAllFilters(){buildDayFilters();buildCatFilters();buildStatusFilters()}

// ═══ Timeline ═══
function drawTimeline(){
  var canvas=document.getElementById('tlCanvas');if(!canvas)return;
  var ctx=canvas.getContext('2d');var W=canvas.offsetWidth,H=canvas.offsetHeight;
  canvas.width=W*2;canvas.height=H*2;ctx.scale(2,2);ctx.clearRect(0,0,W,H);
  var days={};
  allItems.forEach(function(c){var d=parseDate(c.created_at);if(!d)return;
    if(filterCat&&c.category!==filterCat)return;
    if(filterStatus&&c.status!==filterStatus)return;
    var dk=dateKey(d);days[dk]=(days[dk]||0)+1});
  var keys=Object.keys(days).sort();if(!keys.length)return;
  var max=Math.max.apply(null,Object.values(days));
  var barW=Math.max(2,Math.min(8,(W-20)/keys.length-1));
  var startX=(W-keys.length*(barW+1))/2;
  keys.forEach(function(k,i){
    var h=max?(days[k]/max)*(H-12):0;
    var x=startX+i*(barW+1);
    ctx.fillStyle=(filterDay===k||filterMonth===k.slice(0,7))?'rgba(99,102,241,.8)':'rgba(99,102,241,.3)';
    ctx.fillRect(x,H-4-h,barW,h);
  });
}

// ═══ Render markers ═══
function render(){
  if(!mapReady||!cluster)return;cluster.clearLayers();
  var total=0,open=0,pending=0,resolved=0;
  allItems.forEach(function(c){
    if(filterCat&&c.category!==filterCat)return;
    if(filterStatus&&c.status!==filterStatus)return;
    if(filterMonth){var d=parseDate(c.created_at);if(!d||monthKey(d)!==filterMonth)return;
      if(filterDay&&dateKey(d)!==filterDay)return}
    total++;
    if(c.status==='open')open++;else if(c.status==='pending')pending++;else if(c.status==='resolved')resolved++;
    if(c.lat&&c.lng){
      var m=L.marker([c.lat,c.lng],{icon:mkIcon(c.category,c._isNew)});
      m.bindPopup(buildPopup(c,c.lat,c.lng),{maxWidth:280});
      cluster.addLayer(m)}
  });
  map.addLayer(cluster);
  var st=document.getElementById('st'),so=document.getElementById('so'),sw=document.getElementById('sw'),sr=document.getElementById('sr');
  if(st)st.textContent=total;if(so)so.textContent=open;if(sw)sw.textContent=pending;if(sr)sr.textContent=resolved;
}

// ═══ Popup ═══
function buildPopup(c,lat,lng){
  var col=CC[c.category]||'#6366f1';var e=CE[c.category]||'📌';
  var st=SL[c.status]||c.status;var sc=SC[c.status]||'#94a3b8';
  var sup=c.supporters||0;
  var likes=c.likes||0;var dislikes=c.dislikes||0;
  var h='<div class="pp">';
  h+='<h3>'+e+' '+esc(c.category)+'</h3>';
  h+='<span class="badge" style="background:'+sc+'">'+st+'</span>';
  if(c.source_name)h+='<span class="src">'+esc(c.source_name)+'</span>';
  h+='<div class="desc">'+esc((c.summary||c.text||'').substring(0,200))+'</div>';
  if(c.address)h+='<div class="meta">📍 <b>'+esc(c.address)+'</b></div>';
  h+='<div class="meta">📅 '+fmtDate(c.created_at)+'</div>';
  h+='<div class="vote-row">';
  h+='<button class="vote-btn" onclick="voteComplaint(\\''+c.id+'\\',1,this)" title="Проблема решена хорошо">👍 <span id="vl_'+c.id+'">'+likes+'</span></button>';
  h+='<button class="vote-btn" onclick="voteComplaint(\\''+c.id+'\\',-1,this)" title="Проблема не решена">👎 <span id="vd_'+c.id+'">'+dislikes+'</span></button>';
  if(c.status!=='resolved'){
    h+='<button onclick="joinComplaint(\\''+c.id+'\\')" id="jbtn_'+c.id+'" style="';
    h+='padding:3px 8px;border-radius:14px;border:1px solid var(--accent);background:rgba(99,102,241,.12);';
    h+='color:var(--accentL);font-size:9px;font-weight:700;cursor:pointer">✊ +1</button>'}
  h+='</div>';
  if(sup>=10)h+='<div class="meta" style="color:var(--green);font-size:8px;margin-top:1px">📧 Отправлено в УК</div>';
  h+='<div class="links">';
  h+='<a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint='+lat+','+lng+'" target="_blank">👁 Street View</a>';
  h+='<a href="https://yandex.ru/maps/?pt='+lng+','+lat+'&z=17&l=map" target="_blank">🗺 Яндекс</a>';
  h+='</div>';
  if(c.uk_name)h+='<div class="meta" style="margin-top:2px">🏢 <b>'+esc(c.uk_name)+'</b></div>';
  if(c.uk_phone)h+='<div class="meta">📞 <a href="tel:'+c.uk_phone.replace(/[^\\d+]/g,'')+'">'+esc(c.uk_phone)+'</a></div>';
  h+='</div>';return h;
}

function joinComplaint(id){
  var btn=document.getElementById('jbtn_'+id);if(btn)btn.textContent='⏳...';
  fetch(FB.replace('/firebase','') +'/api/join',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({complaint_id:id})
  }).then(function(r){return r.json()}).then(function(d){
    if(d.supporters!==undefined){
      if(btn)btn.textContent='✅ +1';
      showToast('✊ Вы присоединились! ('+d.supporters+')')
    }
  }).catch(function(){if(btn)btn.textContent='❌'});
}

function voteComplaint(id,dir,btn){
  var item=allItems.find(function(c){return c.id===id});
  if(!item)return;
  if(dir===1){item.likes=(item.likes||0)+1;var el=document.getElementById('vl_'+id);if(el)el.textContent=item.likes;btn.classList.add('liked')}
  else{item.dislikes=(item.dislikes||0)+1;var el2=document.getElementById('vd_'+id);if(el2)el2.textContent=item.dislikes;btn.classList.add('disliked')}
  var patch={};patch[dir===1?'likes':'dislikes']=dir===1?(item.likes||0):(item.dislikes||0);
  fetch(FB+'/complaints/'+id+'.json',{method:'PATCH',headers:{'Content-Type':'application/json'},
    body:JSON.stringify(patch)}).catch(function(){});
  buildUkRating();
  showToast(dir===1?'👍 Спасибо за оценку!':'👎 Учтено в рейтинге');
  try{tg&&tg.HapticFeedback&&tg.HapticFeedback.impactOccurred('light')}catch(e){}
}

// ═══ Stats overlay ═══
function buildStatsOverlay(){
  var ov=document.getElementById('statsOverlay');if(!ov)return;
  var total=allItems.length,open=0,pending=0,resolved=0,inProgress=0;
  var cats={},sources={},ukStats={},weekly=0,monthly=0;
  var now=new Date(),weekAgo=new Date(now-7*86400000),monthAgo=new Date(now-30*86400000);
  allItems.forEach(function(c){
    if(c.status==='open')open++;else if(c.status==='pending')pending++;
    else if(c.status==='resolved')resolved++;else if(c.status==='in_progress')inProgress++;
    if(c.category)cats[c.category]=(cats[c.category]||0)+1;
    var src=c.source_name||c.source||'—';sources[src]=(sources[src]||0)+1;
    if(c.uk_name)ukStats[c.uk_name]=(ukStats[c.uk_name]||0)+1;
    var d=parseDate(c.created_at);
    if(d){if(d>=weekAgo)weekly++;if(d>=monthAgo)monthly++}
  });
  var html='<h3>📊 Статистика реалтайм</h3>';
  html+='<div class="so-row"><span class="so-label">Всего жалоб</span><span class="so-val">'+total+'</span></div>';
  html+='<div class="so-row"><span class="so-label">🔴 Открыто</span><span class="so-val" style="color:var(--red)">'+open+'</span></div>';
  html+='<div class="so-row"><span class="so-label">🟡 Новые</span><span class="so-val" style="color:var(--yellow)">'+pending+'</span></div>';
  html+='<div class="so-row"><span class="so-label">🟠 В работе</span><span class="so-val" style="color:var(--orange)">'+inProgress+'</span></div>';
  html+='<div class="so-row"><span class="so-label">✅ Решено</span><span class="so-val" style="color:var(--green)">'+resolved+'</span></div>';
  html+='<div class="so-row"><span class="so-label">📅 За неделю</span><span class="so-val">'+weekly+'</span></div>';
  html+='<div class="so-row"><span class="so-label">📅 За месяц</span><span class="so-val">'+monthly+'</span></div>';
  if(total)html+='<div class="so-row"><span class="so-label">✅ Решено %</span><span class="so-val" style="color:var(--green)">'+Math.round(resolved/total*100)+'%</span></div>';
  html+='<div class="so-section"><h4>Топ категорий</h4>';
  var topCats=Object.entries(cats).sort(function(a,b){return b[1]-a[1]}).slice(0,8);
  var maxCat=topCats.length?topCats[0][1]:1;
  topCats.forEach(function(e){
    html+='<div class="so-bar-wrap"><div class="so-bar-label"><span>'+(CE[e[0]]||'')+' '+e[0]+'</span><span>'+e[1]+'</span></div>';
    html+='<div class="so-bar"><div class="so-bar-fill" style="width:'+Math.round(e[1]/maxCat*100)+'%;background:'+(CC[e[0]]||'var(--accent)')+'"></div></div></div>';
  });
  html+='</div>';
  html+='<div class="so-section"><h4>Источники</h4>';
  Object.entries(sources).sort(function(a,b){return b[1]-a[1]}).slice(0,6).forEach(function(e){
    html+='<div class="so-row"><span class="so-label">'+esc(e[0])+'</span><span class="so-val">'+e[1]+'</span></div>';
  });
  html+='</div>';
  ov.innerHTML='<button class="so-close" onclick="document.getElementById(\\'statsOverlay\\').classList.remove(\\'open\\')">&times;</button>'+html;
}

// ═══ UK Rating ═══
var UK_CATS=['ЖКХ','Отопление','Водоснабжение и канализация','Газоснабжение','Лифты и подъезды','Бытовой мусор','Освещение'];
var ADMIN_CATS=['Дороги','Благоустройство','Транспорт','Экология','Снег/Наледь','Парковки','Строительство','Парки и скверы','Спортивные площадки','Детские площадки','Безопасность','ЧП'];
var allUkData=null;

function loadUkOpendata(){
  if(allUkData)return Promise.resolve(allUkData);
  return fetch(FB+'/opendata_infographic.json',{signal:AbortSignal.timeout(6000)})
    .then(function(r){return r.json()})
    .then(function(d){if(d&&d.uk&&d.uk.top){allUkData=d.uk;return allUkData}return null})
    .catch(function(){return null});
}

function sendAnonEmail(ukName,ukEmail){
  var desc=prompt('Опишите проблему для '+ukName+':');
  if(!desc||!desc.trim())return;
  var addr=prompt('Адрес (необязательно):','');
  showToast('📧 Отправляю...');
  var body='Уважаемая '+ukName+',\\n\\nЧерез систему «Пульс города» поступила анонимная жалоба:\\n\\n'+desc;
  if(addr)body+='\\n\\nАдрес: '+addr;
  body+='\\n\\nПросим рассмотреть и принять меры.\\nС уважением, Пульс города — Нижневартовск';
  fetch(FB.replace('/firebase','')+'/send-email',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({to_email:ukEmail,to_name:ukName,subject:'Анонимная жалоба — Пульс города',body:body,from_name:'Пульс города'})
  }).then(function(r){return r.json()}).then(function(d){
    showToast(d.ok?'✅ Отправлено в '+ukName:'❌ Ошибка отправки')
  }).catch(function(){showToast('❌ Ошибка сети')});
}
function legalAnalysis(ukName){
  var desc=prompt('Опишите проблему для юридического анализа ('+ukName+'):');
  if(!desc||!desc.trim())return;
  var url='https://t.me/pulsenvbot?start=legal_'+encodeURIComponent(ukName.substring(0,30));
  window.open(url,'_blank');
  showToast('⚖️ Откройте бот @pulsenvbot и отправьте описание проблемы');
}
function ukDetails(idx){
  var el=document.getElementById('ukDet_'+idx);
  if(!el)return;
  el.style.display=el.style.display==='none'?'block':'none';
}

// ═══ UK Rating overlay ═══
function buildUkRating(){
  var ov=document.getElementById('ukOverlay');if(!ov)return;
  var ukStats={},adminStats={total:0,open:0,resolved:0,likes:0,dislikes:0};
  allItems.forEach(function(c){
    var isUkCat=UK_CATS.indexOf(c.category)>=0;
    var isAdminCat=ADMIN_CATS.indexOf(c.category)>=0;
    if(isAdminCat){adminStats.total++;if(c.status==='resolved')adminStats.resolved++;else adminStats.open++;adminStats.likes+=(c.likes||0);adminStats.dislikes+=(c.dislikes||0)}
    if(c.uk_name&&isUkCat){
      if(!ukStats[c.uk_name])ukStats[c.uk_name]={total:0,open:0,resolved:0,cats:{},likes:0,dislikes:0};
      ukStats[c.uk_name].total++;
      if(c.status==='resolved')ukStats[c.uk_name].resolved++;else ukStats[c.uk_name].open++;
      ukStats[c.uk_name].cats[c.category]=(ukStats[c.uk_name].cats[c.category]||0)+1;
      ukStats[c.uk_name].likes+=(c.likes||0);ukStats[c.uk_name].dislikes+=(c.dislikes||0);
    }
  });
  var sorted=Object.entries(ukStats).sort(function(a,b){return b[1].total-a[1].total});
  var maxUk=sorted.length?sorted[0][1].total:1;
  var html='<h3>🏢 Рейтинг УК</h3>';
  html+='<div style="font-size:9px;color:var(--hint);margin-bottom:4px">Только жалобы по компетенции УК (ЖКХ, отопление, вода, газ, лифты, мусор, свет)</div>';
  var apct=adminStats.total?Math.round(adminStats.resolved/adminStats.total*100):0;
  html+='<div class="uk-item" style="background:rgba(99,102,241,.08);border-radius:10px;padding:8px;margin-bottom:8px">';
  html+='<div style="display:flex;justify-content:space-between;align-items:center">';
  html+='<span class="uk-name" style="color:var(--accentL)">🏛️ Администрация города</span>';
  html+='<span class="uk-count" style="color:var(--accentL)">'+adminStats.total+'</span></div>';
  html+='<div class="uk-info">Дороги, благоустройство, транспорт, экология, безопасность, ЧП</div>';
  html+='<div class="uk-info">✅ '+adminStats.resolved+' ('+apct+'%) · 🔴 '+adminStats.open+' · 👍 '+adminStats.likes+' · 👎 '+adminStats.dislikes+'</div>';
  html+='<div class="uk-bar"><div class="uk-bar-fill" style="width:100%;background:'+(apct>50?'var(--green)':apct>20?'var(--yellow)':'var(--red)')+'"></div></div>';
  html+='<div style="margin-top:4px"><span onclick="sendAnonEmail(\\'Администрация г. Нижневартовска\\',\\'nvartovsk@n-vartovsk.ru\\')" style="font-size:9px;color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ Написать анонимно</span></div>';
  html+='</div>';
  html+='<div style="font-size:10px;font-weight:700;margin:8px 0 4px;color:var(--text)">Управляющие компании ('+sorted.length+' с жалобами)</div>';
  sorted.forEach(function(e,i){
    var uk=e[1];var pct=uk.total?Math.round(uk.resolved/uk.total*100):0;
    var topCat=Object.entries(uk.cats).sort(function(a,b){return b[1]-a[1]});
    var catLine=topCat.slice(0,3).map(function(c){return(CE[c[0]]||'')+c[1]}).join(' ');
    html+='<div class="uk-item" id="uk_'+i+'">';
    html+='<div style="display:flex;justify-content:space-between;align-items:center">';
    html+='<span class="uk-name">'+(i+1)+'. '+esc(e[0])+'</span>';
    html+='<span class="uk-count">'+uk.total+'</span></div>';
    html+='<div class="uk-info">'+catLine+' · ✅ '+uk.resolved+' ('+pct+'%) · 🔴 '+uk.open+' · 👍 '+uk.likes+' · 👎 '+uk.dislikes+'</div>';
    html+='<div class="uk-bar"><div class="uk-bar-fill" style="width:'+Math.round(uk.total/maxUk*100)+'%;background:'+(pct>50?'var(--green)':pct>20?'var(--yellow)':'var(--red)')+'"></div></div>';
    html+='<div style="display:flex;gap:8px;margin-top:4px;flex-wrap:wrap">';
    html+='<span onclick="legalAnalysis(\\''+esc(e[0]).replace(/'/g,"\\\\'")+'\\')\\" style="font-size:9px;color:var(--yellow);cursor:pointer;text-decoration:underline">⚖️ Юр. анализ</span>';
    html+='<span onclick="ukDetails('+i+')" style="font-size:9px;color:var(--hint);cursor:pointer;text-decoration:underline">📋 Подробнее</span>';
    html+='</div>';
    html+='<div id="ukDet_'+i+'" style="display:none;margin-top:4px;padding:4px 6px;background:rgba(255,255,255,.03);border-radius:6px;font-size:9px;color:var(--hint)">Загрузка...</div>';
    html+='</div>';
  });
  loadUkOpendata().then(function(ukOd){
    if(!ukOd||!ukOd.top)return;
    var existing=new Set(sorted.map(function(e){return e[0]}));
    var allUks=ukOd.top||[];
    sorted.forEach(function(e,i){
      var det=document.getElementById('ukDet_'+i);
      if(!det)return;
      var match=allUks.find(function(u){return u.name===e[0]});
      if(match){
        var d='';
        if(match.address)d+='📍 '+esc(match.address)+'<br>';
        if(match.phone)d+='📞 '+esc(match.phone)+'<br>';
        if(match.director)d+='👤 '+esc(match.director)+'<br>';
        if(match.houses)d+='🏠 '+match.houses+' домов<br>';
        if(match.url)d+='🌐 <a href="'+match.url+'" target="_blank" style="color:var(--accentL)">Сайт</a><br>';
        if(match.email)d+='<span onclick="sendAnonEmail(\\''+esc(match.name).replace(/'/g,"\\\\'")+'\\',\\''+match.email+'\\')" style="color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ '+match.email+'</span>';
        det.innerHTML=d||'Нет данных';
      }else{det.innerHTML='Нет данных в реестре'}
    });
    var noComplaints=allUks.filter(function(u){return !existing.has(u.name)});
    if(!noComplaints.length)return;
    var extra='<div style="font-size:10px;font-weight:700;margin:12px 0 4px;color:var(--hint)">Без жалоб ('+noComplaints.length+')</div>';
    noComplaints.forEach(function(u){
      extra+='<div class="uk-item" style="opacity:.7">';
      extra+='<div style="display:flex;justify-content:space-between;align-items:center">';
      extra+='<span class="uk-name" style="font-size:10px">✅ '+esc(u.name)+'</span>';
      extra+='<span style="font-size:9px;color:var(--green)">'+u.houses+' домов</span></div>';
      if(u.address)extra+='<div style="font-size:8px;color:var(--hint);margin-top:1px">📍 '+esc(u.address)+'</div>';
      if(u.phone)extra+='<div style="font-size:8px;color:var(--hint)">📞 '+esc(u.phone)+'</div>';
      extra+='<div style="display:flex;gap:8px;margin-top:2px;flex-wrap:wrap">';
      if(u.email)extra+='<span onclick="sendAnonEmail(\\''+esc(u.name).replace(/'/g,"\\\\'")+'\\',\\''+u.email+'\\')" style="font-size:9px;color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ Написать</span>';
      extra+='<span onclick="legalAnalysis(\\''+esc(u.name).replace(/'/g,"\\\\'")+'\\')\\" style="font-size:9px;color:var(--yellow);cursor:pointer;text-decoration:underline">⚖️ Юр. анализ</span>';
      extra+='</div></div>';
    });
    var container=document.getElementById('ukExtraList');
    if(container)container.innerHTML=extra;
  });
  html+='<div id="ukExtraList"></div>';
  if(!sorted.length&&!allUkData)html+='<div style="font-size:11px;color:var(--hint);padding:20px 0;text-align:center">Загрузка данных УК...</div>';
  ov.innerHTML='<button class="uk-close" onclick="document.getElementById(\\'ukOverlay\\').classList.remove(\\'open\\')">&times;</button>'+html;
}

// ═══ Data + Realtime ═══
async function loadFB(){
  var r=await fetch(FB+'/complaints.json',{signal:AbortSignal.timeout(8000)});
  if(!r.ok)throw new Error('Firebase: '+r.status);
  var data=await r.json();if(!data)return[];
  return Object.entries(data).map(function(e){return Object.assign({id:e[0]},e[1])});
}
function startSync(){if(syncIv)return;
  syncIv=setInterval(async function(){try{
    var items=await loadFB();if(!items.length)return;
    var nw=items.filter(function(c){return !knownIds.has(c.id)});
    if(nw.length){nw.forEach(function(c){c._isNew=true;allItems.unshift(c);knownIds.add(c.id)});
      allItems.sort(function(a,b){return new Date(b.created_at||0)-new Date(a.created_at||0)});
      render();buildAllFilters();buildStatsOverlay();buildUkRating();
      showToast(nw.length===1?(CE[nw[0].category]||'📌')+' '+(nw[0].summary||nw[0].category).substring(0,50):'🔔 +'+nw.length+' новых');
      setTimeout(function(){nw.forEach(function(c){c._isNew=false})},2000);
      try{tg&&tg.HapticFeedback&&tg.HapticFeedback.impactOccurred('medium')}catch(e){}}
    items.forEach(function(c){if(knownIds.has(c.id)){var ex=allItems.find(function(a){return a.id===c.id});if(ex&&ex.status!==c.status)ex.status=c.status}});
  }catch(e){console.warn('Sync:',e)}},15000)}

function initMap(){
  map=L.map('map',{zoomControl:false}).setView([60.9344,76.5531],13);
  L.control.zoom({position:'topright'}).addTo(map);
  L.maplibreGL({
    style:'https://tiles.openfreemap.org/styles/positron',
    attribution:'© OpenStreetMap contributors',
    pane:'tilePane'
  }).addTo(map);
  cluster=L.markerClusterGroup({maxClusterRadius:50,showCoverageOnHover:false,zoomToBoundsOnClick:true,spiderfyOnMaxZoom:true,
    iconCreateFunction:function(c){var n=c.getChildCount(),s=n<10?30:n<50?38:46;
      return L.divIcon({html:'<div style="width:'+s+'px;height:'+s+'px;border-radius:50%;background:rgba(99,102,241,.85);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:11px;border:2px solid rgba(255,255,255,.3);box-shadow:0 2px 10px rgba(99,102,241,.4)">'+n+'</div>',className:'',iconSize:[s,s]})}});
  mapReady=true;
}

async function loadData(){
  splashProg(10,'Подключение к Firebase...');
  try{
    var items=await loadFB();
    splashProg(50,'Обработка '+items.length+' жалоб...');
    if(!items.length){splashProg(100,'Нет данных');setTimeout(function(){hideSplash();initMap()},800);return}
    items.sort(function(a,b){return new Date(b.created_at||0)-new Date(a.created_at||0)});
    allItems=items;items.forEach(function(c){knownIds.add(c.id)});
    splashProg(70,'Анализ настроения...');
    var mood=analyzeMood(items);applyMood(mood);splashStats(mood);
    splashProg(90,'Карта...');await new Promise(function(r){setTimeout(r,600)});
    initMap();buildAllFilters();render();drawTimeline();
    buildStatsOverlay();buildUkRating();
    splashProg(100,'Готово!');await new Promise(function(r){setTimeout(r,400)});
    hideSplash();startSync();
  }catch(e){console.error(e);splashProg(100,'Ошибка: '+e.message);setTimeout(function(){hideSplash();initMap()},1500)}
}
loadData();

// ═══ Stats + UK buttons ═══
(function(){
  var statsBtn=document.getElementById('statsBtn');
  var statsOv=document.getElementById('statsOverlay');
  var ukBtn=document.getElementById('ukBtn');
  var ukOv=document.getElementById('ukOverlay');
  if(statsBtn&&statsOv){
    statsBtn.onclick=function(){
      buildStatsOverlay();statsOv.classList.toggle('open');
      if(ukOv)ukOv.classList.remove('open');
    };
  }
  if(ukBtn&&ukOv){
    ukBtn.onclick=function(){
      buildUkRating();ukOv.classList.toggle('open');
      if(statsOv)statsOv.classList.remove('open');
    };
  }
})();

// ═══ Complaint form from map ═══
(function(){
  var overlay=document.getElementById('cfOverlay');
  var fab=document.getElementById('fabNew');
  var catSel=document.getElementById('cfCat');
  var descEl=document.getElementById('cfDesc');
  var addrEl=document.getElementById('cfAddr');
  var latEl=document.getElementById('cfLat');
  var lngEl=document.getElementById('cfLng');
  var gpsBtn=document.getElementById('cfGps');
  var cancelBtn=document.getElementById('cfCancel');
  var submitBtn=document.getElementById('cfSubmit');
  if(!fab||!overlay)return;

  var allCats=Object.keys(CE);
  allCats.forEach(function(cat){
    var opt=document.createElement('option');
    opt.value=cat;opt.textContent=(CE[cat]||'')+' '+cat;
    catSel.appendChild(opt);
  });

  fab.onclick=function(){overlay.classList.add('show')};
  cancelBtn.onclick=function(){overlay.classList.remove('show')};
  overlay.onclick=function(e){if(e.target===overlay)overlay.classList.remove('show')};

  gpsBtn.onclick=function(){
    if(!navigator.geolocation){showToast('GPS недоступен');return}
    gpsBtn.textContent='⏳ Определяю...';
    navigator.geolocation.getCurrentPosition(function(pos){
      var lat=pos.coords.latitude,lng=pos.coords.longitude;
      latEl.value=lat.toFixed(6);lngEl.value=lng.toFixed(6);
      gpsBtn.textContent='✅ Координаты получены';
      fetch('https://nominatim.openstreetmap.org/reverse?format=json&lat='+lat+'&lon='+lng+'&accept-language=ru')
        .then(function(r){return r.json()})
        .then(function(d){
          if(d&&d.address){var a=d.address;var parts=[];
            if(a.road)parts.push(a.road);if(a.house_number)parts.push(a.house_number);
            if(!parts.length&&d.display_name)parts.push(d.display_name.split(',')[0]);
            addrEl.value=parts.join(', ');gpsBtn.textContent='📍 '+addrEl.value}
        }).catch(function(){});
    },function(err){gpsBtn.textContent='❌ GPS';showToast('GPS: '+err.message)},{enableHighAccuracy:true,timeout:10000});
  };

  function enableMapClick(){
    if(!map)return;
    map.on('click',function(e){
      if(!overlay.classList.contains('show'))return;
      latEl.value=e.latlng.lat.toFixed(6);lngEl.value=e.latlng.lng.toFixed(6);
      fetch('https://nominatim.openstreetmap.org/reverse?format=json&lat='+e.latlng.lat+'&lon='+e.latlng.lng+'&accept-language=ru')
        .then(function(r){return r.json()})
        .then(function(d){if(d&&d.address){var a=d.address;var parts=[];
          if(a.road)parts.push(a.road);if(a.house_number)parts.push(a.house_number);
          if(!parts.length&&d.display_name)parts.push(d.display_name.split(',')[0]);
          addrEl.value=parts.join(', ')}}).catch(function(){});
    });
  }
  var origInit=initMap;
  initMap=function(){origInit();enableMapClick()};

  submitBtn.onclick=function(){
    var cat=catSel.value,desc=descEl.value.trim(),addr=addrEl.value.trim();
    var lat=parseFloat(latEl.value),lng=parseFloat(lngEl.value);
    if(!desc){showToast('Опишите проблему');return}
    submitBtn.textContent='⏳...';submitBtn.disabled=true;
    var now=new Date().toISOString();
    var complaint={category:cat,description:desc,summary:desc.substring(0,200),
      address:addr,lat:lat||null,lng:lng||null,
      status:'open',created_at:now,source:'webapp',source_name:'Карта',
      supporters:0,supporters_notified:0};
    fetch(FB+'/complaints.json',{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify(complaint)
    }).then(function(r){return r.json()}).then(function(d){
      if(d&&d.name){
        complaint.id=d.name;complaint._isNew=true;
        allItems.unshift(complaint);knownIds.add(complaint.id);
        render();buildAllFilters();buildStatsOverlay();buildUkRating();
        showToast('✅ Жалоба отправлена!');
        overlay.classList.remove('show');
        descEl.value='';addrEl.value='';latEl.value='';lngEl.value='';
        setTimeout(function(){complaint._isNew=false},2000);
        try{tg&&tg.HapticFeedback&&tg.HapticFeedback.notificationOccurred('success')}catch(e){}
      }else{showToast('Ошибка отправки')}
      submitBtn.textContent='Отправить';submitBtn.disabled=false;
    }).catch(function(e){
      showToast('Ошибка: '+e.message);
      submitBtn.textContent='Отправить';submitBtn.disabled=false;
    });
  };
})();

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

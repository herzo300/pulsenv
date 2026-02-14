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

    // --- Map Web App (для Telegram) ---
    if (path === "/map" || path === "/map/") {
      return new Response(MAP_HTML, {
        headers: { "Content-Type": "text/html;charset=utf-8", "Access-Control-Allow-Origin": "*" },
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
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,Roboto,sans-serif;
  background:var(--tg-theme-bg-color,#0a0a1a);color:var(--tg-theme-text-color,#fff);overflow:hidden}
#map{width:100%;height:100vh}
.hdr{position:fixed;top:10px;left:50%;transform:translateX(-50%);z-index:1000;
  background:rgba(10,10,26,.92);backdrop-filter:blur(12px);padding:8px 20px;border-radius:12px;
  border:1px solid rgba(0,180,255,.2);display:flex;align-items:center;gap:8px}
.hdr h1{font-size:15px;font-weight:800}.hdr small{font-size:9px;color:rgba(255,255,255,.4);letter-spacing:2px;display:block}
.pulse{width:8px;height:8px;border-radius:50%;background:#4caf50;animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
.panel{position:fixed;z-index:1000;background:rgba(10,10,26,.92);backdrop-filter:blur(12px);
  padding:10px 14px;border-radius:12px;border:1px solid rgba(0,180,255,.15);font-size:12px}
.stats{bottom:12px;left:10px;min-width:130px}
.stats h3{font-size:10px;color:rgba(255,255,255,.4);margin-bottom:6px;letter-spacing:1px;text-transform:uppercase}
.sr{display:flex;justify-content:space-between;padding:2px 0}
.sr .l{color:rgba(255,255,255,.4)}.sr .v{font-weight:700;font-size:13px}
.blue{color:#00b4ff}.green{color:#4caf50}.red{color:#ff5252}
.leg{bottom:12px;right:10px;max-height:200px;overflow-y:auto;max-width:160px}
.leg h3{font-size:10px;color:rgba(255,255,255,.4);margin-bottom:4px;letter-spacing:1px;text-transform:uppercase}
.li{display:flex;align-items:center;gap:5px;padding:1px 0;font-size:10px;color:rgba(255,255,255,.5)}
.ld{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.loader{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2000;
  background:rgba(10,10,26,.95);padding:18px 32px;border-radius:12px;
  border:1px solid rgba(0,180,255,.2);color:#fff;font-size:13px;display:flex;align-items:center;gap:10px}
.sp{width:20px;height:20px;border:3px solid rgba(0,180,255,.2);border-top-color:#00b4ff;border-radius:50%;animation:spin .8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.leaflet-popup-content-wrapper{background:rgba(10,10,26,.95)!important;color:#fff!important;
  border:1px solid rgba(0,180,255,.2)!important;border-radius:10px!important}
.leaflet-popup-tip{background:rgba(10,10,26,.95)!important}
.pp{min-width:180px}.pp h3{margin:0 0 4px;font-size:13px}
.pp p{margin:2px 0;font-size:11px;color:rgba(255,255,255,.6)}
.pp a{color:#00b4ff;text-decoration:none;font-size:11px}
.badge{display:inline-block;padding:2px 7px;border-radius:4px;font-size:9px;font-weight:600;color:#fff}
</style>
</head>
<body>
<div class="hdr"><div class="pulse"></div><div><h1>Пульс города</h1><small>НИЖНЕВАРТОВСК</small></div></div>
<div id="map"></div>
<div class="panel stats"><h3>Статистика</h3>
<div class="sr"><span class="l">Всего</span><span class="v blue" id="st">—</span></div>
<div class="sr"><span class="l">Открыто</span><span class="v red" id="so">—</span></div>
<div class="sr"><span class="l">Решено</span><span class="v green" id="sr">—</span></div></div>
<div class="panel leg" id="leg"><h3>Категории</h3></div>
<div class="loader" id="ld"><div class="sp"></div>Загрузка…</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"><\/script>
<script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"><\/script>
<script>
const tg=window.Telegram&&window.Telegram.WebApp;if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}
const FB='https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase';
const C={'Дороги':'#FF5722','ЖКХ':'#2196F3','Освещение':'#FFC107','Транспорт':'#4CAF50',
'Благоустройство':'#9C27B0','Экология':'#00BCD4','Животные':'#FF9800','Торговля':'#E91E63',
'Безопасность':'#F44336','Снег/Наледь':'#03A9F4','Медицина':'#009688','Образование':'#673AB7',
'Связь':'#3F51B5','Строительство':'#607D8B','Парковки':'#9E9E9E','Прочее':'#795548',
'ЧП':'#D32F2F','Газоснабжение':'#FF6F00','Водоснабжение и канализация':'#0288D1',
'Отопление':'#D84315','Бытовой мусор':'#689F38','Лифты и подъезды':'#455A64',
'Парки и скверы':'#388E3C','Спортивные площадки':'#1976D2','Детские площадки':'#F06292'};
const SL={pending:'Новая',open:'Открыта',in_progress:'В работе',resolved:'Решена'};
const SC={pending:'#FFC107',open:'#FF5252',in_progress:'#FF9800',resolved:'#4CAF50'};
const map=L.map('map',{zoomControl:false}).setView([60.9344,76.5531],13);
L.control.zoom({position:'topright'}).addTo(map);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OSM',maxZoom:19}).addTo(map);
const cl=L.markerClusterGroup({maxClusterRadius:50,showCoverageOnHover:false,
iconCreateFunction(c){const n=c.getChildCount(),s=n<10?34:n<50?42:50;
return L.divIcon({html:'<div style="width:'+s+'px;height:'+s+'px;border-radius:50%;background:rgba(0,140,255,.85);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:12px;border:2px solid rgba(255,255,255,.4);box-shadow:0 2px 10px rgba(0,140,255,.5)">'+n+'</div>',className:'',iconSize:[s,s]})}});
function ic(cat){const c=C[cat]||'#795548';return L.divIcon({className:'',
html:'<div style="width:24px;height:24px;border-radius:50%;background:'+c+';border:3px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.4)"></div>',
iconSize:[24,24],iconAnchor:[12,12]})}
function fd(s){if(!s)return'—';return new Date(s).toLocaleDateString('ru-RU',{day:'2-digit',month:'2-digit',year:'numeric'})}
async function load(){try{
const r=await fetch(FB+'/complaints.json');if(!r.ok)throw new Error(r.status);
const d=await r.json();if(!d){document.getElementById('ld').innerHTML='📭 Нет жалоб';return}
const items=Object.values(d);cl.clearLayers();
let t=0,o=0,rv=0;const cats={};
items.forEach(c=>{const lat=c.lat,lng=c.lng;if(!lat||!lng)return;t++;
const st=c.status||'open';if(st==='open'||st==='pending')o++;if(st==='resolved')rv++;
cats[c.category]=(cats[c.category]||0)+1;
const col=C[c.category]||'#795548',stC=SC[st]||'#9E9E9E',stL=SL[st]||st;
const m=L.marker([lat,lng],{icon:ic(c.category)});
let pp='<div class="pp"><h3 style="color:'+col+'">'+(c.category||'Прочее')+'</h3>';
pp+='<p><b>'+((c.summary||c.description||'—').substring(0,100))+'</b></p>';
pp+='<p>📍 '+(c.address||'—')+'</p><p>📅 '+fd(c.created_at)+'</p>';
pp+='<span class="badge" style="background:'+stC+'">'+stL+'</span>';
if(lat&&lng){pp+='<p><a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint='+lat+','+lng+'" target="_blank">👁 Street View</a> · <a href="https://www.google.com/maps/search/?api=1&query='+lat+','+lng+'" target="_blank">📌 Maps</a></p>'}
if(c.source_name)pp+='<p>📢 '+c.source_name+'</p>';
pp+='</div>';m.bindPopup(pp);cl.addLayer(m)});
map.addLayer(cl);if(t)try{map.fitBounds(cl.getBounds(),{padding:[40,40]})}catch(_){}
document.getElementById('st').textContent=t;
document.getElementById('so').textContent=o;
document.getElementById('sr').textContent=rv;
const leg=document.getElementById('leg');leg.innerHTML='<h3>Категории</h3>';
Object.entries(cats).sort((a,b)=>b[1]-a[1]).forEach(([cat,n])=>{
leg.innerHTML+='<div class="li"><div class="ld" style="background:'+(C[cat]||'#795548')+'"></div>'+cat+' ('+n+')</div>'});
document.getElementById('ld').style.display='none';
}catch(e){document.getElementById('ld').innerHTML='❌ '+e.message}}
load();setInterval(load,30000);
<\/script></body></html>`;

// ===== Инфографика — открытые данные Нижневартовска =====
const INFO_HTML = `<!DOCTYPE html><html lang="ru"><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Нижневартовск в цифрах</title>
<script src="https://telegram.org/js/telegram-web-app.js"><\/script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"><\/script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#050b18;--card:rgba(8,20,38,.92);--border:rgba(45,200,180,.12);
--accent:#2dc8b4;--a2:#6366f1;--a3:#22d3ee;
--text:#dce8f0;--muted:rgba(200,220,230,.35);--green:#34d399;--red:#f87171;--orange:#fbbf24;--purple:#a78bfa}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
background:var(--bg);color:var(--text);overflow-x:hidden;min-height:100vh}
@keyframes spin{to{transform:rotate(360deg)}}
@keyframes fadeUp{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:translateY(0)}}
@keyframes countUp{from{opacity:0;transform:scale(.8)}to{opacity:1;transform:scale(1)}}
@keyframes shimmer{0%{background-position:-200% 0}100%{background-position:200% 0}}
@keyframes glow{0%,100%{filter:brightness(1)}50%{filter:brightness(1.3)}}
@keyframes slideIn{from{opacity:0;transform:translateX(-20px)}to{opacity:1;transform:translateX(0)}}
@keyframes barGrow{from{width:0}to{width:var(--w)}}
#aurora{position:fixed;top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none}
#app{position:relative;z-index:1;padding-bottom:40px}
.hero{text-align:center;padding:32px 16px 20px;position:relative;overflow:hidden}
.hero::before{content:'';position:absolute;inset:0;
background:linear-gradient(180deg,rgba(45,200,180,.06) 0%,rgba(99,102,241,.04) 50%,transparent 100%)}
.hero h1{font-size:20px;font-weight:800;position:relative;
background:linear-gradient(135deg,#2dc8b4,#22d3ee,#6366f1,#2dc8b4);background-size:300% 300%;
-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;
animation:shimmer 4s ease infinite}
.hero .sub{font-size:10px;color:var(--muted);margin-top:4px;letter-spacing:3px;text-transform:uppercase;position:relative}
.hero .upd{font-size:11px;color:var(--accent);margin-top:8px;font-weight:600;position:relative;
display:inline-flex;align-items:center;gap:6px}
.hero .upd::before{content:'';width:6px;height:6px;border-radius:50%;background:var(--green);animation:glow 2s infinite}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding:12px 12px 0}
.card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:14px;
backdrop-filter:blur(16px);position:relative;overflow:hidden;
animation:fadeUp .6s ease both}
.card:nth-child(1){animation-delay:.05s}.card:nth-child(2){animation-delay:.1s}
.card:nth-child(3){animation-delay:.15s}.card:nth-child(4){animation-delay:.2s}
.card:nth-child(5){animation-delay:.25s}.card:nth-child(6){animation-delay:.3s}
.card:nth-child(7){animation-delay:.35s}.card:nth-child(8){animation-delay:.4s}
.card:nth-child(9){animation-delay:.45s}.card:nth-child(10){animation-delay:.5s}
.card:nth-child(11){animation-delay:.55s}.card:nth-child(12){animation-delay:.6s}
.card.full{grid-column:1/-1}
.card h2{font-size:12px;font-weight:700;color:var(--accent);margin-bottom:8px;display:flex;align-items:center;gap:6px}
.card h2 .i{font-size:15px}
.glow-orb{position:absolute;width:100px;height:100px;border-radius:50%;filter:blur(50px);opacity:.08;pointer-events:none}
.glow-orb.tl{top:-30px;left:-30px;background:var(--accent)}
.glow-orb.br{bottom:-30px;right:-30px;background:var(--a2)}
.big{font-size:34px;font-weight:800;line-height:1;animation:countUp .5s ease both}
.big small{font-size:11px;font-weight:400;color:var(--muted);display:block;margin-top:3px}
.fuel-row{display:flex;align-items:center;padding:7px 0;border-bottom:1px solid rgba(45,200,180,.06)}
.fuel-row:last-child{border:none}
.fuel-name{font-size:11px;color:var(--muted);width:52px;flex-shrink:0}
.fuel-bar{flex:1;height:22px;background:rgba(255,255,255,.03);border-radius:11px;overflow:hidden;margin:0 8px;position:relative}
.fuel-fill{height:100%;border-radius:11px;display:flex;align-items:center;justify-content:center;
font-size:10px;font-weight:700;color:#fff;animation:barGrow .8s ease both;position:relative}
.fuel-fill::after{content:'';position:absolute;inset:0;
background:linear-gradient(90deg,transparent,rgba(255,255,255,.15),transparent);animation:shimmer 2s infinite;background-size:200% 100%}
.fuel-avg{font-size:16px;font-weight:800;width:55px;text-align:right}
.bar-row{display:flex;align-items:center;gap:6px;margin:3px 0;animation:slideIn .5s ease both}
.bar-label{font-size:9px;color:var(--muted);width:65px;text-align:right;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bar-track{flex:1;height:18px;background:rgba(255,255,255,.03);border-radius:9px;overflow:hidden}
.bar-fill{height:100%;border-radius:9px;display:flex;align-items:center;justify-content:flex-end;padding-right:6px;
font-size:9px;font-weight:700;color:#fff;animation:barGrow .8s ease both}
.stat-row{display:flex;justify-content:space-around;text-align:center;padding:4px 0}
.stat-item .num{font-size:24px;font-weight:800;animation:countUp .6s ease both}
.stat-item .lbl{font-size:8px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;margin-top:2px}
.name-grid{display:grid;grid-template-columns:1fr 1fr;gap:0 10px}
.name-col h3{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px;text-align:center}
.name-item{display:flex;justify-content:space-between;padding:2px 0;font-size:11px;
border-bottom:1px solid rgba(45,200,180,.04);animation:slideIn .4s ease both}
.name-item .rk{color:var(--accent);font-weight:700;font-size:10px;margin-right:3px;min-width:14px}
.name-item .c{color:var(--muted);font-weight:600;font-size:10px}
.gkh-item{padding:7px 0;border-bottom:1px solid rgba(45,200,180,.05);animation:slideIn .4s ease both}
.gkh-item:last-child{border:none}
.gkh-name{font-size:11px;font-weight:600}
.gkh-phone{font-size:11px;color:var(--accent);margin-top:1px}
.gkh-phone a{color:var(--accent);text-decoration:none}
.chart-wrap{position:relative;width:100%;max-height:180px;margin-top:6px}
canvas.chart{max-height:180px!important}
.waste-item{display:flex;align-items:center;gap:8px;padding:4px 0;font-size:11px;animation:slideIn .4s ease both}
.waste-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0;animation:glow 3s infinite}
.waste-cnt{font-weight:700;margin-left:auto;font-size:12px}
.donut-wrap{display:flex;align-items:center;gap:12px}
.donut-legend{font-size:11px;line-height:1.8}
.donut-legend span{font-weight:700}
.footer{text-align:center;padding:20px 16px;font-size:10px;color:var(--muted)}
.footer a{color:var(--accent);text-decoration:none}
#loader{position:fixed;inset:0;z-index:99;background:var(--bg);display:flex;flex-direction:column;
align-items:center;justify-content:center;transition:opacity .6s}
#loader .sp{width:36px;height:36px;border:3px solid rgba(45,200,180,.12);border-top-color:var(--accent);
border-radius:50%;animation:spin .7s linear infinite}
#loader span{margin-top:12px;color:var(--accent);font-size:13px}
</style>
</head>
<body>
<canvas id="aurora"></canvas>
<div id="app"></div>
<div id="loader"><div class="sp"></div><span>Загрузка данных…</span></div>
<script>
// Telegram WebApp
const tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}

// ===== Северное сияние (Canvas) =====
const ac=document.getElementById('aurora'),ctx=ac.getContext('2d');
function resizeAurora(){ac.width=window.innerWidth;ac.height=window.innerHeight}
resizeAurora();window.addEventListener('resize',resizeAurora);
let aT=0;
function drawAurora(){
  ctx.clearRect(0,0,ac.width,ac.height);
  const w=ac.width,h=ac.height;
  // Тёмное небо с градиентом
  const sky=ctx.createLinearGradient(0,0,0,h);
  sky.addColorStop(0,'#050b18');sky.addColorStop(.4,'#0a1628');sky.addColorStop(1,'#050b18');
  ctx.fillStyle=sky;ctx.fillRect(0,0,w,h);
  // Полосы сияния
  for(let i=0;i<3;i++){
    ctx.beginPath();
    const yBase=h*.12+i*35;
    const colors=['rgba(45,200,180,','rgba(99,102,241,','rgba(34,211,238,'];
    const grad=ctx.createLinearGradient(0,yBase-40,0,yBase+60);
    grad.addColorStop(0,'transparent');
    grad.addColorStop(.3,colors[i]+(.04+Math.sin(aT*.3+i)*0.02)+')');
    grad.addColorStop(.5,colors[i]+(.07+Math.sin(aT*.5+i*2)*0.03)+')');
    grad.addColorStop(.7,colors[i]+(.03+Math.sin(aT*.4+i)*0.02)+')');
    grad.addColorStop(1,'transparent');
    ctx.fillStyle=grad;
    // Волнистая форма
    ctx.moveTo(0,yBase);
    for(let x=0;x<=w;x+=4){
      const y=yBase+Math.sin(x*.008+aT*.4+i*1.5)*18+Math.sin(x*.003+aT*.2)*25;
      ctx.lineTo(x,y);
    }
    ctx.lineTo(w,yBase+80);ctx.lineTo(0,yBase+80);ctx.closePath();ctx.fill();
  }
  // Звёзды
  for(let i=0;i<40;i++){
    const sx=(i*137.5+aT*0.1)%w,sy=(i*97.3)%h*.5;
    const br=.15+Math.sin(aT+i)*0.1;
    ctx.fillStyle=\`rgba(220,232,240,\${br})\`;
    ctx.fillRect(sx,sy,1.2,1.2);
  }
  // Силуэт тайги внизу
  ctx.beginPath();ctx.moveTo(0,h);
  for(let x=0;x<=w;x+=8){
    const treeH=12+Math.sin(x*.05)*6+Math.sin(x*.13)*4;
    ctx.lineTo(x,h-treeH);
  }
  ctx.lineTo(w,h);ctx.closePath();
  ctx.fillStyle='rgba(5,11,24,.95)';ctx.fill();
  aT+=0.008;
  requestAnimationFrame(drawAurora);
}
drawAurora();

// ===== Загрузка данных и рендеринг =====
const API='https://anthropic-proxy.uiredepositionherzo.workers.dev';

// Fallback данные (встроенные, обновляются при деплое)
const FALLBACK={
  fuel:{date:'13.02.2026',stations:44,prices:{
    'АИ-92':{min:57,max:63.7,avg:60.3,count:38},
    'АИ-95':{min:62,max:69.9,avg:65.3,count:37},
    'ДТ зимнее':{min:74,max:84.1,avg:79.4,count:26},
    'Газ':{min:23,max:32.9,avg:24.2,count:19}}},
  uk:{total:42,houses:904,top:[
    {name:'ПРЭТ №3',houses:186},{name:'УК Диалог',houses:170},{name:'ЖТ №1',houses:125},
    {name:'МЖК-Ладья',houses:73},{name:'УК №1',houses:65},{name:'РНУ ЖКХ',houses:55},
    {name:'УК Пирс',houses:39},{name:'УК-Квартал',houses:33},{name:'Данко',houses:28},{name:'Ренако-плюс',houses:21}]},
  education:{kindergartens:25,schools:33,culture:10,sport_orgs:4,sections:155,sections_free:102,sections_paid:53},
  waste:{total:682,groups:[
    {name:'Пластик',count:334},{name:'Опасные отходы',count:309},{name:'Бумага',count:19},
    {name:'Металлолом',count:7},{name:'Бытовая техника',count:6},{name:'Аккумуляторы',count:5},{name:'Автошины',count:2}]},
  names:{boys:[{n:'Артём',c:530},{n:'Максим',c:428},{n:'Александр',c:392},{n:'Дмитрий',c:385},{n:'Иван',c:311},
    {n:'Михаил',c:290},{n:'Кирилл',c:289},{n:'Роман',c:273},{n:'Матвей',c:243},{n:'Алексей',c:207}],
    girls:[{n:'Виктория',c:392},{n:'Анна',c:367},{n:'София',c:356},{n:'Мария',c:349},{n:'Анастасия',c:320},
    {n:'Дарья',c:308},{n:'Полина',c:292},{n:'Алиса',c:290},{n:'Арина',c:284},{n:'Ксения',c:279}]},
  gkh:[{name:'ЕДДС',phone:'8(3466) 29-72-50, 112'},{name:'Горэлектросеть',phone:'8(3466) 26-08-85'},
    {name:'Теплоснабжение',phone:'8(3466) 67-15-03'},{name:'Нижневартовскгаз',phone:'8(3466) 61-26-12'},
    {name:'Коммунальные системы',phone:'8(3466) 44-77-44'},{name:'ЖТ №1',phone:'8(3466) 29-11-99'},
    {name:'УК №1',phone:'8(3466) 24-69-50'},{name:'ПРЭТ №3',phone:'8(3466) 27-25-71'}],
  counts:{construction:100,phonebook:576,admin:157,sport_places:30,mfc:11,msp:14},
  updated_at:'2026-02-13T00:00:00'
};

async function loadData(){
  try{
    const r=await fetch(API+'/firebase/opendata_infographic.json',{signal:AbortSignal.timeout(5000)});
    if(r.ok){const d=await r.json();if(d&&d.fuel)return d}
  }catch(e){}
  return FALLBACK;
}

function fmtDate(iso){
  if(!iso)return '—';
  try{const d=new Date(iso);return d.toLocaleDateString('ru-RU',{day:'numeric',month:'long',year:'numeric'})}
  catch(e){return iso.substring(0,10)}
}

function render(D){
  const app=document.getElementById('app');
  const updStr=fmtDate(D.updated_at);
  const fuelDate=D.fuel?.date||'';
  const fp=D.fuel?.prices||{};
  const fuelColors={'АИ-92':'#34d399','АИ-95':'#fbbf24','ДТ зимнее':'#f87171','Газ':'#22d3ee'};
  const maxFuel=Math.max(...Object.values(fp).map(v=>v.max||0),1);

  // Fuel rows
  let fuelHTML='';
  for(const[name,v]of Object.entries(fp)){
    const pct=Math.round((v.avg/maxFuel)*100);
    const col=fuelColors[name]||'#2dc8b4';
    fuelHTML+=\`<div class="fuel-row">
      <span class="fuel-name">\${name}</span>
      <div class="fuel-bar"><div class="fuel-fill" style="--w:\${pct}%;width:\${pct}%;background:\${col}">\${v.min}–\${v.max}</div></div>
      <span class="fuel-avg" style="color:\${col}">\${v.avg} ₽</span></div>\`;
  }

  // UK bars
  const ukTop=D.uk?.top||[];
  const maxUk=ukTop[0]?.houses||1;
  const ukColors=['#2dc8b4','#22d3ee','#6366f1','#a78bfa','#34d399','#fbbf24','#f87171','#fb923c','#e879f9','#94a3b8'];
  let ukHTML='';
  ukTop.forEach((u,i)=>{
    const pct=Math.round(u.houses/maxUk*100);
    const nm=(u.name||'').replace(/^ООО\\s*"|^АО\\s*"|"$/g,'').substring(0,14);
    ukHTML+=\`<div class="bar-row" style="animation-delay:\${i*.06}s">
      <span class="bar-label">\${nm}</span>
      <div class="bar-track"><div class="bar-fill" style="--w:\${pct}%;width:\${pct}%;background:\${ukColors[i%10]}">\${u.houses}</div></div></div>\`;
  });

  // Names
  const boys=D.names?.boys||[];const girls=D.names?.girls||[];
  let namesHTML='<div class="name-col"><h3>👦 Мальчики</h3>';
  boys.forEach((b,i)=>{namesHTML+=\`<div class="name-item" style="animation-delay:\${i*.04}s"><span><span class="rk">\${i+1}</span>\${b.n}</span><span class="c">\${b.c}</span></div>\`});
  namesHTML+='</div><div class="name-col"><h3>👧 Девочки</h3>';
  girls.forEach((g,i)=>{namesHTML+=\`<div class="name-item" style="animation-delay:\${i*.04}s"><span><span class="rk">\${i+1}</span>\${g.n}</span><span class="c">\${g.c}</span></div>\`});
  namesHTML+='</div>';

  // Waste
  const wasteColors=['#34d399','#f87171','#22d3ee','#fbbf24','#a78bfa','#94a3b8','#78716c'];
  let wasteHTML='';
  (D.waste?.groups||[]).forEach((w,i)=>{
    const col=wasteColors[i%7];
    const nm=w.name.length>20?w.name.substring(0,18)+'…':w.name;
    wasteHTML+=\`<div class="waste-item" style="animation-delay:\${i*.05}s">
      <div class="waste-dot" style="background:\${col}"></div>\${nm}<span class="waste-cnt" style="color:\${col}">\${w.count}</span></div>\`;
  });

  // GKH
  const gkhIcons=['🚨','⚡','🔥','🔵','💧','🏠','🏠','🏠'];
  let gkhHTML='';
  (D.gkh||[]).forEach((g,i)=>{
    const nm=g.name.replace(/^АО\\s*"|^ООО\\s*"|"\\s*диспетчерская|Филиал.*диспетчерская/g,'').trim();
    const ph=g.phone.split(',')[0].trim();
    gkhHTML+=\`<div class="gkh-item" style="animation-delay:\${i*.05}s">
      <div class="gkh-name">\${gkhIcons[i]||'📞'} \${nm}</div>
      <div class="gkh-phone"><a href="tel:\${ph.replace(/[^\\d+]/g,'')}">\${g.phone}</a></div></div>\`;
  });

  const ed=D.education||{};
  const cn=D.counts||{};

  app.innerHTML=\`
<div class="hero">
  <h1>📊 Нижневартовск в цифрах</h1>
  <div class="sub">Открытые данные города · ХМАО-Югра</div>
  <div class="upd">Обновлено: \${updStr}</div>
</div>
<div class="grid">

<div class="card full"><div class="glow-orb tl"></div>
  <h2><span class="i">⛽</span> Цены на топливо <span style="font-weight:400;color:var(--muted);font-size:10px;margin-left:auto">\${D.fuel?.stations||0} АЗС · \${fuelDate}</span></h2>
  \${fuelHTML}
  <div class="chart-wrap"><canvas class="chart" id="fuelChart"></canvas></div>
</div>

<div class="card"><div class="glow-orb br"></div>
  <h2><span class="i">🏢</span> УК города</h2>
  <div class="big" style="color:var(--accent)">\${D.uk?.total||0}<small>управляющих компаний</small></div>
  <div style="margin-top:8px;font-size:14px;font-weight:700;color:var(--a3)">\${D.uk?.houses||0} <span style="font-size:10px;color:var(--muted);font-weight:400">домов</span></div>
</div>

<div class="card"><div class="glow-orb tl"></div>
  <h2><span class="i">🎓</span> Образование</h2>
  <div class="stat-row">
    <div class="stat-item"><div class="num" style="color:var(--orange)">\${ed.kindergartens||0}</div><div class="lbl">Детсадов</div></div>
    <div class="stat-item"><div class="num" style="color:var(--a3)">\${ed.schools||0}</div><div class="lbl">Школ</div></div>
  </div>
</div>

<div class="card full">
  <h2><span class="i">🏗️</span> Крупнейшие УК по числу домов</h2>
  \${ukHTML}
</div>

<div class="card"><div class="glow-orb br"></div>
  <h2><span class="i">🏅</span> Спорт</h2>
  <div class="big" style="color:var(--green)">\${ed.sections||0}<small>спортивных секций</small></div>
  <div style="margin-top:6px;font-size:11px">
    <span style="color:var(--green)">●</span> \${ed.sections_free||0} бесплатных<br>
    <span style="color:var(--orange)">●</span> \${ed.sections_paid||0} платных
  </div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">\${cn.sport_places||0} спортзалов</div>
</div>

<div class="card"><div class="glow-orb tl"></div>
  <h2><span class="i">🎭</span> Город</h2>
  <div class="stat-row">
    <div class="stat-item"><div class="num" style="color:var(--purple)">\${ed.culture||0}</div><div class="lbl">Культура</div></div>
    <div class="stat-item"><div class="num" style="color:var(--a3)">\${cn.mfc||0}</div><div class="lbl">МФЦ</div></div>
  </div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">\${cn.construction||0} строек · \${cn.msp||0} мер МСП</div>
</div>

<div class="card full">
  <h2><span class="i">⚽</span> Секции: бесплатные vs платные</h2>
  <div class="donut-wrap"><div class="chart-wrap" style="max-width:140px;max-height:140px"><canvas class="chart" id="secChart"></canvas></div>
  <div class="donut-legend"><span style="color:var(--green)">●</span> Бесплатные: <span style="color:var(--green)">\${ed.sections_free||0}</span><br>
  <span style="color:var(--orange)">●</span> Платные: <span style="color:var(--orange)">\${ed.sections_paid||0}</span><br>
  <span style="color:var(--muted)">Всего: \${ed.sections||0}</span></div></div>
</div>

<div class="card full"><div class="glow-orb tl"></div>
  <h2><span class="i">♻️</span> Раздельный сбор отходов <span style="font-weight:400;color:var(--muted);font-size:10px;margin-left:auto">\${D.waste?.total||0} точек</span></h2>
  \${wasteHTML}
  <div class="chart-wrap"><canvas class="chart" id="wasteChart"></canvas></div>
</div>

<div class="card full">
  <h2><span class="i">👶</span> Популярные имена новорождённых</h2>
  <div class="name-grid">\${namesHTML}</div>
</div>

<div class="card full"><div class="glow-orb br"></div>
  <h2><span class="i">📞</span> Аварийные службы ЖКХ</h2>
  \${gkhHTML}
</div>

<div class="card">
  <h2><span class="i">📋</span> Справочник</h2>
  <div class="big" style="color:var(--accent)">\${cn.phonebook||0}<small>телефонов организаций</small></div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">\${cn.admin||0} подразделений</div>
</div>

<div class="card">
  <h2><span class="i">🏗️</span> Строительство</h2>
  <div class="big" style="color:var(--orange)">\${cn.construction||0}<small>объектов</small></div>
</div>

</div>
<div class="footer">
  Источник: <a href="https://data.n-vartovsk.ru" target="_blank">data.n-vartovsk.ru</a><br>
  Пульс города · Нижневартовск © 2026
</div>\`;

  // Charts
  setTimeout(()=>{buildCharts(D)},100);
}

function buildCharts(D){
  const fp=D.fuel?.prices||{};
  const chartOpts={responsive:true,maintainAspectRatio:false,
    plugins:{legend:{labels:{color:'rgba(220,232,240,.6)',font:{size:9},padding:8}}},
    animation:{duration:1200,easing:'easeOutQuart'}};

  // Fuel chart
  const fc=document.getElementById('fuelChart');
  if(fc){
    const labels=Object.keys(fp);
    new Chart(fc,{type:'bar',data:{labels,datasets:[
      {label:'Мин.',data:labels.map(l=>fp[l].min),backgroundColor:'rgba(52,211,153,.5)',borderRadius:4},
      {label:'Средн.',data:labels.map(l=>fp[l].avg),backgroundColor:'rgba(45,200,180,.5)',borderRadius:4},
      {label:'Макс.',data:labels.map(l=>fp[l].max),backgroundColor:'rgba(248,113,113,.5)',borderRadius:4}
    ]},options:{...chartOpts,
      scales:{x:{ticks:{color:'rgba(220,232,240,.4)',font:{size:9}},grid:{display:false}},
      y:{ticks:{color:'rgba(220,232,240,.25)',font:{size:8},callback:v=>v+' ₽'},grid:{color:'rgba(45,200,180,.05)'}}}}});
  }

  // Sections donut
  const sc=document.getElementById('secChart');
  if(sc){
    const ed=D.education||{};
    new Chart(sc,{type:'doughnut',data:{labels:['Бесплатные','Платные'],
      datasets:[{data:[ed.sections_free||0,ed.sections_paid||0],
        backgroundColor:['rgba(52,211,153,.75)','rgba(251,191,36,.75)'],borderWidth:0,hoverOffset:6}]},
      options:{responsive:true,maintainAspectRatio:true,cutout:'68%',
        plugins:{legend:{display:false}},animation:{animateRotate:true,duration:1500}}});
  }

  // Waste horizontal bar
  const wc=document.getElementById('wasteChart');
  if(wc){
    const wg=D.waste?.groups||[];
    const wColors=['#34d399','#f87171','#22d3ee','#fbbf24','#a78bfa','#94a3b8','#78716c'];
    new Chart(wc,{type:'bar',data:{
      labels:wg.map(w=>w.name.length>14?w.name.substring(0,12)+'…':w.name),
      datasets:[{data:wg.map(w=>w.count),backgroundColor:wg.map((_,i)=>wColors[i%7]),borderRadius:6}]},
      options:{indexAxis:'y',...chartOpts,plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:'rgba(220,232,240,.25)',font:{size:8}},grid:{color:'rgba(45,200,180,.04)'}},
        y:{ticks:{color:'rgba(220,232,240,.4)',font:{size:9}},grid:{display:false}}}}});
  }
}

// ===== Init =====
loadData().then(D=>{
  render(D);
  const ld=document.getElementById('loader');
  if(ld){ld.style.opacity='0';setTimeout(()=>ld.remove(),600)}
}).catch(()=>{
  render(FALLBACK);
  const ld=document.getElementById('loader');
  if(ld){ld.style.opacity='0';setTimeout(()=>ld.remove(),600)}
});

<\/script>
</body></html>
`;

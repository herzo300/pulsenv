// ═══════════════════════════════════════════════════════
// Пульс города — Карта проблем Нижневартовска
// Leaflet + MarkerCluster + Firebase RTDB
// ═══════════════════════════════════════════════════════

const tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}

// ═══ CSS ═══
const S=document.createElement('style');
S.textContent=`
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --bg:var(--tg-theme-bg-color,#0a0a1a);
  --text:var(--tg-theme-text-color,#fff);
  --hint:var(--tg-theme-hint-color,rgba(255,255,255,.5));
  --accent:var(--tg-theme-button-color,#00b4ff);
  --panel:rgba(10,10,26,.92);
}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Inter,sans-serif;
  background:var(--bg);color:var(--text);overflow:hidden}
#map{width:100%;height:100vh}

.hdr{position:fixed;top:10px;left:50%;transform:translateX(-50%);z-index:1000;
  background:var(--panel);backdrop-filter:blur(12px);padding:8px 20px;border-radius:14px;
  border:1px solid rgba(0,180,255,.2);display:flex;align-items:center;gap:8px;pointer-events:auto}
.hdr h1{font-size:15px;font-weight:800}.hdr small{font-size:9px;color:var(--hint);letter-spacing:2px;display:block}
.pulse{width:8px;height:8px;border-radius:50%;background:#4caf50;animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}

.panel{position:fixed;z-index:1000;background:var(--panel);backdrop-filter:blur(12px);
  padding:10px 14px;border-radius:14px;border:1px solid rgba(0,180,255,.15);
  pointer-events:auto;font-size:12px}
.stats{bottom:12px;left:10px;min-width:130px}
.stats h3{font-size:10px;color:var(--hint);margin-bottom:6px;letter-spacing:1px;text-transform:uppercase}
.sr{display:flex;justify-content:space-between;padding:2px 0}
.sr .l{color:var(--hint);font-size:11px}.sr .v{font-weight:700;font-size:13px}
.blue{color:#00b4ff}.green{color:#4caf50}.red{color:#ff5252}.yellow{color:#ffc107}

.leg{bottom:12px;right:10px;max-height:220px;overflow-y:auto;max-width:170px}
.leg h3{font-size:10px;color:var(--hint);margin-bottom:4px;letter-spacing:1px;text-transform:uppercase}
.li{display:flex;align-items:center;gap:5px;padding:2px 0;font-size:10px;color:var(--hint);cursor:pointer;transition:.2s}
.li:hover{color:var(--text)}
.li.dim{opacity:.3}
.ld{width:8px;height:8px;border-radius:50%;flex-shrink:0}

.loader{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2000;
  background:var(--panel);padding:18px 32px;border-radius:14px;
  border:1px solid rgba(0,180,255,.2);color:var(--text);font-size:13px;display:flex;align-items:center;gap:10px}
.sp{width:20px;height:20px;border:3px solid rgba(0,180,255,.2);border-top-color:var(--accent);border-radius:50%;animation:spin .8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}

.leaflet-popup-content-wrapper{background:var(--panel)!important;color:var(--text)!important;
  border:1px solid rgba(0,180,255,.2)!important;border-radius:12px!important;max-width:280px!important}
.leaflet-popup-tip{background:var(--panel)!important}
.leaflet-popup-content{margin:10px 12px!important}
.pp{min-width:200px}
.pp h3{margin:0 0 6px;font-size:14px;line-height:1.3}
.pp .desc{margin:4px 0;font-size:12px;color:var(--hint);line-height:1.4}
.pp .meta{margin:3px 0;font-size:11px;color:var(--hint)}
.pp .meta b{color:var(--text);font-weight:600}
.pp a{color:var(--accent);text-decoration:none;font-size:11px}
.pp a:hover{text-decoration:underline}
.pp .links{margin-top:6px;display:flex;gap:8px;flex-wrap:wrap}
.badge{display:inline-block;padding:2px 8px;border-radius:5px;font-size:9px;font-weight:600;color:#fff;margin-top:4px}
.pp .source-tag{display:inline-block;padding:1px 6px;border-radius:4px;font-size:9px;
  background:rgba(0,180,255,.15);color:var(--accent);margin-top:4px}

.filter-bar{position:fixed;top:56px;left:50%;transform:translateX(-50%);z-index:1000;
  display:flex;gap:5px;flex-wrap:wrap;justify-content:center;max-width:96vw;padding:4px}
.fbtn{background:var(--panel);border:1px solid rgba(0,180,255,.15);color:var(--hint);
  padding:4px 10px;border-radius:16px;font-size:10px;cursor:pointer;
  backdrop-filter:blur(8px);transition:.2s;white-space:nowrap;user-select:none}
.fbtn.active{background:var(--accent);color:#fff;border-color:var(--accent)}
.fbtn:hover{border-color:var(--accent)}
.fbtn:active{transform:scale(.95)}

.status-bar{position:fixed;top:96px;left:50%;transform:translateX(-50%);z-index:1000;
  display:flex;gap:5px;justify-content:center}
.sbtn{background:var(--panel);border:1px solid rgba(0,180,255,.1);color:var(--hint);
  padding:3px 8px;border-radius:12px;font-size:9px;cursor:pointer;transition:.2s;white-space:nowrap}
.sbtn.active{color:#fff;border-width:2px}
`;
document.head.appendChild(S);

// ═══ Constants ═══
const FB='https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase';
const CAT_COLORS={
  'Дороги':'#FF5722','ЖКХ':'#2196F3','Освещение':'#FFC107','Транспорт':'#4CAF50',
  'Благоустройство':'#9C27B0','Экология':'#00BCD4','Животные':'#FF9800','Торговля':'#E91E63',
  'Безопасность':'#F44336','Снег/Наледь':'#03A9F4','Медицина':'#009688','Образование':'#673AB7',
  'Связь':'#3F51B5','Строительство':'#607D8B','Парковки':'#9E9E9E','Прочее':'#795548',
  'ЧП':'#D32F2F','Газоснабжение':'#FF6F00','Водоснабжение и канализация':'#0288D1',
  'Отопление':'#D84315','Бытовой мусор':'#689F38','Лифты и подъезды':'#455A64',
  'Парки и скверы':'#388E3C','Спортивные площадки':'#1976D2','Детские площадки':'#F06292',
  'Социальная сфера':'#8E24AA','Трудовое право':'#5D4037'
};
const CAT_EMOJI={
  'Дороги':'🛣️','ЖКХ':'🏠','Освещение':'💡','Транспорт':'🚌','Благоустройство':'🌳',
  'Экология':'🌿','Животные':'🐾','Торговля':'🏪','Безопасность':'🔒','Снег/Наледь':'❄️',
  'Медицина':'🏥','Образование':'🎓','Связь':'📡','Строительство':'🏗️','Парковки':'🅿️',
  'Прочее':'📌','ЧП':'🚨','Газоснабжение':'🔥','Водоснабжение и канализация':'💧',
  'Отопление':'🌡️','Бытовой мусор':'🗑️','Лифты и подъезды':'🛗','Парки и скверы':'🌲',
  'Спортивные площадки':'⚽','Детские площадки':'🎠','Социальная сфера':'👥','Трудовое право':'⚖️'
};
const STATUS_LABEL={pending:'🟡 Новая',open:'🔴 Открыта',in_progress:'🟠 В работе',resolved:'🟢 Решена',rejected:'⚪ Отклонена'};
const STATUS_COLOR={pending:'#FFC107',open:'#FF5252',in_progress:'#FF9800',resolved:'#4CAF50',rejected:'#9E9E9E'};

// ═══ Map init ═══
const map=L.map('map',{zoomControl:false}).setView([60.9344,76.5531],13);
L.control.zoom({position:'topright'}).addTo(map);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OSM',maxZoom:19}).addTo(map);

const clusterGroup=L.markerClusterGroup({
  maxClusterRadius:50,showCoverageOnHover:false,zoomToBoundsOnClick:true,spiderfyOnMaxZoom:true,
  iconCreateFunction(c){
    const n=c.getChildCount(),s=n<10?34:n<50?42:50;
    return L.divIcon({html:'<div style="width:'+s+'px;height:'+s+'px;border-radius:50%;background:rgba(0,140,255,.85);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:12px;border:2px solid rgba(255,255,255,.4);box-shadow:0 2px 10px rgba(0,140,255,.5)">'+n+'</div>',className:'',iconSize:[s,s]})
  }
});

function mkIcon(cat){
  const c=CAT_COLORS[cat]||'#795548';
  const e=CAT_EMOJI[cat]||'📌';
  return L.divIcon({className:'',
    html:'<div style="width:28px;height:28px;border-radius:50%;background:'+c+';border:3px solid rgba(255,255,255,.9);box-shadow:0 2px 8px rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;font-size:13px">'+e+'</div>',
    iconSize:[28,28],iconAnchor:[14,14]})
}

function fmtDate(s){
  if(!s)return'—';
  try{const d=new Date(s);return d.toLocaleDateString('ru-RU',{day:'2-digit',month:'short',year:'numeric'})+' '+d.toLocaleTimeString('ru-RU',{hour:'2-digit',minute:'2-digit'})}
  catch(e){return String(s).substring(0,16)}
}

function escHtml(s){
  if(!s)return'';
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')
}

// ═══ State ═══
let allItems=[];
let filterCat=null;
let filterStatus=null;

// ═══ Filters ═══
function buildFilters(cats){
  const bar=document.getElementById('filters');
  bar.innerHTML='';
  // "Все" button
  const btn0=document.createElement('div');
  btn0.className='fbtn active';btn0.textContent='Все ('+allItems.length+')';
  btn0.onclick=()=>{filterCat=null;renderMarkers();setActive(bar,btn0)};
  bar.appendChild(btn0);
  // Top categories
  Object.entries(cats).sort((a,b)=>b[1]-a[1]).slice(0,10).forEach(([cat,cnt])=>{
    const btn=document.createElement('div');
    btn.className='fbtn';
    btn.textContent=(CAT_EMOJI[cat]||'')+' '+cat+' ('+cnt+')';
    btn.onclick=()=>{filterCat=cat;renderMarkers();setActive(bar,btn)};
    bar.appendChild(btn);
  });
  // Status filter row
  buildStatusFilters();
}

function buildStatusFilters(){
  let sbar=document.getElementById('statusBar');
  if(!sbar){sbar=document.createElement('div');sbar.id='statusBar';sbar.className='status-bar';document.body.appendChild(sbar)}
  sbar.innerHTML='';
  const statuses=[
    {id:null,label:'Все статусы',color:'#00b4ff'},
    {id:'open',label:'🔴 Открыто',color:'#FF5252'},
    {id:'pending',label:'🟡 Новые',color:'#FFC107'},
    {id:'in_progress',label:'🟠 В работе',color:'#FF9800'},
    {id:'resolved',label:'🟢 Решено',color:'#4CAF50'},
  ];
  statuses.forEach(s=>{
    const btn=document.createElement('div');
    btn.className='sbtn'+(filterStatus===s.id?' active':'');
    btn.textContent=s.label;
    if(filterStatus===s.id||(!filterStatus&&!s.id))btn.style.borderColor=s.color;
    btn.onclick=()=>{filterStatus=s.id;renderMarkers();
      sbar.querySelectorAll('.sbtn').forEach(b=>{b.classList.remove('active');b.style.borderColor=''});
      btn.classList.add('active');btn.style.borderColor=s.color};
    sbar.appendChild(btn);
  });
}

function setActive(bar,active){
  bar.querySelectorAll('.fbtn').forEach(b=>b.classList.remove('active'));
  active.classList.add('active');
}

// ═══ Render markers ═══
function renderMarkers(){
  clusterGroup.clearLayers();
  let total=0,open=0,inWork=0,resolved=0;
  const cats={};

  let items=allItems;
  if(filterCat)items=items.filter(c=>c.category===filterCat);
  if(filterStatus)items=items.filter(c=>c.status===filterStatus);

  items.forEach(c=>{
    const lat=parseFloat(c.lat||c.latitude);
    const lng=parseFloat(c.lng||c.longitude);
    if(!lat||!lng||isNaN(lat)||isNaN(lng))return;
    total++;
    const st=c.status||'open';
    if(st==='open'||st==='pending')open++;
    if(st==='in_progress')inWork++;
    if(st==='resolved')resolved++;
    const cat=c.category||'Прочее';
    cats[cat]=(cats[cat]||0)+1;

    const m=L.marker([lat,lng],{icon:mkIcon(cat)});
    m.bindPopup(buildPopup(c,lat,lng),{maxWidth:280});
    clusterGroup.addLayer(m);
  });

  map.addLayer(clusterGroup);
  if(total&&!filterCat&&!filterStatus){
    try{map.fitBounds(clusterGroup.getBounds(),{padding:[50,50],maxZoom:15})}catch(_){}
  }

  document.getElementById('st').textContent=total;
  document.getElementById('so').textContent=open;
  document.getElementById('sw').textContent=inWork;
  document.getElementById('sr').textContent=resolved;

  // Legend
  const leg=document.getElementById('leg');
  leg.innerHTML='<h3>Категории</h3>';
  Object.entries(cats).sort((a,b)=>b[1]-a[1]).forEach(([cat,n])=>{
    const div=document.createElement('div');
    div.className='li'+(filterCat&&filterCat!==cat?' dim':'');
    div.innerHTML='<div class="ld" style="background:'+(CAT_COLORS[cat]||'#795548')+'"></div>'+(CAT_EMOJI[cat]||'')+'&nbsp;'+cat+' ('+n+')';
    div.onclick=()=>{
      if(filterCat===cat){filterCat=null}else{filterCat=cat}
      renderMarkers();
      // Update category filter bar
      const bar=document.getElementById('filters');
      bar.querySelectorAll('.fbtn').forEach(b=>{
        b.classList.remove('active');
        if(!filterCat&&b.textContent.startsWith('Все'))b.classList.add('active');
        if(filterCat&&b.textContent.includes(filterCat))b.classList.add('active');
      });
    };
    leg.appendChild(div);
  });
}

function buildPopup(c,lat,lng){
  const cat=c.category||'Прочее';
  const col=CAT_COLORS[cat]||'#795548';
  const emoji=CAT_EMOJI[cat]||'📌';
  const st=c.status||'open';
  const stLabel=STATUS_LABEL[st]||st;
  const stColor=STATUS_COLOR[st]||'#9E9E9E';
  const title=escHtml(c.summary||c.title||c.description||'Без описания');
  const desc=escHtml(c.description||'');
  const addr=escHtml(c.address||'');
  const src=escHtml(c.source_name||c.telegram_channel||c.source||'');

  let html='<div class="pp">';
  html+='<h3 style="color:'+col+'">'+emoji+' '+escHtml(cat)+'</h3>';
  html+='<div class="desc"><b>'+title.substring(0,150)+'</b></div>';
  if(desc&&desc!==title)html+='<div class="desc">'+desc.substring(0,200)+'</div>';
  if(addr)html+='<div class="meta">📍 <b>'+addr+'</b></div>';
  html+='<div class="meta">📅 '+fmtDate(c.created_at)+'</div>';
  html+='<span class="badge" style="background:'+stColor+'">'+stLabel+'</span>';
  if(src)html+=' <span class="source-tag">📢 '+src+'</span>';
  // Links
  html+='<div class="links">';
  html+='<a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint='+lat+','+lng+'" target="_blank">👁 Street View</a>';
  html+='<a href="https://www.google.com/maps/search/?api=1&query='+lat+','+lng+'" target="_blank">📌 Google Maps</a>';
  html+='<a href="https://yandex.ru/maps/?pt='+lng+','+lat+'&z=17&l=map" target="_blank">🗺 Яндекс</a>';
  html+='</div>';
  // UK info if available
  if(c.uk_name)html+='<div class="meta" style="margin-top:4px">🏢 УК: <b>'+escHtml(c.uk_name)+'</b></div>';
  if(c.uk_phone)html+='<div class="meta">📞 <a href="tel:'+c.uk_phone.replace(/[^\d+]/g,'')+'">'+escHtml(c.uk_phone)+'</a></div>';
  html+='</div>';
  return html;
}

// ═══ Data loading ═══
async function loadFromFirebase(){
  const r=await fetch(FB+'/complaints.json',{signal:AbortSignal.timeout(8000)});
  if(!r.ok)throw new Error('Firebase: '+r.status);
  const data=await r.json();
  if(!data)return[];
  return Object.entries(data).map(([id,d])=>({id,...d}));
}

async function loadData(){
  const ld=document.getElementById('ld');
  try{
    let items=await loadFromFirebase();
    let source='Firebase RTDB';

    if(!items.length){
      ld.innerHTML='📭 Нет жалоб. Отправьте первую через бота @pulsenvbot';
      return;
    }

    // Sort by date desc
    items.sort((a,b)=>{
      const da=new Date(a.created_at||0),db_=new Date(b.created_at||0);
      return db_-da;
    });

    allItems=items;
    document.getElementById('ss').textContent=source+' · '+items.length;

    // Build filters
    const cats={};
    items.forEach(c=>{if(c.category)cats[c.category]=(cats[c.category]||0)+1});
    buildFilters(cats);

    renderMarkers();
    ld.style.display='none';

  }catch(e){
    console.error('Load error:',e);
    ld.innerHTML='❌ Ошибка: '+e.message+'<br><small>Попробуйте обновить страницу</small>';
  }
}

// ═══ Init ═══
loadData();
// Auto-refresh every 60s
setInterval(()=>{loadData()},60000);

// ═══════════════════════════════════════════════════════
// Пульс города — Карта + Статистика + Фильтры по дням
// ═══════════════════════════════════════════════════════
const tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}

const S=document.createElement('style');
S.textContent=`
*{margin:0;padding:0;box-sizing:border-box}
:root{
--bg:#0b0f1a;--text:#e8ecf4;--hint:rgba(255,255,255,.45);
--accent:#3b82f6;--accentL:#60a5fa;--accentD:#1d4ed8;
--surface:rgba(15,20,35,.88);--glass:blur(16px) saturate(1.6);
--green:#22c55e;--red:#ef4444;--yellow:#eab308;--orange:#f97316;
--purple:#a855f7;--teal:#14b8a6;--pink:#ec4899;
--r:16px;--rs:10px;
--shadow:0 2px 12px rgba(0,0,0,.3);
}
body{font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
background:var(--bg);color:var(--text);overflow:hidden;-webkit-font-smoothing:antialiased}

/* ═══ SPLASH ═══ */
#splash{position:fixed;inset:0;z-index:9999;background:#0b0f1a;
display:flex;align-items:center;justify-content:center;transition:opacity .7s,transform .4s}
#splash.hide{opacity:0;transform:scale(1.03);pointer-events:none}
.splash-bg{position:absolute;inset:0;overflow:hidden}
#pulseCanvas{width:100%;height:100%;opacity:.3}
.splash-content{position:relative;z-index:1;text-align:center;padding:20px}
.city-emblem{width:100px;height:100px;margin:0 auto 14px;border-radius:50%;padding:10px;
background:#0b0f1a;box-shadow:10px 10px 20px rgba(0,0,0,.6),-10px -10px 20px rgba(255,255,255,.04);
color:var(--accent);display:flex;align-items:center;justify-content:center;
animation:emblemIn 1s ease .2s both}
@keyframes emblemIn{from{opacity:0;transform:scale(.7)}to{opacity:1;transform:scale(1)}}
.emblem-svg{width:65px;height:65px}
.splash-pulse-ring{position:relative;width:130px;height:130px;margin:0 auto 16px;
display:flex;align-items:center;justify-content:center}
.ring{position:absolute;border-radius:50%;border:2px solid var(--accent);opacity:0}
.r1{width:70px;height:70px;animation:rp 2.5s ease-out infinite}
.r2{width:100px;height:100px;animation:rp 2.5s ease-out .5s infinite}
.r3{width:130px;height:130px;animation:rp 2.5s ease-out 1s infinite}
@keyframes rp{0%{transform:scale(.6);opacity:.7}100%{transform:scale(1.2);opacity:0}}
.pulse-core{width:44px;height:44px;border-radius:50%;
background:radial-gradient(circle,var(--accent),transparent 70%);
box-shadow:0 0 24px var(--accent);animation:cp 1.5s ease-in-out infinite;transition:all .5s}
@keyframes cp{0%,100%{transform:scale(1);opacity:.85}50%{transform:scale(1.12);opacity:1}}
.pulse-core.mood-good{background:radial-gradient(circle,var(--green),transparent 70%);box-shadow:0 0 24px var(--green)}
.pulse-core.mood-ok{background:radial-gradient(circle,var(--yellow),transparent 70%);box-shadow:0 0 24px var(--yellow)}
.pulse-core.mood-bad{background:radial-gradient(circle,var(--red),transparent 70%);box-shadow:0 0 24px var(--red)}
.ring.mood-good{border-color:var(--green)}.ring.mood-ok{border-color:var(--yellow)}.ring.mood-bad{border-color:var(--red)}
.splash-title{font-size:28px;font-weight:800;letter-spacing:.5px;
text-shadow:0 2px 16px rgba(59,130,246,.3);animation:fadeUp .8s ease .4s both}
.splash-city{font-size:10px;letter-spacing:4px;color:var(--hint);margin-top:3px;
text-transform:uppercase;font-weight:600;animation:fadeUp .8s ease .6s both}
.splash-mood{font-size:12px;color:var(--accent);margin-top:10px;font-weight:600;
min-height:18px;transition:color .5s;animation:fadeUp .8s ease .8s both}
@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
.splash-stats{display:flex;justify-content:center;gap:20px;margin-top:14px}
.ss-item{text-align:center}
.ss-num{display:block;font-size:22px;font-weight:800;background:#0b0f1a;border-radius:12px;padding:6px 12px;
box-shadow:6px 6px 12px rgba(0,0,0,.5),-6px -6px 12px rgba(255,255,255,.03);min-width:54px;
animation:fadeUp .8s ease 1s both}
.ss-label{font-size:8px;color:var(--hint);text-transform:uppercase;letter-spacing:1px;margin-top:3px;display:block}
.splash-loader{margin-top:20px;animation:fadeUp .8s ease 1.2s both}
.sl-bar{width:180px;height:3px;border-radius:2px;margin:0 auto;background:rgba(255,255,255,.06);overflow:hidden}
.sl-fill{height:100%;width:0;border-radius:2px;background:linear-gradient(90deg,var(--accent),var(--green));transition:width .3s}
.sl-text{font-size:9px;color:var(--hint);margin-top:6px}

/* ═══ MAP ═══ */
#map{position:fixed;inset:0;z-index:0}

/* ═══ TOP BAR — header + stats unified ═══ */
#topBar{position:fixed;top:0;left:0;right:0;z-index:1000;
background:var(--surface);backdrop-filter:var(--glass);
border-bottom:1px solid rgba(255,255,255,.06);padding:6px 12px;
display:flex;align-items:center;gap:10px}
.tb-header{display:flex;align-items:center;gap:6px;flex-shrink:0}
.tb-pulse{width:8px;height:8px;border-radius:50%;background:var(--green);animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
.tb-title{font-size:14px;font-weight:800;white-space:nowrap}
.tb-city{font-size:8px;color:var(--hint);letter-spacing:2px;text-transform:uppercase;display:none}
.tb-stats{display:flex;gap:8px;margin-left:auto;flex-shrink:0}
.tb-stat{text-align:center;min-width:36px}
.tb-num{font-size:16px;font-weight:800;display:block;line-height:1.1}
.tb-lbl{font-size:7px;color:var(--hint);text-transform:uppercase;letter-spacing:.5px}
.red{color:var(--red)}.green{color:var(--green)}.yellow{color:var(--yellow)}.blue{color:var(--accent)}

/* ═══ FILTER PANEL ═══ */
#filterPanel{position:fixed;top:48px;left:0;right:0;z-index:999;
padding:4px 8px 2px;background:linear-gradient(var(--surface) 80%,transparent);
backdrop-filter:var(--glass)}
.fp-row{display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:2px 0;-webkit-overflow-scrolling:touch}
.fp-row::-webkit-scrollbar{display:none}

/* Filter chips */
.chip{flex-shrink:0;padding:4px 10px;border-radius:20px;font-size:10px;font-weight:600;
cursor:pointer;transition:all .2s;white-space:nowrap;user-select:none;
background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.08);color:var(--hint)}
.chip:active{transform:scale(.94)}
.chip.active{background:var(--accent);color:#fff;border-color:var(--accent);
box-shadow:0 2px 8px rgba(59,130,246,.3)}
.chip.st-open.active{background:var(--red);border-color:var(--red);box-shadow:0 2px 8px rgba(239,68,68,.3)}
.chip.st-pending.active{background:var(--yellow);border-color:var(--yellow);color:#000;box-shadow:0 2px 8px rgba(234,179,8,.3)}
.chip.st-progress.active{background:var(--orange);border-color:var(--orange);box-shadow:0 2px 8px rgba(249,115,22,.3)}
.chip.st-resolved.active{background:var(--green);border-color:var(--green);box-shadow:0 2px 8px rgba(34,197,94,.3)}
/* Day chips */
.chip.day{font-size:9px;padding:3px 8px}
.chip.day .dn{font-weight:800;font-size:11px;display:block;line-height:1}
.chip.day .dd{font-size:7px;opacity:.7}
.chip.day.active{background:var(--accentD);border-color:var(--accent)}
.chip.day.today{border-color:var(--accent);border-width:2px}

/* ═══ TIMELINE ═══ */
.tl-panel{position:fixed;bottom:0;left:0;right:0;z-index:999;height:54px;
background:var(--surface);backdrop-filter:var(--glass);
border-top:1px solid rgba(255,255,255,.06);padding:4px 8px}
#tlCanvas{width:100%;height:46px;display:block}

/* ═══ LEGEND ═══ */
.leg-panel{position:fixed;bottom:58px;right:6px;z-index:998;
background:var(--surface);backdrop-filter:var(--glass);
border:1px solid rgba(255,255,255,.06);border-radius:var(--r);
padding:6px 10px;max-height:180px;overflow-y:auto;max-width:140px;
box-shadow:var(--shadow);scrollbar-width:thin}
.leg-panel h4{font-size:8px;color:var(--hint);text-transform:uppercase;letter-spacing:1px;margin-bottom:3px}
.li{display:flex;align-items:center;gap:4px;padding:1px 0;font-size:9px;color:var(--hint);cursor:pointer;transition:.2s}
.li:hover{color:var(--text)}.li.dim{opacity:.25}
.ld{width:7px;height:7px;border-radius:50%;flex-shrink:0}

/* ═══ POPUPS ═══ */
.leaflet-popup-content-wrapper{background:var(--surface)!important;color:var(--text)!important;
border:1px solid rgba(255,255,255,.08)!important;border-radius:14px!important;max-width:280px!important;
backdrop-filter:var(--glass)!important;box-shadow:0 8px 32px rgba(0,0,0,.4)!important}
.leaflet-popup-tip{background:var(--surface)!important}
.leaflet-popup-content{margin:8px 10px!important}
.pp{min-width:180px}
.pp h3{margin:0 0 4px;font-size:13px;line-height:1.2}
.pp .desc{margin:3px 0;font-size:11px;color:var(--hint);line-height:1.3}
.pp .meta{margin:2px 0;font-size:10px;color:var(--hint)}
.pp .meta b{color:var(--text);font-weight:600}
.pp a{color:var(--accentL);text-decoration:none;font-size:10px}
.pp a:hover{text-decoration:underline}
.pp .links{margin-top:4px;display:flex;gap:6px;flex-wrap:wrap}
.badge{display:inline-block;padding:2px 7px;border-radius:6px;font-size:8px;font-weight:700;color:#fff;margin-top:3px}
.pp .src{display:inline-block;padding:1px 5px;border-radius:4px;font-size:8px;
background:rgba(59,130,246,.12);color:var(--accentL);margin-top:3px;margin-left:4px}

/* ═══ TOAST ═══ */
.toast{position:fixed;top:52px;left:50%;transform:translateX(-50%);z-index:2000;
background:rgba(34,197,94,.92);color:#fff;padding:7px 14px;border-radius:12px;
font-size:11px;display:flex;align-items:center;gap:5px;backdrop-filter:blur(8px);
box-shadow:0 4px 16px rgba(0,0,0,.3);animation:tin .3s ease;cursor:pointer}
.toast.hide{animation:tout .3s ease forwards}
@keyframes tin{from{opacity:0;transform:translateX(-50%) translateY(-16px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}
@keyframes tout{to{opacity:0;transform:translateX(-50%) translateY(-16px)}}
.toast-icon{font-size:14px}

@keyframes mpop{0%{transform:scale(0)}60%{transform:scale(1.3)}100%{transform:scale(1)}}
.new-marker{animation:mpop .5s ease}
`;
document.head.appendChild(S);

// ═══ Constants ═══
const FB='https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase';
const CC={
'Дороги':'#FF5722','ЖКХ':'#2196F3','Освещение':'#FFC107','Транспорт':'#4CAF50',
'Благоустройство':'#9C27B0','Экология':'#00BCD4','Животные':'#FF9800','Торговля':'#E91E63',
'Безопасность':'#F44336','Снег/Наледь':'#03A9F4','Медицина':'#009688','Образование':'#673AB7',
'Связь':'#3F51B5','Строительство':'#607D8B','Парковки':'#9E9E9E','Прочее':'#795548',
'ЧП':'#D32F2F','Газоснабжение':'#FF6F00','Водоснабжение и канализация':'#0288D1',
'Отопление':'#D84315','Бытовой мусор':'#689F38','Лифты и подъезды':'#455A64',
'Парки и скверы':'#388E3C','Спортивные площадки':'#1976D2','Детские площадки':'#F06292',
'Социальная сфера':'#8E24AA','Трудовое право':'#5D4037'};
const CE={
'Дороги':'🛣️','ЖКХ':'🏠','Освещение':'💡','Транспорт':'🚌','Благоустройство':'🌳',
'Экология':'🌿','Животные':'🐾','Торговля':'🏪','Безопасность':'🔒','Снег/Наледь':'❄️',
'Медицина':'🏥','Образование':'🎓','Связь':'📡','Строительство':'🏗️','Парковки':'🅿️',
'Прочее':'📌','ЧП':'🚨','Газоснабжение':'🔥','Водоснабжение и канализация':'💧',
'Отопление':'🌡️','Бытовой мусор':'🗑️','Лифты и подъезды':'🛗','Парки и скверы':'🌲',
'Спортивные площадки':'⚽','Детские площадки':'🎠','Социальная сфера':'👥','Трудовое право':'⚖️'};
const SL={pending:'🟡 Новая',open:'🔴 Открыта',in_progress:'🟠 В работе',resolved:'🟢 Решена'};
const SC={pending:'#eab308',open:'#ef4444',in_progress:'#f97316',resolved:'#22c55e'};
const DAYS_RU=['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
const MON_RU=['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];

// ═══ Splash ═══
const splashCanvas=document.getElementById('pulseCanvas');
let splashCtx,splashAnim;
if(splashCanvas){
  splashCanvas.width=window.innerWidth;splashCanvas.height=window.innerHeight;
  splashCtx=splashCanvas.getContext('2d');
  const waves=[];for(let i=0;i<5;i++)waves.push({x:splashCanvas.width/2,y:splashCanvas.height/2,r:20+i*40,speed:.3+i*.1,op:.15-i*.02});
  // Частицы
  const particles=[];for(let i=0;i<40;i++)particles.push({
    x:Math.random()*splashCanvas.width,y:Math.random()*splashCanvas.height,
    r:Math.random()*2+.5,vx:(Math.random()-.5)*.3,vy:(Math.random()-.5)*.3,
    op:Math.random()*.4+.1});
  let auroraT=0;
  (function draw(){
    splashCtx.clearRect(0,0,splashCanvas.width,splashCanvas.height);
    // Северное сияние
    auroraT+=.005;
    for(let i=0;i<3;i++){
      var cx=splashCanvas.width*(0.3+0.4*Math.sin(auroraT*2+i*1.05));
      var cy=splashCanvas.height*0.12+i*35;
      var grd=splashCtx.createRadialGradient(cx,cy,0,cx,cy,220);
      var hue=i===0?210:i===1?160:280;
      grd.addColorStop(0,'hsla('+hue+',80%,55%,.07)');
      grd.addColorStop(1,'transparent');
      splashCtx.fillStyle=grd;splashCtx.fillRect(0,0,splashCanvas.width,splashCanvas.height);
    }
    // Волны
    waves.forEach(function(w){w.r+=w.speed;if(w.r>Math.max(splashCanvas.width,splashCanvas.height))w.r=20;
      splashCtx.beginPath();splashCtx.arc(w.x,w.y,w.r,0,Math.PI*2);
      splashCtx.strokeStyle='rgba(59,130,246,'+Math.max(0,w.op*(1-w.r/500))+')';splashCtx.lineWidth=1.5;splashCtx.stroke()});
    // Частицы
    particles.forEach(function(p){
      p.x+=p.vx;p.y+=p.vy;
      if(p.x<0)p.x=splashCanvas.width;if(p.x>splashCanvas.width)p.x=0;
      if(p.y<0)p.y=splashCanvas.height;if(p.y>splashCanvas.height)p.y=0;
      splashCtx.beginPath();splashCtx.arc(p.x,p.y,p.r,0,Math.PI*2);
      splashCtx.fillStyle='rgba(255,255,255,'+p.op+')';splashCtx.fill()});
    splashAnim=requestAnimationFrame(draw)})();
}
function analyzeMood(items){
  if(!items.length)return{mood:'ok',text:'Нет данных',ratio:.5,total:0,open:0,resolved:0};
  const t=items.length,res=items.filter(c=>c.status==='resolved').length,
    op=items.filter(c=>c.status==='open'||c.status==='pending').length,
    ratio=res/Math.max(t,1),week=Date.now()-7*864e5,
    recent=items.filter(c=>{try{return new Date(c.created_at)>week}catch(e){return false}}).length;
  let mood,text;
  if(ratio>=.5&&recent<10){mood='good';text='😊 Город спокоен — '+Math.round(ratio*100)+'% решено'}
  else if(ratio>=.3){mood='ok';text='😐 Умеренная активность — '+op+' открытых'}
  else{mood='bad';text='😟 Повышенная активность — '+recent+' за неделю'}
  return{mood,text,ratio,total:t,open:op,resolved:res};
}
function applyMood(m){
  const c=document.getElementById('pulseCore'),mt=document.getElementById('moodText');
  if(c)c.className='pulse-core mood-'+m.mood;
  document.querySelectorAll('.ring').forEach(r=>{r.className=r.className.replace(/mood-\w+/g,'');r.classList.add('mood-'+m.mood)});
  if(mt){mt.textContent=m.text;mt.style.color=m.mood==='good'?'var(--green)':m.mood==='bad'?'var(--red)':'var(--yellow)'}
}
function splashStats(m){
  const $=id=>document.getElementById(id);
  if($('ssTotal'))$('ssTotal').textContent=m.total;
  if($('ssOpen'))$('ssOpen').textContent=m.open;
  if($('ssResolved'))$('ssResolved').textContent=m.resolved;
}
function splashProg(p,t){const f=document.getElementById('slFill'),x=document.getElementById('slText');if(f)f.style.width=p+'%';if(x)x.textContent=t}
function hideSplash(){const s=document.getElementById('splash');if(!s)return;if(splashAnim)cancelAnimationFrame(splashAnim);
  s.classList.add('hide');document.getElementById('app').style.display='';setTimeout(()=>s.remove(),700)}

// ═══ Helpers ═══
function mkIcon(cat,isNew){
  const c=CC[cat]||'#795548',e=CE[cat]||'📌',cls=isNew?'new-marker':'';
  return L.divIcon({className:cls,
    html:'<div style="width:28px;height:28px;border-radius:50%;background:'+c+';border:3px solid rgba(255,255,255,.85);box-shadow:0 2px 8px rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;font-size:13px">'+e+'</div>',
    iconSize:[28,28],iconAnchor:[14,14]})}
function fmtDate(s){if(!s)return'—';try{const d=new Date(s);return d.toLocaleDateString('ru-RU',{day:'2-digit',month:'short'})+' '+d.toLocaleTimeString('ru-RU',{hour:'2-digit',minute:'2-digit'})}catch(e){return String(s).substring(0,16)}}
function esc(s){return s?s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'):''}
function dateKey(d){return d.toISOString().slice(0,10)}
function parseDate(s){try{return new Date(s)}catch(e){return null}}

// ═══ State ═══
let allItems=[],filterCat=null,filterStatus=null,filterDay=null,knownIds=new Set(),mapReady=false,map,cluster;

// ═══ Toast ═══
let toastT=null;
function showToast(t){const el=document.getElementById('newToast'),tx=document.getElementById('toastText');if(!el)return;
  tx.textContent=t;el.style.display='flex';el.classList.remove('hide');clearTimeout(toastT);
  toastT=setTimeout(()=>{el.classList.add('hide');setTimeout(()=>el.style.display='none',300)},4000);
  el.onclick=()=>{el.classList.add('hide');setTimeout(()=>el.style.display='none',300)}}

// ═══ Day filter — last 14 days ═══
function buildDayFilters(){
  const bar=document.getElementById('dayFilters');if(!bar)return;bar.innerHTML='';
  const today=new Date();today.setHours(0,0,0,0);
  // "Все дни" chip
  const all=document.createElement('div');
  all.className='chip day'+(filterDay===null?' active':'');
  all.innerHTML='<span class="dn">∞</span><span class="dd">все</span>';
  all.onclick=()=>{filterDay=null;render();buildDayFilters()};
  bar.appendChild(all);
  // Last 14 days
  for(let i=0;i<14;i++){
    const d=new Date(today);d.setDate(d.getDate()-i);
    const key=dateKey(d);
    const cnt=allItems.filter(c=>{try{return dateKey(new Date(c.created_at))===key}catch(e){return false}}).length;
    if(cnt===0&&i>3)continue;
    const chip=document.createElement('div');
    chip.className='chip day'+(filterDay===key?' active':'')+(i===0?' today':'');
    const dayName=i===0?'Сегодня':i===1?'Вчера':DAYS_RU[d.getDay()];
    chip.innerHTML='<span class="dn">'+d.getDate()+'</span><span class="dd">'+dayName+(cnt?' · '+cnt:'')+'</span>';
    chip.onclick=()=>{filterDay=filterDay===key?null:key;render();buildDayFilters()};
    bar.appendChild(chip);
  }
}

// ═══ Category filters ═══
function buildCatFilters(){
  const bar=document.getElementById('catFilters');if(!bar)return;bar.innerHTML='';
  const cats={};allItems.forEach(c=>{if(c.category)cats[c.category]=(cats[c.category]||0)+1});
  const sorted=Object.entries(cats).sort((a,b)=>b[1]-a[1]);
  // All
  const all=document.createElement('div');
  all.className='chip'+(filterCat===null?' active':'');
  all.textContent='Все категории';
  all.onclick=()=>{filterCat=null;render();buildCatFilters()};
  bar.appendChild(all);
  sorted.slice(0,10).forEach(([cat,cnt])=>{
    const chip=document.createElement('div');
    chip.className='chip'+(filterCat===cat?' active':'');
    chip.textContent=(CE[cat]||'')+''+cat+' '+cnt;
    chip.onclick=()=>{filterCat=filterCat===cat?null:cat;render();buildCatFilters()};
    bar.appendChild(chip);
  });
}

// ═══ Status filters ═══
function buildStatusFilters(){
  const bar=document.getElementById('statusFilters');if(!bar)return;bar.innerHTML='';
  const sts=[
    {id:null,label:'Все статусы',cls:''},
    {id:'open',label:'🔴 Открыто',cls:'st-open'},
    {id:'pending',label:'🟡 Новые',cls:'st-pending'},
    {id:'in_progress',label:'🟠 В работе',cls:'st-progress'},
    {id:'resolved',label:'🟢 Решено',cls:'st-resolved'},
  ];
  sts.forEach(s=>{
    const chip=document.createElement('div');
    chip.className='chip '+s.cls+(filterStatus===s.id?' active':'');
    chip.textContent=s.label;
    chip.onclick=()=>{filterStatus=filterStatus===s.id?null:s.id;render();buildStatusFilters()};
    bar.appendChild(chip);
  });
}

function buildAllFilters(){buildDayFilters();buildCatFilters();buildStatusFilters()}

// ═══ Timeline chart (bottom bar) ═══
function drawTimeline(){
  const canvas=document.getElementById('tlCanvas');if(!canvas)return;
  const ctx=canvas.getContext('2d');
  const W=canvas.parentElement.clientWidth-16;
  canvas.width=W*2;canvas.height=92;canvas.style.width=W+'px';canvas.style.height='46px';
  ctx.scale(2,2);ctx.clearRect(0,0,W,46);
  // Group by day (last 30 days)
  const today=new Date();today.setHours(0,0,0,0);
  const days=[];
  for(let i=29;i>=0;i--){const d=new Date(today);d.setDate(d.getDate()-i);days.push(dateKey(d))}
  const byDay={};days.forEach(d=>byDay[d]={open:0,resolved:0,total:0});
  allItems.forEach(c=>{
    try{const k=dateKey(new Date(c.created_at));
      if(byDay[k]!==undefined){byDay[k].total++;if(c.status==='resolved')byDay[k].resolved++;else byDay[k].open++}}catch(e){}});
  const maxV=Math.max(...days.map(d=>byDay[d].total),1);
  const barW=(W-20)/days.length;
  // Draw bars
  days.forEach((d,i)=>{
    const v=byDay[d];const x=10+i*barW;const h=Math.max(v.total/maxV*30,1);
    // Resolved (green)
    const rh=v.resolved/Math.max(v.total,1)*h;
    ctx.fillStyle='rgba(34,197,94,.6)';
    ctx.fillRect(x+1,36-h,barW-2,rh);
    // Open (red)
    ctx.fillStyle='rgba(239,68,68,.5)';
    ctx.fillRect(x+1,36-h+rh,barW-2,h-rh);
    // Highlight selected day
    if(filterDay===d){ctx.strokeStyle='#3b82f6';ctx.lineWidth=1.5;ctx.strokeRect(x,36-h-1,barW,h+2)}
    // Day label (every 5th or first/last)
    if(i%5===0||i===days.length-1){
      ctx.fillStyle='rgba(255,255,255,.3)';ctx.font='500 7px Inter,sans-serif';ctx.textAlign='center';
      ctx.fillText(d.slice(8),x+barW/2,44)}
  });
  // Y axis label
  ctx.fillStyle='rgba(255,255,255,.2)';ctx.font='500 7px Inter,sans-serif';ctx.textAlign='left';
  ctx.fillText(maxV+'',2,10);
}

// ═══ Render markers ═══
function render(){
  if(!mapReady)return;
  cluster.clearLayers();
  let total=0,open=0,inWork=0,resolved=0;
  let items=allItems;
  if(filterCat)items=items.filter(c=>c.category===filterCat);
  if(filterStatus)items=items.filter(c=>c.status===filterStatus);
  if(filterDay)items=items.filter(c=>{try{return dateKey(new Date(c.created_at))===filterDay}catch(e){return false}});
  const cats={};
  items.forEach(c=>{
    const lat=parseFloat(c.lat||c.latitude),lng=parseFloat(c.lng||c.longitude);
    if(!lat||!lng||isNaN(lat)||isNaN(lng))return;
    total++;const st=c.status||'open';
    if(st==='open'||st==='pending')open++;if(st==='in_progress')inWork++;if(st==='resolved')resolved++;
    const cat=c.category||'Прочее';cats[cat]=(cats[cat]||0)+1;
    const m=L.marker([lat,lng],{icon:mkIcon(cat,c._isNew)});
    m.bindPopup(buildPopup(c,lat,lng),{maxWidth:280});cluster.addLayer(m)});
  map.addLayer(cluster);
  if(total&&!filterCat&&!filterStatus&&!filterDay){try{map.fitBounds(cluster.getBounds(),{padding:[50,50],maxZoom:15})}catch(_){}}
  // Stats
  document.getElementById('st').textContent=total;
  document.getElementById('so').textContent=open;
  document.getElementById('sw').textContent=inWork;
  document.getElementById('sr').textContent=resolved;
  // Legend
  const leg=document.getElementById('leg');leg.innerHTML='<h4>Категории</h4>';
  Object.entries(cats).sort((a,b)=>b[1]-a[1]).forEach(([cat,n])=>{
    const div=document.createElement('div');
    div.className='li'+(filterCat&&filterCat!==cat?' dim':'');
    div.innerHTML='<div class="ld" style="background:'+(CC[cat]||'#795548')+'"></div>'+(CE[cat]||'')+cat+' ('+n+')';
    div.onclick=()=>{filterCat=filterCat===cat?null:cat;render();buildCatFilters()};
    leg.appendChild(div)});
  drawTimeline();
}

function buildPopup(c,lat,lng){
  const cat=c.category||'Прочее',col=CC[cat]||'#795548',emoji=CE[cat]||'📌',
    st=c.status||'open',stL=SL[st]||st,stC=SC[st]||'#9E9E9E',
    title=esc(c.summary||c.title||c.description||'—'),
    desc=esc(c.description||''),addr=esc(c.address||''),
    src=esc(c.source_name||c.telegram_channel||c.source||'');
  let h='<div class="pp"><h3 style="color:'+col+'">'+emoji+' '+esc(cat)+'</h3>';
  h+='<div class="desc"><b>'+title.substring(0,150)+'</b></div>';
  if(desc&&desc!==title)h+='<div class="desc">'+desc.substring(0,200)+'</div>';
  if(addr)h+='<div class="meta">📍 <b>'+addr+'</b></div>';
  h+='<div class="meta">📅 '+fmtDate(c.created_at)+'</div>';
  h+='<span class="badge" style="background:'+stC+'">'+stL+'</span>';
  if(src)h+='<span class="src">📢 '+src+'</span>';
  h+='<div class="links">';
  h+='<a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint='+lat+','+lng+'" target="_blank">👁 Street View</a>';
  h+='<a href="https://yandex.ru/maps/?pt='+lng+','+lat+'&z=17&l=map" target="_blank">🗺 Яндекс</a>';
  h+='</div>';
  if(c.uk_name)h+='<div class="meta" style="margin-top:3px">🏢 <b>'+esc(c.uk_name)+'</b></div>';
  if(c.uk_phone)h+='<div class="meta">📞 <a href="tel:'+c.uk_phone.replace(/[^\d+]/g,'')+'">'+esc(c.uk_phone)+'</a></div>';
  h+='</div>';return h;
}

// ═══ Data + Realtime ═══
async function loadFB(){
  const r=await fetch(FB+'/complaints.json',{signal:AbortSignal.timeout(8000)});
  if(!r.ok)throw new Error('Firebase: '+r.status);
  const data=await r.json();if(!data)return[];
  return Object.entries(data).map(([id,d])=>({id,...d}));
}
let syncIv=null;
function startSync(){if(syncIv)return;
  syncIv=setInterval(async()=>{try{
    const items=await loadFB();if(!items.length)return;
    const nw=items.filter(c=>!knownIds.has(c.id));
    if(nw.length){nw.forEach(c=>{c._isNew=true;allItems.unshift(c);knownIds.add(c.id)});
      allItems.sort((a,b)=>new Date(b.created_at||0)-new Date(a.created_at||0));
      render();buildAllFilters();
      showToast(nw.length===1?(CE[nw[0].category]||'📌')+' '+(nw[0].summary||nw[0].category).substring(0,50):'🔔 +'+nw.length+' новых');
      setTimeout(()=>nw.forEach(c=>c._isNew=false),2000);
      try{tg?.HapticFeedback?.impactOccurred('medium')}catch(e){}}
    items.forEach(c=>{if(knownIds.has(c.id)){const ex=allItems.find(a=>a.id===c.id);if(ex&&ex.status!==c.status)ex.status=c.status}});
  }catch(e){console.warn('Sync:',e)}},15000)}

function initMap(){
  map=L.map('map',{zoomControl:false}).setView([60.9344,76.5531],13);
  L.control.zoom({position:'topright'}).addTo(map);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OSM',maxZoom:19}).addTo(map);
  cluster=L.markerClusterGroup({maxClusterRadius:50,showCoverageOnHover:false,zoomToBoundsOnClick:true,spiderfyOnMaxZoom:true,
    iconCreateFunction(c){const n=c.getChildCount(),s=n<10?32:n<50?40:48;
      return L.divIcon({html:'<div style="width:'+s+'px;height:'+s+'px;border-radius:50%;background:rgba(59,130,246,.85);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:12px;border:2px solid rgba(255,255,255,.35);box-shadow:0 2px 10px rgba(59,130,246,.4)">'+n+'</div>',className:'',iconSize:[s,s]})}});
  mapReady=true;
}

async function loadData(){
  splashProg(10,'Подключение к Firebase...');
  try{
    let items=await loadFB();
    splashProg(50,'Обработка '+items.length+' жалоб...');
    if(!items.length){splashProg(100,'Нет данных');setTimeout(()=>{hideSplash();initMap()},800);return}
    items.sort((a,b)=>new Date(b.created_at||0)-new Date(a.created_at||0));
    allItems=items;items.forEach(c=>knownIds.add(c.id));
    splashProg(70,'Анализ настроения...');
    const mood=analyzeMood(items);applyMood(mood);splashStats(mood);
    splashProg(90,'Карта...');await new Promise(r=>setTimeout(r,600));
    initMap();buildAllFilters();render();
    splashProg(100,'Готово!');await new Promise(r=>setTimeout(r,400));
    hideSplash();startSync();
  }catch(e){console.error(e);splashProg(100,'Ошибка: '+e.message);setTimeout(()=>{hideSplash();initMap()},1500)}
}
loadData();

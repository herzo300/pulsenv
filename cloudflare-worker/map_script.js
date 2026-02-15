// ═══════════════════════════════════════════════════════
// Пульс города — Карта v4: новая заставка, рейтинг УК, статистика
// ═══════════════════════════════════════════════════════
var tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',function(){tg.close()})}

var S=document.createElement('style');
S.textContent=`
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
`;
document.head.appendChild(S);

// ═══ More styles (popups, stats overlay, UK rating, FAB, complaint form) ═══
var S2=document.createElement('style');
S2.textContent=`
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
`;
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
  h+='<button class="vote-btn" onclick="voteComplaint(\''+c.id+'\',1,this)" title="Проблема решена хорошо">👍 <span id="vl_'+c.id+'">'+likes+'</span></button>';
  h+='<button class="vote-btn" onclick="voteComplaint(\''+c.id+'\',-1,this)" title="Проблема не решена">👎 <span id="vd_'+c.id+'">'+dislikes+'</span></button>';
  if(c.status!=='resolved'){
    h+='<button onclick="joinComplaint(\''+c.id+'\')" id="jbtn_'+c.id+'" style="';
    h+='padding:3px 8px;border-radius:14px;border:1px solid var(--accent);background:rgba(99,102,241,.12);';
    h+='color:var(--accentL);font-size:9px;font-weight:700;cursor:pointer">✊ +1</button>'}
  h+='</div>';
  if(sup>=10)h+='<div class="meta" style="color:var(--green);font-size:8px;margin-top:1px">📧 Отправлено в УК</div>';
  h+='<div class="links">';
  h+='<a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint='+lat+','+lng+'" target="_blank">👁 Street View</a>';
  h+='<a href="https://yandex.ru/maps/?pt='+lng+','+lat+'&z=17&l=map" target="_blank">🗺 Яндекс</a>';
  h+='</div>';
  if(c.uk_name)h+='<div class="meta" style="margin-top:2px">🏢 <b>'+esc(c.uk_name)+'</b></div>';
  if(c.uk_phone)h+='<div class="meta">📞 <a href="tel:'+c.uk_phone.replace(/[^\d+]/g,'')+'">'+esc(c.uk_phone)+'</a></div>';
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
  ov.innerHTML='<button class="so-close" onclick="document.getElementById(\'statsOverlay\').classList.remove(\'open\')">&times;</button>'+html;
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
  var body='Уважаемая '+ukName+',\n\nЧерез систему «Пульс города» поступила анонимная жалоба:\n\n'+desc;
  if(addr)body+='\n\nАдрес: '+addr;
  body+='\n\nПросим рассмотреть и принять меры.\nС уважением, Пульс города — Нижневартовск';
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
  html+='<div style="margin-top:4px"><span onclick="sendAnonEmail(\'Администрация г. Нижневартовска\',\'nvartovsk@n-vartovsk.ru\')" style="font-size:9px;color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ Написать анонимно</span></div>';
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
    html+='<span onclick="legalAnalysis(\''+esc(e[0]).replace(/'/g,"\\'")+'\')\" style="font-size:9px;color:var(--yellow);cursor:pointer;text-decoration:underline">⚖️ Юр. анализ</span>';
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
        if(match.email)d+='<span onclick="sendAnonEmail(\''+esc(match.name).replace(/'/g,"\\'")+'\',\''+match.email+'\')" style="color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ '+match.email+'</span>';
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
      if(u.email)extra+='<span onclick="sendAnonEmail(\''+esc(u.name).replace(/'/g,"\\'")+'\',\''+u.email+'\')" style="font-size:9px;color:var(--accentL);cursor:pointer;text-decoration:underline">✉️ Написать</span>';
      extra+='<span onclick="legalAnalysis(\''+esc(u.name).replace(/'/g,"\\'")+'\')\" style="font-size:9px;color:var(--yellow);cursor:pointer;text-decoration:underline">⚖️ Юр. анализ</span>';
      extra+='</div></div>';
    });
    var container=document.getElementById('ukExtraList');
    if(container)container.innerHTML=extra;
  });
  html+='<div id="ukExtraList"></div>';
  if(!sorted.length&&!allUkData)html+='<div style="font-size:11px;color:var(--hint);padding:20px 0;text-align:center">Загрузка данных УК...</div>';
  ov.innerHTML='<button class="uk-close" onclick="document.getElementById(\'ukOverlay\').classList.remove(\'open\')">&times;</button>'+html;
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

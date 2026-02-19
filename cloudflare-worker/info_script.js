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
S.textContent=`
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
`;
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
    h+='<button class="expand-btn" onclick="this.parentElement.classList.toggle(\'expanded\');haptic()">'+
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
          '<button class="uk-email-btn" onclick="sendUkEmail(\''+esc(u.name).replace(/'/g,"\\'")+'\',\''+u.email+'\')">✉️ Написать</button></div>':
          '<div style="font-size:9px;color:var(--textMuted)">Email не указан</div>')+'</div>';
      });
      h+=card('housing',true,
        cardHead('✉️','var(--indigoBg)','Написать в УК анонимно','Все '+(allUks.length||42)+' управляющих компаний')+ukList+
        makeTip('indigo','🔒','Анонимная жалоба отправляется напрямую в УК'),
        allUks.slice(10).map((u,i)=>'<div class="uk-email-item"><span style="font-weight:600;font-size:10px">'+esc(u.name)+'</span>'+
          (u.email?' <button class="uk-email-btn" onclick="sendUkEmail(\''+esc(u.name).replace(/'/g,"\\'")+'\',\''+u.email+'\')">✉️</button>':'')+'</div>').join(''),
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
  const body='Уважаемая '+ukName+',\n\nЧерез систему Пульс города поступила анонимная жалоба:\n\n'+desc+(addr?'\n\nАдрес: '+addr:'')+'\n\nПросим рассмотреть.\nС уважением, Пульс города';
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


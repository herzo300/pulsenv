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
    ctx.fillStyle=`rgba(220,232,240,${br})`;
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
    fuelHTML+=`<div class="fuel-row">
      <span class="fuel-name">${name}</span>
      <div class="fuel-bar"><div class="fuel-fill" style="--w:${pct}%;width:${pct}%;background:${col}">${v.min}–${v.max}</div></div>
      <span class="fuel-avg" style="color:${col}">${v.avg} ₽</span></div>`;
  }

  // UK bars
  const ukTop=D.uk?.top||[];
  const maxUk=ukTop[0]?.houses||1;
  const ukColors=['#2dc8b4','#22d3ee','#6366f1','#a78bfa','#34d399','#fbbf24','#f87171','#fb923c','#e879f9','#94a3b8'];
  let ukHTML='';
  ukTop.forEach((u,i)=>{
    const pct=Math.round(u.houses/maxUk*100);
    const nm=(u.name||'').replace(/^ООО\s*"|^АО\s*"|"$/g,'').substring(0,14);
    ukHTML+=`<div class="bar-row" style="animation-delay:${i*.06}s">
      <span class="bar-label">${nm}</span>
      <div class="bar-track"><div class="bar-fill" style="--w:${pct}%;width:${pct}%;background:${ukColors[i%10]}">${u.houses}</div></div></div>`;
  });

  // Names
  const boys=D.names?.boys||[];const girls=D.names?.girls||[];
  let namesHTML='<div class="name-col"><h3>👦 Мальчики</h3>';
  boys.forEach((b,i)=>{namesHTML+=`<div class="name-item" style="animation-delay:${i*.04}s"><span><span class="rk">${i+1}</span>${b.n}</span><span class="c">${b.c}</span></div>`});
  namesHTML+='</div><div class="name-col"><h3>👧 Девочки</h3>';
  girls.forEach((g,i)=>{namesHTML+=`<div class="name-item" style="animation-delay:${i*.04}s"><span><span class="rk">${i+1}</span>${g.n}</span><span class="c">${g.c}</span></div>`});
  namesHTML+='</div>';

  // Waste
  const wasteColors=['#34d399','#f87171','#22d3ee','#fbbf24','#a78bfa','#94a3b8','#78716c'];
  let wasteHTML='';
  (D.waste?.groups||[]).forEach((w,i)=>{
    const col=wasteColors[i%7];
    const nm=w.name.length>20?w.name.substring(0,18)+'…':w.name;
    wasteHTML+=`<div class="waste-item" style="animation-delay:${i*.05}s">
      <div class="waste-dot" style="background:${col}"></div>${nm}<span class="waste-cnt" style="color:${col}">${w.count}</span></div>`;
  });

  // GKH
  const gkhIcons=['🚨','⚡','🔥','🔵','💧','🏠','🏠','🏠'];
  let gkhHTML='';
  (D.gkh||[]).forEach((g,i)=>{
    const nm=g.name.replace(/^АО\s*"|^ООО\s*"|"\s*диспетчерская|Филиал.*диспетчерская/g,'').trim();
    const ph=g.phone.split(',')[0].trim();
    gkhHTML+=`<div class="gkh-item" style="animation-delay:${i*.05}s">
      <div class="gkh-name">${gkhIcons[i]||'📞'} ${nm}</div>
      <div class="gkh-phone"><a href="tel:${ph.replace(/[^\d+]/g,'')}">${g.phone}</a></div></div>`;
  });

  const ed=D.education||{};
  const cn=D.counts||{};

  app.innerHTML=`
<div class="hero">
  <h1>📊 Нижневартовск в цифрах</h1>
  <div class="sub">Открытые данные города · ХМАО-Югра</div>
  <div class="upd">Обновлено: ${updStr}</div>
</div>
<div class="grid">

<div class="card full"><div class="glow-orb tl"></div>
  <h2><span class="i">⛽</span> Цены на топливо <span style="font-weight:400;color:var(--muted);font-size:10px;margin-left:auto">${D.fuel?.stations||0} АЗС · ${fuelDate}</span></h2>
  ${fuelHTML}
  <div class="chart-wrap"><canvas class="chart" id="fuelChart"></canvas></div>
</div>

<div class="card"><div class="glow-orb br"></div>
  <h2><span class="i">🏢</span> УК города</h2>
  <div class="big" style="color:var(--accent)">${D.uk?.total||0}<small>управляющих компаний</small></div>
  <div style="margin-top:8px;font-size:14px;font-weight:700;color:var(--a3)">${D.uk?.houses||0} <span style="font-size:10px;color:var(--muted);font-weight:400">домов</span></div>
</div>

<div class="card"><div class="glow-orb tl"></div>
  <h2><span class="i">🎓</span> Образование</h2>
  <div class="stat-row">
    <div class="stat-item"><div class="num" style="color:var(--orange)">${ed.kindergartens||0}</div><div class="lbl">Детсадов</div></div>
    <div class="stat-item"><div class="num" style="color:var(--a3)">${ed.schools||0}</div><div class="lbl">Школ</div></div>
  </div>
</div>

<div class="card full">
  <h2><span class="i">🏗️</span> Крупнейшие УК по числу домов</h2>
  ${ukHTML}
</div>

<div class="card"><div class="glow-orb br"></div>
  <h2><span class="i">🏅</span> Спорт</h2>
  <div class="big" style="color:var(--green)">${ed.sections||0}<small>спортивных секций</small></div>
  <div style="margin-top:6px;font-size:11px">
    <span style="color:var(--green)">●</span> ${ed.sections_free||0} бесплатных<br>
    <span style="color:var(--orange)">●</span> ${ed.sections_paid||0} платных
  </div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">${cn.sport_places||0} спортзалов</div>
</div>

<div class="card"><div class="glow-orb tl"></div>
  <h2><span class="i">🎭</span> Город</h2>
  <div class="stat-row">
    <div class="stat-item"><div class="num" style="color:var(--purple)">${ed.culture||0}</div><div class="lbl">Культура</div></div>
    <div class="stat-item"><div class="num" style="color:var(--a3)">${cn.mfc||0}</div><div class="lbl">МФЦ</div></div>
  </div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">${cn.construction||0} строек · ${cn.msp||0} мер МСП</div>
</div>

<div class="card full">
  <h2><span class="i">⚽</span> Секции: бесплатные vs платные</h2>
  <div class="donut-wrap"><div class="chart-wrap" style="max-width:140px;max-height:140px"><canvas class="chart" id="secChart"></canvas></div>
  <div class="donut-legend"><span style="color:var(--green)">●</span> Бесплатные: <span style="color:var(--green)">${ed.sections_free||0}</span><br>
  <span style="color:var(--orange)">●</span> Платные: <span style="color:var(--orange)">${ed.sections_paid||0}</span><br>
  <span style="color:var(--muted)">Всего: ${ed.sections||0}</span></div></div>
</div>

<div class="card full"><div class="glow-orb tl"></div>
  <h2><span class="i">♻️</span> Раздельный сбор отходов <span style="font-weight:400;color:var(--muted);font-size:10px;margin-left:auto">${D.waste?.total||0} точек</span></h2>
  ${wasteHTML}
  <div class="chart-wrap"><canvas class="chart" id="wasteChart"></canvas></div>
</div>

<div class="card full">
  <h2><span class="i">👶</span> Популярные имена новорождённых</h2>
  <div class="name-grid">${namesHTML}</div>
</div>

<div class="card full"><div class="glow-orb br"></div>
  <h2><span class="i">📞</span> Аварийные службы ЖКХ</h2>
  ${gkhHTML}
</div>

<div class="card">
  <h2><span class="i">📋</span> Справочник</h2>
  <div class="big" style="color:var(--accent)">${cn.phonebook||0}<small>телефонов организаций</small></div>
  <div style="margin-top:4px;font-size:10px;color:var(--muted)">${cn.admin||0} подразделений</div>
</div>

<div class="card">
  <h2><span class="i">🏗️</span> Строительство</h2>
  <div class="big" style="color:var(--orange)">${cn.construction||0}<small>объектов</small></div>
</div>

</div>
<div class="footer">
  Источник: <a href="https://data.n-vartovsk.ru" target="_blank">data.n-vartovsk.ru</a><br>
  Пульс города · Нижневартовск © 2026
</div>`;

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

// ═══════════════════════════════════════════════════════
// Пульс города Нижневартовск — React + WebGL + Weather
// ═══════════════════════════════════════════════════════

const tg=window.Telegram&&window.Telegram.WebApp;
if(tg){tg.ready();tg.expand();tg.BackButton.show();tg.onEvent('backButtonClicked',()=>tg.close())}
const isDark=tg?.colorScheme==='dark';
if(isDark)document.documentElement.classList.add('dark');
const h=React.createElement;

// ═══ CSS Styles ═══
const S=document.createElement('style');
S.textContent=`
*{margin:0;padding:0;box-sizing:border-box}
:root{
--bg:#f5f0e8;--surface:rgba(255,255,255,.88);--surfaceS:rgba(255,255,255,.95);
--primary:#0f766e;--primaryL:#14b8a6;--primaryBg:rgba(15,118,110,.07);
--accent:#e8804c;--accentBg:rgba(232,128,76,.08);
--text:#0f172a;--textSec:#475569;--textMuted:#94a3b8;
--border:rgba(0,0,0,.06);--shadow:0 1px 3px rgba(0,0,0,.04),0 6px 24px rgba(0,0,0,.06);
--green:#16a34a;--greenBg:#dcfce7;--red:#dc2626;--redBg:#fee2e2;
--orange:#ea580c;--orangeBg:#fff7ed;--blue:#2563eb;--blueBg:#eff6ff;
--purple:#7c3aed;--purpleBg:#f5f3ff;--teal:#0d9488;--tealBg:#f0fdfa;
--pink:#db2777;--pinkBg:#fdf2f8;--indigo:#4f46e5;--indigoBg:#eef2ff;
--r:20px;--rs:14px;--glass:blur(20px) saturate(1.4);
}
.dark{
--bg:#0c1222;--surface:rgba(26,35,50,.82);--surfaceS:rgba(26,35,50,.95);
--text:#e2e8f0;--textSec:#94a3b8;--textMuted:#64748b;
--border:rgba(255,255,255,.06);--shadow:0 1px 3px rgba(0,0,0,.2),0 6px 24px rgba(0,0,0,.3);
--greenBg:rgba(22,163,74,.15);--redBg:rgba(220,38,38,.15);--orangeBg:rgba(234,88,12,.12);
--blueBg:rgba(37,99,235,.12);--purpleBg:rgba(124,58,237,.12);--tealBg:rgba(13,148,136,.12);
--pinkBg:rgba(219,39,119,.12);--indigoBg:rgba(79,70,229,.12);
}
body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);
overflow-x:hidden;min-height:100vh;-webkit-font-smoothing:antialiased}
#weatherBg{position:fixed;inset:0;z-index:0;pointer-events:none}
#root{position:relative;z-index:1}

@keyframes fadeUp{from{opacity:0;transform:translateY(28px)}to{opacity:1;transform:translateY(0)}}
@keyframes scaleIn{from{opacity:0;transform:scale(.9)}to{opacity:1;transform:scale(1)}}
@keyframes slideR{from{opacity:0;transform:translateX(-16px)}to{opacity:1;transform:translateX(0)}}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-6px)}}
@keyframes spin{to{transform:rotate(360deg)}}
@keyframes barGrow{from{width:0}to{width:var(--w)}}
@keyframes countUp{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
@keyframes shimmer{0%{background-position:-200% 0}100%{background-position:200% 0}}
@keyframes breathe{0%,100%{transform:scale(1)}50%{transform:scale(1.02)}}
@keyframes weatherPulse{0%,100%{opacity:.7}50%{opacity:1}}

.app-wrap{max-width:480px;margin:0 auto;padding:0 10px 40px}

/* Weather banner */
.weather-bar{display:flex;align-items:center;gap:10px;padding:10px 16px;margin:8px 0;
border-radius:var(--r);background:var(--surface);backdrop-filter:var(--glass);
border:1px solid var(--border);box-shadow:var(--shadow);animation:fadeUp .5s ease both}
.weather-icon{font-size:32px;animation:breathe 3s ease infinite}
.weather-info{flex:1}
.weather-temp{font-size:22px;font-weight:800}
.weather-desc{font-size:11px;color:var(--textSec);text-transform:capitalize}
.weather-extra{font-size:9px;color:var(--textMuted);margin-top:2px}
.weather-badge{padding:4px 10px;border-radius:12px;font-size:9px;font-weight:700;
letter-spacing:.3px;animation:weatherPulse 4s ease infinite}

/* Hero */
.hero{text-align:center;padding:28px 16px 8px;animation:fadeUp .6s ease both}
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
.tabs{display:flex;gap:6px;padding:8px 0;overflow-x:auto;-webkit-overflow-scrolling:touch;scrollbar-width:none}
.tabs::-webkit-scrollbar{display:none}
.tab{flex-shrink:0;padding:7px 14px;border-radius:12px;font-size:11px;font-weight:600;
background:var(--surface);backdrop-filter:var(--glass);border:1px solid var(--border);
color:var(--textSec);cursor:pointer;transition:all .25s;white-space:nowrap}
.tab.active{background:var(--primary);color:#fff;border-color:var(--primary);
box-shadow:0 2px 12px rgba(15,118,110,.35);transform:scale(1.04)}
.tab:active{transform:scale(.95)}

/* Grid & Cards */
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding-top:6px}
.card{background:var(--surface);backdrop-filter:var(--glass);border:1px solid var(--border);
border-radius:var(--r);padding:14px;position:relative;overflow:hidden;box-shadow:var(--shadow);
opacity:0;transform:translateY(24px);transition:all .4s cubic-bezier(.4,0,.2,1);cursor:pointer}
.card.visible{opacity:1;transform:translateY(0)}
.card:active{transform:scale(.97)!important}
.card:hover{border-color:var(--primary);box-shadow:0 4px 20px rgba(15,118,110,.12)}
.card[data-section="budget"]{border-left:3px solid var(--orange)}
.card[data-section="fuel"]{border-left:3px solid var(--red)}
.card[data-section="housing"]{border-left:3px solid var(--teal)}
.card[data-section="edu"]{border-left:3px solid var(--blue)}
.card[data-section="transport"]{border-left:3px solid var(--indigo)}
.card[data-section="sport"]{border-left:3px solid var(--green)}
.card[data-section="city"]{border-left:3px solid var(--purple)}
.card[data-section="eco"]{border-left:3px solid var(--teal)}
.card[data-section="people"]{border-left:3px solid var(--pink)}
.card.full{grid-column:1/-1}
.card.expandable{cursor:pointer}
.card.expandable::after{content:'';position:absolute;bottom:0;left:0;right:0;height:40px;
background:linear-gradient(transparent,var(--surfaceS));pointer-events:none;transition:opacity .3s}
.card.expanded::after{opacity:0}
.card .expand-content{max-height:0;overflow:hidden;transition:max-height .5s cubic-bezier(.4,0,.2,1)}
.card.expanded .expand-content{max-height:3000px}
.expand-btn{display:flex;align-items:center;justify-content:center;gap:4px;margin-top:8px;
padding:6px;border-radius:10px;background:var(--primaryBg);color:var(--primary);
font-size:10px;font-weight:600;cursor:pointer;transition:all .25s}
.expand-btn:active{transform:scale(.95)}

.card-head{display:flex;align-items:center;gap:8px;margin-bottom:10px}
.card-icon{width:38px;height:38px;border-radius:12px;display:flex;align-items:center;
justify-content:center;font-size:18px;flex-shrink:0;transition:transform .3s}
.card:hover .card-icon{transform:scale(1.1) rotate(-3deg)}
.card-title{font-size:13px;font-weight:700;line-height:1.2}
.card-sub{font-size:10px;color:var(--textMuted);font-weight:500;margin-top:1px}

.tip{display:flex;align-items:flex-start;gap:6px;margin-top:10px;padding:8px 10px;
border-radius:var(--rs);font-size:10px;line-height:1.4;color:var(--textSec)}
.tip-icon{font-size:13px;flex-shrink:0;animation:float 3s ease infinite}
.tip.green{background:var(--greenBg);color:#166534}
.tip.orange{background:var(--orangeBg);color:#9a3412}
.tip.blue{background:var(--blueBg);color:#1e40af}
.tip.purple{background:var(--purpleBg);color:#5b21b6}
.tip.teal{background:var(--tealBg);color:#134e4a}
.tip.red{background:var(--redBg);color:#991b1b}
.tip.pink{background:var(--pinkBg);color:#9d174d}
.tip.indigo{background:var(--indigoBg);color:#3730a3}

.big{font-size:34px;font-weight:900;line-height:1}
.big small{font-size:10px;font-weight:500;color:var(--textMuted);display:block;margin-top:3px}

.fuel-row{display:flex;align-items:center;padding:5px 0;border-bottom:1px solid var(--border)}
.fuel-row:last-child{border:none}
.fuel-name{font-size:10px;color:var(--textSec);width:50px;flex-shrink:0;font-weight:600}
.fuel-bar{flex:1;height:22px;background:rgba(0,0,0,.03);border-radius:11px;overflow:hidden;margin:0 6px}
.dark .fuel-bar{background:rgba(255,255,255,.05)}
.fuel-fill{height:100%;border-radius:11px;display:flex;align-items:center;justify-content:center;
font-size:8px;font-weight:700;color:#fff;animation:barGrow 1s cubic-bezier(.4,0,.2,1) both}
.fuel-avg{font-size:14px;font-weight:800;width:48px;text-align:right}

.bar-row{display:flex;align-items:center;gap:6px;margin:3px 0}
.bar-label{font-size:9px;color:var(--textSec);width:65px;text-align:right;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:500}
.bar-track{flex:1;height:18px;background:rgba(0,0,0,.03);border-radius:9px;overflow:hidden}
.dark .bar-track{background:rgba(255,255,255,.05)}
.bar-fill{height:100%;border-radius:9px;display:flex;align-items:center;justify-content:flex-end;
padding-right:5px;font-size:8px;font-weight:700;color:#fff;animation:barGrow 1s cubic-bezier(.4,0,.2,1) both}

.stat-row{display:flex;justify-content:space-around;text-align:center;padding:4px 0}
.stat-item .num{font-size:22px;font-weight:800;animation:countUp .5s ease both}
.stat-item .lbl{font-size:8px;color:var(--textMuted);text-transform:uppercase;letter-spacing:.3px;margin-top:2px;font-weight:600}

.name-grid{display:grid;grid-template-columns:1fr 1fr;gap:0 12px}
.name-col h3{font-size:9px;color:var(--textMuted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:4px;text-align:center;font-weight:700}
.name-item{display:flex;justify-content:space-between;padding:3px 0;font-size:11px;border-bottom:1px solid var(--border)}
.name-item .rk{color:var(--primary);font-weight:700;font-size:10px;margin-right:4px;min-width:14px}
.name-item .c{color:var(--textMuted);font-weight:600;font-size:10px}

.gkh-item{padding:7px 0;border-bottom:1px solid var(--border)}
.gkh-item:last-child{border:none}
.gkh-name{font-size:11px;font-weight:600}
.gkh-phone a{color:var(--primary);text-decoration:none;font-weight:600;font-size:11px}

.waste-item{display:flex;align-items:center;gap:8px;padding:4px 0;font-size:11px}
.waste-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.waste-cnt{font-weight:700;margin-left:auto;font-size:12px}

.route-item{padding:6px 0;border-bottom:1px solid var(--border);font-size:11px}
.route-item:last-child{border:none}
.route-num{display:inline-flex;align-items:center;justify-content:center;min-width:28px;height:22px;
background:var(--primary);color:#fff;border-radius:6px;font-size:10px;font-weight:700;margin-right:6px}
.route-title{color:var(--textSec);font-size:10px;margin-top:2px}

.list-item{padding:5px 0;border-bottom:1px solid var(--border);font-size:10px;color:var(--textSec)}
.list-item:last-child{border:none}
.list-item b{color:var(--text);font-weight:600;font-size:11px}

.chart-wrap{position:relative;width:100%;max-height:180px;margin-top:8px}
canvas.chart{max-height:180px!important}
.donut-wrap{display:flex;align-items:center;gap:12px}
.donut-legend{font-size:11px;line-height:1.8}
.donut-legend span{font-weight:700}

.section-title{font-size:11px;font-weight:700;color:var(--textMuted);text-transform:uppercase;
letter-spacing:.8px;padding:16px 4px 6px;grid-column:1/-1}

.footer{text-align:center;padding:24px 16px;font-size:10px;color:var(--textMuted)}
.footer a{color:var(--primary);text-decoration:none;font-weight:600}

/* TrendBar mini chart */
.trend-bar{display:flex;align-items:flex-end;gap:2px;height:40px}
.trend-col{flex:1;display:flex;flex-direction:column;align-items:center;gap:1px}

#loader{position:fixed;inset:0;z-index:99;background:var(--bg);display:flex;flex-direction:column;
align-items:center;justify-content:center;transition:opacity .5s}
#loader.hide{opacity:0;pointer-events:none}
.ld-ring{width:40px;height:40px;position:relative}
.ld-ring div{width:32px;height:32px;border-radius:50%;border:3px solid transparent;
border-top-color:var(--primary);position:absolute;animation:spin .8s linear infinite}
.ld-ring div:nth-child(2){width:24px;height:24px;top:4px;left:4px;border-top-color:var(--accent);animation-duration:1.2s}
.ld-ring div:nth-child(3){width:16px;height:16px;top:8px;left:8px;border-top-color:var(--primaryL);animation-duration:.6s}
`;
document.head.appendChild(S);


// ═══ WebGL Weather Background (Three.js) ═══
const WeatherBG=(function(){
let scene,camera,renderer,particles,clock;
let weatherType='clear'; // clear|snow|rain|clouds|fog|storm
let particleCount=0;
const canvas=document.getElementById('weatherBg');
if(!canvas)return{init(){},setWeather(){},dispose(){}};

function init(type){
  weatherType=type||'clear';
  scene=new THREE.Scene();
  camera=new THREE.PerspectiveCamera(60,window.innerWidth/window.innerHeight,1,1000);
  camera.position.z=300;
  renderer=new THREE.WebGLRenderer({canvas,alpha:true,antialias:false});
  renderer.setSize(window.innerWidth,window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio,2));
  clock=new THREE.Clock();
  createParticles();
  createAmbientLight();
  animate();
  window.addEventListener('resize',onResize);
}

function createAmbientLight(){
  const colors={clear:0xfff4e0,snow:0xc8d8f0,rain:0x8899aa,clouds:0xb0b8c4,fog:0xc0c0c0,storm:0x556677};
  const intensities={clear:.6,snow:.4,rain:.3,clouds:.35,fog:.3,storm:.2};
  const amb=new THREE.AmbientLight(colors[weatherType]||0xffffff,intensities[weatherType]||.4);
  scene.add(amb);
  // Gradient background planes
  const bgColors={
    clear:isDark?[0x0a1628,0x1a2a44]:[0xfff8ee,0xe8dcc8],
    snow:isDark?[0x0c1832,0x1a2848]:[0xe8eef6,0xd0d8e8],
    rain:isDark?[0x0a1220,0x162030]:[0xc8d0d8,0xb0b8c4],
    clouds:isDark?[0x0e1628,0x1a2438]:[0xe0e4ea,0xd0d4da],
    fog:isDark?[0x101820,0x182028]:[0xd8dce0,0xc8ccd0],
    storm:isDark?[0x080e18,0x101828]:[0x9098a8,0x808898]
  };
  const [c1,c2]=bgColors[weatherType]||bgColors.clear;
  const bgGeo=new THREE.PlaneGeometry(2000,2000);
  const bgMat=new THREE.ShaderMaterial({
    uniforms:{color1:{value:new THREE.Color(c1)},color2:{value:new THREE.Color(c2)},time:{value:0}},
    vertexShader:`varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
    fragmentShader:`uniform vec3 color1;uniform vec3 color2;uniform float time;varying vec2 vUv;
    void main(){float t=vUv.y+sin(vUv.x*2.+time*.3)*.05;gl_FragColor=vec4(mix(color1,color2,t),1.);}`,
    depthWrite:false
  });
  const bgMesh=new THREE.Mesh(bgGeo,bgMat);
  bgMesh.position.z=-500;
  bgMesh.name='bgPlane';
  scene.add(bgMesh);
}

function createParticles(){
  if(weatherType==='clear'){createSunParticles();return}
  if(weatherType==='fog'){createFogParticles();return}
  const counts={snow:800,rain:1200,clouds:200,storm:1500};
  particleCount=counts[weatherType]||600;
  const geo=new THREE.BufferGeometry();
  const pos=new Float32Array(particleCount*3);
  const vel=new Float32Array(particleCount*3);
  const sizes=new Float32Array(particleCount);
  for(let i=0;i<particleCount;i++){
    pos[i*3]=Math.random()*800-400;
    pos[i*3+1]=Math.random()*600-100;
    pos[i*3+2]=Math.random()*400-200;
    if(weatherType==='snow'){
      vel[i*3]=(Math.random()-.5)*.3;
      vel[i*3+1]=-(Math.random()*.5+.3);
      vel[i*3+2]=(Math.random()-.5)*.2;
      sizes[i]=Math.random()*3+1;
    }else if(weatherType==='rain'||weatherType==='storm'){
      vel[i*3]=(Math.random()-.5)*.1+(weatherType==='storm'?-1:0);
      vel[i*3+1]=-(Math.random()*3+4);
      vel[i*3+2]=0;
      sizes[i]=Math.random()*1.5+.5;
    }else{
      vel[i*3]=(Math.random()-.5)*.15;
      vel[i*3+1]=(Math.random()-.5)*.05;
      vel[i*3+2]=0;
      sizes[i]=Math.random()*8+4;
    }
  }
  geo.setAttribute('position',new THREE.BufferAttribute(pos,3));
  geo.setAttribute('velocity',new THREE.BufferAttribute(vel,3));
  geo.setAttribute('size',new THREE.BufferAttribute(sizes,1));
  const colors={snow:0xffffff,rain:0x8899bb,clouds:0xdde4ee,storm:0x7788aa};
  const opacities={snow:.7,rain:.4,clouds:.15,storm:.5};
  const mat=new THREE.PointsMaterial({
    color:colors[weatherType]||0xffffff,size:2,transparent:true,
    opacity:opacities[weatherType]||.5,blending:THREE.AdditiveBlending,depthWrite:false,
    sizeAttenuation:true
  });
  particles=new THREE.Points(geo,mat);
  scene.add(particles);
}

function createSunParticles(){
  particleCount=150;
  const geo=new THREE.BufferGeometry();
  const pos=new Float32Array(particleCount*3);
  const vel=new Float32Array(particleCount*3);
  for(let i=0;i<particleCount;i++){
    const angle=Math.random()*Math.PI*2;
    const r=Math.random()*300+50;
    pos[i*3]=Math.cos(angle)*r;
    pos[i*3+1]=Math.sin(angle)*r+100;
    pos[i*3+2]=Math.random()*100-200;
    vel[i*3]=Math.cos(angle)*.1;
    vel[i*3+1]=Math.sin(angle)*.1;
    vel[i*3+2]=0;
  }
  geo.setAttribute('position',new THREE.BufferAttribute(pos,3));
  geo.setAttribute('velocity',new THREE.BufferAttribute(vel,3));
  const mat=new THREE.PointsMaterial({
    color:isDark?0x4488cc:0xffdd88,size:3,transparent:true,opacity:.3,
    blending:THREE.AdditiveBlending,depthWrite:false,sizeAttenuation:true
  });
  particles=new THREE.Points(geo,mat);
  scene.add(particles);
}

function createFogParticles(){
  particleCount=100;
  const geo=new THREE.BufferGeometry();
  const pos=new Float32Array(particleCount*3);
  const vel=new Float32Array(particleCount*3);
  for(let i=0;i<particleCount;i++){
    pos[i*3]=Math.random()*1000-500;
    pos[i*3+1]=Math.random()*400-200;
    pos[i*3+2]=Math.random()*200-300;
    vel[i*3]=(Math.random()-.5)*.2;
    vel[i*3+1]=(Math.random()-.5)*.02;
    vel[i*3+2]=0;
  }
  geo.setAttribute('position',new THREE.BufferAttribute(pos,3));
  geo.setAttribute('velocity',new THREE.BufferAttribute(vel,3));
  const mat=new THREE.PointsMaterial({
    color:isDark?0x556677:0xcccccc,size:20,transparent:true,opacity:.08,
    blending:THREE.AdditiveBlending,depthWrite:false,sizeAttenuation:true
  });
  particles=new THREE.Points(geo,mat);
  scene.add(particles);
}

function animate(){
  requestAnimationFrame(animate);
  const dt=clock.getDelta();
  const t=clock.getElapsedTime();
  // Animate background gradient
  const bg=scene.getObjectByName('bgPlane');
  if(bg&&bg.material.uniforms)bg.material.uniforms.time.value=t;
  // Animate particles
  if(particles){
    const pos=particles.geometry.attributes.position;
    const vel=particles.geometry.attributes.velocity;
    if(pos&&vel){
      for(let i=0;i<pos.count;i++){
        pos.array[i*3]+=vel.array[i*3];
        pos.array[i*3+1]+=vel.array[i*3+1];
        pos.array[i*3+2]+=vel.array[i*3+2];
        // Snow wobble
        if(weatherType==='snow')pos.array[i*3]+=Math.sin(t*2+i)*.15;
        // Reset particles that go off screen
        if(pos.array[i*3+1]<-300){pos.array[i*3+1]=300;pos.array[i*3]=Math.random()*800-400}
        if(pos.array[i*3+1]>400)pos.array[i*3+1]=-200;
        if(Math.abs(pos.array[i*3])>500)pos.array[i*3]*=-.9;
      }
      pos.needsUpdate=true;
    }
    // Gentle rotation for sun/fog
    if(weatherType==='clear'||weatherType==='fog')particles.rotation.z+=.0003;
  }
  renderer.render(scene,camera);
}

function onResize(){
  camera.aspect=window.innerWidth/window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth,window.innerHeight);
}

return{init,setWeather(t){weatherType=t},dispose(){renderer?.dispose()}};
})();


// ═══ Data & Weather Loading ═══
const API='https://anthropic-proxy.uiredepositionherzo.workers.dev';
const FALLBACK={"updated_at":"2026-02-14","fuel":{"date":"13.02.2026","stations":44,"prices":{"АИ-92":{"min":57,"max":63.7,"avg":60.3,"count":38},"АИ-95":{"min":62,"max":69.9,"avg":65.3,"count":37},"ДТ зимнее":{"min":74,"max":84.1,"avg":79.4,"count":26},"Газ":{"min":23,"max":32.9,"avg":24.2,"count":19}}},"azs":[{"name":"АЗС ОкиС","address":"РЭБ 2П2 №52","org":"ЗАО \"ОкиС\", ИП Зипенкова Влада Владимировна ","tel":"89825333444"},{"name":"АЗС","address":"автодорога Нижневартовск - Мегион, 2 ","org":"ООО \"Фактор\"","tel":"8 (3466) 480455"},{"name":"АЗС  ОКИС-С","address":"Кузоваткина,41","org":"ООО \"ОКИС-С\", ИП Афрасов Анатолий Афрасович","tel":"8 (3466) 55-51-43"},{"name":"АЗС ОКИС-С","address":"Ленина, 3а/П","org":"ЗАО \"ОкиС\", ИП Узюма А.А. ","tel":"8 (3466) 41-31-64, 8 (3466) 41-65-65"},{"name":"АЗС ОКИС-С","address":"2П2 ЗПУ, 2","org":"ООО \"СОДКОР\", ИП Афрасов А.А.","tel":"(8-3466) 41-31-64,(8-3466) 41-65-65"},{"name":"АЗС ОКИС-С","address":"Северная, 37а","org":"ООО \"СОДКОР\", ИП Касаткин Н.Н.","tel":"(8-3466) 41-31-64,(8-3466) 41-65-65"},{"name":"АЗС №42","address":"Авиаторов, 8","org":"АО \"Томскнефтепродукт\" ВНК","tel":"(3466) 63-31-95, 67-13-66, 63-35-02; 64-12-83"},{"name":"АЗС №43","address":"Индустриальная, 2","org":"АО \"Томскнефтепродукт\" ВНК","tel":"(3466) 63-31-95, 67-13-66, 63-35-02; 64-12-83"},{"name":"АЗС GN","address":"п. Магистраль,2","org":"ИП А.В. Саратников","tel":"(83466) 56-06-90"},{"name":"АЗС 40","address":"2П2 ЗПУ, 10 ст1","org":"ООО \"ЛУКОЙЛ-Уралнефтепродукт\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 43","address":"Индустриальная, 119","org":"ООО \"ЛУКОЙЛ-Уралнефтепродукт\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 41","address":"Ханты-Мансийская,20","org":"ООО \"ЛУКОЙЛ-Уралнефтепродукт\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 42","address":"М.Жукова, 27П","org":"ООО \"ЛУКОЙЛ-Уралнефтепродукт\"","tel":"+7 (3472) 367-803"},{"name":"АЗС 444","address":"Индустриальная, 111б","org":"ОАО \"Газпромнефть-Урал\"","tel":"(83462) 94-11-95"},{"name":"АЗС 445","address":"Интернациональная, 62","org":"ОАО \"Газпромнефть-Урал\"","tel":"(83462) 94-11-95"}],"uk":{"total":42,"houses":904,"top":[{"name":"ООО \"ПРЭТ №3\"","houses":186,"email":"mup@pret3.ru","phone":"(3466) 27-01-89","address":"ул. Северная, д. 28б","director":"Коростелёв Максим Викторович","url":"https://www.pret3.ru/"},{"name":"ООО \"УК \"Диалог\"","houses":170,"email":"dialog.nv@mail.ru","phone":"(3466) 42‒21‒62","address":"ул. Мира, д. 36, пом.1001","director":"Марталлер Кристина Владимировна","url":"https://dialog.uk-site.ru/"},{"name":"АО \"ЖТ №1\"","houses":125,"email":"mail@jt1-nv.ru","phone":"(3466) 63-36-39","address":"Панель №5, ул. 9п, д. 47","director":"Фаттахова Оксана Анатольевна","url":"https://жт1-нв.рф/"},{"name":"ООО \"УК МЖК - Ладья\"","houses":73,"email":"info@mgk-ladya.com","phone":"(3466) 31-13-11","address":"ул. Мира, д. 96, офис 1005","director":"Зятин Леонид Николаевич","url":"https://mgk-ladya.com/"},{"name":"АО \"УК №1\"","houses":65,"email":"mail@uk1-nv.ru","phone":"(3466) 61-33-01","address":"ул. Омская, д. 12а","director":"Чудов Дмитрий Сергеевич","url":"https://uk1-nv.ru/"},{"name":"АО \"РНУ ЖКХ\"","houses":55,"email":"info@rnugkh.ru","phone":"(3466) 49-11-04","address":"ул. Мусы Джалиля, д. 15, офис 1007","director":"Кибардин Антон Владимирович","url":"https://rnugkh.ru/"},{"name":"ООО \"УК Пирс\"","houses":39,"email":"uk-pirs@yandex.ru","phone":"(3466) 56-16-77","address":"ул. Омская, д. 38, офис 1002","director":"Шипицкий Андрей Николаевич","url":"https://ук-пирс.рф/ "},{"name":"ООО \"УК-Квартал\"","houses":33,"email":"kvartal451855@mail.ru","phone":"(3466) 45-18-55","address":"ул. Мусы Джалиля, д. 20А, офис 1001","director":"Елина Ольга Сергеевна","url":"http://kvartal-nv.ru/"},{"name":"ООО \"Данко\"","houses":28,"email":"info@ukdanko.ru","phone":"(3466) 29-16-91","address":"ул. Спортивная, д. 17​, помещение 1076","director":"Кадочкин Павел Анатольевич","url":"https://ukdanko.ru/"},{"name":"ООО \"Ренако-плюс\"","houses":21,"email":"renako55@mail.ru","phone":"(3466) 65‒20‒80","address":"ул. Дружбы Народов, д. 34","director":"Аристова  Евгения Валерьевна","url":null},{"name":"ООО \"УК \"НВ Град\"","houses":19,"email":"ooouknvgrad@yandex.ru","phone":"(3466) 20‒00‒09","address":"ул. Дружбы Народов, д. 7​, пом. 1006 ","director":"Ларина Екатерина Игоревна","url":null},{"name":"ООО УК \"Крепость\"","houses":14,"email":"ukkrep@mail.ru","phone":"(3466) 54‒86‒86","address":"​ул. Омская, д. 14​, офис 1003","director":"Вахрушев Валерий Викторович","url":null},{"name":"ООО \"УК-Квадратные метры\"","houses":11,"email":"uk-kvmetr@yandex.ru","phone":"7(912) 939‒45‒45","address":"ул. 60 лет Октября, д. 80а​, каб. 428","director":"Шугаев Айрат Фанисович","url":null},{"name":"ООО \"УК \"Жилище-Сервис\"","houses":11,"email":"office@comfort-nv.ru","phone":"(3466) 42-26-47","address":"ул. 60 лет Октября, д. 27, офис 1018","director":"Юрьев Константин Петрович","url":"https://comfort-nv.ru/"},{"name":"ООО \"УК\"","houses":10,"email":"uk.ooo.n-v@yandex.ru","phone":"(3466) 49-15-90","address":"ул. Северная, д. 19г","director":"Дунская Светлана Валериановна","url":"https://uk-nv.ru/  "},{"name":"ООО \"КОМПАНИЯ ЛИДЕР\"","houses":7,"email":"nv-office@uk-lider86.ru","phone":"(3466) 49-05-59","address":"ул. Дружбы Народов, д. 36, Офис центр, каб. 303","director":"Кузнецов Даниил Александрович","url":"https://uk-lider86.ru/"},{"name":"ООО УК \"Пилот\"","houses":4,"email":"uk-pilot.crona@yandex.ru","phone":"(3467) 35-34-10","address":"г. Ханты-Мансийск, ул. Гагарина, д. 134","director":"Шарыгин Павел Игоревич","url":null},{"name":"ЖК \"Белые ночи\"","houses":3,"email":"info@tkvegas.com","phone":"7(922) 252-81-23","address":"ул. Школьная, д. 29а","director":"Шихшабеков Кадырбек Идрисович","url":null},{"name":"ТСЖ \"Сосна","houses":3,"email":"tsj-sosna@mail.ru","phone":"(3466) 42-27-02","address":"ул. Ленина, д. 19","director":"Басырова Роза Асгатовна","url":null},{"name":"ТСН \"ТСЖ \"Северная звезда\"","houses":3,"email":"bondarenko-chts@mail.ru","phone":"7(912) 902-24-27","address":"ул. Нефтяников, д. 37","director":"Бондаренко Ирина Яковлевна","url":null},{"name":"ТСН \"ТСЖ Север\"","houses":3,"email":"tsj-sever@inbox.ru","phone":"7(922) 655-77-29","address":"ул. Ленина, д. 17/1","director":"Колесова Анна Сергеевна","url":null},{"name":"ЖК \"Мир\"","houses":1,"email":"JKMir@mail.ru","phone":"(3466) 44-44-30","address":"ул. Ханты-Мансийская, д. 21/3","director":"Теплякова Ольга Николаевна","url":null},{"name":"ТСЖ \"Единение\"","houses":1,"email":"Vartovsk.tsg.edinenie@bk.ru","phone":"(3466) 24-12-46","address":"ул. 60 лет Октября, д. 19","director":"Акаева Лариса Амарбековна","url":null},{"name":"ТСЖ \"Кедр\"","houses":1,"email":"kedr.nv@mail.ru","phone":"(3466) 41-07-11","address":"ул. 60 лет Октября, д. 19а","director":"Шенцова Елена Федоровна","url":"https://kedr-nv.ru/"},{"name":"ТСЖ \"Ладья\"","houses":1,"email":"tsg.ladja@gmail.com","phone":"(3466) 44-90-45","address":"ул. Интернациональная, д. 7","director":"Меньшенин Александр Васильевич","url":null},{"name":"ТСЖ \"Маяк\"","houses":1,"email":"tczmayak@mail.ru","phone":"7(932) 253-84-63","address":"ул. Дружбы Народов, д. 25","director":"Щепеткова Любовь Витальевна","url":null},{"name":"ТСЖ \"Молодежный\"","houses":1,"email":"tsg44nv@gmail.com","phone":"(3466) 48-04-51","address":"ул. Нефтяников, д. 44","director":"Лапцевич Елена Анатольевна","url":"http://tsg-nv.ru/"},{"name":"ТСЖ \"Спутник\"","houses":1,"email":"sputnik.tsg@gmail.com","phone":"7(919) 532-30-00","address":"ул. Ленина, д. 7/2","director":"Бухарова Наталья Анатольевна","url":null},{"name":"ТСН \"Единство\"","houses":1,"email":"edinstvo71@yandex.ru","phone":"(3466) 49-18-36","address":"ул. Ленина, д. 7/1","director":"Мойсей Виталий Михайлович","url":"https://tsn-edinstvo.ru/"},{"name":"ТСН \"Союз\"","houses":1,"email":"60-9-33@mail.ru","phone":"7(982) 505-66-75","address":"ул. 60 лет Октября, д. 9","director":"Макиенко Юлия Вениаминовна","url":null},{"name":"ТСН \"ТСЖ Брусника\"","houses":1,"email":"sovetdoma85@internet.ru","phone":"7(995) 493-27-02","address":"ул. Нефтяников, д. 85","director":"Борисова Лилия Нигматьяновна","url":null},{"name":"ТСН \"ТСЖ Дружба\"","houses":1,"email":"druzhba.tsg@gmail.com","phone":"7(922) 252-81-23","address":"ул. Дружбы Народов, д. 22/1","director":"Цвиренко Ольга Леонидовна","url":null},{"name":"ТСН \"ТСЖ Мира 23\"","houses":1,"email":"tsjmira23@mail.ru","phone":"7(902) 858-14-96","address":"ул. Мира, д. 23","director":"Починок Ольга Викторовна","url":null},{"name":"ТСН \"ТСЖ Надежда\"","houses":1,"email":"tsj-nadezhda@mail.ru","phone":"7(912) 906-79-98","address":"ул. 60 лет Октября, д. 76","director":"Рой Елена Александровна","url":null},{"name":"ТСН \"ТСЖ Наш уютный дом\"","houses":1,"email":"tsg.uytnidom@gmail.com","phone":"7(982) 566-05-88","address":"ул. Чапаева, д. 13/1","director":"Нотова Наталья Анатольевна","url":null},{"name":"ТСН \"ТСЖ Пик 31\"","houses":1,"email":"pic_31@ro.ru","phone":"7(922)781-95-62","address":"ул. Пикмана, д. 31","director":"Арапов Иван Петрович","url":null},{"name":"ТСН \"ТСЖ Премьер\"","houses":1,"email":"premier.tsn@gmail.com","phone":"7(922) 255-49-89","address":"ул. Нововартовская, д. 5","director":"Хазиев Артур Галинурович","url":"http://premier-tsn.ru/"},{"name":"ТСН \"ТСЖ Содружество\"","houses":1,"email":"souztsg.86@gmail.com","phone":"7(922) 252-81-23","address":"ул. Дружбы Народов, д. 28б","director":"Губанов Евгений Сергеевич","url":null},{"name":"ТСН \"ТСЖ \"Успех\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Чапаева, д. 13/2","director":"Газизова Альфия Ахметжановна","url":null},{"name":"ТСН \"ТСЖ Феникс\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Ленина, д. 46","director":"Пермитин Александр Владимирович","url":null},{"name":"ТСН \"ТСЖ Черногорка\"","houses":1,"email":"souztsg.86@gmail.com ","phone":"7(922) 252-81-23","address":"ул. Дзержинского, д. 9","director":"Малышев Даниил Валерьевич","url":null},{"name":"ТСН ТСЖ \"Осенняя 3\"","houses":1,"email":"osennyaya3@mail.ru","phone":"7(922) 794-63-46","address":"ул. Осенняя, д. 3","director":"Верина Ирина Анатольевна","url":null}]},"education":{"kindergartens":25,"schools":33,"culture":10,"sport_orgs":4,"sections":155,"sections_free":102,"sections_paid":53,"dod":3},"waste":{"total":500,"groups":[{"name":"Опасные отходы (лампы, термометры, батарейки)","count":289},{"name":"Пластик","count":174},{"name":"Бумага","count":18},{"name":"Лом цветных и черных металлов","count":7},{"name":"Бытовая техника. Оргтехника","count":5},{"name":"Аккумуляторы","count":5},{"name":"Автомобильные шины","count":2}]},"names":{"boys":[{"n":"Артём","c":530},{"n":"Максим","c":428},{"n":"Александр","c":392},{"n":"Дмитрий","c":385},{"n":"Иван","c":311},{"n":"Михаил","c":290},{"n":"Кирилл","c":289},{"n":"Роман","c":273},{"n":"Матвей","c":243},{"n":"Алексей","c":207}],"girls":[{"n":"Виктория","c":392},{"n":"Анна","c":367},{"n":"София","c":356},{"n":"Мария","c":349},{"n":"Анастасия","c":320},{"n":"Дарья","c":308},{"n":"Полина","c":292},{"n":"Алиса","c":290},{"n":"Арина","c":284},{"n":"Ксения","c":279}]},"gkh":[{"name":"АО \"Горэлектросеть\" диспетчерская","phone":"8(3466) 26-08-85, 26-07-78"},{"name":"АО \"Жилищный трест №1\" диспетчерская","phone":"8(3466) 29-11-99, 64-21-99"},{"name":"АО \"УК  №1\" диспетчерская","phone":"8(3466) 24-69-50, 64-20-53"},{"name":"Единая Дежурная Диспетчерская Служба (ЕДДС)","phone":"8(3466) 29-72-50, 112"},{"name":"ООО \"Нижневартовскгаз\" диспетчерская","phone":"8(3466) 61-26-12, 61-30-34"},{"name":"ООО \"Нижневартовские коммунальные системы\" диспетчерская","phone":"8(3466) 44-77-44, 40-66-88"},{"name":"ООО \"ПРЭТ №3\" диспетчерская","phone":"8(3466)27-25-71, 27-33-32"},{"name":"Филиал АО \"Горэлектросеть\" Управление теплоснабжением города Нижневартовска диспетчерская","phone":"8(3466) 67-15-03, 24-78-63"}],"tariffs":[{"title":"Полезная информация","desc":""},{"title":"Размер платы за жилое помещение","desc":"Постановления администрации города от 21.12.2012 №1586 &quot;Об утверждении размера платы за содержа"},{"title":"Электроэнергия","desc":""},{"title":"Газоснабжение","desc":""},{"title":"Индексы изменения размера платы граждан за коммунальные услуги","desc":""},{"title":"Услуги в сфере по обращению с твердыми коммунальными отходами","desc":"Постановление администрации города от 19.01.2018 №56 &quot;Об установлении нормативов накопления тве"},{"title":"Водоснабжение, водоотведение","desc":""},{"title":"Тепловая энергия","desc":""}],"transport":{"routes":62,"stops":344,"municipal":34,"commercial":28,"routes_list":[{"num":"1","title":"Железнодорожный вокзал - поселок Дивный","start":"Железнодорожный вокзал","end":"Поселок Дивный(конечная)"},{"num":"2","title":"Поселок Энтузиастов - АСУНефть","start":"Поселок Энтузиастов (конечная)","end":"АСУнефть (в направлении ТК &quot;СЛАВТЭК&quot;)"},{"num":"3","title":"Поселок у северной рощи – МЖК","start":"Поселок у северной рощи","end":"МЖК (конечная)"},{"num":"4","title":"Аэропорт-поселок у северной рощи","start":"Аэропорт (конечная)","end":"Поселок у северной рощи"},{"num":"5К","title":"ДРСУ - СОНТ У озера","start":"ДРСУ","end":"СОНТ &quot;У озера&quot;"},{"num":"5","title":"ДРСУ-поселок у северной рощи","start":"ДРСУ (конечная)","end":"Поселок у северной рощи"},{"num":"6К","title":"Железнодорожный вокзал - Улица 6П","start":"Железнодорожный вокзал","end":"Улица 6П"},{"num":"6","title":"ПАТП №2 - железнодорожный вокзал","start":"ПАТП-2 (конечная)","end":"Железнодорожный вокзал"},{"num":"7","title":"ПАТП №2 –городская больница №3","start":"ПАТП-2 (конечная)","end":"Городская поликлиника №3 (конечная)"},{"num":"8","title":"Авторынок-АСУнефть","start":"Авторынок (конечная)","end":"АСУнефть (в направлении ТК &quot;СЛАВТЭК&quot;)"},{"num":"9","title":"Аэропорт -Старовартовская","start":"Аэропорт (конечная)","end":"Старовартовская (конечная)"},{"num":"10","title":"ПАТП №2 – авторынок","start":"ПАТП-2 (конечная)","end":"Авторынок (конечная)"},{"num":"11К","title":"ДРСУ-СОНТ «Авиатор»- Управление социальной защиты населения","start":"ДРСУ (конечная)","end":"Управление социальной защиты населения (в направлении Хоккейный корт)"},{"num":"11","title":"Управление социальной защиты населения - ДРСУ","start":"ДРСУ (конечная)","end":"Управление социальной защиты населения (в направлении Хоккейный корт)"},{"num":"12","title":"ПАТП №2 –авторынок","start":"ПАТП-2 (конечная)","end":"Авторынок (конечная)"}]},"road_service":{"total":107,"types":[{"name":"АЗС","count":59},{"name":"Парковка","count":48}]},"road_works":{"total":24,"items":[{"title":"Обустройство разделительного (отбойного) ограждения для разделения транспортных потоков на участке а"},{"title":"улица Интернациональная (на участке от улицы Дзержинского до улицы Нефтяников) - устранение колейнос"},{"title":"улица Интернациональная (в районе дома 74/1 улицы Индустриальная (при движении от «САТУ» на кольцо) "},{"title":"улица Интернациональная (в районе пересечения с улицей Зимней) - устранение колейности"},{"title":"улица Ханты–Мансийская (на участке от улицы Омская до улицы Профсоюзная) - устранение колейности"},{"title":"улица Маршала Жукова (в районе пересечения с улицей Зимняя, около МУП «Горводоканал») - устранение к"},{"title":"улица Г.И. Пикмана (от проспекта Победы до улицы Мусы Джалиля) - устранение колейности"},{"title":"улица 60 лет Октября, 23 - ремонт тротуара на улично-дорожной сети города "}]},"building":{"permits":210,"objects":112,"reestr":3,"permits_trend":[{"year":2008,"count":20},{"year":2009,"count":18},{"year":2010,"count":19},{"year":2011,"count":22},{"year":2012,"count":25},{"year":2013,"count":18},{"year":2014,"count":30},{"year":2015,"count":21},{"year":2016,"count":26},{"year":2017,"count":9}]},"land_plots":{"total":7,"items":[{"address":"Ханты-Мансийский автономный округ – Югра, г. Нижневартовск, район Нижневартовско","square":"108508"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, западный промышленны","square":"300000"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, северо-западный пром","square":"165000"},{"address":"Ханты-Мансийский автономный округ - Югра, г. Нижневартовск, северный промышленны","square":"255000"},{"address":"Ханты-Мансийский автономный округ- Югра, г. Нижневартовск, квартал 20 Восточного","square":"12000"}]},"accessibility":{"total":136,"groups":[{"name":"Учреждения образования","count":30},{"name":"Светофоры со звуковыми сигналами","count":18},{"name":"Дорожный знак «Слепые пешеходы»","count":16},{"name":"Пандусы","count":16},{"name":"Учреждения культуры","count":13},{"name":"Дорожный знак «Инвалиды»","count":12},{"name":"Учреждения физической культуры и спорта","count":12},{"name":"Учреждения здравоохранения и социальной защиты населения","count":11},{"name":"Здания структурных подразделений администрации города","count":6},{"name":"Учреждения транспорта и связи","count":2}]},"culture_clubs":{"total":148,"free":125,"paid":23,"items":[{"name":"вокальный коллектив","age":"5-14","pay":"бесплатно"},{"name":"Студия  авторской  песни  «Рио-Рита»","age":"25-29","pay":"бесплатно"},{"name":"Кружок класссического вокала","age":"18-0","pay":"бесплатно"},{"name":"вокальная шоу-группа «Джулия»","age":"8-14","pay":"бесплатно"},{"name":"Ансамбль «Северяне»","age":"18-0","pay":"бесплатно"},{"name":"Почетный коллектив народного творчества, народный самодеятельный коллектив, хор  ветеранов труда «Красная  гвоздика» им. В. Салтысова","age":"45-0","pay":"бесплатно"},{"name":"Народный самодеятельный коллектив, хор русской песни  «Сибирские зори» Ансамбль-спутник «Девчата» ","age":"18-0","pay":"бесплатно"},{"name":"ДЖАЗ-БАЛЕТ","age":"14-35","pay":"бесплатно"},{"name":"Детский  джаз-балет","age":"7-14","pay":"бесплатно"},{"name":"Народный самодеятельный коллектив, хореографический ансамбль «Кавказ» младшая группа","age":"7-16","pay":"бесплатно"},{"name":"Образцовый художественный коллектив, хореографический ансамбль «Альянс»","age":"10-14","pay":"бесплатно"},{"name":"Хореографический  ансамбль «Искорки»","age":"5-12","pay":"платно"}]},"trainers":{"total":191},"salary":{"total":4332,"years":[2017,2018,2019,2020,2021,2022,2023,2024],"trend":[{"year":2017,"avg":98.6,"count":558},{"year":2018,"avg":106.9,"count":563},{"year":2019,"avg":121.9,"count":584},{"year":2020,"avg":127.5,"count":546},{"year":2021,"avg":134.0,"count":527},{"year":2022,"avg":149.5,"count":517},{"year":2023,"avg":162.4,"count":515},{"year":2024,"avg":177.8,"count":519}],"growth_pct":80.3,"latest_avg":177.8},"hearings":{"total":543,"trend":[{"year":2019,"count":56},{"year":2020,"count":49},{"year":2021,"count":36},{"year":2022,"count":64},{"year":2023,"count":66},{"year":2024,"count":72},{"year":2025,"count":75},{"year":2026,"count":11}],"recent":[{"date":"12.02.2026","title":"О проведении общественных обсуждений по проекту планировки территории улично-дорожной сети в части у"},{"date":"11.02.2026","title":"О проведении общественных обсуждений по проекту межевания территории планировочного района 30 города"},{"date":"06.02.2026","title":"О проведении общественных обсуждений по проектам о предоставлении разрешения на отклонение от предел"},{"date":"28.01.2026","title":"О проведении общественных обсуждений по проекту внесения изменений в проект межевания территории пла"},{"date":"28.01.2026","title":"О проведении общественных обсуждений по проекту внесения изменений в проект планировки территории и "}]},"gmu_phones":[{"org":"Предоставление сведений из реестра муниципального имущества","tel":"(3466) 41-06-26\r\n(3466) 24-19-10"},{"org":"Проведение муниципальной экспертизы проектов освоения лесов,","tel":"(3466) 41-20-26"},{"org":"Предоставление водных объектов, находящихся в собственности ","tel":"(3466) 41-20-26"},{"org":"Предоставление водных объектов, находящихся в собственности ","tel":"(3466) 41-20-26"},{"org":"Государственная регистрация заявлений о проведении обществен","tel":"(3466) 41-53-04"},{"org":"Организация общественных обсуждений среди населения о намеча","tel":"(3466) 41-53-04"},{"org":"Выдача разрешений на снос или пересадку зеленых насаждений н","tel":"(3466) 41-20-26"},{"org":"Предоставление информации о реализации программ начального о","tel":"(3466) 43-75-81\r\n(3466) 43-75-24\r\n(3466) 42-24-10"},{"org":"Предоставление информации об образовательных программах и уч","tel":"(3466) 43-75-24\r\n(3466) 43-76-24\r\n(3466) 42-24-10"},{"org":"Предоставление информации о текущей успеваемости обучающегос","tel":"(3466) 43-75-24"}],"demography":[{"marriages":"366","birth":"200","boys":"100","girls":"100","date":"09.11.2018"}],"budget_bulletins":{"total":15,"items":[{"title":"2024 год","desc":"1 квартал 2024 года","url":"https://www.n-vartovsk.ru/upload/iblock/f4f/iyrnf9utmz2wl7pvk1a3jcob8dldt5iq/4grze2d6pziz3bzf3vvtbg9iloss6gtg.docx"},{"title":"2023 год","desc":"1 квартал 2023 года","url":"https://www.n-vartovsk.ru/upload/iblock/7d9/vblnpmi1vh1gf1qcrv20kwrbnxilg3sr/9c3zax3mx13yyb3zxncdhhj7zwxi7up4.docx"},{"title":"2022 год","desc":"Финансовый бюллетень за 1 квартал 2022 года","url":"https://www.n-vartovsk.ru/upload/iblock/4a3/i356g0vkyyqft80yschznahxlrx0zeb7/oycg03f3crsrhu7mum89jkyvrap4c6oz.docx"},{"title":"2021 год","desc":"Финансовый бюллетень за 1 квартал 2021 года","url":"https://www.n-vartovsk.ru/upload/iblock/8b6/qxglhnbp9sk9b68gvo5pazs4v16bcplj/5553ffcd956c733ad2b403318d6403a4.docx"},{"title":"2020 год","desc":"Финансовый бюллетень за 1 квартал 2020 года","url":"https://www.n-vartovsk.ru/upload/iblock/232/c03d912c9586247c9703d656b4c32879.docx"},{"title":"2019 год","desc":"Финансовый бюллетень 1 квартал 2019 года","url":"https://www.n-vartovsk.ru/upload/iblock/055/f16691e345f7816323423dfeb8ba7e0e.doc"},{"title":"2018 год","desc":"Финансовый бюллетень за 1 квартал 2018 года","url":"https://www.n-vartovsk.ru/upload/iblock/dcd/2621bcc26bbc8d8fffbcb5d6ecf90d0e.doc"},{"title":"2017 год","desc":"Финансовый бюллетень за 1 квартал 2017 года","url":"https://www.n-vartovsk.ru/upload/iblock/21f/d28d3kuziakrt01ie0o99ntar7lg3nuy/6361178c8521c5647a4c3c3ca5e60ee8.doc"},{"title":"2016 год","desc":"Финансовый бюллетень за 1 квартал 2016 года","url":"https://www.n-vartovsk.ru/upload/iblock/d18/7f7c4e392c3d6414ad3d0f84dd0b6479.doc"},{"title":"2015 год","desc":"Финансовый бюллетень за 1 полугодие 2015 года","url":"https://www.n-vartovsk.ru/upload/iblock/592/vfg070q95hablw163enhamzztljx9kaj/ca01446ccc0784a99f5f313515ec94c3.doc"}]},"budget_info":{"total":14,"items":[{"title":"2024 год","desc":"январь 2024 года","url":"https://www.n-vartovsk.ru/upload/iblock/3b0/nx0kerqbqi96emliwgctiup4e6cgz4cf/nhvc1qw6m5rxxj63vd4dmlsv55luyp4f.xls"},{"title":"2023 год","desc":"январь 2023 года","url":"https://www.n-vartovsk.ru/upload/iblock/636/ijxbpxgusrszdxfp2ko65lg3v70uiced/cv3z10xzcw7tcj2qudzz3qorlkuhvmz2.xls"},{"title":"2022 год","desc":"Январь 2022 года","url":"https://www.n-vartovsk.ru/upload/iblock/947/qr7plqmr98mqdvpggnbpwylvwsgibkuo/ghafnfiadko3pb3x9qmaxy6cyh0ek50q.xls"},{"title":"2021 год","desc":"январь 2021 года","url":"https://www.n-vartovsk.ru/upload/iblock/ec1/esrcxgu7itynh7sdgr1yz8pgpsqde34d/ccac4fa312a21129efd8600d42cd7c8a.xls"},{"title":"2020 год","desc":"Январь 2020 год","url":"https://www.n-vartovsk.ru/upload/iblock/7ae/1b2f8416e003a9a2010e49640f824378.xls"},{"title":"2019 год","desc":"январь","url":"https://www.n-vartovsk.ru/upload/iblock/456/feacd041fe9023571aba0c13cd1dd630.xls"},{"title":"2018 год","desc":"Январь","url":"https://www.n-vartovsk.ru/upload/iblock/6c6/c4821cbae84703542927dce0c154f0c7.xlsx"},{"title":"2017 год","desc":"январь","url":"https://www.n-vartovsk.ru/upload/iblock/58b/d6vly8vwdtfeq2sep5auphz6c714b13c/4b106f646e745a1e9f46d8f6789bffe7.xlsx"},{"title":"2016 год","desc":"январь 2016","url":"https://www.n-vartovsk.ru/upload/iblock/69d/1fde18917556cb2940ef9a9ea5af57f0.xlsx"},{"title":"2015 год","desc":"на 01.02.2015 год","url":"https://www.n-vartovsk.ru/upload/iblock/3bd/3a0c4a60d04dacc4ebf3856162e31b9d.xlsx"}]},"agreements":{"total":138,"total_summ":107801.9,"total_inv":15603995.88,"total_gos":3919554.51,"by_type":[{"name":"Энергосервис","count":123},{"name":"ГЧП","count":5},{"name":"КЖЦ","count":3},{"name":"Аренда имущества","count":1},{"name":"Капремонт","count":1},{"name":"Инвестпроекты","count":1},{"name":"Инвестконтракты","count":1},{"name":"РИП","count":1},{"name":"Соцпартнёрство","count":1},{"name":"ЗПК","count":1}],"top":[{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по строительству объекта и сдаче результата работ Заказчику по Акту приемки за-конченного с","org":"строительство","date":"25.09.2020","summ":41350.7,"vol_inv":0.0,"vol_gos":248104.4,"year":"10"},{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по разработке проектной документации, в соответствии с Заданием на внесение изменений в про","org":"строительство","date":"12.11.2019","summ":39837.3,"vol_inv":0.0,"vol_gos":239023.8,"year":"9"},{"type":"КЖЦ","title":"Акционерное общество «Государственная компания «Северавтодор»","desc":"- работы по разработке проектной документации, в соответствии с Заданием на внесение изменений в про","org":"строительство","date":"03.06.2019","summ":26076.9,"vol_inv":0.0,"vol_gos":156461.8,"year":"9"},{"type":"Соцпартнёрство","title":"ООО &quot;Пилипака и компания&quot;","desc":"Реализация инвестиционного проекта &quot;Строительство ТК &quot;Станция&quot;","org":"Торговля","date":"15.12.2020","summ":537.0,"vol_inv":1600000.0,"vol_gos":0.0,"year":"6"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"07.08.2023","summ":0.0,"vol_inv":5048.008,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":2028.98661,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":10507.55601,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"02.08.2023","summ":0.0,"vol_inv":3255.55993,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"31.07.2023","summ":0.0,"vol_inv":4476.34425,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"07.08.2023","summ":0.0,"vol_inv":5728.50495,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"15.05.2023","summ":0.0,"vol_inv":2828.58625,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"15.05.2023","summ":0.0,"vol_inv":5134.71,"vol_gos":0.0,"year":"7"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":908.232,"vol_gos":0.0,"year":"5"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":313.248,"vol_gos":0.0,"year":"5"},{"type":"Энергосервис","title":"АО &quot;ГАЗПРОМ ЭНЕРГОСБЫТ ТЮМЕНЬ&quot;","desc":"оказание услуг, направленных на энергосбережение и повышение энергетической эффективности использова","org":"социальная","date":"26.12.2022","summ":0.0,"vol_inv":876.915,"vol_gos":0.0,"year":"5"}]},"property":{"lands":688,"movable":978,"realestate":8449,"stoks":13,"privatization":471,"rent":148,"total":10128},"business":{"info":1995,"smp_messages":0,"events":0},"advertising":{"total":128},"communication":{"total":25},"archive":{"expertise":0,"list":1500},"documents":{"docs":35385,"links":38500,"texts":35385},"programs":{"total":5,"items":[{"title":"ПЕРЕЧЕНЬ МУНИЦИПАЛЬНЫХ ПРОГРАММ ГОРОДА НИЖНЕВАРТОВСКА, ДЕЙСТВУЮЩИХ В 2026 ГОДУ"},{"title":"ПЕРЕЧЕНЬ МУНИЦИПАЛЬНЫХ ПРОГРАММ ГОРОДА НИЖНЕВАРТОВСКА, ДЕЙСТВОВАВШИХ В 2025 ГОДУ"},{"title":"ПЛАН МЕРОПРИЯТИЙ ПО РЕАЛИЗАЦИИ СТРАТЕГИИ СОЦИАЛЬНО-ЭКОНОМИЧЕСКОГО РАЗВИТИЯ ГОРОДА НИЖНЕВАРТОВСКА ДО "},{"title":"СТРАТЕГИЯ СОЦИАЛЬНО-ЭКОНОМИЧЕСКОГО РАЗВИТИЯ ГОРОДА НИЖНЕВАРТОВСКА ДО 2036 ГОДА"},{"title":"ПЕРЕЧЕНЬ ГОСУДАРСТВЕННЫХ ПРОГРАММ ХАНТЫ-МАНСИЙСКОГО АВТОНОМНОГО ОКРУГА – ЮГРЫ"}]},"news":{"total":1018,"rubrics":1332,"photos":0,"trend":[{"year":2020,"count":15},{"year":2021,"count":3},{"year":2025,"count":867},{"year":2026,"count":133}]},"ad_places":{"total":414},"territory_plans":{"total":87},"labor_safety":{"total":29},"appeals":{"total":8},"msp":{"total":14,"items":[{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""},{"title":""}]},"counts":{"construction":112,"phonebook":576,"admin":157,"sport_places":30,"mfc":11,"msp":14,"trainers":191,"bus_routes":62,"bus_stops":344,"accessibility":136,"culture_clubs":148,"hearings":543,"permits":210,"property_total":10128,"agreements_total":138,"budget_docs":29,"privatization":471,"rent":148,"advertising":128,"documents":35385,"archive":1500,"business_info":1995,"smp_messages":0,"news":1018,"territory_plans":87},"datasets_total":72,"datasets_with_data":67};

async function loadData(){
  try{const r=await fetch(API+'/firebase/opendata_infographic.json',{signal:AbortSignal.timeout(5000)});
  if(r.ok){const d=await r.json();if(d&&d.fuel)return d}}catch(e){}
  return FALLBACK;
}

// Open-Meteo: Нижневартовск 60.9344°N, 76.5531°E — free, no API key
async function loadWeather(){
  try{
    const r=await fetch('https://api.open-meteo.com/v1/forecast?latitude=60.9344&longitude=76.5531&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day&timezone=Asia/Yekaterinburg',{signal:AbortSignal.timeout(4000)});
    if(r.ok){const d=await r.json();return d.current||null}
  }catch(e){}
  return null;
}

// WMO weather code → type + emoji + description
function weatherInfo(code,isDay){
  if(code===undefined||code===null)return{type:'clear',emoji:'🌤️',desc:'Ясно',badge:'clear'};
  if(code<=1)return{type:'clear',emoji:isDay?'☀️':'🌙',desc:isDay?'Ясно':'Ясная ночь',badge:'sun'};
  if(code<=3)return{type:'clouds',emoji:'⛅',desc:'Облачно',badge:'clouds'};
  if(code<=48)return{type:'fog',emoji:'🌫️',desc:'Туман',badge:'fog'};
  if(code<=57)return{type:'rain',emoji:'🌧️',desc:'Морось',badge:'rain'};
  if(code<=67)return{type:'rain',emoji:'🌧️',desc:'Дождь',badge:'rain'};
  if(code<=77)return{type:'snow',emoji:'🌨️',desc:'Снег',badge:'snow'};
  if(code<=82)return{type:'rain',emoji:'🌧️',desc:'Ливень',badge:'rain'};
  if(code<=86)return{type:'snow',emoji:'❄️',desc:'Снегопад',badge:'snow'};
  if(code<=99)return{type:'storm',emoji:'⛈️',desc:'Гроза',badge:'storm'};
  return{type:'clouds',emoji:'☁️',desc:'Облачно',badge:'clouds'};
}

const badgeColors={
  sun:{bg:'rgba(255,200,50,.15)',color:'#b8860b'},
  clouds:{bg:'rgba(120,140,170,.12)',color:'#5a6a7a'},
  fog:{bg:'rgba(160,170,180,.12)',color:'#6a7a8a'},
  rain:{bg:'rgba(60,120,200,.12)',color:'#2a5a9a'},
  snow:{bg:'rgba(100,160,220,.12)',color:'#4a7aaa'},
  storm:{bg:'rgba(80,60,120,.15)',color:'#5a3a8a'},
  clear:{bg:'rgba(100,200,150,.1)',color:'#2a8a5a'}
};

// ═══ Utility functions ═══
function fmtDate(iso){
  if(!iso)return'—';
  try{return new Date(iso).toLocaleDateString('ru-RU',{day:'numeric',month:'long',year:'numeric'})}
  catch(e){return String(iso).substring(0,10)}
}
function haptic(){try{tg?.HapticFeedback?.impactOccurred('light')}catch(e){}}
function safe_int(v){try{return parseInt(v)||0}catch(e){return 0}}

function fuelTip(fp){
  const gas=fp['Газ'],ai95=fp['АИ-95'];
  if(!gas||!ai95)return'Данные обновляются ежедневно';
  return'Газ дешевле АИ-95 в '+(ai95.avg/gas.avg).toFixed(1)+'× — экономия ~'+Math.round((ai95.avg-gas.avg)*40)+' ₽ на полном баке';
}
function ukTip(uk){
  if(!uk?.top?.length)return'';
  const t3=uk.top.slice(0,3),hs=t3.reduce((s,u)=>s+u.houses,0);
  return'Топ-3 УК обслуживают '+Math.round(hs/uk.houses*100)+'% домов ('+hs+' из '+uk.houses+')';
}
function eduTip(ed){
  if(!ed)return'';
  return(ed.sections_free||0)+' бесплатных секций — '+Math.round((ed.sections_free||0)/(ed.sections||1)*100)+'% от всех';
}
function wasteTip(wg){
  if(!wg?.length)return'';
  const total=wg.reduce((s,w)=>s+w.count,0);
  return total+' точек раздельного сбора. '+wg[0]?.name+' — '+Math.round(wg[0]?.count/total*100)+'% всех точек';
}
function transTip(t){
  if(!t)return'';
  return t.routes+' маршрутов, '+t.stops+' остановок. '+t.municipal+' муниципальных';
}


// ═══ React Components ═══
const {useState,useEffect,useRef,useCallback}=React;

// --- AnimatedNumber: counts up from 0 ---
function AnimatedNumber({value,duration=1200,suffix=''}){
  const[display,setDisplay]=useState(0);
  const ref=useRef();
  useEffect(()=>{
    const n=typeof value==='number'?value:parseInt(value)||0;
    if(!n)return void setDisplay(0);
    let start=null;
    const step=(ts)=>{
      if(!start)start=ts;
      const p=Math.min((ts-start)/duration,1);
      const ease=1-Math.pow(1-p,3);
      setDisplay(Math.round(n*ease));
      if(p<1)ref.current=requestAnimationFrame(step);
    };
    ref.current=requestAnimationFrame(step);
    return()=>cancelAnimationFrame(ref.current);
  },[value,duration]);
  return h('span',null,display.toLocaleString('ru')+suffix);
}

// --- Card wrapper with IntersectionObserver ---
function Card({children,full,expandable,section,className='',onClick,expanded:expProp,onToggle}){
  const ref=useRef();
  const[visible,setVisible]=useState(false);
  useEffect(()=>{
    if(!ref.current||!('IntersectionObserver' in window))return void setVisible(true);
    const obs=new IntersectionObserver(([e])=>{if(e.isIntersecting){setVisible(true);obs.disconnect()}},
      {threshold:.08,rootMargin:'0px 0px -20px 0px'});
    obs.observe(ref.current);
    return()=>obs.disconnect();
  },[]);
  const cls=['card',full&&'full',expandable&&'expandable',visible&&'visible',expProp&&'expanded',className].filter(Boolean).join(' ');
  const handleClick=useCallback(()=>{
    if(expandable&&onToggle){onToggle();haptic()}
    if(onClick)onClick();
  },[expandable,onToggle,onClick]);
  return h('div',{ref,className:cls,'data-section':section,onClick:(expandable&&onToggle)?handleClick:onClick},children);
}

// --- Section Title ---
function SectionTitle({icon,text,section}){
  return h('div',{className:'section-title','data-section':section},icon+' '+text);
}

// --- Tip ---
function Tip({color,icon,text}){
  return h('div',{className:'tip '+color},
    h('span',{className:'tip-icon'},icon),text);
}

// --- ExpandBtn ---
function ExpandBtn({expanded,label='Подробнее',labelClose='Свернуть'}){
  return h('div',{className:'expand-btn'},(expanded?'▲ '+labelClose:'▼ '+label));
}

// --- Weather Banner ---
function WeatherBanner({weather}){
  if(!weather)return null;
  const wi=weatherInfo(weather.weather_code,weather.is_day);
  const bc=badgeColors[wi.badge]||badgeColors.clear;
  const temp=Math.round(weather.temperature_2m);
  const sign=temp>0?'+':'';
  return h('div',{className:'weather-bar'},
    h('div',{className:'weather-icon'},wi.emoji),
    h('div',{className:'weather-info'},
      h('div',{className:'weather-temp'},sign+temp+'°C'),
      h('div',{className:'weather-desc'},wi.desc),
      h('div',{className:'weather-extra'},
        '💨 '+Math.round(weather.wind_speed_10m)+' км/ч · 💧 '+weather.relative_humidity_2m+'%')
    ),
    h('div',{className:'weather-badge',style:{background:bc.bg,color:bc.color}},
      'Нижневартовск')
  );
}

// --- FuelCard ---
function FuelCard({fuel}){
  const fp=fuel?.prices||{};
  const colors={'АИ-92':'#16a34a','АИ-95':'#ea580c','ДТ зимнее':'#dc2626','Газ':'#0d9488'};
  const maxP=Math.max(...Object.values(fp).map(v=>v.max||0),1);
  const chartRef=useRef();
  const chartInst=useRef();
  const[expanded,setExpanded]=useState(false);

  useEffect(()=>{
    if(!expanded||!chartRef.current)return;
    if(chartInst.current)return;
    const tickC=isDark?'rgba(255,255,255,.4)':'rgba(0,0,0,.3)';
    const gridC=isDark?'rgba(255,255,255,.06)':'rgba(0,0,0,.04)';
    const labels=Object.keys(fp);
    chartInst.current=new Chart(chartRef.current,{type:'bar',data:{labels,datasets:[
      {label:'Мин.',data:labels.map(l=>fp[l].min),backgroundColor:'rgba(22,163,74,.5)',borderRadius:6},
      {label:'Средн.',data:labels.map(l=>fp[l].avg),backgroundColor:'rgba(13,148,136,.5)',borderRadius:6},
      {label:'Макс.',data:labels.map(l=>fp[l].max),backgroundColor:'rgba(220,38,38,.4)',borderRadius:6}
    ]},options:{responsive:true,maintainAspectRatio:false,animation:{duration:1200,easing:'easeOutQuart'},
      plugins:{legend:{labels:{color:tickC,font:{size:9,family:'Inter'},padding:6}}},
      scales:{x:{ticks:{color:tickC,font:{size:9}},grid:{display:false}},
      y:{ticks:{color:tickC,font:{size:8},callback:v=>v+' ₽'},grid:{color:gridC}}}}});
  },[expanded]);

  return h(Card,{full:true,expandable:true,section:'fuel',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--orangeBg)'}},'⛽'),
      h('div',null,
        h('div',{className:'card-title'},'Цены на топливо'),
        h('div',{className:'card-sub'},(fuel?.stations||0)+' АЗС · '+(fuel?.date||'')))),
    ...Object.entries(fp).map(([name,v])=>{
      const pct=Math.round((v.avg/maxP)*100);
      const col=colors[name]||'#0f766e';
      return h('div',{className:'fuel-row',key:name},
        h('span',{className:'fuel-name'},name),
        h('div',{className:'fuel-bar'},
          h('div',{className:'fuel-fill',style:{'--w':pct+'%',width:pct+'%',background:col}},v.min+'–'+v.max)),
        h('span',{className:'fuel-avg',style:{color:col}},v.avg+'₽'));
    }),
    h('div',{className:'expand-content'},
      h('div',{className:'chart-wrap'},h('canvas',{className:'chart',ref:chartRef}))),
    h(ExpandBtn,{expanded}),
    h(Tip,{color:'orange',icon:'💡',text:fuelTip(fp)}));
}


// --- UK Card ---
function UKCard({uk}){
  const top=uk?.top||[];
  const maxH=top[0]?.houses||1;
  const ukC=['#0f766e','#0d9488','#4f46e5','#7c3aed','#16a34a','#ea580c','#dc2626','#e8804c','#d946ef','#64748b'];
  const chartRef=useRef();
  const chartInst=useRef();
  const[expanded,setExpanded]=useState(false);

  useEffect(()=>{
    if(!expanded||!chartRef.current||chartInst.current)return;
    const tickC=isDark?'rgba(255,255,255,.4)':'rgba(0,0,0,.3)';
    const gridC=isDark?'rgba(255,255,255,.06)':'rgba(0,0,0,.04)';
    chartInst.current=new Chart(chartRef.current,{type:'bar',data:{
      labels:top.map(u=>(u.name||'').replace(/^ООО\s*"|^АО\s*"|"$/g,'').substring(0,12)),
      datasets:[{data:top.map(u=>u.houses),backgroundColor:ukC.slice(0,top.length),borderRadius:6}]},
      options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:{duration:1200},
        plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:tickC,font:{size:8}},grid:{color:gridC}},
        y:{ticks:{color:tickC,font:{size:8}},grid:{display:false}}}}});
  },[expanded]);

  return h(Card,{full:true,expandable:true,section:'housing',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--tealBg)'}},'📊'),
      h('div',null,
        h('div',{className:'card-title'},'Топ-10 УК по числу домов'),
        h('div',{className:'card-sub'},'Нажмите для графика'))),
    ...top.map((u,i)=>{
      const pct=Math.round(u.houses/maxH*100);
      const nm=(u.name||'').replace(/^ООО\s*"|^АО\s*"|"$/g,'').substring(0,16);
      return h('div',{className:'bar-row',key:i},
        h('span',{className:'bar-label'},nm),
        h('div',{className:'bar-track'},
          h('div',{className:'bar-fill',style:{'--w':pct+'%',width:pct+'%',background:ukC[i%10]}},u.houses)));
    }),
    h('div',{className:'expand-content'},
      h('div',{className:'chart-wrap'},h('canvas',{className:'chart',ref:chartRef}))),
    h(ExpandBtn,{expanded}),
    h(Tip,{color:'teal',icon:'🔍',text:ukTip(uk)}));
}

// --- GKH Card ---
function GKHCard({gkh}){
  const icons=['🚨','⚡','🏠','📞','🔵','💧','🔥','🏗️'];
  const visible=(gkh||[]).slice(0,3);
  const hidden=(gkh||[]).slice(3);
  const[expanded,setExpanded]=useState(false);
  const renderItem=(g,i)=>{
    const nm=g.name.replace(/^АО\s*"|^ООО\s*"|"\s*диспетчерская|Филиал.*диспетчерская/g,'').trim();
    const ph=g.phone.split(',')[0].trim();
    return h('div',{className:'gkh-item',key:i},
      h('div',{className:'gkh-name'},(icons[i]||'📞')+' '+nm),
      h('div',{className:'gkh-phone'},h('a',{href:'tel:'+ph.replace(/[^\d+]/g,''),onClick:e=>e.stopPropagation()},g.phone)));
  };
  return h(Card,{full:true,expandable:true,section:'housing',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--redBg)'}},'🆘'),
      h('div',null,
        h('div',{className:'card-title'},'Аварийные службы ЖКХ'),
        h('div',{className:'card-sub'},'Нажмите на номер для звонка'))),
    ...visible.map(renderItem),
    h('div',{className:'expand-content'},...hidden.map((g,i)=>renderItem(g,i+3))),
    h(ExpandBtn,{expanded,label:'Все службы'}),
    h(Tip,{color:'red',icon:'🆘',text:'Единый номер 112 работает круглосуточно'}));
}

// --- Routes Card ---
function RoutesCard({transport}){
  const routes=(transport?.routes_list||[]).slice(0,10);
  const visible=routes.slice(0,3);
  const hidden=routes.slice(3);
  const[expanded,setExpanded]=useState(false);
  const renderRoute=(r,i)=>h('div',{className:'route-item',key:i},
    h('span',{className:'route-num'},r.num),r.title,
    h('div',{className:'route-title'},r.start+' → '+r.end));
  return h(Card,{full:true,expandable:true,section:'transport',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--blueBg)'}},'🗺️'),
      h('div',null,
        h('div',{className:'card-title'},'Маршруты автобусов'),
        h('div',{className:'card-sub'},(transport?.municipal||0)+' муниципальных'))),
    ...visible.map(renderRoute),
    h('div',{className:'expand-content'},...hidden.map((r,i)=>renderRoute(r,i+3))),
    h(ExpandBtn,{expanded,label:'Все маршруты'}),
    h(Tip,{color:'blue',icon:'🚌',text:transTip(transport)}));
}

// --- DonutCard ---
function DonutCard({section,icon,iconBg,title,sub,data,colors,labels,legend,tip}){
  const chartRef=useRef();
  const chartInst=useRef();
  const[built,setBuilt]=useState(false);
  useEffect(()=>{
    if(!chartRef.current||built)return;
    chartInst.current=new Chart(chartRef.current,{type:'doughnut',data:{labels,
      datasets:[{data,backgroundColor:colors,borderWidth:0,hoverOffset:6}]},
      options:{responsive:true,maintainAspectRatio:true,cutout:'65%',
        plugins:{legend:{display:false}},animation:{animateRotate:true,duration:1500}}});
    setBuilt(true);
    return()=>{if(chartInst.current)chartInst.current.destroy()};
  },[]);
  return h(Card,{full:true,section},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:iconBg}},icon),
      h('div',null,h('div',{className:'card-title'},title),sub&&h('div',{className:'card-sub'},sub))),
    h('div',{className:'donut-wrap'},
      h('div',{className:'chart-wrap',style:{maxWidth:130,maxHeight:130}},
        h('canvas',{className:'chart',ref:chartRef})),
      legend),
    tip);
}

// --- WasteCard ---
function WasteCard({waste}){
  const wC=['#16a34a','#dc2626','#0d9488','#ea580c','#7c3aed','#64748b','#78716c'];
  const groups=waste?.groups||[];
  const chartRef=useRef();
  const chartInst=useRef();
  const[expanded,setExpanded]=useState(false);

  useEffect(()=>{
    if(!expanded||!chartRef.current||chartInst.current)return;
    const tickC=isDark?'rgba(255,255,255,.4)':'rgba(0,0,0,.3)';
    const gridC=isDark?'rgba(255,255,255,.06)':'rgba(0,0,0,.04)';
    chartInst.current=new Chart(chartRef.current,{type:'bar',data:{
      labels:groups.map(w=>w.name.length>16?w.name.substring(0,14)+'…':w.name),
      datasets:[{data:groups.map(w=>w.count),backgroundColor:groups.map((_,i)=>wC[i%7]),borderRadius:8}]},
      options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:{duration:1200},
        plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:tickC,font:{size:8}},grid:{color:gridC}},
        y:{ticks:{color:tickC,font:{size:8}},grid:{display:false}}}}});
  },[expanded]);

  return h(Card,{full:true,expandable:true,section:'eco',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--greenBg)'}},'♻️'),
      h('div',null,
        h('div',{className:'card-title'},'Раздельный сбор отходов'),
        h('div',{className:'card-sub'},(waste?.total||0)+' точек по городу'))),
    ...groups.map((w,i)=>h('div',{className:'waste-item',key:i},
      h('div',{className:'waste-dot',style:{background:wC[i%7]}}),w.name,
      h('span',{className:'waste-cnt',style:{color:wC[i%7]}},w.count))),
    h('div',{className:'expand-content'},
      h('div',{className:'chart-wrap'},h('canvas',{className:'chart',ref:chartRef}))),
    h(ExpandBtn,{expanded,label:'Диаграмма'}),
    h(Tip,{color:'green',icon:'🌱',text:wasteTip(groups)}));
}

// --- AccessibilityCard ---
function AccessibilityCard({accessibility,count}){
  const groups=(accessibility?.groups||[]).slice(0,8);
  const aC=['#db2777','#7c3aed','#0d9488','#ea580c','#2563eb','#16a34a','#dc2626','#4f46e5'];
  const chartRef=useRef();
  const chartInst=useRef();
  const[expanded,setExpanded]=useState(false);

  useEffect(()=>{
    if(!expanded||!chartRef.current||chartInst.current)return;
    const tickC=isDark?'rgba(255,255,255,.4)':'rgba(0,0,0,.3)';
    const gridC=isDark?'rgba(255,255,255,.06)':'rgba(0,0,0,.04)';
    chartInst.current=new Chart(chartRef.current,{type:'bar',data:{
      labels:groups.map(g=>g.name.length>18?g.name.substring(0,16)+'…':g.name),
      datasets:[{data:groups.map(g=>g.count),backgroundColor:groups.map((_,i)=>aC[i%8]),borderRadius:6}]},
      options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:{duration:1200},
        plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:tickC,font:{size:8}},grid:{color:gridC}},
        y:{ticks:{color:tickC,font:{size:7}},grid:{display:false}}}}});
  },[expanded]);

  return h(Card,{full:true,expandable:true,section:'city',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--pinkBg)'}},'♿'),
      h('div',null,
        h('div',{className:'card-title'},'Доступная среда'),
        h('div',{className:'card-sub'},(count||0)+' объектов для маломобильных'))),
    ...groups.slice(0,6).map((g,i)=>h('div',{className:'waste-item',key:i},
      h('div',{className:'waste-dot',style:{background:aC[i%8]}}),g.name,
      h('span',{className:'waste-cnt'},g.count))),
    h('div',{className:'expand-content'},
      h('div',{className:'chart-wrap'},h('canvas',{className:'chart',ref:chartRef}))),
    h(ExpandBtn,{expanded,label:'Диаграмма'}),
    h(Tip,{color:'pink',icon:'♿',text:'Город адаптирует инфраструктуру: пандусы, звуковые светофоры, знаки'}));
}


// --- RoadServiceCard ---
function RoadServiceCard({data,rsTypes,wC}){
  const[expanded,setExpanded]=useState(false);
  return h(Card,{full:true,expandable:true,section:'transport',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--indigoBg)'}},'🔧'),
      h('div',null,
        h('div',{className:'card-title'},'Дорожный сервис'),
        h('div',{className:'card-sub'},(data.road_service?.total||0)+' объектов'))),
    ...rsTypes.map((t,i)=>h('div',{className:'waste-item',key:i},
      h('div',{className:'waste-dot',style:{background:wC[i%7]}}),t.name,
      h('span',{className:'waste-cnt',style:{color:wC[i%7]}},t.count))),
    h('div',{className:'expand-content'},
      ...(data.road_works?.items||[]).slice(0,5).map((w,i)=>h('div',{className:'list-item',key:'rw'+i},'🚧 '+w.title)),
      h(Tip,{color:'orange',icon:'🚧',text:(data.road_works?.total||0)+' дорожных работ в городе'})),
    h(ExpandBtn,{expanded,label:'Дорожные работы'}));
}

// --- Simple stat cards ---
function StatCard({section,icon,iconBg,title,children}){
  return h(Card,{section},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:iconBg}},icon),
      h('div',null,h('div',{className:'card-title'},title))),
    children);
}

function BigNum({value,label,color}){
  return h('div',{className:'big',style:{color}},
    h(AnimatedNumber,{value}),h('small',null,label));
}

function StatRow({items}){
  return h('div',{className:'stat-row'},
    ...items.map((it,i)=>h('div',{className:'stat-item',key:i},
      h('div',{className:'num',style:{color:it.color}},h(AnimatedNumber,{value:it.value})),
      h('div',{className:'lbl'},it.label))));
}

// --- BudgetCard (БЮДЖЕТ — ключевой блок) ---
function BudgetCard({agreements,budget_bulletins,budget_info,property}){
  const agr=agreements||{};
  const byType=agr.by_type||[];
  const topContracts=(agr.top||[]).slice(0,8);
  const[expanded,setExpanded]=useState(false);
  const ukC=['#dc2626','#ea580c','#0f766e','#2563eb','#7c3aed','#16a34a','#0d9488','#d946ef','#4f46e5','#64748b'];

  // Format money
  const fmtMoney=(v)=>{
    if(!v||v===0)return'—';
    if(v>=1e9)return(v/1e9).toFixed(1)+' млрд ₽';
    if(v>=1e6)return(v/1e6).toFixed(1)+' млн ₽';
    if(v>=1e3)return(v/1e3).toFixed(0)+' тыс ₽';
    return v.toFixed(0)+' ₽';
  };

  return h(Card,{full:true,expandable:true,section:'budget',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--redBg)'}},'💰'),
      h('div',null,
        h('div',{className:'card-title'},'Муниципальные контракты'),
        h('div',{className:'card-sub'},(agr.total||0)+' договоров'))),
    // Summary stats
    h('div',{className:'stat-row'},
      h('div',{className:'stat-item'},
        h('div',{className:'num',style:{color:'var(--red)',fontSize:18}},fmtMoney(agr.total_summ)),
        h('div',{className:'lbl'},'Общая сумма')),
      h('div',{className:'stat-item'},
        h('div',{className:'num',style:{color:'var(--blue)',fontSize:18}},fmtMoney(agr.total_inv)),
        h('div',{className:'lbl'},'Инвестиции')),
      h('div',{className:'stat-item'},
        h('div',{className:'num',style:{color:'var(--green)',fontSize:18}},fmtMoney(agr.total_gos)),
        h('div',{className:'lbl'},'Гос. средства'))),
    // By type bars
    ...byType.slice(0,6).map((t,i)=>{
      const maxC=byType[0]?.count||1;
      const pct=Math.round(t.count/maxC*100);
      return h('div',{className:'bar-row',key:i},
        h('span',{className:'bar-label'},t.name),
        h('div',{className:'bar-track'},
          h('div',{className:'bar-fill',style:{'--w':pct+'%',width:pct+'%',background:ukC[i%10]}},t.count)));
    }),
    // Expand: top contracts
    h('div',{className:'expand-content'},
      h('div',{style:{fontSize:10,fontWeight:700,color:'var(--textMuted)',textTransform:'uppercase',letterSpacing:'.5px',margin:'8px 0 4px'}},'Крупнейшие контракты'),
      ...topContracts.map((c,i)=>h('div',{className:'list-item',key:i},
        h('b',null,(c.type||'')+': '+(c.title||c.desc||'').substring(0,60)),
        c.summ?h('span',{style:{color:'var(--red)',fontWeight:700,marginLeft:4}},fmtMoney(c.summ)):null,
        c.date?h('span',{style:{color:'var(--textMuted)',marginLeft:4,fontSize:9}},c.date):null)),
      h('div',{style:{marginTop:8,fontSize:10,color:'var(--textMuted)'}},
        'Бюджетных бюллетеней: '+(budget_bulletins?.total||0)+' · Бюджетная информация: '+(budget_info?.total||0))),
    h(ExpandBtn,{expanded,label:'Контракты'}),
    h(Tip,{color:'red',icon:'📊',text:agr.total_summ>0?'Общий объём контрактов: '+fmtMoney(agr.total_summ)+'. '+(agr.total_gos>0?'Гос. средства: '+fmtMoney(agr.total_gos)+' ('+Math.round(agr.total_gos/agr.total_summ*100)+'% от общей суммы). ':'')+'Энергосервис — основная статья расходов':'Данные о суммах контрактов обновляются'}));
}

// --- PropertyCard (ИМУЩЕСТВО) ---
function PropertyCard({property}){
  const p=property||{};
  const items=[
    {label:'Недвижимость',value:p.realestate||0,color:'var(--blue)',icon:'🏢'},
    {label:'Движимое',value:p.movable||0,color:'var(--teal)',icon:'🚗'},
    {label:'Земля',value:p.lands||0,color:'var(--green)',icon:'🌍'},
    {label:'Акции',value:p.stoks||0,color:'var(--purple)',icon:'📈'},
  ];
  return h(Card,{full:true,section:'budget'},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--blueBg)'}},'🏛️'),
      h('div',null,
        h('div',{className:'card-title'},'Муниципальное имущество'),
        h('div',{className:'card-sub'},(p.total||0).toLocaleString('ru')+' объектов в реестре'))),
    h('div',{className:'stat-row'},
      ...items.map((it,i)=>h('div',{className:'stat-item',key:i},
        h('div',{className:'num',style:{color:it.color,fontSize:16}},it.icon+' ',h(AnimatedNumber,{value:it.value})),
        h('div',{className:'lbl'},it.label)))),
    h('div',{style:{display:'flex',gap:8,marginTop:8,flexWrap:'wrap'}},
      h('div',{style:{flex:1,minWidth:100,padding:'6px 10px',borderRadius:10,background:'var(--orangeBg)',fontSize:10}},
        '🔑 Приватизация: ',h('b',{style:{color:'var(--orange)'}},(p.privatization||0))),
      h('div',{style:{flex:1,minWidth:100,padding:'6px 10px',borderRadius:10,background:'var(--tealBg)',fontSize:10}},
        '📋 Аренда: ',h('b',{style:{color:'var(--teal)'}},(p.rent||0)))),
    h(Tip,{color:'blue',icon:'🏛️',text:'В реестре '+(p.total||0).toLocaleString('ru')+' объектов. Недвижимость — '+(p.realestate||0).toLocaleString('ru')+' объектов'}),
    h(ConclusionTip,{text:'Муниципальное имущество: '+(p.realestate||0)+' объектов недвижимости, '+(p.lands||0)+' земельных участков. '+(p.privatization>0?'Приватизировано '+p.privatization+' объектов':''),icon:'🏛️',color:'blue'}));
}

// --- TrendBar: mini bar chart for year-by-year data ---
function TrendBar({data,color,label,valueKey='count'}){
  if(!data||!data.length)return null;
  const max=Math.max(...data.map(d=>d[valueKey]||0),1);
  return h('div',{style:{marginTop:6}},
    label?h('div',{style:{fontSize:9,color:'var(--textMuted)',marginBottom:4,fontWeight:600,textTransform:'uppercase',letterSpacing:'.3px'}},label):null,
    h('div',{style:{display:'flex',alignItems:'flex-end',gap:2,height:40}},
      ...data.map((d,i)=>{
        const v=d[valueKey]||0;
        const pct=Math.max(v/max*100,4);
        return h('div',{key:i,style:{flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:1}},
          h('div',{style:{fontSize:7,color:'var(--textMuted)',fontWeight:600}},v),
          h('div',{style:{width:'100%',height:pct+'%',minHeight:2,background:color||'var(--primary)',
            borderRadius:3,transition:'height .5s',opacity:.7+i/data.length*.3}}))
      })),
    h('div',{style:{display:'flex',justifyContent:'space-between',marginTop:2}},
      ...data.map((d,i)=>h('div',{key:i,style:{flex:1,textAlign:'center',fontSize:7,color:'var(--textMuted)'}},
        String(d.year).slice(-2)))));
}

// --- ConclusionTip: analytical conclusion ---
function ConclusionTip({text,icon,color}){
  return h(Tip,{color:color||'blue',icon:icon||'📈',text:text});
}

// --- UKEmailCard: all 42 UKs with anonymous email ---
function UKEmailCard({uk}){
  const allUks=(uk?.top||[]);
  const[expanded,setExpanded]=useState(false);
  const[sending,setSending]=useState(null);
  const[search,setSearch]=useState('');
  const CF='https://anthropic-proxy.uiredepositionherzo.workers.dev';

  const sendAnon=(ukName,ukEmail)=>{
    const desc=prompt('Опишите проблему для '+ukName+':');
    if(!desc||!desc.trim())return;
    const addr=prompt('Адрес (необязательно):','');
    setSending(ukEmail);
    const body='Уважаемая '+ukName+',\n\nЧерез систему Пульс города поступила анонимная жалоба:\n\n'+desc+(addr?'\n\nАдрес: '+addr:'')+'\n\nПросим рассмотреть.\nС уважением, Пульс города';
    fetch(CF+'/send-email',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({to_email:ukEmail,to_name:ukName,subject:'Анонимная жалоба — Пульс города',body:body,from_name:'Пульс города'})
    }).then(r=>r.json()).then(d=>{
      setSending(null);
      alert(d.ok?'Отправлено в '+ukName:'Ошибка отправки');
    }).catch(()=>{setSending(null);alert('Ошибка сети')});
  };

  const filtered=search?allUks.filter(u=>(u.name||'').toLowerCase().includes(search.toLowerCase())):allUks;
  const visible=filtered.slice(0,expanded?filtered.length:5);

  return h(Card,{full:true,expandable:true,section:'housing',expanded,onToggle:()=>setExpanded(v=>!v)},
    h('div',{className:'card-head'},
      h('div',{className:'card-icon',style:{background:'var(--indigoBg)'}},'✉️'),
      h('div',null,
        h('div',{className:'card-title'},'Написать в УК анонимно'),
        h('div',{className:'card-sub'},'Все '+(allUks.length||42)+' управляющих компаний'))),
    h('input',{type:'text',placeholder:'🔍 Поиск УК...',value:search,
      onChange:e=>setSearch(e.target.value),
      onClick:e=>e.stopPropagation(),
      style:{width:'100%',padding:'6px 10px',borderRadius:10,border:'1px solid var(--border)',
        background:'rgba(255,255,255,.04)',color:'var(--text)',fontSize:11,marginBottom:6,outline:'none'}}),
    ...visible.map((u,i)=>h('div',{key:i,style:{padding:'5px 0',borderBottom:'1px solid var(--border)',fontSize:11},
      onClick:e=>e.stopPropagation()},
      h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center'}},
        h('span',{style:{fontWeight:600,flex:1}},u.name),
        h('span',{style:{fontSize:9,color:'var(--textMuted)'}},u.houses+' домов')),
      u.email?h('div',{style:{display:'flex',gap:6,marginTop:3,alignItems:'center'}},
        h('span',{style:{fontSize:9,color:'var(--textMuted)'}},u.email),
        h('span',{onClick:()=>sendAnon(u.name,u.email),
          style:{fontSize:9,color:'var(--primary)',cursor:'pointer',textDecoration:'underline',fontWeight:600}},
          sending===u.email?'⏳...':'✉️ Написать')):
      h('div',{style:{fontSize:9,color:'var(--textMuted)'}},'Email не указан'))),
    h(ExpandBtn,{expanded,label:'Все УК ('+allUks.length+')',labelClose:'Свернуть'}),
    h(Tip,{color:'indigo',icon:'🔒',text:'Анонимная жалоба отправляется напрямую в УК. Ваши данные не передаются'}));
}

// ═══ Main App ═══
function App(){
  const[data,setData]=useState(null);
  const[weather,setWeather]=useState(null);
  const[tab,setTab]=useState('all');

  useEffect(()=>{
    Promise.all([loadData(),loadWeather()]).then(([d,w])=>{
      setData(d);setWeather(w);
      // Init WebGL background based on weather
      const wi=w?weatherInfo(w.weather_code,w.is_day):{type:'clear'};
      WeatherBG.init(wi.type);
      // Hide loader
      const ld=document.getElementById('loader');
      if(ld){ld.classList.add('hide');setTimeout(()=>ld.remove(),600)}
    });
  },[]);

  if(!data)return null;

  const fp=data.fuel?.prices||{};
  const ed=data.education||{};
  const cn=data.counts||{};
  const uk=data.uk||{};
  const tr=data.transport||{};
  const cc=data.culture_clubs||{};
  const updStr=fmtDate(data.updated_at);
  const totalRecords=Object.values(cn).reduce((a,b)=>a+b,0);

  const tabs=[
    {id:'all',label:'Все'},{id:'budget',label:'💰 Бюджет'},{id:'fuel',label:'⛽ Топливо'},{id:'housing',label:'🏢 ЖКХ'},
    {id:'edu',label:'🎓 Образование'},{id:'transport',label:'🚌 Транспорт'},
    {id:'sport',label:'⚽ Спорт'},{id:'city',label:'🏙️ Город'},
    {id:'eco',label:'♻️ Экология'},{id:'people',label:'👶 Люди'}
  ];

  const show=(section)=>tab==='all'||tab===section;

  // Names
  const boys=data.names?.boys||[];
  const girls=data.names?.girls||[];

  // Road service
  const rsTypes=data.road_service?.types||[];
  const wC=['#16a34a','#dc2626','#0d9488','#ea580c','#7c3aed','#64748b','#78716c'];

  // Clubs
  const clubItems=(cc.items||[]).slice(0,8);

  return h('div',{className:'app-wrap'},
    // Hero
    h('div',{className:'hero'},
      h('div',{className:'hero-pill'},h('span',{className:'dot'}),'Обновляется автоматически'),
      h('h1',null,'📊 ',h('em',null,'Нижневартовск'),h('br'),'в цифрах'),
      h('div',{className:'sub'},'Открытые данные · ХМАО-Югра'),
      h('div',{className:'upd'},'🕐 '+updStr),
      h('div',{className:'ds-count'},'📦 '+(data.datasets_total||72)+' датасетов · '+totalRecords.toLocaleString('ru')+' записей')),

    // Weather
    h(WeatherBanner,{weather}),

    // Tabs
    h('div',{className:'tabs'},
      ...tabs.map(t=>h('div',{key:t.id,className:'tab'+(tab===t.id?' active':''),
        'data-tab':t.id,onClick:()=>{setTab(t.id);haptic()}},t.label))),

    // Grid
    h('div',{className:'grid'},

      // ═══ BUDGET (первый — акцент) ═══
      show('budget')&&h(SectionTitle,{icon:'💰',text:'Бюджет и контракты',section:'budget',key:'sb'}),
      show('budget')&&h(BudgetCard,{agreements:data.agreements,budget_bulletins:data.budget_bulletins,
        budget_info:data.budget_info,property:data.property,key:'budgetc'}),
      show('budget')&&h(PropertyCard,{property:data.property,key:'propc'}),
      show('budget')&&h(StatCard,{section:'budget',icon:'📄',iconBg:'var(--orangeBg)',title:'Бюджетные документы',key:'bdocs'},
        h(StatRow,{items:[
          {value:data.budget_bulletins?.total||0,label:'Бюллетеней',color:'var(--orange)'},
          {value:data.budget_info?.total||0,label:'Информация',color:'var(--blue)'},
          {value:data.programs?.total||0,label:'Программ',color:'var(--purple)'}]}),
        h(Tip,{color:'orange',icon:'📋',text:'Бюджетные бюллетени и информация доступны на портале data.n-vartovsk.ru'})),
      show('budget')&&h(StatCard,{section:'budget',icon:'🏪',iconBg:'var(--tealBg)',title:'Бизнес и МСП',key:'biz'},
        h(StatRow,{items:[
          {value:data.business?.info||0,label:'Бизнес-инфо',color:'var(--teal)'},
          {value:data.business?.smp_messages||0,label:'Сообщений МСП',color:'var(--blue)'},
          {value:cn.msp||0,label:'Мер поддержки',color:'var(--green)'}]})),

      // ═══ FUEL ═══
      show('fuel')&&h(SectionTitle,{icon:'⛽',text:'Топливо и АЗС',section:'fuel',key:'sf'}),
      show('fuel')&&h(FuelCard,{fuel:data.fuel,key:'fuel'}),

      // ═══ HOUSING ═══
      show('housing')&&h(SectionTitle,{icon:'🏢',text:'ЖКХ и управление',section:'housing',key:'sh'}),
      show('housing')&&h(StatCard,{section:'housing',icon:'🏢',iconBg:'var(--tealBg)',title:'УК города',key:'uk1'},
        h(BigNum,{value:uk.total||0,label:'управляющих компаний',color:'var(--primary)'}),
        h('div',{style:{marginTop:6,fontSize:14,fontWeight:700,color:'var(--teal)'}},
          h(AnimatedNumber,{value:uk.houses||0}),' ',
          h('span',{style:{fontSize:10,color:'var(--textMuted)'}},'домов')),
        h(ConclusionTip,{text:(uk.total||0)+' УК обслуживают '+(uk.houses||0)+' домов. В среднем '+Math.round((uk.houses||0)/(uk.total||1))+' домов на компанию',icon:'🏢',color:'teal'})),
      show('housing')&&h(StatCard,{section:'housing',icon:'📞',iconBg:'var(--redBg)',title:'Аварийные',key:'gkh1'},
        h(BigNum,{value:(data.gkh||[]).length,label:'служб ЖКХ',color:'var(--red)'}),
        h('div',{style:{marginTop:4,fontSize:10,color:'var(--textMuted)'}},'112 — единый номер'),
        h(ConclusionTip,{text:'В городе '+(data.gkh||[]).length+' аварийных служб ЖКХ. При авариях звоните 112 или в диспетчерскую вашей УК',icon:'📞',color:'red'})),
      show('housing')&&h(UKCard,{uk,key:'ukc'}),
      show('housing')&&h(GKHCard,{gkh:data.gkh,key:'gkhc'}),
      show('housing')&&h(UKEmailCard,{uk:data.uk,key:'ukEmail'}),

      // ═══ EDUCATION ═══
      show('edu')&&h(SectionTitle,{icon:'🎓',text:'Образование',section:'edu',key:'se'}),
      show('edu')&&h(StatCard,{section:'edu',icon:'🎓',iconBg:'var(--blueBg)',title:'Образование',key:'edu1'},
        h(StatRow,{items:[
          {value:ed.kindergartens||0,label:'Детсадов',color:'var(--orange)'},
          {value:ed.schools||0,label:'Школ',color:'var(--blue)'},
          {value:ed.dod||0,label:'ДОД',color:'var(--purple)'}]}),
        h(ConclusionTip,{text:'В городе '+(ed.kindergartens||0)+' детсадов и '+(ed.schools||0)+' школ. Сеть образования покрывает все районы Нижневартовска',icon:'🎓',color:'blue'})),
      show('edu')&&h(StatCard,{section:'edu',icon:'🎭',iconBg:'var(--purpleBg)',title:'Культура',key:'cult1'},
        h(BigNum,{value:ed.culture||0,label:'учреждений',color:'var(--purple)'}),
        h('div',{style:{marginTop:4,fontSize:10,color:'var(--textMuted)'}},
          (cc.total||0)+' кружков · '+(cc.free||0)+' бесплатных'),
        h(ConclusionTip,{text:(ed.culture||0)+' учреждений культуры предлагают '+(cc.total||0)+' кружков, из них '+(cc.free||0)+' бесплатных ('+(Math.round((cc.free||0)/(cc.total||1)*100))+'%)',icon:'🎭',color:'purple'})),
      show('edu')&&h(DonutCard,{section:'edu',icon:'🎨',iconBg:'var(--purpleBg)',
        title:'Кружки и секции культуры',sub:(cc.total||0)+' кружков',
        data:[cc.free||0,cc.paid||0],colors:['rgba(22,163,74,.75)','rgba(234,88,12,.75)'],
        labels:['Бесплатные','Платные'],key:'clubs',
        legend:h('div',{className:'donut-legend'},
          h('span',{style:{color:'var(--green)'}},'● '),'Бесплатные: ',h('span',{style:{color:'var(--green)'}},cc.free||0),h('br'),
          h('span',{style:{color:'var(--orange)'}},'● '),'Платные: ',h('span',{style:{color:'var(--orange)'}},cc.paid||0))}),

      // ═══ TRANSPORT ═══
      show('transport')&&h(SectionTitle,{icon:'🚌',text:'Транспорт',section:'transport',key:'st'}),
      show('transport')&&h(StatCard,{section:'transport',icon:'🚌',iconBg:'var(--blueBg)',title:'Транспорт',key:'tr1'},
        h(StatRow,{items:[
          {value:tr.routes||0,label:'Маршрутов',color:'var(--blue)'},
          {value:tr.stops||0,label:'Остановок',color:'var(--teal)'}]}),
        h(ConclusionTip,{text:tr.municipal+' муниципальных и '+(tr.routes-tr.municipal)+' коммерческих маршрутов. '+(tr.municipal>tr.routes/2?'Муниципальный транспорт преобладает':'Коммерческий транспорт играет значительную роль'),icon:'🚌',color:'blue'})),
      show('transport')&&h(StatCard,{section:'transport',icon:'🛣️',iconBg:'var(--indigoBg)',title:'Дороги',key:'road1'},
        h(StatRow,{items:[
          {value:data.road_service?.total||0,label:'Объектов',color:'var(--indigo)'},
          {value:data.road_works?.total||0,label:'Работ',color:'var(--orange)'}]}),
        h(ConclusionTip,{text:(data.road_works?.total||0)+' дорожных работ на '+(data.road_service?.total||0)+' объектах. Город активно ремонтирует дорожную сеть',icon:'🛣️',color:'indigo'})),
      show('transport')&&h(RoutesCard,{transport:tr,key:'routes'}),
      show('transport')&&h(RoadServiceCard,{data,rsTypes,wC,key:'rs'}),

      // ═══ SPORT ═══
      show('sport')&&h(SectionTitle,{icon:'⚽',text:'Спорт',section:'sport',key:'ss'}),
      show('sport')&&h(StatCard,{section:'sport',icon:'🏅',iconBg:'var(--greenBg)',title:'Спорт',key:'sp1'},
        h(BigNum,{value:ed.sections||0,label:'спортивных секций',color:'var(--green)'}),
        h('div',{style:{marginTop:6,fontSize:11}},
          h('span',{style:{color:'var(--green)'}},'● '),(ed.sections_free||0)+' бесплатных',h('br'),
          h('span',{style:{color:'var(--orange)'}},'● '),(ed.sections_paid||0)+' платных')),
      show('sport')&&h(StatCard,{section:'sport',icon:'👨‍🏫',iconBg:'var(--tealBg)',title:'Тренеры',key:'tr2'},
        h(BigNum,{value:data.trainers?.total||0,label:'тренеров',color:'var(--teal)'}),
        h('div',{style:{marginTop:4,fontSize:10,color:'var(--textMuted)'}},
          (cn.sport_places||0)+' площадок · '+(ed.sport_orgs||0)+' организаций'),
        h(ConclusionTip,{text:(data.trainers?.total||0)+' тренеров работают в '+(ed.sport_orgs||0)+' организациях на '+(cn.sport_places||0)+' площадках. Спортивная инфраструктура развита',icon:'🏅',color:'teal'})),
      show('sport')&&h(DonutCard,{section:'sport',icon:'⚽',iconBg:'var(--greenBg)',
        title:'Секции: бесплатные vs платные',sub:(ed.sections||0)+' секций в '+(ed.sport_orgs||4)+' организациях',
        data:[ed.sections_free||0,ed.sections_paid||0],colors:['rgba(22,163,74,.75)','rgba(234,88,12,.75)'],
        labels:['Бесплатные','Платные'],key:'secDonut',
        legend:h('div',{className:'donut-legend'},
          h('span',{style:{color:'var(--green)'}},'● '),'Бесплатные: ',h('span',{style:{color:'var(--green)'}},ed.sections_free||0),h('br'),
          h('span',{style:{color:'var(--orange)'}},'● '),'Платные: ',h('span',{style:{color:'var(--orange)'}},ed.sections_paid||0)),
        tip:h(Tip,{color:'green',icon:'🎯',text:Math.round((ed.sections_free||0)/(ed.sections||1)*100)+'% секций бесплатные — город поддерживает детский спорт'})}),

      // ═══ CITY ═══
      show('city')&&h(SectionTitle,{icon:'🏙️',text:'Город',section:'city',key:'sc'}),
      show('city')&&h(StatCard,{section:'city',icon:'🏗️',iconBg:'var(--orangeBg)',title:'Строительство',key:'build'},
        h(StatRow,{items:[
          {value:cn.construction||0,label:'Объектов',color:'var(--orange)'},
          {value:cn.permits||0,label:'Разрешений',color:'var(--blue)'}]}),
        h(TrendBar,{data:data.building?.permits_trend||[],color:'var(--orange)',label:'Разрешения на строительство по годам'}),
        (data.building?.permits_trend||[]).length>=2?h(ConclusionTip,{text:'Пик строительной активности — '+(
          (data.building.permits_trend||[]).reduce((a,b)=>b.count>a.count?b:a,{count:0}).year||''
        )+' год ('+(data.building.permits_trend||[]).reduce((a,b)=>b.count>a.count?b:a,{count:0}).count+' разрешений)',icon:'🏗️',color:'orange'}):null),
      show('city')&&h(StatCard,{section:'city',icon:'♿',iconBg:'var(--pinkBg)',title:'Доступная среда',key:'acc1'},
        h(BigNum,{value:cn.accessibility||0,label:'объектов',color:'var(--pink)'}),
        h(ConclusionTip,{text:(cn.accessibility||0)+' объектов доступной среды: пандусы, звуковые светофоры, дорожные знаки. Город развивает инклюзивную инфраструктуру',icon:'♿',color:'pink'})),
      show('city')&&h(AccessibilityCard,{accessibility:data.accessibility,count:cn.accessibility,key:'accc'}),
      show('city')&&h(StatCard,{section:'city',icon:'📋',iconBg:'var(--blueBg)',title:'Справочник',key:'phone'},
        h(BigNum,{value:cn.phonebook||0,label:'телефонов',color:'var(--blue)'}),
        h('div',{style:{marginTop:4,fontSize:10,color:'var(--textMuted)'}},
          (cn.admin||0)+' подразделений · '+(cn.mfc||0)+' МФЦ'),
        h(ConclusionTip,{text:'Справочник содержит '+(cn.phonebook||0)+' контактов. '+(cn.admin||0)+' подразделений администрации и '+(cn.mfc||0)+' МФЦ доступны жителям',icon:'📋',color:'blue'})),
      show('city')&&h(StatCard,{section:'city',icon:'💼',iconBg:'var(--indigoBg)',title:'МСП',key:'msp'},
        h(BigNum,{value:cn.msp||0,label:'мер поддержки',color:'var(--indigo)'}),
        h(ConclusionTip,{text:(cn.msp||0)+' мер поддержки малого и среднего бизнеса. Город создаёт условия для развития предпринимательства',icon:'💼',color:'indigo'})),
      show('city')&&h(StatCard,{section:'city',icon:'📑',iconBg:'var(--tealBg)',title:'Документы и архив',key:'docs'},
        h(StatRow,{items:[
          {value:cn.documents||0,label:'Документов',color:'var(--teal)'},
          {value:cn.archive||0,label:'Архив',color:'var(--blue)'}]}),
        h(Tip,{color:'teal',icon:'📂',text:'Нормативные акты и архивные материалы города'})),
      show('city')&&h(StatCard,{section:'city',icon:'🗺️',iconBg:'var(--purpleBg)',title:'Территория',key:'terr'},
        h(StatRow,{items:[
          {value:data.territory_plans?.total||0,label:'Планов',color:'var(--purple)'},
          {value:data.advertising?.total||0,label:'Реклама',color:'var(--orange)'},
          {value:data.ad_places?.total||0,label:'Мест',color:'var(--blue)'}]}),
        h(ConclusionTip,{text:(data.territory_plans?.total||0)+' территориальных планов, '+(data.advertising?.total||0)+' рекламных конструкций. Город контролирует визуальную среду',icon:'🗺️',color:'purple'})),
      show('city')&&h(StatCard,{section:'city',icon:'📰',iconBg:'var(--blueBg)',title:'Новости и СМИ',key:'news'},
        h(StatRow,{items:[
          {value:data.news?.total||0,label:'Новостей',color:'var(--blue)'},
          {value:data.news?.rubrics||0,label:'Рубрик',color:'var(--teal)'}]}),
        h(TrendBar,{data:data.news?.trend||[],color:'var(--blue)',label:'Публикации по годам'}),
        (data.news?.trend||[]).length>=1?h(ConclusionTip,{text:'Информационная активность: '+(data.news?.total||0)+' публикаций. Город активно информирует жителей через портал',icon:'📰',color:'blue'}):null),
      show('city')&&h(StatCard,{section:'city',icon:'⚠️',iconBg:'var(--orangeBg)',title:'Охрана труда',key:'labor'},
        h(BigNum,{value:data.labor_safety?.total||0,label:'документов',color:'var(--orange)'}),
        h(ConclusionTip,{text:(data.labor_safety?.total||0)+' документов по охране труда. Город контролирует безопасность на рабочих местах',icon:'⚠️',color:'orange'})),
      show('city')&&h(StatCard,{section:'city',icon:'📬',iconBg:'var(--pinkBg)',title:'Обращения граждан',key:'appeals'},
        h(BigNum,{value:data.appeals?.total||0,label:'обзоров обращений',color:'var(--pink)'}),
        h(ConclusionTip,{text:(data.appeals?.total||0)+' обзоров обращений граждан. Администрация публикует статистику по обращениям жителей',icon:'📬',color:'pink'})),
      show('city')&&h(StatCard,{section:'city',icon:'👥',iconBg:'var(--greenBg)',title:'Демография',key:'demo'},
        data.demography&&data.demography[0]?h(StatRow,{items:[
          {value:safe_int(data.demography[0].birth),label:'Рождений',color:'var(--green)'},
          {value:safe_int(data.demography[0].marriages),label:'Браков',color:'var(--pink)'}]}):
        h('div',{style:{fontSize:10,color:'var(--textMuted)'}},'Данные обновляются'),
        data.demography&&data.demography[0]?h(ConclusionTip,{text:'За последний период: '+safe_int(data.demography[0].birth)+' рождений и '+safe_int(data.demography[0].marriages)+' браков. Город растёт и развивается',icon:'👥',color:'green'}):null),
      show('city')&&h(StatCard,{section:'city',icon:'🗣️',iconBg:'var(--indigoBg)',title:'Публичные слушания',key:'hear'},
        h(BigNum,{value:data.hearings?.total||0,label:'слушаний',color:'var(--indigo)'}),
        h(TrendBar,{data:data.hearings?.trend||[],color:'var(--indigo)',label:'Слушания по годам'}),
        data.hearings?.trend?.length>=2?h(ConclusionTip,{text:'Активность публичных слушаний '+(
          (data.hearings.trend.slice(-1)[0]?.count||0)>(data.hearings.trend.slice(-2)[0]?.count||0)?'растёт':'стабильна'
        )+'. В '+(data.hearings.trend.slice(-1)[0]?.year||'')+' году — '+(data.hearings.trend.slice(-1)[0]?.count||0)+' слушаний',icon:'🗣️',color:'indigo'}):null,
        data.hearings?.recent?.[0]?h(Tip,{color:'indigo',icon:'📅',text:data.hearings.recent[0].date+': '+data.hearings.recent[0].title}):null),
      show('city')&&h(StatCard,{section:'city',icon:'💵',iconBg:'var(--greenBg)',title:'Зарплаты муниципальных служащих',key:'sal'},
        h(BigNum,{value:data.salary?.latest_avg||0,label:'тыс. ₽ средняя ('+((data.salary?.trend||[]).slice(-1)[0]?.year||'')+')',color:'var(--green)'}),
        h(TrendBar,{data:data.salary?.trend||[],color:'var(--green)',label:'Динамика средней зарплаты по годам',valueKey:'avg'}),
        data.salary?.growth_pct?h(ConclusionTip,{text:'Рост зарплат за '+(data.salary?.trend?.length||0)+' лет: +'+data.salary.growth_pct+'%. Средняя зарплата выросла с '+(data.salary?.trend?.[0]?.avg||0)+' до '+(data.salary?.latest_avg||0)+' тыс. ₽',icon:'📈',color:'green'}):null),
      show('city')&&h(StatCard,{section:'city',icon:'📡',iconBg:'var(--tealBg)',title:'Связь',key:'comm'},
        h(BigNum,{value:data.communication?.total||0,label:'объектов связи',color:'var(--teal)'}),
        h(ConclusionTip,{text:(data.communication?.total||0)+' объектов связи обеспечивают телекоммуникационную инфраструктуру города',icon:'📡',color:'teal'})),

      // ═══ ECO ═══
      show('eco')&&h(SectionTitle,{icon:'♻️',text:'Экология',section:'eco',key:'seco'}),
      show('eco')&&h(WasteCard,{waste:data.waste,key:'waste'}),

      // ═══ PEOPLE ═══
      show('people')&&h(SectionTitle,{icon:'👶',text:'Люди',section:'people',key:'sp'}),
      show('people')&&h(Card,{full:true,section:'people',key:'names'},
        h('div',{className:'card-head'},
          h('div',{className:'card-icon',style:{background:'var(--accentBg)'}},'👶'),
          h('div',null,
            h('div',{className:'card-title'},'Популярные имена новорождённых'),
            h('div',{className:'card-sub'},'Статистика за все годы'))),
        h('div',{className:'name-grid'},
          h('div',{className:'name-col'},
            h('h3',null,'👦 Мальчики'),
            ...boys.map((b,i)=>h('div',{className:'name-item',key:i},
              h('span',null,h('span',{className:'rk'},i+1),b.n),
              h('span',{className:'c'},b.c)))),
          h('div',{className:'name-col'},
            h('h3',null,'👧 Девочки'),
            ...girls.map((g,i)=>h('div',{className:'name-item',key:i},
              h('span',null,h('span',{className:'rk'},i+1),g.n),
              h('span',{className:'c'},g.c))))),
        h(Tip,{color:'purple',icon:'👼',text:boys[0]?boys[0].n+' и '+(girls[0]?.n||'')+' — самые популярные имена':''}))
    ),

    // Footer
    h('div',{className:'footer'},
      'Источник: ',h('a',{href:'https://data.n-vartovsk.ru',target:'_blank'},'data.n-vartovsk.ru'),' · '+(data.datasets_total||72)+' датасетов',
      h('br'),'Пульс города · Нижневартовск © 2026')
  );
}

// ═══ Mount React App ═══
ReactDOM.createRoot(document.getElementById('root')).render(h(App));

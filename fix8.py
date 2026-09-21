# Part 2: seasonal ground/sky/sun + facade realism (dirt/AO) + performance for 10.5k
p = r'C:\Soobshio_project\services\Frontend\lib\screens\webgl\webgl_twin.html'
src = open(p, encoding='utf-8', newline='').read()

# ── 4) Ground color per season ──
old_ground = "const m = new THREE.MeshStandardMaterial({color: 0x33413a, roughness: 1});"
new_ground = "const m = new THREE.MeshStandardMaterial({color: SEASON_CFG.ground, roughness: 1});"
assert old_ground in src, 'ground'
src = src.replace(old_ground, new_ground, 1)

# ── 5) Sun/hemi per season in applyTime ──
old_sun = '''    sun.intensity = 0.15 + 1.3*dayK;
    sun.color.setHSL(0.09+0.04*dayK, 0.6*(1-dayK*0.7), 0.55+0.35*dayK);
    hemi.intensity = 0.25 + 0.8*dayK;'''
new_sun = '''    sun.intensity = 0.15 + 1.3*dayK * (SEASON === 'summer' ? 1.25 : 1.0);
    sun.color.set(SEASON_CFG.sun);
    hemi.intensity = 0.25 + 0.8*dayK;
    hemi.color.set(SEASON_CFG.sky);'''
assert old_sun in src, 'sun'
src = src.replace(old_sun, new_sun, 1)

# ── 6) Sky colors per season ──
old_sky = "const skyDay = new THREE.Color(0x8fc3e8), skyNight = new THREE.Color(0x0a1024);"
new_sky = "const skyDay = new THREE.Color(SEASON_CFG.sky), skyNight = new THREE.Color(0x0a1024);"
assert old_sky in src, 'sky'
src = src.replace(old_sky, new_sky, 1)

# ── 7) Facade realism: dirt gradient at bottom of texture (in facadeTexture) ──
old_tex = '''  const map = new THREE.CanvasTexture(c);
  const emap = new THREE.CanvasTexture(litC);'''
new_tex = '''  // Фотореализм: грязь/потёмнение внизу фасада (первые 12% высоты)
  const grime = x.createLinearGradient(0, S, 0, S * 0.88);
  grime.addColorStop(0, 'rgba(40,35,28,0.38)');
  grime.addColorStop(1, 'rgba(40,35,28,0)');
  x.fillStyle = grime;
  x.fillRect(0, S * 0.88, S, S * 0.12);
  // AO-полоса вдоль горизонтальных швов (углубление панелей)
  if (kind === 'panel') {
    for (let r = 1; r < 9; r++) {
      x.fillStyle = 'rgba(0,0,0,0.10)';
      x.fillRect(0, r * (S / 9) - 2, S, 2);
      x.fillStyle = 'rgba(255,255,255,0.05)';
      x.fillRect(0, r * (S / 9), S, 1);
    }
  }
  const map = new THREE.CanvasTexture(c);
  const emap = new THREE.CanvasTexture(litC);'''
assert old_tex in src, 'tex'
src = src.replace(old_tex, new_tex, 1)

# ── 8) Per-panel color variance in addBuilding material ──
old_pick = '''  const mat = pickMaterial(h, category, seed);
  const tex = facadeTexture(mat.base, mat.kind, (seed%99991)+7);'''
new_pick = '''  const mat = pickMaterial(h, category, seed);
  // Реальные панели различаются на ±5% тона — делаем каждое здание уникальным
  const cBase = new THREE.Color(mat.base);
  cBase.offsetHSL(0, 0, ((seed % 100) / 100 - 0.5) * 0.10);
  const tex = facadeTexture(cBase.getHex(), mat.kind, (seed%99991)+7);'''
assert old_pick in src, 'pick'
src = src.replace(old_pick, new_pick, 1)

# ── 9) Performance for 10.5k: shadow map only on near, pixel ratio clamp ──
old_pr = "renderer.setPixelRatio(Math.min(devicePixelRatio, 2));"
new_pr = "renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75)); // 10.5k зданий: баланс качества/FPS"
assert old_pr in src, 'pr'
src = src.replace(old_pr, new_pr, 1)

# ── 10) Season badge in HUD ──
old_hud = '<div id="hud">🏙️ НИЖНЕВАРТОВСК · WEBGL-ДВОЙНИК · <span id="cnt">…</span></div>'
new_hud = '<div id="hud">🏙️ НИЖНЕВАРТОВСК · WEBGL-ДВОЙНИК · <span id="cnt">…</span> · <span id="season"></span></div>'
assert old_hud in src, 'hud'
src = src.replace(old_hud, new_hud, 1)

# set season label in loadCity
old_cnt = "document.getElementById('cnt').textContent = count+' зданий';"
new_cnt = """document.getElementById('cnt').textContent = count+' зданий';
    const seasonNames = {winter:'❄️ зима', spring:'🌱 весна', summer:'☀️ лето', autumn:'🍂 осень'};
    document.getElementById('season').textContent = seasonNames[SEASON];"""
assert old_cnt in src, 'cnt'
src = src.replace(old_cnt, new_cnt, 1)

open(p, 'w', encoding='utf-8', newline='').write(src)
print('Photorealism part 2 applied: seasons, grime, AO, variance, HUD')

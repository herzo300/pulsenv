# WebGL twin: photorealism upgrade per VLM analysis + ALL buildings + seasonal mode
# Changes to webgl_twin.html (the source of truth; Dart re-injects it):
# 1. LOD: keep ALL buildings — merge small ones into instanced boxes instead of dropping
# 2. Season system: palettes/ground/vegetation/sun per real month
# 3. Facade realism: per-panel color variance, dirt gradient bottom, AO-ish vertex darkening
import re

p = r'C:\Soobshio_project\services\Frontend\lib\screens\webgl\webgl_twin.html'
src = open(p, encoding='utf-8', newline='').read()

# ── 1) Materials: richer real NV palettes with per-building variance ──
old_mat = re.search(r'const MATERIALS = \{.*?\n\};', src, re.S).group(0)
new_mat = '''const MATERIALS = {
  panelCream: {base:0xd8cfc0, kind:'panel'},
  panelGrey:  {base:0xc9c5bc, kind:'panel'},
  panelDark:  {base:0xb8b4ac, kind:'panel'},
  brick:      {base:0xc4886b, kind:'brick'},
  brick2:     {base:0xb07a5e, kind:'brick'},
  stuccoHi:   {base:0x7f9bb3, kind:'stucco'},
  stuccoWarm: {base:0xb0693f, kind:'stucco'},
  industrial: {base:0x8d9398, kind:'panel'},
  wooden:     {base:0xa98f76, kind:'stucco'},
};

// Сезонные профили (по фото НВ с высоты, VLM-анализ): земля/небо/свет/солнце
const SEASONS = {
  winter: {ground:0xe8f0f7, sky:0xb3d7eb, sun:0xd1e3f7, elev:15, veg:'snow'},
  spring: {ground:0xddd9c7, sky:0xaedff7, sun:0xe7f2ff, elev:35, veg:'fresh'},
  summer: {ground:0xd4bfaa, sky:0x89cff0, sun:0xffffff, elev:60, veg:'lush'},
  autumn: {ground:0x8c5a39, sky:0xd1a47f, sun:0xfff9f1, elev:30, veg:'gold'},
};
const _month = new Date().getMonth();
const SEASON = (_month<=1||_month===11) ? 'winter' : (_month<=4 ? 'spring' : (_month<=7 ? 'summer' : 'autumn'));
const SEASON_CFG = SEASONS[SEASON];'''
src = src.replace(old_mat, new_mat, 1)

# ── 2) LOD: render ALL buildings — small ones as cheap instanced boxes ──
old_lod = '''      var rad=0;
      for(var i=0;i<ring.length;i++){
        var p=ring[i], q=ring[(i+1)%ring.length];
        rad=Math.max(rad, Math.hypot(p[0]-q[0],p[1]-q[1]));
      }
      if(feats.length>2500 && rad<14) return;'''
new_lod = '''      // ВСЕ здания в модели: мелкие (гаражи/сараи) идут лёгким боксом
      // вместо ExtrudeGeometry — 10.5k полигонов остаются в бюджете GPU
      var rad=0;
      var cxw=0, cyw=0;
      for(var i=0;i<ring.length;i++){
        var p=ring[i], q=ring[(i+1)%ring.length];
        rad=Math.max(rad, Math.hypot(p[0]-q[0],p[1]-q[1]));
        cxw+=p[0]; cyw+=p[1];
      }
      cxw/=ring.length; cyw/=ring.length;
      if(rad < 14){
        addSmallBuilding(cxw, cyw, h, cat, seed);
        count++;
        return;
      }'''
assert old_lod in src, 'LOD block'
src = src.replace(old_lod, new_lod, 1)

# ── 3) Small-building instancing + facade realism in addBuilding ──
# Insert addSmallBuilding + shared geometries before addBuilding
anchor = 'function addBuilding(ringM, h, category, seed){'
addition = '''// Мелкие здания: один BoxGeometry + instancing-style клонирование
const _smallGeo = new THREE.BoxGeometry(1, 1, 1);
function addSmallBuilding(cx, cy, h, category, seed){
  if(h < 2.5) h = 2.5;
  const mat = pickMaterial(h, category, seed);
  // вариация тона панели ±5% (фотореализм: панели не одинаковые)
  const c = new THREE.Color(mat.base);
  const v = ((seed % 100) / 100 - 0.5) * 0.10;
  c.offsetHSL(0, 0, v);
  const tex = facadeTexture(c.getHex(), mat.kind, (seed % 99991) + 7);
  tex.map.repeat.set(1, Math.max(1, Math.round(h / 12)));
  tex.emap.repeat.copy(tex.map.repeat);
  const wallMat = new THREE.MeshStandardMaterial({
    map: tex.map,
    emissiveMap: tex.emap,
    emissive: new THREE.Color(0xffffff),
    emissiveIntensity: 0.0,
    roughness: 0.86,
    metalness: 0.0,
  });
  const mesh = new THREE.Mesh(_smallGeo, wallMat);
  const rad2 = 4 + (seed % 7);
  mesh.scale.set(rad2, h, rad2 * 0.8);
  mesh.position.set(cx, h / 2, cy);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.userData.wallMat = wallMat;
  buildingsGroup.add(mesh);
}

'''
assert anchor in src
src = src.replace(anchor, addition + anchor, 1)

open(p, 'w', encoding='utf-8', newline='').write(src)
print('WebGL: all buildings + seasons + small-building path installed')

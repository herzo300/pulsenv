import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/pulse_colors.dart';

/// Interactive 3D panorama of Nizhnevartovsk District 16 (experimental)
/// Rendered via Three.js WebGL in a WebView.
class CityPanoramaScreen extends StatefulWidget {
  const CityPanoramaScreen({super.key});

  @override
  State<CityPanoramaScreen> createState() => _CityPanoramaScreenState();
}

class _CityPanoramaScreenState extends State<CityPanoramaScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF020817))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <title>16 микрорайон — Нижневартовск 3D</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      background: #030712; 
      overflow: hidden; 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      touch-action: none;
    }
    canvas { display: block; width: 100vw; height: 100vh; }
    #info {
      position: fixed;
      top: 16px; left: 50%;
      transform: translateX(-50%);
      background: rgba(15, 23, 42, 0.85);
      border: 1px solid rgba(0, 229, 255, 0.4);
      color: #00E5FF;
      padding: 8px 18px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.5px;
      backdrop-filter: blur(12px);
      box-shadow: 0 4px 20px rgba(0, 229, 255, 0.2);
      pointer-events: none;
      z-index: 10;
    }
    #hud {
      position: fixed;
      bottom: 24px; left: 50%;
      transform: translateX(-50%);
      background: rgba(15, 23, 42, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: rgba(255, 255, 255, 0.8);
      padding: 6px 14px;
      border-radius: 12px;
      font-size: 11px;
      backdrop-filter: blur(8px);
      pointer-events: none;
      z-index: 10;
    }
  </style>
</head>
<body>
  <div id="info">🏙️ 16-й микрорайон • 3D ИИ-Дизайн</div>
  <div id="hud">Вращайте пальцем для 3D обзора сцены</div>
  <canvas id="c"></canvas>

  <script>
              1.5 + r * 2.5,
              z + d / 2 + 0.01,
            );
            scene.add(win);
          }
        }
      }
    }

    // ══════════════════════════════════════════
    // 16-й МИКРОРАЙОН: жилые дома
    // ══════════════════════════════════════════
    
    // Длинные 9-этажки (по 3 штуки в ряд)
    const nineFloorH = 9 * 2.8;
    createBuilding(-22, -8,  18, 5.5, nineFloorH, 0x1B2D45, 0x2563EB);
    createBuilding(0,  -8,  18, 5.5, nineFloorH, 0x1B3040, 0x1D4ED8);
    createBuilding(22, -8,  18, 5.5, nineFloorH, 0x1A2C42, 0x3B82F6);

    // 5-этажки
    const fiveFloorH = 5 * 2.8;
    createBuilding(-18, 12, 12, 5,   fiveFloorH, 0x1E2D3A, 0x0EA5E9);
    createBuilding(0,   12, 12, 5,   fiveFloorH, 0x1E3040, 0x0EA5E9);
    createBuilding(18,  12, 12, 5,   fiveFloorH, 0x1C2E3E, 0x38BDF8);

    // 12-этажки (башни по краям)
    const twelveFloorH = 12 * 2.8;
    createBuilding(-34, -2, 8, 8, twelveFloorH, 0x162033, 0x6366F1);
    createBuilding(34,  -2, 8, 8, twelveFloorH, 0x162033, 0x6366F1);

    // 16-этажка в центре
    const sixteenFloorH = 16 * 3.0;
    createBuilding(0, 26, 10, 10, sixteenFloorH, 0x0F1929, 0x00E5FF);

    // ══════════════════════════════════════════
    // ИНФРАСТРУКТУРА
    // ══════════════════════════════════════════

    // Парковки
    function createParking(x, z, w, d) {
      const geo = new THREE.PlaneGeometry(w, d);
      const mat = new THREE.MeshStandardMaterial({ color: 0x0B1525, roughness: 1 });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(x, 0.02, z);
      scene.add(mesh);
      // Разметка
      for (let i = -Math.floor(w/3)+1; i <= Math.floor(w/3)-1; i++) {
        const lGeo = new THREE.PlaneGeometry(0.1, d * 0.8);
        const lMat = new THREE.MeshBasicMaterial({ color: 0xFFFFFF, transparent: true, opacity: 0.2 });
        const line = new THREE.Mesh(lGeo, lMat);
        line.rotation.x = -Math.PI / 2;
        line.position.set(x + i * 2.8, 0.03, z);
        scene.add(line);
      }
    }
    createParking(-12, 3, 16, 8);
    createParking(12, 3, 16, 8);

    // Детская площадка
    function createPlayground(x, z) {
      const pgGeo = new THREE.PlaneGeometry(8, 6);
      const pgMat = new THREE.MeshStandardMaterial({ color: 0x1A3A1A, roughness: 0.9 });
      const pg = new THREE.Mesh(pgGeo, pgMat);
      pg.rotation.x = -Math.PI / 2;
      pg.position.set(x, 0.02, z);
      scene.add(pg);
      
      // Горка
      const slideGeo = new THREE.ConeGeometry(0.8, 2.5, 6);
      const slideMat = new THREE.MeshStandardMaterial({ color: 0xF59E0B, emissive: 0x7C3009, emissiveIntensity: 0.3 });
      const slide = new THREE.Mesh(slideGeo, slideMat);
      slide.position.set(x - 2, 1.25, z);
      scene.add(slide);
      
      // Качели (столбы)
      [x+1, x+2.5].forEach(sx => {
        const pGeo = new THREE.CylinderGeometry(0.08, 0.08, 2.2, 6);
        const pMat = new THREE.MeshStandardMaterial({ color: 0x64748B });
        const p = new THREE.Mesh(pGeo, pMat);
        p.position.set(sx, 1.1, z);
        scene.add(p);
      });
    }
    createPlayground(0, 4);

    // Деревья
    function createTree(x, z, h) {
      const trunkGeo = new THREE.CylinderGeometry(0.18, 0.22, h * 0.45, 6);
      const trunkMat = new THREE.MeshStandardMaterial({ color: 0x3D2008 });
      const trunk = new THREE.Mesh(trunkGeo, trunkMat);
      trunk.position.set(x, h * 0.225, z);
      scene.add(trunk);
      
      const foliageGeo = new THREE.SphereGeometry(h * 0.38, 6, 5);
      const foliageMat = new THREE.MeshStandardMaterial({
        color: 0x15623A,
        roughness: 0.95,
        emissive: 0x0B3D20,
        emissiveIntensity: 0.15,
      });
      const foliage = new THREE.Mesh(foliageGeo, foliageMat);
      foliage.position.set(x, h * 0.45 + h * 0.38, z);
      scene.add(foliage);
    }
    
    const treePositions = [
      [-8, -2], [-6, -3], [6, -2], [8, -3],
      [-10, 8], [-5, 9], [5, 9], [10, 8],
      [-15, 15], [15, 15], [-20, -14], [20, -14],
      [-3, 20], [3, 20], [-25, 5], [25, 5],
    ];
    treePositions.forEach(([tx, tz]) => createTree(tx, tz, 3.5 + Math.random() * 2));

    // Дороги
    function createRoad(x, z, w, d) {
      const geo = new THREE.PlaneGeometry(w, d);
      const mat = new THREE.MeshStandardMaterial({ color: 0x111827, roughness: 0.95 });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(x, 0.015, z);
      scene.add(mesh);
    }
    // Главная дорога
    createRoad(0, -1.5, 70, 7);
    // Поперечная
    createRoad(-30, 12, 7, 40);
    createRoad(30, 12, 7, 40);

    // Фонари
    function createLampPost(x, z) {
      const postGeo = new THREE.CylinderGeometry(0.06, 0.08, 5, 6);
      const postMat = new THREE.MeshStandardMaterial({ color: 0x374151 });
      const post = new THREE.Mesh(postGeo, postMat);
      post.position.set(x, 2.5, z);
      scene.add(post);
      
      const lampGeo = new THREE.SphereGeometry(0.2, 8, 6);
      const lampMat = new THREE.MeshStandardMaterial({
        color: 0xFFF9C4,
        emissive: 0xFFF176,
        emissiveIntensity: 1.5,
      });
      const lamp = new THREE.Mesh(lampGeo, lampMat);
      lamp.position.set(x, 5.1, z);
      scene.add(lamp);
      
      const light = new THREE.PointLight(0xFFF9C4, 0.8, 14);
      light.position.set(x, 5, z);
      light.castShadow = true;
      scene.add(light);
    }
    
    for (let i = -3; i <= 3; i++) {
      createLampPost(i * 9, -4.5);
      createLampPost(i * 9, 2);
    }
    createLampPost(-31.5, 0);
    createLampPost(-31.5, 10);
    createLampPost(31.5, 0);
    createLampPost(31.5, 10);

    // ══════════════════════════════════════════
    // ОСВЕЩЕНИЕ СЦЕНЫ
    // ══════════════════════════════════════════

    // Ambient moon light
    const ambient = new THREE.AmbientLight(0x1A2840, 0.8);
    scene.add(ambient);

    // Moon directional
    const moon = new THREE.DirectionalLight(0xA0C4FF, 0.6);
    moon.position.set(-30, 50, 20);
    moon.castShadow = true;
    moon.shadow.mapSize.width = 2048;
    moon.shadow.mapSize.height = 2048;
    moon.shadow.camera.near = 1;
    moon.shadow.camera.far = 200;
    moon.shadow.camera.left = -80;
    moon.shadow.camera.right = 80;
    moon.shadow.camera.top = 80;
    moon.shadow.camera.bottom = -80;
    scene.add(moon);

    // Sky gradient (hemisphere)
    const hemi = new THREE.HemisphereLight(0x0A1628, 0x050A14, 0.4);
    scene.add(hemi);

    // ══════════════════════════════════════════
    // ЗВЁЗДЫ
    // ══════════════════════════════════════════
    const starGeo = new THREE.BufferGeometry();
    const starCount = 1200;
    const starPositions = new Float32Array(starCount * 3);
    for (let i = 0; i < starCount * 3; i++) {
      starPositions[i] = (Math.random() - 0.5) * 400;
    }
    starGeo.setAttribute('position', new THREE.BufferAttribute(starPositions, 3));
    const starMat = new THREE.PointsMaterial({ color: 0xE2E8F0, size: 0.3, transparent: true, opacity: 0.7 });
    const stars = new THREE.Points(starGeo, starMat);
    scene.add(stars);

    // ══════════════════════════════════════════
    // ANIMATE
    // ══════════════════════════════════════════
    let time = 0;
    function animate() {
      requestAnimationFrame(animate);
      time += 0.008;
      
      // Slow star twinkle
      starMat.opacity = 0.55 + Math.sin(time * 1.5) * 0.15;
      
      // Auto-rotate is handled automatically by controls.autoRotate = true;
      
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020817),
        foregroundColor: PulseColors.primary,
        title: const Text(
          '16-й микрорайон • 3D',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: const Text(
                'ЭКСПЕРИМЕНТ',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              backgroundColor: PulseColors.primary.withOpacity(0.2),
              side: BorderSide(color: PulseColors.primary.withOpacity(0.4)),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF020817),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: PulseColors.primary,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Загрузка 3D-панорамы...',
                      style: TextStyle(
                        color: PulseColors.primary.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CesiumMapScreen extends StatefulWidget {
  const CesiumMapScreen({
    super.key,
    required this.complaints,
    required this.initialCenter,
    required this.initialZoom,
  });

  final List<dynamic> complaints;
  final LatLng initialCenter;
  final double initialZoom;

  @override
  State<CesiumMapScreen> createState() => _CesiumMapScreenState();
}

class _CesiumMapScreenState extends State<CesiumMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            _sendDataToWebView();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                'WebView error: ${error.errorCode} ${error.description}');
          },
        ),
      );

    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final htmlStr = await rootBundle.loadString('assets/cesium_view.html');
      await _controller.loadHtmlString(
        htmlStr,
        baseUrl: 'https://geoportal.n-vartovsk.ru',
      );
    } catch (e) {
      debugPrint('Error loading cesium HTML: $e');
    }
  }

  double _topAltitudeFromZoom(double zoom) {
    final raw = 3600 * math.pow(2, 14 - zoom).toDouble();
    return raw.clamp(900, 56000).toDouble();
  }

  double _diveAltitudeFromZoom(double zoom) {
    final raw = 1450 * math.pow(2, 14 - zoom).toDouble();
    return raw.clamp(320, 18000).toDouble();
  }

  Future<void> _sendLaunchContext() async {
    final payload = {
      'lat': widget.initialCenter.latitude,
      'lng': widget.initialCenter.longitude,
      'zoom': widget.initialZoom,
      'topAltitude': _topAltitudeFromZoom(widget.initialZoom),
      'diveAltitude': _diveAltitudeFromZoom(widget.initialZoom),
      'heading': 0.18,
      'finalHeading': 0.24,
      'finalPitch': -42,
    };
    final encoded = base64Encode(utf8.encode(jsonEncode(payload)));
    await _controller.runJavaScript('setLaunchContext("$encoded")');
  }

  Future<void> _sendDataToWebView() async {
    await _sendLaunchContext();

    try {
      final camJsonStr = await rootBundle.loadString('assets/cameras_nv.json');
      final base64Cam = base64Encode(utf8.encode(camJsonStr));
      await _controller.runJavaScript('addCameras("$base64Cam")');
    } catch (e) {
      debugPrint('Error loading cameras for Cesium: $e');
      await _controller.runJavaScript('addCameras([])');
    }

    final combined = <Map<String, dynamic>>[];
    if (_activeFilter == 'all' || _activeFilter == 'complaints') {
      combined.addAll(
        widget.complaints.map(
          (c) => {
            'type': 'complaint',
            'lat': c['latitude'] ?? c['lat'],
            'lng': c['longitude'] ?? c['lng'],
            'title': c['title'] ?? 'Проблема',
            'color': _getHexColor(c['category'] ?? 'Прочее'),
          },
        ),
      );
    }

    final jsonStr = jsonEncode(combined);
    final base64Data = base64Encode(utf8.encode(jsonStr));
    await _controller.runJavaScript('updateMarkers("$base64Data")');
  }

  String _getHexColor(String category) {
    return switch (category) {
      'Дороги' => '#FF3D00',
      'ЖКХ' => '#00E5FF',
      'Безопасность' => '#FFC107',
      'Экология' => '#10B981',
      _ => '#00E5FF',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '3D ПУЛЬС ГОРОДА',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _sendDataToWebView,
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('all', 'ВСЕ', Icons.layers_outlined),
                  const SizedBox(width: 8),
                  _filterChip(
                    'complaints',
                    'ЖАЛОБЫ',
                    Icons.report_problem_outlined,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const _CesiumBridgeLoader(),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    final active = _activeFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = id);
        _sendDataToWebView();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF)
              : const Color(0xFF1E1E3F).withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white : Colors.white10),
          boxShadow: active
              ? const [
                  BoxShadow(color: Color(0x4400E5FF), blurRadius: 10),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CesiumBridgeLoader extends StatefulWidget {
  const _CesiumBridgeLoader();

  @override
  State<_CesiumBridgeLoader> createState() => _CesiumBridgeLoaderState();
}

class _CesiumBridgeLoaderState extends State<_CesiumBridgeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF020617),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CesiumBridgePainter(_controller.value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1900E5FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x6600E5FF)),
                    ),
                    child: const Text(
                      'CITY PULSE 3D',
                      style: TextStyle(
                        color: Color(0xFF7DEBFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Стыковка 2D и 3D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 290,
                    child: Text(
                      'Фиксируем текущий центр карты и разворачиваем объемный каркас города в той же точке.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9FB0C7),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CesiumBridgePainter extends CustomPainter {
  const _CesiumBridgePainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x3300E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final accentPaint = Paint()
      ..color = const Color(0x9900E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final revealPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x0000E5FF),
          Color(0x2D00E5FF),
          Color(0x0000E5FF),
        ],
        stops: [
          (phase - 0.18).clamp(0.0, 1.0),
          phase.clamp(0.0, 1.0),
          (phase + 0.18).clamp(0.0, 1.0),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, revealPaint);

    final horizon = size.height * 0.58;
    final centerX = size.width / 2;

    for (var i = 0; i < 12; i++) {
      final t = i / 11;
      final y = horizon + (size.height - horizon) * t;
      final inset = 24 + (size.width * 0.28) * t;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        gridPaint,
      );
    }

    for (var i = -6; i <= 6; i++) {
      final dx = i * 34.0;
      canvas.drawLine(
        Offset(centerX + dx, horizon - 24),
        Offset(centerX + dx * 2.3, size.height),
        gridPaint,
      );
    }

    _drawWireBlock(
      canvas,
      baseCenter: Offset(centerX - 92, horizon + 22),
      size: const Size(64, 70),
      depth: 18,
      paint: accentPaint,
    );
    _drawWireBlock(
      canvas,
      baseCenter: Offset(centerX - 18, horizon - 6),
      size: const Size(72, 110),
      depth: 20,
      paint: accentPaint,
    );
    _drawWireBlock(
      canvas,
      baseCenter: Offset(centerX + 78, horizon + 16),
      size: const Size(70, 82),
      depth: 18,
      paint: accentPaint,
    );
    _drawWireBlock(
      canvas,
      baseCenter: Offset(centerX + 8, horizon + 52),
      size: const Size(116, 52),
      depth: 24,
      paint: accentPaint,
    );

    final scanY = horizon - 30 + (size.height * 0.52) * phase;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0x0000E5FF),
          Color(0xAA00E5FF),
          Color(0x0000E5FF),
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 2, size.width, 4), scanPaint);
  }

  void _drawWireBlock(
    Canvas canvas, {
    required Offset baseCenter,
    required Size size,
    required double depth,
    required Paint paint,
  }) {
    final front = Rect.fromCenter(
      center: baseCenter,
      width: size.width,
      height: size.height,
    );
    final topShift = Offset(depth, -depth * 0.65);

    final frontPath = ui.Path()..addRect(front);
    final topPath = ui.Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.right, front.top)
      ..lineTo(front.right + topShift.dx, front.top + topShift.dy)
      ..lineTo(front.left + topShift.dx, front.top + topShift.dy)
      ..close();
    final sidePath = ui.Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right, front.bottom)
      ..lineTo(front.right + topShift.dx, front.bottom + topShift.dy)
      ..lineTo(front.right + topShift.dx, front.top + topShift.dy)
      ..close();

    canvas.drawPath(frontPath, paint);
    canvas.drawPath(topPath, paint);
    canvas.drawPath(sidePath, paint);
  }

  @override
  bool shouldRepaint(covariant _CesiumBridgePainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

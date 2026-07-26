import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';

import '../theme/pulse_colors.dart';
import '../theme/pulse_categories.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../map/map_config.dart';
import '../widgets/category_icon_3d.dart';

/// AR-style Camera Overlay — shows city event markers on camera feed.
/// Uses device sensors (gyroscope/compass) + GPS to position markers.
/// Works on all Android devices without ARCore dependency.
class ArMarkersScreen extends StatefulWidget {
  /// List of signals/events to show as AR markers
  final List<Map<String, dynamic>> signals;

  const ArMarkersScreen({super.key, required this.signals});

  @override
  State<ArMarkersScreen> createState() => _ArMarkersScreenState();
}

class _ArMarkersScreenState extends State<ArMarkersScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  String? _cameraError;

  // Device orientation
  double _azimuth = 0.0; // compass heading (degrees, 0=North)
  double _pitch = 0.0; // tilt (degrees, 0=horizontal)

  // GPS
  Position? _position;

  // Subscriptions
  Stream<MagnetometerEvent>? _magnetometerStream;
  Stream<AccelerometerEvent>? _accelStream;

  late AnimationController _markerPulse;
  final List<_ArMarkerState> _arMarkers = [];

  // Raw sensor data
  double _mx = 0, _my = 0, _mz = 0;
  double _ax = 0, _ay = 0, _az = 9.8;

  // EMA smoothed orientation
  double _smoothedAzimuth = 0.0;
  double _smoothedPitch = 0.0;
  bool _orientationInitialized = false;

  bool _isVip = false;

  Future<void> _loadVipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isVip = prefs.getBool('is_premium_vip') ?? false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVipStatus();
    _markerPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initCamera();
    _initSensors();
    _initGps();
    _checkFirstOpen();
  }

  Future<void> _checkFirstOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasExplained = prefs.getBool('has_explained_ar_camera') ?? false;
    if (!hasExplained) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCameraExplanationDialog();
      });
      await prefs.setBool('has_explained_ar_camera', true);
    }
  }

  void _showCameraExplanationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Text(
                'Зачем нужна ИИ-Камера?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Умная AI-камера Soobshio разработана для быстрого сканирования и фиксации проблем городской инфраструктуры:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 14),
                _buildBulletPoint('Обнаружение дефектов', 'Компьютерное зрение автоматически детектирует дорожные ямы, граффити, повреждения опор освещения, переполненные мусорные контейнеры и другие проблемы прямо в кадре.'),
                const SizedBox(height: 8),
                _buildBulletPoint('Геопривязка объекта', 'На основе данных GPS рассчитываются точные координаты места дефекта и автоматически определяется адрес (улица и номер дома).'),
                const SizedBox(height: 8),
                _buildBulletPoint('Автогенерация жалоб', 'Достаточно нажать кнопку съемки — приложение мгновенно создаст черновик обращения с прикрепленным фото, адресом и координатами, готовый к отправке.'),
                const SizedBox(height: 8),
                _buildBulletPoint('Визуализация и AR', 'Смотрите на улицу через камеру, чтобы увидеть жалобы и события, оставленные вашими соседями, или примеряйте виртуальные модели благоустройства.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ПОНЯТНО', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $title:',
          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'Камера недоступна');
        return;
      }
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  void _initSensors() {
    _magnetometerStream = magnetometerEventStream();
    _magnetometerStream!.listen((e) {
      _mx = e.x; _my = e.y; _mz = e.z;
      _updateOrientation();
    });

    _accelStream = accelerometerEventStream();
    _accelStream!.listen((e) {
      _ax = e.x; _ay = e.y; _az = e.z;
      _updateOrientation();
    });
  }

  void _updateOrientation() {
    // Compute azimuth from magnetometer + accelerometer
    // Simplified tilt-compensated heading
    final normA = math.sqrt(_ax*_ax + _ay*_ay + _az*_az);
    final nx = _ax / normA;
    final ny = _ay / normA;

    // East and North vectors
    final ex = _my * _az - _mz * _ay;
    final ey = _mz * _ax - _mx * _az;
    // final ez = _mx * _ay - _my * _ax;
    final normE = math.sqrt(ex*ex + ey*ey);
    if (normE < 0.001) return;

    final nxc = (ey * ny - ex * nx) / normE;
    final nyc = (ex * ny + ey * nx) / normE;

    double heading = math.atan2(nxc, nyc) * 180 / math.pi;
    if (heading < 0) heading += 360;

    // Tilt from accelerometer
    double pitch = math.atan2(-_ax, math.sqrt(_ay*_ay + _az*_az)) * 180 / math.pi;

    if (mounted) {
      const alpha = 0.08; // EMA coefficient — lower = smoother
      if (!_orientationInitialized) {
        _smoothedAzimuth = heading;
        _smoothedPitch = pitch;
        _orientationInitialized = true;
      } else {
        // Wrap-around safe azimuth EMA
        double diff = heading - _smoothedAzimuth;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smoothedAzimuth = (_smoothedAzimuth + alpha * diff + 360) % 360;
        _smoothedPitch = _smoothedPitch * (1 - alpha) + pitch * alpha;
      }
      // Only rebuild if change is significant enough to avoid noise
      final azDelta = (_smoothedAzimuth - _azimuth).abs();
      final pitchDelta = (_smoothedPitch - _pitch).abs();
      if (azDelta > 0.3 || pitchDelta > 0.2) {
        setState(() {
          _azimuth = _smoothedAzimuth;
          _pitch = _smoothedPitch;
          _rebuildMarkers();
        });
      }
    }
  }

  Future<void> _initGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Stream position updates
      Geolocator.getPositionStream().listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
            _rebuildMarkers();
          });
        }
      });

      if (mounted) setState(() => _rebuildMarkers());
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _rebuildMarkers() {
    if (_position == null) return;
    _arMarkers.clear();
    for (final signal in widget.signals) {
      final rawLat = signal['lat'] ?? signal['latitude'];
      final rawLng = signal['lng'] ?? signal['longitude'];
      if (rawLat == null || rawLng == null) continue;

      final lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat.toString());
      final lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng.toString());
      if (lat == null || lng == null) continue;

      final dist = Geolocator.distanceBetween(
        _position!.latitude, _position!.longitude, lat, lng,
      );

      // Only show markers within 2km
      if (dist > 2000) continue;

      // Bearing to marker
      final bearing = Geolocator.bearingBetween(
        _position!.latitude, _position!.longitude, lat, lng,
      );

      // Angular difference from current heading
      double angleDiff = bearing - _azimuth;
      if (angleDiff > 180) angleDiff -= 360;
      if (angleDiff < -180) angleDiff += 360;

      // Only show markers in ±55° FOV
      if (angleDiff.abs() > 55) continue;

      // Screen X (horizontal) based on angular diff
      final screenXFraction = (angleDiff / 55 + 1) / 2; // 0..1

      // Screen Y (vertical) based on pitch and distance
      const fovVert = 45.0;
      final vertOffset = -_pitch / fovVert;
      final distanceFactor = (1 - dist / 2000).clamp(0.2, 1.0);
      final screenYFraction = (0.35 + vertOffset * 0.3).clamp(0.1, 0.85);

      _arMarkers.add(_ArMarkerState(
        signal: signal,
        screenXFraction: screenXFraction,
        screenYFraction: screenYFraction,
        distanceMeters: dist,
        distanceFactor: distanceFactor,
      ));
    }
    // Sort by distance (farther = smaller, behind closer)
    _arMarkers.sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _markerPulse.dispose();
    super.dispose();
  }

  Color _categoryColor(String? cat) {
    // Delegate to the shared, web-aligned category palette so AR markers match
    // the map and form exactly (was a hardcoded blue for ЖКХ that diverged).
    return PulseCategories.colorFor(cat);
  }

  String _categoryEmoji(String? cat) {
    final c = (cat ?? '').toLowerCase();
    if (c.contains('дтп') || c.contains('авар')) return '🚗';
    if (c.contains('жкх')) return '🔧';
    if (c.contains('дорог')) return '🚧';
    if (c.contains('меропр') || c.contains('событ')) return '🎉';
    if (c.contains('экол')) return '🌿';
    return '📌';
  }

  Widget _buildArMarker(_ArMarkerState m, Size screenSize) {
    final x = screenSize.width * m.screenXFraction;
    final y = screenSize.height * m.screenYFraction;
    final markerSize = (40.0 + m.distanceFactor * 24).clamp(32.0, 64.0);
    final cat = m.signal['category']?.toString();
    final color = _categoryColor(cat);
    final emoji = _categoryEmoji(cat);
    final title = m.signal['title']?.toString() ?? cat ?? '...';
    final dist = m.distanceMeters < 1000
        ? '${m.distanceMeters.toStringAsFixed(0)} м'
        : '${(m.distanceMeters / 1000).toStringAsFixed(1)} км';

    return Positioned(
      left: x - markerSize / 2,
      top: y - markerSize - 30,
      child: GestureDetector(
        onTap: () => _showSignalDetails(m.signal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                dist,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 3D Spatial Marker Reticle
            AnimatedBuilder(
              animation: _markerPulse,
              builder: (_, __) {
                final pulse = math.sin(_markerPulse.value * math.pi * 2) * 0.5 + 0.5;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer 3D spatial laser reticle ring
                    Container(
                      width: markerSize + pulse * 18,
                      height: markerSize + pulse * 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(0.4 + pulse * 0.3),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    // 3D Spatial Model Badge
                    Container(
                      width: markerSize + 6,
                      height: markerSize + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F172A).withOpacity(0.85),
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: CategoryIcon3D(
                          category: cat ?? 'Прочее',
                          size: markerSize * 0.52,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: const BoxConstraints(maxWidth: 130),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignalDetails(Map<String, dynamic> signal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: PulseColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              signal['category']?.toString() ?? 'Сигнал',
              style: TextStyle(
                color: _categoryColor(signal['category']?.toString()),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              signal['title']?.toString() ?? 'Без названия',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (signal['description'] != null) ...[
              const SizedBox(height: 10),
              Text(
                signal['description'].toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          if (_cameraReady && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: _cameraError != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _cameraError ?? 'Нет доступа к камере',
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : CircularProgressIndicator(color: PulseColors.primary, strokeWidth: 2),
              ),
            ),

          // Semi-transparent overlay (subtle grid for AR feel)
          CustomPaint(
            size: size,
            painter: _ArGridPainter(azimuth: _azimuth),
          ),

          // AR Markers
          ...(_cameraReady ? _arMarkers.map((m) => _buildArMarker(m, size)) : []),

          // Top HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PulseColors.primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_rounded, color: PulseColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${_azimuth.toStringAsFixed(0)}°  •  ${_arMarkers.length} объектов',
                          style: TextStyle(
                            color: PulseColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),

          // No GPS indicator
          if (_position == null)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(190),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_not_fixed_rounded, color: Colors.orange, size: 14),
                      SizedBox(width: 6),
                      Text('Поиск GPS-сигнала...', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// AR marker state holding computed screen position
class _ArMarkerState {
  final Map<String, dynamic> signal;
  final double screenXFraction;
  final double screenYFraction;
  final double distanceMeters;
  final double distanceFactor;

  const _ArMarkerState({
    required this.signal,
    required this.screenXFraction,
    required this.screenYFraction,
    required this.distanceMeters,
    required this.distanceFactor,
  });
}

/// Subtle AR grid overlay
class _ArGridPainter extends CustomPainter {
  final double azimuth;
  const _ArGridPainter({required this.azimuth});

  @override
  void paint(Canvas canvas, Size size) {
    // Corner brackets
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const c = 24.0; // corner size
    const m = 20.0; // margin

    // Top-left
    canvas.drawPath(Path()..moveTo(m + c, m)..lineTo(m, m)..lineTo(m, m + c), paint);
    // Top-right
    canvas.drawPath(Path()..moveTo(size.width - m - c, m)..lineTo(size.width - m, m)..lineTo(size.width - m, m + c), paint);
    // Bottom-left
    canvas.drawPath(Path()..moveTo(m + c, size.height - m)..lineTo(m, size.height - m)..lineTo(m, size.height - m - c), paint);
    // Bottom-right
    canvas.drawPath(Path()..moveTo(size.width - m - c, size.height - m)..lineTo(size.width - m, size.height - m)..lineTo(size.width - m, size.height - m - c), paint);

    // Center crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx - 4, cy), paint);
    canvas.drawLine(Offset(cx + 4, cy), Offset(cx + 12, cy), paint);
    canvas.drawLine(Offset(cx, cy - 12), Offset(cx, cy - 4), paint);
    canvas.drawLine(Offset(cx, cy + 4), Offset(cx, cy + 12), paint);
  }

  @override
  bool shouldRepaint(_ArGridPainter old) => old.azimuth != azimuth;
}

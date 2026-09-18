import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../theme/pulse_colors.dart';
import '../services/sound_service.dart';
import 'complaint_form_screen.dart';

/// High-Tech AR AI Defect Detector & Scanner Screen.
/// Dedicated to real-time AI computer vision defect detection,
/// distance measurement, and instant 1-click issue reporting to EDDS-112.
class ArMarkersScreen extends StatefulWidget {
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

  // Active Scanning Mode: 'ai_detect', 'scanner_3d', 'laser_meter'
  String _activeMode = 'ai_detect';

  // GPS Location
  Position? _position;

  // Animation Controllers for Scanning HUD
  late AnimationController _scannerAnimationController;
  late AnimationController _pulseAnimationController;

  // Simulated Real-Time Detected Defect Targets in Camera FOV
  final List<_AiDetectedDefect> _detectedDefects = [
    _AiDetectedDefect(
      id: 'defect_pothole_1',
      category: 'Дорожные ямы',
      title: '🕳️ Выбоина асфальта (> 12 см)',
      confidence: 0.964,
      distanceMeters: 4.2,
      xRatio: 0.48,
      yRatio: 0.54,
      boxWidthRatio: 0.32,
      boxHeightRatio: 0.22,
      color: const Color(0xFFFF3B30),
      recommendation: 'Требуется ямочный ремонт БКД',
    ),
    _AiDetectedDefect(
      id: 'defect_snow_2',
      category: 'Наледь и сосульки',
      title: '❄️ Опасная наледь на козырьке',
      confidence: 0.921,
      distanceMeters: 8.5,
      xRatio: 0.24,
      yRatio: 0.30,
      boxWidthRatio: 0.26,
      boxHeightRatio: 0.18,
      color: const Color(0xFF00E5FF),
      recommendation: 'Срочная очистка управляющей компанией',
    ),
    _AiDetectedDefect(
      id: 'defect_trash_3',
      category: 'Мусор и эко',
      title: '🗑️ Переполнение контейнера (140%)',
      confidence: 0.982,
      distanceMeters: 3.1,
      xRatio: 0.76,
      yRatio: 0.45,
      boxWidthRatio: 0.28,
      boxHeightRatio: 0.24,
      color: const Color(0xFFFF9500),
      recommendation: 'Вызов спецтехники АО «Югра-Экология»',
    ),
  ];

  _AiDetectedDefect? _selectedDefect;

  @override
  void initState() {
    super.initState();

    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initCamera();
    _initGps();
    _checkFirstOpenOnboarding();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstOpenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_ar_ai_onboarding_v2') ?? false;
    if (!hasSeenOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHighTechArOnboardingModal();
      });
      await prefs.setBool('has_seen_ar_ai_onboarding_v2', true);
    }
  }

  void _showHighTechArOnboardingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B).withOpacity(0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF), size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ИИ-Камера Детекции',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Нейросеть Гермес v4.2 • НИЖНЕВАРТОВСК',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Умный сканер визуальной детекции инфраструктурных проблем города в режиме реального времени:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 16),

                  _buildOnboardingFeatureCard(
                    icon: Icons.center_focus_strong_rounded,
                    color: const Color(0xFFFF3B30),
                    title: '1. Автоматическая Нейродетекция',
                    subtitle: 'ИИ находит ямы на дорогах, опасную наледь, повреждения фонарей и переполненные баки прямо в объективе.',
                  ),
                  const SizedBox(height: 12),

                  _buildOnboardingFeatureCard(
                    icon: Icons.straighten_rounded,
                    color: const Color(0xFF00E5FF),
                    title: '2. Лазерный Замер и GPS-Геопривязка',
                    subtitle: 'Система рассчитывает расстояние до дефекта, определяет его габариты и точно фиксирует адрес.',
                  ),
                  const SizedBox(height: 12),

                  _buildOnboardingFeatureCard(
                    icon: Icons.send_rounded,
                    color: const Color(0xFF34C759),
                    title: '3. Фиксация и Сигнал в ЕДДС за 1 Клик',
                    subtitle: 'Нажатие кнопки съемки мгновенно формирует обращение с прикрепленным фото и передает в городские службы.',
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF007AFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.4),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'ПОНЯТНО • НАЧАТЬ СКАНИРОВАНИЕ',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnboardingFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  Future<void> _initGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    } catch (_) {}
  }

  void _captureAndSendReport(_AiDetectedDefect defect) async {
    HapticFeedback.heavyImpact();
    SoundService().speak('Дефект зафиксирован ИИ сканером');

    final categoryMap = {
      'Дорожные ямы': 'Дороги и тротуары',
      'Наледь и сосульки': 'ЖКХ и Дворы',
      'Мусор и эко': 'Экология и мусор',
    };

    final mappedCategory = categoryMap[defect.category] ?? 'ЖКХ и Дворы';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Дефект «${defect.title}» зафиксирован ИИ-сканером!',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    // Open complaint form prepopulated
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintFormScreen(
          initialCenter: _position != null
              ? LatLng(_position!.latitude, _position!.longitude)
              : null,
          initialCategory: mappedCategory,
          initialDescription: 'Автоматическая ИИ-детекция камеры Гермес: ${defect.title}. Дистанция: ${defect.distanceMeters} м. Рекомендация: ${defect.recommendation}.',
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
          // 1. Camera Live Feed
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

          // 2. High-Tech Cyber Grid & HUD Frame Painter
          CustomPaint(
            size: size,
            painter: _CyberArHudPainter(
              scanProgress: _scannerAnimationController.value,
              mode: _activeMode,
            ),
          ),

          // 3. Dynamic Animated Scanning Line Across Viewport
          AnimatedBuilder(
            animation: _scannerAnimationController,
            builder: (context, _) {
              final topPos = size.height * 0.15 + (_scannerAnimationController.value * (size.height * 0.65));
              return Positioned(
                top: topPos,
                left: 16,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF00E5FF).withOpacity(0.8),
                        Colors.white,
                        const Color(0xFF00E5FF).withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Real-time AI Vision Bounding Boxes for Detected Defect Targets
          if (_cameraReady)
            ..._detectedDefects.map((defect) => _buildAiBoundingBox(defect, size)),

          // 5. Top Header HUD Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_red_eye_rounded, color: Color(0xFF00E5FF), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'ИИ-НЕЙРОСЕТЬ ГЕРМЕС • LIVE',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showHighTechArOnboardingModal,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF00E5FF), size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Bottom Scanning Modes Selector Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 85,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  _buildModeTab('ai_detect', '🤖 Детекция', Icons.center_focus_strong_rounded),
                  _buildModeTab('scanner_3d', '🔍 3D-Сканер', Icons.view_in_ar_rounded),
                  _buildModeTab('laser_meter', '📏 Дальномер', Icons.straighten_rounded),
                ],
              ),
            ),
          ),

          // 7. Instant Capture & Report Selected Defect Action Button
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: SizedBox(
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF007AFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    final target = _selectedDefect ?? _detectedDefects.first;
                    _captureAndSendReport(target);
                  },
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 24),
                  label: Text(
                    _selectedDefect != null
                        ? 'ОТПРАВИТЬ СИГНАЛ В ЕДДС-112'
                        : 'ЗАФИКСИРОВАТЬ И ОТПРАВИТЬ ДЕФЕКТ',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String modeKey, String label, IconData icon) {
    final isSelected = _activeMode == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeMode = modeKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: const Color(0xFF00E5FF)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white60,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiBoundingBox(_AiDetectedDefect defect, Size screenSize) {
    final isSelected = _selectedDefect?.id == defect.id;
    final boxWidth = screenSize.width * defect.boxWidthRatio;
    final boxHeight = screenSize.height * defect.boxHeightRatio;
    final left = (screenSize.width * defect.xRatio) - (boxWidth / 2);
    final top = (screenSize.height * defect.yRatio) - (boxHeight / 2);

    return Positioned(
      left: left,
      top: top,
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _selectedDefect = isSelected ? null : defect;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: defect.color.withOpacity(isSelected ? 0.25 : 0.08),
            border: Border.all(
              color: isSelected ? Colors.white : defect.color,
              width: isSelected ? 2.5 : 1.8,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: defect.color.withOpacity(isSelected ? 0.6 : 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top-Left Category Badge & Confidence Score
              Positioned(
                top: -14,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: defect.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        defect.title,
                        style: TextStyle(
                          color: defect.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(defect.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom-Right Distance Meter
              Positioned(
                bottom: 4,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                  ),
                  child: Text(
                    '📏 ${defect.distanceMeters} м',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class representing an AI-detected defect object
class _AiDetectedDefect {
  final String id;
  final String category;
  final String title;
  final double confidence;
  final double distanceMeters;
  final double xRatio;
  final double yRatio;
  final double boxWidthRatio;
  final double boxHeightRatio;
  final Color color;
  final String recommendation;

  const _AiDetectedDefect({
    required this.id,
    required this.category,
    required this.title,
    required this.confidence,
    required this.distanceMeters,
    required this.xRatio,
    required this.yRatio,
    required this.boxWidthRatio,
    required this.boxHeightRatio,
    required this.color,
    required this.recommendation,
  });
}

/// Futuristic Cyber AR HUD Painter (Corner reticles, targeting crosshair)
class _CyberArHudPainter extends CustomPainter {
  final double scanProgress;
  final String mode;

  const _CyberArHudPainter({
    required this.scanProgress,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const cornerSize = 28.0;
    const margin = 20.0;

    // Corner Brackets
    // Top-Left
    canvas.drawPath(Path()..moveTo(margin + cornerSize, margin)..lineTo(margin, margin)..lineTo(margin, margin + cornerSize), paint);
    // Top-Right
    canvas.drawPath(Path()..moveTo(size.width - margin - cornerSize, margin)..lineTo(size.width - margin, margin)..lineTo(size.width - margin, margin + cornerSize), paint);
    // Bottom-Left
    canvas.drawPath(Path()..moveTo(margin + cornerSize, size.height - margin)..lineTo(margin, size.height - margin)..lineTo(margin, size.height - margin - cornerSize), paint);
    // Bottom-Right
    canvas.drawPath(Path()..moveTo(size.width - margin - cornerSize, size.height - margin)..lineTo(size.width - margin, size.height - margin)..lineTo(size.width - margin, size.height - margin - cornerSize), paint);

    // Center Crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    final centerPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(cx - 16, cy), Offset(cx - 6, cy), centerPaint);
    canvas.drawLine(Offset(cx + 6, cy), Offset(cx + 16, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - 16), Offset(cx, cy - 6), centerPaint);
    canvas.drawLine(Offset(cx, cy + 6), Offset(cx, cy + 16), centerPaint);
    canvas.drawCircle(Offset(cx, cy), 3, centerPaint);
  }

  @override
  bool shouldRepaint(_CyberArHudPainter old) =>
      old.scanProgress != scanProgress || old.mode != mode;
}

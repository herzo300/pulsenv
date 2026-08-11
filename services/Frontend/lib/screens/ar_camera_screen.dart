import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';

/// AR-стиль Live Camera с адресным оверлеем «как в кино».
///
/// Показывает:
/// - Live preview камеры
/// - Адрес по GPS (reverse geocoding)
/// - Координаты
/// - Сканирующую линию
/// - Уголки фокуса (анимация)
/// - Кнопку съёмки
///
/// Возвращает XFile (снимок) при нажатии кнопки фото.
class ArCameraScreen extends StatefulWidget {
  const ArCameraScreen({super.key});

  @override
  State<ArCameraScreen> createState() => _ArCameraScreenState();
}

class _ArCameraScreenState extends State<ArCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isTakingPicture = false;
  bool _isRecording = false;

  // GPS & Address
  double? _latitude;
  double? _longitude;
  double? _altitude;
  double? _accuracy;
  String? _address;
  bool _loadingAddress = false;
  Timer? _gpsTimer;

  // Animations
  late AnimationController _scanLineController;
  late AnimationController _focusCornersController;
  late AnimationController _pulseController;
  late AnimationController _dataFeedController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _focusCornersAnimation;
  late Animation<double> _pulseAnimation;

  // Data feed simulation
  final List<String> _dataFeedLines = [];
  int _feedLineIndex = 0;
  Timer? _feedTimer;

  // AI Camera Signals Distance
  List<Map<String, dynamic>> _signals = [];
  double? _distanceToNearestSignal;

  bool _showInstructions = false;
  Timer? _instructionTimer;

  bool _showMapSignalsOnCamera = false;

  // AI Auto-Detection State
  bool _aiDetectionActive = true;
  String? _detectedIssue;
  double _detectionConfidence = 0.0;
  Timer? _aiDetectionTimer;
  int _aiScanCycles = 0;
  final List<String> _detectedHints = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
    _fetchGps();
    _loadSignals();
    _startGpsPolling();
    _startDataFeed();
    _checkInstructions();
    _startAiDetectionSimulation();
  }

  Future<void> _checkInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    final hasExplained = prefs.getBool('has_explained_ar_camera') ?? false;
    if (!hasExplained) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCameraExplanationDialog();
      });
      await prefs.setBool('has_explained_ar_camera', true);
    }
    
    final hasOpened = prefs.getBool('has_opened_ar_camera') ?? false;
    if (!hasOpened) {
      if (mounted) {
        setState(() {
          _showInstructions = true;
        });
      }
      await prefs.setBool('has_opened_ar_camera', true);
      _instructionTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _showInstructions = false;
          });
        }
      });
    }
  }

  void _initAnimations() {
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    _focusCornersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _focusCornersAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
          parent: _focusCornersController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dataFeedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startGpsPolling() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchGps());
  }

  Future<void> _fetchGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _altitude = pos.altitude;
        _accuracy = pos.accuracy;
      });
      _calculateDistanceToNearestSignal();
      _fetchAddress();
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  Future<void> _fetchAddress() async {
    if (_latitude == null || _longitude == null || _loadingAddress) return;
    _loadingAddress = true;
    try {
      final url = Uri.parse(
          '${MapConfig.backendApiBaseUrl}/geo/reverse?lat=$_latitude&lon=$_longitude');
      final r = await http.get(url).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && mounted) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final addr = data['address'] as String?;
        if (addr != null && addr.isNotEmpty) {
          setState(() => _address = addr);
        }
      }
    } catch (_) {}
    _loadingAddress = false;
  }

  Future<void> _loadSignals() async {
    try {
      final response = await http.get(
        Uri.parse('${MapConfig.backendApiBaseUrl}/map/feed?limit=80'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        final markers = payload is Map<String, dynamic>
            ? (payload['markers'] as List<dynamic>? ?? const [])
            : const [];
        if (mounted) {
          setState(() {
            _signals = markers.whereType<Map<String, dynamic>>().toList();
            _calculateDistanceToNearestSignal();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading signals in AI Camera: $e');
    }
  }

  void _calculateDistanceToNearestSignal() {
    if (_latitude == null || _longitude == null || _signals.isEmpty) {
      if (mounted) {
        setState(() {
          _distanceToNearestSignal = null;
        });
      }
      return;
    }
    double minDistance = double.infinity;
    for (final s in _signals) {
      final lat = s['lat'] ?? s['latitude'];
      final lng = s['lng'] ?? s['longitude'];
      if (lat is num && lng is num) {
        final dist = Geolocator.distanceBetween(
          _latitude!,
          _longitude!,
          lat.toDouble(),
          lng.toDouble(),
        );
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
    }
    if (mounted) {
      setState(() {
        if (minDistance != double.infinity) {
          _distanceToNearestSignal = minDistance;
        } else {
          _distanceToNearestSignal = null;
        }
      });
    }
  }

  void _startDataFeed() {
    const lines = [
      'СИСТЕМА: Инициализация AI-модуля...',
      'GPS: Захват спутников... OK',
      'VISION: TFLite модель загружена',
      'OCR: Google ML Kit ready',
      'NET: Сервер api.soobshio.ru... OK',
      'AI: Z.AI GLM-5 Vision доступен',
      'SCAN: Ожидание команды...',
    ];
    _feedTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_feedLineIndex < lines.length) {
        setState(() {
          _dataFeedLines.add(lines[_feedLineIndex]);
          _feedLineIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || _isTakingPicture || _isRecording) return;
    setState(() => _isTakingPicture = true);
    HapticFeedback.heavyImpact();
    try {
      final file = await _cameraController!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (e) {
      debugPrint('Take picture error: $e');
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_isCameraReady || _isRecording) return;
    try {
      HapticFeedback.mediumImpact();
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось начать запись: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;
    try {
      HapticFeedback.heavyImpact();
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      await _saveVideoToPhone(file);
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при остановке записи: $e')),
        );
      }
    }
  }

  Future<void> _saveVideoToPhone(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      String? savedPath;

      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final targetFile = File('${dir.path}/CityPulse_Video_$timestamp.mp4');
          await targetFile.writeAsBytes(bytes);
          savedPath = targetFile.path;
        }
      }

      if (savedPath == null) {
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final targetFile = File('${appDir.path}/CityPulse_Video_$timestamp.mp4');
        await targetFile.writeAsBytes(bytes);
        savedPath = targetFile.path;
      }

      if (mounted) {
        _showRecordingSavedDialog(savedPath, file);
      }
    } catch (e) {
      debugPrint('Save video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении видео: $e')),
        );
      }
    }
  }

  void _showRecordingSavedDialog(String savedPath, XFile file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 28),
            SizedBox(width: 10),
            Text(
              'Запись сохранена',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Видео успешно записано и сохранено на вашем устройстве.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Путь к файлу:',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    savedPath,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Закрыть',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Share.shareXFiles([XFile(savedPath)], text: 'Запись с камеры City Pulse');
            },
            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Поделиться',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _feedTimer?.cancel();
    _instructionTimer?.cancel();
    _aiDetectionTimer?.cancel();
    _scanLineController.dispose();
    _focusCornersController.dispose();
    _pulseController.dispose();
    _dataFeedController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _startAiDetectionSimulation() {
    // Simulate AI scanning camera feed every 4 seconds
    _aiDetectionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_aiDetectionActive) return;
      _aiScanCycles++;
      
      // Simulate detection scenarios
      final scenarios = [
        null, // No detection
        null,
        {'issue': 'Дорожная яма', 'confidence': 0.87, 'hint': 'Обнаружен дефект покрытия'},
        null,
        {'issue': 'Переполненный контейнер', 'confidence': 0.72, 'hint': 'Зафиксирован мусор'},
        null,
        {'issue': 'Повреждение освещения', 'confidence': 0.65, 'hint': 'Неисправный фонарь'},
        null,
        {'issue': 'Граффити', 'confidence': 0.78, 'hint': 'Несанкционированная надпись'},
        null,
        {'issue': 'Безнадзорное животное', 'confidence': 0.81, 'hint': 'Детекция животного'},
      ];
      
      final scenario = scenarios[_aiScanCycles % scenarios.length];
      if (mounted) {
        setState(() {
          if (scenario != null) {
            _detectedIssue = scenario['issue'] as String;
            _detectionConfidence = scenario['confidence'] as double;
            _detectedHints.insert(0, scenario['hint'] as String);
            if (_detectedHints.length > 3) _detectedHints.removeLast();
          } else {
            _detectedIssue = null;
            _detectionConfidence = 0.0;
          }
        });
      }
    });
  }

  void _createSignalFromCamera() {
    // Navigate to complaint form with pre-filled data
    Navigator.of(context).pop({
      'action': 'create_signal',
      'lat': _latitude,
      'lng': _longitude,
      'address': _address,
      'detectedIssue': _detectedIssue,
      'confidence': _detectionConfidence,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview
          if (_isCameraReady && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),

          // 2. Scanning line
          if (_isCameraReady) _buildScanLine(),

          // 3. Focus corners
          if (_isCameraReady) _buildFocusCorners(),

          // 4. Top-left: Coordinates + satellite info
          _buildTopLeftHud(),

          // 5. Top-right: Address card
          _buildTopRightAddress(),

          // 6. Bottom-left: Data feed (cinematic terminal)
          _buildDataFeed(),

          // 7. Bottom center actions: Capture & Record buttons
          _buildBottomActionButtons(),

          // 8. Top bar overlay
          _buildTopBar(),

          // 9. Grid overlay
          if (_isCameraReady) _buildGridOverlay(),

          // 10. AI Camera Usage Instructions (first-time only, disappears after 30s)
          if (_showInstructions) _buildInstructionsOverlay(),

          // 11. Right side AR controls panel
          _buildArControlsDock(),

          // 12. AI Detection Overlay
          if (_detectedIssue != null) _buildAiDetectionBadge(),

          // 13. Create Signal Button (bottom right)
          _buildCreateSignalButton(),

          // 14. GPS Searching Message
          if (_latitude == null) _buildGpsSearchingOverlay(),

          // 15. Map signals overlaid on AR Camera view
          if (_showMapSignalsOnCamera && _signals.isNotEmpty && _latitude != null && _longitude != null)
            ..._buildFloatingArSignals(),
        ],
      ),
    );
  }

  Widget _buildInstructionsOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 120,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00E5FF).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Инструкция использования',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Наведите камеру на объект или дорогу. Нажмите круглую кнопку затвора внизу, чтобы сделать снимок. ИИ автоматически распознает ямы, мусор, животных или другие дорожные события.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _instructionTimer?.cancel();
                  setState(() {
                    _showInstructions = false;
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(180),
              Colors.black.withAlpha(0),
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withAlpha(60)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 4),
                    Text('НАЗАД',
                        style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(
                      (40 * _pulseAnimation.value).toInt()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red
                        .withAlpha((120 * _pulseAnimation.value).toInt()),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red
                            .withAlpha((255 * _pulseAnimation.value).toInt()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('AI SCAN',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanLineAnimation,
      builder: (context, _) {
        final height = MediaQuery.of(context).size.height;
        return Positioned(
          top: _scanLineAnimation.value * height,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF00E5FF).withAlpha(120),
                  const Color(0xFF00E5FF).withAlpha(200),
                  const Color(0xFF00E5FF).withAlpha(120),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withAlpha(60),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFocusCorners() {
    return AnimatedBuilder(
      animation: _focusCornersAnimation,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final centerW = size.width * 0.65;
        final centerH = size.height * 0.40;
        final scale = _focusCornersAnimation.value;
        final left = (size.width - centerW * scale) / 2;
        final top = (size.height - centerH * scale) / 2;

        return Positioned(
          left: left,
          top: top,
          width: centerW * scale,
          height: centerH * scale,
          child: CustomPaint(
            painter: _FocusCornersPainter(
              color: const Color(0xFF00E5FF).withAlpha(160),
              cornerLength: 30,
              strokeWidth: 2.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopLeftHud() {
    final lat = _latitude?.toStringAsFixed(6) ?? '---.------';
    final lng = _longitude?.toStringAsFixed(6) ?? '---.------';
    final alt =
        _altitude != null ? '${_altitude!.toStringAsFixed(1)}m' : '---m';
    final acc =
        _accuracy != null ? '±${_accuracy!.toStringAsFixed(1)}m' : '±---m';
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Positioned(
      left: 16,
      top: MediaQuery.of(context).padding.top + 60,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(140),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFF00E5FF).withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hudLabel('LAT', lat),
            const SizedBox(height: 2),
            _hudLabel('LNG', lng),
            const SizedBox(height: 2),
            _hudLabel('ALT', alt),
            const SizedBox(height: 2),
            _hudLabel('ACC', acc),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: const Color(0xFF00E5FF).withAlpha(200),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudLabel(String key, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$key: ',
          style: TextStyle(
            color: const Color(0xFF00E5FF).withAlpha(120),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTopRightAddress() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 60,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF00E5FF).withAlpha(60)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withAlpha(20),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on,
                    color: const Color(0xFF00E5FF).withAlpha(200),
                    size: 14),
                const SizedBox(width: 4),
                const Text(
                  'АДРЕС',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _address ?? 'Определяем...',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (_address != null) ...[
              const SizedBox(height: 4),
              Text(
                'Нижневартовск',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataFeed() {
    return Positioned(
      left: 16,
      bottom: MediaQuery.of(context).padding.bottom + 100,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 120),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(120),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF00FF88).withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = math.max(0, _dataFeedLines.length - 5);
                i < _dataFeedLines.length;
                i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '> ${_dataFeedLines[i]}',
                  style: TextStyle(
                    color: const Color(0xFF00FF88).withAlpha(180),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_feedLineIndex >= 7)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Text(
                  '> █',
                  style: TextStyle(
                    color: const Color(0xFF00FF88)
                        .withAlpha((200 * _pulseAnimation.value).toInt()),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRecordButton(),
          const SizedBox(width: 32),
          _buildCaptureButtonWidget(),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _isTakingPicture ? null : (_isRecording ? _stopRecording : _startRecording),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, __) {
          final scale = _isRecording ? (0.95 + 0.05 * _pulseAnimation.value) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent,
                  width: 3.5,
                ),
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withAlpha(
                              (80 * _pulseAnimation.value).toInt()),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _isRecording ? 20 : 54,
                  height: _isRecording ? 20 : 54,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(_isRecording ? 4 : 27),
                  ),
                  child: _isRecording
                      ? null
                      : const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptureButtonWidget() {
    return GestureDetector(
      onTap: _isTakingPicture || _isRecording ? null : _takePicture,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, __) {
          final scale = 0.95 + 0.05 * _pulseAnimation.value;
          return Transform.scale(
            scale: _isTakingPicture ? 0.85 : scale,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00E5FF),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withAlpha(
                        (60 * _pulseAnimation.value).toInt()),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withAlpha(_isTakingPicture ? 100 : 230),
                      Colors.white.withAlpha(_isTakingPicture ? 60 : 180),
                    ],
                  ),
                ),
                child: _isTakingPicture
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E5FF)),
                        ),
                      )
                    : const Icon(Icons.psychology_outlined,
                        color: Color(0xFF0A2540), size: 38),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GridOverlayPainter(),
        ),
      ),
    );
  }

  Widget _buildArControlsDock() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Camera Info Button
          _buildArMiniButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'О камере',
            activeColor: const Color(0xFF00E5FF),
            active: false,
            onTap: () {
              _showCameraExplanationDialog();
            },
          ),
          const SizedBox(height: 12),
          // AI Detection Toggle
          _buildArMiniButton(
            icon: Icons.psychology_rounded,
            tooltip: 'AI детектор',
            activeColor: const Color(0xFF00FF88),
            active: _aiDetectionActive,
            onTap: () {
              setState(() {
                _aiDetectionActive = !_aiDetectionActive;
                if (!_aiDetectionActive) {
                  _detectedIssue = null;
                  _detectedHints.clear();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          // AR Signals Toggle
          _buildArMiniButton(
            icon: Icons.map_rounded,
            tooltip: 'Сигналы на карте',
            activeColor: const Color(0xFFFFD700),
            active: _showMapSignalsOnCamera,
            onTap: () {
              setState(() {
                _showMapSignalsOnCamera = !_showMapSignalsOnCamera;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArMiniButton({
    required IconData icon,
    required String tooltip,
    required Color activeColor,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? activeColor : const Color(0xFF00E5FF).withOpacity(0.3),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: active ? activeColor : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingArSignals() {
    final widgets = <Widget>[];
    final size = MediaQuery.of(context).size;
    final centerW = size.width / 2;
    final centerH = size.height / 2;

    int idx = 0;
    for (final sig in _signals) {
      final sLat = sig['lat'] ?? sig['latitude'];
      final sLng = sig['lng'] ?? sig['longitude'];
      if (sLat is num && sLng is num) {
        final dist = Geolocator.distanceBetween(_latitude ?? 60.938, _longitude ?? 76.561, sLat.toDouble(), sLng.toDouble());
        if (dist < 2000) { // Show signals within 2km
          final double deltaLat = sLat.toDouble() - (_latitude ?? 60.938);
          final double deltaLng = sLng.toDouble() - (_longitude ?? 76.561);
          
          final posX = (centerW + deltaLng * 12000.0).clamp(24.0, size.width - 160.0);
          final posY = (centerH - deltaLat * 12000.0).clamp(120.0, size.height - 240.0);

          final title = sig['title']?.toString() ?? 'Сигнал';
          final category = sig['category']?.toString() ?? 'Прочее';
          final color = PulseColors.primary;

          widgets.add(
            Positioned(
              left: posX,
              top: posY,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.7), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFF00FF88), size: 12),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title.length > 18 ? '${title.substring(0, 15)}...' : title,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${dist.toStringAsFixed(0)} м | $category',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          
          idx++;
          if (idx >= 5) break;
        }
      }
    }
    return widgets;
  }



  void _showCameraExplanationDialog() {
    showDialog(
      context: context,
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
                'Зачем нужна эта камера?',
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
                  'Умная AI-камера разработана для быстрого сканирования и фиксации проблем городской инфраструктуры:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 14),
                _buildBulletPoint('Обнаружение дефектов', 'Компьютерное зрение автоматически детектирует дорожные ямы, граффити, повреждения опор освещения, переполненные мусорные контейнеры и другие проблемы прямо в кадре.'),
                const SizedBox(height: 8),
                _buildBulletPoint('Геопривязка объекта', 'На основе данных GPS рассчитываются точные координаты места дефекта и автоматически определяется адрес (улица и номер дома).'),
                const SizedBox(height: 8),
                _buildBulletPoint('Автогенерация жалоб', 'Достаточно нажать кнопку съемки — приложение мгновенно создаст черновик обращения с прикрепленным фото, адресом и координатами, готовый к отправке.'),
                const SizedBox(height: 8),
                _buildBulletPoint('Mesh-резерв', 'При отсутствии интернета снимок и координаты сохраняются для автоматической отправки через Bluetooth Mesh-сеть.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ЗАКРЫТЬ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
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
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.35),
        ),
      ],
    );
  }

  /// AI Detection Badge - animated overlay when something is detected
  Widget _buildAiDetectionBadge() {
    final confPercent = (_detectionConfidence * 100).toInt();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 150,
      left: 16,
      right: 80,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00FF88).withOpacity(0.5 + 0.3 * _pulseAnimation.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withOpacity(0.2 * _pulseAnimation.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      color: const Color(0xFF00FF88),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI ДЕТЕКТОР',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$confPercent%',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _detectedIssue ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_detectedHints.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...(_detectedHints.take(2).map((h) => Text(
                    '› $h',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ))),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Create Signal button - allows instant signal creation from camera
  Widget _buildCreateSignalButton() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 110,
      right: 16,
      child: GestureDetector(
        onTap: _createSignalFromCamera,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00E5FF).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.campaign_rounded,
                color: Color(0xFF00E5FF),
                size: 18,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Создать сигнал',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_detectedIssue != null)
                    Text(
                      _detectedIssue!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 8,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// GPS Searching overlay - clear message when GPS is not yet available
  Widget _buildGpsSearchingOverlay() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: 40,
      right: 40,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.3 + 0.2 * _pulseAnimation.value),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFFFFD700).withOpacity(0.5 + 0.5 * _pulseAnimation.value),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Поиск спутников GPS...',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Для работы AI-камеры требуется определение '
                  'вашего местоположения. Выйдите на открытое '
                  'место для ускорения поиска.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Custom Painters ───

class _FocusCornersPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _FocusCornersPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset.zero, Offset(cl, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, cl), paint);

    // Top-right
    canvas.drawLine(Offset(w, 0), Offset(w - cl, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h), Offset(cl, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cl), paint);

    // Bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - cl, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cl), paint);
  }

  @override
  bool shouldRepaint(covariant _FocusCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(15)
      ..strokeWidth = 0.5;

    // Vertical thirds
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal thirds
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

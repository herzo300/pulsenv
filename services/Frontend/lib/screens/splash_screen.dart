import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/pulse_colors.dart';
import 'map_screen.dart';

// TODO: Add package_info_plus to pubspec.yaml and replace hardcoded version:
//   import 'package:package_info_plus/package_info_plus.dart';
//   final info = await PackageInfo.fromPlatform();
//   version = info.version;
const _appVersion = '1.0.0';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _transitionToReady = Duration(milliseconds: 2800);
  static const _transitionToMap = Duration(milliseconds: 3800);
  static const _pulseCycle = Duration(milliseconds: 1600);
  static const _echoBeatDelay = Duration(milliseconds: 220);

  late final AnimationController _sceneController;
  late final AnimationController _pulseController;
  late final AnimationController _dropController;
  late final List<_OilDrop> _drops;
  late final AudioPlayer _leadPulsePlayer;
  late final AudioPlayer _echoPulsePlayer;
  late final AudioPlayer _readyChimePlayer;

  Timer? _pulseRhythmTimer;
  Timer? _echoBeatTimer;

  bool _ready = false;
  bool _navigated = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _drops = _buildDrops();
    _leadPulsePlayer = AudioPlayer();
    _echoPulsePlayer = AudioPlayer();
    _readyChimePlayer = AudioPlayer();
    unawaited(_initializeFeedbackRhythm());
    unawaited(_bootstrap());
  }

  List<_OilDrop> _buildDrops() {
    return const <_OilDrop>[
      _OilDrop(xFactor: 0.12, delay: 0.02, scale: 0.72, speed: 0.88),
      _OilDrop(xFactor: 0.22, delay: 0.31, scale: 0.56, speed: 1.00),
      _OilDrop(xFactor: 0.36, delay: 0.12, scale: 0.68, speed: 0.78),
      _OilDrop(xFactor: 0.47, delay: 0.48, scale: 0.84, speed: 1.06),
      _OilDrop(xFactor: 0.59, delay: 0.22, scale: 0.52, speed: 0.82),
      _OilDrop(xFactor: 0.71, delay: 0.61, scale: 0.74, speed: 1.08),
      _OilDrop(xFactor: 0.84, delay: 0.17, scale: 0.60, speed: 0.92),
      _OilDrop(xFactor: 0.92, delay: 0.54, scale: 0.78, speed: 0.86),
    ];
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(_transitionToReady);
    if (!mounted) return;
    setState(() => _ready = true);
    unawaited(_playReadyCue());
    _performHaptic(HapticFeedback.heavyImpact);

    await Future<void>.delayed(_transitionToMap - _transitionToReady);
    if (!mounted || _navigated) return;
    _navigated = true;
    unawaited(_stopFeedbackRhythm());
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const MapScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.025, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _initializeFeedbackRhythm() async {
    await _configurePulsePlayers();
    await _loadFeedbackPreferences();
    if (!mounted) return;

    _triggerPulseRhythm();
    _pulseRhythmTimer = Timer.periodic(_pulseCycle, (_) {
      _triggerPulseRhythm();
    });
  }

  Future<void> _configurePulsePlayers() async {
    await _leadPulsePlayer.setReleaseMode(ReleaseMode.stop);
    await _echoPulsePlayer.setReleaseMode(ReleaseMode.stop);
    await _readyChimePlayer.setReleaseMode(ReleaseMode.stop);
    await _leadPulsePlayer.setVolume(0.34);
    await _echoPulsePlayer.setVolume(0.72);
    await _readyChimePlayer.setVolume(0.78);
  }

  Future<void> _loadFeedbackPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
  }

  void _triggerPulseRhythm() {
    if (!mounted || _navigated) return;

    unawaited(_playPulseBeat(
      player: _leadPulsePlayer,
      asset: 'sounds/soft_pulse.wav',
      volume: _ready ? 0.34 : 0.24,
    ));
    _performHaptic(HapticFeedback.selectionClick);

    _echoBeatTimer?.cancel();
    _echoBeatTimer = Timer(_echoBeatDelay, () {
      if (!mounted || _navigated) return;
      unawaited(_playPulseBeat(
        player: _echoPulsePlayer,
        asset: 'sounds/pulse.wav',
        volume: _ready ? 0.74 : 0.52,
      ));
      _performHaptic(HapticFeedback.mediumImpact);
    });
  }

  Future<void> _playPulseBeat({
    required AudioPlayer player,
    required String asset,
    required double volume,
  }) async {
    if (!_soundEnabled) return;

    // Check if the audio file exists in assets before attempting to play.
    final assetPath = 'assets/$asset';
    final assetFile = io.File(assetPath);
    if (!assetFile.existsSync()) {
      debugPrint(
          '[SplashScreen] Audio asset not found: $assetPath, skipping playback');
      return;
    }

    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('[SplashScreen] Failed to play audio asset $asset: $e');
    }
  }

  void _performHaptic(Future<void> Function() feedback) {
    if (!_vibrationEnabled) return;
    unawaited(feedback());
  }

  Future<void> _playReadyCue() async {
    await _playPulseBeat(
      player: _readyChimePlayer,
      asset: 'sounds/soft_pop.wav',
      volume: 0.82,
    );
  }

  Future<void> _stopFeedbackRhythm() async {
    _pulseRhythmTimer?.cancel();
    _echoBeatTimer?.cancel();
    _pulseRhythmTimer = null;
    _echoBeatTimer = null;

    try {
      await _leadPulsePlayer.stop();
      await _echoPulsePlayer.stop();
      await _readyChimePlayer.stop();
    } catch (_) {
      // Stop best-effort only.
    }
  }

  @override
  void dispose() {
    unawaited(_stopFeedbackRhythm());
    _sceneController.dispose();
    _pulseController.dispose();
    _dropController.dispose();
    unawaited(_leadPulsePlayer.dispose());
    unawaited(_echoPulsePlayer.dispose());
    unawaited(_readyChimePlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = CurvedAnimation(
      parent: _sceneController,
      curve: Curves.easeInOut,
    );
    final titleOpacity = CurvedAnimation(
      parent: _sceneController,
      curve: const Interval(0.08, 0.36, curve: Curves.easeOutCubic),
    );
    final subtitleOpacity = CurvedAnimation(
      parent: _sceneController,
      curve: const Interval(0.24, 0.56, curve: Curves.easeOutCubic),
    );
    final footerOpacity = CurvedAnimation(
      parent: _sceneController,
      curve: const Interval(0.42, 0.82, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF04070D),
      body: AnimatedBuilder(
        animation: Listenable.merge(
          <Listenable>[_sceneController, _pulseController, _dropController],
        ),
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AuroraBackdropPainter(
                    scenePhase: scene.value,
                    pulsePhase: _pulseController.value,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridAndDropsPainter(
                    dropPhase: _dropController.value,
                    pulsePhase: _pulseController.value,
                    drops: _drops,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      FadeTransition(
                        opacity: titleOpacity,
                        child: _HeroBlock(
                          pulsePhase: _pulseController.value,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: subtitleOpacity,
                        child: _CaptionBlock(ready: _ready),
                      ),
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: footerOpacity,
                        child: _LoadingBlock(
                          ready: _ready,
                          pulsePhase: _pulseController.value,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.pulsePhase,
  });

  final double pulsePhase;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.92 + math.sin(pulsePhase * math.pi * 2) * 0.06;

    return Column(
      children: [
        Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 264,
            height: 264,
            child: CustomPaint(
              painter: _CorePulsePainter(pulsePhase: pulsePhase),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'НИЖНЕВАРТОВСК',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: PulseColors.accentGold,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.2,
            shadows: const [
              Shadow(color: Color(0x99FFB84D), blurRadius: 18),
              Shadow(color: Color(0x66FF8A00), blurRadius: 36),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x141F2D3D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x44E0A83D)),
          ),
          child: Text(
            'НЕФТЕГАЗОВАЯ СТОЛИЦА',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.86),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaptionBlock extends StatelessWidget {
  const _CaptionBlock({
    required this.ready,
  });

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.exo2(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            children: const [
              TextSpan(text: 'ПУЛЬС ГОРОДА '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: PulseColors.accentGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'МОНИТОРИНГ ИНФРАСТРУКТУРЫ',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFFB6C7D9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            ready
                ? 'Северный контур синхронизирован. Городская карта, сигналы и индустриальные потоки готовы к работе.'
                : 'Запускаем северный индустриальный контур: aurora-слой, пульс города, карту событий и мониторинг жизненно важной инфраструктуры.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: const Color(0xFFD8E4EE).withOpacity(0.84),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.ready,
    required this.pulsePhase,
  });

  final bool ready;
  final double pulsePhase;

  @override
  Widget build(BuildContext context) {
    final progress = ready ? 1.0 : (0.16 + pulsePhase * 0.84).clamp(0.0, 0.98);

    return Column(
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x14111B28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x33FFB84D)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ready ? 'СТАТУС СИСТЕМЫ' : 'ЗАГРУЗКА КОНТУРА',
                    style: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFFE8EEF4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                    ),
                  ),
                  Text(
                    ready ? '100%' : '${(progress * 100).round()}%',
                    style: GoogleFonts.jetBrainsMono(
                      color: PulseColors.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0x22192A3D),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    PulseColors.accentGold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                child: Text(
                  ready
                      ? 'ГОТОВО К РАБОТЕ'
                      : 'СИНХРОНИЗАЦИЯ СЕВЕРНОГО МОНИТОРИНГА',
                  key: ValueKey<bool>(ready),
                  style: GoogleFonts.exo2(
                    color: ready
                        ? const Color(0xFFFFD67A)
                        : const Color(0xFFB5C7D7),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v$_appVersion',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF7A8FA3).withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CorePulsePainter extends CustomPainter {
  const _CorePulsePainter({
    required this.pulsePhase,
  });

  final double pulsePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = 0.5 + 0.5 * math.sin(pulsePhase * math.pi * 2);

    final outerGlow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width * 0.42,
        [
          const Color(0x66FFB84D),
          const Color(0x24C6861A),
          Colors.transparent,
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, size.width * 0.42, outerGlow);

    for (var i = 0; i < 3; i++) {
      final localPhase = ((pulsePhase + i * 0.18) % 1.0);
      final radius = 64 + localPhase * 58;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 2.6 : 1.6
        ..color = const Color(0xAAFFB84D).withOpacity((1 - localPhase) * 0.42);
      canvas.drawCircle(center, radius, ringPaint);
    }

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x66F4C36B);
    canvas.drawCircle(center, 94, framePaint);
    canvas.drawCircle(center, 116, framePaint);

    final coreRect = Rect.fromCircle(center: center, radius: 60);
    final coreFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFD979),
          Color(0xFFF0A020),
          Color(0xFF8F5110),
        ],
      ).createShader(coreRect);
    canvas.drawCircle(center, 58, coreFill);

    final innerGlass = Paint()
      ..shader = ui.Gradient.radial(
        center.translate(-10, -12),
        52,
        [
          Colors.white.withOpacity(0.58),
          const Color(0x22FFE8B0),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, 49, innerGlass);

    final heartBeatPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF20150A).withOpacity(0.84);
    final path = Path()
      ..moveTo(center.dx - 26, center.dy + 2)
      ..lineTo(center.dx - 12, center.dy + 2)
      ..lineTo(center.dx - 4, center.dy - 14)
      ..lineTo(center.dx + 4, center.dy + 16)
      ..lineTo(center.dx + 13, center.dy - 4)
      ..lineTo(center.dx + 24, center.dy - 4);
    canvas.drawPath(path, heartBeatPaint);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_city_rounded.codePoint),
        style: TextStyle(
          color: const Color(0xFF26180A),
          fontSize: 22 + pulse * 2.4,
          fontFamily: Icons.location_city_rounded.fontFamily,
          package: Icons.location_city_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2 + 24),
    );
  }

  @override
  bool shouldRepaint(covariant _CorePulsePainter oldDelegate) {
    return oldDelegate.pulsePhase != pulsePhase;
  }
}

class _AuroraBackdropPainter extends CustomPainter {
  const _AuroraBackdropPainter({
    required this.scenePhase,
    required this.pulsePhase,
  });

  final double scenePhase;
  final double pulsePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF02050A),
          Color(0xFF05111D),
          Color(0xFF070C14),
          Color(0xFF020306),
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bg);

    final auroraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);

    void drawWave({
      required Color color,
      required double topBase,
      required double amplitude,
      required double frequency,
      required double speed,
      required double thickness,
    }) {
      final path = Path()..moveTo(0, size.height * topBase);
      for (double x = 0; x <= size.width + 24; x += 12) {
        final wave = math.sin((x / size.width) * math.pi * frequency +
            scenePhase * speed * math.pi * 2);
        final pulse = math.cos(
                (x / size.width) * math.pi * 1.5 + pulsePhase * math.pi * 2) *
            8;
        final y = size.height * topBase + wave * amplitude + pulse;
        path.lineTo(x, y);
      }
      final fill = Path.from(path)
        ..lineTo(size.width, size.height * topBase + thickness)
        ..lineTo(0, size.height * topBase + thickness)
        ..close();
      auroraPaint.color = color;
      canvas.drawPath(fill, auroraPaint);
    }

    drawWave(
      color: const Color(0x6636F7A7),
      topBase: 0.16,
      amplitude: 22,
      frequency: 2.4,
      speed: 0.32,
      thickness: 82,
    );
    drawWave(
      color: const Color(0x554ACDFF),
      topBase: 0.20,
      amplitude: 28,
      frequency: 2.0,
      speed: -0.28,
      thickness: 100,
    );
    drawWave(
      color: const Color(0x446D57FF),
      topBase: 0.13,
      amplitude: 18,
      frequency: 3.1,
      speed: 0.24,
      thickness: 74,
    );

    final stars = Paint()..color = Colors.white.withOpacity(0.18);
    for (var i = 0; i < 22; i++) {
      final dx = (size.width / 22) * i + ((i % 3) * 7.0);
      final dy =
          40 + (i % 6) * 18.0 + math.sin(scenePhase * math.pi * 2 + i) * 4;
      canvas.drawCircle(Offset(dx, dy), i.isEven ? 1.2 : 0.8, stars);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraBackdropPainter oldDelegate) {
    return oldDelegate.scenePhase != scenePhase ||
        oldDelegate.pulsePhase != pulsePhase;
  }
}

class _GridAndDropsPainter extends CustomPainter {
  const _GridAndDropsPainter({
    required this.dropPhase,
    required this.pulsePhase,
    required this.drops,
  });

  final double dropPhase;
  final double pulsePhase;
  final List<_OilDrop> drops;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x35E0A83D)
      ..strokeWidth = 1;
    final pointPaint = Paint()..color = const Color(0x55FFCF70);

    for (double x = 24; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 24; x < size.width; x += 68) {
      for (double y = 24; y < size.height; y += 68) {
        canvas.drawCircle(Offset(x, y), 1.8, pointPaint);
      }
    }

    final cornerPaint = Paint()
      ..color = const Color(0x99F1B95A)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    _drawCorner(canvas, const Offset(16, 16), 36, true, true, cornerPaint);
    _drawCorner(
      canvas,
      Offset(size.width - 16, 16),
      36,
      false,
      true,
      cornerPaint,
    );
    _drawCorner(
      canvas,
      Offset(16, size.height - 16),
      36,
      true,
      false,
      cornerPaint,
    );
    _drawCorner(
      canvas,
      Offset(size.width - 16, size.height - 16),
      36,
      false,
      false,
      cornerPaint,
    );

    for (final drop in drops) {
      final local = ((dropPhase * drop.speed) + drop.delay) % 1.0;
      final y = -40 + local * (size.height + 80);
      final x = size.width * drop.xFactor +
          math.sin((local + pulsePhase) * math.pi * 2) * 8;
      final scale = drop.scale;
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x - 10 * scale,
          y + 14 * scale,
          x - 7 * scale,
          y + 28 * scale,
        )
        ..arcToPoint(
          Offset(x + 7 * scale, y + 28 * scale),
          radius: Radius.circular(12 * scale),
          clockwise: false,
        )
        ..quadraticBezierTo(
          x + 10 * scale,
          y + 14 * scale,
          x,
          y,
        );

      final dropFill = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x, y + 28 * scale),
          const [
            Color(0xEE1A120D),
            Color(0xEE0B0907),
            Color(0xCC3C2614),
          ],
        );
      canvas.drawPath(path, dropFill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x44FFB84D),
      );
    }
  }

  void _drawCorner(
    Canvas canvas,
    Offset anchor,
    double length,
    bool left,
    bool top,
    Paint paint,
  ) {
    final horizontalEnd = Offset(
      anchor.dx + (left ? length : -length),
      anchor.dy,
    );
    final verticalEnd = Offset(
      anchor.dx,
      anchor.dy + (top ? length : -length),
    );
    canvas.drawLine(anchor, horizontalEnd, paint);
    canvas.drawLine(anchor, verticalEnd, paint);
    canvas.drawCircle(anchor, 3.6, Paint()..color = const Color(0xCCFFCF70));
  }

  @override
  bool shouldRepaint(covariant _GridAndDropsPainter oldDelegate) {
    return oldDelegate.dropPhase != dropPhase ||
        oldDelegate.pulsePhase != pulsePhase;
  }
}

class _OilDrop {
  const _OilDrop({
    required this.xFactor,
    required this.delay,
    required this.scale,
    required this.speed,
  });

  final double xFactor;
  final double delay;
  final double scale;
  final double speed;
}

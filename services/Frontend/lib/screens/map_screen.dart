import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter/services.dart';

import '../config/mcp_config.dart';
import '../map/map_config.dart'
    show kMapCenterDefault, kOsmAttributionText, kOsmCopyrightUrl, MapConfig;
import '../services/mcp_service.dart';
import '../theme/pulse_colors.dart';
import 'complaint_form_screen.dart';
import 'infographic_screen.dart';
import 'about_screen.dart';
import '../widgets/city_pulse_wave.dart';
import '../services/sound_service.dart';
import 'cesium_map_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// Р вЂњР В»Р В°Р Р†Р Р…РЎвЂ№Р в„– РЎРЊР С”РЎР‚Р В°Р Р… Р С”Р В°РЎР‚РЎвЂљРЎвЂ№ РІР‚вЂќ Р С•РЎвЂљР С•Р В±РЎР‚Р В°Р В¶Р В°Р ВµРЎвЂљ Р В¶Р В°Р В»Р С•Р В±РЎвЂ№ Р Р…Р В° Р С”Р В°РЎР‚РЎвЂљР Вµ Р СњР С‘Р В¶Р Р…Р ВµР Р†Р В°РЎР‚РЎвЂљР С•Р Р†РЎРѓР С”Р В°
/// РЎРѓ РЎР‚Р ВµР В°Р В»-РЎвЂљР В°Р в„–Р С Р С•Р В±Р Р…Р С•Р Р†Р В»Р ВµР Р…Р С‘РЎРЏР СР С‘ Р С‘ РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р В°РЎвЂ Р С‘Р ВµР в„– Р С—Р С• РЎРѓРЎвЂљР В°РЎвЂљРЎС“РЎРѓР В°Р С/Р С”Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘РЎРЏР С.
class _NeoGlassPanel extends StatelessWidget {
  const _NeoGlassPanel({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding = const EdgeInsets.all(16),
    this.fillColor = const Color(0xCC151C2F),
    this.blurSigma = 20,
    this.borderColors,
    this.boxShadow,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color fillColor;
  final double blurSigma;
  final List<Color>? borderColors;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final colors = borderColors ??
        [
          const Color(0xFF00E5FF).withAlpha(200),
          const Color(0x6600E5FF),
          Colors.transparent,
        ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: borderRadius,
              ),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMapMarker extends StatelessWidget {
  const _AnimatedMapMarker({
    required this.animation,
    required this.color,
    required this.icon,
    required this.size,
    required this.seed,
    required this.isDayMode,
  });

  final Animation<double> animation;
  final Color color;
  final IconData icon;
  final double size;
  final double seed;
  final bool isDayMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = (animation.value + seed) % 1.0;
        final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
        final ringScale = 1 + wave * 0.38;
        final glowOpacity = isDayMode ? 0.10 + wave * 0.08 : 0.24 + wave * 0.24;
        final coreScale = 0.97 + wave * 0.06;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: size * 0.88,
                  height: size * 0.88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha((glowOpacity * 110).round()),
                    border: Border.all(
                      color: color.withAlpha(
                        (glowOpacity * (isDayMode ? 120 : 180)).round(),
                      ),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(
                          (glowOpacity * (isDayMode ? 140 : 190)).round(),
                        ),
                        blurRadius: isDayMode ? 9 : 20,
                        spreadRadius: isDayMode ? 1 : 3,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.scale(
                scale: coreScale,
                child: Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withAlpha(isDayMode ? 226 : 255),
                        color.withAlpha(isDayMode ? 144 : 210),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(isDayMode ? 190 : 245),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDayMode ? 22 : 80),
                        blurRadius: isDayMode ? 8 : 10,
                        spreadRadius: isDayMode ? 0 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isDayMode ? const Color(0xFF04243C) : Colors.white,
                    size: size * 0.34,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р С™Р С•Р Р…РЎвЂљРЎР‚Р С•Р В»Р В»Р ВµРЎР‚РЎвЂ№ Р С‘ РЎРѓР ВµРЎР‚Р Р†Р С‘РЎРѓРЎвЂ№ РІвЂќР‚РІвЂќР‚РІвЂќР‚
  final MapController _mapController = MapController();
  final MCPService _mcpService = MCPService();

  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р РЋР С•РЎРѓРЎвЂљР С•РЎРЏР Р…Р С‘Р Вµ РІвЂќР‚РІвЂќР‚РІвЂќР‚
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _showCamerasLayer = false;
  List<Marker> _cameraMarkers = [];
  int _totalComplaints = 0;
  int _newComplaints = 0;
  int _resolvedComplaints = 0;
  Timer? _updateTimer;
  String? _selectedCategory;
  int? _selectedDaysFilter;
  List<Map<String, dynamic>> _allComplaints = [];
  bool _isSatellite = false;
  final Map<String, int> _categoryCounts = {};
  final List<String> _markerCategories = [];
  late final AnimationController _fabPulseController;
  late final AnimationController _markerPulseController;
  Timer? _mapMotionTimer;
  bool _isMapMoving = false;
  bool _isNightMode = true;

  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р РЋР С•РЎРѓРЎвЂљР С•РЎРЏР Р…Р С‘Р Вµ Р Т‘Р В»РЎРЏ Р В°Р Р†РЎвЂљР С•Р В·РЎС“Р СР В° РІвЂќР‚РІвЂќР‚РІвЂќР‚
  LatLng? _preZoomCenter;
  double? _preZoomLevel;
  Map<String, dynamic>? _focusedComplaint;

  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р С™Р С•Р Р…РЎРѓРЎвЂљР В°Р Р…РЎвЂљРЎвЂ№ РІвЂќР‚РІвЂќР‚РІвЂќР‚
  static const LatLng _center = kMapCenterDefault;
  static const Duration _updateInterval = Duration(seconds: 30);
  static const Duration _mapMotionCooldown = Duration(milliseconds: 750);
  static const Duration _markerPulseDuration = Duration(milliseconds: 3200);
  static const Duration _nizhnevartovskOffset = Duration(hours: 5);
  static const String _visualModePrefKey = 'map_visual_mode_is_night';

  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р В¦Р Р†Р ВµРЎвЂљР С•Р Р†Р В°РЎРЏ Р С—Р В°Р В»Р С‘РЎвЂљРЎР‚Р В° РІвЂќР‚РІвЂќР‚РІвЂќР‚
  static const Color _colorDanger = PulseColors.negative;
  static const Color _colorSuccess = PulseColors.success;
  static const Color _colorNeutral = PulseColors.neutral;
  static const Color _colorPrimary = PulseColors.primary;
  static const Color _colorAccent = PulseColors.primarySoft;
  static const Color _colorSurface = PulseColors.background;
  static const Color _colorBottomSheet = PulseColors.backgroundRaised;

  // РІвЂќР‚РІвЂќР‚РІвЂќР‚ Р С™Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘Р С‘ РІвЂќР‚РІвЂќР‚РІвЂќР‚
  static const List<(String, IconData, Color)> _categories = [
    ('Р вЂќР С•РЎР‚Р С•Р С–Р С‘', Icons.directions_car, _colorDanger),
    ('Р вЂ“Р С™Р Тђ', Icons.home, _colorPrimary),
    (
      'Р С›РЎРѓР Р†Р ВµРЎвЂ°Р ВµР Р…Р С‘Р Вµ',
      Icons.lightbulb,
      Color(0xFFf59e0b)
    ),
    (
      'Р СћРЎР‚Р В°Р Р…РЎРѓР С—Р С•РЎР‚РЎвЂљ',
      Icons.directions_bus,
      Color(0xFF3b82f6)
    ),
    ('Р В­Р С”Р С•Р В»Р С•Р С–Р С‘РЎРЏ', Icons.eco, _colorSuccess),
    (
      'Р вЂР ВµР В·Р С•Р С—Р В°РЎРѓР Р…Р С•РЎРѓРЎвЂљРЎРЉ',
      Icons.shield,
      Color(0xFF6366f1)
    ),
    (
      'Р РЋР Р…Р ВµР С–/Р СњР В°Р В»Р ВµР Т‘РЎРЉ',
      Icons.ac_unit,
      Color(0xFF38bdf8)
    ),
    (
      'Р СљР ВµР Т‘Р С‘РЎвЂ Р С‘Р Р…Р В°',
      Icons.local_hospital,
      Color(0xFFef4444)
    ),
    (
      'Р С›Р В±РЎР‚Р В°Р В·Р С•Р Р†Р В°Р Р…Р С‘Р Вµ',
      Icons.school,
      Color(0xFF818cf8)
    ),
    (
      'Р СџР В°РЎР‚Р С”Р С•Р Р†Р С”Р С‘',
      Icons.local_parking,
      Color(0xFF9ca3af)
    ),
    (
      'Р РЋРЎвЂљРЎР‚Р С•Р С‘РЎвЂљР ВµР В»РЎРЉРЎРѓРЎвЂљР Р†Р С•',
      Icons.architecture_rounded,
      Color(0xFFF59E0B)
    ),
    (
      'Р СљР ВµРЎР‚Р С•Р С—РЎР‚Р С‘РЎРЏРЎвЂљР С‘Р Вµ',
      Icons.event_available_rounded,
      Color(0xFFEAB308)
    ),
    ('Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ', Icons.report_problem, _colorNeutral),
  ];

  @override
  void initState() {
    super.initState();
    _isNightMode = _isCurrentlyNightInNizhnevartovsk();
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _markerPulseController = AnimationController(
      vsync: this,
      duration: _markerPulseDuration,
    )..repeat();
    MCPConfig.initializeMCPService();
    unawaited(_restoreVisualModePreference());
    _loadCameras();
    _loadComplaints();
    _startPeriodicUpdates();
  }

  Future<void> _loadCameras() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/cameras_nv.json');
      final data = jsonDecode(jsonStr) as List<dynamic>;
      final markers = <Marker>[];
      for (final item in data) {
        final lat = item['lat'];
        final lng = item['lng'];
        final name = item['n'] ?? 'Р С™Р В°Р СР ВµРЎР‚Р В°';
        final url = item['s'];
        final rawPeopleCount = item['peopleCount'] ?? item['people_count'];
        final peopleCount =
            rawPeopleCount is num ? rawPeopleCount.toInt() : null;
        final detectorEnabled = item['detectorEnabled'] == true ||
            item['detector_ready'] == true ||
            peopleCount != null;

        if (lat != null && lng != null) {
          final point =
              LatLng((lat as num).toDouble(), (lng as num).toDouble());
          markers.add(Marker(
            point: point,
            width: 52,
            height: 52,
            child: GestureDetector(
              onTap: () {
                _emitSelectionHaptic();
                _showLiveCamDialog(
                  name,
                  url,
                  peopleCount: peopleCount,
                  detectorEnabled: detectorEnabled,
                );
              },
              child: _AnimatedMapMarker(
                animation: _markerPulseController,
                color: _colorPrimary,
                icon: Icons.videocam_rounded,
                size: 52,
                seed: ((point.latitude + point.longitude).abs() % 1),
                isDayMode: !_isNightMode,
              ),
            ),
          ));
        }
      }
      if (mounted) setState(() => _cameraMarkers = markers);
    } catch (e) {
      debugPrint('Error loading cameras: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapMotionTimer?.cancel();
    _fabPulseController.dispose();
    _markerPulseController.dispose();
    _mcpService.disconnectAll();
    super.dispose();
  }

  void _emitSelectionHaptic() {
    HapticFeedback.selectionClick();
  }

  void _emitImpactHaptic() {
    HapticFeedback.lightImpact();
  }

  DateTime _nizhnevartovskNow() =>
      DateTime.now().toUtc().add(_nizhnevartovskOffset);

  bool _isCurrentlyNightInNizhnevartovsk() {
    final hour = _nizhnevartovskNow().hour;
    return hour < 7 || hour >= 19;
  }

  Color get _uiTextPrimary =>
      _isNightMode ? PulseColors.textPrimary : const Color(0xFF082233);

  Color get _uiTextSecondary =>
      _isNightMode ? PulseColors.textSecondary : const Color(0xFF3E6278);

  Color get _uiPanelFill => _isNightMode
      ? PulseColors.surface.withAlpha(170)
      : const Color(0xDDF6FBFF);

  Color get _uiPanelFillStrong => _isNightMode
      ? PulseColors.backgroundRaised.withAlpha(188)
      : const Color(0xEEFBFEFF);

  Color get _uiAccent => _isNightMode ? _colorAccent : const Color(0xFF00AAC4);

  Color get _uiPrimary =>
      _isNightMode ? _colorPrimary : const Color(0xFF00B6CE);

  Color get _uiGlow =>
      _isNightMode ? PulseColors.primary : const Color(0xFF00B4D0);

  List<Color> get _mapOverlayGradient => _isNightMode
      ? [
          const Color(0xDE020617),
          const Color(0xB0061527),
          const Color(0x800B2038),
        ]
      : [
          const Color(0x24F7FCFF),
          const Color(0x12DEF1FF),
          const Color(0x06FFFFFF),
        ];

  void _toggleVisualMode() {
    _emitSelectionHaptic();
    setState(() => _isNightMode = !_isNightMode);
    unawaited(_persistVisualModePreference());
  }

  Future<void> _restoreVisualModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_visualModePrefKey);
      if (saved == null || !mounted) {
        return;
      }
      setState(() => _isNightMode = saved);
    } catch (error) {
      debugPrint('Visual mode preference restore failed: $error');
    }
  }

  Future<void> _persistVisualModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_visualModePrefKey, _isNightMode);
    } catch (error) {
      debugPrint('Visual mode preference save failed: $error');
    }
  }

  void _registerMapMovement() {
    _mapMotionTimer?.cancel();
    if (!_isMapMoving && mounted) {
      setState(() => _isMapMoving = true);
    }
    _mapMotionTimer = Timer(_mapMotionCooldown, () {
      if (mounted && _isMapMoving) {
        setState(() => _isMapMoving = false);
      }
    });
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Р вЂ”Р В°Р С–РЎР‚РЎС“Р В·Р С”Р В° Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      if (mounted) _loadComplaints();
    });
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final complaints = await _fetchComplaints();

      if (complaints.isNotEmpty) {
        final combined = [...complaints];

        // Find if there are actually any *newly added* complaints since last load.
        final existingIds = _allComplaints.map((c) => c['id']).toSet();
        Map<String, dynamic>? freshComplaint;

        if (_allComplaints.isNotEmpty) {
          for (var c in complaints) {
            if (!existingIds.contains(c['id'])) {
              freshComplaint = c;
              break;
            }
          }
        }

        _allComplaints = combined;
        _processComplaints(_filterByDate(combined));

        // Auto zoom if found fresh
        if (freshComplaint != null) {
          final activeComplaint = freshComplaint;
          if (!mounted) return;
          _zoomToComplaint(activeComplaint);
          _showComplaintDetails(activeComplaint);

          // Play category specific sound
          SoundService().playCategorySound(
              activeComplaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ');

          // Show in-app notification
          NotificationService().showNewComplaintNotification(
            context,
            title: activeComplaint['title'] ??
                'Р СњР С•Р Р†Р В°РЎРЏ Р В¶Р В°Р В»Р С•Р В±Р В°',
            category:
                activeComplaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ',
            color: _getCategoryColor(
                activeComplaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ'),
          );

          // Show system push notification
          NotificationService().showPushNotification(
            id: activeComplaint['id'] is int
                ? activeComplaint['id']
                : math.Random().nextInt(1000000),
            title:
                'Р СњР С•Р Р†Р В°РЎРЏ Р В¶Р В°Р В»Р С•Р В±Р В°: ${activeComplaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ'}',
            body: activeComplaint['title'] ??
                'Р СњР В°Р В¶Р СР С‘РЎвЂљР Вµ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р С—Р С•РЎРѓР СР С•РЎвЂљРЎР‚Р ВµРЎвЂљРЎРЉ Р С—Р С•Р Т‘РЎР‚Р С•Р В±Р Р…Р С•РЎРѓРЎвЂљР С‘',
            category: activeComplaint['category'],
          );

          // Auto return to overview in 10 secs
          Timer(const Duration(seconds: 10), () {
            if (mounted &&
                _focusedComplaint != null &&
                _focusedComplaint!['id'] == activeComplaint['id']) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context); // close bottomsheet
              }
              _zoomBack();
            }
          });
        }
      } else {
        debugPrint(
            'Р вЂќР В°Р Р…Р Р…РЎвЂ№Р Вµ Р Р…Р Вµ Р С—Р С•Р В»РЎС“РЎвЂЎР ВµР Р…РЎвЂ№, Р С—РЎС“РЎРѓРЎвЂљР С•Р в„– РЎРѓР С—Р С‘РЎРѓР С•Р С” Р В¶Р В°Р В»Р С•Р В±');
        if (!mounted) return;
        setState(() {
          _allComplaints = [];
          _markers = [];
          _markerCategories.clear();
          _totalComplaints = 0;
          _newComplaints = 0;
          _resolvedComplaints = 0;
          _categoryCounts.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Р СњР ВµРЎвЂљ Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦, Р С—РЎР‚Р С•Р Р†Р ВµРЎР‚РЎРЉРЎвЂљР Вµ РЎРѓР С•Р ВµР Т‘Р С‘Р Р…Р ВµР Р…Р С‘Р Вµ')),
        );
      }
    } catch (e) {
      debugPrint(
          'Р С™РЎР‚Р С‘РЎвЂљР С‘РЎвЂЎР ВµРЎРѓР С”Р В°РЎРЏ Р С•РЎв‚¬Р С‘Р В±Р С”Р В° Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘ Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦: $e');
      if (!mounted) return;
      setState(() {
        _allComplaints = [];
        _markers = [];
        _markerCategories.clear();
        _totalComplaints = 0;
        _newComplaints = 0;
        _resolvedComplaints = 0;
        _categoryCounts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘ Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦, Р С—РЎР‚Р С•Р Р†Р ВµРЎР‚РЎРЉРЎвЂљР Вµ РЎРѓР С•Р ВµР Т‘Р С‘Р Р…Р ВµР Р…Р С‘Р Вµ')),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  final Duration _fetchTimeout = const Duration(seconds: 20);
  final int _fetchRetries = 2;

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    final apiUrl = '${MapConfig.reportsRestUrl}?select=*';
    final supabaseKey = MapConfig.supabaseAnonKey;

    for (var attempt = 0; attempt < _fetchRetries; attempt++) {
      try {
        final res = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
          },
        ).timeout(_fetchTimeout);

        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          final complaints = data.cast<Map<String, dynamic>>();

          if (complaints.isNotEmpty) {
            debugPrint(
                'Р СџР С•Р В»РЎС“РЎвЂЎР ВµР Р…Р С• Р В¶Р В°Р В»Р С•Р В± Р С‘Р В· API: ${complaints.length}');
            return complaints;
          }
        }
      } catch (e) {
        debugPrint('Fetch attempt ${attempt + 1}/$_fetchRetries failed: $e');
      }
    }

    return [];
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Р С›Р В±РЎР‚Р В°Р В±Р С•РЎвЂљР С”Р В° Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> data) {
    if (_selectedDaysFilter == null) return data;

    // Р РЋР С—Р ВµРЎвЂ Р С‘Р В°Р В»РЎРЉР Р…РЎвЂ№Р в„– РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚ "Р СњР С•Р Р†РЎвЂ№Р Вµ" (-1) - Р В¶Р В°Р В»Р С•Р В±РЎвЂ№ Р Т‘Р С• 3 РЎвЂЎР В°РЎРѓР С•Р Р†
    if (_selectedDaysFilter == -1) {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      return data.where((item) {
        final dt = _parseDateTime(item);
        return (dt != null && dt.isAfter(threeHoursAgo));
      }).toList();
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedDaysFilter!));

    return data.where((item) {
      final dt = _parseDateTime(item);
      if (dt == null) return true;
      return dt.isAfter(cutoff);
    }).toList();
  }

  DateTime? _parseDateTime(Map<String, dynamic> item) {
    final raw = item['created_at'] ?? item['createdAt'] ?? item['timestamp'];
    if (raw == null) return null;

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return null;
  }

  void _processComplaints(List<dynamic> data) {
    if (data.length == 100 && data.isNotEmpty && data[0] == 'mock') {
      if (!mounted) return;
      setState(() {
        _markers = [];
        _markerCategories.clear();
        _totalComplaints = 0;
        _newComplaints = 0;
        _resolvedComplaints = 0;
        _categoryCounts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data, check net')),
      );
      return;
    }

    int total = data.length;
    int newCount = 0;
    int resolvedCount = 0;
    final markers = <Marker>[];

    final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));

    for (final item in data) {
      final lat = item['lat'] ?? item['latitude'];
      final lng = item['lng'] ?? item['longitude'];
      if (lat == null || lng == null) continue;

      final status = (item['status'] ?? 'open') as String;
      final dt = _parseDateTime(item);

      // Р вЂ“Р В°Р В»Р С•Р В±Р В° РЎРѓРЎвЂЎР С‘РЎвЂљР В°Р ВµРЎвЂљРЎРѓРЎРЏ Р Р…Р С•Р Р†Р С•Р в„–, Р ВµРЎРѓР В»Р С‘ Р С•Р Р…Р В° РЎРѓР С•Р В·Р Т‘Р В°Р Р…Р В° Р СР ВµР Р…Р ВµР Вµ 3 РЎвЂЎР В°РЎРѓР С•Р Р† Р Р…Р В°Р В·Р В°Р Т‘
      final isNew = dt != null && dt.isAfter(threeHoursAgo);

      if (isNew) newCount++;
      if (status == 'resolved') resolvedCount++;

      try {
        final category =
            (item['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ') as String;
        markers.add(_buildMarker(
          point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          status: status,
          category: category,
          complaint: item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item),
        ));
      } catch (e) {
        debugPrint(
            'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р С•Р В±РЎР‚Р В°Р В±Р С•РЎвЂљР С”Р С‘ Р СР В°РЎР‚Р С”Р ВµРЎР‚Р В°: $e. Item: $item');
      }
    }

    final counts = <String, int>{};
    for (final item in data) {
      final cat = (item['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ') as String;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _markerCategories.clear();
      for (final item in data) {
        final lat = item['lat'] ?? item['latitude'];
        final lng = item['lng'] ?? item['longitude'];
        if (lat != null && lng != null) {
          _markerCategories
              .add((item['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ') as String);
        }
      }
      _totalComplaints = total;
      _newComplaints = newCount;
      _resolvedComplaints = resolvedCount;
      _categoryCounts
        ..clear()
        ..addAll(counts);
    });
  }

  List<Marker> get _filteredMarkers {
    if (_selectedCategory == null) return _markers;
    return [
      for (var i = 0; i < _markers.length; i++)
        if (i < _markerCategories.length &&
            _markerCategories[i] == _selectedCategory)
          _markers[i],
    ];
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Р С’Р Р…Р С‘Р СР В°РЎвЂ Р С‘РЎРЏ Р С”Р В°РЎР‚РЎвЂљРЎвЂ№
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  void _animateMapTo(LatLng center, double zoom) {
    const steps = 12;
    const duration = Duration(milliseconds: 380);
    final c = _mapController.camera;
    final startCenter = c.center;
    final startZoom = c.zoom;
    final endCenter = center;
    final endZoom = zoom;
    var step = 0;
    void tick() {
      step++;
      final t = step / steps;
      final eased = _curveCubic(t);
      _mapController.move(
        LatLng(
          startCenter.latitude +
              (endCenter.latitude - startCenter.latitude) * eased,
          startCenter.longitude +
              (endCenter.longitude - startCenter.longitude) * eased,
        ),
        startZoom + (endZoom - startZoom) * eased,
      );
      if (step < steps && mounted) {
        Future.delayed(
            Duration(milliseconds: duration.inMilliseconds ~/ steps), tick);
      }
    }

    tick();
  }

  double _curveCubic(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
  }

  /// Р вЂ”РЎС“Р С Р Р…Р В° Р С—РЎР‚Р С•Р В±Р В»Р ВµР СРЎС“ РЎРѓ РЎРѓР С•РЎвЂ¦РЎР‚Р В°Р Р…Р ВµР Р…Р С‘Р ВµР С Р С—РЎР‚Р ВµР Т‘РЎвЂ№Р Т‘РЎС“РЎвЂ°Р ВµР в„– Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р С‘
  void _zoomToComplaint(Map<String, dynamic> complaint) {
    final lat = complaint['lat'] ?? complaint['latitude'];
    final lng = complaint['lng'] ?? complaint['longitude'];
    if (lat == null || lng == null) return;

    // Р РЋР С•РЎвЂ¦РЎР‚Р В°Р Р…РЎРЏР ВµР С РЎвЂљР ВµР С”РЎС“РЎвЂ°РЎС“РЎР‹ Р С—Р С•Р В·Р С‘РЎвЂ Р С‘РЎР‹ Р Т‘Р В»РЎРЏ Р Р†Р С•Р В·Р Р†РЎР‚Р В°РЎвЂљР В°
    final camera = _mapController.camera;
    _preZoomCenter = camera.center;
    _preZoomLevel = camera.zoom;

    setState(() {
      _focusedComplaint = complaint;
    });

    // Р вЂ”РЎС“Р С Р Р…Р В° Р С—РЎР‚Р С•Р В±Р В»Р ВµР СРЎС“
    _animateMapTo(
      LatLng((lat as num).toDouble(), (lng as num).toDouble()),
      17.0,
    );
  }

  /// Р вЂ™Р С•Р В·Р Р†РЎР‚Р В°РЎвЂљ Р С” Р С—РЎР‚Р ВµР Т‘РЎвЂ№Р Т‘РЎС“РЎвЂ°Р ВµР в„– Р С—Р С•Р В·Р С‘РЎвЂ Р С‘Р С‘
  void _zoomBack() {
    if (_preZoomCenter != null && _preZoomLevel != null) {
      _animateMapTo(_preZoomCenter!, _preZoomLevel!);
    } else {
      _animateMapTo(_center, 13.0);
    }

    setState(() {
      _focusedComplaint = null;
      _preZoomCenter = null;
      _preZoomLevel = null;
    });
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Р вЂ™РЎвЂ№Р С—Р В°Р Т‘Р В°РЎР‹РЎвЂ°Р ВµР Вµ Р СР ВµР Р…РЎР‹ РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р В°РЎвЂ Р С‘Р С‘
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  Widget _buildCategoryDropdown() {
    final borderColor = _selectedCategory != null
        ? _uiAccent.withAlpha(_isNightMode ? 180 : 130)
        : _uiGlow.withAlpha(_isNightMode ? 120 : 80);

    return _NeoGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      fillColor: _uiPanelFill,
      blurSigma: 24,
      borderColors: [
        borderColor,
        borderColor.withAlpha(60),
        Colors.transparent,
      ],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(60),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedCategory,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _selectedCategory != null ? _uiAccent : _uiTextSecondary,
                size: 22,
              ),
              dropdownColor:
                  _isNightMode ? _colorSurface : const Color(0xFFF7FCFF),
              borderRadius: BorderRadius.circular(12),
              hint: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      color: _uiTextSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Р’СЃРµ РєР°С‚РµРіРѕСЂРёРё',
                    style: TextStyle(
                      color: _uiTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded,
                          color: _uiTextSecondary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Р’СЃРµ РєР°С‚РµРіРѕСЂРёРё',
                        style: TextStyle(
                          color: _uiTextPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_totalComplaints',
                        style: TextStyle(
                          color: _uiTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._categories.map((cat) {
                  final (name, icon, color) = cat;
                  final count = _categoryCounts[name] ?? 0;
                  return DropdownMenuItem<String?>(
                    value: name,
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color.withAlpha(40),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(icon, color: color, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: _uiTextPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                _emitSelectionHaptic();
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // UI Р СР В°РЎР‚Р С”Р ВµРЎР‚Р С•Р Р† Р С‘ popup'Р С•Р Р†
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Р вЂќР С•РЎР‚Р С•Р С–Р С‘':
        return Icons.add_road;
      case 'Р С›РЎРѓР Р†Р ВµРЎвЂ°Р ВµР Р…Р С‘Р Вµ':
        return Icons.lightbulb;
      case 'Р вЂ“Р С™Р Тђ':
        return Icons.home_repair_service;
      case 'Р СћРЎР‚Р В°Р Р…РЎРѓР С—Р С•РЎР‚РЎвЂљ':
        return Icons.directions_bus;
      case 'Р В­Р С”Р С•Р В»Р С•Р С–Р С‘РЎРЏ':
        return Icons.eco;
      case 'Р вЂР ВµР В·Р С•Р С—Р В°РЎРѓР Р…Р С•РЎРѓРЎвЂљРЎРЉ':
        return Icons.security;
      case 'Р РЋР Р…Р ВµР С–/Р СњР В°Р В»Р ВµР Т‘РЎРЉ':
        return Icons.ac_unit;
      case 'Р СљР ВµР Т‘Р С‘РЎвЂ Р С‘Р Р…Р В°':
      case 'Р вЂ”Р Т‘РЎР‚Р В°Р Р†Р С•Р С•РЎвЂ¦РЎР‚Р В°Р Р…Р ВµР Р…Р С‘Р Вµ':
        return Icons.local_hospital;
      case 'Р С›Р В±РЎР‚Р В°Р В·Р С•Р Р†Р В°Р Р…Р С‘Р Вµ':
        return Icons.school;
      case 'Р СџР В°РЎР‚Р С”Р С•Р Р†Р С”Р С‘':
        return Icons.local_parking;
      case 'Р вЂР В»Р В°Р С–Р С•РЎС“РЎРѓРЎвЂљРЎР‚Р С•Р в„–РЎРѓРЎвЂљР Р†Р С•':
        return Icons.park;
      case 'Р СљР ВµРЎР‚Р С•Р С—РЎР‚Р С‘РЎРЏРЎвЂљР С‘Р Вµ':
        return Icons.event_available_rounded;
      default:
        return Icons.help_outline;
    }
  }

  Color _getCategoryColor(String category) {
    for (final cat in _categories) {
      if (cat.$1 == category) return cat.$3;
    }
    return _colorNeutral;
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'open' || 'pending' => _colorDanger,
      'resolved' => _colorSuccess,
      _ => _colorNeutral,
    };
  }

  Marker _buildMarker({
    required LatLng point,
    required String status,
    required String category,
    required Map<String, dynamic> complaint,
  }) {
    final isCamera = category == 'Р С™Р В°Р СР ВµРЎР‚РЎвЂ№';
    final color =
        isCamera ? const Color(0xFF6366F1) : _getCategoryColor(category);
    final markerIcon =
        isCamera ? Icons.videocam_rounded : _getCategoryIcon(category);
    final seed =
        (((complaint['id'] ?? category.hashCode) as Object).hashCode.abs() %
                997) /
            997;

    return Marker(
      point: point,
      width: isCamera ? 58 : 54,
      height: isCamera ? 58 : 54,
      child: GestureDetector(
        onTap: () {
          _emitSelectionHaptic();
          _zoomToComplaint(complaint);
          if (category == 'Р С™Р В°Р СР ВµРЎР‚РЎвЂ№') {
            final streamUrl = MapConfig.cityCams[complaint['title']];
            _showLiveCamDialog(
                complaint['title'] ?? 'Р С™Р В°Р СР ВµРЎР‚Р В°', streamUrl);
          } else {
            _showComplaintDetails(complaint);
          }
        },
        child: _AnimatedMapMarker(
          animation: _markerPulseController,
          color: color,
          icon: markerIcon,
          size: isCamera ? 58 : 54,
          seed: seed,
          isDayMode: !_isNightMode,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    return switch (status) {
      'open' => 'Р СњР С•Р Р†Р В°РЎРЏ',
      'pending' => 'Р вЂ™ РЎР‚Р В°Р В±Р С•РЎвЂљР Вµ',
      'resolved' => 'Р В Р ВµРЎв‚¬Р ВµР Р…Р В°',
      _ => 'Р СњР ВµР С‘Р В·Р Р†Р ВµРЎРѓРЎвЂљР Р…Р С•',
    };
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Р СњР Вµ РЎС“Р С”Р В°Р В·Р В°Р Р…Р В°';
    DateTime? dt;
    if (raw is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      try {
        dt = DateTime.parse(raw);
      } catch (_) {
        return raw;
      }
    }
    if (dt == null) return 'Р СњР Вµ РЎС“Р С”Р В°Р В·Р В°Р Р…Р В°';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    final status = (complaint['status'] ?? 'open') as String;
    final statusColor = _getStatusColor(status);
    final category =
        (complaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ') as String;
    final categoryColor = _getCategoryColor(category);
    final dateRaw = complaint['created_at'] ??
        complaint['createdAt'] ??
        complaint['timestamp'];
    int likes = complaint['likes_count'] ?? 0;
    bool isLiked = complaint['_ui_isLiked'] == true;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (BuildContext contextInner, StateSetter setModalState) {
              final lat = complaint['lat'] ?? complaint['latitude'];
              final lng = complaint['lng'] ?? complaint['longitude'];
              final hasCoords = lat != null && lng != null;

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: _NeoGlassPanel(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  padding: EdgeInsets.zero,
                  fillColor: _colorBottomSheet.withAlpha(185),
                  blurSigma: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Р В РЎС“РЎвЂЎР С”Р В°
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(60),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Р вЂ”Р В°Р С–Р С•Р В»Р С•Р Р†Р С•Р С” + Р С”Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘РЎРЏ
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          categoryColor.withAlpha(60),
                                          categoryColor.withAlpha(25),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: categoryColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.toUpperCase(),
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Text(
                                          complaint['title'] as String? ??
                                              'Р СџРЎР‚Р С•Р В±Р В»Р ВµР СР В°',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              if (category == 'Р С™Р В°Р СР ВµРЎР‚РЎвЂ№') ...[
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(Icons.videocam_off_rounded,
                                          color: Colors.white24, size: 48),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('LIVE',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const Center(
                                        child: Text(
                                          'Р вЂ”Р С’Р вЂњР В Р Р€Р вЂ”Р С™Р С’ Р СџР С›Р СћР С›Р С™Р С’...',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                              letterSpacing: 2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Р РЋРЎвЂљР В°РЎвЂљРЎС“РЎРѓ + Р Т‘Р В°РЎвЂљР В°
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(40),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: statusColor.withAlpha(80),
                                          width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getStatusText(status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.schedule_rounded,
                                      color: Colors.white.withAlpha(120),
                                      size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(dateRaw),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Р С›Р С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ
                              if (complaint['description'] != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withAlpha(15),
                                        width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.description_outlined,
                                              color:
                                                  Colors.white.withAlpha(140),
                                              size: 15),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Р С›Р С—Р С‘РЎРѓР В°Р Р…Р С‘Р Вµ',
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withAlpha(140),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Builder(builder: (ctx) {
                                        final desc =
                                            complaint['description'] as String;
                                        if (desc.contains(
                                            'Р В¤Р С•РЎвЂљР С•: http')) {
                                          final parts =
                                              desc.split('Р В¤Р С•РЎвЂљР С•: ');
                                          final textPart = parts[0].trim();
                                          final urlPart = parts[1].trim();
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                textPart,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withAlpha(220),
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  urlPart,
                                                  width: double.infinity,
                                                  height: 180,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, err,
                                                          stack) =>
                                                      const Text(
                                                          'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘ РЎвЂћР С•РЎвЂљР С•',
                                                          style: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 12)),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Text(
                                            desc,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withAlpha(220),
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          );
                                        }
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Р С’Р Т‘РЎР‚Р ВµРЎРѓ
                              if (complaint['address'] != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _colorPrimary.withAlpha(15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _colorPrimary.withAlpha(30),
                                        width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          color: _colorPrimary, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          complaint['address'] as String,
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(210),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Р С™Р С•Р С•РЎР‚Р Т‘Р С‘Р Р…Р В°РЎвЂљРЎвЂ№ + Google Street View
                              if (hasCoords)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.gps_fixed_rounded,
                                          color: Colors.white.withAlpha(100),
                                          size: 15),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(100),
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: _colorPrimary.withAlpha(50),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  _colorPrimary.withAlpha(100)),
                                        ),
                                        child: IconButton(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          constraints: const BoxConstraints(
                                              minWidth: 40),
                                          icon: const Icon(
                                              Icons.streetview_rounded,
                                              size: 16,
                                              color: _colorAccent),
                                          tooltip:
                                              'Р РЋР СР С•РЎвЂљРЎР‚Р ВµРЎвЂљРЎРЉ Р Р† Google Street View',
                                          onPressed: () async {
                                            final url =
                                                'google.streetview:cbll=$lat,$lng';
                                            final fallbackUrl =
                                                'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
                                            try {
                                              if (await canLaunchUrl(
                                                  Uri.parse(url))) {
                                                await launchUrl(Uri.parse(url));
                                              } else {
                                                await launchUrl(
                                                    Uri.parse(fallbackUrl));
                                              }
                                            } catch (_) {
                                              await launchUrl(
                                                  Uri.parse(fallbackUrl));
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Р В Р ВµР В°Р С”РЎвЂ Р С‘Р С‘ Р С‘ Р СњР В°Р С—Р С•Р СР С‘Р Р…Р В°Р Р…Р С‘РЎРЏ
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (category ==
                                      'Р СљР ВµРЎР‚Р С•Р С—РЎР‚Р С‘РЎРЏРЎвЂљР С‘Р Вµ')
                                    PopupMenuButton<Duration>(
                                      color: _colorSurface,
                                      onSelected: (Duration offset) {
                                        final dateStr =
                                            complaint['created_at'] ??
                                                complaint['createdAt'] ??
                                                complaint['timestamp'];
                                        DateTime? scheduledDate;
                                        if (dateStr is String) {
                                          scheduledDate =
                                              DateTime.tryParse(dateStr);
                                        }
                                        if (dateStr is int) {
                                          scheduledDate = DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  dateStr);
                                        }

                                        if (scheduledDate != null) {
                                          final reminderTime =
                                              scheduledDate.subtract(offset);
                                          NotificationService()
                                              .scheduleReminder(
                                            id: complaint['id']?.hashCode ?? 0,
                                            title:
                                                'Р РЋР С•Р В±РЎвЂ№РЎвЂљР С‘Р Вµ: ${complaint['title']}',
                                            body:
                                                'Р РЋР С•Р В±РЎвЂ№РЎвЂљР С‘Р Вµ Р Р…Р В°РЎвЂЎР Р…Р ВµРЎвЂљРЎРѓРЎРЏ РЎвЂЎР ВµРЎР‚Р ВµР В· ${offset.inMinutes >= 60 ? '${offset.inHours} РЎвЂЎ.' : '${offset.inMinutes} Р СР С‘Р Р….'}!',
                                            scheduledDate: reminderTime,
                                          );
                                          ScaffoldMessenger.of(contextInner)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Р СњР В°Р С—Р С•Р СР С‘Р Р…Р В°Р Р…Р С‘Р Вµ РЎС“РЎРѓРЎвЂљР В°Р Р…Р С•Р Р†Р В»Р ВµР Р…Р С•!')),
                                          );
                                        }
                                      },
                                      itemBuilder: (contextInner) => [
                                        const PopupMenuItem(
                                            value: Duration(minutes: 30),
                                            child: Text(
                                                'Р вЂ”Р В° 30 Р СР С‘Р Р…',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        const PopupMenuItem(
                                            value: Duration(hours: 2),
                                            child: Text(
                                                'Р вЂ”Р В° 2 РЎвЂЎР В°РЎРѓР В°',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        const PopupMenuItem(
                                            value: Duration(days: 1),
                                            child: Text(
                                                'Р вЂ”Р В° Р Т‘Р ВµР Р…РЎРЉ',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons
                                                    .notifications_active_rounded,
                                                color: categoryColor,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                                'Р СњР В°Р С—Р С•Р СР Р…Р С‘РЎвЂљРЎРЉ',
                                                style: TextStyle(
                                                    color: Colors.white
                                                        .withAlpha(200))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (category !=
                                          'Р СљР ВµРЎР‚Р С•Р С—РЎР‚Р С‘РЎРЏРЎвЂљР С‘Р Вµ' &&
                                      category != 'Р С™Р В°Р СР ВµРЎР‚РЎвЂ№')
                                    GestureDetector(
                                      onTap: () async {
                                        setModalState(() {
                                          isLiked = !isLiked;
                                          complaint['_ui_isLiked'] = isLiked;
                                          likes += isLiked ? 1 : -1;
                                          complaint['likes_count'] = likes;
                                        });
                                        // Р С›РЎвЂљР С—РЎР‚Р В°Р Р†Р С”Р В° Р В»Р В°Р в„–Р С”Р В° Р Р† Supabase
                                        try {
                                          final id = complaint['id'];
                                          if (id != null) {
                                            await http.patch(
                                              Uri.parse(
                                                '${MapConfig.reportsRestUrl}?id=eq.$id',
                                              ),
                                              headers: {
                                                'Content-Type':
                                                    'application/json',
                                                'apikey':
                                                    MapConfig.supabaseAnonKey,
                                                'Authorization':
                                                    'Bearer ${MapConfig.supabaseAnonKey}',
                                              },
                                              body: jsonEncode(
                                                  {'likes_count': likes}),
                                            );
                                          }
                                        } catch (e) {
                                          debugPrint(
                                              'Error updating likes: $e');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isLiked
                                              ? Colors.red.withAlpha(40)
                                              : Colors.white.withAlpha(15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isLiked
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: isLiked
                                                  ? Colors.red
                                                  : Colors.white.withAlpha(150),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Р Р€ Р СР ВµР Р…РЎРЏ РЎвЂљР В°Р С”Р В°РЎРЏ Р В¶Р Вµ ($likes)',
                                              style: TextStyle(
                                                color: isLiked
                                                    ? Colors.redAccent
                                                    : Colors.white
                                                        .withAlpha(200),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Р С™Р Р…Р С•Р С—Р С”Р В° Р’В«Р вЂ™Р ВµРЎР‚Р Р…РЎС“РЎвЂљРЎРЉРЎРѓРЎРЏР’В»
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _zoomBack();
                                  },
                                  icon: const Icon(Icons.zoom_out_map_rounded,
                                      size: 18),
                                  label: const Text(
                                      'Р вЂ™Р ВµРЎР‚Р Р…РЎС“РЎвЂљРЎРЉРЎРѓРЎРЏ Р С” Р С•Р В±Р В·Р С•РЎР‚РЎС“'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _colorPrimary.withAlpha(40),
                                    foregroundColor: _colorAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: _colorPrimary.withAlpha(80)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).whenComplete(() {
      // When bottom sheet is dismissed by swipe, also zoom back
      if (_focusedComplaint != null) {
        _zoomBack();
      }
    });
  }

  void _showLiveCamDialog(
    String title,
    String? url, {
    int? peopleCount,
    bool detectorEnabled = false,
  }) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Р РЋРЎРѓРЎвЂ№Р В»Р С”Р В° Р Р…Р В° РЎвЂљРЎР‚Р В°Р Р…РЎРѓР В»РЎРЏРЎвЂ Р С‘РЎР‹ Р Р…Р Вµ Р Р…Р В°Р в„–Р Т‘Р ВµР Р…Р В°')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _LiveCamDialog(
        title: title,
        url: url,
        peopleCount: peopleCount,
        detectorEnabled: detectorEnabled,
      ),
    );
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Р ВР Р…РЎвЂћР С•РЎР‚Р СР В°РЎвЂ Р С‘Р С•Р Р…Р Р…Р В°РЎРЏ Р С”Р В°РЎР‚РЎвЂљР С•РЎвЂЎР С”Р В° Р Р…Р В° Р С”Р В°РЎР‚РЎвЂљР Вµ (overlay)
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  Widget _buildFocusedOverlay() {
    if (_focusedComplaint == null) return const SizedBox.shrink();

    final complaint = _focusedComplaint!;
    final status = (complaint['status'] ?? 'open') as String;
    final statusColor = _getStatusColor(status);
    final category =
        (complaint['category'] ?? 'Р СџРЎР‚Р С•РЎвЂЎР ВµР Вµ') as String;
    final categoryColor = _getCategoryColor(category);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: _NeoGlassPanel(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(14),
          fillColor: _uiPanelFillStrong,
          blurSigma: 24,
          borderColors: [
            categoryColor.withAlpha(190),
            _uiGlow.withAlpha(110),
            Colors.transparent,
          ],
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(category),
                    color: categoryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      complaint['title'] as String? ??
                          'Р вЂР ВµР В· Р Р…Р В°Р В·Р Р†Р В°Р Р…Р С‘РЎРЏ',
                      style: TextStyle(
                        color: _uiTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_getStatusText(status)} Р’В· $category',
                          style: TextStyle(
                            color: _uiTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _emitSelectionHaptic();
                  _zoomBack();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _uiPrimary.withAlpha(_isNightMode ? 50 : 28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: _uiTextSecondary, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’
  // Build
  // РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’РІвЂўС’

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Р С™Р В°РЎР‚РЎвЂљР В° (Р В±Р ВµРЎРѓР С—Р В»Р В°РЎвЂљР Р…Р В°РЎРЏ Р С—Р С•Р Т‘Р В»Р С•Р В¶Р С”Р В° OSM)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: MapConfig.initialZoom,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) {
                  _registerMapMovement();
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    _isSatellite ? MapConfig.satelliteUrl : MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgent,
                maxNativeZoom: 19,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _filteredMarkers,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: _uiPrimary.withAlpha(_isNightMode ? 215 : 172),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isNightMode
                              ? Colors.white
                              : const Color(0xFF0F2742),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _uiGlow.withAlpha(_isNightMode ? 110 : 40),
                            blurRadius: _isNightMode ? 10 : 5,
                            spreadRadius: _isNightMode ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: TextStyle(
                            color: _isNightMode
                                ? Colors.white
                                : const Color(0xFF0F2742),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_showCamerasLayer) MarkerLayer(markers: _cameraMarkers),
              // Р СљР В°РЎРѓРЎв‚¬РЎвЂљР В°Р В±Р Р…Р В°РЎРЏ Р В»Р С‘Р Р…Р ВµР в„–Р С”Р В°
              Scalebar(
                alignment: Alignment.bottomLeft,
                textStyle: TextStyle(
                  color: _isNightMode
                      ? Colors.white.withAlpha(230)
                      : const Color(0xFF10314D),
                  fontSize: 12,
                ),
                lineColor: _isNightMode
                    ? Colors.white.withAlpha(200)
                    : const Color(0xFF2563EB).withAlpha(180),
              ),
              // Р С’РЎвЂљРЎР‚Р С‘Р В±РЎС“РЎвЂ Р С‘РЎРЏ OSM
              SimpleAttributionWidget(
                source: Text(
                  kOsmAttributionText,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isNightMode
                        ? Colors.white.withAlpha(190)
                        : const Color(0xFF173654),
                  ),
                ),
                alignment: Alignment.bottomRight,
                onTap: () => launchUrl(Uri.parse(kOsmCopyrightUrl)),
              ),
            ],
          ),

          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _mapOverlayGradient,
                ),
              ),
            ),
          ),

          // Р ВР Р…Р Т‘Р С‘Р С”Р В°РЎвЂљР С•РЎР‚ Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: CircularProgressIndicator(color: _colorPrimary),
              ),
            ),

          // Р вЂ™Р ВµРЎР‚РЎвЂ¦Р Р…РЎРЏРЎРЏ Р С—Р В°Р Р…Р ВµР В»РЎРЉ РЎРѓ Р В·Р В°Р С–Р С•Р В»Р С•Р Р†Р С”Р С•Р С Р С‘ РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р В°Р СР С‘
          Positioned(
            top: paddingTop + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 10),
                _buildFiltersIsland(),
                const SizedBox(height: 10),
                _buildCategoryDropdown(),
              ],
            ),
          ),

          // Р ВР С”Р С•Р Р…Р С”Р В° РЎРѓРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”Р С‘
          Positioned(
            top: paddingTop + 140,
            right: 16,
            child: Tooltip(
              message: 'Р РЋРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”Р В°',
              child: _buildControlButton(
                icon: Icons.analytics_rounded,
                onTap: _showStatsDialog,
              ),
            ),
          ),

          // Р ВР С”Р С•Р Р…Р С”Р В° РЎРѓР С—Р С‘РЎРѓР С”Р В° Р Р€Р С™
          Positioned(
            top: paddingTop + 200,
            right: 16,
            child: Tooltip(
              message:
                  'Р Р€Р С—РЎР‚Р В°Р Р†Р В»РЎРЏРЎР‹РЎвЂ°Р С‘Р Вµ Р С”Р С•Р СР С—Р В°Р Р…Р С‘Р С‘',
              child: _buildControlButton(
                icon: Icons.business_rounded,
                onTap: _showUkDialog,
              ),
            ),
          ),

          // Р ВР С”Р С•Р Р…Р С”Р В° Р С”Р В°Р СР ВµРЎР‚ (Р Р†Р Р†Р ВµРЎР‚РЎвЂ¦РЎС“)
          Positioned(
            top: paddingTop + 260,
            right: 16,
            child: Tooltip(
              message: 'Р С™Р В°Р СР ВµРЎР‚РЎвЂ№ Р С–Р С•РЎР‚Р С•Р Т‘Р В°',
              child: _buildControlButton(
                icon: _showCamerasLayer ? Icons.videocam : Icons.videocam_off,
                onTap: () =>
                    setState(() => _showCamerasLayer = !_showCamerasLayer),
              ),
            ),
          ),

          // Р ВР С”Р С•Р Р…Р С”Р В° Р С‘Р Р…РЎвЂћР С•Р С–РЎР‚Р В°РЎвЂћР С‘Р С”Р С‘ (Р Р†Р Р†Р ВµРЎР‚РЎвЂ¦РЎС“)
          Positioned(
            top: paddingTop + 320,
            right: 16,
            child: Tooltip(
              message: 'Р ВР Р…РЎвЂћР С•Р С–РЎР‚Р В°РЎвЂћР С‘Р С”Р В°',
              child: _buildControlButton(
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InfographicScreen()),
                ),
              ),
            ),
          ),

          // Р С™Р Р…Р С•Р С—Р С”Р С‘ РЎС“Р С—РЎР‚Р В°Р Р†Р В»Р ВµР Р…Р С‘РЎРЏ
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                // Р С™Р Р…Р С•Р С—Р С”Р В° Р Р†Р С•Р В·Р Р†РЎР‚Р В°РЎвЂљР В° (Р Р†Р С‘Р Т‘Р С‘Р СР В° РЎвЂљР С•Р В»РЎРЉР С”Р С• Р С—РЎР‚Р С‘ РЎвЂћР С•Р С”РЎС“РЎРѓР Вµ)
                if (_focusedComplaint != null) ...[
                  _buildControlButton(
                    icon: Icons.zoom_out_map_rounded,
                    onTap: _zoomBack,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildControlButton(
                  icon: _isSatellite ? Icons.layers_outlined : Icons.layers,
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                ),
                const SizedBox(height: 12.0),
                Tooltip(
                  message: _isNightMode
                      ? 'Р”РЅРµРІРЅРѕР№ СЂРµР¶РёРј'
                      : 'РќРѕС‡РЅРѕР№ РєРёР±РµСЂРїР°РЅРє',
                  child: _buildControlButton(
                    icon: _isNightMode
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    onTap: _toggleVisualMode,
                  ),
                ),
                const SizedBox(height: 12.0),
                _buildPrimaryActionFab(),
                const SizedBox(height: 12.0),
                Tooltip(
                  message: '3D Р В Р ВµР В¶Р С‘Р С (Cesium)',
                  child: _buildControlButton(
                    icon: Icons.view_in_ar_rounded,
                    onTap: _openCesiumViewer,
                  ),
                ),

                const SizedBox(height: 12.0),
                Tooltip(
                  message: 'Р СњР В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–Р С”Р С‘',
                  child: _buildControlButton(
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overlay РЎРѓ Р С‘Р Р…РЎвЂћР С•РЎР‚Р СР В°РЎвЂ Р С‘Р ВµР в„– Р С• Р Р†РЎвЂ№Р В±РЎР‚Р В°Р Р…Р Р…Р С•Р в„– Р С—РЎР‚Р С•Р В±Р В»Р ВµР СР Вµ
          _buildFocusedOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return _NeoGlassPanel(
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      fillColor: _uiPanelFill,
      blurSigma: 28,
      borderColors: [
        _uiGlow.withAlpha(_isNightMode ? 160 : 58),
        _uiGlow.withAlpha(_isNightMode ? 60 : 12),
        Colors.transparent,
      ],
      child: Stack(
        children: [
          Positioned(
            bottom: -5,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: _isNightMode ? 0.58 : 0.14,
              child: CityPulseWave(
                totalCount: _totalComplaints,
                categoryCounts: _categoryCounts,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'РџРЈР›Р¬РЎ Р“РћР РћР”Рђ В· РќРР–РќР•Р’РђР РўРћР’РЎРљ',
                        style: TextStyle(
                          color: _uiTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildQuickCamButton(),
                    IconButton(
                      icon: Icon(Icons.info_outline,
                          color: _uiAccent, size: 22.0),
                      splashRadius: 22,
                      tooltip: 'Рћ РїСЂРѕРµРєС‚Рµ',
                      onPressed: () {
                        _emitSelectionHaptic();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.bar_chart, color: _uiAccent, size: 22.0),
                      splashRadius: 22,
                      tooltip: 'РРЅС„РѕРіСЂР°С„РёРєР°',
                      onPressed: () {
                        _emitSelectionHaptic();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const InfographicScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  _isNightMode
                      ? 'РќРѕС‡РЅРѕР№ РєРёР±РµСЂРїР°РЅРє В· РґР°РЅРЅС‹Рµ РїРѕРІРµСЂС… РєР°СЂС‚С‹'
                      : 'Р”РЅРµРІРЅРѕР№ СЂРµР¶РёРј В· С‡РёСЃС‚Р°СЏ РєР°СЂС‚Р° Рё Р»РµРіРєРёРµ РѕСЃС‚СЂРѕРІРєРё',
                  style: TextStyle(
                    color: _uiTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersIsland() {
    final filters = <Map<String, Object?>>[
      {'days': null, 'label': 'Р’СЃРµ'},
      {'days': -1, 'label': 'РќРѕРІС‹Рµ'},
      {'days': 1, 'label': '1 Рґ'},
      {'days': 7, 'label': '7 Рґ'},
      {'days': 30, 'label': '30 Рґ'},
    ];

    return _NeoGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      fillColor: _uiPanelFill,
      blurSigma: 24,
      borderColors: [
        _uiGlow.withAlpha(_isNightMode ? 120 : 48),
        _uiGlow.withAlpha(_isNightMode ? 55 : 12),
        Colors.transparent,
      ],
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in filters)
            _buildDaysChip(
              days: f['days'] as int?,
              label: f['label'] as String,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCamButton() {
    return const SizedBox.shrink();
  }

  Widget _buildDaysChip({required int? days, required String label}) {
    final selected = _selectedDaysFilter == days;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? (_isNightMode ? Colors.black : Colors.white)
              : _uiTextPrimary,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: _uiAccent,
      backgroundColor: _isNightMode
          ? _colorSurface.withAlpha(185)
          : Colors.white.withAlpha(175),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? _uiAccent
              : (_isNightMode
                  ? Colors.white.withAlpha(60)
                  : const Color(0xFF7DD3FC).withAlpha(120)),
          width: 1.0,
        ),
      ),
      onSelected: (_) {
        _emitSelectionHaptic();
        setState(() {
          _selectedDaysFilter = days;
        });
        if (_allComplaints.isNotEmpty) {
          _processComplaints(_filterByDate(_allComplaints));
        }
      },
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colorSurface.withAlpha(245),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _colorPrimary.withAlpha(80), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.pie_chart_rounded, color: _colorAccent),
            const SizedBox(width: 8),
            const Text(
              'Р РЋРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”Р В° Р Р…Р В° Р С”Р В°РЎР‚РЎвЂљР Вµ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem(
                'Р вЂ™РЎРѓР ВµР С–Р С• Р С•Р В±РЎР‚Р В°РЎвЂ°Р ВµР Р…Р С‘Р в„–',
                _totalComplaints,
                Colors.white),
            _buildStatItem(
                'Р СћРЎР‚Р ВµР В±РЎС“РЎР‹РЎвЂљ Р Р†Р Р…Р С‘Р СР В°Р Р…Р С‘РЎРЏ',
                _newComplaints,
                _colorDanger),
            _buildStatItem(
                'Р Р€РЎРѓР С—Р ВµРЎв‚¬Р Р…Р С• РЎР‚Р ВµРЎв‚¬Р ВµР Р…РЎвЂ№',
                _resolvedComplaints,
                _colorSuccess),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Р вЂќР В°Р Р…Р Р…РЎвЂ№Р Вµ Р С•Р В±Р Р…Р С•Р Р†Р В»РЎРЏРЎР‹РЎвЂљРЎРѓРЎРЏ Р Р† РЎР‚Р ВµР В¶Р С‘Р СР Вµ РЎР‚Р ВµР В°Р В»РЎРЉР Р…Р С•Р С–Р С• Р Р†РЎР‚Р ВµР СР ВµР Р…Р С‘. Р вЂ™РЎвЂ№ Р СР С•Р В¶Р ВµРЎвЂљР Вµ РЎвЂћР С‘Р В»РЎРЉРЎвЂљРЎР‚Р С•Р Р†Р В°РЎвЂљРЎРЉ Р В¶Р В°Р В»Р С•Р В±РЎвЂ№ Р С—Р С• Р С”Р В°РЎвЂљР ВµР С–Р С•РЎР‚Р С‘РЎРЏР С Р С‘ Р Р†РЎР‚Р ВµР СР ВµР Р…Р Р…РЎвЂ№Р С Р Т‘Р С‘Р В°Р С—Р В°Р В·Р С•Р Р…Р В°Р С РЎвЂЎР ВµРЎР‚Р ВµР В· Р Р†Р ВµРЎР‚РЎвЂ¦Р Р…РЎР‹РЎР‹ Р С—Р В°Р Р…Р ВµР В»РЎРЉ.',
              style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Р вЂ”Р С’Р С™Р В Р В«Р СћР В¬',
                style: TextStyle(
                    color: _colorAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withAlpha(179),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showUkDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      const supabaseUrl =
          'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data?data_type=eq.uk_list&select=data';
      const supabaseKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

      final response = await http.get(
        Uri.parse(supabaseUrl),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // close progress
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          final results = data[0]['data'] as List;
          _showUkListOverlay(results);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Р вЂќР В°Р Р…Р Р…РЎвЂ№Р Вµ Р Р€Р С™ Р С—РЎС“РЎРѓРЎвЂљРЎвЂ№')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Р С›РЎв‚¬Р С‘Р В±Р С”Р В° Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С”Р С‘ Р Р€Р С™')));
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Р С›РЎв‚¬Р С‘Р В±Р С”Р В° РЎРѓР ВµРЎвЂљР С‘: $e')));
    }
  }

  void _showUkListOverlay(List uks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _colorBottomSheet,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: _colorAccent, size: 28),
                    const SizedBox(width: 8),
                    Text(
                        'Р Р€Р С—РЎР‚Р В°Р Р†Р В»РЎРЏРЎР‹РЎвЂ°Р С‘Р Вµ Р С”Р С•Р СР С—Р В°Р Р…Р С‘Р С‘ (${uks.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: uks.length,
                  itemBuilder: (ctx, i) {
                    final uk = uks[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorPrimary.withAlpha(50),
                        child: const Icon(Icons.apartment, color: _colorAccent),
                      ),
                      title: Text(uk['TITLESM'] ?? uk['TITLE'] ?? 'Р Р€Р С™',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          uk['ADR'] ?? 'Р СњР ВµРЎвЂљ Р В°Р Т‘РЎР‚Р ВµРЎРѓР В°',
                          style: TextStyle(
                              color: Colors.white.withAlpha(150), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white54),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            backgroundColor: _colorSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: _colorPrimary.withAlpha(80),
                                  width: 1.5),
                            ),
                            title: Text(uk['TITLE'] ?? 'Р Р€Р С™',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.phone,
                                      color: _colorAccent),
                                  title: Text(uk['TEL'] ?? '-',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.email,
                                      color: _colorAccent),
                                  title: Text(uk['EMAIL'] ?? '-',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.home,
                                      color: _colorAccent),
                                  title: Text(uk['ADR'] ?? '-',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.apartment,
                                      color: _colorAccent),
                                  title: Text(
                                      'Р вЂ™ РЎС“Р С—РЎР‚Р В°Р Р†Р В»Р ВµР Р…Р С‘Р С‘ Р Т‘Р С•Р СР С•Р Р†: ${uk['CNT'] ?? '-'}',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person,
                                      color: _colorAccent),
                                  title: Text(
                                      'Р В РЎС“Р С”Р С•Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЉ: ${uk['FIO'] ?? '-'}',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx2);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Р С’Р Р…Р С•Р Р…Р С‘Р СР Р…Р С•Р Вµ Р С—Р С‘РЎРѓРЎРЉР СР С• Р С•РЎвЂљР С—РЎР‚Р В°Р Р†Р В»Р ВµР Р…Р С• Р Р† Р Р€Р С™! (Р СћР ВµРЎРѓРЎвЂљ)'),
                                    backgroundColor: _colorSuccess,
                                  ));
                                },
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        _colorAccent.withAlpha(30)),
                                child: const Text(
                                    'Р С›РЎвЂљР С—РЎР‚Р В°Р Р†Р С‘РЎвЂљРЎРЉ Р В°Р Р…Р С•Р Р…Р С‘Р СР Р…РЎС“РЎР‹ Р В¶Р В°Р В»Р С•Р В±РЎС“',
                                    style: TextStyle(
                                        color: _colorAccent,
                                        fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx2),
                                child: const Text(
                                    'Р вЂ”Р В°Р С”РЎР‚РЎвЂ№РЎвЂљРЎРЉ',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openComplaintComposer() async {
    final center = _mapController.camera.center;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComplaintFormScreen(
          initialCenter: LatLng(center.latitude, center.longitude),
        ),
      ),
    );
    if (result == true && mounted) {
      _loadComplaints();
    }
  }

  Widget _buildFabPulseRing(double progress, double visibility) {
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.5 * visibility;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 1 + progress * 0.8,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _uiGlow.withAlpha(
                  (opacity * (_isNightMode ? 255 : 145)).round(),
                ),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _uiGlow.withAlpha(
                    math.max(
                      0,
                      math.min(
                        _isNightMode ? 120 : 62,
                        (opacity * (_isNightMode ? 120 : 62)).round(),
                      ),
                    ),
                  ),
                  blurRadius: _isNightMode ? 26 : 14,
                  spreadRadius: _isNightMode ? 4 : 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionFab() {
    return Tooltip(
      message:
          'Р РЋР С•Р С•Р В±РЎвЂ°Р С‘РЎвЂљРЎРЉ Р С• Р С—РЎР‚Р С•Р В±Р В»Р ВµР СР Вµ',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _emitImpactHaptic();
          _openComplaintComposer();
        },
        child: AnimatedBuilder(
          animation: _fabPulseController,
          builder: (context, _) {
            final visibility = _isMapMoving ? 0.14 : 1.0;
            final progress = _fabPulseController.value;
            final secondaryProgress = (progress + 0.45) % 1.0;
            final bob =
                math.sin(progress * math.pi * 2) * (_isMapMoving ? 1.5 : 4.0);
            final scale = _isMapMoving
                ? 1.0
                : 1.0 + math.sin(progress * math.pi * 2) * 0.03;
            final glowAlpha = _isMapMoving
                ? (_isNightMode ? 90 : 44)
                : (_isNightMode ? 150 : 78);

            return SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildFabPulseRing(progress, visibility),
                  _buildFabPulseRing(secondaryProgress, visibility * 0.85),
                  IgnorePointer(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _uiGlow.withAlpha(glowAlpha),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -bob),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_uiPrimary, _uiAccent],
                          ),
                          border: Border.all(
                            color: _uiGlow.withAlpha(_isNightMode ? 200 : 138),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _uiGlow.withAlpha(glowAlpha),
                              blurRadius: _isNightMode ? 28 : 12,
                              spreadRadius: _isNightMode ? 4 : 1,
                            ),
                            BoxShadow(
                              color: Colors.black
                                  .withAlpha(_isNightMode ? 80 : 34),
                              blurRadius: _isNightMode ? 16 : 12,
                              spreadRadius: _isNightMode ? 2 : 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_alert,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _emitSelectionHaptic();
        onTap();
      },
      child: _NeoGlassPanel(
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.all(0),
        fillColor: _uiPanelFillStrong,
        blurSigma: 26,
        borderColors: [
          _uiGlow.withAlpha(_isNightMode ? 140 : 62),
          _uiGlow.withAlpha(_isNightMode ? 45 : 12),
          Colors.transparent,
        ],
        boxShadow: [
          BoxShadow(
            color: _uiGlow.withAlpha(_isNightMode ? 95 : 28),
            blurRadius: _isNightMode ? 20 : 10,
            spreadRadius: _isNightMode ? 2 : 0,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(_isNightMode ? 70 : 14),
            blurRadius: _isNightMode ? 12 : 10,
            spreadRadius: 1,
          ),
        ],
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: _uiTextPrimary, size: 24.0),
        ),
      ),
    );
  }

  void _openCesiumViewer() {
    final camera = _mapController.camera;
    final focusCenter = LatLng(camera.center.latitude, camera.center.longitude);
    final focusZoom = camera.zoom;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return CesiumMapScreen(
            complaints: _allComplaints,
            initialCenter: focusCenter,
            initialZoom: focusZoom,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final scale = Tween<double>(
            begin: 0.955,
            end: 1,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          );

          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final portalRadius = lerpDouble(0.18, 1.45, animation.value) ?? 1;
              final portalOpacity = (1 - animation.value).clamp(0.0, 1.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  FadeTransition(
                    opacity: fade,
                    child: Transform.scale(
                      scale: scale.value,
                      alignment: Alignment.center,
                      child: child,
                    ),
                  ),
                  IgnorePointer(
                    child: Opacity(
                      opacity: portalOpacity * 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: portalRadius,
                            colors: const [
                              Color(0xAA00E5FF),
                              Color(0x3300E5FF),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.38, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LiveCamDialog extends StatefulWidget {
  final String title;
  final String url;
  final int? peopleCount;
  final bool detectorEnabled;

  const _LiveCamDialog({
    required this.title,
    required this.url,
    this.peopleCount,
    this.detectorEnabled = false,
  });

  @override
  State<_LiveCamDialog> createState() => _LiveCamDialogState();
}

class _LiveCamDialogState extends State<_LiveCamDialog> {
  static const double _nizhnevartovskLat = 60.9366;
  static const double _nizhnevartovskLon = 76.5594;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Timer? _hudClockTimer;
  Timer? _weatherRefreshTimer;
  bool _hasError = false;
  DateTime _cityTime = _currentNizhnevartovskTime();
  _CameraHudWeather _weather = const _CameraHudWeather.loading();
  int? _peopleCount;

  @override
  void initState() {
    super.initState();
    _peopleCount = widget.peopleCount;
    _startHudTelemetry();
    _initializePlayer();
  }

  static DateTime _currentNizhnevartovskTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 5));
  }

  void _startHudTelemetry() {
    _hudClockTimer?.cancel();
    _hudClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _cityTime = _currentNizhnevartovskTime());
    });

    _refreshWeather();
    _weatherRefreshTimer?.cancel();
    _weatherRefreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _refreshWeather(),
    );
  }

  Future<void> _refreshWeather() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': _nizhnevartovskLat.toString(),
      'longitude': _nizhnevartovskLon.toString(),
      'current': 'temperature_2m,apparent_temperature,weather_code,is_day',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Weather request failed: ${response.statusCode}');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final current = payload['current'] as Map<String, dynamic>?;
      if (current == null) throw Exception('Weather payload missing current');

      final code = (current['weather_code'] as num?)?.toInt() ?? -1;
      final isDay = ((current['is_day'] as num?)?.toInt() ?? 1) == 1;
      final temperature = (current['temperature_2m'] as num?)?.toDouble();
      final apparent = (current['apparent_temperature'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        _weather = _mapWeatherCode(
          code: code,
          isDay: isDay,
          temperature: temperature,
          apparentTemperature: apparent,
        );
      });
    } catch (e) {
      debugPrint('Live camera weather load error: $e');
      if (!mounted) return;
      setState(() {
        _weather = const _CameraHudWeather.error();
      });
    }
  }

  _CameraHudWeather _mapWeatherCode({
    required int code,
    required bool isDay,
    required double? temperature,
    required double? apparentTemperature,
  }) {
    IconData icon =
        isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round_rounded;
    String label = 'РЇСЃРЅРѕ';
    Color accent = const Color(0xFF56E0FF);

    if (code == 0) {
      label = isDay ? 'РЇСЃРЅРѕ' : 'РЇСЃРЅР°СЏ РЅРѕС‡СЊ';
      accent = const Color(0xFF7DE7FF);
    } else if ([1, 2].contains(code)) {
      icon = isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue_rounded;
      label = 'РџРµСЂРµРјРµРЅРЅР°СЏ РѕР±Р»Р°С‡РЅРѕСЃС‚СЊ';
      accent = const Color(0xFF8BE7FF);
    } else if (code == 3) {
      icon = Icons.cloud_rounded;
      label = 'РџР°СЃРјСѓСЂРЅРѕ';
      accent = const Color(0xFF86B7DA);
    } else if ([45, 48].contains(code)) {
      icon = Icons.blur_on_rounded;
      label = 'РўСѓРјР°РЅ';
      accent = const Color(0xFFB8D7EA);
    } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      icon = Icons.water_drop_rounded;
      label = 'Р”РѕР¶РґСЊ';
      accent = const Color(0xFF3DA8FF);
    } else if (code >= 71 && code <= 77) {
      icon = Icons.ac_unit_rounded;
      label = 'РЎРЅРµРі';
      accent = const Color(0xFFC8F4FF);
    } else if (code >= 95) {
      icon = Icons.flash_on_rounded;
      label = 'Р“СЂРѕР·Р°';
      accent = const Color(0xFFFFC857);
    }

    final tempLabel =
        temperature == null ? '--В°' : '${temperature.round().toString()}В°';
    final feelsLikeLabel = apparentTemperature == null
        ? 'РћС‰СѓС‰Р°РµС‚СЃСЏ --В°'
        : 'РћС‰СѓС‰Р°РµС‚СЃСЏ ${apparentTemperature.round()}В°';

    return _CameraHudWeather(
      icon: icon,
      label: label,
      temperatureLabel: tempLabel,
      feelsLikeLabel: feelsLikeLabel,
      accent: accent,
    );
  }

  String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    return '$dd.$mm.${value.year}';
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _hasError = false;
      _chewieController = null;
    });

    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        isLive: true,
        errorBuilder: (context, errorMessage) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white24, size: 40),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Video initialized error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _hudClockTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: _NeoGlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: EdgeInsets.zero,
        fillColor: const Color(0xD9141A28),
        blurSigma: 26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded,
                        color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const Text(
                          'Live stream',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Player Area
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hasError)
                      const Center(
                        child: Text(
                          'Stream unavailable',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else if (_chewieController != null &&
                        _chewieController!
                            .videoPlayerController.value.isInitialized)
                      Chewie(controller: _chewieController!)
                    else
                      const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(100),
                              Colors.transparent,
                              Colors.black.withAlpha(130),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: IgnorePointer(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildHudChip(
                                    icon: _weather.icon,
                                    title: 'РџРѕРіРѕРґР°',
                                    value: _weather.temperatureLabel,
                                    subtitle: _weather.label,
                                    accent: _weather.accent,
                                  ),
                                  _buildHudChip(
                                    icon: Icons.schedule_rounded,
                                    title: 'РќРёР¶РЅРµРІР°СЂС‚РѕРІСЃРє',
                                    value: _formatTime(_cityTime),
                                    subtitle: _formatDate(_cityTime),
                                    accent: const Color(0xFF9AF8FF),
                                  ),
                                  _buildHudChip(
                                    icon: Icons.groups_rounded,
                                    title: 'Р›СЋРґРё РІ РєР°РґСЂРµ',
                                    value: _peopleCount?.toString() ?? '--',
                                    subtitle: widget.detectorEnabled
                                        ? 'AI counter online'
                                        : 'Detector standby',
                                    accent: widget.detectorEnabled
                                        ? const Color(0xFF77FFCB)
                                        : const Color(0xFFFFC857),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildHudStatusPill(),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildScanlineLabel(
                                label: 'WX LINK',
                                value: _weather.feelsLikeLabel,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildScanlineLabel(
                                label: 'AI VISION',
                                value: widget.detectorEnabled
                                    ? 'People telemetry synced'
                                    : 'Vision channel pending',
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  if (_hasError) ...[
                    ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(widget.url),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open in browser / VLC'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(20),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCol('Bitrate', 'Live'),
                      _buildStatCol('Format', 'HLS/m3u8'),
                      _buildStatCol('Status', _hasError ? 'Offline' : 'Online'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white30, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHudChip({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xA0171F31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(160)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(34),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accent.withAlpha(235),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xB01B1020),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.redAccent.withAlpha(200)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withAlpha(45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record_rounded,
              color: Colors.redAccent, size: 12),
          SizedBox(width: 6),
          Text(
            'LIVE HUD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanlineLabel({
    required String label,
    required String value,
    bool alignEnd = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x7F101722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x5537DDFE)),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7DE7FF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraHudWeather {
  const _CameraHudWeather({
    required this.icon,
    required this.label,
    required this.temperatureLabel,
    required this.feelsLikeLabel,
    required this.accent,
  });

  const _CameraHudWeather.loading()
      : icon = Icons.sync_rounded,
        label = 'РЎРёРЅС…СЂРѕРЅРёР·Р°С†РёСЏ',
        temperatureLabel = '--В°',
        feelsLikeLabel = 'РџРѕРіРѕРґРЅС‹Р№ РєР°РЅР°Р»...',
        accent = const Color(0xFF9AF8FF);

  const _CameraHudWeather.error()
      : icon = Icons.cloud_off_rounded,
        label = 'РќРµС‚ РґР°РЅРЅС‹С…',
        temperatureLabel = '--В°',
        feelsLikeLabel = 'РџРѕРіРѕРґР° РЅРµРґРѕСЃС‚СѓРїРЅР°',
        accent = const Color(0xFFFFC857);

  final IconData icon;
  final String label;
  final String temperatureLabel;
  final String feelsLikeLabel;
  final Color accent;
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/mcp_config.dart';
import '../map/map_config.dart'
    show kMapCenterDefault, kOsmAttributionText, kOsmCopyrightUrl, MapConfig;
import '../services/admin_dashboard_service.dart';
import '../services/backend_api_service.dart';
import '../services/mcp_service.dart';
import '../services/notification_tap_payload_store.dart';
import '../theme/pulse_colors.dart';
import 'complaint_form_screen.dart';
import 'infographic_screen.dart';
import 'about_screen.dart';
import 'profile_screen.dart';
import 'mesh_screen.dart';
import '../services/sound_service.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import '../utils/offline_tiles_service.dart';

// Extracted map widgets
import 'map/widgets/index.dart';

/// Главный экран карты — отображает городские сигналы на карте Нижневартовска.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.initialNotificationPayload,
  });

  final Map<String, String?>? initialNotificationPayload;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ─── Контроллеры и сервисы ───
  final MapController _mapController = MapController();
  final BackendApiService _backendApi = BackendApiService.instance;
  final MCPService _mcpService = MCPService();

  // ─── Состояние ───
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _showCamerasLayer = false;
  bool _showProblemMarkers = true;
  bool _showEventMarkers = true;
  bool _secretCamerasEnabled = false;
  List<Marker> _cameraMarkers = [];
  bool _showUkLayer = false;
  Map<String, dynamic>? _ukAtCenter;
  int _totalComplaints = 0;
  int _newComplaints = 0;
  int _resolvedComplaints = 0;
  Timer? _updateTimer;
  Timer? _secretCameraTapResetTimer;
  String? _selectedCategory;
  int? _selectedDaysFilter;
  List<Map<String, dynamic>> _allComplaints = [];
  bool _isSatellite = false;
  final Map<String, int> _categoryCounts = {};
  final List<String> _markerCategories = [];
  final List<Map<String, dynamic>> _markerItems = [];
  late final AnimationController _fabPulseController;
  late final AnimationController _markerPulseController;
  Timer? _mapMotionTimer;
  bool _isMapMoving = false;
  bool _isNightMode = true;

  // ─── Состояние для автозума ───
  LatLng? _preZoomCenter;
  double? _preZoomLevel;
  Map<String, dynamic>? _focusedComplaint;
  Map<String, String?>? _pendingNotificationPayload;

  // ─── Константы ───
  static const LatLng _center = kMapCenterDefault;
  static const Duration _updateInterval = Duration(seconds: 30);
  static const Duration _mapMotionCooldown = Duration(milliseconds: 750);
  static const Duration _markerPulseDuration = Duration(milliseconds: 3200);
  static const Duration _secretCameraTapWindow = Duration(seconds: 7);
  static const Duration _nizhnevartovskOffset = Duration(hours: 5);
  static const String _complaintsCachePrefKey = 'map_cached_markers_v2';
  static const String _complaintsCacheTsPrefKey = 'map_cached_markers_ts_v2';
  static const String _visualModePrefKey = 'map_visual_mode_is_night';
  static const String _secretCameraPrefKey = 'map_secret_cameras_enabled';
  static const int _secretCameraTapTarget = 10;
  int _secretCameraTapCount = 0;

  // ─── Цветовая палитра ───
  static const Color _colorDanger = PulseColors.negative;
  static const Color _colorSuccess = PulseColors.success;
  static const Color _colorNeutral = PulseColors.neutral;
  static const Color _colorPrimary = PulseColors.primary;
  static const Color _colorAccent = PulseColors.primarySoft;
  static const Color _colorSurface = PulseColors.background;

  // ─── Категории ───
  static const List<(String, IconData, Color)> _categories = [
    ('Дороги', Icons.directions_car, _colorDanger),
    ('ЖКХ', Icons.home, _colorPrimary),
    ('Освещение', Icons.lightbulb, Color(0xFFf59e0b)),
    ('Транспорт', Icons.directions_bus, Color(0xFF3b82f6)),
    ('Экология', Icons.eco, _colorSuccess),
    ('Безопасность', Icons.shield, Color(0xFF6366f1)),
    ('Снег/Наледь', Icons.ac_unit, Color(0xFF38bdf8)),
    ('Медицина', Icons.local_hospital, Color(0xFFef4444)),
    ('Образование', Icons.school, Color(0xFF818cf8)),
    ('Парковки', Icons.local_parking, Color(0xFF9ca3af)),
    ('Строительство', Icons.architecture_rounded, Color(0xFFF59E0B)),
    ('Мероприятие', Icons.event_available_rounded, Color(0xFFEAB308)),
    ('Прочее', Icons.report_problem, _colorNeutral),
  ];

  @override
  void initState() {
    super.initState();
    _pendingNotificationPayload = widget.initialNotificationPayload ??
        NotificationTapPayloadStore.consumePendingPayload();
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
    unawaited(_restoreSecretCameraPreference());
    unawaited(_restoreCachedComplaints());
    _loadCameras();
    _loadComplaints();
    _startPeriodicUpdates();
    unawaited(_locateUserOnMap());
  }

  Future<void> _locateUserOnMap() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      if (mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          16.0,
        );
      }
    } catch (e) {
      debugPrint('Error locating user: $e');
    }
  }

  Future<void> _loadCameras() async {
    try {
      final response = await _backendApi.get(
        '/api/cameras',
        timeout: const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Camera feed failed: HTTP ${response.statusCode}');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final publicRows = payload is Map<String, dynamic>
          ? (payload['cameras'] as List<dynamic>? ?? const <dynamic>[])
          : const <dynamic>[];
      final rows = <Map<String, dynamic>>[
        for (final row in publicRows.whereType<Map>())
          row.map((key, value) => MapEntry(key.toString(), value)),
      ];
      if (_secretCamerasEnabled && AdminDashboardService.instance.hasSession) {
        rows.addAll(await AdminDashboardService.instance.fetchSecretCameras());
      }
      final dedupedRows = <String, Map<String, dynamic>>{};
      for (final item in rows) {
        final cameraId = item['camera_id']?.toString().trim();
        final dedupeKey = (cameraId != null && cameraId.isNotEmpty)
            ? cameraId
            : '${item['name'] ?? item['n']}:${item['lat']}:${item['lng']}:${item['stream_url'] ?? item['s']}';
        dedupedRows[dedupeKey] = item;
      }
      final markers = <Marker>[];
      for (final item in dedupedRows.values) {
        final lat = item['lat'];
        final lng = item['lng'];
        final name = item['n'] ?? 'Камера';
        final url = item['s'];
        final serverName = item['name'] ?? name;
        final serverUrl = (item['stream_url'] ?? url ?? '').toString();
        final isSecret = item['is_secret'] == true;

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
                _showLiveCamDialog(serverName.toString(), serverUrl);
              },
              child: AnimatedMapMarker(
                animation: _markerPulseController,
                color: isSecret ? const Color(0xFFF59E0B) : _colorPrimary,
                icon: isSecret
                    ? Icons.lock_outline_rounded
                    : Icons.videocam_rounded,
                size: 52,
                seed: ((point.latitude + point.longitude).abs() % 1),
                isDayMode: !_isNightMode,
                shell: isSecret ? MarkerShell.shield : MarkerShell.hexagon,
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

  Future<void> _restoreSecretCameraPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_secretCameraPrefKey) ?? false;
      if (!mounted) {
        _secretCamerasEnabled = saved;
        return;
      }
      setState(() => _secretCamerasEnabled = saved);
      if (_showCamerasLayer) {
        await _loadCameras();
      }
    } catch (error) {
      debugPrint('Secret camera preference restore failed: $error');
    }
  }

  Future<void> _persistSecretCameraPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_secretCameraPrefKey, _secretCamerasEnabled);
    } catch (error) {
      debugPrint('Secret camera preference save failed: $error');
    }
  }

  Future<void> _handleSecretCameraTap() async {
    _secretCameraTapResetTimer?.cancel();
    _secretCameraTapCount += 1;

    if (_secretCameraTapCount >= _secretCameraTapTarget) {
      _secretCameraTapCount = 0;
      final nextValue = !_secretCamerasEnabled;
      if (mounted) {
        setState(() => _secretCamerasEnabled = nextValue);
      } else {
        _secretCamerasEnabled = nextValue;
      }
      await _persistSecretCameraPreference();
      if (_showCamerasLayer) {
        await _loadCameras();
      }
      if (nextValue && !AdminDashboardService.instance.hasSession) {
        await _ensureSecretCameraSession();
      }
      if (!mounted) return;
      final message = nextValue
          ? (AdminDashboardService.instance.hasSession
              ? 'Секретные камеры включены'
              : 'Секретный режим включен. Для скрытых камер нужна 2FA-сессия.')
          : 'Секретные камеры выключены';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    _secretCameraTapResetTimer = Timer(_secretCameraTapWindow, () {
      _secretCameraTapCount = 0;
    });
  }

  Future<void> _toggleCameraLayer() async {
    _emitSelectionHaptic();
    final nextValue = !_showCamerasLayer;
    if (mounted) {
      setState(() => _showCamerasLayer = nextValue);
    } else {
      _showCamerasLayer = nextValue;
    }
    if (nextValue) {
      await _loadCameras();
    }
  }

  Future<void> _fetchUkForCenter() async {
    if (!_showUkLayer) return;
    try {
      final center = _mapController.camera.center;
      final response = await http
          .get(Uri.parse(
              '${MapConfig.backendApiBaseUrl}/uk/by_coords?lat=${center.latitude}&lng=${center.longitude}'))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final payload = json.decode(utf8.decode(response.bodyBytes));
        setState(() => _ukAtCenter = payload);
        HapticFeedback.lightImpact();
      } else {
        setState(() => _ukAtCenter = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('УК для этой точки не найдена')),
        );
      }
    } catch (e) {
      debugPrint('UK fetch error: $e');
    }
  }

  Future<void> _toggleUkLayer() async {
    _emitSelectionHaptic();
    setState(() => _showUkLayer = !_showUkLayer);
    if (_showUkLayer) {
      await _fetchUkForCenter();
    } else {
      setState(() => _ukAtCenter = null);
    }
  }

  Future<void> _ensureSecretCameraSession() async {
    if (AdminDashboardService.instance.hasSession || !mounted) return;

    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _colorSurface,
        title: const Text('2FA код', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.visiblePassword,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Введите код администратора',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Подключить'),
          ),
        ],
      ),
    );
    controller.dispose();

    final normalized = code?.trim();
    if (normalized == null || normalized.isEmpty) return;

    try {
      await AdminDashboardService.instance.ensureSession(
        twoFactorCode: normalized,
      );
      if (_showCamerasLayer) await _loadCameras();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть скрытые камеры: $error')),
      );
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapMotionTimer?.cancel();
    _secretCameraTapResetTimer?.cancel();
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
      if (saved == null || !mounted) return;
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

  // ═══════════════════════════════════════════════════════════
  // Загрузка данных
  // ═══════════════════════════════════════════════════════════

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      if (!mounted) return;
      _loadComplaints();
      if (_showCamerasLayer) _loadCameras();
    });
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final complaints = await _fetchComplaints();

      if (complaints.isNotEmpty) {
        final combined = [...complaints];
        final existingIds = _allComplaints.map((c) => c['id']).toSet();
        Map<String, dynamic>? freshComplaint;

        if (_allComplaints.isNotEmpty) {
          for (var c in complaints) {
            if (!_isEventItem(c) && !existingIds.contains(c['id'])) {
              freshComplaint = c;
              break;
            }
          }
        }

        _allComplaints = combined;
        unawaited(_cacheComplaints(combined));
        _processComplaints(_filterByDate(combined));

        if (freshComplaint != null) {
          final activeComplaint = freshComplaint;
          if (!mounted) return;
          _zoomToComplaint(activeComplaint);
          _showMapItemDetails(activeComplaint);

          SoundService()
              .playCategorySound(activeComplaint['category'] ?? 'Прочее');

          NotificationService().showNewComplaintNotification(
            context,
            title: activeComplaint['title'] ?? 'Новая ситуация',
            category: activeComplaint['category'] ?? 'Прочее',
            color: _getCategoryColor(activeComplaint['category'] ?? 'Прочее'),
          );

          NotificationService().showPushNotification(
            id: activeComplaint['id'] is int
                ? activeComplaint['id']
                : math.Random().nextInt(1000000),
            title: 'Новая ситуация: ${activeComplaint['category'] ?? 'Прочее'}',
            body: activeComplaint['summary'] ??
                activeComplaint['title'] ??
                activeComplaint['description'] ??
                'Нажмите, чтобы посмотреть подробности',
            category: activeComplaint['category'],
            payload: {
              'report_id': '${activeComplaint['id'] ?? ''}',
              if (activeComplaint['lat'] != null)
                'lat': '${activeComplaint['lat']}',
              if (activeComplaint['latitude'] != null &&
                  activeComplaint['lat'] == null)
                'lat': '${activeComplaint['latitude']}',
              if (activeComplaint['lng'] != null)
                'lng': '${activeComplaint['lng']}',
              if (activeComplaint['longitude'] != null &&
                  activeComplaint['lng'] == null)
                'lng': '${activeComplaint['longitude']}',
            },
          );

          Timer(const Duration(seconds: 10), () {
            if (mounted &&
                _focusedComplaint != null &&
                _focusedComplaint!['id'] == activeComplaint['id']) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              _zoomBack();
            }
          });
        }
      } else {
        debugPrint('Данные не получены, пустой список сигналов');
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
          const SnackBar(content: Text('Нет данных, проверьте соединение')),
        );
      }
    } catch (e) {
      debugPrint('Критическая ошибка загрузки данных: $e');
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
            content: Text('Ошибка загрузки данных, проверьте соединение')),
      );
    }

    if (mounted) setState(() => _isLoading = false);
    _applyPendingNotificationFocus();
  }

  final Duration _fetchTimeout = const Duration(seconds: 20);
  final int _fetchRetries = 2;

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    final apiUrl = '${MapConfig.backendApiBaseUrl}/map/feed?limit=80';

    for (var attempt = 0; attempt < _fetchRetries; attempt++) {
      try {
        final res = await http.get(Uri.parse(apiUrl), headers: {
          'Content-Type': 'application/json',
        }).timeout(_fetchTimeout);

        if (res.statusCode == 200) {
          final payload = jsonDecode(utf8.decode(res.bodyBytes));
          final markers = payload is Map<String, dynamic>
              ? (payload['markers'] as List<dynamic>? ?? const <dynamic>[])
              : const <dynamic>[];
          final complaints =
              markers.whereType<Map>().map(_normalizeMapItem).toList();

          if (complaints.isNotEmpty) {
            debugPrint('Получено сигналов из API: ${complaints.length}');
            return complaints;
          }
        }
      } catch (e) {
        debugPrint('Fetch attempt ${attempt + 1}/$_fetchRetries failed: $e');
      }
    }

    final cached = await _readCachedComplaints();
    if (cached.isNotEmpty) {
      debugPrint('Using cached map feed: ${cached.length}');
      return cached;
    }

    return _fallbackComplaints();
  }

  Future<void> _cacheComplaints(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_complaintsCachePrefKey, jsonEncode(items));
      await prefs.setInt(
        _complaintsCacheTsPrefKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('Map cache write failed: $error');
    }
  }

  Future<void> _restoreCachedComplaints() async {
    final cached = await _readCachedComplaints();
    if (!mounted || cached.isEmpty) return;
    _allComplaints = cached;
    _processComplaints(_filterByDate(cached));
  }

  Future<List<Map<String, dynamic>>> _readCachedComplaints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_complaintsCachePrefKey);
      if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('Map cache restore failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _fallbackComplaints() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'fallback-city-anchor',
        'title': 'Городской контур',
        'summary': 'Резервный маркер города',
        'description':
            'Сервер недоступен. Карта покажет городской центр и обновится, когда связь восстановится.',
        'lat': _center.latitude,
        'lng': _center.longitude,
        'category': 'Прочее',
        'status': 'open',
        'source_kind': 'system',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // Обработка данных
  // ═══════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> data) {
    if (_selectedDaysFilter == null) return data;

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
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _normalizeMapItem(Map item) {
    final normalized = Map<String, dynamic>.from(
      item.map((key, value) => MapEntry(key.toString(), value)),
    );
    normalized['title'] =
        (normalized['title'] ?? normalized['summary'] ?? 'Без названия')
            .toString()
            .trim();
    normalized['summary'] = normalized['summary'] ?? normalized['title'];
    normalized['latitude'] = normalized['latitude'] ?? normalized['lat'];
    normalized['longitude'] = normalized['longitude'] ?? normalized['lng'];
    normalized['source_kind'] = normalized['source_kind'] ??
        ((normalized['category'] == 'Мероприятие') ? 'event' : 'report');
    normalized['status'] = normalized['status'] ?? 'open';
    return normalized;
  }

  void _applyPendingNotificationFocus() {
    final payload = _pendingNotificationPayload;
    if (!NotificationTapPayloadStore.hasMarkerTarget(payload)) return;

    final reportId = int.tryParse(payload?['report_id']?.trim() ?? '');
    Map<String, dynamic>? matchedComplaint;

    if (reportId != null) {
      for (final item in _allComplaints) {
        if ('${item['id']}' == '$reportId') {
          matchedComplaint = item;
          break;
        }
      }
    }

    matchedComplaint ??= _matchComplaintByCoordinates(payload);
    if (matchedComplaint != null) {
      _pendingNotificationPayload = null;
      _zoomToComplaint(matchedComplaint);
      return;
    }

    final lat = double.tryParse(payload?['lat']?.trim() ?? '');
    final lng = double.tryParse(payload?['lng']?.trim() ?? '');
    if (lat != null && lng != null) {
      _pendingNotificationPayload = null;
      _animateMapTo(LatLng(lat, lng), 17.0);
    }
  }

  Map<String, dynamic>? _matchComplaintByCoordinates(
    Map<String, String?>? payload,
  ) {
    final lat = double.tryParse(payload?['lat']?.trim() ?? '');
    final lng = double.tryParse(payload?['lng']?.trim() ?? '');
    if (lat == null || lng == null) return null;

    const tolerance = 0.0002;
    for (final item in _allComplaints) {
      final itemLat = item['lat'] ?? item['latitude'];
      final itemLng = item['lng'] ?? item['longitude'];
      if (itemLat is! num || itemLng is! num) continue;
      if ((itemLat.toDouble() - lat).abs() <= tolerance &&
          (itemLng.toDouble() - lng).abs() <= tolerance) {
        return item;
      }
    }
    return null;
  }

  bool _isEventItem(Map<String, dynamic> item) {
    final sourceKind = item['source_kind']?.toString().trim().toLowerCase();
    final category = _normalizeCategoryLabel(
      item['category']?.toString().trim() ?? '',
    );
    return sourceKind == 'event' || category == 'Мероприятие';
  }

  void _showMapItemDetails(Map<String, dynamic> item) {
    if (_isEventItem(item)) {
      _showEventDetails(item);
      return;
    }
    _showComplaintDetails(item);
  }

  void _processComplaints(List<dynamic> data) {
    if (data.length == 100 && data.isNotEmpty && data[0] == 'mock') {
      if (!mounted) return;
      setState(() {
        _markers = [];
        _markerItems.clear();
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

    int total = 0;
    int newCount = 0;
    int resolvedCount = 0;
    final markers = <Marker>[];
    final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));

    for (final item in data) {
      final lat = item['lat'] ?? item['latitude'];
      final lng = item['lng'] ?? item['longitude'];
      if (lat == null || lng == null) continue;

      final status = (item['status'] ?? 'open') as String;
      final isEvent = _isEventItem(item);
      final dt = _parseDateTime(item);
      final isNew = dt != null && dt.isAfter(threeHoursAgo);

      if (!isEvent) {
        total++;
        if (isNew) newCount++;
        if (status == 'resolved') resolvedCount++;
      }

      try {
        final category = _normalizeCategoryLabel(
          (item['category'] ?? 'Прочее') as String,
        );
        final normalizedItem = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item);
        markers.add(_buildMarker(
          point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          status: status,
          category: category,
          complaint: normalizedItem,
        ));
      } catch (e) {
        debugPrint('Ошибка обработки маркера: $e. Item: $item');
      }
    }

    final counts = <String, int>{};
    for (final item in data) {
      final cat = _normalizeCategoryLabel(
        (item['category'] ?? 'Прочее') as String,
      );
      counts[cat] = (counts[cat] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _markerItems.clear();
      _markerCategories.clear();
      for (final item in data) {
        final lat = item['lat'] ?? item['latitude'];
        final lng = item['lng'] ?? item['longitude'];
        if (lat != null && lng != null) {
          _markerItems.add(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item),
          );
          _markerCategories.add(
            _normalizeCategoryLabel((item['category'] ?? 'Прочее') as String),
          );
        }
      }
      _totalComplaints = total;
      _newComplaints = newCount;
      _resolvedComplaints = resolvedCount;
      _categoryCounts
        ..clear()
        ..addAll(counts);
    });
    _applyPendingNotificationFocus();
  }

  List<Marker> get _filteredProblemMarkers {
    return [
      for (var i = 0; i < _markers.length; i++)
        if (i < _markerCategories.length &&
            i < _markerItems.length &&
            !_isEventItem(_markerItems[i]) &&
            _showProblemMarkers &&
            (_selectedCategory == null ||
                _normalizeCategoryLabel(_markerCategories[i]) ==
                    _normalizeCategoryLabel(_selectedCategory!)))
          _markers[i],
    ];
  }

  List<Marker> get _filteredEventMarkers {
    return [
      for (var i = 0; i < _markers.length; i++)
        if (i < _markerCategories.length &&
            i < _markerItems.length &&
            _isEventItem(_markerItems[i]) &&
            _showEventMarkers &&
            (_selectedCategory == null ||
                _normalizeCategoryLabel(_markerCategories[i]) ==
                    _normalizeCategoryLabel(_selectedCategory!)))
          _markers[i],
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // Анимация карты
  // ═══════════════════════════════════════════════════════════

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

  void _zoomToComplaint(Map<String, dynamic> complaint) {
    final lat = complaint['lat'] ?? complaint['latitude'];
    final lng = complaint['lng'] ?? complaint['longitude'];
    if (lat == null || lng == null) return;

    final camera = _mapController.camera;
    _preZoomCenter = camera.center;
    _preZoomLevel = camera.zoom;

    setState(() => _focusedComplaint = complaint);

    _animateMapTo(
      LatLng((lat as num).toDouble(), (lng as num).toDouble()),
      17.0,
    );
  }

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

  // ═══════════════════════════════════════════════════════════
  // Хелперы категорий
  // ═══════════════════════════════════════════════════════════

  IconData _getCategoryIcon(String category) {
    switch (_normalizeCategoryLabel(category)) {
      case 'Дороги':
        return Icons.add_road;
      case 'Освещение':
        return Icons.lightbulb;
      case 'ЖКХ':
        return Icons.home_repair_service;
      case 'Транспорт':
        return Icons.directions_bus;
      case 'Экология':
        return Icons.eco;
      case 'Безопасность':
        return Icons.security;
      case 'Снег/Наледь':
        return Icons.ac_unit;
      case 'Медицина':
      case 'Здравоохранение':
        return Icons.local_hospital;
      case 'Образование':
        return Icons.school;
      case 'Парковки':
        return Icons.local_parking;
      case 'Благоустройство':
        return Icons.park;
      case 'Строительство':
        return Icons.architecture_rounded;
      case 'Мероприятие':
        return Icons.event_available_rounded;
    }
    switch (category) {
      case 'Дороги':
        return Icons.add_road;
      case 'Освещение':
        return Icons.lightbulb;
      case 'ЖКХ':
        return Icons.home_repair_service;
      case 'Транспорт':
        return Icons.directions_bus;
      case 'Экология':
        return Icons.eco;
      case 'Безопасность':
        return Icons.security;
      case 'Снег/Наледь':
        return Icons.ac_unit;
      case 'Медицина':
      case 'Здравоохранение':
        return Icons.local_hospital;
      case 'Образование':
        return Icons.school;
      case 'Парковки':
        return Icons.local_parking;
      case 'Благоустройство':
        return Icons.park;
      case 'Мероприятие':
        return Icons.event_available_rounded;
      default:
        return Icons.help_outline;
    }
  }

  MarkerShell _getCategoryShell(String category) {
    switch (_normalizeCategoryLabel(category)) {
      case 'Дороги':
        return MarkerShell.diamond;
      case 'ЖКХ':
        return MarkerShell.roundedSquare;
      case 'Освещение':
        return MarkerShell.hexagon;
      case 'Транспорт':
        return MarkerShell.shield;
      case 'Экология':
        return MarkerShell.circle;
      case 'Безопасность':
        return MarkerShell.shield;
      case 'Снег/Наледь':
        return MarkerShell.hexagon;
      case 'Медицина':
        return MarkerShell.roundedSquare;
      case 'Образование':
        return MarkerShell.roundedSquare;
      case 'Парковки':
        return MarkerShell.diamond;
      case 'Благоустройство':
        return MarkerShell.circle;
      case 'Строительство':
        return MarkerShell.hexagon;
      case 'Мероприятие':
        return MarkerShell.circle;
      case 'Камеры':
        return MarkerShell.hexagon;
      default:
        return MarkerShell.circle;
    }
  }

  String _normalizeCategoryLabel(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) return 'Прочее';

    const canonical = <String>{
      'Дороги',
      'ЖКХ',
      'Освещение',
      'Транспорт',
      'Экология',
      'Безопасность',
      'Снег/Наледь',
      'Медицина',
      'Здравоохранение',
      'Образование',
      'Парковки',
      'Благоустройство',
      'Строительство',
      'Мероприятие',
      'Прочее',
      'Камеры',
    };

    if (canonical.contains(normalized)) return normalized;

    // Fallback: return as-is for unrecognized labels
    return normalized;
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
    final isCamera = category == 'Камеры';
    final color =
        isCamera ? const Color(0xFF6366F1) : _getCategoryColor(category);
    final markerIcon =
        isCamera ? Icons.videocam_rounded : _getCategoryIcon(category);
    final markerShell =
        isCamera ? MarkerShell.hexagon : _getCategoryShell(category);
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
          if (category == 'Камеры') {
            final streamUrl = (complaint['stream_url'] ??
                    complaint['s'] ??
                    MapConfig.cityCams[complaint['title']])
                ?.toString();
            _showLiveCamDialog(complaint['title'] ?? 'Камера', streamUrl);
          } else {
            _showMapItemDetails(complaint);
          }
        },
        child: AnimatedMapMarker(
          animation: _markerPulseController,
          color: color,
          icon: markerIcon,
          size: isCamera ? 58 : 54,
          seed: seed,
          isDayMode: !_isNightMode,
          shell: markerShell,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    return switch (status) {
      'open' => 'Новая',
      'pending' => 'В работе',
      'resolved' => 'Решена',
      _ => 'Неизвестно',
    };
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Не указана';
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
    if (dt == null) return 'Не указана';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════
  // Bottom sheets и диалоги
  // ═══════════════════════════════════════════════════════════

  Future<void> _scheduleEventReminder(
    BuildContext snackbarContext,
    Map<String, dynamic> event,
    Duration offset,
  ) async {
    final scheduledDate = _parseDateTime(event);
    if (scheduledDate == null) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        const SnackBar(content: Text('Не удалось определить время события')),
      );
      return;
    }

    final reminderTime = scheduledDate.subtract(offset);
    await NotificationService().scheduleReminder(
      id: event['id']?.hashCode ?? 0,
      title: 'Событие: ${event['title']}',
      body: offset.inMinutes >= 60
          ? 'Напоминание за ${offset.inHours} ч. до начала.'
          : 'Напоминание за ${offset.inMinutes} мин. до начала.',
      scheduledDate: reminderTime,
    );
    if (!mounted || !snackbarContext.mounted) return;
    ScaffoldMessenger.of(snackbarContext).showSnackBar(
      const SnackBar(content: Text('Напоминание установлено')),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    final categoryColor = _getCategoryColor('Мероприятие');
    final scheduledDate = _parseDateTime(event);
    final sourceLabel =
        event['source_label']?.toString().trim() ?? 'Городская афиша';
    final venue = event['venue']?.toString().trim();
    final link = event['link']?.toString().trim();
    final address = event['address']?.toString().trim();
    final description = event['description']?.toString().trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          child: MapGlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            padding: EdgeInsets.zero,
            fillColor: const Color(0xEA16110A),
            blurSigma: 26,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                categoryColor.withAlpha(72),
                                const Color(0xFF2B1804),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border:
                                Border.all(color: categoryColor.withAlpha(120)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(36),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.event_available_rounded,
                                      color: categoryColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ГОРОДСКОЕ СОБЫТИЕ',
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.6,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          event['title']?.toString() ??
                                              'Событие',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildEventChip(
                                    Icons.schedule_rounded,
                                    scheduledDate == null
                                        ? 'Время уточняется'
                                        : _formatDate(
                                            scheduledDate.toIso8601String()),
                                    categoryColor,
                                  ),
                                  _buildEventChip(
                                    Icons.campaign_rounded,
                                    sourceLabel,
                                    categoryColor,
                                  ),
                                  if (venue != null && venue.isNotEmpty)
                                    _buildEventChip(
                                      Icons.place_rounded,
                                      venue,
                                      categoryColor,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (address != null && address.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(8),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.white.withAlpha(18)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on_rounded,
                                    color: categoryColor, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(6),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.white.withAlpha(12)),
                            ),
                            child: Text(
                              description,
                              style: TextStyle(
                                color: Colors.white.withAlpha(220),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: PopupMenuButton<Duration>(
                                color: _colorSurface,
                                onSelected: (offset) => _scheduleEventReminder(
                                  ctx,
                                  event,
                                  offset,
                                ),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: Duration(minutes: 30),
                                    child: Text('За 30 мин.',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                  PopupMenuItem(
                                    value: Duration(hours: 2),
                                    child: Text('За 2 часа',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                  PopupMenuItem(
                                    value: Duration(days: 1),
                                    child: Text('За день',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withAlpha(32),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: categoryColor.withAlpha(110),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.notifications_active_rounded,
                                          color: categoryColor, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Напомнить',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (link != null && link.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.tryParse(link);
                                    if (uri == null) return;
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Источник'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withAlpha(18),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: Colors.white.withAlpha(20)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _zoomBack();
                            },
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Вернуться к карте'),
                            style: TextButton.styleFrom(
                              foregroundColor: categoryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
    ).whenComplete(() {
      if (_focusedComplaint != null) _zoomBack();
    });
  }

  Widget _buildEventChip(IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    if (_isEventItem(complaint)) {
      _showEventDetails(complaint);
      return;
    }
    final status = (complaint['status'] ?? 'open') as String;
    final statusColor = _getStatusColor(status);
    final category = (complaint['category'] ?? 'Прочее') as String;
    final categoryColor = _getCategoryColor(category);
    final dateRaw = complaint['created_at'] ??
        complaint['createdAt'] ??
        complaint['timestamp'];

    showComplaintBottomSheet(
      context: context,
      complaint: complaint,
      categoryColor: categoryColor,
      statusColor: statusColor,
      statusText: _getStatusText(status),
      categoryLabel: _normalizeCategoryLabel(category),
      categoryIcon: _getCategoryIcon(category),
      formattedDate: _formatDate(dateRaw),
      onZoomBack: _zoomBack,
      onScheduleReminder: () => _scheduleEventReminder(
          context, complaint, const Duration(minutes: 30)),
      isEvent: _isEventItem(complaint),
      onComplaintUpdated: (updated) {
        setState(() {
          for (int i = 0; i < _allComplaints.length; i++) {
            if (_allComplaints[i]['id'] == updated['id']) {
              _allComplaints[i] = updated;
              break;
            }
          }
        });
      },
    );
  }

  void _showLiveCamDialog(String title, String? url) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на трансляцию не найдена')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => VideoPlayerDialog(title: title, url: url),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Overlay карты
  // ═══════════════════════════════════════════════════════════

  Widget _buildFocusedOverlay() {
    if (_focusedComplaint == null) return const SizedBox.shrink();

    final complaint = _focusedComplaint!;
    final status = (complaint['status'] ?? 'open') as String;
    final statusColor = _getStatusColor(status);
    final category = (complaint['category'] ?? 'Прочее') as String;
    final categoryColor = _getCategoryColor(category);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: MapGlassPanel(
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
                      complaint['title'] as String? ?? 'Без названия',
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
                          '${_getStatusText(status)} - $category',
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

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Карта (бесплатная подложка OSM)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: MapConfig.initialZoom,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _registerMapMovement();
                if (_showUkLayer && hasGesture) {
                  _fetchUkForCenter();
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              OfflineTilesService.instance.getTileLayer(
                _isSatellite ? MapConfig.satelliteUrl : MapConfig.tileUrl,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _filteredProblemMarkers,
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
              // Мероприятия отдельным слоем без кластеризации
              if (_showEventMarkers && _filteredEventMarkers.isNotEmpty)
                MarkerLayer(markers: _filteredEventMarkers),
              if (_showCamerasLayer) MarkerLayer(markers: _cameraMarkers),
              if (_showUkLayer && _ukAtCenter != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _mapController.camera.center,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _showUkDetails({
                          'uk_name': _ukAtCenter!['name'],
                          'phone': _ukAtCenter!['phone'],
                          'email': _ukAtCenter!['email'],
                          'houses': _ukAtCenter!['houses_count'],
                          'overall_score': '?',
                          'resolved_complaints': 0,
                          'address': _ukAtCenter!['address']
                        }),
                        child: AnimatedMapMarker(
                          animation: _markerPulseController,
                          color: PulseColors.primaryDeep,
                          icon: Icons.business_rounded,
                          size: 60,
                          seed: 0.5,
                          isDayMode: !_isNightMode,
                          shell: MarkerShell.hexagon,
                        ),
                      ),
                    ),
                  ],
                ),
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

          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: CircularProgressIndicator(color: _colorPrimary),
              ),
            ),

          // Верхняя панель с заголовком и фильтрами
          Positioned(
            top: paddingTop + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MapTopBar(
                  isNightMode: _isNightMode,
                  totalComplaints: _totalComplaints,
                  categoryCounts: _categoryCounts,
                  uiTextPrimary: _uiTextPrimary,
                  uiTextSecondary: _uiTextSecondary,
                  uiPanelFill: _uiPanelFill,
                  uiGlow: _uiGlow,
                  uiAccent: _uiAccent,
                  isUkLayerActive: _showUkLayer,
                  onUkToggleLayer: _toggleUkLayer,
                  onUkDialog: _showUkDialog,
                  onMapMenuSheet: _showMapMenuSheet,
                  onSecretCameraTap: () => unawaited(_handleSecretCameraTap()),
                ),
                const SizedBox(height: 10),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: DailyDigestTicker(),
                ),
                const SizedBox(height: 10),
                MapFilterPanel(
                  selectedDaysFilter: _selectedDaysFilter,
                  uiTextPrimary: _uiTextPrimary,
                  uiPanelFill: _uiPanelFill,
                  uiGlow: _uiGlow,
                  uiAccent: _uiAccent,
                  isNightMode: _isNightMode,
                  onDaysFilterChanged: (days) {
                    _emitSelectionHaptic();
                    setState(() => _selectedDaysFilter = days);
                    if (_allComplaints.isNotEmpty) {
                      _processComplaints(_filterByDate(_allComplaints));
                    }
                  },
                ),
                const SizedBox(height: 10),
                MapCategoryDropdown(
                  selectedCategory: _selectedCategory,
                  totalComplaints: _totalComplaints,
                  categoryCounts: _categoryCounts,
                  uiTextPrimary: _uiTextPrimary,
                  uiTextSecondary: _uiTextSecondary,
                  uiPanelFill: _uiPanelFill,
                  uiGlow: _uiGlow,
                  uiAccent: _uiAccent,
                  isNightMode: _isNightMode,
                  onCategoryChanged: (value) {
                    _emitSelectionHaptic();
                    setState(() => _selectedCategory = value);
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                if (_focusedComplaint != null) ...[
                  _buildControlButton(
                    icon: Icons.zoom_out_map_rounded,
                    onTap: _zoomBack,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildPrimaryActionFab(),
              ],
            ),
          ),

          _buildFocusedOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Меню карты
  // ═══════════════════════════════════════════════════════════

  void _showMapMenuSheet() {
    _emitSelectionHaptic();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MapGlassPanel(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(18),
              fillColor: _uiPanelFillStrong,
              blurSigma: 30,
              borderColors: [
                _uiGlow.withAlpha(_isNightMode ? 150 : 70),
                _uiGlow.withAlpha(30),
                Colors.transparent,
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Меню карты',
                        style: TextStyle(
                          color: _uiTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon:
                            Icon(Icons.close_rounded, color: _uiTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildMenuToggleChip(
                        label: 'Сигналы',
                        icon: Icons.report_problem_outlined,
                        active: _showProblemMarkers,
                        onTap: () => setState(
                          () => _showProblemMarkers = !_showProblemMarkers,
                        ),
                      ),
                      _buildMenuToggleChip(
                        label: 'Мероприятия',
                        icon: Icons.event_available_rounded,
                        active: _showEventMarkers,
                        onTap: () => setState(
                          () => _showEventMarkers = !_showEventMarkers,
                        ),
                      ),
                      _buildMenuToggleChip(
                        label: 'Камеры',
                        icon: _showCamerasLayer
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        active: _showCamerasLayer,
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _toggleCameraLayer();
                        },
                      ),
                      _buildMenuToggleChip(
                        label: _isSatellite ? 'Спутник' : 'Карта',
                        icon: _isSatellite
                            ? Icons.satellite_alt_rounded
                            : Icons.map_outlined,
                        active: _isSatellite,
                        onTap: () => setState(
                          () => _isSatellite = !_isSatellite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMenuActionTile(
                    icon: Icons.analytics_rounded,
                    label: 'Статистика',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showStatsDialog();
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.business_rounded,
                    label: 'Управляющие компании',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showUkDialog();
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Инфографика',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InfographicScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.info_outline_rounded,
                    label: 'О проекте',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Профиль',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.hub_rounded,
                    label: 'Mesh-сеть',
                    subtitle: 'Автономная связь без интернета',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MeshScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuActionTile(
                    icon: _isNightMode
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    label: _isNightMode ? 'Дневной режим' : 'Ночной режим',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _toggleVisualMode();
                    },
                  ),
                  _buildMenuActionTile(
                    icon: Icons.settings_outlined,
                    label: 'Настройки',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  if (_secretCamerasEnabled)
                    _buildMenuActionTile(
                      icon: Icons.lock_open_rounded,
                      label: 'Скрытые камеры',
                      subtitle: AdminDashboardService.instance.hasSession
                          ? '2FA-сессия активна'
                          : 'Нужна 2FA-сессия',
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _ensureSecretCameraSession();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuToggleChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      selected: active,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 16, color: active ? Colors.black : _uiAccent),
      label: Text(label),
      selectedColor: _uiAccent,
      backgroundColor: _isNightMode
          ? _colorSurface.withAlpha(185)
          : Colors.white.withAlpha(175),
      labelStyle: TextStyle(
        color: active ? Colors.black : _uiTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: active ? _uiAccent : _uiGlow.withAlpha(_isNightMode ? 80 : 40),
      ),
    );
  }

  Widget _buildMenuActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _uiPrimary.withAlpha(_isNightMode ? 40 : 25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _uiAccent, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: _uiTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: _uiTextSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: _uiTextSecondary),
      onTap: onTap,
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
              'Статистика на карте',
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
            _buildStatItem('Всего сигналов', _totalComplaints, Colors.white),
            _buildStatItem('Требуют внимания', _newComplaints, _colorDanger),
            _buildStatItem(
                'Успешно решены', _resolvedComplaints, _colorSuccess),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Данные обновляются в режиме реального времени. Вы можете фильтровать сигналы по категориям и временным диапазонам через верхнюю панель.',
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
            child: const Text('ЗАКРЫТЬ',
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
          Text('$label:',
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 12,
              )),
          const SizedBox(width: 8.0),
          Text(value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              )),
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
      final response = await http
          .get(
            Uri.parse('${MapConfig.backendApiBaseUrl}/uk/ratings?limit=100'),
          )
          .timeout(const Duration(seconds: 10));

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки УК: ${response.statusCode}')),
        );
        return;
      }

      final payload = json.decode(utf8.decode(response.bodyBytes));
      final ratings = payload is Map<String, dynamic>
          ? (payload['ratings'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((row) => row.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList()
          : const <Map<String, dynamic>>[];

      if (!mounted) return;
      if (ratings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные УК пока отсутствуют')),
        );
        return;
      }

      _showUkListOverlay(ratings);
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
    }
  }

  void _showUkListOverlay(List uks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MapGlassPanel(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(18),
              fillColor: _uiPanelFillStrong,
              blurSigma: 30,
              borderColors: [
                _uiGlow.withAlpha(_isNightMode ? 150 : 70),
                _uiGlow.withAlpha(30),
                Colors.transparent,
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, color: _colorAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Управляющие компании (${uks.length})',
                        style: TextStyle(
                          color: _uiTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon:
                            Icon(Icons.close_rounded, color: _uiTextSecondary),
                      ),
                    ],
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: uks.length,
                      separatorBuilder: (_, __) => Divider(
                        color: _uiGlow.withAlpha(30),
                        height: 1,
                      ),
                      itemBuilder: (ctx, i) {
                        final uk = Map<String, dynamic>.from(uks[i] as Map);
                        final name = (uk['uk_name'] ?? 'УК').toString();
                        final houses = (uk['houses'] ?? 0).toString();
                        final phone = (uk['phone'] ?? '').toString().trim();
                        final email = (uk['email'] ?? '').toString().trim();
                        final grade = (uk['grade'] ?? '—').toString();

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _colorPrimary.withAlpha(50),
                            child: Text(
                              grade,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: _uiTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Домов: $houses · ${phone.isNotEmpty ? phone : (email.isNotEmpty ? email : 'контакты уточняются')}',
                            style: TextStyle(color: _uiTextSecondary),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: _uiTextSecondary),
                          onTap: () => _showUkDetails(uk),
                        );
                      },
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

  void _showUkDetails(Map<String, dynamic> uk) {
    final name = (uk['uk_name'] ?? 'УК').toString();
    final phone = (uk['phone'] ?? '').toString().trim();
    final email = (uk['email'] ?? '').toString().trim();
    final houses = (uk['houses'] ?? 0).toString();
    final score = (uk['overall_score'] ?? 0).toString();
    final resolved = (uk['resolved_complaints'] ?? 0).toString();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colorSurface,
        title: Text(name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Рейтинг: $score',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Решённых ситуаций: $resolved',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Домов в управлении: $houses',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Телефон: ${phone.isNotEmpty ? phone : 'не указан'}',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Email: ${email.isNotEmpty ? email : 'не указан'}',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          if (phone.isNotEmpty)
            TextButton(
              onPressed: () => _contactUk('tel:$phone'),
              child: const Text('Позвонить'),
            ),
          if (email.isNotEmpty)
            TextButton(
              onPressed: () => _contactUk('mailto:$email'),
              child: const Text('Написать'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactUk(String uri) async {
    final target = Uri.parse(uri);
    if (!await launchUrl(target)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть контакт')),
      );
    }
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
    if (result == true && mounted) _loadComplaints();
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
      message: 'Сообщить о ситуации',
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
                            Colors.transparent
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
      child: MapGlassPanel(
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
}

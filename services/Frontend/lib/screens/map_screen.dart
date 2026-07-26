import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../config/mcp_config.dart';
import '../map/map_config.dart'
    show kMapCenterDefault, kOsmAttributionText, kOsmCopyrightUrl, MapConfig;
import '../services/admin_dashboard_service.dart';
import '../services/backend_api_service.dart';
import '../services/mcp_service.dart';
import '../services/notification_tap_payload_store.dart';
import '../theme/pulse_categories.dart';
import '../theme/pulse_colors.dart';
import '../theme/theme_provider.dart';
import 'complaint_form_screen.dart';
import 'about_screen.dart';
import 'profile_screen.dart';
import 'mesh_screen.dart';
import 'gamification_screen.dart';
import 'uk_companies_screen.dart';
import '../services/sound_service.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import '../services/favorite_cameras_service.dart';
import '../data/district_data.dart';
import '../data/city_config.dart';
import '../data/novosibirsk_district_data.dart';
import '../services/city_provider.dart';
import '../utils/offline_tiles_service.dart';
import 'ai_digest_screen.dart';
import 'lost_and_found_screen.dart';
import '../services/city_weather_service.dart';
import '../services/mesh_network_service.dart';
import 'city_panorama_screen.dart';
import 'ar_markers_screen.dart';
import '../services/app_state_service.dart';
import '../services/navigation_history_service.dart';
import 'navigation/navigator_screen.dart';
import 'package:confetti/confetti.dart';

// Extracted map widgets
import 'map/widgets/index.dart';
import 'map/widgets/map_menu_sheet.dart';
import 'meme_screen.dart';

import 'ai_assistant_screen.dart';
import '../widgets/category_icon_3d.dart';
import '../widgets/gpu_shader_background.dart';
import '../services/deep_link_service.dart';
import '../services/analytics_service.dart';
import '../widgets/onboarding_overlay.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<int> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('telegram_id') ?? 0;
  }

  Future<void> _saveMapState() async {
    try {
      await AppStateService.instance.saveMapPosition(
        lat: _mapController.camera.center.latitude,
        lng: _mapController.camera.center.longitude,
        zoom: _mapController.camera.zoom,
      );
      await AppStateService.instance.saveMapDisplayMode(
        satellite: _isSatellite,
        nightMode: _isNightMode,
      );
      await AppStateService.instance.saveMapFilters(
        categories: _selectedCategories,
        districts: _selectedDistricts,
      );
      await AppStateService.instance.saveMapLayers(
        problems: _showProblemMarkers,
        events: _showEventMarkers,
        cameras: _showCamerasLayer,
        transport: false,
        lostFound: _showLostFoundLayer,
      );
    } catch (_) {}
  }

  Future<void> _restoreMapState() async {
    try {
      final s = AppStateService.instance.state;
      if (mounted) {
        setState(() {
          _isSatellite = s.mapSatellite;
          _selectedCategories = List<String>.from(s.mapCategories);
          _selectedDistricts = List<String>.from(s.mapDistricts);
          _showProblemMarkers = s.layerProblems;
          _showEventMarkers = s.layerEvents;
          _showCamerasLayer = s.layerCameras;
          _showLostFoundLayer = s.layerLostFound;
          _activeCity = CityConfig.byId(s.activeCity);
        });
        if (s.mapLat != null && s.mapLng != null && s.mapZoom != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(LatLng(s.mapLat!, s.mapLng!), s.mapZoom!);
            }
          });
        }
      }
    } catch (_) {}
  }

  void _onDistrictsChanged(List<String> list) {
    setState(() {
      _selectedDistricts = list;
    });
    _saveMapState();
    final cityDistricts = _activeCity.runtimeDistricts;
    if (_selectedDistricts.isNotEmpty) {
      final dist = cityDistricts.firstWhere(
        (d) => d.id == _selectedDistricts.last,
        orElse: () => cityDistricts.first,
      );
      if (dist.polygon.isNotEmpty) {
        double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
        for (final pt in dist.polygon) {
          if (pt.latitude < minLat) minLat = pt.latitude;
          if (pt.latitude > maxLat) maxLat = pt.latitude;
          if (pt.longitude < minLng) minLng = pt.longitude;
          if (pt.longitude > maxLng) maxLng = pt.longitude;
        }
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;
        
        setState(() {
          _selectedDistrictForHighlight = dist;
          _districtHighlightCenter = LatLng(centerLat, centerLng);
        });
        _districtFadeController?.stop();
        _districtFadeController?.forward(from: 0.0);

        _isAutoPanningToDistrict = true;
        _animateMapTo(LatLng(centerLat, centerLng), 14.5);
        Future.delayed(const Duration(milliseconds: 800), () {
          _isAutoPanningToDistrict = false;
        });
      }
    }
  }

  void _updateDistrictUnderCenter(LatLng centerPoint) {
    // Disabled to prevent overriding user selected filters and losing map markers on pan
  }

  /// Смена активного города: анимируем карту и перезагружаем данные
  void _onCityChanged(CityConfig city) {
    if (!mounted) return;
    setState(() {
      _activeCity = city;
      _selectedDistricts = [];
    });
    unawaited(AppStateService.instance.saveActiveCity(city.id));
    unawaited(AppStateService.instance.saveMapFilters(
      categories: _selectedCategories,
      districts: [],
    ));
    // Анимация карты к центру нового города
    _animateMapTo(city.center, city.zoom);
    // Перезагрузить все данные (события и бюро находок приходят из общего фида)
    _loadComplaints();
    _loadCameras();
    unawaited(_refreshCityWeatherAndAlerts());
  }

  List<DistrictData> get _sortedDistricts {
    final list = List<DistrictData>.from(_activeCity.runtimeDistricts);
    list.sort((a, b) {
      final numA = _extractNumber(a.name);
      final numB = _extractNumber(b.name);
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      } else if (numA != null) {
        return -1;
      } else if (numB != null) {
        return 1;
      } else {
        final distA = _getDistanceToCenter(a);
        final distB = _getDistanceToCenter(b);
        return distA.compareTo(distB);
      }
    });
    return list;
  }

  int? _extractNumber(String s) {
    final match = RegExp(r'\d+').firstMatch(s);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  double _getDistanceToCenter(DistrictData d) {
    if (d.polygon.isEmpty) return 9999999.0;
    double sumLat = 0, sumLng = 0;
    for (final pt in d.polygon) {
      sumLat += pt.latitude;
      sumLng += pt.longitude;
    }
    final centroid = LatLng(sumLat / d.polygon.length, sumLng / d.polygon.length);
    return _distance(_activeCity.center, centroid);
  }

  void _showCamerasPanel() {
    SoundService().playAiCamera();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = _searchQuery.toLowerCase();
            final filteredCams = MapConfig.loadedCameras.where((c) {
              final name = (c['n'] ?? c['name'] ?? '').toString().toLowerCase();
              final provider = (c['provider'] ?? '').toString().toLowerCase();
              final street = (c['street'] ?? '').toString().toLowerCase();
              return name.contains(query) || provider.contains(query) || street.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: _uiPanelFillStrong.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Камеры Нижневартовска',
                              style: TextStyle(
                                color: _uiTextPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(Icons.close_rounded, color: _uiTextSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          style: TextStyle(color: _uiTextPrimary),
                          decoration: InputDecoration(
                            hintText: 'Поиск по адресу, улице или провайдеру...',
                            hintStyle: TextStyle(color: _uiTextSecondary.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.search, color: _uiTextSecondary),
                            filled: true,
                            fillColor: _isNightMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filteredCams.isEmpty
                              ? Center(
                                  child: Text(
                                    'Камеры не найдены',
                                    style: TextStyle(color: _uiTextSecondary),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredCams.length,
                                  separatorBuilder: (_, __) => Divider(
                                    color: _uiGlow.withOpacity(0.1),
                                  ),
                                  itemBuilder: (context, index) {
                                    final cam = filteredCams[index];
                                    final name = cam['n'] ?? cam['name'] ?? 'Камера';
                                    final provider = cam['provider'] ?? 'Неизвестно';
                                    final isOnline = cam['streamable'] == true;
                                    final lat = cam['lat'];
                                    final lng = cam['lng'];
                                    
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: isOnline
                                            ? _uiPrimary.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        child: Icon(
                                          Icons.videocam_rounded,
                                          color: isOnline ? _uiPrimary : _uiTextSecondary,
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                          color: _uiTextPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Провайдер: $provider | ${isOnline ? 'Онлайн' : 'Офлайн'}',
                                        style: TextStyle(
                                          color: isOnline ? _uiPrimary : _uiTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (lat != null && lng != null)
                                            IconButton(
                                              icon: Icon(Icons.location_on_rounded, color: _uiPrimary),
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                _mapController.move(LatLng(lat.toDouble(), lng.toDouble()), 15.5);
                                                _emitSelectionHaptic();
                                              },
                                            ),
                                          IconButton(
                                            icon: Icon(Icons.play_circle_fill_rounded, color: isOnline ? _uiPrimary : _uiTextSecondary),
                                            onPressed: () {
                                              Navigator.of(ctx).pop();
                                              _showLiveCamDialog(name, cam['s'] ?? cam['stream_url'] ?? '');
                                              _emitSelectionHaptic();
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Контроллеры и сервисы ───
  final MapController _mapController = MapController();
  final BackendApiService _backendApi = BackendApiService.instance;
  final Distance _distance = const Distance();
  final MCPService _mcpService = MCPService();

  // ─── Состояние ───
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _showCamerasLayer = true;
  bool _showProblemMarkers = true;
  bool _showEventMarkers = true;
  bool _secretCamerasEnabled = false;
  List<Marker> _cameraMarkers = [];
  bool _showLostFoundLayer = false;
  List<Marker> _lostFoundMarkers = [];
  List<LatLng>? _selectedRoutePath;
  Color? _selectedRouteColor;
  bool _showUkLayer = false;
  Map<String, dynamic>? _ukAtCenter;
  int _totalComplaints = 0;
  int _newComplaints = 0;
  int _resolvedComplaints = 0;
  Timer? _updateTimer;
  Timer? _secretCameraTapResetTimer;
  List<String> _selectedCategories = [];
  List<String> _selectedDistricts = [];
  bool _isAutoPanningToDistrict = false;
  String _searchQuery = '';
  int? _selectedDaysFilter = 1;
  List<Map<String, dynamic>> _allComplaints = [];
  bool _isSatellite = false;
  final Map<String, int> _categoryCounts = {};
  final List<String> _markerCategories = [];
  final List<Map<String, dynamic>> _markerItems = [];
  List<Marker> _eventMarkers = [];
  final List<String> _eventMarkerCategories = [];
  final List<Map<String, dynamic>> _eventMarkerItems = [];
  late final AnimationController _fabPulseController;
  late final AnimationController _markerPulseController;
  DistrictData? _selectedDistrictForHighlight;
  LatLng? _districtHighlightCenter;
  AnimationController? _districtFadeController;
  Timer? _cameraBatchTimer;
  AnimationController? _mapMoveController;
  bool _ambientShaderEnabled = true;
  bool _showOnboarding = false;
  Timer? _mapMotionTimer;
  bool _isMapMoving = false;
  bool _isNightMode = true;
  CityConfig _activeCity = CityProvider().activeCity;

  // ─── Состояние для автозума ───
  LatLng? _preZoomCenter;
  double? _preZoomLevel;
  Map<String, dynamic>? _focusedComplaint;
  Map<String, String?>? _pendingNotificationPayload;
  String? _pulseSignalCategory;
  bool _voiceAnnouncementsEnabled = true;
  bool _showWeatherOverlay = false;
  NavigationTrack? _selectedTrack;
  List<LatLng> _liveTrackPoints = [];
  List<LatLng> _replayPoints = [];
  int _replayCurrentIndex = -1;
  Timer? _replayTimer;
  StreamSubscription<List<LatLng>>? _liveTrackSubscription;
  CityWeatherSnapshot _weather = CityWeatherSnapshot.empty();
  CityAlertTickerData _cityAlerts = CityAlertTickerData.empty();
  bool _lastAlertWasUrgent = false;
  Timer? _alertsTimer;
  Set<String> _favoriteCameraUrls = {};
  late final ConfettiController _confettiController;
  // ─── Пуш-тикер внизу карты ───
  String? _pushTickerText;       // текст из пуш-уведомления
  Map<String, dynamic>? _pushTickerComplaint; // связанный инцидент
  bool _isSpeakingPushTicker = false;  // голос активен
  bool _isPushTickerExpanded = false; // развернута ли бегущая строка

  // ─── Режим Дзен ───
  bool _isZenMode = false;
  bool _showFiltersInZen = false;
  bool _userFiltersHidden = false;
  bool _focusFiltersHidden = false;
  bool _isRightPanelVisible = true;
  Timer? _zenHideTimer;
  Timer? _inactivityTimer;
  Timer? _houseGeocodeDebounce;

  LatLng? _highlightedMapPosition;
  String? _highlightedHouseAddress;

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
  static Color get _colorDanger => PulseColors.negative;
  static Color get _colorSuccess => PulseColors.success;
  static Color get _colorNeutral => PulseColors.neutral;
  static Color get _colorPrimary => PulseColors.primary;
  static Color get _colorAccent => PulseColors.primarySoft;
  static Color get _colorSurface => PulseColors.background;

  double get _currentRainDensity {
    if (!_ambientShaderEnabled) return 0.0;
    final kind = _weather.kind.toLowerCase();
    if (kind == 'rain') return 0.7;
    if (kind == 'storm') return 1.0;
    return 0.0;
  }

  double get _currentFogDensity {
    if (!_ambientShaderEnabled) return 0.0;
    final kind = _weather.kind.toLowerCase();
    if (kind == 'cloudy') return 0.25;
    if (kind == 'rain') return 0.45;
    if (kind == 'storm') return 0.65;
    if (kind == 'fog' || kind == 'snow') return 0.8;
    return 0.0;
  }

  double get _currentHoloDensity {
    return 0.0;
  }

  // ─── Категории ───
  // Unified with web `map_script.js` and form categories via PulseCategories.
  static List<(String, IconData, Color)> get _categories =>
      PulseCategories.mapFilterOptions;

  @override
  void initState() {
    super.initState();
    FavoriteCamerasService().addListener(_onFavoritesChanged);
    OfflineTilesService.instance.addListener(_onOfflineTilesChanged);
    ThemeProvider.instance.addListener(_onThemeChanged);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _resetInactivityTimer();
    unawaited(_restoreMapState());
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
    _districtFadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _districtFadeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _selectedDistrictForHighlight = null;
          _districtHighlightCenter = null;
        });
      }
    });
    MCPConfig.initializeMCPService();
    unawaited(_restoreVisualModePreference());
    unawaited(_restoreSecretCameraPreference());
    unawaited(_restoreVoiceAnnouncementsPreference());
    unawaited(_restoreCachedComplaints());
    unawaited(_loadFavorites());
    _loadCameras();
    _loadComplaints();
    _startPeriodicUpdates();
    unawaited(_locateUserOnMap());

    AnalyticsService.trackEvent('app_open');
    _checkOnboarding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final routerState = GoRouterState.of(context);
        final ref = routerState.uri.queryParameters['ref'];
        if (ref != null && ref.isNotEmpty) {
          _handleReferralCode(ref);
        }
      } catch (_) {}
    });
    unawaited(_refreshCityWeatherAndAlerts());
    _alertsTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_refreshCityWeatherAndAlerts());
    });
    _liveTrackSubscription = NavigationHistoryService.instance.currentTrackStream.listen((pts) {
      if (mounted) {
        setState(() {
          _liveTrackPoints = pts;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNotificationPayload != oldWidget.initialNotificationPayload &&
        widget.initialNotificationPayload != null) {
      _pendingNotificationPayload = widget.initialNotificationPayload;
      _applyPendingNotificationFocus();
    }
  }

  Future<void> _locateUserOnMap() async {
    try {
      final userId = await _getUserId();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('map_center_lat_user_$userId')) {
        return;
      }
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

  Future<void> _focusOnUserLocation() async {
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
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        _animateMapTo(
          LatLng(position.latitude, position.longitude),
          15.5,
        );
      }
    } catch (e) {
      debugPrint('Error focusing on user location: $e');
    }
  }

  Future<void> _refreshCityWeatherAndAlerts() async {
    final weather = await CityWeatherService.instance.fetchWeather();
    final alerts = await CityWeatherService.instance.fetchAlerts();
    if (!mounted) return;
    final urgent = alerts.hasHighSeverity;

    final prefs = await SharedPreferences.getInstance();
    final weatherAlertsEnabled = prefs.getBool('weather_alerts_enabled') ?? true;

    if (weatherAlertsEnabled && urgent && !_lastAlertWasUrgent) {
      unawaited(SoundService().playEmergencyAlert());
    }

    if (weatherAlertsEnabled) {
      unawaited(_checkAndTriggerWeatherPushNotification(weather));
    }

    setState(() {
      _weather = weather;
      _cityAlerts = weatherAlertsEnabled ? alerts : CityAlertTickerData.empty();
      _lastAlertWasUrgent = urgent;
    });
  }

  Future<void> _checkAndTriggerWeatherPushNotification(CityWeatherSnapshot weather) async {
    if (!weather.available) return;

    if (!AppStateService.instance.state.weatherAlerts) return;
    final prefs = await SharedPreferences.getInstance();

    final List<String> anomalies = [];
    if (weather.schumannFreqHz != null && (weather.schumannFreqHz! < 7.7 || weather.schumannFreqHz! > 8.0)) {
      anomalies.add('Резонанс Шумана: ${weather.schumannFreqHz} Гц');
    }
    if (weather.pressureMmHg != null && (weather.pressureMmHg! < 748 || weather.pressureMmHg! > 768)) {
      anomalies.add('Давление: ${weather.pressureMmHg} мм рт. ст.');
    }
    if (weather.solarFlare != null && (weather.solarFlare!.startsWith('M') || weather.solarFlare!.startsWith('X'))) {
      final isX = weather.solarFlare!.startsWith('X');
      final healthImpact = isX
          ? 'риск для сердечно-сосудистой системы'
          : 'умеренное влияние на метеочувствительных людей';
      anomalies.add('Солнечная вспышка класса ${weather.solarFlare} ($healthImpact)');
    }
    if (weather.schumannAmpPt != null && weather.schumannAmpPt! > 15.0) {
      anomalies.add('Магнитная буря (Шуман: ${weather.schumannAmpPt} pT)');
    }
    if (weather.windSpeedMs != null && weather.windSpeedMs! > 10.0) {
      anomalies.add('Сильный ветер: ${weather.windSpeedMs} м/с');
    }

    if (anomalies.isEmpty) return;

    final anomalyText = anomalies.join('; ');
    final lastNotified = prefs.getString('last_notified_weather_anomaly') ?? '';

    if (lastNotified != anomalyText) {
      await prefs.setString('last_notified_weather_anomaly', anomalyText);
      await NotificationService().showPushNotification(
        id: 9999,
        title: '⚠️ Погодная аномалия в городе!',
        body: '${anomalies.first}. Нажмите, чтобы открыть карту погоды.',
        category: 'Прочее',
        forceShow: true,
        payload: {
          'type': 'weather_anomaly',
        },
      );
    }
  }

  Future<void> _openWeatherOverlay() async {
    _emitSelectionHaptic();
    if (!_weather.available) {
      await _refreshCityWeatherAndAlerts();
    }
    if (!mounted) return;
    setState(() => _showWeatherOverlay = true);
  }

  void _closeWeatherOverlay() {
    setState(() => _showWeatherOverlay = false);
  }

  Future<void> _loadFavorites() async {
    try {
      final list = await FavoriteCamerasService().getFavorites();
      if (!mounted) return;
      setState(() {
        _favoriteCameraUrls = list.map((c) => c['url'] ?? '').toSet();
      });
      if (_showCamerasLayer) {
        _buildCameraMarkersSmoothly(MapConfig.loadedCameras);
      }
    } catch (_) {}
  }

  void _onFavoritesChanged() {
    _loadFavorites();
  }

  void _onOfflineTilesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isNightMode = ThemeProvider.instance.isDarkMode;
      });
    }
  }

  Future<void> _loadCameras() async {
    try {
      final cityParam = _activeCity.backendCityParam;
      final response = await _backendApi.get(
        '/api/cameras?city=$cityParam',
        timeout: const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Camera feed failed: HTTP ${response.statusCode}');
      }
      final payload = await Isolate.run(() {
        return jsonDecode(utf8.decode(response.bodyBytes));
      });
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
      MapConfig.loadedCameras = dedupedRows.values.toList();
      
      if (_showCamerasLayer && mounted) {
        _buildCameraMarkersSmoothly(MapConfig.loadedCameras);
      }
    } catch (e) {
      debugPrint('Error loading cameras: $e');
      if (MapConfig.loadedCameras.isEmpty) {
        MapConfig.loadedCameras = [
          {'name': '60 лет Октября, 3', 'n': '60 лет Октября, 3', 'lat': 60.9325, 'lng': 76.5710, 'stream_url': 'https://stream3.dantser.org/NV_60Let_3/tracks-v1/mono.ts.m3u8', 's': 'https://stream3.dantser.org/NV_60Let_3/tracks-v1/mono.ts.m3u8'},
          {'name': '60 лет Октября, 10', 'n': '60 лет Октября, 10', 'lat': 60.9330, 'lng': 76.5740, 'stream_url': 'https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8', 's': 'https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8'},
          {'name': 'Героев Самотлора, 18', 'n': 'Героев Самотлора, 18', 'lat': 60.9412, 'lng': 76.5890, 'stream_url': 'https://nginx02.pride-net.ru/geroi18/index.m3u8', 's': 'https://nginx02.pride-net.ru/geroi18/index.m3u8'},
        ];
      }
      if (_showCamerasLayer && mounted) {
        _buildCameraMarkersSmoothly(MapConfig.loadedCameras);
      }
    }
  }

  void _buildCameraMarkersSmoothly(List<Map<String, dynamic>> cameraRows) {
    _cameraBatchTimer?.cancel();
    
    final markers = <Marker>[];
    for (final item in cameraRows) {
      final lat = item['lat'];
      final lng = item['lng'];
      final name = item['n'] ?? 'Камера';
      final url = item['s'];
      final serverName = item['name'] ?? name;
      final serverUrl = (item['stream_url'] ?? url ?? '').toString();
      final isSecret = item['is_secret'] == true;

      if (lat != null && lng != null) {
        final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
        final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;
        final point = LatLng(doubleLat, doubleLng);
        final canonicalStream = MapConfig.cameraAnalysisUrl(serverUrl);
        final isCameraFavorite = _favoriteCameraUrls.any((fav) => 
          MapConfig.cameraAnalysisUrl(fav) == canonicalStream
        );
        final isCameraAlarm = item['active_alarm'] == true || item['alarm'] == true;
        
        final cameraColor = isSecret
            ? const Color(0xFFF59E0B)
            : (isCameraAlarm
                ? const Color(0xFFEF4444)
                : (isCameraFavorite
                    ? const Color(0xFF10B981)
                    : const Color(0xFF00E5FF)));
        
        final cameraIcon = isSecret
            ? Icons.lock_outline_rounded
            : (isCameraAlarm
                ? Icons.warning_amber_rounded
                : (isCameraFavorite ? Icons.star_rounded : Icons.videocam_rounded));

        markers.add(Marker(
          point: point,
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () {
              SoundService().playAiCamera();
              _emitSelectionHaptic();
              _showLiveCamDialog(serverName.toString(), serverUrl).then((_) {
                _loadFavorites();
              });
            },
            child: AnimatedMapMarker(
              animation: _markerPulseController,
              animate: false, // Turn off continuous animation to prevent lag/stutters!
              color: cameraColor,
              icon: cameraIcon,
              size: 52,
              seed: ((point.latitude + point.longitude).abs() % 1),
              isDayMode: !_isNightMode,
              shell: MarkerShell.circle,
            ),
          ),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _cameraMarkers = markers;
      });
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
    _cameraBatchTimer?.cancel();
    if (mounted) {
      setState(() {
        _showCamerasLayer = nextValue;
        if (!nextValue) {
          _cameraMarkers = [];
        }
      });
    } else {
      _showCamerasLayer = nextValue;
    }
    if (nextValue) {
      if (MapConfig.loadedCameras.isNotEmpty) {
        _buildCameraMarkersSmoothly(MapConfig.loadedCameras);
      } else {
        await _loadCameras();
      }
    }
    await _saveMapState();
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
    FavoriteCamerasService().removeListener(_onFavoritesChanged);
    OfflineTilesService.instance.removeListener(_onOfflineTilesChanged);
    ThemeProvider.instance.removeListener(_onThemeChanged);
    _inactivityTimer?.cancel();
    _updateTimer?.cancel();
    _mapMotionTimer?.cancel();
    _cameraBatchTimer?.cancel();
    _secretCameraTapResetTimer?.cancel();
    _alertsTimer?.cancel();
    _zenHideTimer?.cancel();
    _houseGeocodeDebounce?.cancel();
    _liveTrackSubscription?.cancel();
    _fabPulseController.dispose();
    _markerPulseController.dispose();
    _districtFadeController?.dispose();
    _mapMoveController?.dispose();
    _mcpService.disconnectAll();
    _confettiController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_isRightPanelVisible || _isZenMode) {
      setState(() {
        _isRightPanelVisible = true;
        _isZenMode = false;
      });
    }
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        // Play camera offline/disconnect sound upon 1 minute of inactivity
        unawaited(SoundService().playCategorySound('cat_safety.mp3'));
        setState(() {
          _isZenMode = true;
          _showFiltersInZen = false;
          _isRightPanelVisible = false;
          _focusedComplaint = null;
          _pulseSignalCategory = null;
          _preZoomCenter = null;
          _preZoomLevel = null;
        });
        final targetZoom = _activeCity.id == 'novosibirsk' ? 10.8 : 11.8;
        _animateMapToCinematic(_activeCity.center, targetZoom);
      }
    });
  }

  void _emitSelectionHaptic() {
    _resetInactivityTimer();
    HapticFeedback.selectionClick();
  }

  void _emitImpactHaptic() {
    _resetInactivityTimer();
    HapticFeedback.lightImpact();
  }

  void _onScreenTouched() {
    _resetInactivityTimer();
    if (!_isZenMode) return;
    if (!_showFiltersInZen) {
      setState(() {
        _showFiltersInZen = true;
      });
    }
    _zenHideTimer?.cancel();
    _zenHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showFiltersInZen = false;
        });
      }
    });
  }

  bool get _shouldShowFilterPanel {
    if (_userFiltersHidden) return false;
    if (_focusFiltersHidden) return false;
    if (!_isZenMode) return true;
    return _showFiltersInZen;
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
      ? PulseColors.surface.withAlpha(115)
      : Colors.white.withOpacity(0.72); // Luxurious pearl-white glassmorphism

  Color get _uiPanelFillStrong => _isNightMode
      ? PulseColors.backgroundRaised.withAlpha(135)
      : Colors.white.withOpacity(0.85); // Frosted premium white glass

  Color get _uiAccent => _isNightMode ? _colorAccent : const Color(0xFF0284C7); // Rich royal purple/indigo

  Color get _uiPrimary =>
      _isNightMode ? _colorPrimary : const Color(0xFF0284C7);

  Color get _uiGlow =>
      _isNightMode ? PulseColors.primary : const Color(0xFF0EA5E9); // Sophisticated sky-blue glow

  List<Color> get _mapOverlayGradient => _isNightMode
      ? [
          const Color(0x70020617),
          const Color(0x50061527),
          const Color(0x300B2038),
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
    unawaited(ThemeProvider.instance.setThemeMode(_isNightMode ? ThemeMode.dark : ThemeMode.light));
  }

  Future<void> _restoreVisualModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_visualModePrefKey);
      if (saved == null || !mounted) return;
      setState(() => _isNightMode = saved);
      unawaited(ThemeProvider.instance.setThemeMode(saved ? ThemeMode.dark : ThemeMode.light));
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

  void _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    if (!seen) {
      await prefs.setBool('seen_onboarding', true);
      if (mounted) {
        setState(() => _showOnboarding = false);
      }
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    setState(() => _showOnboarding = false);
  }

  void _handleReferralCode(String refCode) async {
    final processed = await DeepLinkService.handleReferral(refCode);
    if (processed) {
      if (!mounted) return;
      _emitSelectionHaptic();
      
      SoundService().playCategorySound('Успех');

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0C1424),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: PulseColors.primary.withOpacity(0.5)),
            ),
            title: Row(
              children: [
                Icon(Icons.stars_rounded, color: PulseColors.primary, size: 28),
                const SizedBox(width: 10),
                const Text('РЕФЕРАЛЬНЫЙ БОНУС', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: const Text(
              'Вы успешно активировали приглашение!\n\nВам начислено +500/500 приветственных баллов!',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('ОТЛИЧНО', style: TextStyle(color: PulseColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      _confettiController.play();
    }
  }

  Future<void> _restoreVoiceAnnouncementsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('voice_announcements_enabled') ?? true;
      if (!mounted) {
        _voiceAnnouncementsEnabled = saved;
        return;
      }
      setState(() => _voiceAnnouncementsEnabled = saved);
    } catch (error) {
      debugPrint('Voice announcements preference restore failed: $error');
    }
  }

  Future<void> _saveVoiceAnnouncementsPreference(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_announcements_enabled', val);
    } catch (error) {
      debugPrint('Voice announcements preference save failed: $error');
    }
  }

  void _registerMapMovement() {
    _resetInactivityTimer();
    _mapMotionTimer?.cancel();
    if (!_isMapMoving && mounted) {
      setState(() => _isMapMoving = true);
    }
    _mapMotionTimer = Timer(_mapMotionCooldown, () {
      if (mounted && _isMapMoving) {
        setState(() => _isMapMoving = false);
        _saveMapState();
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
    if (_allComplaints.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final complaints = await _fetchComplaints();

      if (complaints.isNotEmpty) {
        final combined = [...complaints];
        final existingIds = _allComplaints.map((c) => c['id']).toSet();
        Map<String, dynamic>? freshComplaint;

        if (_allComplaints.isNotEmpty) {
          for (var c in complaints) {
            if (!_isEventItem(c) && !existingIds.contains(c['id'])) {
              final cat = (c['category'] ?? 'Прочее').toString();
              final matchesCat = _selectedCategories.isEmpty ||
                  _selectedCategories.any((selectedCat) =>
                      _normalizeCategoryLabel(cat) == _normalizeCategoryLabel(selectedCat));
              if (_matchesDistrict(c) && matchesCat) {
                freshComplaint = c;
                break;
              }
            }
          }
        }

        _allComplaints = combined;
        unawaited(_cacheComplaints(combined));
        _processComplaints(_filterByDate(combined));

        if (freshComplaint != null) {
          final activeComplaint = freshComplaint;
          if (!mounted) return;
          _centerOnComplaint(activeComplaint);
          
          final title = activeComplaint['title'] ?? 'Новая ситуация';
          final desc = activeComplaint['description'] ?? activeComplaint['summary'] ?? '';
          final tickerText = (desc.toString().isNotEmpty && desc.toString() != title)
              ? '$title — $desc'
              : title.toString();
              
          setState(() {
            _pushTickerText = tickerText;
            _pushTickerComplaint = activeComplaint;
            _isSpeakingPushTicker = false;
            _isPushTickerExpanded = false;
            _pulseSignalCategory = activeComplaint['category']?.toString();
          });
          SoundService()
              .playCategorySound(activeComplaint['category'] ?? 'Прочее');

          if (_voiceAnnouncementsEnabled) {
            unawaited(SoundService().speak(tickerText));
          }

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

          final speakFuture = _voiceAnnouncementsEnabled
              ? SoundService().onTtsComplete.first.timeout(const Duration(seconds: 12), onTimeout: () {})
              : Future<void>.delayed(const Duration(seconds: 6));

          speakFuture.then((_) {
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
        if (_allComplaints.isEmpty) {
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
      }
    } catch (e) {
      debugPrint('Критическая ошибка загрузки данных: $e');
      if (!mounted) return;
      if (_allComplaints.isEmpty) {
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
    }

    if (mounted) setState(() => _isLoading = false);
    _applyPendingNotificationFocus();
  }

  final Duration _fetchTimeout = const Duration(seconds: 20);
  final int _fetchRetries = 2;

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    final cityParam = _activeCity.backendCityParam;
    final apiUrl = '${MapConfig.backendApiBaseUrl}/map/feed?limit=80&city=$cityParam';

    for (var attempt = 0; attempt < _fetchRetries; attempt++) {
      try {
        final res = await http.get(Uri.parse(apiUrl), headers: {
          'Content-Type': 'application/json',
        }).timeout(_fetchTimeout);

        if (res.statusCode == 200) {
          final payload = await Isolate.run(() {
            return jsonDecode(utf8.decode(res.bodyBytes));
          });
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
    final DateTime cutoff;
    if (_selectedDaysFilter == 1) {
      cutoff = DateTime(now.year, now.month, now.day);
    } else {
      final baseDate = now.subtract(Duration(days: _selectedDaysFilter!));
      cutoff = DateTime(baseDate.year, baseDate.month, baseDate.day);
    }

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
    if (payload == null) return;

    final title = payload['title'] ?? payload['body'] ?? payload['category'] ?? '';
    final body = payload['body'] ?? '';
    final tickerText = (body.isNotEmpty && body != title)
        ? '$title — $body'
        : title;

    final lat = double.tryParse(payload['lat']?.trim() ?? '');
    final lng = double.tryParse(payload['lng']?.trim() ?? '');
    final reportId = int.tryParse(payload['report_id']?.trim() ?? '');
    
    Map<String, dynamic>? targetComplaint;

    if (reportId != null) {
      for (final item in _allComplaints) {
        if ('${item['id']}' == '$reportId') {
          targetComplaint = item;
          break;
        }
      }
    }

    if (targetComplaint == null && lat != null && lng != null) {
      for (final item in _allComplaints) {
        final itemLat = item['lat'] ?? item['latitude'];
        final itemLng = item['lng'] ?? item['longitude'];
        if (itemLat is num && itemLng is num) {
          final d = _distance.as(
            LengthUnit.Meter,
            LatLng(lat, lng),
            LatLng(itemLat.toDouble(), itemLng.toDouble()),
          );
          if (d < 25) { // В пределах 25 метров
            targetComplaint = item;
            break;
          }
        }
      }
    }

    if (tickerText.isNotEmpty) {
      setState(() {
        _pushTickerText = tickerText;
        _pushTickerComplaint = targetComplaint;
        _isSpeakingPushTicker = false;
        _isPushTickerExpanded = false;
      });
    }

    if (targetComplaint != null) {
      final itemLat = targetComplaint['lat'] ?? targetComplaint['latitude'];
      final itemLng = targetComplaint['lng'] ?? targetComplaint['longitude'];
      if (itemLat is num && itemLng is num) {
        _animateMapTo(LatLng(itemLat.toDouble(), itemLng.toDouble()), 16.5, offsetForBottomSheet: true);
      }
      _showComplaintDetails(targetComplaint);
    } else if (lat != null && lng != null) {
      _animateMapTo(LatLng(lat, lng), 16.5, offsetForBottomSheet: true);
      if (payload['from_digest'] == 'true') {
        final synth = {
          'id': reportId ?? 9999,
          'title': payload['title'] ?? 'Происшествие',
          'description': payload['description'] ?? '',
          'lat': lat,
          'lng': lng,
          'address': payload['address'] ?? 'Нижневартовск',
          'category': payload['category'] ?? 'Прочее',
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        };
        _showComplaintDetails(synth);
      }
    }
    _pendingNotificationPayload = null;
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
        _eventMarkers = [];
        _eventMarkerItems.clear();
        _eventMarkerCategories.clear();
        _lostFoundMarkers = [];
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

    final filteredProblems = <Map<String, dynamic>>[];
    final filteredEvents = <Map<String, dynamic>>[];
    final filteredLostFound = <Map<String, dynamic>>[];
    final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
    int total = 0;
    int newCount = 0;
    int resolvedCount = 0;

    for (final rawItem in data) {
      final item = rawItem is Map<String, dynamic>
          ? rawItem
          : Map<String, dynamic>.from(rawItem);
      final rawLat = item['lat'] ?? item['latitude'];
      final rawLng = item['lng'] ?? item['longitude'];
      if (rawLat == null || rawLng == null) continue;

      double? lat;
      if (rawLat is num) lat = rawLat.toDouble();
      else if (rawLat is String) lat = double.tryParse(rawLat);

      double? lng;
      if (rawLng is num) lng = rawLng.toDouble();
      else if (rawLng is String) lng = double.tryParse(rawLng);

      if (lat == null || lng == null) continue;

      final isEvent = _isEventItem(item);
      final dt = _parseDateTime(item);
      final category = (item['category'] ?? 'Прочее').toString();
      final isLostFound = category == 'Животные' ||
          category == 'Вещи' ||
          category.contains('животное') ||
          category.contains('вещь') ||
          category.contains('Потеря') ||
          category.contains('Найдено');

      if (isLostFound) {
        filteredLostFound.add(item);
      } else if (isEvent) {
        final now = DateTime.now();
        if (dt == null || dt.year != now.year || dt.month != now.month || dt.day != now.day) {
          continue; // Показываем только мероприятия на текущий день!
        }
        filteredEvents.add(item);
      } else {
        total++;
        final isNew = dt != null && dt.isAfter(threeHoursAgo);
        if (isNew) newCount++;
        if ((item['status'] ?? 'open').toString().toLowerCase() == 'resolved') {
          resolvedCount++;
        }
        filteredProblems.add(item);
      }
    }

    // Рендерим маркеры проблем
    final problemMarkersList = <Marker>[];
    for (final item in filteredProblems) {
      try {
        final rawLat = item['lat'] ?? item['latitude'];
        final rawLng = item['lng'] ?? item['longitude'];
        final double lat = rawLat is num 
            ? rawLat.toDouble() 
            : double.tryParse(rawLat?.toString() ?? '') ?? 60.9344;
        final double lng = rawLng is num 
            ? rawLng.toDouble() 
            : double.tryParse(rawLng?.toString() ?? '') ?? 76.5531;

        final category = _normalizeCategoryLabel((item['category'] ?? 'Прочее') as String);
        problemMarkersList.add(_buildMarker(
          point: LatLng(lat, lng),
          status: (item['status'] ?? 'open') as String,
          category: category,
          complaint: item,
        ));
      } catch (e) {
        debugPrint('Ошибка обработки маркера: $e. Item: $item');
      }
    }

    // Рендерим маркеры мероприятий
    final eventMarkersList = <Marker>[];
    for (final item in filteredEvents) {
      try {
        final rawLat = item['lat'] ?? item['latitude'];
        final rawLng = item['lng'] ?? item['longitude'];
        final double lat = rawLat is num 
            ? rawLat.toDouble() 
            : double.tryParse(rawLat?.toString() ?? '') ?? 60.9344;
        final double lng = rawLng is num 
            ? rawLng.toDouble() 
            : double.tryParse(rawLng?.toString() ?? '') ?? 76.5531;

        final category = _normalizeCategoryLabel((item['category'] ?? 'Прочее') as String);
        eventMarkersList.add(_buildMarker(
          point: LatLng(lat, lng),
          status: (item['status'] ?? 'open') as String,
          category: category,
          complaint: item,
        ));
      } catch (e) {
        debugPrint('Ошибка обработки маркера мероприятия: $e. Item: $item');
      }
    }

    // Рендерим маркеры Бюро находок
    final lostFoundMarkersList = <Marker>[];
    for (final item in filteredLostFound) {
      try {
        lostFoundMarkersList.add(_buildLostFoundMarker(item));
      } catch (e) {
        debugPrint('Ошибка обработки маркера бюро находок: $e. Item: $item');
      }
    }

    // Подсчет категорий по всем отображаемым элементам
    final counts = <String, int>{};
    for (final item in [...filteredProblems, ...filteredEvents]) {
      final cat = _normalizeCategoryLabel((item['category'] ?? 'Прочее') as String);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _markers = problemMarkersList;
      _markerItems.clear();
      _markerCategories.clear();
      for (final item in filteredProblems) {
        _markerItems.add(item);
        _markerCategories.add(_normalizeCategoryLabel((item['category'] ?? 'Прочее') as String));
      }

      _eventMarkers = eventMarkersList;
      _eventMarkerItems.clear();
      _eventMarkerCategories.clear();
      for (final item in filteredEvents) {
        _eventMarkerItems.add(item);
        _eventMarkerCategories.add(_normalizeCategoryLabel((item['category'] ?? 'Прочее') as String));
      }

      _lostFoundMarkers = lostFoundMarkersList;

      _totalComplaints = total;
      _newComplaints = newCount;
      _resolvedComplaints = resolvedCount;
      _categoryCounts
        ..clear()
        ..addAll(counts);
    });
    _applyPendingNotificationFocus();
  }

  Marker _buildLostFoundMarker(Map<String, dynamic> item) {
    final rawLat = item['lat'] ?? item['latitude'];
    final rawLng = item['lng'] ?? item['longitude'];
    double lat = rawLat is num 
        ? rawLat.toDouble() 
        : double.tryParse(rawLat?.toString() ?? '') ?? 60.9344;
    double lng = rawLng is num 
        ? rawLng.toDouble() 
        : double.tryParse(rawLng?.toString() ?? '') ?? 76.5531;

    final category = (item['category'] ?? 'Прочее').toString();
    final title = (item['title'] ?? '').toString().toLowerCase();
    final description = (item['description'] ?? '').toString().toLowerCase();

    final isPhone = title.contains('телефон') || 
                    title.contains('смартфон') || 
                    title.contains('сотовый') ||
                    title.contains('iphone') ||
                    title.contains('phone') ||
                    description.contains('телефон') || 
                    description.contains('смартфон') || 
                    description.contains('сотовый') ||
                    description.contains('iphone') ||
                    description.contains('phone');

    final isAnimal = category.contains('животное') || category == 'Животные';
    
    final Color color;
    final IconData icon;
    String? customAsset;
    
    final text = '$title $description'.toLowerCase();
    
    if (isPhone) {
      color = const Color(0xFF00E5FF); // Premium neon cyan
      icon = Icons.smartphone_rounded;
      customAsset = 'assets/3d_icons/lost_phone_3d.png';
    } else if (isAnimal) {
      color = const Color(0xFFF59E0B);
      icon = Icons.pets_rounded;
      if (text.contains('кот') || text.contains('кошк') || text.contains('котенок')) {
        customAsset = 'assets/3d_icons/lost_cat_3d.png';
      } else if (text.contains('собак') || text.contains('пес') || text.contains('щенок') || text.contains('хаски')) {
        customAsset = 'assets/3d_icons/lost_dog_3d.png';
      } else {
        customAsset = 'assets/3d_icons/animals_3d.png';
      }
    } else {
      color = const Color(0xFF10B981);
      icon = Icons.backpack_rounded;
      if (text.contains('ключ')) {
        customAsset = 'assets/3d_icons/lost_keys_3d.png';
      } else if (text.contains('кошел') || text.contains('бумажн') || text.contains('портмоне') || text.contains('карт')) {
        customAsset = 'assets/3d_icons/lost_wallet_3d.png';
      } else if (text.contains('рюкзак') || text.contains('сумк') || text.contains('портфе') || text.contains('пакет')) {
        customAsset = 'assets/3d_icons/lost_backpack_3d.png';
      } else if (text.contains('документ') || text.contains('паспорт') || text.contains('прав') || text.contains('снилс')) {
        customAsset = 'assets/3d_icons/lost_passport_3d.png';
      } else if (text.contains('наушник') || text.contains('airpods')) {
        customAsset = 'assets/3d_icons/items_3d.png';
      } else if (text.contains('велосипед') || text.contains('самокат')) {
        customAsset = 'assets/3d_icons/items_3d.png';
      } else if (text.contains('очк')) {
        customAsset = 'assets/3d_icons/items_3d.png';
      } else if (text.contains('час')) {
        customAsset = 'assets/3d_icons/items_3d.png';
      } else if (text.contains('игрушк') || text.contains('мишк') || text.contains('кукл')) {
        customAsset = 'assets/3d_icons/items_3d.png';
      } else {
        customAsset = 'assets/3d_icons/items_3d.png';
      }
    }

    final seed = (((item['id'] ?? category.hashCode) as Object).hashCode.abs() % 997) / 997;

    return Marker(
      point: LatLng(lat, lng),
      width: 54,
      height: 54,
      child: GestureDetector(
        onTap: () {
          _emitSelectionHaptic();
          _zoomToComplaint(item);
          _showMapItemDetails(item);
        },
        child: AnimatedMapMarker(
          animation: _markerPulseController,
          color: color,
          icon: icon,
          size: 54,
          seed: seed,
          isDayMode: !_isNightMode,
          shell: MarkerShell.roundedSquare,
          custom3dAsset: customAsset,
        ),
      ),
    );
  }

  bool _matchesDistrict(Map<String, dynamic> item) {
    if (_selectedDistricts.isEmpty) return true;
    final lat = item['lat'] ?? item['latitude'];
    final lng = item['lng'] ?? item['longitude'];
    if (lat == null || lng == null) return false;
    final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
    final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;
    final point = LatLng(doubleLat, doubleLng);
    final cityDistricts = _activeCity.runtimeDistricts;
    
    final activeCityDistIds = cityDistricts.map((d) => d.id).toSet();
    final validSelectedDistricts = _selectedDistricts.where((id) => activeCityDistIds.contains(id)).toList();
    
    if (validSelectedDistricts.isEmpty) return true;
    
    for (final distId in validSelectedDistricts) {
      final dist = cityDistricts.firstWhere((d) => d.id == distId);
      final inPolygon = _activeCity.id == 'novosibirsk'
          ? NovosibirskDistricts.isPointInPolygon(point, dist.polygon)
          : NizhnevartovskDistricts.isPointInPolygon(point, dist.polygon);
      if (inPolygon) return true;
    }
    return false;
  }

  List<Marker> get _filteredProblemMarkers {
    return [
      for (var i = 0; i < _markers.length; i++)
        if (i < _markerCategories.length &&
            i < _markerItems.length &&
            _showProblemMarkers &&
            _matchesDistrict(_markerItems[i]) &&
            (_selectedCategories.isEmpty ||
                _selectedCategories.any((cat) =>
                    _normalizeCategoryLabel(_markerCategories[i]) ==
                    _normalizeCategoryLabel(cat))))
          _markers[i],
    ];
  }

  List<Marker> get _filteredEventMarkers {
    return [
      for (var i = 0; i < _eventMarkers.length; i++)
        if (i < _eventMarkerCategories.length &&
            i < _eventMarkerItems.length &&
            _showEventMarkers &&
            _matchesDistrict(_eventMarkerItems[i]) &&
            (_selectedCategories.isEmpty ||
                _selectedCategories.any((cat) =>
                    _normalizeCategoryLabel(_eventMarkerCategories[i]) ==
                    _normalizeCategoryLabel(cat))))
          _eventMarkers[i],
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // Анимация карты
  // ═══════════════════════════════════════════════════════════

  void _animateMapTo(LatLng targetCenter, double targetZoom, {bool offsetForBottomSheet = false}) {
    SoundService().playCameraMove();
    final camera = _mapController.camera;
    final startCenter = camera.center;
    final startZoom = camera.zoom;

    double finalLat = targetCenter.latitude;
    if (offsetForBottomSheet) {
      final double shift = targetZoom >= 16.0 ? 0.00095 : 0.0019;
      finalLat = finalLat - shift;
    }

    final latDiff = finalLat - startCenter.latitude;
    final lngDiff = targetCenter.longitude - startCenter.longitude;
    final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

    // Dynamic duration for cinematic flight: from 800ms to 2000ms
    final durationMs = (800 + (distance * 8000).clamp(0.0, 1200.0)).toInt();

    _mapMoveController?.stop();
    _mapMoveController?.dispose();

    final controller = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: this,
    );
    _mapMoveController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    final latTween = Tween<double>(begin: startCenter.latitude, end: finalLat);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: targetCenter.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

    controller.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_mapMoveController == controller) {
          _mapMoveController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _animateMapToCinematic(LatLng targetCenter, double targetZoom) {
    SoundService().playCameraMove();
    final camera = _mapController.camera;
    final startCenter = camera.center;
    final startZoom = camera.zoom;

    _mapMoveController?.stop();
    _mapMoveController?.dispose();

    final controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    _mapMoveController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    final latTween = Tween<double>(begin: startCenter.latitude, end: targetCenter.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: targetCenter.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

    controller.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_mapMoveController == controller) {
          _mapMoveController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  double _curveCubic(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
  }

  void _centerOnComplaint(Map<String, dynamic> complaint) {
    final lat = complaint['lat'] ?? complaint['latitude'];
    final lng = complaint['lng'] ?? complaint['longitude'];
    if (lat == null || lng == null) return;

    final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
    final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;

    _animateMapTo(
      LatLng(doubleLat, doubleLng),
      15.5,
      offsetForBottomSheet: true,
    );
  }

  void _zoomToComplaint(Map<String, dynamic> complaint) {
    final lat = complaint['lat'] ?? complaint['latitude'];
    final lng = complaint['lng'] ?? complaint['longitude'];
    if (lat == null || lng == null) return;

    final camera = _mapController.camera;
    _preZoomCenter = camera.center;
    _preZoomLevel = camera.zoom;

    setState(() {
      _focusedComplaint = complaint;
      _pulseSignalCategory = complaint['category']?.toString();
    });

    final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
    final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;

    _animateMapTo(
      LatLng(doubleLat, doubleLng),
      15.5,
      offsetForBottomSheet: true,
    );
  }

  void _zoomBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_preZoomCenter != null && _preZoomLevel != null) {
      _animateMapTo(_preZoomCenter!, _preZoomLevel!);
    } else {
      _animateMapTo(_activeCity.center, _activeCity.zoom);
    }
    setState(() {
      _focusFiltersHidden = false;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _focusedComplaint = null;
          _pulseSignalCategory = null;
          _preZoomCenter = null;
          _preZoomLevel = null;
        });
      }
    });
  }

  void _startRouteReplay(NavigationTrack track) {
    _stopRouteReplay();
    if (track.points.isEmpty) return;
    
    setState(() {
      _selectedTrack = track;
      _replayPoints = track.points;
      _replayCurrentIndex = 0;
    });
    
    _animateMapTo(_replayPoints.first, 15.0);
    
    _replayTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_replayCurrentIndex < _replayPoints.length - 1) {
          _replayCurrentIndex++;
          _animateMapTo(_replayPoints[_replayCurrentIndex], 15.0);
        } else {
          _stopRouteReplay();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Воспроизведение маршрута завершено')),
          );
        }
      });
    });
  }

  void _stopRouteReplay() {
    _replayTimer?.cancel();
    _replayTimer = null;
    setState(() {
      _replayCurrentIndex = -1;
      _replayPoints = [];
    });
  }

  Future<void> _startLiveRouteTracking() async {
    await _focusOnUserLocation();
    await NavigationHistoryService.instance.startTracking();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Начата запись маршрута в реальном времени'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );
  }

  Future<void> _stopLiveRouteTracking() async {
    final track = await NavigationHistoryService.instance.stopTracking();
    if (mounted) {
      if (track != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запись маршрута завершена: записано ${track.points.length} точек'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись маршрута остановлена'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      setState(() {});
    }
  }

  Widget _buildDockButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool highlighted = false,
  }) {
    final color = highlighted
        ? _uiAccent
        : (_isNightMode ? Colors.white.withOpacity(0.8) : const Color(0xFF243B53));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: highlighted
                  ? LinearGradient(
                      colors: [
                        _uiAccent.withOpacity(_isNightMode ? 0.28 : 0.20),
                        _uiAccent.withOpacity(_isNightMode ? 0.08 : 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: _isNightMode
                          ? [
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.15),
                            ]
                          : [
                              const Color(0xFFFFFFFF).withOpacity(0.85),
                              const Color(0xFFE2E8F0).withOpacity(0.50),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlighted
                    ? _uiAccent.withOpacity(0.85)
                    : (_isNightMode ? Colors.white.withOpacity(0.08) : const Color(0xFF0EA5C7).withOpacity(0.12)),
                width: highlighted ? 1.5 : 1.0,
              ),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: _uiAccent.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : (_isNightMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFF0EA5C7).withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Хелперы категорий
  // ═══════════════════════════════════════════════════════════

  IconData _getCategoryIcon(String category) {
    return PulseCategories.iconFor(category);
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
    final isEvent = _isEventItem(complaint);
    
    bool isCameraFavorite = false;
    bool isCameraAlarm = false;
    
    if (isCamera) {
      final streamUrl = (complaint['stream_url'] ??
              complaint['s'] ??
              MapConfig.cityCams[complaint['title']])
          ?.toString() ?? '';
      final canonicalStream = MapConfig.cameraAnalysisUrl(streamUrl);
      isCameraFavorite = _favoriteCameraUrls.any((fav) => 
        MapConfig.cameraAnalysisUrl(fav) == canonicalStream
      );
      
      final cStatus = complaint['status']?.toString().toLowerCase() ?? '';
      final cAlarm = complaint['active_alarm'] == true || complaint['alarm'] == true;
      isCameraAlarm = cStatus.contains('alarm') || cAlarm;
    }

    final color = isEvent
        ? const Color(0xFF8B5CF6) // Фиолетовый маркер для мероприятий
        : (isCamera
            ? (isCameraAlarm
                ? const Color(0xFFEF4444) // Красный для тревоги
                : (isCameraFavorite
                    ? const Color(0xFF10B981) // Зеленый для избранного
                    : const Color(0xFF00E5FF))) // Неоново-голубой для обычной
            : _getCategoryColor(category));

    final markerIcon = isCamera
        ? (isCameraAlarm
            ? Icons.warning_amber_rounded
            : (isCameraFavorite ? Icons.star_rounded : Icons.videocam_rounded))
        : _getCategoryIcon(category);

    final markerShell = isCamera
        ? MarkerShell.hexagon // 3D значки для камер
        : _getCategoryShell(category);

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
          setState(() {
            _focusFiltersHidden = true;
          });
          if (category == 'Камеры') {
            final streamUrl = (complaint['stream_url'] ??
                    complaint['s'] ??
                    MapConfig.cityCams[complaint['title']])
                ?.toString();
            _showLiveCamDialog(complaint['title'] ?? 'Камера', streamUrl).then((_) {
              _loadFavorites();
            });
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
          highlighted: _focusedComplaint != null && _focusedComplaint!['id'] == complaint['id'],
          custom3dAsset: isEvent ? 'assets/3d_icons/event_3d.png' : null,
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
    final initialIndex = _eventMarkerItems.indexWhere((e) => e['id'] == event['id']);
    final pageController = PageController(initialPage: initialIndex != -1 ? initialIndex : 0);
    var currentPageIndex = initialIndex != -1 ? initialIndex : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isNightMode = _isNightMode;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          child: MapGlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            padding: EdgeInsets.zero,
            fillColor: const Color(0xEA0B0F19),
            blurSigma: 26,
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                final currentEvent = _eventMarkerItems.isNotEmpty ? _eventMarkerItems[currentPageIndex] : event;
                final scheduledDate = _parseDateTime(currentEvent);
                final sourceLabel = currentEvent['source_label']?.toString().trim() ?? 'Городская афиша';
                final venue = currentEvent['venue']?.toString().trim();
                final link = currentEvent['link']?.toString().trim();
                final address = currentEvent['address']?.toString().trim();
                final description = currentEvent['description']?.toString().trim();

                return Column(
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
                    Expanded(
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: _eventMarkerItems.isNotEmpty ? _eventMarkerItems.length : 1,
                        onPageChanged: (index) {
                          setSheetState(() {
                            currentPageIndex = index;
                          });
                          if (_eventMarkerItems.isNotEmpty) {
                            final nextEvent = _eventMarkerItems[index];
                            final lat = nextEvent['latitude'] ?? nextEvent['lat'];
                            final lng = nextEvent['longitude'] ?? nextEvent['lng'];
                            if (lat != null && lng != null) {
                              final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 60.9;
                              final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 76.5;
                              _animateMapTo(LatLng(doubleLat, doubleLng), 15.5);
                            }
                            setState(() {
                              _focusedComplaint = nextEvent;
                              _pulseSignalCategory = nextEvent['category']?.toString() ?? 'Мероприятие';
                            });
                          }
                        },
                        itemBuilder: (ctx, pageIndex) {
                          final item = _eventMarkerItems.isNotEmpty ? _eventMarkerItems[pageIndex] : event;
                          final itemDate = _parseDateTime(item);
                          final itemSource = item['source_label']?.toString().trim() ?? 'Городская афиша';
                          final itemVenue = item['venue']?.toString().trim();
                          final itemAddress = item['address']?.toString().trim();
                          final itemDesc = item['description']?.toString().trim();

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Unified Event Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        categoryColor.withAlpha(72),
                                        const Color(0xFF0A0F1D),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: categoryColor.withAlpha(120)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Category3DBadge(
                                            category: item['category']?.toString() ?? 'Мероприятие',
                                            size: 56,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  item['title']?.toString() ?? 'Событие',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.15,
                                                  ),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              SoundService().isSpeakingTts
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.volume_up_rounded,
                                              color: categoryColor,
                                              size: 28,
                                            ),
                                            tooltip: 'Озвучить событие приятным голосом Ксении',
                                            onPressed: () async {
                                              if (SoundService().isSpeakingTts) {
                                                await SoundService().stopSpeak();
                                                setSheetState(() {});
                                              } else {
                                                final textToSpeak = [
                                                  item['title']?.toString(),
                                                  itemDesc != null && itemDesc.isNotEmpty ? itemDesc : null,
                                                ].whereType<String>().join('. ');
                                                
                                                setSheetState(() {});
                                                await SoundService().speak(textToSpeak, isEvent: true);
                                                setSheetState(() {});
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Date & Time
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded, color: categoryColor, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              itemDate == null
                                                  ? 'Время уточняется'
                                                  : _formatDate(itemDate.toIso8601String()),
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Place
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.place_rounded, color: categoryColor, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              [
                                                if (itemVenue != null && itemVenue.isNotEmpty) itemVenue,
                                                if (itemAddress != null && itemAddress.isNotEmpty) itemAddress,
                                              ].join(' — '),
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Description
                                if (itemDesc != null && itemDesc.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withAlpha(12)),
                                    ),
                                    child: Text(
                                      itemDesc,
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(220),
                                        fontSize: 14,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Action Buttons (Static)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: PopupMenuButton<Duration>(
                                  color: _colorSurface,
                                  onSelected: (offset) => _scheduleEventReminder(
                                    ctx,
                                    currentEvent,
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
                  ],
                );
              },
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

  void _showNavigatorSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        return Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: (screenWidth - 80.0).clamp(280.0, 500.0),
            child: NavigatorScreen(
              selectedTrack: _selectedTrack,
              onTrackSelected: (track) {
                _startRouteReplay(track);
              },
              onClearTrack: () {
                _stopRouteReplay();
                setState(() {
                  _selectedTrack = null;
                });
              },
              onStartTracking: () {
                _focusOnUserLocation();
              },
            ),
          ),
        );
      },
    );
  }

  void _onHouseAddressSelected(String address) {
    final houseSignals = _allComplaints.where((c) {
      final addr = c['address']?.toString();
      final isEvent = _isEventItem(c) || c['category'] == 'Мероприятие' || c['layer'] == 'city_events';
      return addr != null && addr.toLowerCase() == address.toLowerCase() && !isEvent;
    }).toList();

    LatLng? targetLatLng;
    if (houseSignals.isNotEmpty) {
      final firstSig = houseSignals.first;
      final lat = firstSig['latitude'] ?? firstSig['lat'];
      final lng = firstSig['longitude'] ?? firstSig['lng'];
      if (lat != null && lng != null) {
        final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 60.9;
        final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 76.5;
        targetLatLng = LatLng(doubleLat, doubleLng);
      }
    } else if (_highlightedMapPosition != null && _highlightedHouseAddress?.toLowerCase() == address.toLowerCase()) {
      targetLatLng = _highlightedMapPosition;
    }

    if (targetLatLng != null) {
      _animateMapTo(targetLatLng, 16.0);
      setState(() {
        _highlightedMapPosition = targetLatLng;
        _highlightedHouseAddress = address;
      });
    }

    _showHouseSignalsSheet(address, houseSignals);
  }

  void _onHouseAddressTyped(String address) {
    if (address.isEmpty) {
      _houseGeocodeDebounce?.cancel();
      setState(() {
        _highlightedMapPosition = null;
        _highlightedHouseAddress = null;
      });
      return;
    }

    final houseSignals = _allComplaints.where((c) {
      final addr = c['address']?.toString();
      final isEvent = _isEventItem(c) || c['category'] == 'Мероприятие' || c['layer'] == 'city_events';
      return addr != null && addr.toLowerCase() == address.toLowerCase() && !isEvent;
    }).toList();

    if (houseSignals.isNotEmpty) {
      _houseGeocodeDebounce?.cancel();
      final firstSig = houseSignals.first;
      final lat = firstSig['latitude'] ?? firstSig['lat'];
      final lng = firstSig['longitude'] ?? firstSig['lng'];

      if (lat != null && lng != null) {
        final doubleLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 60.9;
        final doubleLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 76.5;
        setState(() {
          _highlightedMapPosition = LatLng(doubleLat, doubleLng);
          _highlightedHouseAddress = address;
        });
        _animateMapTo(LatLng(doubleLat, doubleLng), 16.0);
      }
    } else {
      // Debounce the Nominatim network request so we don't query on every keystroke
      _houseGeocodeDebounce?.cancel();
      _houseGeocodeDebounce = Timer(const Duration(milliseconds: 500), () async {
        try {
          final queryStr = address.contains('Нижневартовск') ? address : 'Нижневартовск, $address';
          final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(queryStr)}&format=json&limit=1');
          final response = await http.get(url, headers: {'User-Agent': 'CityPulse/1.0'});
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as List;
            if (data.isNotEmpty) {
              final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
              final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
              if (lat != null && lon != null) {
                if (mounted) {
                  setState(() {
                    _highlightedMapPosition = LatLng(lat, lon);
                    _highlightedHouseAddress = address;
                  });
                  _animateMapTo(LatLng(lat, lon), 16.0);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error geocoding typed address: $e');
        }
      });
    }
  }

  void _showHouseSignalsSheet(String address, List<Map<String, dynamic>> houseSignals) {
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
            fillColor: const Color(0xEA0B0F19),
            blurSigma: 26,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.home_work_rounded, color: _uiAccent, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'СИГНАЛЫ ПО АДРЕСУ',
                              style: TextStyle(
                                color: _uiAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: houseSignals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.mark_email_unread_outlined, color: Colors.white30, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'По этому адресу сигналов нет',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Вы можете подать первый сигнал на карте!',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: houseSignals.length,
                    itemBuilder: (ctx, index) {
                      final sig = houseSignals[index];
                      final cat = sig['category']?.toString() ?? 'Прочее';
                      final catColor = _getCategoryColor(cat);
                      final catIcon = _getCategoryIcon(cat);
                      final title = sig['title']?.toString() ?? 'Сигнал';
                      final desc = sig['description']?.toString() ?? '';
                      final dateStr = sig['created_at']?.toString() ?? '';
                      final status = sig['status']?.toString() ?? 'Активно';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _zoomToComplaint(sig);
                            _showComplaintDetails(sig);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: catColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(catIcon, color: catColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$cat • $dateStr',
                                        style: TextStyle(
                                          color: _uiTextSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                desc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _highlightedMapPosition = null;
          _highlightedHouseAddress = null;
        });
      }
    });
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

  Future<void> _showLiveCamDialog(String title, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на трансляцию не найдена')),
      );
      return;
    }

    final playUrl = MapConfig.cameraPlaybackUrl(url);

    await showDialog(
      context: context,
      builder: (ctx) => VideoPlayerDialog(title: title, url: playUrl),
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

    return PopScope(
      canPop: !_showWeatherOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showWeatherOverlay) {
          _closeWeatherOverlay();
        }
      },
      child: Scaffold(
        body: Stack(
        children: [
          // Карта (бесплатная подложка OSM)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: MapConfig.initialZoom,
              minZoom: _activeCity.id == 'novosibirsk' ? 9.8 : 11.2,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: _activeCity.id == 'novosibirsk'
                    ? LatLngBounds(const LatLng(54.7, 82.5), const LatLng(55.25, 83.3))
                    : LatLngBounds(const LatLng(60.83, 76.25), const LatLng(61.05, 76.85)),
              ),
              backgroundColor: _isNightMode ? const Color(0xFF0C1424) : const Color(0xFFF5FAFF),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _registerMapMovement();
                  _updateDistrictUnderCenter(position.center);
                }
                if (_showUkLayer && hasGesture) {
                  _fetchUkForCenter();
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                _resetInactivityTimer();
              },
            ),
            children: [
              if (!_isSatellite)
                OfflineTilesService.instance.getTileLayer(
                  MapConfig.tileUrl,
                  isNightMode: _isNightMode,
                )
              else
                OfflineTilesService.instance.getTileLayer(
                  MapConfig.satelliteUrl,
                  isNightMode: _isNightMode,
                ),
              AnimatedBuilder(
                animation: Listenable.merge([_markerPulseController, _districtFadeController ?? const AlwaysStoppedAnimation(0.0)]),
                builder: (context, _) {
                  final pulseVal = 0.5 + 0.5 * math.sin(_markerPulseController.value * 2 * math.pi);
                  final fadeVal = _districtFadeController?.value ?? 0.0;
                  final highlightFactor = fadeVal < 0.8 ? 1.0 : (1.0 - (fadeVal - 0.8) / 0.2);
                  return PolygonLayer(
                    polygons: [
                      for (final dist in _activeCity.runtimeDistricts)
                        Polygon(
                          points: dist.polygon,
                          color: _selectedDistrictForHighlight?.id == dist.id
                              ? _uiPrimary.withOpacity(0.015 + (0.18 - 0.015) * highlightFactor)
                              : Colors.transparent,
                          borderColor: _selectedDistrictForHighlight?.id == dist.id
                              ? _uiPrimary.withOpacity(0.12 + (0.8 - 0.12) * highlightFactor)
                              : Colors.transparent,
                          borderStrokeWidth: _selectedDistrictForHighlight?.id == dist.id
                              ? (1.2 + (3.5 - 1.2) * highlightFactor)
                              : 0.0,
                        ),
                    ],
                  );
                },
              ),
              if (_selectedDistrictForHighlight != null && _districtHighlightCenter != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _districtHighlightCenter!,
                      width: 260,
                      height: 54,
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _districtFadeController!,
                        builder: (context, _) {
                          final progress = _districtFadeController!.value;
                          final fadeOpacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);
                          return Opacity(
                            opacity: fadeOpacity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: Text(
                                _selectedDistrictForHighlight!.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  if (_selectedRoutePath != null)
                    Polyline(
                      points: _selectedRoutePath!,
                      color: _isNightMode 
                          ? (_selectedRouteColor ?? _uiAccent) 
                          : Colors.blue.shade700,
                      strokeWidth: 4.5,
                    ),
                  if (_selectedTrack != null)
                    Polyline(
                      points: _selectedTrack!.points,
                      color: _isNightMode 
                          ? const Color(0xFF00E5FF) 
                          : Colors.blue.shade600,
                      strokeWidth: 4.5,
                      borderColor: _isNightMode 
                          ? const Color(0xFF0F172A) 
                          : Colors.white.withOpacity(0.9),
                      borderStrokeWidth: _isNightMode ? 1.0 : 2.0,
                    ),
                  if (_liveTrackPoints.isNotEmpty)
                    Polyline(
                      points: _liveTrackPoints,
                      color: _isNightMode 
                          ? const Color(0xFF10B981) 
                          : Colors.green.shade600,
                      strokeWidth: 4.5,
                      borderColor: _isNightMode 
                          ? const Color(0xFF0F172A) 
                          : Colors.white.withOpacity(0.9),
                      borderStrokeWidth: _isNightMode ? 1.0 : 2.0,
                    ),
                ],
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  polygonOptions: PolygonOptions(
                    borderColor: _uiAccent.withOpacity(0.65),
                    color: _uiAccent.withOpacity(0.08),
                    borderStrokeWidth: 1.5,
                  ),
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _filteredProblemMarkers,
                  onMarkerTap: (Marker marker) {
                    // Each marker already handles its own tap via GestureDetector
                    // inside _buildMarker — the onTap closure captures the correct
                    // complaint item regardless of city or filter state.
                  },
                  builder: (context, markers) {
                    return _PointCloudClusterWidget(
                      count: markers.length,
                      isNightMode: _isNightMode,
                      primaryColor: _uiPrimary,
                      glowColor: _uiGlow,
                    );
                  },
                ),
              ),
              // Мероприятия отдельным слоем без кластеризации
              if (_showEventMarkers && _filteredEventMarkers.isNotEmpty)
                MarkerLayer(markers: _filteredEventMarkers),
              if (_showCamerasLayer) MarkerLayer(markers: _cameraMarkers),
              if (_showLostFoundLayer && _lostFoundMarkers.isNotEmpty)
                MarkerLayer(markers: _lostFoundMarkers),
              if (_focusedComplaint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: (() {
                        final dynamic rawLat = _focusedComplaint!['latitude'] ?? _focusedComplaint!['lat'];
                        final dynamic rawLng = _focusedComplaint!['longitude'] ?? _focusedComplaint!['lng'];
                        final double lat = rawLat is num
                            ? rawLat.toDouble()
                            : double.tryParse(rawLat.toString()) ?? 0.0;
                        final double lng = rawLng is num
                            ? rawLng.toDouble()
                            : double.tryParse(rawLng.toString()) ?? 0.0;
                        return LatLng(lat, lng);
                      })(),
                      width: 150,
                      height: 150,
                      child: IgnorePointer(
                        child: _FocusedMarkerRipple(
                          color: _uiAccent,
                        ),
                      ),
                    ),
                  ],
                ),
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
              if (_highlightedMapPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _highlightedMapPosition!,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          if (_highlightedHouseAddress != null) {
                            _onHouseAddressSelected(_highlightedHouseAddress!);
                          } else {
                            setState(() {
                              _highlightedMapPosition = null;
                            });
                          }
                        },
                        child: AnimatedMapMarker(
                          animation: _markerPulseController,
                          color: Colors.redAccent,
                          icon: Icons.place_rounded,
                          size: 50,
                          seed: 0.1,
                          isDayMode: !_isNightMode,
                          shell: MarkerShell.circle,
                          highlighted: true,
                        ),
                      ),
                    ),
                  ],
                ),
              if (_replayCurrentIndex >= 0 && _replayCurrentIndex < _replayPoints.length)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _replayPoints[_replayCurrentIndex],
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF00E5FF),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
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

          // Шейдерный слой поверх карты (динамическая погода / сетка)
          if (_ambientShaderEnabled && (_currentRainDensity > 0.05 || _currentFogDensity > 0.05 || _currentHoloDensity > 0.05))
            Positioned.fill(
              child: IgnorePointer(
                child: GpuShaderBackground(
                  shaderAsset: 'shaders/weather_overlay.frag',
                  onSetUniforms: (shader, time, size) {
                    shader.setFloat(0, size.width);
                    shader.setFloat(1, size.height);
                    shader.setFloat(2, time);
                    shader.setFloat(3, _currentRainDensity);
                    shader.setFloat(4, _currentFogDensity);
                    shader.setFloat(5, _currentHoloDensity);
                  },
                ),
              ),
            ),

          // Прозрачный перехватчик касаний для выхода из режима скрытых фильтров в режиме Дзен
          if (_isZenMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _onScreenTouched(),
                onPanDown: (_) => _onScreenTouched(),
                child: const SizedBox(),
              ),
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
              child: Center(
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
                  showProblems: _showProblemMarkers,
                  showEvents: _showEventMarkers,
                  showCameras: _showCamerasLayer,
                  isSatellite: _isSatellite,
                  onToggleProblems: () {
                    setState(() => _showProblemMarkers = !_showProblemMarkers);
                    _saveMapState();
                  },
                  onToggleEvents: () {
                    setState(() => _showEventMarkers = !_showEventMarkers);
                    _saveMapState();
                  },
                  onToggleCameras: () => unawaited(_toggleCameraLayer()),
                  onToggleMapStyle: () {
                    setState(() => _isSatellite = !_isSatellite);
                    _saveMapState();
                  },
                  onMapMenuSheet: _showMapMenuSheet,
                  onToggleTheme: _toggleVisualMode,
                  showLostFound: _showLostFoundLayer,
                  onToggleLostFound: () {
                    _emitSelectionHaptic();
                    setState(() => _showLostFoundLayer = !_showLostFoundLayer);
                    _saveMapState();
                  },

                  onCityChanged: _onCityChanged,
                  latestSignalCategory: _pulseSignalCategory,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: ClipRect(
                    child: SizedBox(
                      height: _shouldShowFilterPanel ? null : 0.0,
                      child: AnimatedOpacity(
                        opacity: _shouldShowFilterPanel ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 350),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              MapFilterPanel(
                                selectedDaysFilter: _selectedDaysFilter,
                                selectedCategories: _selectedCategories,
                                selectedDistricts: _selectedDistricts,
                                totalComplaints: _totalComplaints,
                                categoryCounts: _categoryCounts,
                                uiTextPrimary: _uiTextPrimary,
                                uiTextSecondary: _uiTextSecondary,
                                uiPanelFill: _uiPanelFill,
                                uiGlow: _uiGlow,
                                uiAccent: _uiAccent,
                                isNightMode: _isNightMode,
                                districts: _activeCity.runtimeDistricts,
                                allSignals: _allComplaints,
                                onDaysFilterChanged: (days) {
                                  _emitSelectionHaptic();
                                  setState(() => _selectedDaysFilter = days);
                                  if (_allComplaints.isNotEmpty) {
                                    _processComplaints(_filterByDate(_allComplaints));
                                  }
                                },
                                onCategoriesChanged: (list) {
                                  _emitSelectionHaptic();
                                  final newAdded = list.firstWhere(
                                    (cat) => !_selectedCategories.contains(cat),
                                    orElse: () => '',
                                  );
                                  setState(() => _selectedCategories = list);
                                  _saveMapState();
                                  if (newAdded.isNotEmpty) {
                                    SoundService().playCategorySound(newAdded);
                                  }
                                },
                                onDistrictsChanged: (list) {
                                  _emitSelectionHaptic();
                                  _onDistrictsChanged(list);
                                },
                                onAddressSelected: (address) {
                                  _emitSelectionHaptic();
                                  _onHouseAddressSelected(address);
                                },
                                onAddressTyped: _onHouseAddressTyped,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_focusedComplaint != null)
            Positioned(
              bottom: 350,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'zoom_back_fab',
                backgroundColor: _uiPanelFillStrong,
                foregroundColor: _uiTextPrimary,
                elevation: 4,
                onPressed: _zoomBack,
                child: const Icon(Icons.center_focus_weak_rounded, size: 20),
              ),
            ),



          // Боковой премиальный док управления (Side Dock)
          if (MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
              left: !AppStateService.instance.state.isMenuOnRight ? 16 : null,
              right: AppStateService.instance.state.isMenuOnRight ? 16 : null,
              bottom: (204.0 - MediaQuery.of(context).viewInsets.bottom).clamp(16.0, 204.0),
            child: IgnorePointer(
              ignoring: !_isRightPanelVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _isRightPanelVisible ? 1.0 : 0.0,
                child: SafeArea(
                  child: MapGlassPanel(
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    fillColor: _uiPanelFill,
                    blurSigma: _isRightPanelVisible ? 22 : 0.0,
                child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // AI Assistant
                        _buildDockButton(
                           icon: Icons.support_agent_rounded,
                           tooltip: 'AI Ассистент',
                           highlighted: false,
                           onPressed: () {
                             _emitSelectionHaptic();
                             Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                             );
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // AI Digest
                        _buildDockButton(
                           icon: Icons.newspaper_rounded,
                           tooltip: 'AI Дайджест',
                           highlighted: false,
                           onPressed: () {
                             _emitSelectionHaptic();
                             Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => const AiDigestScreen()),
                             );
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // Бюро находок (Экран списка)
                        _buildDockButton(
                           icon: Icons.manage_search_rounded,
                           tooltip: 'Бюро находок (Список)',
                           highlighted: false,
                           onPressed: () {
                             _emitSelectionHaptic();
                             Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => const LostAndFoundScreen()),
                             );
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // AR Camera Overlay (AI Камера)
                        _buildDockButton(
                           icon: Icons.camera_enhance_rounded,
                           tooltip: 'AR-маркеры',
                           highlighted: false,
                           onPressed: () {
                             _emitSelectionHaptic();
                             Navigator.of(context).push(
                               MaterialPageRoute(
                                 builder: (_) => ArMarkersScreen(signals: _markerItems),
                               ),
                             );
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // Navigator
                        _buildDockButton(
                           icon: Icons.navigation_rounded,
                           tooltip: 'Навигатор',
                           highlighted: _selectedTrack != null || _liveTrackPoints.isNotEmpty,
                           onPressed: () async {
                             _emitSelectionHaptic();
                             _showNavigatorSheet();
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // Погода
                        _buildDockButton(
                           icon: Icons.filter_drama_rounded,
                           tooltip: 'Погода',
                           highlighted: _showWeatherOverlay,
                           onPressed: () {
                             _emitSelectionHaptic();
                             setState(() => _showWeatherOverlay = !_showWeatherOverlay);
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // Toggle Filters
                        _buildDockButton(
                           icon: _userFiltersHidden ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                           tooltip: 'Показать фильтры',
                           highlighted: !_userFiltersHidden,
                           onPressed: () {
                             _emitSelectionHaptic();
                             setState(() {
                               _userFiltersHidden = !_userFiltersHidden;
                               if (!_userFiltersHidden && _isZenMode) {
                                 _showFiltersInZen = true;
                               }
                             });
                           },
                        ),
                        const SizedBox(height: 6),
                        
                        // Общий вид
                        _buildDockButton(
                           icon: Icons.explore_rounded,
                           tooltip: 'Общий вид',
                           highlighted: false,
                           onPressed: () {
                             _emitSelectionHaptic();
                             _animateMapTo(_activeCity.center, _activeCity.zoom);
                           },
                        ).animate(target: _isRightPanelVisible ? 1.0 : 0.0)
                         .fadeIn(delay: 490.ms, duration: 200.ms)
                         .slideX(begin: 2.0, end: 0.0, delay: 490.ms, curve: Curves.easeOutBack, duration: 350.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),




          if (_showWeatherOverlay)
            Positioned.fill(
              child: WeatherOverlayPanel(
                weather: _weather,
                alerts: _cityAlerts,
                onClose: _closeWeatherOverlay,
                isNightMode: _isNightMode,
                accent: _uiAccent,
              ),
            ),



          _buildFocusedOverlay(),

          // Confetti overlay on successful submission
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF00E5FF),
                Color(0xFF7C4DFF),
                Color(0xFFFFC857),
                Color(0xFF00E676),
              ],
            ),
          ),
          
          if (!_showWeatherOverlay)
            Positioned(
              bottom: _userFiltersHidden ? 134 : 74,
              right: 16,
              child: _buildPrimaryActionFab(),
            ),

          // Слайдер сигналов внизу экрана (отображается при скрытом блоке фильтров)
          if (_userFiltersHidden && !_showWeatherOverlay && _allComplaints.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: _pushTickerText != null ? 50 : MediaQuery.of(context).padding.bottom + 4,
              child: SignalCarouselSlider(
                signals: _allComplaints,
                isNightMode: _isNightMode,
                onSignalFocused: (signal) {
                  final dynamic rawLat = signal['lat'] ?? signal['latitude'];
                  final dynamic rawLng = signal['lng'] ?? signal['longitude'];
                  final double? lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '');
                  final double? lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '');
                  if (lat != null && lng != null) {
                    _animateMapTo(LatLng(lat, lng), 16.5);
                  }
                },
                onSignalTapped: _showComplaintDetails,
              ),
            ),
          
          // Пуш-тикер: бегущая строка при тапе на уведомление (поверх кнопок подачи сигнала)
          if (_pushTickerText != null)
            _buildPushTicker(_pushTickerText!),
          
          if (_showOnboarding)
            OnboardingOverlay(
              onFinished: _finishOnboarding,
            ),
        ],
      ),
    ),
  );
}

  // ═══════════════════════════════════════════════════════════
  // Меню карты
  // ═══════════════════════════════════════════════════════════

  Widget _buildMenuCategoryChip({
    required String? categoryName,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _emitSelectionHaptic();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(_isNightMode ? 0.05 : 0.4),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.white.withOpacity(_isNightMode ? 0.15 : 0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? color : _uiTextSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMenuDistrictChip({
    required String? districtId,
    required String shortName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = _uiAccent;
    return GestureDetector(
      onTap: () {
        _emitSelectionHaptic();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? activeColor.withOpacity(0.2)
              : Colors.white.withOpacity(_isNightMode ? 0.05 : 0.4),
          border: Border.all(
            color: isSelected
                ? activeColor
                : Colors.white.withOpacity(_isNightMode ? 0.15 : 0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            shortName,
            style: TextStyle(
              color: isSelected ? activeColor : _uiTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_isNightMode ? 0.04 : 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(_isNightMode ? 0.12 : 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _uiAccent, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _uiTextPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapMenuSheet() {
    _emitSelectionHaptic();
    MapMenuSheet.show(
      context: context,
      sheet: MapMenuSheet(
        isNightMode: _isNightMode,
        uiTextPrimary: _uiTextPrimary,
        uiTextSecondary: _uiTextSecondary,
        uiAccent: _uiAccent,
        uiGlow: _uiGlow,
        meshConnected: MeshNetworkService().isConnected,
        showSecretCameras: _secretCamerasEnabled,
        secretCamerasSubtitle: _secretCamerasEnabled ? 'Камеры онлайн' : 'Не активно',
        totalComplaints: _totalComplaints,
        activeCamerasCount: _cameraMarkers.length,
        onClose: () => Navigator.of(context).pop(),
        onToggleTheme: () {
          Navigator.of(context).pop();
          _toggleVisualMode();
        },
        onOpenProfile: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        },
        onOpenUk: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UkCompaniesScreen()));
        },
        onOpenMesh: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeshScreen()));
        },
        onOpenSettings: () async {
          Navigator.of(context).pop();
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          unawaited(_restoreVoiceAnnouncementsPreference());
        },
        onOpenAbout: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
        },
        onOpenPrivacy: () {
          Navigator.of(context).pop();
          launchUrl(Uri.parse('https://citypulse.ru/privacy'), mode: LaunchMode.externalApplication);
        },
        onOpenLegal: () {
          Navigator.of(context).pop();
          launchUrl(Uri.parse('https://citypulse.ru/terms'), mode: LaunchMode.externalApplication);
        },
        onOpenSecretCameras: () async {
          Navigator.of(context).pop();
          await _ensureSecretCameraSession();
        },
        onOpenAiDigest: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiDigestScreen()));
        },
        onOpenAiAssistant: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
        },
        onOpenMemes: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemeScreen()));
        },
        onOpenLostFound: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LostAndFoundScreen()));
        },
        onOpenInfographics: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Раздел находится в обновлении')),
          );
        },
        onOpenPanorama: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CityPanoramaScreen()));
        },
        onOpenAr: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArMarkersScreen(signals: _markerItems)));
        },
        onOpenGamification: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamificationScreen()));
        },
      ),
    );
  }

  String _getShortDistrictName(String fullName) {
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(fullName);
    if (match != null) {
      return match.group(0)!;
    }
    if (fullName.length > 2) {
      return fullName.substring(0, 2);
    }
    return fullName;
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
            child: Text('ЗАКРЫТЬ',
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
                      Icon(Icons.business_rounded, color: _colorAccent),
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

  /// Убираем краткий анализ из текста, оставляем только описание
  String _stripAnalysisFromText(String fullText) {
    final lower = fullText.toLowerCase();
    const markers = [
      'краткий анализ ситуации',
      'краткий анализ',
      'анализ ситуации:',
      'анализ (ии):',
      '• важность:',
      '• масштаб:',
    ];
    for (final marker in markers) {
      final idx = lower.indexOf(marker);
      if (idx != -1) {
        return fullText.substring(0, idx).trim();
      }
    }
    return fullText.trim();
  }

  /// Бегущая строка пуш-уведомления внизу карты (с поддержкой раскрытия по нажатию)
  Widget _buildPushTicker(String text) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: safeBottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, 60 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: MapGlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            fillColor: _uiPanelFillStrong,
            blurSigma: 22,
            borderColors: [
              _uiGlow.withAlpha(_isNightMode ? 130 : 48),
              Colors.transparent,
            ],
            child: Row(
              crossAxisAlignment: _isPushTickerExpanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                // Бегущая строка или развернутый текст
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isPushTickerExpanded = !_isPushTickerExpanded;
                      });
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _isPushTickerExpanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notification_important_rounded,
                                      size: 14,
                                      color: _uiGlow,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'СООБЩЕНИЕ СИСТЕМЫ',
                                      style: TextStyle(
                                        color: _uiGlow,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _stripAnalysisFromText(text),
                                  style: TextStyle(
                                    color: _uiTextPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    Map<String, dynamic>? complaint = _pushTickerComplaint;
                                    if (complaint == null) {
                                      final queryText = text.toLowerCase();
                                      for (final c in _allComplaints) {
                                        final title = (c['title'] ?? '').toString().toLowerCase();
                                        final desc = (c['description'] ?? c['summary'] ?? '').toString().toLowerCase();
                                        if (queryText.contains(title) || (desc.isNotEmpty && queryText.contains(desc))) {
                                          complaint = c;
                                          break;
                                        }
                                      }
                                    }
                                    if (complaint != null) {
                                      final c = complaint;
                                      return GestureDetector(
                                        onTap: () {
                                          final lat = c['lat'] ?? c['latitude'];
                                          final lng = c['lng'] ?? c['longitude'];
                                          if (lat is num && lng is num) {
                                            _animateMapTo(LatLng(lat.toDouble(), lng.toDouble()), 16.5);
                                          }
                                          _showComplaintDetails(c);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _uiGlow.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _uiGlow.withOpacity(0.3), width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.location_on_rounded, size: 12, color: _uiGlow),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Показать на карте',
                                                style: TextStyle(
                                                  color: _uiGlow,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            )
                          : _MarqueeText(
                              text: text,
                              style: TextStyle(
                                color: _uiTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка озвучки (Воспроизведение/Пауза)
                GestureDetector(
                  onTap: () async {
                    if (_isSpeakingPushTicker) {
                      await SoundService().stopSpeak();
                      setState(() {
                        _isSpeakingPushTicker = false;
                      });
                    } else {
                      setState(() {
                        _isSpeakingPushTicker = true;
                      });
                      await SoundService().speak(text);
                      SoundService().onTtsComplete.first.then((_) {
                        if (mounted) {
                          setState(() {
                            _isSpeakingPushTicker = false;
                          });
                        }
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isSpeakingPushTicker
                          ? _uiGlow.withAlpha(50)
                          : _uiPanelFillStrong,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSpeakingPushTicker
                            ? _uiGlow.withAlpha(180)
                            : _uiGlow.withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      _isSpeakingPushTicker
                          ? Icons.volume_up_rounded
                          : Icons.volume_mute_rounded,
                      color: _isSpeakingPushTicker ? _uiGlow : _uiTextSecondary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Закрыть
                GestureDetector(
                  onTap: () {
                    SoundService().stopSpeak();
                    setState(() {
                      _pushTickerText = null;
                      _pushTickerComplaint = null;
                      _isSpeakingPushTicker = false;
                      _isPushTickerExpanded = false;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isNightMode
                          ? Colors.white.withAlpha(12)
                          : Colors.black.withAlpha(12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: _uiTextSecondary, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openComplaintComposer() async {
    final center = _mapController.camera.center;
    AnalyticsService.trackEvent('complaint_started');
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComplaintFormScreen(
          initialCenter: LatLng(center.latitude, center.longitude),
        ),
      ),
    );
    if (result is Map && result['action'] == 'show_on_map' && mounted) {
      final double lat = (result['lat'] as num).toDouble();
      final double lng = (result['lng'] as num).toDouble();
      final target = LatLng(lat, lng);
      setState(() {
        _highlightedMapPosition = target;
      });
      _animateMapTo(target, 16.5);
    } else if (result == true && mounted) {
      _loadComplaints();
      _triggerSuccessConfetti();
    }
  }

  void _triggerSuccessConfetti() {
    _confettiController.play();
  }

  // ── Oil Drop Pulse Ring ──
  Widget _buildFabPulseRing(double progress, double visibility) {
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.5 * visibility;
    final isNsk = _activeCity.id == 'novosibirsk';
    final Color mainColor = isNsk ? const Color(0xFF00E5FF) : const Color(0xFFD4A537);

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 1 + progress * 0.8,
          child: SizedBox(
            width: 72,
            height: 88,
            child: CustomPaint(
              painter: _OilDropBorderPainter(
                cityId: _activeCity.id,
                color: mainColor.withAlpha(
                  (opacity * (_isNightMode ? 255 : 165)).round(),
                ),
                strokeWidth: 1.2,
                glowColor: mainColor.withAlpha(
                  math.max(0, math.min(
                    _isNightMode ? 120 : 62,
                    (opacity * (_isNightMode ? 120 : 62)).round(),
                  )),
                ),
                glowRadius: _isNightMode ? 22 : 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionFab() {
    final isNsk = _activeCity.id == 'novosibirsk';
    
    const Color nskBlue = Color(0xFF00E5FF);
    const Color nskBlueLight = Color(0xFFE0F7FA);
    const Color nskBlueDeep = Color(0xFF00B8D4);
    
    const Color oilGold = Color(0xFFD4A537);
    const Color oilGoldLight = Color(0xFFE8C555);
    const Color oilGoldDeep = Color(0xFFB8860B);
    
    final Color mainColor = isNsk ? nskBlue : oilGold;
    final Color mainColorLight = isNsk ? nskBlueLight : oilGoldLight;
    final Color mainColorDeep = isNsk ? nskBlueDeep : oilGoldDeep;
    
    const Color oilBlack = Color(0xFF0D0D0D);
    const Color oilBlackLight = Color(0xFF1A1A1A);

    return Tooltip(
      message: isNsk ? 'Подать сигнал — Наука Сибири' : 'Подать сигнал — Пульс города',
      child: Semantics(
        label: 'Подать сигнал',
        button: true,
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
                  math.sin(progress * math.pi * 2) * (_isMapMoving ? 1.5 : 4.5);
              final scale = _isMapMoving
                  ? 1.0
                  : 1.0 + math.sin(progress * math.pi * 2) * 0.035;
              final glowAlpha = _isMapMoving
                  ? (_isNightMode ? 90 : 50)
                  : (_isNightMode ? 170 : 95);
                  
              final rotation = isNsk ? (math.sin(progress * math.pi * 2) * 0.15) : 0.0;

              return SizedBox(
                width: 90,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildFabPulseRing(progress, visibility),
                    _buildFabPulseRing(secondaryProgress, visibility * 0.85),

                    IgnorePointer(
                      child: SizedBox(
                        width: 82,
                        height: 98,
                        child: CustomPaint(
                          painter: _OilDropGlowPainter(
                            cityId: _activeCity.id,
                            glowColor: mainColor.withAlpha(glowAlpha),
                            blurRadius: _isNightMode ? 28 : 14,
                          ),
                        ),
                      ),
                    ),

                    Transform.translate(
                      offset: Offset(0, -bob),
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: 66,
                          height: 82,
                          child: CustomPaint(
                            painter: _OilDropButtonPainter(
                              cityId: _activeCity.id,
                              fillColors: const [oilBlack, oilBlackLight, oilBlack],
                              borderColor: mainColor.withAlpha(_isNightMode ? 220 : 180),
                              borderColors: [mainColor.withAlpha(220), mainColor.withAlpha(120)],
                              borderWidth: 1.5,
                              shadowColor: mainColor.withAlpha(glowAlpha),
                              shadowBlur: _isNightMode ? 30 : 14,
                              innerGlowColor: mainColorLight.withAlpha(
                                _isNightMode ? 40 : 22,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.rotate(
                                      angle: rotation,
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [mainColorLight, mainColor, mainColorDeep],
                                        ).createShader(bounds),
                                        blendMode: BlendMode.srcIn,
                                        child: Icon(
                                          isNsk ? Icons.science_rounded : Icons.monitor_heart_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [mainColorLight, mainColor],
                                      ).createShader(bounds),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        isNsk ? 'НАУКА' : 'ПУЛЬС',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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

/// Бегущая строка — прокручивает текст горизонтально, если он не помещается
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll = ScrollController();
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: (widget.text.length * 0.12).ceil().clamp(6, 40)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  Future<void> _startScroll() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;

    // Прокручиваем до конца, затем обратно в начало (loop)
    while (mounted) {
      await _scroll.animateTo(max,
          duration: Duration(milliseconds: (max * 22).toInt()),
          curve: Curves.linear);
      if (!mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) break;
      _scroll.jumpTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Text(widget.text, style: widget.style, maxLines: 1),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Oil Drop Custom Painters
// ═══════════════════════════════════════════════════════════

/// Draws oil drop outline for pulse rings
class _OilDropBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Color glowColor;
  final double glowRadius;
  final String cityId;

  _OilDropBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.glowColor,
    required this.glowRadius,
    required this.cityId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getFabPath(size, cityId);
    
    // Glow
    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawPath(path, glowPaint);
    }

    // Border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_OilDropBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.cityId != cityId;
}

/// Draws ambient glow behind the oil drop
class _OilDropGlowPainter extends CustomPainter {
  final Color glowColor;
  final double blurRadius;
  final String cityId;

  _OilDropGlowPainter({required this.glowColor, required this.blurRadius, required this.cityId});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getFabPath(size, cityId);
    final paint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OilDropGlowPainter old) =>
      old.glowColor != glowColor || old.blurRadius != blurRadius || old.cityId != cityId;
}

/// Main oil drop button painter: fill + border + inner glow
class _OilDropButtonPainter extends CustomPainter {
  final List<Color> fillColors;
  final Color borderColor;
  final List<Color>? borderColors;
  final double borderWidth;
  final Color shadowColor;
  final double shadowBlur;
  final Color innerGlowColor;
  final String cityId;

  _OilDropButtonPainter({
    required this.fillColors,
    required this.borderColor,
    this.borderColors,
    required this.borderWidth,
    required this.shadowColor,
    required this.shadowBlur,
    required this.innerGlowColor,
    required this.cityId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getFabPath(size, cityId);

    // Shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
    canvas.drawPath(path, shadowPaint);

    // Fill gradient
    final rect = path.getBounds();
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        fillColors,
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Inner glow (top highlight)
    final innerPath = _getFabPath(Size(size.width * 0.7, size.height * 0.5), cityId);
    final innerOffset = Offset(size.width * 0.15, size.height * 0.08);
    final innerGlow = Paint()
      ..color = innerGlowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.save();
    canvas.translate(innerOffset.dx, innerOffset.dy);
    canvas.drawPath(innerPath, innerGlow);
    canvas.restore();

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    if (borderColors != null && borderColors!.length >= 2) {
      borderPaint.shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        borderColors!,
      );
    } else {
      borderPaint.color = borderColor;
    }
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_OilDropButtonPainter old) =>
      old.borderColor != borderColor ||
      old.shadowColor != shadowColor ||
      old.cityId != cityId ||
      old.borderColors != borderColors;
}

/// Shared path builder for FAB buttons (teardrop for Nizhnevartovsk, hexagon for Novosibirsk).
Path _getFabPath(Size size, String cityId) {
  final w = size.width;
  final h = size.height;
  final path = Path();

  if (cityId == 'novosibirsk') {
    // Futuristic Science Hexagon!
    path.moveTo(w * 0.5, 0); // Top peak
    path.lineTo(w, h * 0.23); // Top right
    path.lineTo(w, h * 0.77); // Bottom right
    path.lineTo(w * 0.5, h); // Bottom peak
    path.lineTo(0, h * 0.77); // Bottom left
    path.lineTo(0, h * 0.23); // Top left
    path.close();
    return path;
  }

  // Teardrop shape
  path.moveTo(w * 0.5, 0);
  path.cubicTo(w * 0.85, h * 0.25, w, h * 0.52, w, h * 0.62);
  path.cubicTo(w, h * 0.82, w * 0.82, h, w * 0.5, h);
  path.cubicTo(w * 0.18, h, 0, h * 0.82, 0, h * 0.62);
  path.cubicTo(0, h * 0.52, w * 0.15, h * 0.25, w * 0.5, 0);
  path.close();
  return path;
}

class _FocusedMarkerRipple extends StatefulWidget {
  final Color color;
  const _FocusedMarkerRipple({required this.color});

  @override
  State<_FocusedMarkerRipple> createState() => _FocusedMarkerRippleState();
}

class _FocusedMarkerRippleState extends State<_FocusedMarkerRipple> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scale = t;
        final opacity = 1.0 - t;
        return Center(
          child: Container(
            width: 120 * scale,
            height: 120 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withOpacity(opacity * 0.7),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(opacity * 0.25),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PointCloudClusterWidget extends StatefulWidget {
  final int count;
  final bool isNightMode;
  final Color primaryColor;
  final Color glowColor;

  const _PointCloudClusterWidget({
    required this.count,
    required this.isNightMode,
    required this.primaryColor,
    required this.glowColor,
  });

  @override
  State<_PointCloudClusterWidget> createState() => _PointCloudClusterWidgetState();
}

class _PointCloudClusterWidgetState extends State<_PointCloudClusterWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int pointsCount = widget.count.clamp(3, 10);
    final double radius = 18.0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Orbiting dots (Point Cloud swarm)
        ...List.generate(pointsCount, (index) {
          final double angleOffset = (index * 2 * math.pi) / pointsCount;
          
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              // Smooth mathematical sine offset staggered by index
              final wave = math.sin((progress * 2 * math.pi) + (index * 0.6));
              
              // Smooth breathing orbit radius
              final currentRadius = radius + (wave * 3.5);
              
              // Rotate angle smoothly
              final currentAngle = angleOffset + (progress * 2 * math.pi * 0.15);
              
              final dx = math.cos(currentAngle) * currentRadius;
              final dy = math.sin(currentAngle) * currentRadius;
              
              // Staggered size scaling & fading
              final scale = 0.55 + (wave + 1) * 0.225;
              final opacity = 0.35 + (wave + 1) * 0.325;
              
              return Positioned(
                left: 20 + dx - 2.5,
                top: 20 + dy - 2.5,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.glowColor,
                        boxShadow: [
                          BoxShadow(
                            color: widget.glowColor.withOpacity(0.85),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),

        // Main Cluster Center Core
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.primaryColor.withOpacity(widget.isNightMode ? 0.85 : 0.75),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isNightMode ? Colors.white : const Color(0xFF0F2742),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(widget.isNightMode ? 0.65 : 0.35),
                blurRadius: widget.isNightMode ? 10 : 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.count.toString(),
              style: TextStyle(
                color: widget.isNightMode ? Colors.white : const Color(0xFF0F2742),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


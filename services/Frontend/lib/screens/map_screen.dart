import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/mcp_config.dart';
import '../map/map_config.dart'
    show kMapCenterDefault, kOsmAttributionText, kOsmCopyrightUrl, MapConfig;
import '../services/mcp_service.dart';
import '../widgets/category_tile_rive.dart';
import 'complaint_form_screen.dart';
import 'infographic_screen.dart';

/// Главный экран карты — отображает жалобы на карте Нижневартовска
/// с реал-тайм обновлениями и фильтрацией по статусам/категориям.
///
/// Функции карты:
/// - Подложка: бесплатная OSM (map_config.dart), атрибуция и масштаб
/// - Маркеры: цвет по статусу (новая/в работе/решена), иконка по категории
/// - Фильтр: плитки категорий (Дороги, ЖКХ, Освещение, Транспорт, Прочее)
/// - Тап по маркеру: анимация к точке, zoom 16, bottom sheet с деталями
/// - Статистика: всего / новые / решены
/// - Кнопки: «Моя позиция» (центр города), «Обновить» (перезагрузка данных)
/// - Данные: Supabase REST API, автообновление каждые 30 с
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ─── Контроллеры и сервисы ───
  final MapController _mapController = MapController();
  final MCPService _mcpService = MCPService();

  // ─── Состояние ───
  List<Marker> _markers = [];
  bool _isLoading = true;
  int _totalComplaints = 0;
  int _newComplaints = 0;
  int _resolvedComplaints = 0;
  Timer? _updateTimer;
  String? _selectedCategory;
  int? _selectedDaysFilter; // null = все, иначе последние N дней
  List<Map<String, dynamic>> _allComplaints = [];
  final Map<String, int> _categoryCounts = {};
  final List<String> _markerCategories = [];

  // ─── Константы ───
  static const LatLng _center = kMapCenterDefault;
  static const Duration _updateInterval = Duration(seconds: 30);

  // ─── Цветовая палитра ───
  static const Color _colorDanger = Color(0xFFFF5252);
  static const Color _colorSuccess = Color(0xFF4CAF50);
  static const Color _colorNeutral = Color(0xFF9E9E9E);
  static const Color _colorPrimary = Color(0xFF2196F3);
  static const Color _colorAccent = Color(0xFF00D9FF);
  static const Color _colorSurface = Color(0xFF0F0F23);
  static const Color _colorBottomSheet = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    MCPConfig.initializeMCPService();
    _loadComplaints();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mcpService.disconnectAll();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // Загрузка данных
  // ═══════════════════════════════════════════════

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
        _allComplaints = complaints;
        _processComplaints(_filterByDate(complaints));
      } else {
        debugPrint('Данные не получены, пустой список жалоб');
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
  }

  static const Duration _fetchTimeout = Duration(seconds: 20);
  static const int _fetchRetries = 2;

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    const supabaseUrl =
        'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/complaints?select=*&order=created_at.desc&limit=500';
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

    for (var attempt = 0; attempt < _fetchRetries; attempt++) {
      try {
        final res = await http.get(
          Uri.parse(supabaseUrl),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
          },
        ).timeout(_fetchTimeout);

        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          final complaints = data.cast<Map<String, dynamic>>();

          if (complaints.isNotEmpty) {
            debugPrint('Получено жалоб из Supabase: ${complaints.length}');
            return complaints;
          }
        }
      } catch (e) {
        debugPrint('Fetch attempt ${attempt + 1}/$_fetchRetries failed: $e');
      }
    }

    return [];
  }

  // ═══════════════════════════════════════════════
  // Обработка данных
  // ═══════════════════════════════════════════════

  /// Фильтрация жалоб по дате создания за последние N дней.
  /// Если дата отсутствует или не парсится — жалоба не отфильтровывается.
  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> data) {
    if (_selectedDaysFilter == null) return data;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedDaysFilter!));

    return data.where((item) {
      final raw = item['created_at'] ?? item['createdAt'] ?? item['timestamp'];
      if (raw == null) return true;

      DateTime? dt;
      if (raw is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(raw);
      } else if (raw is String) {
        try {
          dt = DateTime.parse(raw);
        } catch (_) {}
      }
      if (dt == null) return true;
      return dt.isAfter(cutoff);
    }).toList();
  }

  void _processComplaints(List<dynamic> data) {
    // Специальный маркер «моковых» данных: 100 элементов и первый = 'mock'.
    // В этом случае не рисуем маркеры, а показываем пользователю сообщение.
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

    for (final item in data) {
      final lat = item['lat'] ?? item['latitude'];
      final lng = item['lng'] ?? item['longitude'];
      if (lat == null || lng == null) continue;

      final status = (item['status'] ?? 'open') as String;
      if (status == 'open' || status == 'pending') newCount++;
      if (status == 'resolved') resolvedCount++;

      final category = (item['category'] ?? 'Прочее') as String;
      markers.add(_buildMarker(
        point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
        status: status,
        category: category,
        complaint: item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item),
      ));
    }

    final counts = <String, int>{};
    for (final item in data) {
      final cat = (item['category'] ?? 'Прочее') as String;
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
          _markerCategories.add((item['category'] ?? 'Прочее') as String);
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

  static double _curveCubic(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
  }

  Widget _buildCategoryTiles() {
    final categories = [
      ('Дороги', Icons.directions_car, _colorDanger),
      ('ЖКХ', Icons.home, const Color(0xFF14b8a6)),
      ('Освещение', Icons.lightbulb, const Color(0xFFf59e0b)),
      ('Транспорт', Icons.directions_bus, const Color(0xFF3b82f6)),
      ('Экология', Icons.eco, const Color(0xFF22c55e)),
      ('Безопасность', Icons.shield, const Color(0xFF6366f1)),
      ('Снег/Наледь', Icons.ac_unit, const Color(0xFF38bdf8)),
      ('Медицина', Icons.local_hospital, const Color(0xFFef4444)),
      ('Образование', Icons.school, const Color(0xFF818cf8)),
      ('Парковки', Icons.local_parking, const Color(0xFF9ca3af)),
      ('Прочее', Icons.report_problem, _colorNeutral),
    ];
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (name, icon, color) = categories[i];
          final count = _categoryCounts[name] ?? 0;
          return CategoryTileRive(
            label: name,
            icon: icon,
            count: count,
            color: color,
            selected: _selectedCategory == name,
            riveAssetPath: null,
            onTap: () {
              setState(() {
                _selectedCategory = _selectedCategory == name ? null : name;
              });
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // UI маркеров и popup'ов
  // ═══════════════════════════════════════════════

  String _getCategorySvgPath(String category) {
    switch (category) {
      case 'Дороги':
        return 'assets/markers/marker-roads.svg';
      case 'Освещение':
        return 'assets/markers/marker-lighting.svg';
      case 'ЖКХ':
        return 'assets/markers/marker-zhkh.svg';
      case 'Транспорт':
        return 'assets/markers/marker-transport.svg';
      case 'Экология':
        return 'assets/markers/marker-ecology.svg';
      case 'Безопасность':
        return 'assets/markers/marker-safety.svg';
      case 'Снег/Наледь':
        return 'assets/markers/marker-snow.svg';
      case 'Медицина':
      case 'Здравоохранение':
        return 'assets/markers/marker-medicine.svg';
      case 'Образование':
        return 'assets/markers/marker-education.svg';
      case 'Парковки':
        return 'assets/markers/marker-parking.svg';
      case 'Благоустройство':
        return 'assets/markers/marker-landscaping.svg';
      default:
        return 'assets/markers/marker-other.svg';
    }
  }

  IconData _getCategoryIcon(String category) {
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
      default:
        return Icons.help_outline;
    }
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
    final color = _getStatusColor(status);

    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () {
          _animateMapTo(point, 16.0);
          _showComplaintDetails(complaint);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(128),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SvgPicture.asset(
            _getCategorySvgPath(category),
            width: 48,
            height: 48,
            // Вы можете опционально красить маркер через colorFilter,
            // но так как сами SVG могут иметь цвета, оставим как есть,
            // либо подкрасим тенью как сделано выше.
          ),
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

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    final status = (complaint['status'] ?? 'open') as String;
    final color = _getStatusColor(status);
    final category = (complaint['category'] ?? 'Прочее') as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: _colorBottomSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint['title'] as String? ?? 'Без названия',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            color: Colors.white.withAlpha(179),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Описание
              if (complaint['description'] != null) ...[
                const Text(
                  'Описание:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  complaint['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Адрес
              if (complaint['address'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: _colorPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        complaint['address'] as String,
                        style: TextStyle(
                          color: Colors.white.withAlpha(204),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Статус
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;
    const double topBarHeight = 72;
    const double filtersHeight = 76;

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
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
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
                        color: _colorPrimary.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _colorPrimary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Масштабная линейка
              Scalebar(
                alignment: Alignment.bottomLeft,
                textStyle: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 12,
                ),
                lineColor: Colors.white.withAlpha(200),
              ),
              // Атрибуция OSM (обязателена по Tile Usage Policy)
              SimpleAttributionWidget(
                source: Text(
                  kOsmAttributionText,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                alignment: Alignment.bottomRight,
                onTap: () => launchUrl(Uri.parse(kOsmCopyrightUrl)),
              ),
            ],
          ),

          // Индикатор загрузки
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: CircularProgressIndicator(color: _colorPrimary),
              ),
            ),

          // Верхняя панель с заголовком и фильтром по дням
          Positioned(
            top: paddingTop + 8,
            left: 16,
            right: 16,
            child: _buildTopBar(),
          ),

          // Плитки категорий (Rive / fallback) + данные из Supabase
          Positioned(
            top: paddingTop + 8 + topBarHeight + 8,
            left: 8,
            right: 8,
            child: _buildCategoryTiles(),
          ),
          // Панель статистики
          Positioned(
            top: paddingTop + 8 + topBarHeight + 8 + filtersHeight + 8,
            right: 16,
            child: _buildStatsPanel(),
          ),

          // Кнопки управления
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                _buildControlButton(
                  icon: Icons.my_location,
                  onTap: () => _animateMapTo(_center, 13.0),
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.refresh,
                  onTap: _loadComplaints,
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.bar_chart,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const InfographicScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Tooltip(
                  message: 'Сообщить о проблеме',
                  child: _buildControlButton(
                    icon: Icons.add_alert,
                    onTap: () {
                      final center = _mapController.camera.center;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ComplaintFormScreen(
                            initialCenter:
                                LatLng(center.latitude, center.longitude),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final filters = <Map<String, Object?>>[
      {'days': null, 'label': 'Все'},
      {'days': 1, 'label': '1 д'},
      {'days': 7, 'label': '7 д'},
      {'days': 30, 'label': '30 д'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _colorSurface.withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorPrimary.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
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
              const Expanded(
                child: Text(
                  'Пульс города · Нижневартовск',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.bar_chart, color: _colorAccent, size: 22),
                splashRadius: 22,
                tooltip: 'Инфографика',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const InfographicScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in filters)
                _buildDaysChip(
                  days: f['days'] as int?,
                  label: f['label'] as String,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaysChip({required int? days, required String label}) {
    final selected = _selectedDaysFilter == days;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: _colorAccent,
      backgroundColor: _colorSurface.withAlpha(200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? _colorAccent : Colors.white.withAlpha(60),
          width: 1,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _selectedDaysFilter = days;
        });
        if (_allComplaints.isNotEmpty) {
          _processComplaints(_filterByDate(_allComplaints));
        }
      },
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorSurface.withAlpha(242),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _colorPrimary.withAlpha(77),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Статистика',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatItem('Всего', _totalComplaints, Colors.white),
          _buildStatItem('Новые', _newComplaints, _colorDanger),
          _buildStatItem('Решены', _resolvedComplaints, _colorSuccess),
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
          const SizedBox(width: 8),
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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_colorPrimary, _colorAccent],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: _colorPrimary.withAlpha(102),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

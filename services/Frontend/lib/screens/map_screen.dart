import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import '../config/mcp_config.dart';
import '../map/map_config.dart'
    show kMapCenterDefault, kOsmAttributionText, kOsmCopyrightUrl, MapConfig;
import '../services/mcp_service.dart';
import 'complaint_form_screen.dart';
import 'infographic_screen.dart';
import 'about_screen.dart';
import '../widgets/city_pulse_wave.dart';
import '../services/sound_service.dart';
import 'cesium_map_screen.dart';
import 'settings_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// Главный экран карты — отображает жалобы на карте Нижневартовска
/// с реал-тайм обновлениями и фильтрацией по статусам/категориям.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ─── Контроллеры и сервисы ───
  final MapController _mapController = MapController();
  final MCPService _mcpService = MCPService();

  // ─── Состояние ───
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

  // ─── Состояние для автозума ───
  LatLng? _preZoomCenter;
  double? _preZoomLevel;
  Map<String, dynamic>? _focusedComplaint;

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

  // ─── Категории ───
  static const List<(String, IconData, Color)> _categories = [
    ('Дороги', Icons.directions_car, _colorDanger),
    ('ЖКХ', Icons.home, Color(0xFF14b8a6)),
    ('Освещение', Icons.lightbulb, Color(0xFFf59e0b)),
    ('Транспорт', Icons.directions_bus, Color(0xFF3b82f6)),
    ('Экология', Icons.eco, Color(0xFF22c55e)),
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
    MCPConfig.initializeMCPService();
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
        final name = item['n'] ?? 'Камера';
        final url = item['s'];
        
        if (lat != null && lng != null) {
          markers.add(Marker(
            point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                _showLiveCamDialog(name, url);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF6366f1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366f1).withAlpha(128),
                      // use smaller blur for multiple markers
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
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
             _zoomToComplaint(freshComplaint);
             _showComplaintDetails(freshComplaint);
             
             // Play category specific sound
             SoundService().playCategorySound(freshComplaint['category'] ?? 'Прочее');

             // Show in-app notification
             NotificationService().showNewComplaintNotification(
               context,
               title: freshComplaint['title'] ?? 'Новая жалоба',
               category: freshComplaint['category'] ?? 'Прочее',
               color: _getCategoryColor(freshComplaint['category'] ?? 'Прочее'),
             );

             // Show system push notification
             NotificationService().showPushNotification(
               id: freshComplaint['id'] is int ? freshComplaint['id'] : math.Random().nextInt(1000000),
               title: 'Новая жалоба: ${freshComplaint['category'] ?? 'Прочее'}',
               body: freshComplaint['title'] ?? 'Нажмите, чтобы посмотреть подробности',
               category: freshComplaint['category'],
             );
             
             // Auto return to overview in 10 secs
             Timer(const Duration(seconds: 10), () {
               if (mounted && _focusedComplaint != null && _focusedComplaint!['id'] == freshComplaint!['id']) {
                  if (Navigator.canPop(context)) Navigator.pop(context); // close bottomsheet
                  _zoomBack();
               }
             });
          }
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

  final Duration _fetchTimeout = const Duration(seconds: 20);
  final int _fetchRetries = 2;

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    const apiUrl = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/reports?select=*';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

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
            debugPrint('Получено жалоб из API: ${complaints.length}');
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

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> data) {
    if (_selectedDaysFilter == null) return data;
    
    // Специальный фильтр "Новые" (-1) - жалобы до 3 часов
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
      
      // Жалоба считается новой, если она создана менее 3 часов назад
      final isNew = dt != null && dt.isAfter(threeHoursAgo);
      
      if (isNew) newCount++;
      if (status == 'resolved') resolvedCount++;

      try {
        final category = (item['category'] ?? 'Прочее') as String;
        markers.add(_buildMarker(
          point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          status: status,
          category: category,
          complaint: item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item),
        ));
      } catch (e) {
        debugPrint('Ошибка обработки маркера: $e. Item: $item');
      }
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

  // ═══════════════════════════════════════════════
  // Анимация карты
  // ═══════════════════════════════════════════════

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

  /// Зум на проблему с сохранением предыдущей позиции
  void _zoomToComplaint(Map<String, dynamic> complaint) {
    final lat = complaint['lat'] ?? complaint['latitude'];
    final lng = complaint['lng'] ?? complaint['longitude'];
    if (lat == null || lng == null) return;

    // Сохраняем текущую позицию для возврата
    final camera = _mapController.camera;
    _preZoomCenter = camera.center;
    _preZoomLevel = camera.zoom;

    setState(() {
      _focusedComplaint = complaint;
    });

    // Зум на проблему
    _animateMapTo(
      LatLng((lat as num).toDouble(), (lng as num).toDouble()),
      17.0,
    );
  }

  /// Возврат к предыдущей позиции
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

  // ═══════════════════════════════════════════════
  // Выпадающее меню фильтрации
  // ═══════════════════════════════════════════════

  Widget _buildCategoryDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _colorSurface.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCategory != null
              ? _colorAccent.withAlpha(150)
              : _colorPrimary.withAlpha(77),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _selectedCategory != null ? _colorAccent : Colors.white70,
            size: 22,
          ),
          dropdownColor: _colorSurface,
          borderRadius: BorderRadius.circular(12),
          hint: Row(
            children: [
              Icon(Icons.filter_list_rounded,
                  color: Colors.white.withAlpha(180), size: 18),
              const SizedBox(width: 8),
              Text(
                'Все категории',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
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
                      color: Colors.white.withAlpha(180), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Все категории',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_totalComplaints',
                    style: TextStyle(
                      color: Colors.white.withAlpha(120),
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
                        style: const TextStyle(
                          color: Colors.white,
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
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
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
      case 'Мероприятие':
        return 'assets/markers/marker-other.svg';
      case 'Камеры':
        return 'assets/markers/marker-other.svg'; // Reuse other or add specific later
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
      case 'Мероприятие':
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
    final isCamera = category == 'Камеры';
    final color = isCamera ? const Color(0xFF6366f1) : _getStatusColor(status);

    return Marker(
      point: point,
      width: isCamera ? 54 : 48,
      height: isCamera ? 54 : 48,
      child: GestureDetector(
        onTap: () {
          _zoomToComplaint(complaint);
          if (category == 'Камеры') {
            final streamUrl = MapConfig.cityCams[complaint['title']];
            _showLiveCamDialog(complaint['title'] ?? 'Камера', streamUrl);
          } else {
            _showComplaintDetails(complaint);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(128),
                blurRadius: isCamera ? 15 : 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: isCamera 
            ? Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
              )
            : SvgPicture.asset(
                _getCategorySvgPath(category),
                width: 48,
                height: 48,
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

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    final status = (complaint['status'] ?? 'open') as String;
    final statusColor = _getStatusColor(status);
    final category = (complaint['category'] ?? 'Прочее') as String;
    final categoryColor = _getCategoryColor(category);
    final dateRaw =
        complaint['created_at'] ?? complaint['createdAt'] ?? complaint['timestamp'];

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
            
            int likes = complaint['likes_count'] ?? 0;
            bool isLiked = false;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              decoration: const BoxDecoration(
                color: _colorBottomSheet,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ручка
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
                      // Заголовок + категория
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  complaint['title'] as String? ?? 'Проблема',
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
                  
                      if (category == 'Камеры') ...[
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
                              const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 48),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const Center(
                                child: Text(
                                  'ЗАГРУЗКА ПОТОКА...',
                                  style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Статус + дата
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withAlpha(80), width: 1),
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
                              color: Colors.white.withAlpha(120), size: 15),
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

                      // Описание
                      if (complaint['description'] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withAlpha(15), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description_outlined,
                                      color: Colors.white.withAlpha(140),
                                      size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Описание',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(140),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(builder: (ctx) {
                                final desc = complaint['description'] as String;
                                if (desc.contains('Фото: http')) {
                                  final parts = desc.split('Фото: ');
                                  final textPart = parts[0].trim();
                                  final urlPart = parts[1].trim();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(textPart,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(220),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          urlPart,
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, err, stack) => 
                                              const Text('Ошибка загрузки фото', style: TextStyle(color: Colors.red, fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Text(
                                    desc,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(220),
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

                      // Адрес
                      if (complaint['address'] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _colorPrimary.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _colorPrimary.withAlpha(30), width: 1),
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

                      // Координаты + Google Street View
                      if (hasCoords)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.gps_fixed_rounded,
                                  color: Colors.white.withAlpha(100), size: 15),
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
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _colorPrimary.withAlpha(100)),
                                ),
                                child: IconButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  constraints: const BoxConstraints(minWidth: 40),
                                  icon: const Icon(Icons.streetview_rounded, size: 16, color: _colorAccent),
                                  tooltip: 'Смотреть в Google Street View',
                                  onPressed: () async {
                                    final url = 'google.streetview:cbll=$lat,$lng';
                                    final fallbackUrl = 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
                                    try {
                                      if (await canLaunchUrl(Uri.parse(url))) {
                                         await launchUrl(Uri.parse(url));
                                      } else {
                                         await launchUrl(Uri.parse(fallbackUrl));
                                      }
                                    } catch (_) {
                                       await launchUrl(Uri.parse(fallbackUrl));
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                      // Реакции и Напоминания
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (category == 'Мероприятие')
                            PopupMenuButton<Duration>(
                              color: _colorSurface,
                              onSelected: (Duration offset) {
                                final dateStr = complaint['created_at'] ?? complaint['createdAt'] ?? complaint['timestamp'];
                                DateTime? scheduledDate;
                                if (dateStr is String) scheduledDate = DateTime.tryParse(dateStr);
                                if (dateStr is int) scheduledDate = DateTime.fromMillisecondsSinceEpoch(dateStr);
                                
                                if (scheduledDate != null) {
                                  final reminderTime = scheduledDate.subtract(offset);
                                  NotificationService().scheduleReminder(
                                    id: complaint['id']?.hashCode ?? 0,
                                    title: 'Событие: ${complaint['title']}',
                                    body: 'Событие начнется через ${offset.inMinutes >= 60 ? '${offset.inHours} ч.' : '${offset.inMinutes} мин.'}!',
                                    scheduledDate: reminderTime,
                                  );
                                  ScaffoldMessenger.of(contextInner).showSnackBar(
                                    const SnackBar(content: Text('Напоминание установлено!')),
                                  );
                                }
                              },
                              itemBuilder: (contextInner) => [
                                const PopupMenuItem(value: Duration(minutes: 30), child: Text('За 30 мин', style: TextStyle(color: Colors.white))),
                                const PopupMenuItem(value: Duration(hours: 2), child: Text('За 2 часа', style: TextStyle(color: Colors.white))),
                                const PopupMenuItem(value: Duration(days: 1), child: Text('За день', style: TextStyle(color: Colors.white))),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.notifications_active_rounded, color: categoryColor, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Напомнить', style: TextStyle(color: Colors.white.withAlpha(200))),
                                  ],
                                ),
                              ),
                            ),
                          if (category != 'Мероприятие' && category != 'Камеры')
                            GestureDetector(
                              onTap: () async {
                                setModalState(() {
                                  isLiked = !isLiked;
                                  likes += isLiked ? 1 : -1;
                                  complaint['likes_count'] = likes;
                                });
                                // Отправка лайка в Supabase
                                try {
                                  final id = complaint['id'];
                                  if (id != null) {
                                    const url = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/reports?id=eq.';
                                    await http.patch(
                                      Uri.parse('$url$id'),
                                      headers: {
                                        'Content-Type': 'application/json',
                                        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc',
                                        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc',
                                      },
                                      body: jsonEncode({'likes_count': likes}),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error updating likes: $e');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isLiked ? Colors.red.withAlpha(40) : Colors.white.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isLiked ? Colors.red : Colors.white.withAlpha(150),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Поддерживаю ($likes)',
                                      style: TextStyle(
                                        color: isLiked ? Colors.redAccent : Colors.white.withAlpha(200),
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

                      // Кнопка «Вернуться»
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _zoomBack();
                          },
                          icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                          label: const Text('Вернуться к обзору'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _colorPrimary.withAlpha(40),
                            foregroundColor: _colorAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: _colorPrimary.withAlpha(80)),
                            ),
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

  void _showLiveCamDialog(String title, String? url) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на трансляцию не найдена')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => _LiveCamDialog(title: title, url: url),
    );
  }

  // ═══════════════════════════════════════════════
  // Информационная карточка на карте (overlay)
  // ═══════════════════════════════════════════════

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _colorBottomSheet.withAlpha(245),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: categoryColor.withAlpha(80), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
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
                      style: const TextStyle(
                        color: Colors.white,
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
                          '${_getStatusText(status)} · $category',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
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
                onTap: _zoomBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _colorPrimary.withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;
    const double topBarHeight = 72;

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
                urlTemplate: _isSatellite
                    ? MapConfig.satelliteUrl
                    : MapConfig.tileUrl,
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
                        border: Border.all(color: Colors.white, width: 2.0),
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
              if (_showCamerasLayer)
                MarkerLayer(markers: _cameraMarkers),
              // Масштабная линейка
              Scalebar(
                alignment: Alignment.bottomLeft,
                textStyle: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 12,
                ),
                lineColor: Colors.white.withAlpha(200),
              ),
              // Атрибуция OSM
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

          // Верхняя панель с заголовком и фильтрами
          Positioned(
            top: paddingTop + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                _buildCategoryDropdown(),
              ],
            ),
          ),

          // Иконка статистики
          Positioned(
            top: paddingTop + 140,
            right: 16,
            child: Tooltip(
              message: 'Статистика',
              child: _buildControlButton(
                icon: Icons.analytics_rounded,
                onTap: _showStatsDialog,
              ),
            ),
          ),

          // Иконка списка УК
          Positioned(
            top: paddingTop + 200,
            right: 16,
            child: Tooltip(
              message: 'Управляющие компании',
              child: _buildControlButton(
                icon: Icons.business_rounded,
                onTap: _showUkDialog,
              ),
            ),
          ),

          // Иконка камер (вверху)
          Positioned(
            top: paddingTop + 260,
            right: 16,
            child: Tooltip(
              message: 'Камеры города',
              child: _buildControlButton(
                icon: _showCamerasLayer ? Icons.videocam : Icons.videocam_off,
                onTap: () => setState(() => _showCamerasLayer = !_showCamerasLayer),
              ),
            ),
          ),

          // Иконка инфографики (вверху)
          Positioned(
            top: paddingTop + 320,
            right: 16,
            child: Tooltip(
              message: 'Инфографика',
              child: _buildControlButton(
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InfographicScreen()),
                ),
              ),
            ),
          ),

          // Кнопки управления
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                // Кнопка возврата (видима только при фокусе)
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
                  message: 'Сообщить о проблеме',
                  child: _buildControlButton(
                    icon: Icons.add_alert,
                    onTap: () async {
                      final center = _mapController.camera.center;
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ComplaintFormScreen(
                            initialCenter:
                                LatLng(center.latitude, center.longitude),
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadComplaints();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12.0),
                Tooltip(
                  message: '3D Режим (Cesium)',
                  child: _buildControlButton(
                    icon: Icons.view_in_ar_rounded,
                    onTap: _openCesiumViewer,
                  ),
                ),

                const SizedBox(height: 12.0),
                Tooltip(
                  message: 'Настройки',
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

          // Overlay с информацией о выбранной проблеме
          _buildFocusedOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final filters = <Map<String, Object?>>[
      {'days': null, 'label': 'Все'},
      {'days': -1, 'label': 'Новые'},
      {'days': 1, 'label': '1 д'},
      {'days': 7, 'label': '7 д'},
      {'days': 30, 'label': '30 д'},
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _colorSurface.withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorPrimary.withAlpha(77), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // City Pulse Wave
          Positioned(
            bottom: -5,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.6,
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
                    const Expanded(
                      child: Text(
                        'ПУЛЬС ГОРОДА · НИЖНЕВАРТОВСК',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildQuickCamButton(),
                    IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: _colorAccent, size: 22.0),
                      splashRadius: 22,
                      tooltip: 'О проекте',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.bar_chart,
                          color: _colorAccent, size: 22.0),
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
                const SizedBox(height: 8.0),
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
          width: 1.0,
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
            _buildStatItem('Всего обращений', _totalComplaints, Colors.white),
            _buildStatItem('Требуют внимания', _newComplaints, _colorDanger),
            _buildStatItem('Успешно решены', _resolvedComplaints, _colorSuccess),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Данные обновляются в режиме реального времени. Вы можете фильтровать жалобы по категориям и временным диапазонам через верхнюю панель.',
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
            child: const Text('ЗАКРЫТЬ', style: TextStyle(color: _colorAccent, fontWeight: FontWeight.bold)),
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
      const supabaseUrl = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data?data_type=eq.uk_list&select=data';
      const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Данные УК пусты')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка загрузки УК')));
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
    }
  }

  void _showUkListOverlay(List uks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _colorBottomSheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      'Управляющие компании (${uks.length})', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
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
                      title: Text(uk['TITLESM'] ?? uk['TITLE'] ?? 'УК', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(uk['ADR'] ?? 'Нет адреса', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            backgroundColor: _colorSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _colorPrimary.withAlpha(80), width: 1.5),
                            ),
                            title: Text(uk['TITLE'] ?? 'УК', style: const TextStyle(color: Colors.white, fontSize: 16)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.phone, color: _colorAccent),
                                  title: Text(uk['TEL'] ?? '-', style: const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.email, color: _colorAccent),
                                  title: Text(uk['EMAIL'] ?? '-', style: const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.home, color: _colorAccent),
                                  title: Text(uk['ADR'] ?? '-', style: const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.apartment, color: _colorAccent),
                                  title: Text('В управлении домов: ${uk['CNT'] ?? '-'}', style: const TextStyle(color: Colors.white)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person, color: _colorAccent),
                                  title: Text('Руководитель: ${uk['FIO'] ?? '-'}', style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx2);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Анонимное письмо отправлено в УК! (Тест)'),
                                      backgroundColor: _colorSuccess,
                                    )
                                  );
                                },
                                style: TextButton.styleFrom(backgroundColor: _colorAccent.withAlpha(30)),
                                child: const Text('Отправить анонимную жалобу', style: TextStyle(color: _colorAccent, fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx2),
                                child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
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
        child: Icon(icon, color: Colors.white, size: 24.0),
      ),
    );
  }

  void _openCesiumViewer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CesiumMapScreen(complaints: _allComplaints),
      ),
    );
  }
}

class _LiveCamDialog extends StatefulWidget {
  final String title;
  final String url;

  const _LiveCamDialog({required this.title, required this.url});

  @override
  State<_LiveCamDialog> createState() => _LiveCamDialogState();
}

class _LiveCamDialogState extends State<_LiveCamDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _hasError = false;
      _chewieController = null;
    });
    
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        isLive: true,
        errorBuilder: (context, errorMessage) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white24, size: 40),
              const SizedBox(height: 12),
              const Text('Ошибка загрузки потока', style: TextStyle(color: Colors.white70)),
              TextButton(onPressed: _initializePlayer, child: const Text('Повторить', style: TextStyle(color: Colors.red))),
            ],
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video initialized error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.videocam_rounded, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Прямая трансляция',
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Player Area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: _hasError 
                ? const Center(child: Text('Поток недоступен', style: TextStyle(color: Colors.white54)))
                : (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                  ? Chewie(controller: _chewieController!)
                  : const Center(child: CircularProgressIndicator(color: Colors.red)),
            ),
          ),

          // Footer info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                if (_hasError) ...[
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Открыть в браузере / VLC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol('Битрейт', 'Live'),
                    _buildStatCol('Формат', 'HLS/m3u8'),
                    _buildStatCol('Качество', 'HD'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

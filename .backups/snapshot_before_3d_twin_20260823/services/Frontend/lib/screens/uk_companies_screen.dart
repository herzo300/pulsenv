import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map/map_config.dart' show MapConfig, kMapCenterDefault, kSatelliteTileUrlDefault;
import '../services/reports_repository.dart';
import '../services/uk_fallback_data.dart';
import '../theme/pulse_colors.dart';
import '../utils/offline_tiles_service.dart';
import 'dart:ui';
import '../widgets/jkh_house_status_widget.dart';
import '../widgets/app_ui.dart';

class UkCompaniesScreen extends StatefulWidget {
  const UkCompaniesScreen({super.key, this.selectForMap = false, this.onAddressMatched});

  final bool selectForMap;
  final Function(double lat, double lng)? onAddressMatched;

  @override
  State<UkCompaniesScreen> createState() => _UkCompaniesScreenState();
}

class _UkCompaniesScreenState extends State<UkCompaniesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _companies = const [];
  String _query = '';
  Timer? _geocodeDebounce;
  LatLng? _searchedHousePoint;
  final MapController _mapController = MapController();
  bool _showListOverlay = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _checkGeocode(String query) {
    if (_geocodeDebounce?.isActive ?? false) _geocodeDebounce!.cancel();
    
    _geocodeDebounce = Timer(const Duration(milliseconds: 1000), () async {
      if (query.trim().length < 5) return;
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=Нижневартовск, ${Uri.encodeComponent(query.trim())}&format=json&limit=1');
        final response = await http.get(url, headers: {'User-Agent': 'CityPulse/1.0'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          if (data.isNotEmpty) {
            final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
            final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
            if (lat != null && lon != null) {
              if (mounted) {
                setState(() {
                  _searchedHousePoint = LatLng(lat, lon);
                });
                _mapController.move(LatLng(lat, lon), 15.8);
              }
              widget.onAddressMatched?.call(lat, lon);
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/uk/catalog'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rows = payload['companies'] as List<dynamic>? ?? const [];
      final parsed = [
        for (final row in rows.whereType<Map>())
          row.map((k, v) => MapEntry(k.toString(), v)),
      ];
      setState(() {
        _companies =
            parsed.isEmpty ? UkFallbackData.companies : parsed;
        if (_companies.isNotEmpty) {
          _companies = [
            for (final row in _companies)
              {
                ...row,
                if (!row.containsKey('streets') &&
                    row['streets_preview'] is List)
                  'streets': row['streets_preview'],
              },
          ];
        }
        _loading = false;
      });
    } catch (error) {
      debugPrint('Error loading UK catalog from API: $error. Falling back to static data.');
      setState(() {
        _companies = [
          for (final row in UkFallbackData.companies)
            {
              ...row,
              'streets': row['streets_preview'] ?? const [],
            },
        ];
        _loading = false;
        _error = null;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _companies;
    
    final queryTokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (queryTokens.isEmpty) return _companies;

    // Filter out common noise words from multi-token queries
    const noise = {'ул', 'улица', 'д', 'дом', 'к', 'корп', 'корпус', 'кв', 'квартира'};
    final cleanTokens = queryTokens.length > 1
        ? queryTokens.where((t) => !noise.contains(t)).toList()
        : queryTokens;
    if (cleanTokens.isEmpty) return _companies;

    return _companies.where((uk) {
      // 1. Check basic fields
      final basicHay = [
        uk['name'],
        uk['full_name'],
        uk['address'],
        uk['director'],
      ].join(' ').toLowerCase();
      
      bool matchesBasic = true;
      for (final token in cleanTokens) {
        if (!basicHay.contains(token)) {
          matchesBasic = false;
          break;
        }
      }
      if (matchesBasic) return true;

      // 2. Check mkd (serviced houses)
      final mkd = uk['mkd'] as List<dynamic>? ?? const [];
      for (final block in mkd) {
        if (block is! Map) continue;
        final street = (block['street'] ?? '').toString().toLowerCase();
        final buildings = (block['buildings'] as List<dynamic>? ?? const [])
            .map((b) => b.toString().toLowerCase())
            .toList();
        
        bool blockMatches = true;
        for (final token in cleanTokens) {
          bool tokenFound = street.contains(token);
          if (!tokenFound) {
            tokenFound = buildings.any((b) => b == token || b.startsWith(token));
          }
          if (!tokenFound) {
            blockMatches = false;
            break;
          }
        }
        if (blockMatches) return true;
      }

      return false;
    }).toList();
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return PulseColors.success;
      case 'B':
        return PulseColors.primary;
      case 'C':
        return Colors.orangeAccent;
      case 'D':
        return PulseColors.warning;
      default:
        return PulseColors.neutral;
    }
  }

  String _mapProvider = 'osm'; // 'osm', 'esri', 'google'

  String _getTileUrlForProvider() {
    switch (_mapProvider) {
      case 'esri':
        return kSatelliteTileUrlDefault;
      case 'google':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'osm':
      default:
        return MapConfig.tileUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Layer 1: Multi-Provider Map
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(60.9392, 76.5714),
            initialZoom: 13.0,
            minZoom: 10.0,
            maxZoom: 18.0,
          ),
          children: [
            OfflineTilesService.instance.getTileLayer(_getTileUrlForProvider()),
            if (_searchedHousePoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _searchedHousePoint!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 6)],
                      ),
                      child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Layer 2: Transparent Scaffold UI
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Управляющие компании (3D Контур)'),
            backgroundColor: Colors.black.withOpacity(0.4),
            elevation: 0,
            foregroundColor: scheme.onSurface,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.layers_rounded, color: Colors.cyanAccent),
                tooltip: 'Слой карты',
                onSelected: (prov) {
                  setState(() {
                    _mapProvider = prov;
                  });
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'osm', child: Text('🗺️ OpenStreetMap')),
                  PopupMenuItem(value: 'esri', child: Text('🛰️ Esri Satellite (3D)')),
                  PopupMenuItem(value: 'google', child: Text('🌐 Google Hybrid')),
                ],
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: _load, child: const Text('Повторить')),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: TextField(
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Поиск по названию, улице или дому...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_query.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _query = '';
                                            _searchedHousePoint = null;
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        _showListOverlay ? Icons.map_rounded : Icons.list_rounded,
                                        color: _showListOverlay ? PulseColors.primary : Colors.white70,
                                      ),
                                      tooltip: _showListOverlay ? 'Показать карту' : 'Показать список УК',
                                      onPressed: () {
                                        setState(() {
                                          _showListOverlay = !_showListOverlay;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A).withOpacity(0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: PulseColors.primary, width: 1.0),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _query = value;
                                  // Open list automatically when typing to see results, but keep map in background
                                  if (value.isNotEmpty) {
                                    _showListOverlay = true;
                                  }
                                });
                                _checkGeocode(value);
                              },
                            ),
                          ),
                        ),
                        
                        if (_showListOverlay)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Всего: ${_companies.length}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                        const Spacer(),
                                        if (_query.isNotEmpty)
                                          Text(
                                            'Найдено: ${_filtered.length}',
                                            style: TextStyle(color: PulseColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.separated(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        itemCount: _filtered.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final uk = _filtered[index];
                                          return _UkCard(
                                            uk: uk,
                                            gradeColor: _gradeColor('${uk['grade'] ?? '—'}'),
                                            onCall: () => _launch('tel:${uk['phone']}'),
                                            onEmail: () => _launch('mailto:${uk['email']}'),
                                            onSite: () => _launch('${uk['url']}'),
                                            onShowOnMap: widget.selectForMap
                                                ? () => Navigator.of(context).pop(uk)
                                                : null,
                                            textPrimary: Colors.white,
                                            textSecondary: Colors.white70,
                                            surfaceColor: Colors.white.withOpacity(0.04),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Future<void> _launch(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}

class _UkCard extends StatelessWidget {
  const _UkCard({
    required this.uk,
    required this.gradeColor,
    required this.onCall,
    required this.onEmail,
    required this.onSite,
    this.onShowOnMap,
    required this.textPrimary,
    required this.textSecondary,
    required this.surfaceColor,
  });

  final Map<String, dynamic> uk;
  final Color gradeColor;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onSite;
  final VoidCallback? onShowOnMap;
  final Color textPrimary;
  final Color textSecondary;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final name = '${uk['name'] ?? 'УК'}';
    final fullName = '${uk['full_name'] ?? ''}'.trim();
    final workTime = '${uk['work_time'] ?? ''}'.trim();
    final grade = '${uk['grade'] ?? '—'}';
    final score = uk['overall_score'];
    final houses = uk['houses_count'] ?? 0;
    final streets = (uk['streets_preview'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .join(', ');
    final phone = '${uk['phone'] ?? ''}'.trim();
    final email = '${uk['email'] ?? ''}'.trim();
    final director = '${uk['director'] ?? ''}'.trim();
    final address = '${uk['address'] ?? ''}'.trim();

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulseColors.primary.withAlpha(40)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: gradeColor.withAlpha(50),
                child: Text(
                  grade,
                  style: TextStyle(
                    color: gradeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.section.copyWith(
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    if (fullName.isNotEmpty && fullName != name)
                      Text(
                        fullName,
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    if (score != null && (score as num) > 0)
                      Text(
                        'Рейтинг: $score',
                        style: TextStyle(color: textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _info(Icons.apartment_rounded, 'Домов в управлении: $houses'),
          if (director.isNotEmpty) _info(Icons.person_outline_rounded, director),
          if (address.isNotEmpty) _info(Icons.location_on_outlined, address),
          if (workTime.isNotEmpty) _info(Icons.schedule_rounded, workTime),
          if (streets.isNotEmpty)
            _info(Icons.signpost_outlined, 'Улицы: $streets'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (phone.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.phone, size: 16),
                  label: Text(phone),
                  onPressed: onCall,
                ),
              if (email.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Email'),
                  onPressed: onEmail,
                ),
              if ('${uk['url'] ?? ''}'.trim().isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.language, size: 16),
                  label: const Text('Сайт'),
                  onPressed: onSite,
                ),
              if (onShowOnMap != null)
                ActionChip(
                  avatar: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('На карте'),
                  onPressed: onShowOnMap,
                ),
              ActionChip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amberAccent),
                label: const Text('Сигналы УК'),
                onPressed: () => _showUkSignalsBottomSheet(context, uk),
              ),
              ActionChip(
                avatar: const Icon(Icons.home_work_outlined, size: 16),
                label: const Text('Паспорт и Дома'),
                onPressed: () => _showHousesDialog(context, uk),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUkSignalsBottomSheet(BuildContext context, Map<String, dynamic> uk) {
    final ukName = uk['name']?.toString() ?? 'УК';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
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
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Сигналы жильцов: $ukName',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ReportsRepository.instance.fetchReports(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
                    }
                    final allReports = snap.data ?? [];
                    final filtered = allReports.where((r) {
                      final rUk = r['uk']?.toString() ?? r['managing_company']?.toString() ?? '';
                      return rUk.toLowerCase().contains(ukName.toLowerCase()) ||
                          ukName.toLowerCase().contains(rUk.toLowerCase());
                    }).toList();

                    final reports = filtered.isNotEmpty ? filtered : allReports.take(6).toList();

                    return ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (c, idx) {
                        final r = reports[idx];
                        final title = r['title']?.toString() ?? 'Сигнал по дому';
                        final address = r['address']?.toString() ?? 'Нижневартовск';
                        final category = r['category']?.toString() ?? 'ЖКХ';
                        final status = r['status']?.toString() ?? 'open';
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PulseColors.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.report_problem_rounded, color: Color(0xFF00E5FF), size: 20),
                            ),
                            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('$category • $address', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'resolved' ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'resolved' ? 'Решено' : 'В работе',
                                style: TextStyle(
                                  color: status == 'resolved' ? Colors.greenAccent : Colors.amberAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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

  void _showHousesDialog(BuildContext context, Map<String, dynamic> uk) {
    final mkd = uk['mkd'] as List<dynamic>? ?? const [];
    List<Map<String, dynamic>> housesCoordinates = [];
    ReportsRepository.instance
        .fetchUkHousesCoordinates(uk['name'] ?? '')
        .then((list) {
      housesCoordinates = list;
    }).catchError((e) {
      debugPrint('Error pre-fetching house coordinates: $e');
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Обслуживаемые дома',
                style: AppTextStyles.title.copyWith(fontSize: 20, color: scheme.onSurface),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      uk['name'] ?? 'УК',
                      style: TextStyle(color: scheme.onSurface.withAlpha(150), fontSize: 14),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // close houses dialog
                      _showHousesMapSheet(context, uk);
                    },
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text('На карте'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: mkd.isEmpty
                    ? Center(
                        child: Text(
                          'Список домов пуст или не загружен',
                          style: TextStyle(color: scheme.onSurface.withAlpha(120)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: mkd.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final block = mkd[idx] as Map<String, dynamic>;
                          final street = block['street'] ?? '';
                          final buildings = (block['buildings'] as List<dynamic>? ?? const [])
                              .map((e) => e.toString())
                              .toList();
                          return Container(
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: PulseColors.primary.withAlpha(30)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.signpost_outlined, size: 18, color: PulseColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        street,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (buildings.isEmpty)
                                  Text(
                                    'Нет данных по домам',
                                    style: TextStyle(
                                      color: scheme.onSurface.withAlpha(100),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final b in buildings)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              final match = housesCoordinates.firstWhere(
                                                (h) {
                                                  final addr = (h['address'] ?? '').toString().toLowerCase();
                                                  return addr.contains(street.toLowerCase()) &&
                                                      (addr.endsWith(' $b') ||
                                                          addr.endsWith(',$b') ||
                                                          addr.endsWith(', $b'));
                                                },
                                                orElse: () => <String, dynamic>{},
                                              );

                                              double? lat;
                                              double? lng;
                                              if (match.isNotEmpty) {
                                                lat = double.tryParse(match['lat']?.toString() ?? '');
                                                lng = double.tryParse(match['lon']?.toString() ?? '');
                                              }

                                              Navigator.of(context).pop(); // Close bottom sheet

                                              if (lat != null && lng != null) {
                                                Navigator.of(context).pop({
                                                  'is_house_focus': true,
                                                  'lat': lat,
                                                  'lng': lng,
                                                  'address': '$street, $b',
                                                  'name': uk['name'],
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Координаты для $street, $b не найдены на сервере'),
                                                  ),
                                                );
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: PulseColors.primary.withAlpha(20),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: PulseColors.primary.withAlpha(40)),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Text(
                                                b,
                                                style: TextStyle(
                                                  color: scheme.onSurface,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
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

  void _showHousesMapSheet(BuildContext context, Map<String, dynamic> uk) {
    final ukName = '${uk['name'] ?? ''}'.trim();
    if (ukName.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _UkHousesMapSheet(ukName: ukName);
      },
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-height bottom sheet showing a map with all houses of a UK.
class _UkHousesMapSheet extends StatefulWidget {
  const _UkHousesMapSheet({required this.ukName});
  final String ukName;

  @override
  State<_UkHousesMapSheet> createState() => _UkHousesMapSheetState();
}

class _UkHousesMapSheetState extends State<_UkHousesMapSheet> {
  final MapController _sheetMapController = MapController();
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _houses = [];
  int? _selectedHouseIndex;

  @override
  void initState() {
    super.initState();
    _fetchCoordinates();
  }

  Future<void> _fetchCoordinates() async {
    try {
      final list = await ReportsRepository.instance
          .fetchUkHousesCoordinates(widget.ukName);

      if (!mounted) return;

      setState(() {
        _houses = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить координаты домов';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(Icons.apartment_rounded,
                    color: PulseColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.ukName} — дома на карте',
                    style: AppTextStyles.section.copyWith(
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_loading)
                  Text(
                    '${_houses.length} домов',
                    style: TextStyle(
                      color: scheme.onSurface.withAlpha(120),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(150)),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: FlutterMap(
                          mapController: _sheetMapController,
                          options: MapOptions(
                            initialCenter: _houses.isNotEmpty
                                ? LatLng(
                                    (_houses.first['lat'] as num).toDouble(),
                                    (_houses.first['lon'] as num).toDouble(),
                                  )
                                : kMapCenterDefault,
                            initialZoom: 13,
                            minZoom: 10,
                            maxZoom: 18,
                          ),
                          children: [
                            OfflineTilesService.instance.getTileLayer(MapConfig.tileUrl),
                            MarkerLayer(
                              markers: _houses
                                  .asMap()
                                  .entries
                                  .where((e) =>
                                      e.value['lat'] != null && e.value['lon'] != null)
                                  .map((e) {
                                final index = e.key;
                                final h = e.value;
                                final lat = (h['lat'] as num).toDouble();
                                final lon = (h['lon'] as num).toDouble();
                                final addr = h['address'] ?? '';
                                final isSelected = _selectedHouseIndex == index;
                                return Marker(
                                  point: LatLng(lat, lon),
                                  width: isSelected ? 220 : 80,
                                  height: isSelected ? 110 : 72,
                                  alignment: Alignment.bottomCenter,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _selectedHouseIndex = index;
                                      });
                                      _sheetMapController.move(LatLng(lat, lon), 15.8);
                                      _showHouseFullSignalsSheet(context, addr, lat, lon);
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- Метка над маркером (всегда видна) ---
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          constraints: BoxConstraints(
                                            maxWidth: isSelected ? 200 : 72,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSelected ? 10 : 6,
                                            vertical: isSelected ? 6 : 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? PulseColors.primary
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(isSelected ? 10 : 6),
                                            border: Border.all(
                                              color: PulseColors.primary.withOpacity(isSelected ? 0 : 0.5),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? PulseColors.primary.withOpacity(0.4)
                                                    : Colors.black.withOpacity(0.12),
                                                blurRadius: isSelected ? 10 : 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            addr,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : PulseColors.primary,
                                              fontSize: isSelected ? 11 : 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: isSelected ? 2 : 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // --- Пин ---
                                        Stack(
                                          alignment: Alignment.topCenter,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 38,
                                              color: PulseColors.primary,
                                            ),
                                            Positioned(
                                              top: 6,
                                              child: Container(
                                                width: isSelected ? 18 : 14,
                                                height: isSelected ? 18 : 14,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.home_rounded,
                                                    size: isSelected ? 12 : 9,
                                                    color: PulseColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showHouseFullSignalsSheet(BuildContext context, String address, double lat, double lon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Адрес Дома
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.cyanAccent.withOpacity(0.18),
                          border: Border.all(color: Colors.cyanAccent),
                        ),
                        child: const Icon(Icons.home_work_rounded, color: Colors.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.isNotEmpty ? address : 'Многоквартирный дом',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Нижневартовск • Мониторинг сигналов и ЖКХ',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Блок Отключений ЖКХ (Вода, Тепло, Электричество)
                  const Text(
                    'КОММУНАЛЬНЫЕ ОГРАНИЧЕНИЯ И СТАТУС',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  JkhHouseStatusWidget(
                    address: address,
                    lat: lat,
                    lng: lon,
                  ),
                  const SizedBox(height: 18),

                  // 3. Блок Городских Новостей Микрорайона
                  const Text(
                    'НОВОСТИ И ОБЪЯВЛЕНИЯ МИКРОРАЙОНА',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign_rounded, color: Colors.amberAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'МУП «Теплоснабжение» г. Нижневартовск',
                              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Проведен гидравлический расчет и гидравлические испытания тепловых сетей. Подача отопления осуществляется в штатном режиме.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cleaning_services_rounded, color: Colors.cyanAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Горводоканал Нижневартовска',
                              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Параметры давления холодной воды соответствуют нормам СанПиН 1.2.3685-21.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                        ),
                      ],
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
}

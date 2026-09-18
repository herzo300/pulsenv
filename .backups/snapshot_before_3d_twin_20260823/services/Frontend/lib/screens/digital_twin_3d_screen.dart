import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:services/config/map_config.dart';

/// 3D Digital Twin Screen for Nizhnevartovsk (OSM + ArcticDEM + Sentinel-2)
class DigitalTwin3DScreen extends StatefulWidget {
  const DigitalTwin3DScreen({Key? key}) : super(key: key);

  @override
  State<DigitalTwin3DScreen> createState() => _DigitalTwin3DScreenState();
}

class _DigitalTwin3DScreenState extends State<DigitalTwin3DScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  double _waterLevelCm = 850.0;
  Map<String, dynamic>? _floodData;
  List<Map<String, dynamic>> _landmarks = [];
  List<Map<String, dynamic>> _cameras3D = [];
  Map<String, dynamic>? _twinStats;

  bool _showBuildings = true;
  bool _showFloodLayer = true;
  bool _showCameras = true;
  bool _showLandmarks = true;

  int _selectedTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDigitalTwinData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDigitalTwinData() async {
    setState(() => _isLoading = true);
    final baseUrl = MapConfig.backendBaseUrl;

    try {
      // 1. Fetch Landmarks
      final lmResp = await http.get(Uri.parse('$baseUrl/api/v1/3d-twin/landmarks')).timeout(const Duration(seconds: 4));
      if (lmResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(lmResp.bodyBytes));
        if (data['items'] != null) {
          _landmarks = List<Map<String, dynamic>>.from(data['items']);
        }
      }

      // 2. Fetch 3D Cameras
      final camResp = await http.get(Uri.parse('$baseUrl/api/v1/3d-twin/cameras-3d')).timeout(const Duration(seconds: 4));
      if (camResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(camResp.bodyBytes));
        if (data['items'] != null) {
          _cameras3D = List<Map<String, dynamic>>.from(data['items']);
        }
      }

      // 3. Fetch Stats
      final statsResp = await http.get(Uri.parse('$baseUrl/api/v1/3d-twin/stats')).timeout(const Duration(seconds: 4));
      if (statsResp.statusCode == 200) {
        _twinStats = jsonDecode(utf8.decode(statsResp.bodyBytes));
      }

      // 4. Fetch Flood Simulation for current water level
      await _updateFloodSimulation(_waterLevelCm, refreshState: false);
    } catch (e) {
      debugPrint('[DigitalTwin3D] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateFloodSimulation(double level, {bool refreshState = true}) async {
    try {
      final baseUrl = MapConfig.backendBaseUrl;
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v1/3d-twin/flood-simulation?water_level_cm=${level.toInt()}'))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['data'] != null) {
          _floodData = data['data'];
        }
      }
    } catch (e) {
      debugPrint('[DigitalTwin3D] Flood simulation query error: $e');
    }
    if (refreshState && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3D Digital Twin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Нижневартовск • OSM + ArcticDEM + Sentinel-2', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить модель',
            onPressed: _loadDigitalTwinData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.location_city_rounded), text: '3D Город'),
            Tab(icon: Icon(Icons.flood_rounded), text: 'Паводок Оби'),
            Tab(icon: Icon(Icons.videocam_rounded), text: '3D Камеры'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _build3DCityTab(),
                _buildFloodSimTab(),
                _buildCameras3DTab(),
              ],
            ),
    );
  }

  Widget _build3DCityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          const SizedBox(height: 16),
          _buildLayerToggles(),
          const SizedBox(height: 16),
          const Text('Ключевые 3D Доминанты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _landmarks.length,
            itemBuilder: (context, index) {
              final lm = _landmarks[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(lm['color'].replaceAll('#', '0xFF'))).withOpacity(0.2),
                    child: Icon(Icons.architecture_rounded, color: Color(int.parse(lm['color'].replaceAll('#', '0xFF')))),
                  ),
                  title: Text(lm['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${lm['address']}\nВысота: ${lm['height']}м • ${lm['category']}'),
                  isThreeLine: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${lm['height']}m 3D', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Цифровой двойник Нижневартовска', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('READY 100%', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('3D Зданий', '${_twinStats?['total_3d_buildings'] ?? 1100}+', Icons.domain_rounded),
              _buildMetricItem('Микрорайонов', '${_twinStats?['microdistricts_covered'] ?? 26}', Icons.grid_view_rounded),
              _buildMetricItem('ArcticDEM', '2 метра', Icons.terrain_rounded),
              _buildMetricItem('Sentinel-2', '10м TCI', Icons.satellite_alt_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildLayerToggles() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Слои 3D визуализации', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('3D Здания (OSM)'),
                  selected: _showBuildings,
                  onSelected: (val) => setState(() => _showBuildings = val),
                  selectedColor: const Color(0xFF00E5FF).withOpacity(0.2),
                ),
                FilterChip(
                  label: const Text('Паводок реки Обь'),
                  selected: _showFloodLayer,
                  onSelected: (val) => setState(() => _showFloodLayer = val),
                  selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                ),
                FilterChip(
                  label: const Text('3D Камеры & FOV'),
                  selected: _showCameras,
                  onSelected: (val) => setState(() => _showCameras = val),
                  selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloodSimTab() {
    final statusColor = _floodData?['status_color'] != null
        ? Color(int.parse(_floodData!['status_color'].replaceAll('#', '0xFF')))
        : const Color(0xFFF59E0B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Уровень реки Обь: ${_waterLevelCm.toInt()} см',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(_floodData?['threat_level']?.toUpperCase() ?? 'WARNING',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_floodData?['status_label'] ?? 'Расчёт гидрологической модели...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 12),
                Text('Площадь затопления поймы: ${_floodData?['flooded_area_hectares'] ?? 0} га',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Симуляция уровня воды (Гидропост Нижневартовск):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Slider(
            value: _waterLevelCm,
            min: 500.0,
            max: 1100.0,
            divisions: 60,
            activeColor: statusColor,
            label: '${_waterLevelCm.toInt()} см',
            onChanged: (val) {
              setState(() => _waterLevelCm = val);
              _updateFloodSimulation(val);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('500 см (Норма)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('850 см (Пойма)', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
              Text('940 см (Опасно)', style: TextStyle(fontSize: 11, color: Color(0xFFF97316))),
              Text('1061 см (Пик 2015)', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Зоны риска подтопления:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_floodData?['affected_areas'] != null)
            ...(_floodData!['affected_areas'] as List).map((area) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.warning_rounded, color: Color(0xFFF59E0B)),
                    title: Text(area.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Старый Вартовск / РЭБ Флота (ArcticDEM 2m)'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildCameras3DTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cameras3D.length,
      itemBuilder: (context, index) {
        final cam = _cameras3D[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(cam['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('3D FOV ONLINE', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Высота подвеса: ${cam['elevation_m']}м • Угол обзора: ${cam['fov_deg']}° • Дальность: ${cam['range_m']}м',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Подключение к 3D стриму: ${cam['stream_url']}')),
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: const Text('Открыть 3D WebRTC Стрим'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

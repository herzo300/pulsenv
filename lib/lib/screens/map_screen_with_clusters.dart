// lib/lib/screens/map_screen_with_clusters.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../services/api_service.dart';
import '../models/complaint.dart';
import 'complaint_detail_screen.dart';
import 'create_complaint_screen.dart';

/// Экран карты с оптимизированной кластеризацией маркеров
class MapScreenWithClusters extends StatefulWidget {
  const MapScreenWithClusters({super.key});

  @override
  State<MapScreenWithClusters> createState() => _MapScreenWithClustersState();
}

class _MapScreenWithClustersState extends State<MapScreenWithClusters> {
  final MapController _mapController = MapController();
  final ClusterPlugin _clusterPlugin = ClusterPlugin();
  List<Complaint> _complaints = [];
  List<Map<String, dynamic>> _clusters = [];
  List<Marker> _markers = [];
  bool _isLoading = true;
  String? _error;
  LatLng _currentCenter = const LatLng(60.9392, 76.5922);
  double _currentZoom = 13.0;
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCategories();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getComplaints(category: _selectedCategory, limit: 1000),
        ApiService.getClusters(),
      ]);

      final complaintsData = results[0] as List<Map<String, dynamic>>;
      final clustersData = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _complaints = complaintsData.map((c) => Complaint.fromJson(c)).toList();
        _clusters = clustersData;
        _markers = _complaints
            .map((c) => _createMarker(c))
            .toList();
        _isLoading = false;
        _isOffline = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Marker _createMarker(Complaint complaint) {
    return Marker(
      width: 40.0,
      height: 40.0,
      point: LatLng(complaint.lat, complaint.lng),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getCategoryColor(complaint.category),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => _onMarkerTapped(complaint),
          child: Center(
            child: Icon(
              _getCategoryIcon(complaint.category),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _onMarkerTapped(Complaint complaint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailScreen(complaint: complaint),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colorMap = {
      'Дороги': Colors.red,
      'ЖКХ': Colors.blue,
      'Экология': Colors.green,
      'Освещение': Colors.orange,
      'Безопасность': Colors.purple,
    };
    return colorMap[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    final iconMap = {
      'Дороги': Icons.directions_car,
      'ЖКХ': Icons.home,
      'Экология': Icons.eco,
      'Освещение': Icons.lightbulb,
      'Безопасность': Icons.security,
    };
    return iconMap[category] ?? Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта жалоб'),
        actions: [
          if (_selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
                _loadData();
              },
              tooltip: 'Сбросить фильтр',
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showCategoryFilter(),
              tooltip: 'Фильтровать по категории',
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_isLoading)
            _buildLoadingState(),
          if (_error != null)
            _buildErrorState(),
          if (_isOffline)
            _buildOfflineIndicator(),
          _buildCategoryFilter(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      plugins: [_clusterPlugin],
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: _currentZoom,
        minZoom: 10,
        maxZoom: 18,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            setState(() {
              _currentCenter = position.center;
              _currentZoom = position.zoom;
            });
          }
        },
        onTap: (tapPosition, point) {
          setState(() {
            _selectedLocation = point;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgent: 'SoobshioApp/1.0',
        ),
        MarkerLayer(
          markers: _markers,
          rotate: true,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загрузка жалоб...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Ошибка загрузки данных',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(_error ?? 'Неизвестная ошибка'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      height: 56,
      color: Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: const [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Офлайн режим. Данные из кэша.'),
            Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category['name']),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category['name'] : null;
                });
                _loadData();
              },
              avatar: category['icon'] != null
                  ? Text(category['icon'])
                  : null,
            ),
          );
        },
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            controller: scrollController,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return ListTile(
                title: Text(category['name']),
                onTap: () {
                  setState(() {
                    _selectedCategory = category['name'];
                  });
                  Navigator.pop(context);
                  _loadData();
                },
                trailing: _selectedCategory == category['name']
                    ? const Icon(Icons.check)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

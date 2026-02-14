// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../models/complaint.dart';
import 'complaint_detail_screen.dart';
import 'create_complaint_screen.dart';

/// Экран карты с OpenStreetMap для Android
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Complaint> _complaints = [];
  List<Map<String, dynamic>> _clusters = [];
  bool _isLoading = true;
  String? _error;
  LatLng _currentCenter = const LatLng(60.9392, 76.5922); // Нижневартовск
  double _currentZoom = 13.0;
  
  // Выбранная категория для фильтрации
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];

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
      // Загружаем и жалобы, и кластеры параллельно
      final results = await Future.wait([
        ApiService.getComplaints(category: _selectedCategory, limit: 500),
        ApiService.getClusters(),
      ]);

      final complaintsData = results[0] as List<Map<String, dynamic>>;
      final clustersData = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _complaints = complaintsData.map((c) => Complaint.fromJson(c)).toList();
        _clusters = clustersData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Карта OpenStreetMap
          FlutterMap(
            mapController: _mapController,
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
            ),
            children: [
              // OpenStreetMap слой
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.soobshio.app',
              ),
              // Маркеры жалоб
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // Верхняя панель с поиском и фильтрами
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Поиск
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск по адресу...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _centerOnUser,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onSubmitted: (value) => _searchAddress(value),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Фильтр категорий
                    if (_categories.isNotEmpty)
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildCategoryChip(
                                'Все',
                                null,
                                Icons.all_inclusive,
                                _selectedCategory == null,
                              );
                            }
                            final cat = _categories[index - 1];
                            return _buildCategoryChip(
                              cat['name'],
                              cat['name'],
                              _getCategoryIcon(cat['icon']),
                              _selectedCategory == cat['name'],
                              color: _parseColor(cat['color']),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Индикатор загрузки
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Сообщение об ошибке
          if (_error != null && !_isLoading)
            Positioned(
              top: 200,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ошибка загрузки данных',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),

          // Кнопки управления картой
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // Кнопка зума +
                _buildMapButton(
                  icon: Icons.add,
                  onTap: () {
                    _mapController.move(
                      _currentCenter,
                      _currentZoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Кнопка зума -
                _buildMapButton(
                  icon: Icons.remove,
                  onTap: () {
                    _mapController.move(
                      _currentCenter,
                      _currentZoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Кнопка обновления
                _buildMapButton(
                  icon: Icons.refresh,
                  onTap: _loadData,
                ),
              ],
            ),
          ),
        ],
      ),

      // FAB для создания жалобы
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateComplaintScreen(
                initialLocation: _currentCenter,
              ),
            ),
          );
          if (result == true) {
            _loadData(); // Обновляем данные после создания
          }
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Сообщить'),
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    String? category,
    IconData icon,
    bool isSelected, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (color ?? Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
          _loadData();
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: color ?? Theme.of(context).colorScheme.primary,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Добавляем маркеры для каждой жалобы
    for (final complaint in _complaints) {
      if (complaint.latitude != null && complaint.longitude != null) {
        markers.add(
          Marker(
            point: LatLng(complaint.latitude!, complaint.longitude!),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showComplaintDetails(complaint),
              child: Container(
                decoration: BoxDecoration(
                  color: _getCategoryColor(complaint.category),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(_getCategoryIconName(complaint.category)),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showComplaintDetails(Complaint complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: ComplaintDetailScreen(
              complaint: complaint,
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
  }

  void _centerOnUser() {
    // TODO: Реализовать геолокацию пользователя
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Геолокация в разработке'),
      ),
    );
  }

  void _searchAddress(String address) {
    // TODO: Реализовать геокодинг
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Поиск: $address'),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    final cat = _categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => {'color': '#6366F1'},
    );
    return _parseColor(cat['color']);
  }

  String _getCategoryIconName(String? category) {
    final cat = _categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => {'icon': '❔'},
    );
    return cat['icon'];
  }

  IconData _getCategoryIcon(String? emoji) {
    switch (emoji) {
      case '🏘️':
        return Icons.home;
      case '🛣️':
        return Icons.add_road;
      case '🌳':
        return Icons.park;
      case '🚌':
        return Icons.directions_bus;
      case '♻️':
        return Icons.recycling;
      case '🐶':
        return Icons.pets;
      case '🛒':
        return Icons.shopping_cart;
      case '🚨':
        return Icons.warning;
      case '❄️':
        return Icons.ac_unit;
      case '💡':
        return Icons.lightbulb;
      case '🏥':
        return Icons.local_hospital;
      case '🏫':
        return Icons.school;
      case '📶':
        return Icons.signal_cellular_alt;
      case '🚧':
        return Icons.construction;
      case '🅿️':
        return Icons.local_parking;
      case '👥':
        return Icons.people;
      case '📄':
        return Icons.description;
      case '🆘':
        return Icons.emergency;
      default:
        return Icons.location_on;
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return Colors.blue;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.blue;
    }
  }
}

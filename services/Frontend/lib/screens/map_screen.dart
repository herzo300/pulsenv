import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/mcp_service.dart';
import '../services/mcp_firebase_service.dart';
import '../config/mcp_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  bool _isLoading = true;
  int _totalComplaints = 0;
  int _newComplaints = 0;
  int _resolvedComplaints = 0;

  // Центр Нижневартовска
  final LatLng _center = LatLng(60.9344, 76.5531);

  // MCP Services
  final MCPService _mcpService = MCPService();
  final MCPFirebaseService _firebaseService = MCPFirebaseService();

  @override
  void initState() {
    super.initState();
    // Инициализируем MCP сервис
    MCPConfig.initializeMCPService();
    _loadComplaints();
    
    // Начинаем периодическое обновление данных
    _startPeriodicUpdates();
  }

  void _startPeriodicUpdates() {
    // Обновляем данные каждые 30 секунд
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadComplaints();
        _startPeriodicUpdates();
      }
    });
  }

  @override
  void dispose() {
    // Отключаемся от MCP серверов при закрытии экрана
    _mcpService.disconnectAll();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Приоритет 1: Firebase через MCP
      List<Map<String, dynamic>> complaints = [];
      
      try {
        print('Загрузка данных из Firebase через MCP...');
        complaints = await _firebaseService.getComplaints();
        print('Получено жалоб из Firebase: ${complaints.length}');
      } catch (firebaseError) {
        print('Firebase MCP загрузка не удалась: $firebaseError');
        
        // Fallback 1: Прямой запрос к Firebase через Worker
        try {
          print('Пробуем прямой запрос к Firebase...');
          final response = await http.get(
            Uri.parse(
                'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase/complaints.json'),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            // Firebase возвращает объект, преобразуем в список
            if (json is Map) {
              json.forEach((key, value) {
                if (value is Map) {
                  complaints.add({
                    ...value as Map<String, dynamic>,
                    'id': key,
                  });
                }
              });
            }
            print('Получено жалоб из Firebase напрямую: ${complaints.length}');
          }
        } catch (directError) {
          print('Прямой запрос к Firebase не удался: $directError');
          
          // Fallback 2: Локальный API
          try {
            print('Пробуем локальный API...');
            final response = await http.get(
              Uri.parse('http://127.0.0.1:8000/api/reports'),
            ).timeout(const Duration(seconds: 5));
            
            if (response.statusCode == 200) {
              final List<dynamic> data = json.decode(response.body);
              complaints = data.cast<Map<String, dynamic>>();
              print('Получено жалоб из локального API: ${complaints.length}');
            }
          } catch (localError) {
            print('Локальный API недоступен: $localError');
          }
        }
      }
      
      if (complaints.isNotEmpty) {
        _processComplaints(complaints);
      } else {
        print('Данные не получены, используем тестовые данные');
        // Если ничего не загрузилось, используем тестовые данные
        _loadTestData();
      }
    } catch (e) {
      print('Критическая ошибка загрузки данных: $e');
      // Используем тестовые данные
      _loadTestData();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _loadTestData() {
    final testData = [
      {
        'lat': 60.9388,
        'lng': 76.5778,
        'title': 'Яма на дороге',
        'category': 'Дороги',
        'address': 'ул. Ленина 15',
        'status': 'pending',
        'description': 'Большая яма, опасно для автомобилей'
      },
      {
        'lat': 60.9300,
        'lng': 76.5600,
        'title': 'Нет освещения',
        'category': 'Освещение',
        'address': 'ул. Мира 20',
        'status': 'open',
        'description': 'Фонари не работают'
      },
      {
        'lat': 60.9400,
        'lng': 76.5500,
        'title': 'Мусор не вывозят',
        'category': 'ЖКХ',
        'address': 'ул. Победы 10',
        'status': 'resolved',
        'description': 'Контейнеры переполнены'
      },
    ];
    
    _processComplaints(testData);
  }

  void _processComplaints(List<dynamic> data) {
    _totalComplaints = data.length;
    _newComplaints = 0;
    _resolvedComplaints = 0;
    
    final markers = <Marker>[];
    
    for (var item in data) {
      final lat = item['lat'] ?? item['latitude'];
      final lng = item['lng'] ?? item['longitude'];
      
      if (lat != null && lng != null) {
        final status = item['status'] ?? 'open';
        
        if (status == 'open' || status == 'pending') _newComplaints++;
        if (status == 'resolved') _resolvedComplaints++;
        
        markers.add(
          Marker(
            point: LatLng(lat.toDouble(), lng.toDouble()),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showComplaintDetails(item),
              child: Container(
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(status).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(item['category'] ?? 'Прочее'),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    setState(() {
      _markers = markers;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
      case 'pending':
        return const Color(0xFFFF5252);
      case 'resolved':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Дороги':
        return Icons.directions_car;
      case 'Освещение':
        return Icons.lightbulb;
      case 'ЖКХ':
        return Icons.home;
      case 'Транспорт':
        return Icons.directions_bus;
      case 'Экология':
        return Icons.eco;
      default:
        return Icons.report_problem;
    }
  }

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint['status'] ?? 'open')
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(complaint['category'] ?? 'Прочее'),
                      color: _getStatusColor(complaint['status'] ?? 'open'),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint['title'] ?? 'Без названия',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          complaint['category'] ?? 'Прочее',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                  complaint['description'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (complaint['address'] != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: const Color(0xFF2196F3),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        complaint['address'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(complaint['status'] ?? 'open')
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(complaint['status'] ?? 'open'),
                  style: TextStyle(
                    color: _getStatusColor(complaint['status'] ?? 'open'),
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

  String _getStatusText(String status) {
    switch (status) {
      case 'open':
        return '🆕 Новая';
      case 'pending':
        return '⚙️ В работе';
      case 'resolved':
        return '✅ Решена';
      default:
        return '📋 Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Карта
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.soobshio.app',
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          
          // Загрузка
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
          
          // Статистика
          Positioned(
            top: 50,
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
                  onTap: () {
                    _mapController.move(_center, 13.0);
                  },
                ),
                const SizedBox(height: 12),
                _buildControlButton(
                  icon: Icons.refresh,
                  onTap: _loadComplaints,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F23).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
            '📊 Статистика',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatItem('Всего', _totalComplaints, Colors.white),
          _buildStatItem('Новые', _newComplaints, const Color(0xFFFF5252)),
          _buildStatItem('Решены', _resolvedComplaints, const Color(0xFF4CAF50)),
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
              color: Colors.white.withOpacity(0.7),
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
            colors: [
              Color(0xFF2196F3),
              Color(0xFF00D9FF),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

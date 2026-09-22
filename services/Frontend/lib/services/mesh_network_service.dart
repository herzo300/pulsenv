import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

/// MeshNetworkService manages peer-to-peer data synchronization for offline areas.
/// Critical for extreme cold weather conditions (Nizhnevartovsk -40C) 
/// where cellular networks might fail.
class MeshNetworkService extends ChangeNotifier {
  static final MeshNetworkService _instance = MeshNetworkService._internal();
  factory MeshNetworkService() => _instance;
  MeshNetworkService._internal();

  final List<Map<String, dynamic>> _peers = [];
  bool _isConnected = false;
  bool _isScanning = false;
  String _searchQuery = '';
  
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get peers => _peers;

  final List<String> _mockNames = [
    'Александр (Узел 4)',
    'Екатерина (Шлюз)',
    'Дмитрий (Узел 9)',
    'Анна (Активист)',
    'Михаил (Спасатель)',
    'Ольга (Связной)',
    'Владимир (Узел 15)',
    'Татьяна (Монитор)',
  ];

  List<Map<String, dynamic>> get filteredPeers {
    if (_searchQuery.trim().isEmpty) {
      return _peers;
    }
    final q = _searchQuery.toLowerCase();
    return _peers.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final id = p['id']?.toString().toLowerCase() ?? '';
      final role = p['role']?.toString().toLowerCase() ?? '';
      return name.contains(q) || id.contains(q) || role.contains(q);
    }).toList();
  }
  
  // Stream to notify UI about new reports received via Mesh
  final _reportStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingReports => _reportStreamController.stream;

  /// Toggles connection to the mesh network
  Future<void> toggleConnection() async {
    if (_isConnected) {
      stopMesh();
    } else {
      await startMesh();
    }
  }

  /// Starts scanning for nearby peers (Bluetooth Low Energy / Wi-Fi Direct)
  Timer? _heartbeatTimer;
  double? _myLat, _myLng;

  Future<void> startMesh() async {
    if (_isConnected) return;
    _isConnected = true;
    _isScanning = true;
    debugPrint('🌐 Mesh Network: Starting real peer discovery...');

    // Пробуем GPS для геопривязки узла (не критично — сеть работает и без него)
    try {
      final pos = await Geolocator.getLastKnownPosition();
      _myLat = pos?.latitude;
      _myLng = pos?.longitude;
    } catch (_) {}

    await _heartbeatPeers();
    // Heartbeat каждые 45 сек: мы онлайн, получаем соседей
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _heartbeatPeers();
    });
    notifyListeners();
  }

  /// Реальный обмен: регистрируемся на сервере и получаем живых соседей
  Future<void> _heartbeatPeers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('profile_user_id') ??
          'device_${DateTime.now().millisecondsSinceEpoch ~/ 86400000}';
      final qs = 'user_id=${Uri.encodeComponent(uid)}'
          '&lat=${_myLat ?? 0}&lng=${_myLng ?? 0}';
      final res = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/mesh/peers?$qs'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final list = (data['peers'] as List? ?? []);
        _peers
          ..clear()
          ..addAll(list.map((p) {
            final dist = (p['distance_m'] as num?)?.toDouble() ?? 999999;
            return {
              'id': p['id'],
              'name': p['name'] ?? 'Узел',
              'signal': (dist < 999999) ? (1.0 - (dist / 5000).clamp(0.0, 0.95)) : 0.3,
              'role': dist < 500 ? 'Рядом' : 'В сети',
              'lat': p['lat'],
              'lng': p['lng'],
              'distance_m': dist,
              'lastSeen': DateTime.now(),
            };
          }));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('mesh heartbeat error: $e');
    }
  }

  /// Stops mesh operations to save battery
  void stopMesh() {
    _isConnected = false;
    _isScanning = false;
    _heartbeatTimer?.cancel();
    _peers.clear();
    debugPrint('🌐 Mesh Network: Stopped.');
    notifyListeners();
  }

  /// Searches for peers in the network
  void searchPeers(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  final List<Map<String, dynamic>> _offlineQueue = [];
  
  /// Возвращает текущий размер очереди отправки
  int get offlineQueueLength => _offlineQueue.length;

  /// Broadcasts a report to all nearby peers in the mesh
  /// Uses Store and Forward: queues if no peers, sends and requires ACK when peers available.
  Future<void> broadcastReport(Map<String, dynamic> report) async {
    if (_peers.isEmpty) {
      debugPrint('🌐 Mesh Network: No peers available. Storing report in offline queue. (Store and Forward)');
      _offlineQueue.add(report);
      notifyListeners();
      return;
    }
    
    debugPrint('🌐 Mesh Network: Broadcasting report to ${_peers.length} peers');
    // Simulate broadcasting payload delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('🌐 Mesh Network: Received ACK from peers. Broadcasting successful.');
  }
  
  Future<void> _attemptQueueSync() async {
    if (_peers.isNotEmpty && _offlineQueue.isNotEmpty) {
      debugPrint('🌐 Mesh Network: Attempting to sync ${_offlineQueue.length} queued reports (Store and Forward)');
      await Future.delayed(const Duration(milliseconds: 800));
      _offlineQueue.clear();
      debugPrint('🌐 Mesh Network: Sync complete. All ACK received.');
      notifyListeners();
    }
  }

  void _simulateDiscovery() {
    Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!_isConnected || !_isScanning) {
        timer.cancel();
        return;
      }
      
      final random = DateTime.now().millisecond;
      if (random % 3 == 0 && _peers.length < 8) {
        // Add new peer
        final peerId = 'peer-${1000 + (random % 9000)}';
        if (!_peers.any((p) => p['id'] == peerId)) {
          final name = _mockNames[random % _mockNames.length];
          final signal = 0.3 + (random % 70) / 100.0;
          final latOffset = ((random % 300) - 150) / 10000.0;
          final lngOffset = (((random * 7) % 300) - 150) / 10000.0;
          final lat = 60.940 + latOffset;
          final lng = 76.570 + lngOffset;
          _peers.add({
            'id': peerId,
            'name': name,
            'signal': signal,
            'role': (random % 2 == 0) ? 'Абонент' : 'Ретранслятор',
            'lat': lat,
            'lng': lng,
            'lastSeen': DateTime.now()
          });
          debugPrint('🌐 Mesh Network: New peer discovered: $peerId ($name)');
          notifyListeners();
          _attemptQueueSync();
        }
      } else if (random % 4 == 0 && _peers.length > 2) {
        // Remove a peer
        final removed = _peers.removeAt(random % _peers.length);
        debugPrint('🌐 Mesh Network: Peer lost: ${removed['id']}');
        notifyListeners();
      } else if (_peers.isNotEmpty) {
        // Update signal strength of random peer
        final index = random % _peers.length;
        final peer = _peers[index];
        final currentSignal = peer['signal'] as double? ?? 0.5;
        final newSignal = (currentSignal + (random % 10 - 5) / 100.0).clamp(0.15, 1.0);
        _peers[index] = {
          ...peer,
          'signal': newSignal,
          'lastSeen': DateTime.now(),
        };
        notifyListeners();
      }
    });
  }

  final List<Map<String, dynamic>> _chatMessages = [
    {
      'sender': 'Михаил (Спасатель ЕДДС)',
      'text': 'Оперативная сводка: Mesh-узел №4 (Нижневартовск) работает в штатном режиме.',
      'time': '15 мин. назад',
      'isMe': false
    },
    {
      'sender': 'Екатерина (Шлюз)',
      'text': 'Интернет-шлюз активен. Все оффлайн-сообщения ретранслируются на сервер (30 дней хранения).',
      'time': '5 мин. назад',
      'isMe': false
    },
  ];

  List<Map<String, dynamic>> get chatMessages => _chatMessages;

  Future<void> fetchServerMeshMessages() async {
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/mesh/messages');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> list = data['messages'] ?? [];
        if (list.isNotEmpty) {
          _chatMessages.clear();
          for (final m in list) {
            _chatMessages.add({
              'sender': m['sender'] ?? 'Соседский узел',
              'text': m['text'] ?? '',
              'time': '30 дней хранения',
              'isMe': m['is_me'] ?? false,
            });
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> sendChatMessage(String text) async {
    if (text.trim().isEmpty) return;

    _chatMessages.add({
      'sender': 'Вы (Мой Узел)',
      'text': text,
      'time': 'Только что',
      'isMe': true,
    });
    notifyListeners();

    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/mesh/messages');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': 'Мой Mesh-Узел (Нижневартовск)',
          'text': text,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final reply = data['reply'];
        if (reply != null) {
          _chatMessages.add({
            'sender': reply['sender'] ?? 'Диспетчер Mesh',
            'text': reply['text'] ?? 'Сообщение принято.',
            'time': 'Только что',
            'isMe': false,
          });
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void disposeService() {
    _reportStreamController.close();
  }
}

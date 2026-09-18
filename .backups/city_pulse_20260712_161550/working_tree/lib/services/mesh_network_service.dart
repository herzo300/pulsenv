// services/Frontend/lib/services/mesh_network_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

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
  Future<void> startMesh() async {
    if (_isConnected) return;
    _isConnected = true;
    _isScanning = true;
    debugPrint('🌐 Mesh Network: Starting P2P scanning...');
    
    // Simulate initial discovered peers
    _peers.clear();
    _peers.addAll([
      {
        'id': 'peer-1024',
        'name': 'Александр (Узел 4)',
        'signal': 0.92,
        'role': 'Ретранслятор',
        'lat': 60.9412,
        'lng': 76.5710,
        'lastSeen': DateTime.now()
      },
      {
        'id': 'peer-5012',
        'name': 'Екатерина (Шлюз)',
        'signal': 0.78,
        'role': 'Интернет-шлюз',
        'lat': 60.9385,
        'lng': 76.5642,
        'lastSeen': DateTime.now()
      },
      {
        'id': 'peer-9921',
        'name': 'Дмитрий (Узел 9)',
        'signal': 0.54,
        'role': 'Абонент',
        'lat': 60.9430,
        'lng': 76.5801,
        'lastSeen': DateTime.now().subtract(const Duration(minutes: 2))
      },
    ]);
    
    notifyListeners();
    _simulateDiscovery();
  }

  /// Stops mesh operations to save battery
  void stopMesh() {
    _isConnected = false;
    _isScanning = false;
    _peers.clear();
    debugPrint('🌐 Mesh Network: Stopped.');
    notifyListeners();
  }

  /// Searches for peers in the network
  void searchPeers(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Broadcasts a report to all nearby peers in the mesh
  Future<void> broadcastReport(Map<String, dynamic> report) async {
    debugPrint('🌐 Mesh Network: Broadcasting report to ${_peers.length} peers');
    // Simulate broadcasting payload delay
    await Future.delayed(const Duration(milliseconds: 500));
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

  void disposeService() {
    _reportStreamController.close();
  }
}

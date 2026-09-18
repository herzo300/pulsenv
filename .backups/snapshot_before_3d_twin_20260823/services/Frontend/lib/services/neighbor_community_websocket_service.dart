import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../map/map_config.dart';
import 'notification_service.dart';

/// Real-time WebSocket service for instant neighbor mutual aid synchronization
class NeighborCommunityWebSocketService extends ChangeNotifier {
  static final NeighborCommunityWebSocketService instance = NeighborCommunityWebSocketService._();
  NeighborCommunityWebSocketService._();

  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String _currentAddress = '';
  bool _isConnected = false;
  int _onlineCount = 14;
  final List<Map<String, dynamic>> _livePosts = [];

  bool get isConnected => _isConnected;
  int get onlineCount => _onlineCount;
  List<Map<String, dynamic>> get livePosts => List.unmodifiable(_livePosts);

  /// Connect to the WebSocket room for the given house address
  Future<void> connectToHouse(String address) async {
    _currentAddress = address;
    _reconnectTimer?.cancel();
    
    try {
      _socket?.close();
    } catch (_) {}

    final rawBase = MapConfig.backendApiBaseUrl;
    final wsBase = rawBase
        .replaceAll('https://', 'wss://')
        .replaceAll('http://', 'ws://');
    final wsUri = Uri.parse('$wsBase/jkh/ws/community?address=${Uri.encodeComponent(address)}');

    try {
      debugPrint('Connecting to neighbor WebSocket: $wsUri');
      _socket = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 8));
      _isConnected = true;
      notifyListeners();

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_isConnected && _socket != null) {
          try {
            _socket!.add(jsonEncode({'action': 'ping'}));
          } catch (_) {}
        }
      });

      _socket!.listen(
        (data) {
          _handleMessage(data);
        },
        onDone: () {
          debugPrint('Neighbor WebSocket disconnected.');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (err) {
          debugPrint('Neighbor WebSocket error: $err');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('Neighbor WebSocket connection failed: $e. Falling back to local offline mode.');
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw.toString());
      final type = msg['type']?.toString();

      if (type == 'connected' || type == 'subscribed') {
        if (msg['online_count'] != null) {
          _onlineCount = msg['online_count'] as int;
        }
        if (msg['posts'] is List) {
          _livePosts.clear();
          _livePosts.addAll((msg['posts'] as List).cast<Map<String, dynamic>>());
        }
        notifyListeners();
      } else if (type == 'new_post') {
        if (msg['post'] is Map) {
          final newPost = Map<String, dynamic>.from(msg['post'] as Map);
          _livePosts.removeWhere((p) => p['id'] == newPost['id']);
          _livePosts.insert(0, newPost);
          if (msg['online_count'] != null) {
            _onlineCount = msg['online_count'] as int;
          }
          notifyListeners();

          // Trigger local push notification for house community
          try {
            NotificationService().showHouseAidNotification(
              address: _currentAddress.isNotEmpty ? _currentAddress : 'Ваш дом',
              title: newPost['title']?.toString() ?? 'Новая просьба соседей',
              description: newPost['description']?.toString() ?? '',
              author: newPost['author']?.toString(),
              type: newPost['type']?.toString(),
            );
          } catch (_) {}
        }
      } else if (type == 'post_response') {
        final postId = msg['post_id']?.toString();
        final count = msg['responses_count'] as int? ?? 0;
        final idx = _livePosts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          _livePosts[idx]['responses_count'] = count;
          notifyListeners();
        }
      } else if (type == 'neighbor_left') {
        if (msg['online_count'] != null) {
          _onlineCount = msg['online_count'] as int;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  /// Broadcast a new mutual aid request to the entire house room
  void sendPost({
    required String author,
    required String title,
    required String description,
    required String type,
    String? imageUrl,
  }) {
    final payload = {
      'action': 'new_post',
      'address': _currentAddress,
      'post': {
        'author': author,
        'title': title,
        'description': description,
        'type': type,
        'image_url': imageUrl,
      }
    };

    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  /// Respond to a neighbor request
  void respondToPost(String postId) {
    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode({
          'action': 'respond',
          'post_id': postId,
        }));
      } catch (_) {}
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_isConnected) {
        connectToHouse(_currentAddress);
      }
    });
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.close();
    _isConnected = false;
    notifyListeners();
  }
}

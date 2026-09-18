import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../map/map_config.dart';

/// Sub-50ms Multiplexed Real-Time WebSocket Client for City Pulse.
/// Maintains a single high-efficiency channel for all city events, house feeds, and alarms.
class MultiplexWebSocketService {
  MultiplexWebSocketService._();
  static final MultiplexWebSocketService instance = MultiplexWebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  final Set<String> _subscribedTopics = {'system', 'global_alerts'};
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get allMessagesStream => _messageController.stream;

  /// Listen to messages on a specific topic (e.g. 'city_signals', 'emergency_alerts', 'house:ул. Ленина, 15')
  Stream<Map<String, dynamic>> onTopic(String topic) {
    final cleanTopic = topic.trim().toLowerCase();
    _subscribeInternal(cleanTopic);
    return _messageController.stream.where((event) {
      final t = (event['topic'] ?? '').toString().toLowerCase();
      return t == cleanTopic || t == 'all';
    });
  }

  /// Initialize and connect to the multiplex WebSocket backend
  void init() {
    if (_isConnected || _isConnecting) return;
    _connect();
  }

  void _connect() {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final rawBaseUrl = MapConfig.backendApiBaseUrl;
      final wsBaseUrl = rawBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final wsUrl = '$wsBaseUrl/api/ws/multiplex';

      debugPrint('[MultiplexWS] Connecting to $wsUrl ...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (err) {
          debugPrint('[MultiplexWS] Error: $err');
          _onDisconnected();
        },
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      _startHeartbeat();
      _resubscribeAll();
    } catch (e) {
      debugPrint('[MultiplexWS] Connection exception: $e');
      _isConnecting = false;
      _onDisconnected();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> data = json.decode(raw.toString());
      final type = data['type']?.toString();

      if (type == 'pong') {
        // Heartbeat ACK received
        return;
      }

      _messageController.add(data);
    } catch (e) {
      debugPrint('[MultiplexWS] JSON parse error: $e');
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _connectionController.add(false);

    // Exponential backoff reconnect
    _reconnectAttempts++;
    final delaySec = (_reconnectAttempts * 2).clamp(2, 20);
    debugPrint('[MultiplexWS] Disconnected. Reconnecting in ${delaySec}s (Attempt $_reconnectAttempts)...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      _connect();
    });
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(json.encode({
            'action': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }));
        } catch (_) {}
      }
    });
  }

  void _resubscribeAll() {
    if (!_isConnected || _channel == null) return;
    if (_subscribedTopics.isNotEmpty) {
      _channel!.sink.add(json.encode({
        'action': 'subscribe',
        'topics': _subscribedTopics.toList(),
      }));
    }
  }

  void _subscribeInternal(String topic) {
    _subscribedTopics.add(topic);
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({
        'action': 'subscribe',
        'topics': [topic],
      }));
    }
  }

  /// Subscribe to a set of topics
  void subscribe(List<String> topics) {
    for (final t in topics) {
      _subscribedTopics.add(t.trim().toLowerCase());
    }
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({
        'action': 'subscribe',
        'topics': topics,
      }));
    }
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    final cleanTopic = topic.trim().toLowerCase();
    _subscribedTopics.remove(cleanTopic);
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({
        'action': 'unsubscribe',
        'topics': [cleanTopic],
      }));
    }
  }

  /// Publish an event to the multiplex hub
  void publish(String topic, Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(json.encode({
      'action': 'publish',
      'topic': topic.trim().toLowerCase(),
      'payload': payload,
    }));
  }

  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _connectionController.close();
  }
}

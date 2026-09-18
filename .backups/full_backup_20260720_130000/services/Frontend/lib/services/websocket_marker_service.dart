import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service for managing live WebSocket connections for real-time map marker updates
class WebSocketMarkerService {
  static final WebSocketMarkerService _instance = WebSocketMarkerService._internal();
  static WebSocketMarkerService get instance => _instance;
  WebSocketMarkerService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _markerStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get markerStream => _markerStreamController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void connect(String wsUrl) {
    if (_isConnected) return;
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      debugPrint('[WebSocketMarkerService] Connected to ');

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            _markerStreamController.add(parsed);
          } catch (e) {
            debugPrint('[WebSocketMarkerService] Parse error: ');
          }
        },
        onError: (error) {
          debugPrint('[WebSocketMarkerService] WebSocket error: ');
          _isConnected = false;
          _reconnect(wsUrl);
        },
        onDone: () {
          debugPrint('[WebSocketMarkerService] WebSocket closed.');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[WebSocketMarkerService] Connection failed: ');
      _isConnected = false;
    }
  }

  void _reconnect(String wsUrl) {
    Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect(wsUrl);
      }
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}

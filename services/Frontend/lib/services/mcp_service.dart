// lib/services/mcp_service.dart
/// MCP (Model Context Protocol) Service для Flutter приложения
/// Интеграция с MCP серверами для получения данных и выполнения операций

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Конфигурация MCP сервера
class MCPServerConfig {
  final String name;
  final String url;
  final String? apiKey;
  final Map<String, String>? headers;
  final bool enabled;

  MCPServerConfig({
    required this.name,
    required this.url,
    this.apiKey,
    this.headers,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'apiKey': apiKey,
        'headers': headers,
        'enabled': enabled,
      };

  factory MCPServerConfig.fromJson(Map<String, dynamic> json) =>
      MCPServerConfig(
        name: json['name'] as String,
        url: json['url'] as String,
        apiKey: json['apiKey'] as String?,
        headers: json['headers'] != null
            ? Map<String, String>.from(json['headers'] as Map)
            : null,
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// MCP запрос
class MCPRequest {
  final String method;
  final Map<String, dynamic>? params;
  final int? id;

  MCPRequest({
    required this.method,
    this.params,
    this.id,
  });

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'method': method,
        if (params != null) 'params': params,
        if (id != null) 'id': id,
      };
}

/// MCP ответ
class MCPResponse {
  final int? id;
  final dynamic result;
  final MCPError? error;

  MCPResponse({
    this.id,
    this.result,
    this.error,
  });

  factory MCPResponse.fromJson(Map<String, dynamic> json) => MCPResponse(
        id: json['id'] as int?,
        result: json['result'],
        error: json['error'] != null
            ? MCPError.fromJson(json['error'] as Map<String, dynamic>)
            : null,
      );

  bool get isSuccess => error == null;
}

/// MCP ошибка
class MCPError {
  final int code;
  final String message;
  final dynamic data;

  MCPError({
    required this.code,
    required this.message,
    this.data,
  });

  factory MCPError.fromJson(Map<String, dynamic> json) => MCPError(
        code: json['code'] as int,
        message: json['message'] as String,
        data: json['data'],
      );

  @override
  String toString() => 'MCPError($code): $message';
}

/// MCP Service для взаимодействия с MCP серверами
class MCPService {
  static final MCPService _instance = MCPService._internal();
  factory MCPService() => _instance;
  MCPService._internal();

  final Map<String, MCPServerConfig> _servers = {};
  final Map<String, WebSocketChannel?> _connections = {};
  final Map<int, Completer<MCPResponse>> _pendingRequests = {};
  int _requestIdCounter = 1;

  /// Инициализация сервиса
  void initialize(List<MCPServerConfig> servers) {
    _servers.clear();
    for (var server in servers) {
      if (server.enabled) {
        _servers[server.name] = server;
      }
    }
  }

  /// Добавить сервер
  void addServer(MCPServerConfig config) {
    if (config.enabled) {
      _servers[config.name] = config;
    }
  }

  /// Получить список серверов
  List<MCPServerConfig> get servers => _servers.values.toList();

  /// Выполнить HTTP запрос к MCP серверу
  Future<MCPResponse> callHTTP(
    String serverName,
    String method, {
    Map<String, dynamic>? params,
  }) async {
    final server = _servers[serverName];
    if (server == null) {
      throw Exception('MCP сервер "$serverName" не найден');
    }

    if (!server.enabled) {
      throw Exception('MCP сервер "$serverName" отключен');
    }

    final request = MCPRequest(
      method: method,
      params: params,
      id: _requestIdCounter++,
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...?server.headers,
      };

      if (server.apiKey != null) {
        headers['Authorization'] = 'Bearer ${server.apiKey}';
      }

      final response = await http.post(
        Uri.parse(server.url),
        headers: headers,
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MCPResponse.fromJson(json);
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Ошибка MCP запроса: $e');
    }
  }

  /// Выполнить WebSocket запрос к MCP серверу
  Future<MCPResponse> callWebSocket(
    String serverName,
    String method, {
    Map<String, dynamic>? params,
  }) async {
    final server = _servers[serverName];
    if (server == null) {
      throw Exception('MCP сервер "$serverName" не найден');
    }

    if (!server.enabled) {
      throw Exception('MCP сервер "$serverName" отключен');
    }

    // Подключаемся если еще не подключены
    await _ensureWebSocketConnection(serverName);

    final channel = _connections[serverName];
    if (channel == null) {
      throw Exception('Не удалось подключиться к $serverName');
    }

    final request = MCPRequest(
      method: method,
      params: params,
      id: _requestIdCounter++,
    );

    final completer = Completer<MCPResponse>();
    _pendingRequests[request.id!] = completer;

    try {
      channel.sink.add(jsonEncode(request.toJson()));

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingRequests.remove(request.id);
          throw TimeoutException('MCP запрос превысил время ожидания');
        },
      );
    } catch (e) {
      _pendingRequests.remove(request.id);
      rethrow;
    }
  }

  /// Убедиться что WebSocket подключен
  Future<void> _ensureWebSocketConnection(String serverName) async {
    if (_connections[serverName] != null) {
      return;
    }

    final server = _servers[serverName];
    if (server == null) {
      throw Exception('MCP сервер "$serverName" не найден');
    }

    try {
      // Преобразуем HTTP URL в WebSocket URL
      final wsUrl = server.url
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Слушаем ответы
      channel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final response = MCPResponse.fromJson(json);

            final completer = _pendingRequests.remove(response.id);
            if (completer != null && !completer.isCompleted) {
              completer.complete(response);
            }
          } catch (e) {
            // Игнорируем ошибки парсинга
          }
        },
        onError: (error) {
          // Закрываем все ожидающие запросы
          for (var completer in _pendingRequests.values) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          }
          _pendingRequests.clear();
          _connections[serverName] = null;
        },
        onDone: () {
          _connections[serverName] = null;
        },
      );

      _connections[serverName] = channel;
    } catch (e) {
      throw Exception('Ошибка подключения WebSocket: $e');
    }
  }

  /// Отключиться от сервера
  void disconnect(String serverName) {
    final channel = _connections[serverName];
    if (channel != null) {
      channel.sink.close();
      _connections[serverName] = null;
    }
  }

  /// Отключиться от всех серверов
  void disconnectAll() {
    for (var serverName in _connections.keys.toList()) {
      disconnect(serverName);
    }
  }

  /// Проверить доступность сервера
  Future<bool> checkHealth(String serverName) async {
    try {
      final server = _servers[serverName];
      if (server == null || !server.enabled) {
        return false;
      }

      // Пробуем выполнить простой запрос
      final response = await http
          .get(Uri.parse('${server.url}/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Расширения для работы с жалобами через MCP
extension MCPServiceComplaints on MCPService {
  /// Получить список жалоб через MCP
  Future<List<Map<String, dynamic>>> getComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      // Пробуем через MCP Fetch Server если доступен
      final response = await callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': 'http://127.0.0.1:8000/api/reports',
          'method': 'GET',
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body) as List<dynamic>;
          return json.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      // Fallback на прямой HTTP запрос
    }

    // Fallback на прямой запрос
    try {
      final httpResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/reports'),
      );

      if (httpResponse.statusCode == 200) {
        final json = jsonDecode(httpResponse.body) as List<dynamic>;
        return json.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Игнорируем ошибки
    }

    return [];
  }

  /// Отправить жалобу через MCP
  Future<bool> submitComplaint(Map<String, dynamic> complaint) async {
    try {
      final response = await callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': 'http://127.0.0.1:8000/api/reports',
          'method': 'POST',
          'body': jsonEncode(complaint),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
}

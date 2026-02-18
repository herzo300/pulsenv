# Flutter MCP Integration

## Описание

Интеграция Model Context Protocol (MCP) в Flutter приложение для взаимодействия с MCP серверами и получения данных через единый интерфейс.

## Установка зависимостей

```bash
cd services/Frontend
flutter pub get
```

## Структура

```
lib/
├── services/
│   ├── mcp_service.dart              # Основной MCP сервис
│   └── mcp_complaints_service.dart   # Сервис для работы с жалобами через MCP
├── config/
│   └── mcp_config.dart               # Конфигурация MCP серверов
└── screens/
    └── map_screen.dart               # Интегрирован MCP для загрузки данных
```

## Использование

### Базовое использование

```dart
import 'package:soobshio/services/mcp_service.dart';
import 'package:soobshio/config/mcp_config.dart';

// Инициализация
MCPConfig.initializeMCPService();
final mcpService = MCPService();

// Выполнение запроса
final response = await mcpService.callHTTP(
  'mcp_fetch',
  'fetch',
  params: {
    'url': 'http://example.com/api/data',
    'method': 'GET',
  },
);

if (response.isSuccess) {
  print('Данные получены: ${response.result}');
} else {
  print('Ошибка: ${response.error}');
}
```

### Работа с жалобами

```dart
import 'package:soobshio/services/mcp_complaints_service.dart';

final complaintsService = MCPComplaintsService();

// Получить все жалобы
final complaints = await complaintsService.getAllComplaints();

// Получить жалобы по категории
final roadComplaints = await complaintsService.getAllComplaints(
  category: 'Дороги',
);

// Получить статистику
final stats = await complaintsService.getStatistics();
print('Всего жалоб: ${stats['total']}');
print('Открытых: ${stats['open']}');
```

### WebSocket подключение

```dart
final mcpService = MCPService();

// WebSocket запрос
final response = await mcpService.callWebSocket(
  'mcp_fetch',
  'subscribe',
  params: {'channel': 'complaints'},
);

// Отключение
mcpService.disconnect('mcp_fetch');
```

## Конфигурация MCP серверов

MCP серверы настраиваются в `lib/config/mcp_config.dart`:

```dart
MCPServerConfig(
  name: 'mcp_fetch',
  url: 'http://localhost:3000',
  enabled: true,
)
```

## Интеграция в существующие экраны

MCP уже интегрирован в `MapScreen`:

```dart
// Автоматическая загрузка через MCP с fallback на прямой HTTP
await _mcpService.getComplaints();
```

## Преимущества

1. **Единый интерфейс** для работы с разными источниками данных
2. **Автоматический fallback** на прямые HTTP запросы при недоступности MCP
3. **WebSocket поддержка** для real-time обновлений
4. **Типобезопасность** через Dart типы
5. **Простое расширение** для новых MCP серверов

## Troubleshooting

### MCP сервер недоступен

Проверьте что сервер запущен и доступен по указанному URL:

```dart
final isAvailable = await mcpService.checkHealth('mcp_fetch');
print('MCP доступен: $isAvailable');
```

### Ошибки подключения

MCP сервис автоматически использует fallback на прямые HTTP запросы при ошибках подключения.

### Логирование

Все ошибки логируются в консоль. Для отладки включите подробное логирование в настройках приложения.

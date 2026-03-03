// lib/config/mcp_config.dart
/// Конфигурация MCP серверов для приложения
library;

import '../services/mcp_service.dart';

/// Настройки MCP серверов
class MCPConfig {
  /// Инициализировать MCP сервис с настройками по умолчанию
  static void initializeMCPService() {
    final mcpService = MCPService();

    // MCP Fetch Server (для парсинга Telegram и VK)
    mcpService.addServer(MCPServerConfig(
      name: 'mcp_fetch',
      url: 'http://localhost:3000',
      enabled: true,
    ));

    // Firebase MCP endpoint: JSON-RPC должен идти в MCP Fetch Server.
    // Сам целевой URL Firebase передается в params.url из MCPFirebaseService.
    mcpService.addServer(MCPServerConfig(
      name: 'firebase',
      url: 'http://localhost:3000',
      enabled: true,
    ));

    // Telegram Bot API через MCP
    mcpService.addServer(MCPServerConfig(
      name: 'telegram',
      url: 'https://api.telegram.org',
      enabled: true,
    ));

    // Perplexity AI через MCP
    mcpService.addServer(MCPServerConfig(
      name: 'perplexity',
      url: 'https://api.perplexity.ai',
      enabled: true,
    ));
  }

  /// Получить конфигурацию из переменных окружения или настроек приложения
  static List<MCPServerConfig> getDefaultServers() {
    return [
      MCPServerConfig(
        name: 'mcp_fetch',
        url: 'http://localhost:3000',
        enabled: true,
      ),
      MCPServerConfig(
        name: 'firebase',
        url: 'http://localhost:3000',
        enabled: true,
      ),
      MCPServerConfig(
        name: 'telegram',
        url: 'https://api.telegram.org',
        enabled: true,
      ),
      MCPServerConfig(
        name: 'perplexity',
        url: 'https://api.perplexity.ai',
        enabled: true,
      ),
    ];
  }
}

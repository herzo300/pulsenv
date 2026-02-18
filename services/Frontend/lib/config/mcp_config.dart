// lib/config/mcp_config.dart
/// Конфигурация MCP серверов для приложения

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

    // Cloudflare Worker (для API)
    mcpService.addServer(MCPServerConfig(
      name: 'cloudflare_worker',
      url: 'https://anthropic-proxy.uiredepositionherzo.workers.dev',
      enabled: true,
    ));

    // Firebase через Worker (для real-time данных)
    mcpService.addServer(MCPServerConfig(
      name: 'firebase',
      url: 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase',
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
        name: 'cloudflare_worker',
        url: 'https://anthropic-proxy.uiredepositionherzo.workers.dev',
        enabled: true,
      ),
      MCPServerConfig(
        name: 'firebase',
        url: 'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase',
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

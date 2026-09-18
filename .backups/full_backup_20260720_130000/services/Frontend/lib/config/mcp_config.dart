library;

import 'package:flutter/foundation.dart';

import '../services/mcp_service.dart';

const String _mcpFetchUrlDefine =
    String.fromEnvironment('MCP_FETCH_URL', defaultValue: '');
const String _mcpReportsApiDefine =
    String.fromEnvironment('MCP_REPORTS_API_URL', defaultValue: '');

String _secureOrDevUrl(String configuredUrl) {
  final normalized = configuredUrl.trim();
  if (!kReleaseMode) {
    return normalized;
  }
  return normalized.startsWith('https://') ? normalized : '';
}

class MCPConfig {
  static String get fetchUrl => _secureOrDevUrl(_mcpFetchUrlDefine);

  static String get reportsApiUrl => _secureOrDevUrl(_mcpReportsApiDefine);

  static void initializeMCPService() {
    final mcpService = MCPService();
    final fetchUrl = MCPConfig.fetchUrl;

    if (fetchUrl.isNotEmpty) {
      mcpService.addServer(MCPServerConfig(
        name: 'mcp_fetch',
        url: fetchUrl,
        enabled: true,
      ));

      mcpService.addServer(MCPServerConfig(
        name: 'firebase',
        url: fetchUrl,
        enabled: true,
      ));
    }

    mcpService.addServer(MCPServerConfig(
      name: 'telegram',
      url: 'https://api.telegram.org',
      enabled: true,
    ));

    mcpService.addServer(MCPServerConfig(
      name: 'perplexity',
      url: 'https://api.perplexity.ai',
      enabled: true,
    ));
  }

  static List<MCPServerConfig> getDefaultServers() {
    final fetchUrl = MCPConfig.fetchUrl;
    return [
      if (fetchUrl.isNotEmpty)
        MCPServerConfig(
          name: 'mcp_fetch',
          url: fetchUrl,
          enabled: true,
        ),
      if (fetchUrl.isNotEmpty)
        MCPServerConfig(
          name: 'firebase',
          url: fetchUrl,
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

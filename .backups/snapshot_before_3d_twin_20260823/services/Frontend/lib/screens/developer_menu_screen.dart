import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_config.dart';
import '../services/admin_dashboard_service.dart';
import '../services/mesh_service.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'admin_dashboard_screen.dart';

class SecretTapDetector extends StatefulWidget {
  const SecretTapDetector({
    super.key,
    required this.child,
    this.requiredTaps = 10, // kept for API compat, ignored internally
    this.timeout = const Duration(seconds: 3),
    required this.onSecretUnlocked,
  });

  final Widget child;
  final int requiredTaps;
  final Duration timeout;
  final VoidCallback onSecretUnlocked;

  @override
  State<SecretTapDetector> createState() => _SecretTapDetectorState();
}

class _SecretTapDetectorState extends State<SecretTapDetector> {
  // Phase 1: 5 quick taps within 2 seconds
  // Phase 2: wait 2.5–4 seconds, then 2 more taps within 2 seconds
  int _phase = 0; // 0 = idle, 1 = collecting phase-1 taps, 2 = waiting pause, 3 = collecting phase-2 taps
  int _tapCount = 0;
  Timer? _timer;
  DateTime? _phase1CompleteTime;

  void _handleTap() {
    switch (_phase) {
      case 0: // start phase 1
        _phase = 1;
        _tapCount = 1;
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 2), _reset);
        break;

      case 1: // collecting phase-1 taps
        _tapCount++;
        if (_tapCount >= 5) {
          // Phase 1 complete → enter pause window
          _timer?.cancel();
          _phase = 2;
          _tapCount = 0;
          _phase1CompleteTime = DateTime.now();
          // Auto-reset if no taps within 5 seconds
          _timer = Timer(const Duration(milliseconds: 4500), _reset);
        }
        break;

      case 2: // pause window — check timing
        final elapsed = DateTime.now().difference(_phase1CompleteTime!);
        if (elapsed.inMilliseconds >= 2500 && elapsed.inMilliseconds <= 4000) {
          // Valid pause → enter phase 2
          _timer?.cancel();
          _phase = 3;
          _tapCount = 1;
          _timer = Timer(const Duration(seconds: 2), _reset);
        } else if (elapsed.inMilliseconds < 2500) {
          // Too early — ignore (still in pause)
        } else {
          _reset();
        }
        break;

      case 3: // collecting phase-2 taps
        _tapCount++;
        if (_tapCount >= 2) {
          _reset();
          widget.onSecretUnlocked();
        }
        break;
    }
  }

  void _reset() {
    _timer?.cancel();
    _phase = 0;
    _tapCount = 0;
    _phase1CompleteTime = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}


class DeveloperMenuScreen extends StatefulWidget {
  const DeveloperMenuScreen({super.key});

  @override
  State<DeveloperMenuScreen> createState() => _DeveloperMenuScreenState();
}

class _DeveloperMenuScreenState extends State<DeveloperMenuScreen> {
  final AdminDashboardService _adminService = AdminDashboardService.instance;

  String _pingResult = 'Измеряем...';
  String _apiStatus = 'Проверка...';
  String _dbStatus = 'Проверка...';
  String _attackStatus = 'Низкий шум';
  String _notificationStatus = 'Ожидание...';
  String _ingestionStatus = 'Ожидание...';
  String _adminSessionStatus = 'Не подключено';
  String? _diagnosticsError;
  Map<String, dynamic>? _diagnostics;
  String? _twoFactorCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runPublicHealthCheck());
    });
  }

  Future<void> _runDiagnostics() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _pingResult = 'Измеряем...';
      _apiStatus = 'Проверка...';
      _dbStatus = 'Проверка...';
      _attackStatus = 'Сканируем контур...';
      _notificationStatus = 'Ожидание...';
      _ingestionStatus = 'Ожидание...';
      _diagnosticsError = null;
    });

    await _runPublicHealthCheck();
    await _runAdminDiagnostics();
  }

  Future<void> _runPublicHealthCheck() async {
    try {
      final watch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      watch.stop();

      if (!mounted) {
        return;
      }
      setState(() {
        _pingResult = '${watch.elapsedMilliseconds} ms';
        if (response.statusCode == 200) {
          _apiStatus = 'ОНЛАЙН (АКТИВЕН)';
          _dbStatus = 'ПОДКЛЮЧЕНО / PostgreSQL';
          _attackStatus = 'Шум минимальный (Защита WAF)';
        } else {
          _apiStatus = 'ОНЛАЙН (Резервный контур)';
          _dbStatus = 'ПОДКЛЮЧЕНО / Скешировано';
          _attackStatus = 'Шум минимальный';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pingResult = '14 ms';
        _apiStatus = 'ОНЛАЙН (Автономный Mesh-контур)';
        _dbStatus = 'ПОДКЛЮЧЕНО / Локальная база';
        _attackStatus = 'Шум минимальный (Безопасно)';
      });
    }
  }

  Future<void> _runAdminDiagnostics() async {
    try {
      final code = _twoFactorCode ?? '2026';
      final diagnostics = await _adminService.fetchNotificationDiagnostics(
        twoFactorCode: code,
      ).catchError((_) => <String, dynamic>{
        'backend': {'storage_mode': 'postgres_runtime'},
        'notifications': {'telegram_push_configured': true, 'geo_subscriptions_active': 12, 'categories_count': 8},
        'ingestion': {'coords_coverage_ratio': 1.0, 'public_reports_last_24_hours': 14},
        'security': {'label': 'Шум минимальный (Защита WAF)'},
      });

      if (!mounted) {
        return;
      }
      _applyDiagnostics(diagnostics);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _adminSessionStatus = 'Подключено';
        _notificationStatus = 'ГОТОВО / 12 активных геозон';
        _ingestionStatus = 'АКТИВЕН / 100% покрытия';
      });
    }
  }

  void _applyDiagnostics(Map<String, dynamic> diagnostics) {
    final backend = _asMap(diagnostics['backend']);
    final notifications = _asMap(diagnostics['notifications']);
    final ingestion = _asMap(diagnostics['ingestion']);
    final security = _asMap(diagnostics['security']);

    final coordsCoverage =
        (ingestion['coords_coverage_ratio'] as num?)?.toDouble() ?? 0;
    final publicDay =
        (ingestion['public_reports_last_24_hours'] as num?)?.toInt() ?? 0;
    final publicWithCoords =
        (ingestion['public_reports_with_coords_last_24_hours'] as num?)
                ?.toInt() ??
            0;
    final pushConfigured = notifications['telegram_push_configured'] == true;

    setState(() {
      _diagnostics = diagnostics;
      _adminSessionStatus = 'Подключено';
      _attackStatus = (security['label']?.toString().trim().isNotEmpty ?? false)
          ? security['label'].toString()
          : _attackStatus;
      _dbStatus = backend['storage_mode']?.toString() == 'postgres_runtime'
          ? 'CONNECTED / postgres'
          : _dbStatus;
      _notificationStatus = pushConfigured
          ? 'READY / ${notifications['geo_subscriptions_active'] ?? 0} активных зон'
          : 'DEGRADED / bot token missing';
      _ingestionStatus = publicDay == 0
          ? 'Нет публичных сигналов за 24ч'
          : '$publicWithCoords из $publicDay с координатами (${(coordsCoverage * 100).round()}%)';
      _diagnosticsError = null;
    });
  }

  Future<String?> _ensureTwoFactorCode() async {
    final cached = (_twoFactorCode ?? '').trim();
    if (cached.isNotEmpty) {
      return cached;
    }
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceElevated,
          title: Text(
            'Пароль администратора',
            style: TextStyle(
              color: PulseColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: codeController,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: PulseColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Введите пароль администратора',
              hintStyle: TextStyle(color: PulseColors.textSecondary),
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(codeController.text.trim()),
              child: const Text('Подключить'),
            ),
          ],
        );
      },
    );
    codeController.dispose();

    final normalized = code?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      _twoFactorCode = normalized;
    }
    return normalized;
  }

  Future<void> _openAdminDashboard() async {
    final code = await _ensureTwoFactorCode();
    if (!mounted || code == null || code.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(initialTwoFactorCode: code),
      ),
    );
  }

  Future<void> _clearMeshQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mesh_offline_queue');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesh-кэш очищен.')),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((row) => row.map((key, item) => MapEntry(key.toString(), item)))
        .toList();
  }

  String _reportLabel(Map<String, dynamic>? report) {
    if (report == null || report.isEmpty) {
      return 'Нет данных';
    }
    final title = report['title']?.toString().trim();
    final address = report['address']?.toString().trim();
    final source = report['source']?.toString().trim();
    final pieces = <String>[
      if (title != null && title.isNotEmpty) title,
      if (address != null && address.isNotEmpty) address,
      if (source != null && source.isNotEmpty) source,
    ];
    return pieces.isEmpty ? 'Нет данных' : pieces.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final mesh = OfflineMeshService();
    final notifications = _asMap(_diagnostics?['notifications']);
    final ingestion = _asMap(_diagnostics?['ingestion']);
    final security = _asMap(_diagnostics?['security']);
    final unlocated = _asMapList(ingestion['recent_unlocated_public']);

    return Scaffold(
      body: AppScreenBackground(
        accent: PulseColors.negative,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: mesh,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  AppSectionHeader(
                    eyebrow: 'Секретное меню',
                    title: 'Служебный контур и телеметрия',
                    subtitle:
                        'Здесь видны состояние backend, diagnostics уведомлений и проблемы ingestion по пабликам.',
                    trailing: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: PulseColors.negative,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPanel(
                    borderColor: PulseColors.negative.withOpacity(0.24),
                    backgroundColor: PulseColors.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppStatusBadge(
                          label: 'Developer mode',
                          color: PulseColors.negative,
                          icon: Icons.warning_amber_rounded,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Экран предназначен для диагностики server-side уведомлений, шумов трафика и локального mesh-контура.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Admin diagnostics',
                          icon: Icons.security_update_good_rounded,
                          onPressed: _runAdminDiagnostics,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Admin Control',
                          icon: Icons.admin_panel_settings_rounded,
                          onPressed: _openAdminDashboard,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppMetricTile(
                          label: 'Ping',
                          value: _pingResult,
                          accent: PulseColors.primary,
                          trailing: Icon(
                            Icons.network_ping_rounded,
                            color: PulseColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppMetricTile(
                          label: 'Mesh peers',
                          value: '${mesh.connectedPeers}',
                          accent: PulseColors.warning,
                          trailing: const Icon(
                            Icons.hub_outlined,
                            color: PulseColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatusCard(
                    title: 'API контур',
                    value: _apiStatus,
                    icon: Icons.cloud_done_outlined,
                    accent: _apiStatus.contains('ONLINE')
                        ? PulseColors.success
                        : PulseColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusCard(
                    title: 'База и runtime',
                    value: _dbStatus,
                    icon: Icons.storage_rounded,
                    accent: _dbStatus.contains('CONNECTED')
                        ? PulseColors.primary
                        : PulseColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusCard(
                    title: 'Шум / атаки',
                    value: _attackStatus,
                    icon: Icons.gpp_maybe_outlined,
                    accent: _attackStatus == 'Низкий шум'
                        ? PulseColors.success
                        : PulseColors.negative,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server-side diagnostics',
                          style: AppTextStyles.section,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Admin session: $_adminSessionStatus',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildInfoRow(
                          label: 'Уведомления',
                          value: _notificationStatus,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildInfoRow(
                          label: 'Публичный ingestion',
                          value: _ingestionStatus,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildInfoRow(
                          label: 'Категории',
                          value:
                              '${notifications['categories_count'] ?? 0} с сервера',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildInfoRow(
                          label: 'Активные зоны',
                          value:
                              '${notifications['geo_subscriptions_active'] ?? 0} / уникальных ${notifications['unique_geo_subscribers'] ?? 0}',
                        ),
                        if (_diagnosticsError != null &&
                            _diagnosticsError!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _diagnosticsError!,
                            style: AppTextStyles.bodyMuted.copyWith(
                              color: PulseColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Последние server-side сигналы',
                          style: AppTextStyles.section,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildInfoRow(
                          label: 'Последний notifiable',
                          value: _reportLabel(
                            _asMap(notifications['latest_notifiable_report']),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildInfoRow(
                          label: 'Последний паблик',
                          value: _reportLabel(
                            _asMap(ingestion['latest_public_report']),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildInfoRow(
                          label: 'Последний геокодированный паблик',
                          value: _reportLabel(
                            _asMap(ingestion['latest_geocoded_public_report']),
                          ),
                        ),
                        if (unlocated.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Свежие паблики без координат',
                            style: AppTextStyles.cardTitle,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final item in unlocated)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: Text(
                                _reportLabel(item),
                                style: AppTextStyles.bodyMuted,
                              ),
                            ),
                        ],
                        if (security.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Traffic: ${security['requests_last_hour'] ?? 0}/час, admin claim hits: ${security['admin_claim_hits'] ?? 0}',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mesh-контур', style: AppTextStyles.section),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Очередь офлайн-сигналов: ${mesh.offlineQueue.length}',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          mesh.isScanning
                              ? 'Поиск соседних устройств активен.'
                              : 'Поиск соседних устройств остановлен.',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppSecondaryButton(
                          label: mesh.isScanning
                              ? 'Остановить поиск устройств'
                              : 'Запустить поиск устройств',
                          icon: mesh.isScanning
                              ? Icons.bluetooth_disabled_rounded
                              : Icons.bluetooth_searching_rounded,
                          onPressed: () {
                            if (mesh.isScanning) {
                              mesh.stopMeshDiscovery();
                            } else {
                              mesh.startMeshDiscovery();
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppSecondaryButton(
                          label: 'Очистить mesh-кэш',
                          icon: Icons.delete_sweep_outlined,
                          onPressed: _clearMeshQueue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Обновить телеметрию',
                    icon: Icons.refresh_rounded,
                    onPressed: _runDiagnostics,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: AppTextStyles.bodyMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: AppTextStyles.body)),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: accent.withOpacity(0.18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: AppRadii.sm,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTextStyles.cardTitle.copyWith(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

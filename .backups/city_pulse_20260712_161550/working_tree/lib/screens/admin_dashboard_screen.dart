import 'dart:async';

import 'package:flutter/material.dart';

import '../services/admin_dashboard_service.dart';
import '../services/device_identity_service.dart';
import '../services/sound_service.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.initialTwoFactorCode,
  });

  final String initialTwoFactorCode;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _adminService = AdminDashboardService.instance;
  Timer? _refreshTimer;

  Map<String, dynamic>? _metrics;
  Map<String, dynamic>? _productFunnel;
  Map<String, dynamic>? _ingestionQuality;
  Map<String, dynamic>? _hermesReport;
  bool _hermesReportVisible = false;
  List<Map<String, dynamic>> _cameras = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _claimingSession = true;
  bool _recheckingCameras = false;
  String? _error;
  String? _busyDeviceId;
  String? _busyCameraId;
  String? _localDeviceId;

  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _grantTgIdController = TextEditingController();
  final TextEditingController _grantUsernameController = TextEditingController();
  final TextEditingController _grantPhoneController = TextEditingController();
  final TextEditingController _grantAddressController = TextEditingController();
  final TextEditingController _grantVkIdController = TextEditingController();

  List<Map<String, dynamic>> _searchedUsers = [];
  bool _searchingUsers = false;
  String? _searchError;
  int _grantDays = 30;
  bool _grantingPremium = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalDeviceId());
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _adminService.releaseSession();
    _userSearchController.dispose();
    _grantTgIdController.dispose();
    _grantUsernameController.dispose();
    _grantPhoneController.dispose();
    _grantAddressController.dispose();
    _grantVkIdController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalDeviceId() async {
    final id = await DeviceIdentityService.instance.getCurrentDeviceIdOrNull();
    if (!mounted) {
      return;
    }
    setState(() {
      _localDeviceId = id;
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _adminService.ensureSession(
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _claimingSession = false;
      });
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _claimingSession = false;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<dynamic>([
        _adminService.fetchMetrics(twoFactorCode: widget.initialTwoFactorCode),
        _adminService.fetchCameras(twoFactorCode: widget.initialTwoFactorCode),
        _adminService.fetchProductFunnel(twoFactorCode: widget.initialTwoFactorCode),
        _adminService.fetchIngestionQuality(twoFactorCode: widget.initialTwoFactorCode),
        _adminService.fetchHermesReport(twoFactorCode: widget.initialTwoFactorCode),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _metrics = (results[0] as Map<String, dynamic>);
        _cameras = (results[1] as List<Map<String, dynamic>>);
        _productFunnel = (results[2] as Map<String, dynamic>);
        _ingestionQuality = (results[3] as Map<String, dynamic>);
        final hermesData = (results[4] as Map<String, dynamic>);
        _hermesReportVisible = hermesData['visible'] ?? false;
        _hermesReport = hermesData['report'];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _dismissHermesReport() async {
    try {
      await _adminService.dismissHermesReport(twoFactorCode: widget.initialTwoFactorCode);
      setState(() {
        _hermesReportVisible = false;
      });
    } catch (e) {
      debugPrint('Error dismissing Hermes report: $e');
    }
  }

  Future<void> _updatePolicy({
    required Map<String, dynamic> device,
    bool? mapAccess,
    bool? cameraAccess,
    bool? freeAccess,
  }) async {
    final deviceId = device['device_id']?.toString().trim() ?? '';
    if (deviceId.isEmpty) {
      return;
    }

    setState(() {
      _busyDeviceId = deviceId;
    });

    try {
      await _adminService.updateDevicePolicy(
        deviceId: deviceId,
        mapAccess: mapAccess,
        cameraAccess: cameraAccess,
        freeAccess: freeAccess,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить политику: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceId = null;
        });
      }
    }
  }

  Future<void> _grantFullAccess({
    required String deviceId,
    required String note,
  }) async {
    if (deviceId.isEmpty) {
      return;
    }

    setState(() {
      _busyDeviceId = deviceId;
    });

    try {
      await _adminService.updateDevicePolicy(
        deviceId: deviceId,
        mapAccess: true,
        cameraAccess: true,
        freeAccess: true,
        note: note,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Полный доступ предоставлен')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Не удалось предоставить полный доступ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceId = null;
        });
      }
    }
  }

  Future<void> _recheckCameras() async {
    if (_recheckingCameras) {
      return;
    }
    setState(() {
      _recheckingCameras = true;
    });
    try {
      final report = await _adminService.recheckCameras(
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      final msg = 'Проверка камер завершена: ${report['streamable'] ?? 0} из ${report['total'] ?? 0} доступны для трансляции';
      SoundService().speak(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Проверка камер: ${report['streamable'] ?? 0}/${report['total'] ?? 0} доступны для трансляции',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось перепроверить камеры: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recheckingCameras = false;
        });
      }
    }
  }

  Future<void> _toggleCameraVisibility({
    required String cameraId,
    required bool hiddenByAdmin,
  }) async {
    if (cameraId.isEmpty) {
      return;
    }
    setState(() {
      _busyCameraId = cameraId;
    });
    try {
      await _adminService.setCameraVisibility(
        cameraId: cameraId,
        hiddenByAdmin: hiddenByAdmin,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить видимость камеры: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyCameraId = null;
        });
      }
    }
  }

  Future<void> _unbindDevice({
    required String deviceId,
    required bool currentDevice,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PulseColors.surfaceElevated,
        title: Text('Отвязать устройство',
            style: TextStyle(color: PulseColors.textPrimary)),
        content: Text(
          currentDevice
              ? 'Отвязать это устройство от панели администратора и обновить локальный идентификатор устройства?'
              : 'Удалить это устройство из реестра?',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _busyDeviceId = deviceId;
    });
    try {
      await _adminService.unbindDevice(
        deviceId: deviceId,
        twoFactorCode: widget.initialTwoFactorCode,
      );

      if (currentDevice) {
        await _adminService.releaseSession();
        await DeviceIdentityService.instance.regenerateDeviceId();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Текущее устройство отвязано, идентификатор обновлён.')),
        );
        Navigator.of(context).pop();
        return;
      }

      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Устройство отвязано')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отвязать устройство: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AppScreenBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'ПАНЕЛЬ УПРАВЛЕНИЯ',
              style: AppTextStyles.overline.copyWith(
                color: PulseColors.textPrimary,
                fontSize: 14,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded,
                    color: PulseColors.textPrimary),
              ),
              if ((_localDeviceId ?? '').isNotEmpty)
                IconButton(
                  onPressed: _busyDeviceId == _localDeviceId
                      ? null
                      : () => _unbindDevice(
                            deviceId: _localDeviceId!,
                            currentDevice: true,
                          ),
                  tooltip: 'Отвязать это устройство',
                  icon: Icon(Icons.link_off_rounded,
                      color: PulseColors.textPrimary),
                ),
            ],
          ),
          body: _claimingSession
              ? const Center(child: CircularProgressIndicator())
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                            children: [
                              _buildHermesReportCard(),
                              _buildHeroCard(),
                              const SizedBox(height: 24),
                              _buildSummaryGrid(),
                              const SizedBox(height: 24),
                              _buildProductOpsCard(),
                              const SizedBox(height: 24),
                              _buildTrafficCard(),
                              const SizedBox(height: 24),
                              _buildRealtimeGroups(),
                              const SizedBox(height: 24),
                              _buildTopRoutesCard(),
                              const SizedBox(height: 24),
                              _buildCamerasCard(),
                              const SizedBox(height: 24),
                              _buildSentryTestCard(),
                              const SizedBox(height: 24),
                              _buildVipManagementCard(),
                              const SizedBox(height: 24),
                              _buildDevicesCard(),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_person_rounded,
                size: 44, color: PulseColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Сессия администратора недоступна',
              style: AppTextStyles.section,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Повторить',
              onPressed: _bootstrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return AppPanel(
      style: PanelStyle.aurora,
      accent: PulseColors.primaryDeep,
      showAuroraGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PulseColors.primary.withOpacity(0.2),
                  borderRadius: AppRadii.sm,
                ),
                child: Icon(Icons.shield_rounded, color: PulseColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Управление PostgreSQL',
                  style: AppTextStyles.hero.copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Последняя активность: ${_readString('last_activity_at', fallback: 'н/д')}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 6),
          Text(
            'Активное окно: ${_readInt('active_window_seconds')}с',
            style: AppTextStyles.mono,
          ),
          const SizedBox(height: 6),
          Text(
            'Uptime: ${_readString('uptime_human', fallback: '-')}',
            style: AppTextStyles.mono,
          ),
          const SizedBox(height: 6),
          Text(
            'Storage: ${_readString('storage_mode', fallback: 'unknown')}',
            style: AppTextStyles.mono,
          ),
          if ((_localDeviceId ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Текущее устройство: $_localDeviceId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mono,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: AppPrimaryButton(
                label: 'Предоставить полный доступ этому устройству',
                icon: Icons.verified_user_rounded,
                onPressed: _busyDeviceId == _localDeviceId
                    ? null
                    : () => _grantFullAccess(
                          deviceId: _localDeviceId!,
                          note: 'Полный доступ из панели администратора',
                        ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final items = <_MetricTileData>[
      _MetricTileData(
          'Всего устройств',
          _readInt('total_unique_users').toString(),
          PulseColors.primaryDeep,
          Icons.phone_android_rounded),
      _MetricTileData(
          'Зарегистрировано',
          _readInt('total_registered_users').toString(),
          PulseColors.warning,
          Icons.supervised_user_circle_rounded),
      _MetricTileData(
          'Активны сейчас', 
          _readInt('online_users').toString(),
          PulseColors.success, 
          Icons.radar_rounded),
      _MetricTileData(
          'Пик активности',
          _readInt('peak_active_unique_users').toString(),
          PulseColors.primary,
          Icons.show_chart_rounded),
      _MetricTileData(
          'Открытий приложения',
          _readInt('app_launches_total').toString(),
          PulseColors.accentViolet,
          Icons.play_circle_fill_rounded),
      _MetricTileData(
          'Адресов с жалобами',
          _readInt('unique_report_addresses').toString(),
          PulseColors.neutral,
          Icons.home_work_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppPanel(
          style: PanelStyle.neo,
          padding: const EdgeInsets.all(16),
          accent: item.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.accent, size: 24),
              ),
              const Spacer(),
              Text(
                item.value,
                style: AppTextStyles.title.copyWith(color: PulseColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: AppTextStyles.caption.copyWith(color: PulseColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductOpsCard() {
    final week = (_productFunnel?['week'] as Map?) ?? const {};
    final funnel = (week['funnel'] as List?) ?? const [];
    final quality = (_ingestionQuality?['quality'] as Map?) ?? const {};
    final ratio = ((_ingestionQuality?['confidence_ratio'] as num?) ?? 0).toDouble();
    return AppPanel(
      style: PanelStyle.aurora,
      accent: PulseColors.accentViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: PulseColors.accentViolet),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Аналитика продукта', style: AppTextStyles.section),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniMetric(
                'Уверенные входящие',
                '${((ratio * 100).round())}%',
                PulseColors.success,
              ),
              _miniMetric(
                'С адресом и координатами',
                '${quality['confident'] ?? 0}',
                PulseColors.primary,
              ),
              _miniMetric(
                'На проверку',
                '${(quality['partial'] ?? 0) + (quality['no_address'] ?? 0)}',
                PulseColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Funnel за 7 дней', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          for (final item in funnel.take(7))
            if (item is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _translateFunnelEvent(item['event']?.toString() ?? '-'),
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${item['count'] ?? 0}',
                      style: AppTextStyles.mono,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.section.copyWith(color: color)),
        ],
      ),
    );
  }

  String _translateFunnelEvent(String event) {
    switch (event) {
      case 'map_viewed':
        return 'Просмотр карты';
      case 'report_cta_tapped':
        return 'Клик по "Создать сигнал"';
      case 'photo_added':
        return 'Добавлено фото';
      case 'address_confirmed':
        return 'Адрес подтвержден';
      case 'report_submit_started':
        return 'Начало отправки сигнала';
      case 'report_submit_completed':
        return 'Сигнал успешно отправлен';
      case 'report_saved_to_draft':
        return 'Сохранено в черновик';
      default:
        return event;
    }
  }

  Widget _buildTrafficCard() {
    return _SectionCard(
      title: 'Трафик',
      icon: Icons.hub_rounded,
      child: Column(
        children: [
          _buildTrafficRow('Общий трафик сервера',
              _formatBytes(_readInt('total_traffic_bytes'))),
          _buildTrafficRow('Трафик сервера за 1 ч',
              _formatBytes(_readInt('traffic_last_hour_bytes'))),
          _buildTrafficRow('Трафик сервера за 24 ч',
              _formatBytes(_readInt('traffic_last_24_hours_bytes'))),
          _buildTrafficRow('Трафик сервера за 7 дн',
              _formatBytes(_readInt('traffic_last_7_days_bytes'))),
        ],
      ),
    );
  }

  Widget _buildSentryTestCard() {
    return _SectionCard(
      title: 'Диагностика и мониторинг',
      icon: Icons.bug_report_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Используйте для проверки интеграции Sentry и системы мониторинга ошибок. Будет вызвано намеренное исключение.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 16),
          AppSecondaryButton(
            label: 'Отправить тестовый сбой в Sentry',
            icon: Icons.flash_on_rounded,
            onPressed: () async {
              try {
                throw Exception('Test Sentry Exception from Admin Dashboard');
              } catch (exception, stackTrace) {
                await Sentry.captureException(
                  exception,
                  stackTrace: stackTrace,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Тестовое исключение отправлено в Sentry!')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMuted,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeGroups() {
    return Column(
      children: [
        _buildKeyValueCard(
          title: 'Платформы онлайн',
          icon: Icons.devices_rounded,
          values: _readMap('active_platforms'),
        ),
        const SizedBox(height: 16),
        _buildKeyValueCard(
          title: 'Версии приложения онлайн',
          icon: Icons.system_update_alt_rounded,
          values: _readMap('active_app_versions'),
        ),
        const SizedBox(height: 16),
        _buildKeyValueCard(
          title: 'Экраны онлайн',
          icon: Icons.space_dashboard_rounded,
          values: _readMap('active_screens'),
        ),
      ],
    );
  }

  Widget _buildKeyValueCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> values,
  }) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: values.isEmpty
          ? Text(
              'Нет активных данных',
              style: AppTextStyles.bodyMuted,
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: PulseColors.textPrimary.withOpacity(0.04),
                        borderRadius: AppRadii.pill,
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildTopRoutesCard() {
    final routes =
        (_metrics?['top_routes'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((route) =>
                route.map((key, value) => MapEntry(key.toString(), value)))
            .toList();

    return _SectionCard(
      title: 'Основные маршруты',
      icon: Icons.route_rounded,
      child: routes.isEmpty
          ? Text('Нет данных о маршрутах', style: AppTextStyles.bodyMuted)
          : Column(
              children: routes
                  .map(
                    (route) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              route['path']?.toString() ?? '-',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                          Text(
                            route['hits']?.toString() ?? '0',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCamerasCard() {
    return _SectionCard(
      title: 'Городские камеры',
      icon: Icons.videocam_rounded,
      action: TextButton.icon(
        onPressed: _recheckingCameras ? null : _recheckCameras,
        icon: _recheckingCameras
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync_rounded, size: 16),
        label: const Text('Перепроверить'),
        style: TextButton.styleFrom(
          foregroundColor: PulseColors.textPrimary,
        ),
      ),
      child: _cameras.isEmpty
          ? Text('Нет камер в каталоге', style: AppTextStyles.bodyMuted)
          : Column(
              children: _cameras.map(_buildCameraTile).toList(),
            ),
    );
  }

  Widget _buildCameraTile(Map<String, dynamic> camera) {
    final cameraId = camera['camera_id']?.toString() ?? '';
    final name = camera['name']?.toString() ?? 'Камера';
    final streamable = _readBool(camera['streamable'], fallback: false);
    final hiddenByAdmin = _readBool(camera['hidden_by_admin'], fallback: false);
    final hiddenDueToOffline =
        _readBool(camera['hidden_due_to_offline'], fallback: false);
    final hiddenInMap = _readBool(camera['hidden_in_map'], fallback: true);
    final busy = _busyCameraId == cameraId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseColors.textPrimary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulseColors.textPrimary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            streamable ? 'Поток: OK' : 'Поток: НЕДОСТУПЕН',
            style: AppTextStyles.bodyMuted.copyWith(
              color: streamable ? PulseColors.success : PulseColors.negative,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hidden: ${hiddenInMap ? 'yes' : 'no'} В· '
            'manual=${hiddenByAdmin ? '1' : '0'} В· offline=${hiddenDueToOffline ? '1' : '0'}',
            style: AppTextStyles.mono,
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: hiddenByAdmin,
            onChanged: busy
                ? null
                : (value) => _toggleCameraVisibility(
                      cameraId: cameraId,
                      hiddenByAdmin: value,
                    ),
            title: Text(
              'Скрыть на карте (админ)',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard() {
    final devices =
        (_metrics?['devices'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((device) =>
                device.map((key, value) => MapEntry(key.toString(), value)))
            .toList();

    return _SectionCard(
      title: 'Устройства и политики доступа',
      icon: Icons.admin_panel_settings_rounded,
      child: devices.isEmpty
          ? Text('Устройства ещё не зарегистрированы',
              style: AppTextStyles.bodyMuted)
          : Column(
              children: devices.map(_buildDeviceTile).toList(),
            ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final policy = _readInlineMap(device['policy']);
    final deviceId = device['device_id']?.toString() ?? '';
    final busy = _busyDeviceId == deviceId;
    final isCurrentDevice = (_localDeviceId ?? '') == deviceId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulseColors.textPrimary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PulseColors.textPrimary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deviceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isCurrentDevice)
                AppStatusBadge(
                  label: 'ЭТО УСТРОЙСТВО',
                  color: PulseColors.primary,
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy
                    ? null
                    : () => _unbindDevice(
                          deviceId: deviceId,
                          currentDevice: isCurrentDevice,
                        ),
                icon: Icon(Icons.link_off_rounded,
                    color: PulseColors.textSecondary, size: 20),
                tooltip: 'Отвязать устройство',
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${device['platform'] ?? 'unknown'} В· ${device['app_version'] ?? 'unknown'}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 4),
          Text(
            'Последнее подключение: ${device['last_seen_at'] ?? 'н/д'}',
            style: AppTextStyles.mono,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSecondaryButton(
              label: isCurrentDevice
                  ? 'Полный доступ для этого устройства'
                  : 'Предоставить полный доступ',
              icon: Icons.verified_user_rounded,
              onPressed: busy
                  ? null
                  : () => _grantFullAccess(
                        deviceId: deviceId,
                        note: isCurrentDevice
                            ? 'Полный доступ для текущего администратора'
                            : 'Полный доступ выдан администратором',
                      ),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['map_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, mapAccess: value),
            title: Text('Доступ к карте', style: AppTextStyles.body),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['camera_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, cameraAccess: value),
            title: Text('Доступ к камерам', style: AppTextStyles.body),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['free_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, freeAccess: value),
            title: Text('Свободный доступ', style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTrafficCard() {
    final traffic = (_metrics?['traffic_last_hour'] as Map?) ?? const {};
    final level = (_metrics?['attack_signal']?['level'] as String?) ?? 'low';
    final label = (_metrics?['attack_signal']?['label'] as String?) ?? 'Норма';
    final Color signalColor = level == 'high'
        ? PulseColors.negative
        : level == 'elevated'
            ? PulseColors.warning
            : PulseColors.success;

    return AppPanel(
      style: PanelStyle.aurora,
      accent: signalColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.traffic_rounded, color: signalColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Сигнал угроз / Трафик', style: AppTextStyles.section),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.15),
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  label,
                  style: AppTextStyles.overline.copyWith(color: signalColor),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Map<String, dynamic> _readMap(String key) {
    return _readInlineMap(_metrics?[key]);
  }

  Map<String, dynamic> _readInlineMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  int _readInt(String key) {
    final value = _metrics?[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return fallback;
  }

  String _readString(String key, {required String fallback}) {
    final value = _metrics?[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final fixed =
        value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed ${units[unitIndex]}';
  }

  Future<void> _searchUsers() async {
    final query = _userSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchedUsers = const [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searchingUsers = true;
      _searchError = null;
    });

    try {
      final results = await _adminService.searchUsers(
        query: query,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) return;
      setState(() {
        _searchedUsers = results;
        _searchingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchingUsers = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _submitGrantPremium({
    int? telegramId,
    String? username,
    String? phone,
    String? address,
    String? vkId,
    required int days,
  }) async {
    setState(() {
      _grantingPremium = true;
    });

    try {
      final response = await _adminService.grantPremium(
        telegramId: telegramId,
        username: username,
        phone: phone,
        address: address,
        vkId: vkId,
        days: days,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) return;
      setState(() {
        _grantingPremium = false;
      });
      
      final msg = response['message']?.toString() ?? 'VIP доступ успешно выдан';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: PulseColors.success),
      );
      
      if (_userSearchController.text.trim().isNotEmpty) {
        await _searchUsers();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _grantingPremium = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: PulseColors.negative),
      );
    }
  }

  Widget _buildVipManagementCard() {
    return _SectionCard(
      title: 'Управление VIP-подписками',
      icon: Icons.workspace_premium_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Поиск пользователя по телефону, адресу, VK ID, TG ID или юзернейму:',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  style: TextStyle(color: PulseColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Введите поисковый запрос...',
                    hintStyle: TextStyle(color: PulseColors.textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: PulseColors.textPrimary.withOpacity(0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: PulseColors.border),
                    ),
                  ),
                  onSubmitted: (_) => _searchUsers(),
                ),
              ),
              const SizedBox(width: 8),
              AppPrimaryButton(
                label: 'Найти',
                onPressed: _searchingUsers ? null : _searchUsers,
              ),
            ],
          ),
          if (_searchingUsers) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_searchError != null) ...[
            const SizedBox(height: 8),
            Text(_searchError!, style: TextStyle(color: PulseColors.negative)),
          ],
          if (!_searchingUsers && _searchedUsers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Результаты поиска (${_searchedUsers.length}):', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._searchedUsers.map((u) {
              final isVip = u['is_vip'] == true;
              final vipUntil = u['vip_until']?.toString() ?? 'нет';
              final telegramId = u['telegram_id'];
              final username = u['username']?.toString();
              final phone = u['phone']?.toString();
              final address = u['address']?.toString();
              final vkId = u['vk_id']?.toString();
              
              final name = [
                u['first_name']?.toString() ?? '',
                u['last_name']?.toString() ?? ''
              ].join(' ').trim();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PulseColors.textPrimary.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PulseColors.textPrimary.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name.isNotEmpty ? name : 'Аноним', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                        AppStatusBadge(
                          label: isVip ? 'VIP АКТИВЕН' : 'БЕЗ VIP',
                          color: isVip ? Colors.amber : PulseColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (telegramId != null) Text('Telegram ID: $telegramId', style: AppTextStyles.mono),
                    if (username != null && username.isNotEmpty) Text('Username: @$username', style: AppTextStyles.bodyMuted),
                    if (phone != null && phone.isNotEmpty) Text('Телефон: $phone', style: AppTextStyles.bodyMuted),
                    if (address != null && address.isNotEmpty) Text('Адрес: $address', style: AppTextStyles.bodyMuted),
                    if (vkId != null && vkId.isNotEmpty) Text('VK ID: $vkId', style: AppTextStyles.mono),
                    if (isVip) Text('Активен до: $vipUntil', style: TextStyle(color: Colors.amber.shade300, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Продлить на 30 дней',
                            onPressed: _grantingPremium
                                ? null
                                : () => _submitGrantPremium(
                                      telegramId: telegramId is int ? telegramId : null,
                                      username: username,
                                      phone: phone,
                                      address: address,
                                      vkId: vkId,
                                      days: 30,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Продлить на год',
                            onPressed: _grantingPremium
                                ? null
                                : () => _submitGrantPremium(
                                      telegramId: telegramId is int ? telegramId : null,
                                      username: username,
                                      phone: phone,
                                      address: address,
                                      vkId: vkId,
                                      days: 365,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ] else if (!_searchingUsers && _userSearchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Пользователи не найдены.', style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Выдать VIP новой записи (создастся профиль, если не существует):',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFormTextField(_grantTgIdController, 'Telegram ID (число)'),
          const SizedBox(height: 8),
          _buildFormTextField(_grantUsernameController, 'Telegram Username (без @)'),
          const SizedBox(height: 8),
          _buildFormTextField(_grantPhoneController, 'Номер телефона'),
          const SizedBox(height: 8),
          _buildFormTextField(_grantAddressController, 'Адрес пользователя'),
          const SizedBox(height: 8),
          _buildFormTextField(_grantVkIdController, 'VK ID / ник'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Срок подписки:', style: AppTextStyles.body),
              DropdownButton<int>(
                dropdownColor: PulseColors.surface,
                value: _grantDays,
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 дней', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 90, child: Text('90 дней', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 365, child: Text('365 дней', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _grantDays = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: _grantingPremium ? 'Выдача...' : 'Активировать VIP подписку',
            onPressed: _grantingPremium
                ? null
                : () {
                    final tgIdStr = _grantTgIdController.text.trim();
                    final username = _grantUsernameController.text.trim();
                    final phone = _grantPhoneController.text.trim();
                    final address = _grantAddressController.text.trim();
                    final vkId = _grantVkIdController.text.trim();
                    
                    if (tgIdStr.isEmpty && username.isEmpty && phone.isEmpty && address.isEmpty && vkId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните хотя бы одно поле идентификатора')),
                      );
                      return;
                    }
                    
                    final int? tgId = int.tryParse(tgIdStr);
                    _submitGrantPremium(
                      telegramId: tgId,
                      username: username.isNotEmpty ? username : null,
                      phone: phone.isNotEmpty ? phone : null,
                      address: address.isNotEmpty ? address : null,
                      vkId: vkId.isNotEmpty ? vkId : null,
                      days: _grantDays,
                    ).then((_) {
                      _grantTgIdController.clear();
                      _grantUsernameController.clear();
                      _grantPhoneController.clear();
                      _grantAddressController.clear();
                      _grantVkIdController.clear();
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFormTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: TextStyle(color: PulseColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: PulseColors.textSecondary.withOpacity(0.6), fontSize: 13),
        filled: true,
        fillColor: PulseColors.textPrimary.withOpacity(0.02),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: PulseColors.border.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildHermesReportCard() {
    if (!_hermesReportVisible || _hermesReport == null) {
      return const SizedBox.shrink();
    }
    final report = _hermesReport!;
    final points = (report['new_knowledge_points'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: AppPanel(
        style: PanelStyle.aurora,
        accent: PulseColors.accentGold,
        showAuroraGlow: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded, color: PulseColors.accentGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ИИ-Помощник «Гермес»: Отчёт',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: PulseColors.accentGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismissHermesReport,
                  child: Icon(Icons.close_rounded, color: PulseColors.textSecondary, size: 20),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white12),
            Text(
              '${report['summary']}',
              style: AppTextStyles.body.copyWith(
                color: PulseColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildReportStat('Сигналов обработано', '${report['signals_processed']}'),
                _buildReportStat('Индекс комфорта', '${report['comfort_score']}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Области внимания: ${report['categories_breakdown']}',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Самообучение и базы знаний:',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              ...points.map((pt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: PulseColors.accentGold)),
                        Expanded(
                          child: Text(
                            pt.toString(),
                            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Обновлено: ${report['date']} в ${report['time']}',
                  style: AppTextStyles.mono.copyWith(fontSize: 10, color: PulseColors.textSecondary),
                ),
                TextButton(
                  onPressed: _dismissHermesReport,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Убрать отчёт с экрана',
                    style: TextStyle(color: Colors.redAccent.shade100, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.cardTitle.copyWith(
            color: PulseColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PulseColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.cardTitle,
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData(this.label, this.value, this.accent, this.icon);

  final String label;
  final String value;
  final Color accent;
  final IconData icon;
}


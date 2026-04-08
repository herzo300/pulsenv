import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'developer_menu_screen.dart';
import 'mesh_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const Duration _adminTapWindow = Duration(seconds: 4);
  static const int _adminTapTarget = 10;

  Timer? _adminTapResetTimer;
  int _adminTapCount = 0;

  static const List<_ModuleInfo> _modules = <_ModuleInfo>[
    _ModuleInfo(
      title: 'App Shell',
      icon: Icons.dashboard_customize_rounded,
      description:
          'Точка входа Flutter-приложения, тема, bootstrap, runtime-конфиг и безопасный запуск.',
      chips: <String>['main.dart', 'PulseColors', 'RuntimeConfigService'],
    ),
    _ModuleInfo(
      title: 'Карта города',
      icon: Icons.map_rounded,
      description:
          'Основной экран карты, категории сигналов, слой камер, фильтры, кеш последнего снимка и офлайн-резерв.',
      chips: <String>['MapScreen', 'flutter_map', 'offline cache'],
    ),
    _ModuleInfo(
      title: 'Жалобы и репозиторий',
      icon: Icons.report_problem_rounded,
      description:
          'Загрузка маркеров, создание обращений, media upload, сводки и серверные категории.',
      chips: <String>[
        'ReportsRepository',
        'ComplaintFormScreen',
        'Backend API'
      ],
    ),
    _ModuleInfo(
      title: 'Уведомления',
      icon: Icons.notifications_active_rounded,
      description:
          'Локальные push и in-app уведомления, фоновые проверки и отдельные настройки по категориям.',
      chips: <String>[
        'NotificationService',
        'BackgroundNotificationsService',
        'NotificationCatalog',
      ],
    ),
    _ModuleInfo(
      title: 'Mesh и офлайн',
      icon: Icons.hub_rounded,
      description:
          'Очередь store-and-forward, подготовка к P2P обмену и инструменты волонтёра для работы без интернета.',
      chips: <String>[
        'OfflineMeshService',
        'MeshNetworkService',
        'MeshScreen'
      ],
    ),
    _ModuleInfo(
      title: 'Камеры и мониторинг',
      icon: Icons.videocam_rounded,
      description:
          'Каталог городских камер, probe-проверка потоков, AI-watchdog, Frigate bridge и админ-видимость.',
      chips: <String>[
        'camera_probe',
        'camera_watchdog_service',
        'admin_metrics',
      ],
    ),
    _ModuleInfo(
      title: 'AI и поиск',
      icon: Icons.auto_awesome_rounded,
      description:
          'AI-ассистент, object detection, visual search, EXIF и локальные/облачные vision-сервисы.',
      chips: <String>[
        'AiAssistantScreen',
        'object_detection_service',
        'visual_search',
      ],
    ),
    _ModuleInfo(
      title: 'Профиль',
      icon: Icons.person_rounded,
      description:
          'Профиль пользователя, настройки уведомлений и персонализация.',
      chips: <String>['ProfileScreen', 'SettingsScreen'],
    ),
    _ModuleInfo(
      title: 'Админ и runtime',
      icon: Icons.admin_panel_settings_rounded,
      description:
          'Heartbeat, доступы устройств, телеметрия, 2FA-сессия, скрытые камеры и диагностические панели.',
      chips: <String>['AdminDashboard', 'RuntimeAccess', 'DeveloperMenu'],
    ),
  ];

  static const List<String> _meshSteps = <String>[
    'Откройте раздел «Оффлайн mesh» в меню карты до потери связи, чтобы приложение подготовило локальную очередь.',
    'Создавайте обращения как обычно. При отсутствии интернета они сохраняются локально и не теряются.',
    'Если рядом есть устройство с этим приложением, данные могут быть переданы дальше по цепочке после включения P2P-модуля.',
    'Как только одно из устройств снова получает интернет, накопленные обращения синхронизируются с backend.',
    'Для экономии батареи выключайте mesh-поиск, когда офлайн-режим больше не нужен.',
  ];

  @override
  void dispose() {
    _adminTapResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleAdminTap() async {
    _adminTapResetTimer?.cancel();
    _adminTapCount += 1;

    if (_adminTapCount >= _adminTapTarget) {
      _adminTapCount = 0;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DeveloperMenuScreen(),
        ),
      );
      return;
    }

    _adminTapResetTimer = Timer(_adminTapWindow, () {
      _adminTapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppScreenBackground(
        accent: PulseColors.primarySoft,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              AppSectionHeader(
                eyebrow: 'About',
                title: 'О проекте',
                subtitle:
                    'Пульс города объединяет карту, сигналы жителей, камеры, уведомления и автономный офлайн-контур.',
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: PulseColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildSummary(),
              const SizedBox(height: AppSpacing.lg),
              _buildCameraCatalogCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildModuleSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildMeshSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildQuickActions(),
              const SizedBox(height: AppSpacing.lg),
              _buildVersionTile(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что делает проект', style: AppTextStyles.section),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Проект представляет собой автономную систему мониторинга города. Приложение фиксирует сигналы и мероприятия на карте, использует AI для анализа обстановки с видеокамер, локально распознает образы на фото, автоматически определяет вашу управляющую компанию по геопозиции и поддерживает работу в условиях отсутствия связи через Mesh-сеть.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCatalogCard() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Каталог камер', style: AppTextStyles.section),
          SizedBox(height: AppSpacing.sm),
          Text(
            'В проекте сейчас найдено 216 исходных записей камер в полном каталоге. '
            'После дедупликации по координатам и потоку остаётся 130 уникальных точек, '
            'из них 94 помечены как служебные/скрытые. Мобильный публичный бандл содержит 117 публичных камер.',
            style: AppTextStyles.body,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Проверка работоспособности потоков выполняется отдельным probe-скриптом и backend-каталогом. '
            'В приложении отображаются только штатные камеры, которые backend считает доступными.',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Модули проекта', style: AppTextStyles.section),
        const SizedBox(height: AppSpacing.sm),
        for (final module in _modules) ...[
          _ModuleCard(info: module),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildMeshSection() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Как пользоваться mesh без интернета',
              style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          for (final step in _meshSteps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.fiber_manual_record_rounded,
                    size: 12,
                    color: PulseColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(step, style: AppTextStyles.body),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Быстрые действия', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Mesh-сеть',
                  icon: Icons.hub_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeshScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionTile() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_handleAdminTap()),
      child: AppPanel(
        backgroundColor: PulseColors.surfaceSoft.withOpacity(0.28),
        child: Column(
          children: [
            Text('SOOBSHIO / CITY PULSE', style: AppTextStyles.cardTitle),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Версия 2.2 · карта · камеры · mesh · premium · admin runtime',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleInfo {
  const _ModuleInfo({
    required this.title,
    required this.icon,
    required this.description,
    required this.chips,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> chips;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.info,
  });

  final _ModuleInfo info;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PulseColors.primary.withOpacity(0.14),
                  borderRadius: AppRadii.sm,
                ),
                child: Icon(info.icon, color: PulseColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(info.title, style: AppTextStyles.cardTitle),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(info.description, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final chip in info.chips)
                AppStatusBadge(
                  label: chip,
                  color: PulseColors.primarySoft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

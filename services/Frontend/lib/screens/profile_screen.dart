import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.telegramId,
  });

  final int? telegramId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _telegramIdPrefKey = 'profile_telegram_id';
  static const Map<String, dynamic> _emptyProfilePayload = {
    'success': true,
    'profile': {
      'telegram_id': 0,
      'reports_submitted': 0,
      'reports_on_map': 0,
      'reports_resolved': 0,
      'activity_rank': 0,
      'is_vip': false,
      'tariff_name': 'Базовый',
      'tariff_expiry': null,
      'is_track_active': false,
      'monitoring_hours_left': 0.0,
      'monitoring_minutes_left': 0,
      'ai_monitoring_balance': {
        'total_minutes_allowed': 0,
        'used_minutes': 0,
        'remaining_minutes': 0,
      },
      'visual_searches_balance': {
        'limit': 0,
        'used': 0,
        'remaining': 0,
      },
    },
    'features': {
      'general': <dynamic>[],
      'vip': <dynamic>[],
    },
  };

  bool _isLoading = true;
  bool _trackActionBusy = false;
  String? _error;
  Map<String, dynamic> _profileData = {};
  final TextEditingController _telegramIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _telegramIdController.dispose();
    super.dispose();
  }

  Future<int> _resolveTelegramId() async {
    final explicit = widget.telegramId ?? 0;
    if (explicit > 0) {
      return explicit;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_telegramIdPrefKey) ?? prefs.getInt('telegram_id') ?? 0;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final tgId = await _resolveTelegramId();
    if (tgId == 0) {
      setState(() {
        _profileData = _buildEmptyProfilePayload(tgId);
        _isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/profile/$tgId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final payload =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if ((payload['success'] as bool?) != true) {
        throw Exception(payload['error'] ?? 'Profile request failed');
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _profileData = payload;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            'Не удалось загрузить профиль. Проверьте подключение и повторите попытку.';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildEmptyProfilePayload(int tgId) {
    return {
      ..._emptyProfilePayload,
      'profile': {
        ..._emptyProfilePayload['profile'] as Map<String, dynamic>,
        'telegram_id': tgId,
      },
    };
  }

  Future<void> _saveTelegramId() async {
    final value = int.tryParse(_telegramIdController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный Telegram ID')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_telegramIdPrefKey, value);
    if (!mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    await _loadProfile();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Telegram ID сохранён: $value')),
    );
  }

  Future<void> _toggleAiTrack(bool shouldStart) async {
    final tgId = await _resolveTelegramId();
    if (tgId == 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала привяжите Telegram ID в профиле.'),
        ),
      );
      return;
    }

    setState(() {
      _trackActionBusy = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${MapConfig.backendApiBaseUrl}/viptask/toggle'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telegram_id': tgId,
              'action': shouldStart ? 'start' : 'stop',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final payload =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['success'] != true) {
        throw Exception(
            payload['message'] ?? payload['detail'] ?? 'Action failed');
      }

      await _loadProfile();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldStart
                ? 'AI-сканирование активировано.'
                : 'AI-сканирование остановлено.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Не удалось изменить статус AI-сканирования: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _trackActionBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: PulseColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: AppScreenBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Профиль временно недоступен',
                          style: AppTextStyles.section,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: AppTextStyles.bodyMuted),
                        const SizedBox(height: AppSpacing.lg),
                        AppPrimaryButton(
                          label: 'Повторить',
                          icon: Icons.refresh_rounded,
                          onPressed: _loadProfile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile = (_profileData['profile'] as Map<String, dynamic>? ?? {});
    final features = (_profileData['features'] as Map<String, dynamic>? ?? {});
    final aiBalance =
        (profile['ai_monitoring_balance'] as Map<String, dynamic>? ?? {});
    final visualBalance =
        (profile['visual_searches_balance'] as Map<String, dynamic>? ?? {});

    final telegramIdValue = (profile['telegram_id'] as num?)?.toInt() ?? 0;
    final telegramId = telegramIdValue > 0 ? telegramIdValue.toString() : '0';
    final reports = (profile['reports_submitted'] as num?)?.toInt() ?? 0;
    final onMap = (profile['reports_on_map'] as num?)?.toInt() ?? 0;
    final resolved = (profile['reports_resolved'] as num?)?.toInt() ?? 0;
    final rank = (profile['activity_rank'] as num?)?.toInt() ?? 0;
    final isVip = profile['is_vip'] == true;
    final tariffName = profile['tariff_name']?.toString() ?? 'Базовый';
    final tariffExpiry = profile['tariff_expiry']?.toString();
    final isTrackActive = profile['is_track_active'] == true;
    final monitoringHours =
        (profile['monitoring_hours_left'] as num?)?.toDouble() ?? 0.0;
    final monitoringMinutes =
        (profile['monitoring_minutes_left'] as num?)?.toInt() ?? 0;
    final totalMin = (aiBalance['total_minutes_allowed'] as num?)?.toInt() ?? 0;
    final usedMin = (aiBalance['used_minutes'] as num?)?.toInt() ?? 0;
    final remMin = (aiBalance['remaining_minutes'] as num?)?.toInt() ?? 0;
    final visualRemaining = (visualBalance['remaining'] as num?)?.toInt() ?? 0;
    final progress =
        totalMin > 0 ? (usedMin / totalMin).clamp(0, 1).toDouble() : 0.0;

    return Scaffold(
      body: AppScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.xl),
              ProfileHeroCard(
                telegramId: telegramId,
                tariffName: tariffName,
                tariffExpiry: tariffExpiry,
                reports: reports,
                rank: rank,
                remMin: remMin,
                progress: progress,
                isVip: isVip,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (telegramIdValue == 0) ...[
                _buildTelegramBindingCard(),
                const SizedBox(height: AppSpacing.lg),
              ],
              ProfileStatsRow(
                  onMap: onMap,
                  resolved: resolved,
                  visualRemaining: visualRemaining),
              const SizedBox(height: AppSpacing.xl),
              ProfileMonitoringPanel(
                monitoringHours: monitoringHours,
                monitoringMinutes: monitoringMinutes,
                isTrackActive: isTrackActive,
                hasLinkedTelegramId: telegramIdValue > 0,
                onToggleTrack: () => _toggleAiTrack(!isTrackActive),
                trackActionBusy: _trackActionBusy,
              ),
              const SizedBox(height: AppSpacing.xl),
              ProfileFeatureList(
                title: 'Доступно сейчас',
                subtitle:
                    'Каждая функция снабжена подсказкой: нажмите на иконку информации.',
                accent: PulseColors.primary,
                features: _featureList(features['general']),
              ),
              const SizedBox(height: AppSpacing.lg),
              ProfileFeatureList(
                title: 'Premium и AI',
                subtitle:
                    'Расширенные возможности для камер, AI-сканирования и приоритетных сценариев.',
                accent: PulseColors.warning,
                features: _featureList(features['vip']),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAppServicesSection(),
              const SizedBox(height: AppSpacing.lg),
              AppSecondaryButton(
                label: 'Открыть настройки',
                icon: Icons.settings_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppSectionHeader(
      eyebrow: 'Профиль',
      title: 'Ваш городской контур',
      subtitle:
          'Здесь видны тариф, мониторинги, AI-минуты и описание каждой функции.',
      trailing: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: PulseColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTelegramBindingCard() {
    return AppPanel(
      borderColor: PulseColors.warning.withOpacity(0.22),
      backgroundColor: PulseColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Привязка Telegram', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Чтобы видеть реальные минуты, мониторинги и управлять AI-сканированием, укажите ваш Telegram ID.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _telegramIdController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Например: 123456789',
              hintStyle: AppTextStyles.bodyMuted,
              filled: true,
              fillColor: PulseColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: AppRadii.md,
                borderSide: BorderSide(
                  color: PulseColors.warning.withOpacity(0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.md,
                borderSide: BorderSide(
                  color: PulseColors.warning.withOpacity(0.18),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadii.md,
                borderSide: BorderSide(color: PulseColors.warning),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Сохранить Telegram ID',
            icon: Icons.link_rounded,
            onPressed: _saveTelegramId,
          ),
        ],
      ),
    );
  }

  Widget _buildAppServicesSection() {
    const services = <_AppService>[
      _AppService(
        title: 'Карта города',
        description:
            'Главная поверхность приложения: сигналы, события, камеры, мероприятия и адресные точки.',
        icon: Icons.map_outlined,
      ),
      _AppService(
        title: 'Инфографика',
        description:
            'Аналитика города по годам и ключевым темам: население, экономика, ЖКХ и безопасность.',
        icon: Icons.insert_chart_outlined,
      ),
      _AppService(
        title: 'Камеры',
        description:
            'Просмотр городских камер и переход к тревожным сценам, если AI видит ЧП.',
        icon: Icons.videocam_outlined,
      ),
      _AppService(
        title: 'Управляющие компании',
        description:
            'Рейтинг УК, контакты и статус качества обслуживания по вашему адресу и по городу.',
        icon: Icons.business_outlined,
      ),
      _AppService(
        title: 'AI ассистент',
        description:
            'Подсказки по городу, объяснение функций и помощь с интерпретацией данных.',
        icon: Icons.smart_toy_outlined,
      ),
      _AppService(
        title: 'EXIF сканер',
        description:
            'Проверка метаданных снимка, координат, времени и скрытых следов файла.',
        icon: Icons.image_search_outlined,
      ),
      _AppService(
        title: 'Мероприятия',
        description:
            'Городская афиша и события, которые отображаются и на карте, и в списках.',
        icon: Icons.event_outlined,
      ),
      _AppService(
        title: 'OCR',
        description:
            'Распознавание текста с фото: адреса, объявления, таблички и документы.',
        icon: Icons.document_scanner_outlined,
      ),
      _AppService(
        title: 'Mesh-сеть',
        description:
            'Автономная P2P-связь для работы в ЧС без интернета.',
        icon: Icons.hub_outlined,
      ),
    ];

    return AppPanel(
      borderColor: PulseColors.primaryDeep.withOpacity(0.22),
      backgroundColor: PulseColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Все функции приложения', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Для каждой функции есть короткая подсказка и описание.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: PulseColors.surfaceSoft,
                  borderRadius: AppRadii.sm,
                  border: Border.all(
                    color: PulseColors.primary.withOpacity(0.10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(service.icon, color: PulseColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service.title, style: AppTextStyles.body),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            service.description,
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                    AppHintButton(
                      title: service.title,
                      message: service.description,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_FeatureItem> _featureList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map>().map((item) {
      final map = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final title = map['name']?.toString().trim();
      return _FeatureItem(
        title: (title == null || title.isEmpty) ? 'Функция' : title,
        description: map['description']?.toString().trim().isNotEmpty == true
            ? map['description'].toString().trim()
            : 'Описание пока не добавлено.',
        available: map['available'] == true,
        icon: _iconForFeature(title ?? ''),
      );
    }).toList();
  }

  IconData _iconForFeature(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('карта')) return Icons.map_outlined;
    if (lower.contains('проблем')) return Icons.edit_note_rounded;
    if (lower.contains('ai') || lower.contains('ии')) {
      return Icons.auto_awesome_outlined;
    }
    if (lower.contains('кам')) return Icons.videocam_outlined;
    if (lower.contains('visual')) return Icons.search_rounded;
    if (lower.contains('ук')) return Icons.business_outlined;
    if (lower.contains('данн')) return Icons.dataset_outlined;
    return Icons.bolt_rounded;
  }
}

// ─── Extracted Widgets ───────────────────────────────────────────────────────

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.telegramId,
    required this.tariffName,
    required this.tariffExpiry,
    required this.reports,
    required this.rank,
    required this.remMin,
    required this.progress,
    required this.isVip,
  });

  final String telegramId;
  final String tariffName;
  final String? tariffExpiry;
  final int reports;
  final int rank;
  final int remMin;
  final double progress;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      borderColor:
          (isVip ? PulseColors.warning : PulseColors.primary).withOpacity(0.22),
      backgroundColor: PulseColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: PulseColors.primary.withOpacity(0.16),
                  borderRadius: AppRadii.md,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: PulseColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID $telegramId', style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Отправлено сигналов: $reports',
                      style: AppTextStyles.bodyMuted,
                    ),
                    if (rank > 0) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Место по активности: #$rank',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                    if (tariffExpiry != null &&
                        tariffExpiry?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Действует до: ${tariffExpiry?.replaceFirst('T', ' ').split('.').first ?? ''}',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ],
                ),
              ),
              AppStatusBadge(
                label: tariffName,
                color: isVip ? PulseColors.warning : PulseColors.primary,
                icon: isVip
                    ? Icons.workspace_premium_rounded
                    : Icons.shield_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Осталось $remMin AI-минут', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadii.pill,
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: PulseColors.backgroundRaised,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(PulseColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Настройки и уведомления',
            icon: Icons.settings_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.onMap,
    required this.resolved,
    required this.visualRemaining,
  });

  final int onMap;
  final int resolved;
  final int visualRemaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppMetricTile(
                label: 'На карте',
                value: '$onMap',
                accent: PulseColors.primary,
                trailing: const Icon(
                  Icons.map_rounded,
                  color: PulseColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppMetricTile(
                label: 'Решено',
                value: '$resolved',
                accent: PulseColors.success,
                trailing: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: PulseColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppMetricTile(
          label: 'Visual Search',
          value: '$visualRemaining',
          accent: PulseColors.warning,
          trailing: const Icon(
            Icons.search_rounded,
            color: PulseColors.warning,
          ),
        ),
      ],
    );
  }
}

class ProfileMonitoringPanel extends StatelessWidget {
  const ProfileMonitoringPanel({
    super.key,
    required this.monitoringHours,
    required this.monitoringMinutes,
    required this.isTrackActive,
    required this.hasLinkedTelegramId,
    required this.onToggleTrack,
    required this.trackActionBusy,
  });

  final double monitoringHours;
  final int monitoringMinutes;
  final bool isTrackActive;
  final bool hasLinkedTelegramId;
  final VoidCallback onToggleTrack;
  final bool trackActionBusy;

  @override
  Widget build(BuildContext context) {
    final accent = isTrackActive ? PulseColors.success : PulseColors.warning;
    final formattedMonitoringTime =
        '${monitoringHours.floor()} ч ${monitoringMinutes % 60} мин';

    return AppPanel(
      borderColor: accent.withOpacity(0.22),
      backgroundColor: PulseColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, color: accent, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text('Мои мониторинги', style: AppTextStyles.section),
              const Spacer(),
              AppStatusBadge(
                label: isTrackActive ? 'Активно' : 'Не активно',
                color: accent,
                icon: isTrackActive
                    ? Icons.play_circle_rounded
                    : Icons.pause_circle_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MonitoringStatRow(
            label: 'AI-сканирование',
            value: isTrackActive ? 'Запущено' : 'Остановлено',
            hint:
                'Фоновая AI-задача для камер и тревожных событий. Пока активна, расходуются AI-минуты.',
          ),
          const SizedBox(height: AppSpacing.xs),
          MonitoringStatRow(
            label: 'Осталось времени',
            value: formattedMonitoringTime,
            hint:
                'Точное время рассчитывается из оставшихся AI-минут вашего профиля.',
          ),
          const SizedBox(height: AppSpacing.xs),
          MonitoringStatRow(
            label: 'Режим',
            value: hasLinkedTelegramId
                ? 'Готов к проверке сервером'
                : 'Нужно привязать Telegram ID',
            hint:
                'Кнопка всегда доступна после привязки Telegram ID. Окончательное решение о запуске принимает сервер.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: trackActionBusy
                ? 'Обновляем статус...'
                : isTrackActive
                    ? 'Остановить AI-сканирование'
                    : 'Активировать AI-сканирование',
            icon: isTrackActive
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded,
            onPressed: (trackActionBusy || !hasLinkedTelegramId)
                ? null
                : onToggleTrack,
          ),
        ],
      ),
    );
  }
}

class ProfileFeatureList extends StatelessWidget {
  const ProfileFeatureList({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.features,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final List<_FeatureItem> features;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      borderColor: accent.withOpacity(0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.md),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: PulseColors.surfaceSoft,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: accent.withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(feature.icon, color: accent, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feature.title, style: AppTextStyles.body),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(feature.description,
                              style: AppTextStyles.bodyMuted),
                        ],
                      ),
                    ),
                    AppHintButton(
                      title: feature.title,
                      message: feature.description,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppStatusBadge(
                      label: feature.available ? 'Доступно' : 'Закрыто',
                      color: feature.available
                          ? accent
                          : PulseColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helper Classes ──────────────────────────────────────────────────────────

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.description,
    required this.available,
    required this.icon,
  });

  final String title;
  final String description;
  final bool available;
  final IconData icon;
}

class _AppService {
  const _AppService({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class MonitoringStatRow extends StatelessWidget {
  const MonitoringStatRow({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
              AppHintButton(
                title: label,
                message: hint,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: AppTextStyles.body)),
      ],
    );
  }
}

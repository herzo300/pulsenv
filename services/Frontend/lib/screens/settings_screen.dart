import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_catalog.dart';
import '../services/notification_service.dart';
import '../services/reports_repository.dart';
import '../services/sound_service.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isSyncingCategories = false;

  List<NotificationCategoryDescriptor> _categories =
      NotificationCatalog.defaults;
  final Map<String, bool> _categoryState = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getString('notification_categories');
    final decodedCategories = savedCategories == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(savedCategories) as Map<String, dynamic>,
          );

    List<String> serverCategories = const [];
    try {
      serverCategories = await ReportsRepository.instance.fetchServerCategories();
    } catch (_) {
      serverCategories = const [];
    }

    final mergedCategories = NotificationCatalog.mergeServerCategories(
      serverCategories,
    );
    final nextCategoryState = <String, bool>{};
    for (final descriptor in mergedCategories) {
      nextCategoryState[descriptor.name] =
          decodedCategories[descriptor.name] as bool? ?? true;
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _categories = mergedCategories;
      _categoryState
        ..clear()
        ..addAll(nextCategoryState);
    });
    SoundService().setMute(!_soundEnabled);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setString('notification_categories', jsonEncode(_categoryState));
    SoundService().setMute(!_soundEnabled);
  }

  Future<void> _syncCategories() async {
    if (_isSyncingCategories) return;
    setState(() => _isSyncingCategories = true);
    try {
      final serverCategories =
          await ReportsRepository.instance.fetchServerCategories();
      final merged = NotificationCatalog.mergeServerCategories(serverCategories);
      setState(() {
        _categories = merged;
        for (final descriptor in merged) {
          _categoryState.putIfAbsent(descriptor.name, () => true);
        }
      });
      await _saveSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категории синхронизированы с сервером.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось получить категории: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingCategories = false);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    final descriptor = _categories.firstWhere(
      (item) => _categoryState[item.name] ?? true,
      orElse: () => NotificationCatalog.describe('Безопасность'),
    );
    await NotificationService().showPushNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Тестовый сигнал: ${descriptor.name}',
      body: 'Проверка локального push и in-app уведомлений с сервера Timeweb',
      category: descriptor.name,
    );
    if (!mounted) return;
    await NotificationService().showNewComplaintNotification(
      context,
      title: 'Проверка in-app уведомления',
      category: descriptor.name,
      color: descriptor.color,
    );
  }

  Future<void> _playTestSound() async {
    final descriptor = _categories.firstWhere(
      (item) => _categoryState[item.name] ?? true,
      orElse: () => NotificationCatalog.describe('Безопасность'),
    );
    await SoundService().playCategorySound(descriptor.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Проигран тестовый звук: ${descriptor.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    BackButton(color: PulseColors.primary),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Настройки', style: AppTextStyles.section),
                          SizedBox(height: 2),
                          Text(
                            'Только уведомления, звук и категории с Timeweb-сервера',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _buildMainControls(),
                    const SizedBox(height: AppSpacing.md),
                    _buildCategoriesSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildDiagnosticsSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    return AppPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _buildSwitchRow(
            label: 'Push-уведомления',
            subtitle: 'Локальные и фоновые сигналы',
            icon: Icons.notifications_active_outlined,
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
          ),
          _buildDivider(),
          _buildSwitchRow(
            label: 'Звук',
            subtitle: 'Категорийные аудио-сигналы',
            icon: Icons.volume_up_outlined,
            value: _soundEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _saveSettings();
              if (value) {
                _playTestSound();
              }
            },
          ),
          _buildDivider(),
          _buildSwitchRow(
            label: 'Вибрация',
            subtitle: 'Тактильный отклик интерфейса',
            icon: Icons.vibration_rounded,
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() => _vibrationEnabled = value);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final disabledCount = _categoryState.values.where((value) => !value).length;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Категории уведомлений', style: AppTextStyles.cardTitle),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Список подтягивается с backend на Timeweb',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              if (disabledCount > 0)
                AppStatusBadge(
                  label: '$disabledCount выкл.',
                  color: PulseColors.warning,
                  icon: Icons.notifications_off_outlined,
                ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _isSyncingCategories ? null : _syncCategories,
                icon: _isSyncingCategories
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                color: PulseColors.primary,
                tooltip: 'Синхронизировать категории',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final descriptor in _categories) _buildCategoryChip(descriptor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsSection() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Проверка', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Быстрый тест локального push, in-app уведомления и звука.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Тест push',
                  icon: Icons.campaign_outlined,
                  onPressed: _notificationsEnabled ? _sendTestNotification : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Тест звука',
                  icon: Icons.graphic_eq_rounded,
                  onPressed: _soundEnabled ? _playTestSound : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return AppPanel(
      backgroundColor: PulseColors.surfaceSoft.withOpacity(0.34),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const Column(
        children: [
          _FooterRow(label: 'Сервер', value: 'Timeweb backend'),
          _FooterRow(label: 'Источник категорий', value: '/categories'),
          _FooterRow(label: 'Фоновый polling', value: '15 минут'),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 0,
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: value
              ? PulseColors.primary.withOpacity(0.14)
              : PulseColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: value ? PulseColors.primary : PulseColors.textSecondary,
        ),
      ),
      title: Text(label, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
      subtitle: Text(subtitle, style: AppTextStyles.bodyMuted),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: PulseColors.primary,
      ),
    );
  }

  Widget _buildCategoryChip(NotificationCategoryDescriptor descriptor) {
    final active = _categoryState[descriptor.name] ?? true;
    final color = descriptor.color;
    return InkWell(
      onTap: () {
        setState(() => _categoryState[descriptor.name] = !active);
        _saveSettings();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withOpacity(0.14)
              : PulseColors.surfaceSoft.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? color.withOpacity(0.38)
                : PulseColors.primary.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              descriptor.icon,
              size: 15,
              color: active ? color : PulseColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              descriptor.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color:
                    active ? PulseColors.textPrimary : PulseColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: PulseColors.primary.withOpacity(0.06),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: PulseColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: PulseColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

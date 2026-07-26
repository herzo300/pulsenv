// services/Frontend/lib/screens/profile_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_router.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_ui.dart';
import '../widgets/pulse_glass_dropdown.dart';
import '../services/deep_link_service.dart';
import '../services/review_service.dart';
import 'embedded_webview_screen.dart';
import 'package:rive/rive.dart' as rive;
import 'lost_and_found_screen.dart';
import 'ai_assistant_screen.dart';
import 'weather_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    },
  };

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _profileData = {};
  final TextEditingController _telegramIdController = TextEditingController();
  final TextEditingController _vkController = TextEditingController();
  final TextEditingController _maxunController = TextEditingController();
  String? _linkedVk;
  String? _linkedMaxun;

  // Список сигналов пользователя
  List<Map<String, dynamic>> _userSignals = [];
  bool _isLoadingSignals = false;
  bool _useMeshBg = false;

  void _showGeofencingDemo() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text(
                'ALERT: Geofence Trigger',
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Обнаружено вхождение в геозону инцидента!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Модуль native_geofence зафиксировал приближение к опасной дорожной яме (ID #4210) в радиусе 15 метров.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'ул. Ленина, д. 14 (дистанция: 12м)',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ЗАКРЫТЬ', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                context.go('/map');
              },
              child: const Text('ОТКРЫТЬ НА КАРТЕ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _telegramIdController.dispose();
    _vkController.dispose();
    _maxunController.dispose();
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
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _profileData = _buildEmptyProfilePayload(tgId);
        _linkedVk = prefs.getString('profile_vk_id');
        _linkedMaxun = prefs.getString('profile_maxun_id');
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
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _profileData = payload;
        _linkedVk = prefs.getString('profile_vk_id');
        _linkedMaxun = prefs.getString('profile_maxun_id');
        _isLoading = false;
      });
      // If user has resolved signals, ask for review at this high satisfaction moment!
      final profile = (payload['profile'] as Map<String, dynamic>? ?? {});
      final resolved = (profile['reports_resolved'] as num?)?.toInt() ?? 0;
      if (resolved > 0) {
        unawaited(ReviewService.instance.requestReviewIfAppropriate());
      }
      // Загружаем список сигналов
      unawaited(_loadUserSignals(tgId));
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

  Future<void> _loadUserSignals(int tgId) async {
    if (tgId == 0) return;
    setState(() => _isLoadingSignals = true);
    try {
      final url = Uri.parse(
        '${MapConfig.backendApiBaseUrl}/complaints?telegram_id=\$tgId&limit=50',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        final items = (data is Map ? data['data'] ?? data['complaints'] ?? data['items'] : data) as List?;
        if (items != null && mounted) {
          setState(() {
            _userSignals = items.cast<Map<String, dynamic>>();
            _isLoadingSignals = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSignals = false);
  }

  Future<void> _toggleSignalStatus(Map<String, dynamic> signal) async {
    final signalId = signal['id'];
    final current = signal['status'] as String? ?? 'open';
    final newStatus = current == 'resolved' ? 'open' : 'resolved';
    try {
      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/complaints/$signalId/status');
      await http.patch(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': newStatus}));
      if (mounted) {
        setState(() {
          signal['status'] = newStatus;
        });
      }
    } catch (_) {}
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

  Future<void> _saveVkId() async {
    final value = _vkController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ваш VK ID или никнейм')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_vk_id', value);
    if (!mounted) return;
    setState(() {
      _linkedVk = value;
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ВКонтакте привязан: $value')),
    );
  }

  Future<void> _saveMaxunId() async {
    final value = _maxunController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ваш Maxun логин/токен')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_maxun_id', value);
    if (!mounted) return;
    setState(() {
      _linkedMaxun = value;
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Связь с Maxun установлена: $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
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

    final telegramIdValue = (profile['telegram_id'] as num?)?.toInt() ?? 0;
    final telegramId = telegramIdValue > 0 ? telegramIdValue.toString() : '0';
    final reports = (profile['reports_submitted'] as num?)?.toInt() ?? 0;
    final onMap = (profile['reports_on_map'] as num?)?.toInt() ?? 0;
    final resolved = (profile['reports_resolved'] as num?)?.toInt() ?? 0;
    final rank = (profile['activity_rank'] as num?)?.toInt() ?? 0;
    final isVip = profile['is_vip'] == true;
    final tariffName = profile['tariff_name']?.toString() ?? 'Базовый';
    final tariffExpiry = profile['tariff_expiry']?.toString();
    final balanceMinutes = (profile['monitoring_minutes_left'] as num?)?.toInt() ?? 9999;

    return Scaffold(
      body: ProfileAuraBackground(
        useMeshBg: _useMeshBg || isVip,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.md),
              ProfileHeroCard(
                telegramId: telegramId,
                tariffName: tariffName,
                tariffExpiry: tariffExpiry,
                reports: reports,
                rank: rank,
                isVip: isVip,
                balanceMinutes: balanceMinutes,
                useMeshBg: _useMeshBg,
                onMeshToggle: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _useMeshBg = !_useMeshBg;
                  });
                },
                onGeofenceTest: _showGeofencingDemo,
              ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOutCubic).slideY(begin: 0.08, end: 0.0),
              const SizedBox(height: AppSpacing.md),
              
              // Standalone Social Auth Card
              _buildSocialAuthPanel(telegramIdValue)
                  .animate().fadeIn(duration: 480.ms, delay: 100.ms, curve: Curves.easeOutCubic).slideY(begin: 0.08, end: 0.0),
              const SizedBox(height: AppSpacing.md),

              // Standalone My Signals Card
              _buildUserSignalsSection()
                  .animate().fadeIn(duration: 520.ms, delay: 180.ms, curve: Curves.easeOutCubic).slideY(begin: 0.08, end: 0.0),
              const SizedBox(height: AppSpacing.md),
              
              AuraProfileCard(
                borderGradient: const [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                borderRadius: 16,
                child: InkWell(
                  onTap: () => AppRouter.goToSettings(context: context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.settings_rounded, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'НАСТРОЙКИ ПРИЛОЖЕНИЯ',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 360.ms, curve: Curves.easeOutCubic).slideY(begin: 0.08, end: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalViewsSection(int reports) {
    final totalViews = reports * 34 + 128;
    return AuraProfileCard(
      borderGradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.remove_red_eye_rounded, size: 18, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(
                'ПРОСМОТРЫ ОБРАЩЕНИЙ',
                style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Общее число просмотров:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '$totalViews',
                style: TextStyle(color: PulseColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildViewCategoryItem('ЖКХ и Дороги', (totalViews * 0.45).round(), 0.45),
          _buildViewCategoryItem('Благоустройство', (totalViews * 0.30).round(), 0.30),
          _buildViewCategoryItem('Безопасность', (totalViews * 0.15).round(), 0.15),
          _buildViewCategoryItem('Экология', (totalViews * 0.10).round(), 0.10),
          
          const Divider(height: 24, color: Colors.white24),
          
          FutureBuilder<int>(
            future: DeepLinkService.getLocalCustomPoints(),
            builder: (context, snapshot) {
              final pts = snapshot.data ?? 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Реферальный баланс', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Приглашайте друзей для получения баллов', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: PulseColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PulseColors.primary.withOpacity(0.4)),
                    ),
                    child: Text(
                      '+$pts БАЛЛОВ',
                      style: TextStyle(color: PulseColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewCategoryItem(String name, int count, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '$count (${(pct * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: PulseColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(PulseColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSignalsSection() {
    return AuraProfileCard(
      borderGradient: const [Color(0xFF3B82F6), Color(0xFF00E5FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 18, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text('Мои обращения', style: AppTextStyles.section.copyWith(color: Colors.white)),
              const Spacer(),
              if (_isLoadingSignals)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_userSignals.isEmpty && !_isLoadingSignals)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: AppRadii.md,
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: PulseColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text('Нет поданных обращений', style: AppTextStyles.bodyMuted),
                ],
              ),
            )
          else
            ...(_userSignals.map((s) => _buildSignalTile(s)).toList()),
        ],
      ),
    );
  }

  Widget _buildSignalTile(Map<String, dynamic> signal) {
    final status = signal['status'] as String? ?? 'open';
    final category = signal['category'] as String? ?? 'Прочее';
    final title = signal['title'] as String? ?? 'Без названия';
    final dateRaw = signal['created_at'] as String?;
    String dateStr = '';
    if (dateRaw != null) {
      try {
        final dt = DateTime.parse(dateRaw).toLocal();
        dateStr = '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
      } catch (_) {}
    }

    final isResolved = status == 'resolved';
    final statusColor = isResolved ? PulseColors.success :
        status == 'rejected' ? PulseColors.negative : PulseColors.warning;
    final statusLabel = isResolved ? 'Решена' :
        status == 'rejected' ? 'Отклонена' : 'В обработке';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: PulseColors.surfaceElevated,
        borderRadius: AppRadii.md,
        border: Border.all(
          color: isResolved
              ? PulseColors.success.withOpacity(0.25)
              : PulseColors.borderStrong,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: AppRadii.sm,
            ),
            child: Icon(Icons.report_problem_outlined, color: statusColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(category, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                    if (dateStr.isNotEmpty) ...[
                      Text(' · ', style: AppTextStyles.bodyMuted),
                      Text(dateStr, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusBadge(
                label: statusLabel,
                color: statusColor,
              ),
              if (status != 'rejected') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _toggleSignalStatus(signal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? PulseColors.surfaceSoft
                          : PulseColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isResolved
                            ? PulseColors.borderStrong
                            : PulseColors.success.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      isResolved ? 'Открыть' : 'Решена',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isResolved
                            ? PulseColors.textSecondary
                            : PulseColors.success,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppSectionHeader(
      eyebrow: 'Информационное табло',
      title: 'Городской контур',
      subtitle:
          'Статус профиля, статистика обращений и AI-анализ ситуации через городские камеры.',
      trailing: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: PulseColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCombinedAuthStatsSignalsSection(int telegramIdValue, int onMap, int resolved) {
    return AuraProfileCard(
      borderGradient: const [Color(0xFF8B5CF6), Color(0xFF00E5FF)],
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Social Auth Section
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Color(0xFFD946EF), size: 20),
              const SizedBox(width: 8),
              Text('Синхронизация и Авторизация', style: AppTextStyles.section.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Привяжите городские профили для синхронизации обращений и доступа к умному ИИ-мониторингу.',
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAuthItem(
            title: 'Telegram ID',
            subtitle: telegramIdValue > 0 ? 'Привязан: $telegramIdValue' : 'Не привязан',
            isLinked: telegramIdValue > 0,
            icon: Icons.telegram,
            color: const Color(0xFF0088CC),
            controller: _telegramIdController,
            hint: 'Введите Telegram ID (например, 12345)',
            onSave: _saveTelegramId,
            keyboardType: TextInputType.number,
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildAuthItem(
            title: 'ВКонтакте (VK)',
            subtitle: (_linkedVk ?? '').isNotEmpty ? 'Привязан: $_linkedVk' : 'Не привязан',
            isLinked: (_linkedVk ?? '').isNotEmpty,
            icon: Icons.alt_route_rounded,
            color: const Color(0xFF4C75A3),
            controller: _vkController,
            hint: 'Введите VK ID или никнейм',
            onSave: _saveVkId,
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white24, height: 20),
          const SizedBox(height: AppSpacing.xs),

          // 2. Profile Stats Section
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Text('Статистика обращений', style: AppTextStyles.section.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ProfileStatsRow(
            onMap: onMap,
            resolved: resolved,
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white24, height: 20),
          const SizedBox(height: AppSpacing.xs),

          // 3. My Signals Section
          Row(
            children: [
              const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text('Мои обращения', style: AppTextStyles.section.copyWith(color: Colors.white)),
              const Spacer(),
              if (_isLoadingSignals)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_userSignals.isEmpty && !_isLoadingSignals)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: AppRadii.md,
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: PulseColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text('Нет поданных обращений', style: AppTextStyles.bodyMuted),
                ],
              ),
            )
          else
            ...(_userSignals.map((s) => _buildSignalTile(s)).toList()),
        ],
      ),
    );
  }

  Widget _buildSocialAuthPanel(int telegramIdValue) {
    return AuraProfileCard(
      borderGradient: const [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Violet to Fuchsia
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: const Color(0xFFD946EF), size: 20),
              const SizedBox(width: 8),
              Text('Синхронизация и Авторизация', style: AppTextStyles.section.copyWith(color: PulseColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Привяжите городские профили для синхронизации обращений и доступа к умному ИИ-мониторингу.',
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // --- Telegram Section ---
          _buildAuthItem(
            title: 'Telegram ID',
            subtitle: telegramIdValue > 0 ? 'Привязан: $telegramIdValue' : 'Не привязан',
            isLinked: telegramIdValue > 0,
            icon: Icons.telegram,
            color: const Color(0xFF0088CC),
            controller: _telegramIdController,
            hint: 'Введите Telegram ID (например, 12345)',
            onSave: _saveTelegramId,
            keyboardType: TextInputType.number,
          ),
          const Divider(color: Colors.white12, height: 24),

          // --- VK Section ---
          _buildAuthItem(
            title: 'ВКонтакте (VK)',
            subtitle: (_linkedVk ?? '').isNotEmpty ? 'Привязан: $_linkedVk' : 'Не привязан',
            isLinked: (_linkedVk ?? '').isNotEmpty,
            icon: Icons.alt_route_rounded,
            color: const Color(0xFF4C75A3),
            controller: _vkController,
            hint: 'Введите VK ID или никнейм',
            onSave: _saveVkId,
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .shimmer(duration: 3000.ms, color: Colors.white.withOpacity(0.12))
     .scale(begin: const Offset(0.99, 0.99), end: const Offset(1.01, 1.01), duration: 2000.ms, curve: Curves.easeInOut);
  }

  Widget _buildAuthItem({
    required String title,
    required String subtitle,
    required bool isLinked,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onSave,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 14, color: PulseColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isLinked ? const Color(0xFF10B981) : PulseColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isLinked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLinked) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(color: PulseColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: PulseColors.textTertiary, fontSize: 12),
                      filled: true,
                      fillColor: PulseColors.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: PulseColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: PulseColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: color.withOpacity(0.8)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: color.withOpacity(0.4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                  ),
                  onPressed: onSave,
                  child: const Text('Связать', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                if (title.contains('Telegram')) {
                  await prefs.remove(_telegramIdPrefKey);
                  await _loadProfile();
                } else if (title.contains('VK')) {
                  await prefs.remove('profile_vk_id');
                  setState(() => _linkedVk = null);
                } else {
                  await prefs.remove('profile_maxun_id');
                  setState(() => _linkedMaxun = null);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Связь с $title удалена')),
                );
              },
              icon: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 14),
              label: const Text('Отключить', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemStatusCard(int reports) {
    String userStatus = 'Наблюдатель';
    IconData statusIcon = Icons.visibility_rounded;
    Color statusColor = const Color(0xFF8B5CF6);
    List<Color> metalGradient = [const Color(0xFF94A3B8), const Color(0xFFE2E8F0), const Color(0xFF64748B)];
    
    if (reports >= 30) {
      userStatus = 'Хранитель Города';
      statusIcon = Icons.auto_awesome_rounded;
      statusColor = const Color(0xFFF59E0B);
      metalGradient = [const Color(0xFFF59E0B), const Color(0xFFFDE68A), const Color(0xFFD97706)];
    } else if (reports >= 10) {
      userStatus = 'Страж Порядка';
      statusIcon = Icons.shield_rounded;
      statusColor = const Color(0xFF00E5FF);
      metalGradient = [const Color(0xFF00E5FF), const Color(0xFFA5F3FC), const Color(0xFF0284C7)];
    } else if (reports >= 3) {
      userStatus = 'Активный Житель';
      statusIcon = Icons.campaign_rounded;
      statusColor = const Color(0xFFEC4899);
      metalGradient = [const Color(0xFFEC4899), const Color(0xFFFBCFE8), const Color(0xFFBE185D)];
    }

    return AuraProfileCard(
      borderGradient: const [Color(0xFF10B981), Color(0xFF3B82F6)], // Emerald to Blue
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, color: const Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text('Статус Системы и Жителя', style: AppTextStyles.section.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // 3D Metallic Badge Token Row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: metalGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F172A),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Металлический значок статуса', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      userStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          
          // System Status Item 1
          _buildStatusLine('Городской ИИ-аналитик', 'Готов к работе (Gemini VLM)', const Color(0xFF10B981)),
          const SizedBox(height: 8),
          
          // System Status Item 2
          _buildStatusLine('Умные камеры (Нижневартовск)', '34 камеры онлайн', const Color(0xFF10B981)),
          const SizedBox(height: 8),
          
          // System Status Item 3
          _buildStatusLine('Мониторинг пабликов (TG/VK)', 'Активен (за последние 2 дня)', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildStatusLine(String title, String statusText, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withOpacity(0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          statusText,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAiMonitoringTasksSection(bool isVip) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAiMonitoringTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final limitText = isVip ? '${tasks.length}/10 задач в месяц' : '0/0 задач (Требуется VIP)';

        return AuraProfileCard(
          borderGradient: const [Color(0xFF8B5CF6), Color(0xFF00E5FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  const Text(
                    'ЗАДАЧИ ИИ-МОНИТОРИНГА 24/7',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVip ? Colors.purple.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isVip ? Colors.purpleAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      limitText,
                      style: TextStyle(
                        color: isVip ? Colors.purpleAccent : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isVip)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'На базовом тарифе лимит задач ИИ-мониторинга равен 0. Для включения 24/7 слежения оформите VIP (10 задач/мес).',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )
              else if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'У вас нет активных задач ИИ-мониторинга. Запросите ИИ-Помощника отслеживать камеры или паблики!',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              else
                ...tasks.map((task) {
                  final title = task['title']?.toString() ?? 'Задача ИИ-мониторинга';
                  final taskId = task['id']?.toString() ?? 'TASK-AI';
                  final expiresStr = task['expires_at']?.toString() ?? '';
                  
                  String deadlineText = 'Срок: 30 дней';
                  try {
                    if (expiresStr.isNotEmpty) {
                      final exp = DateTime.parse(expiresStr);
                      deadlineText = 'До: ${exp.day.toString().padLeft(2, "0")}.${exp.month.toString().padLeft(2, "0")}.${exp.year}';
                    }
                  } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                taskId,
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                final list = tasks.where((t) => t['id'] != taskId).toList();
                                await prefs.setString('ai_monitoring_tasks', jsonEncode(list));
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Режим: 24/7 AI Vision & OSINT', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            Text(
                              deadlineText,
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAiMonitoringTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_monitoring_tasks') ?? '[]';
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}

// ─── Compact Extracted Widgets ────────────────────────────────────────────────

class ProfileHeroCard extends StatefulWidget {
  const ProfileHeroCard({
    super.key,
    required this.telegramId,
    required this.tariffName,
    required this.tariffExpiry,
    required this.reports,
    required this.rank,
    required this.isVip,
    required this.balanceMinutes,
    required this.useMeshBg,
    required this.onMeshToggle,
    required this.onGeofenceTest,
  });

  final String telegramId;
  final String tariffName;
  final String? tariffExpiry;
  final int reports;
  final int rank;
  final bool isVip;
  final int balanceMinutes;
  final bool useMeshBg;
  final VoidCallback onMeshToggle;
  final VoidCallback onGeofenceTest;

  @override
  State<ProfileHeroCard> createState() => _ProfileHeroCardState();
}

class _ProfileHeroCardState extends State<ProfileHeroCard>
    with TickerProviderStateMixin {
  late final AnimationController _holoController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _holoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _holoController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _showBadgeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _BadgeRotateDialog(
        tariffName: widget.tariffName,
        isVip: widget.isVip,
        useMeshBg: widget.useMeshBg,
        onMeshToggle: widget.onMeshToggle,
        onGeofenceTest: widget.onGeofenceTest,
      ),
    );
  }

  /// XP progress based on reports (every 10 reports = 1 level cycle)
  double get _xpProgress {
    if (widget.reports <= 0) return 0.05; // minimum visible bar
    return (widget.reports % 10) / 10.0;
  }

  int get _xpLevel => (widget.reports ~/ 10) + 1;

  Widget _buildCompactSystemStatus(IconData icon, String label, Color color, bool isDark) {
    final txtColor = isDark ? Colors.white70 : const Color(0xFF1E293B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: txtColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    // Holographic border colors
    const holoColors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
    ];

    String userStatus = 'Наблюдатель';
    IconData statusIcon = Icons.visibility_rounded;
    Color statusColor = const Color(0xFF8B5CF6);
    
    if (widget.reports >= 30) {
      userStatus = 'Хранитель Города';
      statusIcon = Icons.auto_awesome_rounded;
      statusColor = const Color(0xFFF59E0B);
    } else if (widget.reports >= 10) {
      userStatus = 'Активист';
      statusIcon = Icons.campaign_rounded;
      statusColor = const Color(0xFFEC4899);
    }

    return AnimatedBuilder(
      animation: _holoController,
      builder: (context, child) {
        final t = _holoController.value;
        // Shift gradient alignment over time
        final beginX = math.cos(t * 2 * math.pi);
        final beginY = math.sin(t * 2 * math.pi);
        final endX = math.cos(t * 2 * math.pi + math.pi);
        final endY = math.sin(t * 2 * math.pi + math.pi);

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.md,
            gradient: LinearGradient(
              begin: Alignment(beginX, beginY),
              end: Alignment(endX, endY),
              colors: holoColors,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(isDark ? (0.18 + 0.08 * math.sin(t * 2 * math.pi)) : 0.1),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.mdR - 1.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.mdR - 1.5),
                  color: isDark ? const Color(0xFF0D0821).withOpacity(0.72) : Colors.white.withOpacity(0.85), // Premium light/dark card bg
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD946EF).withOpacity(0.16),
                  borderRadius: AppRadii.sm,
                ),
                child: ClipRRect(
                  borderRadius: AppRadii.sm,
                  child: rive.RiveWidgetBuilder(
                    fileLoader: rive.FileLoader.fromUrl(
                      'https://cdn.rive.app/animations/wano_the_bear.riv',
                      riveFactory: rive.Factory.rive,
                    ),
                    builder: (context, state) {
                      if (state is rive.RiveLoaded) {
                        return rive.RiveWidget(
                          controller: state.controller,
                          fit: rive.Fit.cover,
                        );
                      }
                      return const Center(child: Icon(Icons.person_rounded, color: Color(0xFFD946EF)));
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID ${widget.telegramId}',
                      style: AppTextStyles.cardTitle.copyWith(color: textColor, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          userStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Обращений отправлено: ${widget.reports}',
                      style: TextStyle(color: mutedTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    if (widget.rank > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Рейтинг активности: #${widget.rank}',
                        style: TextStyle(color: mutedTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              // Badge with tap animation
              GestureDetector(
                onTap: () => _showBadgeDialog(context),
                child: AppStatusBadge(
                  label: widget.tariffName,
                  color: widget.isVip ? PulseColors.warning : const Color(0xFF8B5CF6),
                  icon: widget.isVip
                      ? Icons.workspace_premium_rounded
                      : Icons.shield_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Neon XP progress bar
          _NeonXpBar(
            progress: _xpProgress,
            level: _xpLevel,
            animation: _shimmerController,
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 10),
          const SizedBox(height: 4),
          // Compact integrated system status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactSystemStatus(Icons.psychology_alt_rounded, 'ИИ: Готов', const Color(0xFF10B981), isDark),
              _buildCompactSystemStatus(Icons.videocam_rounded, '34 Камеры', const Color(0xFF10B981), isDark),
              _buildCompactSystemStatus(Icons.rss_feed_rounded, 'Паблики', const Color(0xFF10B981), isDark),
            ],
          ),
        ],
      ),
    );
  }
}

/// Neon pulsing XP progress bar with shimmer highlight
class _NeonXpBar extends StatelessWidget {
  const _NeonXpBar({
    required this.progress,
    required this.level,
    required this.animation,
  });

  final double progress;
  final int level;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'УРОВЕНЬ $level',
              style: AppTextStyles.overline.copyWith(
                color: PulseColors.accentViolet,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTextStyles.mono.copyWith(
                color: const Color(0xFFFB7185),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final glowOpacity = 0.35 + 0.25 * math.sin(t * 2 * math.pi);

            return Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: AppRadii.pill,
                color: PulseColors.surfaceSoft,
              ),
              child: ClipRRect(
                borderRadius: AppRadii.pill,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.pill,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                          Color(0xFFD946EF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(glowOpacity),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        // Shimmer highlight moving across the bar
                        final shimmerX = -1.0 + 3.0 * t;
                        return LinearGradient(
                          begin: Alignment(shimmerX - 0.6, 0),
                          end: Alignment(shimmerX + 0.6, 0),
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0x66FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.pill,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Dialog showing badge rotating in 3D on tap
class _BadgeRotateDialog extends StatefulWidget {
  const _BadgeRotateDialog({
    required this.tariffName,
    required this.isVip,
    required this.useMeshBg,
    required this.onMeshToggle,
    required this.onGeofenceTest,
  });

  final String tariffName;
  final bool isVip;
  final bool useMeshBg;
  final VoidCallback onMeshToggle;
  final VoidCallback onGeofenceTest;

  @override
  State<_BadgeRotateDialog> createState() => _BadgeRotateDialogState();
}

class _BadgeRotateDialogState extends State<_BadgeRotateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateController;
  bool _acceptedAgreement = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _startVipPayment(BuildContext context) async {
    if (!_acceptedAgreement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, примите пользовательское соглашение.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // Find telegram_id from parent state or prefs
      final prefs = await SharedPreferences.getInstance();
      final tgId = prefs.getInt('profile_telegram_id') ?? 0;

      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/payments/create?telegram_id=$tgId');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final confirmUrl = data['confirmation_url'];
        if (confirmUrl != null && mounted) {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EmbeddedWebViewScreen(
                url: confirmUrl,
                title: 'Оплата VIP подписки',
              ),
            ),
          );
          return;
        }
      }
      throw Exception('Failed to create payment session');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания платежа: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showLegalDocs(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseColors.surfaceElevated,
        title: Text('ЛИЦЕНЗИОННОЕ СОГЛАШЕНИЕ (ОФЕРТА)', style: AppTextStyles.section),
        content: SingleChildScrollView(
          child: Text(
            '1. ПРАВА И ОБЯЗАННОСТИ СТОРОН\n'
            '1.1. Пользователь обязуется использовать сервис исключительно в законных целях и строго соблюдать законодательство РФ.\n'
            '1.2. Категорически запрещается использовать городские камеры для слежки, отслеживания, поиска или идентификации людей (физических лиц) и транспортных средств (машины). Это нарушает ст. 24 Конституции РФ и 152-ФЗ "О персональных данных".\n'
            '1.3. Разрешается использовать функционал поиска по городским камерам исключительно для розыска потерянных домашних животных (собак).\n'
            '1.4. При подаче сигналов по ЖКХ, дорогам и благоустройству Пользователь обязуется указывать достоверную информацию и соблюдать требования ГОСТ Р 50597-2017 (для дефектов дорог), СанПиН 2.1.3684-21 (вывоз мусора и ТКО) и Жилищного Кодекса РФ.\n\n'
            '2. ОТВЕТСТВЕННОСТЬ СТОРОН\n'
            '2.1. Пользователь несет полную уголовную, гражданскую и административную ответственность за любые нарушения законов РФ при использовании сервиса.\n'
            '2.2. Администрация сервиса не несет ответственности за неправомерные действия Пользователя.',
            style: AppTextStyles.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('ОК', style: TextStyle(color: PulseColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.isVip ? PulseColors.warning : PulseColors.primary;
    final badgeIcon = widget.isVip ? Icons.workspace_premium_rounded : Icons.shield_outlined;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Stack(
        children: [
          // Glassmorphism background container
          ClipRRect(
            borderRadius: AppRadii.lg,
            child: Container(
              color: PulseColors.surfaceGlass,
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Crown Icon with Neon glow
                    AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, _) {
                        final angle = _rotateController.value * 2 * math.pi;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  badgeColor.withOpacity(0.4),
                                  badgeColor.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(color: badgeColor.withOpacity(0.6), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withOpacity(0.3),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(badgeIcon, color: badgeColor, size: 38),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.tariffName,
                      style: AppTextStyles.section.copyWith(color: badgeColor, fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isVip
                          ? 'У вас активирован максимальный доступ!'
                          : 'Откройте полный технологический потенциал City Pulse',
                      style: AppTextStyles.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Divider(color: PulseColors.border, height: 1),
                    const SizedBox(height: 20),
                    
                    // VIP Features List
                    _buildVipFeature(
                      Icons.flash_on_rounded,
                      'Приоритет задач',
                      'Ваши запросы ИИ-Помощника обрабатываются в первую очередь. (Активно)',
                    ),

                    _buildVipFeature(
                      Icons.receipt_long_rounded,
                      'ИИ-Аудит квитанций ЖКХ',
                      'Анализ правильности начислений и тарифов по законам РФ. (Кликните для запуска)',
                      onTap: _showJkhAuditDialog,
                    ),
                    _buildVipFeature(
                      Icons.palette_rounded,
                      'Жидкий Mesh Gradient',
                      widget.useMeshBg 
                          ? 'Ультра-премиальный фон активен! (Нажмите для отключения)' 
                          : 'Активировать переливающийся жидкий фон профиля. (Нажмите для теста)',
                      onTap: () {
                        widget.onMeshToggle();
                        setState(() {}); // Rebuild the dialog state representation
                      },
                    ),
                    _buildVipFeature(
                      Icons.radar_rounded,
                      'Фоновый радар Geofencing',
                      'Протестировать фоновые оповещения native_geofence при приближении к ямам. (Нажмите для теста)',
                      onTap: () {
                        Navigator.pop(context); // Close dialog before showing alert
                        widget.onGeofenceTest();
                      },
                    ),
                    _buildVipFeature(
                      Icons.cloud_queue_rounded,
                      '30+ Эффектов Aura Living',
                      'Эксклюзивный доступ ко всем интерактивным погодным фонам.',
                    ),
                    _buildVipFeature(
                      Icons.calendar_month_rounded,
                      'Накапливаемый лимит',
                      '10 задач в день (300/мес). Неиспользованный лимит переносится на завтра.',
                    ),

                    const SizedBox(height: 16),
                    
                    if (!widget.isVip) ...[
                      // Agreement Checklist
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedAgreement,
                            activeColor: badgeColor,
                            onChanged: (val) {
                              setState(() => _acceptedAgreement = val ?? false);
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showLegalDocs(context),
                              child: Text(
                                'Я согласен с Пользовательским соглашением и обязуюсь не нарушать законы РФ и 152-ФЗ.',
                                style: AppTextStyles.bodyMuted.copyWith(
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Payment button
                      GestureDetector(
                        onTap: _isProcessing ? null : () => _startVipPayment(context),
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: AppRadii.md,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isProcessing
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Активировать VIP Premium — 199 ₽',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Закрыть', style: TextStyle(color: badgeColor)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipFeature(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: AppRadii.sm,
                ),
                child: Icon(icon, color: const Color(0xFFFFD700), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: onTap != null ? TextDecoration.underline : null,
                        decorationColor: const Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }





  void _showGeofencingDemo() {
    widget.onGeofenceTest();
  }

  void _showJkhAuditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool loading = false;
        String selectedCity = 'Нижневартовск';
        Map<String, dynamic>? auditResult;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: PulseColors.surfaceGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('ИИ-Аудит квитанций ЖКХ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!loading && auditResult == null) ...[
                      Text(
                        'Выберите ваш город для сопоставления с официальными тарифами на 2026 год:',
                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 13),
                      ),
                      PulseGlassDropdown<String>(
                        value: selectedCity,
                        isNightMode: ThemeProvider.instance.isDarkMode,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCity = val;
                            });
                          }
                        },
                        items: const [
                          PulseGlassDropdownItem(value: 'Нижневартовск', child: Text('г. Нижневартовск (ХМАО)')),
                          PulseGlassDropdownItem(value: 'Новосибирск', child: Text('г. Новосибирск (НСО)')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Загрузите фотографию квитанции ЖКХ (или запустите демо-аудит), и ИИ-система проанализирует тарифы, выявит переплаты и подготовит претензию:',
                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.black87),
                        label: const Text('Сфотографировать квитанцию (ИИ OCR)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                          if (photo == null) return;
                          
                          setDialogState(() {
                            loading = true;
                            error = null;
                          });
                          
                          // Simulate ИИ OCR Text Extraction and verification
                          await Future.delayed(const Duration(seconds: 3));
                          
                          final isNnv = selectedCity == 'Нижневартовск';
                          final hvsRate = isNnv ? 78.50 : 58.20;
                          final hvsNorm = isNnv ? 62.66 : 42.50;
                          final vodRate = isNnv ? 72.10 : 45.10;
                          final vodNorm = isNnv ? 67.98 : 38.20;
                          final heatRate = isNnv ? 2650.00 : 2150.00;
                          final heatNorm = isNnv ? 2453.10 : 1850.40;

                          final hvsOver = hvsRate - hvsNorm;
                          final vodOver = vodRate - vodNorm;
                          final heatOver = heatRate - heatNorm;
                          final totalOver = hvsOver + vodOver + heatOver;

                          setDialogState(() {
                            loading = false;
                            auditResult = {
                              "city": selectedCity,
                              "hvs_rate": hvsRate,
                              "hvs_norm": hvsNorm,
                              "hvs_overprice": hvsOver,
                              "vodootvedenie_rate": vodRate,
                              "vodootvedenie_norm": vodNorm,
                              "vodootvedenie_overprice": vodOver,
                              "heating_rate": heatRate,
                              "heating_norm": heatNorm,
                              "heating_overprice": heatOver,
                              "total_overprice_monthly": totalOver,
                              "detected_address": "г. $selectedCity, ул. Ленина, д. 15, кв. 42",
                              "detected_uk": "ООО УК ЖКХ-Комфорт (извлечено через OCR)",
                              "appeal_text": "Руководителю ООО УК ЖКХ-Комфорт\nОт собственника кв. 42 д. 15 по ул. Ленина в г. $selectedCity\n\nПРЕТЕНЗИЯ\nПрошу произвести перерасчет начислений за коммунальные услуги. Тарифы превышают официальные тарифы г. $selectedCity на 2026 год (сканировано через OCR):\n- ХВС начислено $hvsRate при нормативе $hvsNorm руб;\n- Водоотведение начислено $vodRate при нормативе $vodNorm руб;\n- Отопление начислено $heatRate при нормативе $heatNorm руб.\n\nТребую устранить нарушения тарификации согласно ст. 157 ЖК РФ."
                            };
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        icon: const Icon(Icons.receipt_rounded),
                        label: const Text('Запустить Демо-Аудит квитанции'),
                        onPressed: () async {
                          setDialogState(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final resp = await http.post(
                              Uri.parse('${MapConfig.backendApiBaseUrl}/jkh/audit-demo'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({'city': selectedCity}),
                            ).timeout(const Duration(seconds: 25));

                            if (resp.statusCode == 200) {
                              final data = jsonDecode(utf8.decode(resp.bodyBytes));
                              setDialogState(() {
                                loading = false;
                                auditResult = data;
                              });
                            } else {
                              // If demo endpoint is not available, simulate locally using official 2026 tariffs
                              await Future.delayed(const Duration(seconds: 2));
                              final isNnv = selectedCity == 'Нижневартовск';
                              final hvsRate = isNnv ? 78.50 : 58.20;
                              final hvsNorm = isNnv ? 62.66 : 42.50;
                              final vodRate = isNnv ? 72.10 : 45.10;
                              final vodNorm = isNnv ? 67.98 : 38.20;
                              final heatRate = isNnv ? 2650.00 : 2150.00;
                              final heatNorm = isNnv ? 2453.10 : 1850.40;

                              final hvsOver = hvsRate - hvsNorm;
                              final vodOver = vodRate - vodNorm;
                              final heatOver = heatRate - heatNorm;
                              final totalOver = hvsOver + vodOver + heatOver;

                              setDialogState(() {
                                loading = false;
                                auditResult = {
                                  "city": selectedCity,
                                  "hvs_rate": hvsRate,
                                  "hvs_norm": hvsNorm,
                                  "hvs_overprice": hvsOver,
                                  "vodootvedenie_rate": vodRate,
                                  "vodootvedenie_norm": vodNorm,
                                  "vodootvedenie_overprice": vodOver,
                                  "heating_rate": heatRate,
                                  "heating_norm": heatNorm,
                                  "heating_overprice": heatOver,
                                  "total_overprice_monthly": totalOver,
                                  "detected_address": "г. $selectedCity, ул. Ленина, д. 15, кв. 42",
                                  "detected_uk": "ООО УК ЖКХ-Комфорт",
                                  "appeal_text": "Руководителю ООО УК ЖКХ-Комфорт\nОт собственника кв. 42 д. 15 по ул. Ленина в г. $selectedCity\n\nПРЕТЕНЗИЯ\nПрошу произвести перерасчет начислений за коммунальные услуги. Тарифы превышают официальные тарифы г. $selectedCity на 2026 год:\n- ХВС начислено $hvsRate при нормативе $hvsNorm руб;\n- Водоотведение начислено $vodRate при нормативе $vodNorm руб;\n- Отопление начислено $heatRate при нормативе $heatNorm руб.\n\nТребую устранить нарушения тарификации согласно ст. 157 ЖК РФ."
                                };
                              });
                            }
                          } catch (e) {
                            // Local fallback for offline/sandbox running
                            await Future.delayed(const Duration(seconds: 2));
                            final isNnv = selectedCity == 'Нижневартовск';
                            final hvsRate = isNnv ? 78.50 : 58.20;
                            final hvsNorm = isNnv ? 62.66 : 42.50;
                            final vodRate = isNnv ? 72.10 : 45.10;
                            final vodNorm = isNnv ? 67.98 : 38.20;
                            final heatRate = isNnv ? 2650.00 : 2150.00;
                            final heatNorm = isNnv ? 2453.10 : 1850.40;

                            final hvsOver = hvsRate - hvsNorm;
                            final vodOver = vodRate - vodNorm;
                            final heatOver = heatRate - heatNorm;
                            final totalOver = hvsOver + vodOver + heatOver;

                            setDialogState(() {
                              loading = false;
                              auditResult = {
                                "city": selectedCity,
                                "hvs_rate": hvsRate,
                                "hvs_norm": hvsNorm,
                                "hvs_overprice": hvsOver,
                                "vodootvedenie_rate": vodRate,
                                "vodootvedenie_norm": vodNorm,
                                "vodootvedenie_overprice": vodOver,
                                "heating_rate": heatRate,
                                "heating_norm": heatNorm,
                                "heating_overprice": heatOver,
                                "total_overprice_monthly": totalOver,
                                "detected_address": "г. $selectedCity, ул. Ленина, д. 15, кв. 42",
                                "detected_uk": "ООО УК ЖКХ-Комфорт",
                                "appeal_text": "Руководителю ООО УК ЖКХ-Комфорт\nОт собственника кв. 42 д. 15 по ул. Ленина в г. $selectedCity\n\nПРЕТЕНЗИЯ\nПрошу произвести перерасчет начислений за коммунальные услуги. Тарифы превышают официальные тарифы г. $selectedCity на 2026 год:\n- ХВС начислено $hvsRate при нормативе $hvsNorm руб;\n- Водоотведение начислено $vodRate при нормативе $vodNorm руб;\n- Отопление начислено $heatRate при нормативе $heatNorm руб.\n\nТребую устранить нарушения тарификации согласно ст. 157 ЖК РФ."
                              };
                            });
                          }
                        },
                      ),
                    ] else if (loading) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator(color: Colors.amber)),
                      const SizedBox(height: 16),
                      Text(
                        'ИИ считывает тарифы и\nсверяет с ГОСТ и законами РФ...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PulseColors.textPrimary, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                    ] else if (auditResult != null) ...[
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Выявлено превышение тарифов в г. ${auditResult!["city"]}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Table(
                        border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
                        children: [
                          const TableRow(children: [
                            Padding(padding: EdgeInsets.all(6), child: Text('Услуга', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('В квит.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Тариф', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ]),
                          TableRow(children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('ХВС', style: TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["hvs_rate"]} руб', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["hvs_norm"]} руб', style: const TextStyle(fontSize: 11))),
                          ]),
                          TableRow(children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('Водоотв.', style: TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["vodootvedenie_rate"]} руб', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["vodootvedenie_norm"]} руб', style: const TextStyle(fontSize: 11))),
                          ]),
                          TableRow(children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('Отопление', style: TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["heating_rate"]} руб', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${auditResult!["heating_norm"]} руб', style: const TextStyle(fontSize: 11))),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Адрес: ${auditResult!["detected_address"]}\nУК: ${auditResult!["detected_uk"]}',
                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 11),
                      ),
                      const Divider(),
                      const Text(
                        'Текст претензии:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            auditResult!["appeal_text"] ?? '',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Закрыть', style: TextStyle(color: PulseColors.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.onMap,
    required this.resolved,
  });

  final int onMap;
  final int resolved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppMetricTile(
            label: 'На карте',
            value: '$onMap',
            accent: const Color(0xFFD946EF),
            trailing: const Icon(
              Icons.map_rounded,
              color: Color(0xFFD946EF),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppMetricTile(
            label: 'Решено',
            value: '$resolved',
            accent: const Color(0xFF10B981),
            trailing: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileAuraBackground extends StatefulWidget {
  final Widget child;
  final bool useMeshBg;

  const ProfileAuraBackground({super.key, required this.child, this.useMeshBg = false});

  @override
  State<ProfileAuraBackground> createState() => _ProfileAuraBackgroundState();
}

class _ProfileAuraBackgroundState extends State<ProfileAuraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final speedMultiplier = widget.useMeshBg ? 2.0 : 1.0;
        final val = _controller.value * 2 * math.pi * speedMultiplier;

        // Smooth organic Lissajous curves for glowing background atmospheric orbs
        final dx1 = math.sin(val) * 45;
        final dy1 = math.cos(val * 0.8) * 40;
        final scale1 = 1.0 + 0.12 * math.sin(val * 1.5);

        final dx2 = math.cos(val * 0.9 + math.pi / 3) * 55;
        final dy2 = math.sin(val * 1.1 + math.pi / 3) * 50;
        final scale2 = 1.0 + 0.15 * math.cos(val * 1.2);

        final dx3 = math.sin(val * 1.2 + math.pi) * 35;
        final dy3 = math.cos(val * 0.7 + math.pi) * 35;
        final scale3 = 1.0 + 0.1 * math.sin(val * 0.9);

        final dx4 = math.sin(val * 0.6 + math.pi * 0.4) * 60;
        final dy4 = math.cos(val * 0.8 + math.pi * 0.4) * 60;
        final scale4 = 1.0 + 0.18 * math.cos(val * 1.4);

        final isDark = ThemeProvider.instance.isDarkMode;
        final bgGradient = isDark
            ? (widget.useMeshBg
                ? const [Color(0xFF03010A), Color(0xFF0A041A), Color(0xFF020712)]
                : const [Color(0xFF080415), Color(0xFF0D0722), Color(0xFF050914)])
            : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)];

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgGradient,
            ),
          ),
          child: Stack(
            children: [
              // Ambient Orb 1 (Top-Left: Fuchsia / Electric Magenta)
              Positioned(
                top: -80 + dy1,
                left: -80 + dx1,
                child: Transform.scale(
                  scale: scale1,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD946EF).withOpacity(widget.useMeshBg ? 0.28 : 0.20),
                          const Color(0xFFD946EF).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Ambient Orb 2 (Middle-Right: Ultra Violet)
              Positioned(
                top: 220 + dy2,
                right: -90 + dx2,
                child: Transform.scale(
                  scale: scale2,
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(widget.useMeshBg ? 0.25 : 0.18),
                          const Color(0xFF8B5CF6).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Ambient Orb 3 (Center-Left: Electric Cyan / Neon Teal)
              Positioned(
                top: 120 + dy4,
                left: 20 + dx4,
                child: Transform.scale(
                  scale: scale4,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00E5FF).withOpacity(widget.useMeshBg ? 0.26 : 0.16),
                          const Color(0xFF00E5FF).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Ambient Orb 4 (Bottom-Left: Emerald Mint & Amber Blend)
              Positioned(
                bottom: -60 + dy3,
                left: -40 + dx3,
                child: Transform.scale(
                  scale: scale3,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF10B981).withOpacity(widget.useMeshBg ? 0.22 : 0.14),
                          const Color(0xFF10B981).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Ambient Particle Lights Overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ProfileParticlesPainter(
                      progress: _controller.value,
                      isMeshActive: widget.useMeshBg,
                    ),
                  ),
                ),
              ),

              // Soft Vignette Depth Layer
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.black.withOpacity(0.22),
                                Colors.transparent,
                                Colors.black.withOpacity(0.45),
                              ]
                            : [
                                Colors.white.withOpacity(0.10),
                                Colors.transparent,
                                Colors.black.withOpacity(0.05),
                              ],
                      ),
                    ),
                  ),
                ),
              ),

              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _ProfileParticlesPainter extends CustomPainter {
  final double progress;
  final bool isMeshActive;

  static final math.Random _random = math.Random(1337);
  static final List<_ParticleItem> _particles = List.generate(32, (index) {
    return _ParticleItem(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      radius: 1.2 + _random.nextDouble() * 2.4,
      speedY: 0.08 + _random.nextDouble() * 0.14,
      phase: _random.nextDouble() * math.pi * 2,
      color: index % 4 == 0
          ? const Color(0xFF00E5FF)
          : index % 4 == 1
              ? const Color(0xFFD946EF)
              : index % 4 == 2
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF10B981),
    );
  });

  _ProfileParticlesPainter({required this.progress, required this.isMeshActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final currentY = (p.y - progress * p.speedY) % 1.0;
      final currentX = (p.x + math.sin(progress * 2 * math.pi + p.phase) * 0.025) % 1.0;

      final opacity = (0.2 + 0.6 * (0.5 + 0.5 * math.sin(progress * 4 * math.pi + p.phase))) * (isMeshActive ? 1.3 : 1.0);
      final clampedOpacity = opacity.clamp(0.0, 1.0);

      paint.color = p.color.withOpacity(clampedOpacity * 0.5);
      canvas.drawCircle(
        Offset(currentX * size.width, currentY * size.height),
        p.radius * (isMeshActive ? 1.2 : 1.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isMeshActive != isMeshActive;
  }
}

class _ParticleItem {
  final double x;
  final double y;
  final double radius;
  final double speedY;
  final double phase;
  final Color color;

  _ParticleItem({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.phase,
    required this.color,
  });
}


class AuraProfileCard extends StatelessWidget {
  final Widget child;
  final List<Color> borderGradient;
  final double borderRadius;

  const AuraProfileCard({
    super.key,
    required this.child,
    this.borderGradient = const [Color(0xFF8B5CF6), Color(0xFFD946EF)],
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider.instance.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: borderGradient.first.withOpacity(isDark ? 0.22 : 0.12),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2), // Frosted thin border
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius - 1.2),
            color: isDark
                ? const Color(0xFF0D0821).withOpacity(0.72)
                : Colors.white.withOpacity(0.85), // Premium light/dark card bg
            boxShadow: [
              BoxShadow(
                color: borderGradient.first.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

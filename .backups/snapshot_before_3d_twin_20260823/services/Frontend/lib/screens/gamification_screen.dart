import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/wow_effects.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wow_effects.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Gamification screen — XP, level, streak, achievements, quests.
class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key, this.telegramId = 0});

  final int telegramId;

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _achievements = [];
  List<dynamic> _quests = [];
  List<dynamic> _weeklyChallenges = [];
  Map<String, dynamic>? _leaderboard;
  bool _loading = true;
  String _selectedTab = 'profile';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final baseUrl = MapConfig.backendApiBaseUrl;
      final profileResp = await http.get(
        Uri.parse('$baseUrl/gamification/profile/${widget.telegramId}'),
      ).timeout(const Duration(seconds: 10));
      if (profileResp.statusCode == 200) {
        _profile = json.decode(utf8.decode(profileResp.bodyBytes));
      }

      final achResp = await http.get(
        Uri.parse('$baseUrl/gamification/achievements?telegram_id=${widget.telegramId}'),
      ).timeout(const Duration(seconds: 10));
      if (achResp.statusCode == 200) {
        final data = json.decode(utf8.decode(achResp.bodyBytes));
        _achievements = data['achievements'] ?? [];
      }

      final prefs = await SharedPreferences.getInstance();
      final signalsToday = prefs.getInt('signals_today') ?? 0;
      final jkhChecks = prefs.getInt('jkh_checks') ?? 0;
      final camerasViewed = prefs.getInt('cameras_viewed') ?? 0;

      final questResp = await http.get(
        Uri.parse('$baseUrl/gamification/quests?telegram_id=${widget.telegramId}'),
      ).timeout(const Duration(seconds: 10));
      if (questResp.statusCode == 200) {
        final data = json.decode(utf8.decode(questResp.bodyBytes));
        _weeklyChallenges = data['quests'] ?? [];
      }

      _quests = [
        {
          'title': 'Подай 1 сигнал сегодня',
          'desc': 'Сделай город лучше',
          'progress': signalsToday,
          'target': 1,
          'completed': signalsToday >= 1,
          'reward_xp': 50,
        },
        {
          'title': 'Проверь статус ЖКХ дома',
          'desc': 'Будь в курсе отключений',
          'progress': jkhChecks,
          'target': 1,
          'completed': jkhChecks >= 1,
          'reward_xp': 20,
        },
        {
          'title': 'Посмотри 3 камеры города',
          'desc': 'Проверь обстановку на улицах',
          'progress': camerasViewed,
          'target': 3,
          'completed': camerasViewed >= 3,
          'reward_xp': 30,
        }
      ];

      final lbResp = await http.get(
        Uri.parse('$baseUrl/gamification/leaderboard?limit=20'),
      ).timeout(const Duration(seconds: 10));
      if (lbResp.statusCode == 200) {
        _leaderboard = json.decode(utf8.decode(lbResp.bodyBytes));
      }
    } catch (e) {
      debugPrint('Gamification load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_esports_rounded, color: PulseColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Геймификация', style: AppTextStyles.title.copyWith(fontSize: 22)),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAll),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: PulseColors.primary))
            : _profile == null
                ? _noProfileWidget()
                : Column(
                    children: [
                      if (widget.telegramId == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: PulseColors.primary.withOpacity(0.12),
                              borderRadius: AppRadii.sm,
                              border: Border.all(color: PulseColors.primary.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: PulseColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Демо-режим гостя. Привяжите Telegram для сохранения прогресса.',
                                    style: AppTextStyles.bodyMuted.copyWith(
                                      color: PulseColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // XP Level Bar
                      _xpLevelCard(),
                      // Tabs
                      _tabBar(),
                      // Content
                      Expanded(
                        child: IndexedStack(
                          index: _tabIndex,
                          children: [
                            _achievementsTab(),
                            _questsTab(),
                            _leaderboardTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  int get _tabIndex {
    switch (_selectedTab) {
      case 'achievements':
        return 0;
      case 'quests':
        return 1;
      case 'leaderboard':
        return 2;
      default:
        return 0;
    }
  }

  Widget _noProfileWidget() {
    return Center(
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports_rounded, size: 48, color: PulseColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Войди в систему', style: AppTextStyles.section),
            const SizedBox(height: AppSpacing.xs),
            Text('Привяжи Telegram ID в профиле', style: AppTextStyles.bodyMuted),
          ],
        ),
      ),
    );
  }

  Widget _xpLevelCard() {
    final p = _profile!;
    final level = p['level'] ?? 'Новичок';
    final icon = p['level_icon'] ?? '🌱';
    final xp = p['xp'] ?? 0;
    final progress = (p['progress'] ?? 0.0).toDouble();
    final nextLevel = p['next_level'] ?? '';
    final streak = p['streak'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppPanel(
        style: PanelStyle.neo,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar + Level + WOW Radar
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PulseRadarRadar(
                        radius: 32,
                        color: PulseColors.accentViolet,
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              PulseColors.accentViolet,
                              PulseColors.primary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: PulseColors.accentViolet.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level,
                        style: AppTextStyles.section.copyWith(
                          color: PulseColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$xp XP',
                        style: AppTextStyles.metric.copyWith(
                          fontSize: 20,
                          color: PulseColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: PulseColors.warning.withOpacity(0.15),
                      borderRadius: AppRadii.md,
                      border: Border.all(color: PulseColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 18, color: PulseColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '$streak',
                          style: AppTextStyles.mono.copyWith(
                            color: PulseColors.warning,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Progress bar
            ClipRRect(
              borderRadius: AppRadii.sm,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: PulseColors.surfaceSoft,
                valueColor: AlwaysStoppedAnimation<Color>(PulseColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ур. $level', style: AppTextStyles.bodyMuted),
                if (nextLevel.isNotEmpty)
                  Text('До: $nextLevel', style: AppTextStyles.bodyMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = <(String, IconData, String)>[
      ('achievements', Icons.emoji_events_rounded, 'Достижения'),
      ('quests', Icons.checklist_rounded, 'Квесты'),
      ('leaderboard', Icons.leaderboard_rounded, 'Топ'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: tabs.map((t) {
          final selected = _selectedTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = t.$1),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? PulseColors.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: AppRadii.sm,
                  border: Border.all(
                    color: selected ? PulseColors.primary : PulseColors.borderStrong,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      t.$2,
                      size: 18,
                      color: selected ? PulseColors.primary : PulseColors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.$3,
                      style: AppTextStyles.bodyMuted.copyWith(
                        color: selected ? PulseColors.primary : PulseColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _achievementsTab() {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _achievements.length,
        itemBuilder: (context, index) {
          final ach = _achievements[index];
          final unlocked = ach['unlocked'] ?? false;
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppPanel(
                    style: PanelStyle.standard,
                    borderColor: unlocked
                        ? PulseColors.success.withOpacity(0.3)
                        : PulseColors.borderStrong,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: unlocked
                                ? PulseColors.success.withOpacity(0.15)
                                : PulseColors.surfaceSoft,
                          ),
                          child: Center(
                            child: Text(
                              ach['icon'] ?? '❓',
                              style: TextStyle(
                                fontSize: 24,
                                color: unlocked ? null : PulseColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ach['title'] ?? '',
                                style: AppTextStyles.cardTitle.copyWith(
                                  color: unlocked ? PulseColors.textPrimary : PulseColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ach['desc'] ?? '',
                                style: AppTextStyles.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: unlocked
                                ? PulseColors.success.withOpacity(0.15)
                                : PulseColors.surfaceSoft,
                            borderRadius: AppRadii.sm,
                          ),
                          child: Text(
                            '+${ach['xp'] ?? 0}',
                            style: AppTextStyles.mono.copyWith(
                              color: unlocked ? PulseColors.success : PulseColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _questsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text(
          'ЕЖЕДНЕВНЫЕ ЗАДАНИЯ',
          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_quests.isEmpty)
          Center(child: Text('Нет квестов на сегодня', style: AppTextStyles.bodyMuted))
        else
          ..._quests.map((q) => _buildQuestCard(q)).toList(),
        
        const SizedBox(height: AppSpacing.lg),
        
        const Text(
          'НЕДЕЛЬНЫЕ ИСПЫТАНИЯ',
          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_weeklyChallenges.isEmpty)
          Center(child: Text('Нет испытаний на этой неделе', style: AppTextStyles.bodyMuted))
        else
          ..._weeklyChallenges.map((q) => _buildQuestCard(q)).toList(),
      ],
    );
  }

  Widget _buildQuestCard(dynamic q) {
    final progress = (q['progress'] ?? 0) as num;
    final target = (q['target'] ?? 1) as num;
    final completed = q['completed'] ?? false;
    final pct = target > 0 ? progress / target : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPanel(
        style: PanelStyle.standard,
        borderColor: completed
            ? PulseColors.success.withOpacity(0.3)
            : PulseColors.borderStrong,
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: pct.clamp(0.0, 1.0).toDouble()),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: value,
                        backgroundColor: PulseColors.surfaceSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completed ? PulseColors.success : PulseColors.accentViolet,
                        ),
                        strokeWidth: 4,
                      ),
                      Icon(
                        completed ? Icons.check_rounded : Icons.star_rounded,
                        color: completed ? PulseColors.success : PulseColors.accentViolet,
                        size: 20,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q['title'] ?? '',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: completed ? PulseColors.success : PulseColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(q['desc'] ?? '', style: AppTextStyles.bodyMuted),
                  const SizedBox(height: 6),
                  Text(
                    '$progress / $target',
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PulseColors.success.withOpacity(0.15),
                  borderRadius: AppRadii.sm,
                ),
                child: Text(
                  '✅ +${q['reward_xp'] ?? 0} XP',
                  style: AppTextStyles.mono.copyWith(
                    color: PulseColors.success,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _leaderboardTab() {
    final lb = _leaderboard?['leaderboard'] as List<dynamic>? ?? [];
    if (lb.isEmpty) {
      return Center(
        child: Text('Лидерборд пуст', style: AppTextStyles.bodyMuted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: lb.length,
      itemBuilder: (context, index) {
        final entry = lb[index];
        final rank = entry['rank'] as int;
        final isMe = entry['telegram_id'] == widget.telegramId;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: AppPanel(
            style: PanelStyle.standard,
            borderColor: isMe
                ? PulseColors.primary.withOpacity(0.4)
                : PulseColors.borderStrong,
            backgroundColor: isMe
                ? PulseColors.primary.withOpacity(0.05)
                : PulseColors.surfaceGlass,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rank <= 3
                        ? [PulseColors.accentGold, PulseColors.neutral, PulseColors.accentViolet][rank - 1].withOpacity(0.2)
                        : PulseColors.surfaceSoft,
                  ),
                  child: Center(
                    child: Text(
                      rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['level'] ?? '',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 14,
                          color: isMe ? PulseColors.primary : PulseColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${entry['level_icon'] ?? '🌱'} ${entry['xp'] ?? 0} XP',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';

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
  Map<String, dynamic>? _leaderboard;
  bool _loading = true;
  String _selectedTab = 'profile';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (widget.telegramId == 0) {
      setState(() => _loading = false);
      return;
    }
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

      final questResp = await http.get(
        Uri.parse('$baseUrl/gamification/quests?telegram_id=${widget.telegramId}'),
      ).timeout(const Duration(seconds: 10));
      if (questResp.statusCode == 200) {
        final data = json.decode(utf8.decode(questResp.bodyBytes));
        _quests = data['quests'] ?? [];
      }

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
          title: Text('🎮 Геймификация', style: AppTextStyles.title.copyWith(fontSize: 22)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAll),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: PulseColors.primary))
            : _profile == null
                ? _noProfileWidget()
                : Column(
                    children: [
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
            Text('🎮', style: TextStyle(fontSize: 48)),
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
                // Avatar + Level
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        PulseColors.accentViolet,
                        PulseColors.primary,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 28),
                    ),
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
                        const Text('🔥', style: TextStyle(fontSize: 18)),
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
    final tabs = [
      ('achievements', '🏆', 'Достижения'),
      ('quests', '📋', 'Квесты'),
      ('leaderboard', '👑', 'Топ'),
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
                    Text(t.$2, style: const TextStyle(fontSize: 18)),
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
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final ach = _achievements[index];
        final unlocked = ach['unlocked'] ?? false;
        return Padding(
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
        );
      },
    );
  }

  Widget _questsTab() {
    if (_quests.isEmpty) {
      return Center(
        child: Text('Нет квестов на этой неделе', style: AppTextStyles.bodyMuted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _quests.length,
      itemBuilder: (context, index) {
        final q = _quests[index];
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('📋', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        q['title'] ?? '',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: completed ? PulseColors.success : PulseColors.textPrimary,
                        ),
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
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(q['desc'] ?? '', style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadii.sm,
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: PulseColors.surfaceSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completed ? PulseColors.success : PulseColors.accentViolet,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$progress / $target',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
        );
      },
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';

/// AI Meme Generator — generates city memes and shares them.
class MemeScreen extends StatefulWidget {
  const MemeScreen({super.key, this.telegramId = 0});
  final int telegramId;

  @override
  State<MemeScreen> createState() => _MemeScreenState();
}

class _MemeScreenState extends State<MemeScreen> {
  Map<String, dynamic>? _currentMeme;
  List<dynamic> _memes = [];
  bool _loading = false;
  final List<String> _categories = ['random', 'Дороги', 'ЖКХ', 'Экология', 'Транспорт'];
  String _selectedCategory = 'random';

  @override
  void initState() {
    super.initState();
    _loadMemes();
  }

  Future<void> _loadMemes() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(
        Uri.parse('${MapConfig.backendApiBaseUrl}/gamification/memes?limit=20'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        _memes = data['memes'] ?? [];
      }
    } catch (e) {
      debugPrint('Meme load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generateMeme() async {
    if (widget.telegramId == 0) return;
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('${MapConfig.backendApiBaseUrl}/gamification/memes/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'telegram_id': widget.telegramId,
          'category': _selectedCategory,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _currentMeme = json.decode(utf8.decode(resp.bodyBytes));
        // Show confetti / celebration
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('😂 Мем создан! +25 XP'),
              backgroundColor: PulseColors.accentGold,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadMemes();
      }
    } catch (e) {
      debugPrint('Meme generate error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка генерации мема')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shareMeme(Map<String, dynamic> meme) {
    final text = meme['share_text'] ?? meme['caption'] ?? '';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('😂 Городские мемы', style: AppTextStyles.title.copyWith(fontSize: 20)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadMemes),
          ],
        ),
        body: Column(
          children: [
            // Generate button + category picker
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppPanel(
                style: PanelStyle.neo,
                child: Column(
                  children: [
                    Text('🎨 Генератор мемов', style: AppTextStyles.section),
                    const SizedBox(height: AppSpacing.sm),
                    // Category chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final selected = cat == _selectedCategory;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? PulseColors.primary.withOpacity(0.15)
                                  : PulseColors.surfaceSoft,
                              borderRadius: AppRadii.pill,
                              border: Border.all(
                                color: selected ? PulseColors.primary : PulseColors.borderStrong,
                              ),
                            ),
                            child: Text(
                              cat == 'random' ? '🎲 Рандом' : cat,
                              style: AppTextStyles.body.copyWith(
                                color: selected ? PulseColors.primary : PulseColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Generate button
                    AppPrimaryButton(
                      label: _loading ? 'Генерация...' : '🎲 Сгенерировать мем',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _loading ? null : _generateMeme,
                    ),
                  ],
                ),
              ),
            ),

            // Current meme
            if (_currentMeme != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _memeCard(_currentMeme!, isCurrent: true),
              ),

            // Meme feed
            Expanded(
              child: _memes.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        'Нажми "Сгенерировать" чтобы создать первый мем! 🎨',
                        style: AppTextStyles.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _memes.length,
                      itemBuilder: (context, index) {
                        final meme = _memes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _memeCard(meme, isCurrent: false),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memeCard(Map<String, dynamic> meme, {required bool isCurrent}) {
    final caption = meme['caption'] ?? meme['share_text'] ?? '';
    final category = meme['category'] ?? '';

    return AppPanel(
      style: isCurrent ? PanelStyle.neo : PanelStyle.standard,
      borderColor: isCurrent ? PulseColors.accentGold.withOpacity(0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meme visual (text-based for now, can add image later)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PulseColors.accentViolet.withOpacity(0.1),
                  PulseColors.primary.withOpacity(0.05),
                  PulseColors.warning.withOpacity(0.05),
                ],
              ),
              borderRadius: AppRadii.sm,
              border: Border.all(color: PulseColors.borderStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PulseColors.accentViolet.withOpacity(0.15),
                      borderRadius: AppRadii.sm,
                    ),
                    child: Text(
                      category,
                      style: AppTextStyles.mono.copyWith(
                        color: PulseColors.accentViolet,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                // Meme text
                Text(
                  caption,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareMeme(meme),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Поделиться'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PulseColors.primary,
                    side: BorderSide(color: PulseColors.primary.withOpacity(0.3)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('😂 Мем скопирован!'),
                      backgroundColor: PulseColors.accentGold,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PulseColors.accentGold.withOpacity(0.1),
                    borderRadius: AppRadii.sm,
                    border: Border.all(color: PulseColors.accentGold.withOpacity(0.3)),
                  ),
                  child: const Text('😂', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

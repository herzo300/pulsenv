import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _showLottieRewardOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PulseColors.accentGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: PulseColors.accentGold.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 180,
                child: Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_lk8omw77.json',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Lottie.asset('assets/animations/pulse.json', height: 120);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Мем создан!',
                style: AppTextStyles.title.copyWith(fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: PulseColors.accentGold, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    '+25 XP',
                    style: TextStyle(
                      color: PulseColors.accentGold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Вы заработали баллы в рейтинг района!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseColors.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отлично!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
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
        if (mounted) {
          _showLottieRewardOverlay();
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
    final imageUrl = meme['image_url'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: PulseColors.accentGold.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Поделиться в соцсетях',
              style: AppTextStyles.title.copyWith(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(
                  icon: Icons.telegram_rounded,
                  label: 'Telegram',
                  color: const Color(0xFF229ED9),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = 'https://t.me/share/url?url=${Uri.encodeComponent(imageUrl)}&text=${Uri.encodeComponent(text)}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _shareOption(
                  icon: Icons.alternate_email_rounded,
                  label: 'ВКонтакте',
                  color: const Color(0xFF4C75A3),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final shareText = '$text\n$imageUrl';
                    final url = 'https://vk.com/share.php?title=${Uri.encodeComponent(shareText)}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _shareOption(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent('$text\n$imageUrl')}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
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

import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/aura_living_background.dart';
import '../../../core/living/aura_living_engine.dart';
import 'pulse_app_badge.dart';
import 'pulse_ui_icons.dart';
import '../../../widgets/city_pulse_wave.dart';

import '../../profile_screen.dart';
import '../../uk_companies_screen.dart';
import '../../mesh_screen.dart';
import '../../settings_screen.dart';
import '../../about_screen.dart';
import '../../lost_and_found_screen.dart';
import '../../meme_screen.dart';
import '../../infographic_screen.dart';
import '../../city_panorama_screen.dart';
import '../../ar_markers_screen.dart';
import '../../gamification_screen.dart';
import '../../ai_digest_screen.dart';
import '../../ai_assistant_screen.dart';

typedef MapMenuVoidCallback = VoidCallback;

class MapMenuSheet extends StatelessWidget {
  const MapMenuSheet({
    super.key,
    required this.isNightMode,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiAccent,
    required this.uiGlow,
    required this.onClose,
    required this.onOpenProfile,
    required this.onOpenUk,
    required this.onOpenMesh,
    required this.onOpenSettings,
    required this.onToggleTheme,
    required this.onOpenAbout,
    required this.onOpenPrivacy,
    required this.onOpenLegal,
    required this.onOpenSecretCameras,
    required this.showSecretCameras,
    required this.secretCamerasSubtitle,
    required this.meshConnected,
    required this.totalComplaints,
    required this.activeCamerasCount,
    this.onOpenAiDigest,
    this.onOpenAiAssistant,
    this.onOpenMemes,
    this.onOpenLostFound,
    this.onOpenInfographics,
    this.onOpenPanorama,
    this.onOpenAr,
    this.onOpenGamification,
  });

  final bool isNightMode;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiAccent;
  final Color uiGlow;
  final MapMenuVoidCallback onClose;
  final MapMenuVoidCallback onOpenProfile;
  final MapMenuVoidCallback onOpenUk;
  final MapMenuVoidCallback onOpenMesh;
  final MapMenuVoidCallback onOpenSettings;
  final MapMenuVoidCallback onToggleTheme;
  final MapMenuVoidCallback onOpenAbout;
  final MapMenuVoidCallback onOpenPrivacy;
  final MapMenuVoidCallback onOpenLegal;
  final MapMenuVoidCallback onOpenSecretCameras;
  final bool showSecretCameras;
  final String secretCamerasSubtitle;
  final bool meshConnected;
  final int totalComplaints;
  final int activeCamerasCount;
  final MapMenuVoidCallback? onOpenAiDigest;
  final MapMenuVoidCallback? onOpenAiAssistant;
  final MapMenuVoidCallback? onOpenMemes;
  final MapMenuVoidCallback? onOpenLostFound;
  final MapMenuVoidCallback? onOpenInfographics;
  final MapMenuVoidCallback? onOpenPanorama;
  final MapMenuVoidCallback? onOpenAr;
  final MapMenuVoidCallback? onOpenGamification;

  static Future<void> show({
    required BuildContext context,
    required MapMenuSheet sheet,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bright = !isNightMode;
    final border = uiGlow.withOpacity(bright ? 0.2 : 0.34);

    final scene = AuraLivingEngine.resolve(
      mood: 0,
      streak: 5,
      meditationMinutes: 10,
      practicesCompleted: 5,
      isPremium: true,
      hour: DateTime.now().hour,
    ).copyWith(
      weather: AuraWeather.water,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Stack(
          children: [
            // AuraLivingBackground using same water engine as the flood card
            Positioned.fill(
              child: AuraLivingBackground(
                scene: scene,
                interactive: true,
                showConstellationVeil: false,
                child: const SizedBox(),
              ),
            ),
            // Semi-transparent overlay to ensure light/dark text readability
            Positioned.fill(
              child: Container(
                color: bright 
                    ? Colors.white.withOpacity(0.24) 
                    : const Color(0xFF0A101C).withOpacity(0.32),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: border, width: 1.2),
                  left: BorderSide(color: border),
                  right: BorderSide(color: border),
                ),
              ),
              child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onToggleTheme();
                          },
                          child: PulseAppBadge(
                            isNightMode: isNightMode,
                            accent: uiAccent,
                            textPrimary: uiTextPrimary,
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Animated pulse wave in side menu
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: CityPulseWave(
                              totalCount: totalComplaints,
                              categoryCounts: const {},
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onToggleTheme,
                          icon: Icon(
                            isNightMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: uiAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            color: uiTextSecondary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isNightMode
                          ? const Color(0xFF0F172A).withAlpha(180)
                          : Colors.white.withAlpha(220),
                      border: Border.all(
                        color: uiGlow.withAlpha(isNightMode ? 100 : 50),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: uiGlow.withAlpha(isNightMode ? 30 : 10),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.favorite_rounded,
                          value: 'ЖИВОЙ',
                          label: 'Пульс города',
                          color: const Color(0xFFEF4444),
                          pulsing: true,
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          icon: Icons.warning_amber_rounded,
                          value: totalComplaints.toString(),
                          label: 'Сигналов',
                          color: uiAccent,
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          icon: Icons.videocam_rounded,
                          value: activeCamerasCount.toString(),
                          label: 'Камер онлайн',
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle('Сервисы и разделы'),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final List<Widget> gridItems = [
                        _menuTile(
                          label: 'УК города',
                          subtitle: '42 компании',
                          kind: PulseUiIconKind.uk,
                          color: PulseColors.accentViolet,
                          onTap: onOpenUk,
                        ),
                        _menuTile(
                          label: 'Mesh-сеть',
                          subtitle: meshConnected ? 'Подключена' : 'Оффлайн-связь',
                          kind: PulseUiIconKind.mesh,
                          color: meshConnected ? PulseColors.success : PulseColors.warning,
                          onTap: onOpenMesh,
                        ),
                        _menuTile(
                          label: 'Профиль',
                          subtitle: 'Мои обращения',
                          kind: PulseUiIconKind.profile,
                          color: PulseColors.primary,
                          onTap: onOpenProfile,
                        ),
                        _menuTile(
                          label: 'Настройки',
                          subtitle: 'Звуки и пуши',
                          kind: PulseUiIconKind.settings,
                          color: PulseColors.neutral,
                          onTap: onOpenSettings,
                        ),
                        if (showSecretCameras)
                          _menuTile(
                            label: 'Скрытые камеры',
                            subtitle: secretCamerasSubtitle,
                            kind: PulseUiIconKind.secret,
                            color: PulseColors.negative,
                            onTap: onOpenSecretCameras,
                          ),
                        _menuTile(
                          label: 'О проекте',
                          subtitle: 'Инфо и помощь',
                          kind: PulseUiIconKind.about,
                          color: uiAccent,
                          onTap: onOpenAbout,
                        ),
                      ];

                      final bool isEven = gridItems.length % 2 == 0;
                      if (isEven) {
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.0,
                          children: gridItems.asMap().entries.map((e) {
                            return e.value.animate()
                              .fade(duration: 300.ms, delay: (30 * e.key).ms)
                              .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
                          }).toList(),
                        );
                      } else {
                        final topFour = gridItems.sublist(0, 4);
                        final lastItem = gridItems.last;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 3.0,
                              children: topFour.asMap().entries.map((e) {
                                return e.value.animate()
                                  .fade(duration: 300.ms, delay: (30 * e.key).ms)
                                  .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 60,
                              child: lastItem.animate()
                                .fade(duration: 300.ms, delay: 120.ms)
                                .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: uiTextSecondary.withOpacity(0.28),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: uiTextSecondary.withOpacity(0.75),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _menuTile({
    required String label,
    required String subtitle,
    required PulseUiIconKind kind,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _MenuTile(
      label: label,
      subtitle: subtitle,
      kind: kind,
      color: color,
      onTap: onTap,
      isNightMode: isNightMode,
      uiTextPrimary: uiTextPrimary,
      uiTextSecondary: uiTextSecondary,
    );
  }

  Widget _menuTileWithToggle({
    required String label,
    required String subtitle,
    required IconData customIcon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _MenuTile(
      label: label,
      subtitle: subtitle,
      customIcon: customIcon,
      color: color,
      onTap: onTap,
      isNightMode: isNightMode,
      uiTextPrimary: uiTextPrimary,
      uiTextSecondary: uiTextSecondary,
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: uiTextSecondary.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: uiTextPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: isNightMode ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool pulsing = false,
  }) {
    final textStyle = TextStyle(
      color: isNightMode ? Colors.white : Colors.black87,
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: pulsing ? 0.8 : 0.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulsing)
              _PulseIcon(icon: icon, color: color)
            else
              Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(value, style: textStyle),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isNightMode ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulseIcon({required this.icon, required this.color});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, color: widget.color, size: 16),
    );
  }
}

class _MenuTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final PulseUiIconKind? kind;
  final IconData? customIcon;
  final Color color;
  final VoidCallback onTap;
  final bool isNightMode;
  final Color uiTextPrimary;
  final Color uiTextSecondary;

  const _MenuTile({
    required this.label,
    required this.subtitle,
    this.kind,
    this.customIcon,
    required this.color,
    required this.onTap,
    required this.isNightMode,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleController.reverse();
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final isNightMode = widget.isNightMode;
    
    // Premium HSL-based gradient colors for the icon glow and border
    final hsl = HSLColor.fromColor(color);
    final gradientStart = hsl.withLightness(isNightMode ? 0.22 : 0.45).toColor();
    final gradientEnd = hsl.withLightness(isNightMode ? 0.12 : 0.35).toColor();
    
    // Localized text colors to ensure perfect readability in both light/dark mode
    final textPrimaryColor = isNightMode ? widget.uiTextPrimary : const Color(0xFF0A2540);
    final textSecondaryColor = isNightMode ? widget.uiTextSecondary : const Color(0xFF486581);
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Premium glass fill — translucent with surface tint and HSL gradient
                color: isNightMode
                    ? PulseColors.surfaceSoft.withOpacity(0.32)
                    : Colors.white.withOpacity(0.68),
                border: Border.all(
                  color: isNightMode
                      ? color.withOpacity(0.12)
                      : color.withOpacity(0.24),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isNightMode
                      ? [
                          color.withOpacity(0.06),
                          Colors.transparent,
                        ]
                      : [
                          color.withOpacity(0.04),
                          Colors.transparent,
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isNightMode ? 0.22 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  // Subtle colored shadow to match card theme
                  BoxShadow(
                    color: color.withOpacity(isNightMode ? 0.04 : 0.02),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left Glowing Accent Bar
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gradientStart, gradientEnd],
                      ),
                      border: Border.all(
                        color: color.withOpacity(isNightMode ? 0.34 : 0.4),
                        width: 0.8,
                      ),
                      boxShadow: [
                        // Glow effect drop shadow for premium depth
                        BoxShadow(
                          color: color.withOpacity(isNightMode ? 0.38 : 0.26),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: (widget.customIcon != null
                          ? Icon(
                              widget.customIcon,
                              size: 19,
                              color: Colors.white,
                            )
                          : PulseUiIcon(
                              kind: widget.kind ?? PulseUiIconKind.settings,
                              size: 17,
                              color: Colors.white,
                            ))
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            delay: 400.ms,
                            duration: 1800.ms,
                            begin: const Offset(1, 1),
                            end: const Offset(1.08, 1.08),
                            curve: Curves.easeInOut,
                          )
                          .shimmer(
                            delay: 800.ms,
                            duration: 1600.ms,
                            color: Colors.white24,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondaryColor.withOpacity(0.8),
                            fontSize: 9.0,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: textSecondaryColor.withOpacity(0.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuBackdropPainter extends CustomPainter {
  const _MenuBackdropPainter({required this.isNightMode});
  final bool isNightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = isNightMode ? 0.08 : 0.04;
    
    // Top-left Violet Glow
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B5CF6).withOpacity(opacity),
          const Color(0xFF8B5CF6).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(0, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(0, 0), size.width * 0.8, paint1);

    // Bottom-right Teal Glow
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0EA5E9).withOpacity(opacity),
          const Color(0xFF0EA5E9).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width, size.height * 0.8), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, size.height * 0.8), size.width * 0.8, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulseWaveformWidget extends StatefulWidget {
  const _PulseWaveformWidget({required this.color});
  final Color color;

  @override
  State<_PulseWaveformWidget> createState() => _PulseWaveformWidgetState();
}

class _PulseWaveformWidgetState extends State<_PulseWaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
      builder: (context, _) {
        return CustomPaint(
          painter: _PulseWaveformPainter(
            animationValue: _controller.value,
            color: widget.color,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PulseWaveformPainter extends CustomPainter {
  _PulseWaveformPainter({
    required this.animationValue,
    required this.color,
  });

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double midY = size.height / 2;
    final double width = size.width;

    path.moveTo(0, midY);

    for (double x = 0; x <= width; x += 1) {
      // Shift horizontal wave based on animation progress
      final double normalizedX = x / width;
      final double shiftedX = normalizedX - animationValue;
      
      double y = midY;
      
      // Simulate ECG pattern: mostly flat, with repeating P-Q-R-S-T peaks
      final double phase = (shiftedX * 3) % 1.0; // 3 cardiac cycles across screen
      
      if (phase > 0.3 && phase < 0.35) {
        // P Wave
        y -= math.sin((phase - 0.3) / 0.05 * math.pi) * 3;
      } else if (phase >= 0.35 && phase < 0.37) {
        // Q Wave
        y += ((phase - 0.35) / 0.02) * 4;
      } else if (phase >= 0.37 && phase < 0.42) {
        // R Wave (tall spike)
        final double t = (phase - 0.37) / 0.05;
        if (t < 0.5) {
          y -= (t / 0.5) * 16;
        } else {
          y -= (1 - (t - 0.5) / 0.5) * 16;
        }
      } else if (phase >= 0.42 && phase < 0.44) {
        // S Wave
        y += ((phase - 0.42) / 0.02) * 5;
      } else if (phase >= 0.44 && phase < 0.52) {
        // T Wave
        y -= math.sin((phase - 0.44) / 0.08 * math.pi) * 5;
      }
      
      path.lineTo(x, y);
    }

    // Apply neon glow blur
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

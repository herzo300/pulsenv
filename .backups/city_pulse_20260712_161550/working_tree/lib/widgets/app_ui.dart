import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/pulse_colors.dart';
import 'aura_shader_background.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadii {
  static const double smR = 12;
  static const double mdR = 18;
  static const double lgR = 24;
  static const double pillR = 999;
  static const BorderRadius sm = BorderRadius.all(Radius.circular(smR));
  static const BorderRadius md = BorderRadius.all(Radius.circular(mdR));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(lgR));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillR));
}

/// Unified app breakpoints for responsive design.
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isPhone(double width) => width < phone;
  static bool isTablet(double width) => width >= phone && width < tablet;
  static bool isDesktop(double width) => width >= tablet;

  static double responsivePadding(BuildContext context,
      {double phone = 12, double tablet = 20, double desktop = 24}) {
    final width = MediaQuery.sizeOf(context).width;
    if (isPhone(width)) return phone;
    if (isTablet(width)) return tablet;
    return desktop;
  }

  static double responsiveFontSize(BuildContext context,
      {double phone = 14, double tablet = 15, double desktop = 16}) {
    final width = MediaQuery.sizeOf(context).width;
    if (isPhone(width)) return phone;
    if (isTablet(width)) return tablet;
    return desktop;
  }
}

/// Responsive wrapper: returns different widgets based on screen width.
class AppResponsive extends StatelessWidget {
  const AppResponsive({
    super.key,
    required this.builder,
  });

  final Widget Function(
          BuildContext context, bool isPhone, bool isTablet, bool isDesktop)
      builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = MediaQuery.sizeOf(ctx).width;
        return builder(
          context,
          AppBreakpoints.isPhone(width),
          AppBreakpoints.isTablet(width),
          AppBreakpoints.isDesktop(width),
        );
      },
    );
  }
}

abstract final class AppTextStyles {
  static TextStyle get overline => GoogleFonts.ibmPlexSans(
    color: PulseColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    height: 1.1,
  );

  static TextStyle get title => GoogleFonts.exo2(
    color: PulseColors.textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.02,
    letterSpacing: -0.72,
  );

  static TextStyle get section => GoogleFonts.exo2(
    color: PulseColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -0.2,
  );

  static TextStyle get cardTitle => GoogleFonts.exo2(
    color: PulseColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  static TextStyle get body => GoogleFonts.manrope(
    color: PulseColors.textPrimary,
    fontSize: 14,
    height: 1.48,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get bodyMuted => GoogleFonts.manrope(
    color: PulseColors.textSecondary,
    fontSize: 13,
    height: 1.46,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get metric => GoogleFonts.exo2(
    color: PulseColors.textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 0.98,
    letterSpacing: -0.8,
  );

  static TextStyle get button => GoogleFonts.manrope(
    color: PulseColors.background,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: 0.1,
  );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    color: PulseColors.textTertiary,
    fontSize: 13,
  );

  static TextStyle get caption => GoogleFonts.manrope(
    color: PulseColors.textTertiary,
    fontSize: 12,
  );

  /// Hero/large title style (replaces Orbitron in infographic)
  static TextStyle get hero => GoogleFonts.exo2(
    color: PulseColors.textPrimary,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    height: 0.95,
    letterSpacing: -1.2,
  );

  /// Subtitle style (replaces Inter in infographic)
  static TextStyle get subtitle => GoogleFonts.manrope(
    color: PulseColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

class AppScreenBackground extends StatelessWidget {
  AppScreenBackground({
    super.key,
    required this.child,
    this.accent,
  });

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return AuraShaderBackground(
      pulseIndex: 0.5,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _overlayColors(context),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  List<Color> _bgColors(BuildContext context) {
    final bright = Theme.of(context).brightness == Brightness.light;
    if (bright) {
      return const [
        Color(0xFFF5FAFF),
        Color(0xFFE8F2FB),
        Color(0xFFF5FAFF),
      ];
    }
    return [
      PulseColors.background,
      PulseColors.backgroundRaised,
      PulseColors.background,
    ];
  }

  List<Color> _overlayColors(BuildContext context) {
    final bright = Theme.of(context).brightness == Brightness.light;
    if (bright) {
      return [
        Colors.black.withOpacity(0.02),
        Colors.transparent,
        Colors.white.withOpacity(0.3),
      ];
    }
    return [
      Colors.white.withOpacity(0.02),
      Colors.transparent,
      Colors.black.withOpacity(0.16),
    ];
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// Unified glass-morphism panel — replaces AppPanel, NeoGlassPanel,
/// and GlassPanel with a single parameterised widget.
///
/// Style variants:
///   • standard  — classic backdrop blur (AppPanel)
///   • neo       — gradient border + deep shadow (NeoGlassPanel)
///   • aurora    — aurora glow + inner gradient (GlassPanel)
/// ────────────────────────────────────────────────────────────────
class AppPanel extends StatelessWidget {
  AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.backgroundColor,
    this.borderRadius,
    this.blurSigma = 22,
    this.style = PanelStyle.standard,
    this.accent,
    this.showAuroraGlow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final PanelStyle style;
  final Color? accent;
  final bool showAuroraGlow;

  BorderRadius get _radius => borderRadius ?? AppRadii.md;
  Color get _bg => backgroundColor ?? PulseColors.surfaceGlass;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      PanelStyle.standard => _buildStandard(context),
      PanelStyle.neo => _buildNeo(context),
      PanelStyle.aurora => _buildAurora(context),
    };
  }

  /// Classic glass panel — blur + translucent background + border
  Widget _buildStandard(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: _radius,
            border: Border.all(
              color: borderColor ?? PulseColors.borderStrong,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Neo glass — gradient border trick, deeper shadow
  Widget _buildNeo(BuildContext context) {
    final colors = borderColor != null
        ? [borderColor!, borderColor!.withOpacity(0.4), Colors.transparent]
        : [
            const Color(0xFF00E5FF).withAlpha(200),
            const Color(0x6600E5FF),
            Colors.transparent,
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: _radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: _radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: _radius,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// Aurora glass — aurora glow + inner gradient painter
  Widget _buildAurora(BuildContext context) {
    final radius = borderRadius ?? AppRadii.lg;
    final accentColor = accent ?? PulseColors.primary;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PulseColors.textPrimary.withOpacity(0.085),
                const Color(0xFF111A2B).withOpacity(0.78),
              ],
            ),
            border: Border.all(color: accentColor.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.46),
                blurRadius: 28,
                offset: const Offset(10, 16),
              ),
              BoxShadow(
                color: PulseColors.textPrimary.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(-8, -8),
              ),
              BoxShadow(
                color: accentColor.withOpacity(0.12),
                blurRadius: 30,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: [
              if (showAuroraGlow)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: RadialGradient(
                          center: const Alignment(-0.85, -0.9),
                          radius: 1.3,
                          colors: [
                            PulseColors.textPrimary.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InnerGlowPainter(accentColor, radius),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

enum PanelStyle { standard, neo, aurora }

class _InnerGlowPainter extends CustomPainter {
  const _InnerGlowPainter(this.accent, this.radius);
  final Color accent;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.22),
          Colors.transparent,
          PulseColors.textPrimary.withOpacity(0.05),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.deflate(0.8), const Radius.circular(AppRadii.lgR)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InnerGlowPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow.toUpperCase(), style: AppTextStyles.overline),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: AppTextStyles.title),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle!, style: AppTextStyles.bodyMuted),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  AppStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? PulseColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.12),
        borderRadius: AppRadii.pill,
        border: Border.all(color: activeColor.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: activeColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.accent,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final activeAccent = accent ?? PulseColors.primary;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: activeAccent.withOpacity(0.18),
      backgroundColor: PulseColors.surfaceSoft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.xs),
                Text(value,
                    style: AppTextStyles.metric.copyWith(color: activeAccent)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: PulseColors.primary,
          foregroundColor: PulseColors.background,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
        ),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: PulseColors.textPrimary,
          side: BorderSide(color: PulseColors.primary.withOpacity(0.24)),
          backgroundColor: PulseColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          textStyle: AppTextStyles.button.copyWith(
            color: PulseColors.textPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
        ),
      ),
    );
  }
}

class AppHintButton extends StatelessWidget {
  AppHintButton({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? PulseColors.primary;
    return IconButton(
      tooltip: title,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: PulseColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.md,
            side: BorderSide(color: activeColor.withOpacity(0.18)),
          ),
          title: Text(title, style: AppTextStyles.section),
          content: Text(message, style: AppTextStyles.bodyMuted),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      icon: Icon(icon, size: 20, color: color),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PulseColors.primarySoft, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTextStyles.bodyMuted),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

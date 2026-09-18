import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/city_config.dart';
import '../../../widgets/city_pulse_wave.dart';
import '../../../services/city_provider.dart';
import 'city_selector_chip.dart';
import 'map_glass_panel.dart';
import 'pulse_app_badge.dart';
import 'pulse_ui_icons.dart';
/// Compact top bar: brand badge + layer pills + quick actions.
class MapTopBar extends StatelessWidget {
  final bool isNightMode;
  final int totalComplaints;
  final Map<String, int> categoryCounts;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiPanelFill;
  final Color uiGlow;
  final Color uiAccent;
  final bool showProblems;
  final bool showEvents;
  final bool showCameras;
  final bool isSatellite;
  final VoidCallback onToggleProblems;
  final VoidCallback onToggleEvents;
  final VoidCallback onToggleCameras;
  final VoidCallback onToggleMapStyle;
  final bool showLostFound;
  final VoidCallback onToggleLostFound;
  final VoidCallback? onToggleTheme;
  final VoidCallback onMapMenuSheet;
  final ValueChanged<CityConfig>? onCityChanged;

  const MapTopBar({
    super.key,
    required this.isNightMode,
    required this.totalComplaints,
    required this.categoryCounts,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiPanelFill,
    required this.uiGlow,
    required this.uiAccent,
    required this.showProblems,
    required this.showEvents,
    required this.showCameras,
    required this.isSatellite,
    required this.onToggleProblems,
    required this.onToggleEvents,
    required this.onToggleCameras,
    required this.onToggleMapStyle,
    required this.onMapMenuSheet,
    required this.showLostFound,
    required this.onToggleLostFound,
    this.onToggleTheme,
    this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MapGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      fillColor: uiPanelFill,
      blurSigma: 22,
      borderColors: [
        uiGlow.withAlpha(isNightMode ? 130 : 48),
        Colors.transparent,
      ],
      child: Stack(
        children: [
          Positioned(
            bottom: -4,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: isNightMode ? 0.45 : 0.1,
              child: CityPulseWave(
                totalCount: totalComplaints,
                categoryCounts: categoryCounts,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                PopupMenuButton<CityConfig>(
                  onSelected: (city) {
                    HapticFeedback.selectionClick();
                    onCityChanged?.call(city);
                  },
                  offset: const Offset(0, 36),
                  color: uiPanelFill.withOpacity(0.95),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (context) => CityConfig.all.map((city) {
                    final isActive = city.id == CityProvider().activeCity.id;
                    return PopupMenuItem<CityConfig>(
                      value: city,
                      height: 38,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(city.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            city.name,
                            style: TextStyle(
                              color: isActive ? uiAccent : uiTextPrimary.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_rounded, color: uiAccent, size: 14),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: uiAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onToggleTheme?.call();
                        },
                        child: AnimatedBuilder(
                          animation: CityProvider(),
                          builder: (context, _) => PulseAppBadge(
                            isNightMode: isNightMode,
                            accent: uiAccent,
                            textPrimary: uiTextPrimary,
                            cityName: CityProvider().activeCity.name,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _layerPill(
                          kind: PulseUiIconKind.mapLayers,
                          active: isSatellite,
                          onPressed: onToggleMapStyle,
                          label: 'Слой карты: спутник или схема',
                        ),
                        _layerPill(
                          kind: PulseUiIconKind.cameras,
                          active: showCameras,
                          onPressed: onToggleCameras,
                          label: 'Слой камер',
                        ),
                        _layerPill(
                          kind: PulseUiIconKind.events,
                          active: showEvents,
                          onPressed: onToggleEvents,
                          label: 'Слой мероприятий',
                        ),
                        _layerPill(
                          kind: PulseUiIconKind.signals,
                          active: showProblems,
                          onPressed: onToggleProblems,
                          label: 'Слой сигналов и проблем',
                        ),
                        _layerPill(
                          icon: Icons.pets_rounded,
                          active: showLostFound,
                          onPressed: onToggleLostFound,
                          label: 'Слой «Найдено и потеряно»',
                        ),

                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onMapMenuSheet();
                  },
                  child: Semantics(
                    label: 'Меню',
                    button: true,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: uiTextSecondary.withAlpha(isNightMode ? 16 : 10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: uiTextSecondary.withAlpha(28),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_rounded,
                          size: 18,
                          color: uiTextSecondary.withAlpha(200),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerPill({
    PulseUiIconKind? kind,
    IconData? icon,
    required bool active,
    required VoidCallback onPressed,
    String? label,
  }) {
    final color = active ? uiAccent : uiTextSecondary.withAlpha(140);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        label: label,
        button: true,
        toggled: active,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? uiAccent.withAlpha(isNightMode ? 28 : 18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? uiAccent.withAlpha(isNightMode ? 120 : 80)
                    : uiTextSecondary.withAlpha(30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind != null)
                  PulseUiIcon(kind: kind, size: 16, color: color)
                else if (icon != null)
                  Icon(icon, size: 16, color: color),
                if (active) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: uiAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: uiAccent.withAlpha(160),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _iconChip({
    PulseUiIconKind? kind,
    IconData? icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool highlighted = false,
  }) {
    final color = highlighted ? uiAccent : uiTextSecondary.withAlpha(200);
    return IconButton(
      tooltip: tooltip,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      splashRadius: 18,
      onPressed: onPressed,
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: highlighted
              ? uiAccent.withAlpha(isNightMode ? 24 : 16)
              : uiTextSecondary.withAlpha(isNightMode ? 16 : 10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted
                ? uiAccent.withAlpha(90)
                : uiTextSecondary.withAlpha(28),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 16, color: color)
              : PulseUiIcon(kind: kind!, size: 16, color: color),
        ),
      ),
    );
  }
}

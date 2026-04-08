import 'package:flutter/material.dart';

import '../../../widgets/city_pulse_wave.dart';
import 'map_glass_panel.dart';

/// Top bar widget displaying live stats and header for the map screen.
class MapTopBar extends StatelessWidget {
  final bool isNightMode;
  final int totalComplaints;
  final Map<String, int> categoryCounts;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiPanelFill;
  final Color uiGlow;
  final Color uiAccent;
  final VoidCallback onUkDialog;
  final VoidCallback onUkToggleLayer;
  final bool isUkLayerActive;
  final VoidCallback onMapMenuSheet;
  final VoidCallback? onSecretCameraTap;

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
    required this.onUkDialog,
    required this.onUkToggleLayer,
    required this.isUkLayerActive,
    required this.onMapMenuSheet,
    this.onSecretCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return MapGlassPanel(
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      fillColor: uiPanelFill,
      blurSigma: 28,
      borderColors: [
        uiGlow.withAlpha(isNightMode ? 160 : 58),
        uiGlow.withAlpha(isNightMode ? 60 : 12),
        Colors.transparent,
      ],
      child: Stack(
        children: [
          Positioned(
            bottom: -5,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: isNightMode ? 0.58 : 0.14,
              child: CityPulseWave(
                totalCount: totalComplaints,
                categoryCounts: categoryCounts,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSecretCameraTap,
                        child: Text(
                          'ПУЛЬС ГОРОДА · НИЖНЕВАРТОВСК',
                          style: TextStyle(
                            color: uiTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                          isUkLayerActive
                              ? Icons.domain_rounded
                              : Icons.domain_disabled_rounded,
                          color:
                              isUkLayerActive ? Colors.yellowAccent : uiAccent,
                          size: 22.0),
                      splashRadius: 22,
                      tooltip: 'Слой локальной УК',
                      onPressed: onUkToggleLayer,
                    ),
                    IconButton(
                      icon: Icon(Icons.format_list_bulleted_rounded,
                          color: uiAccent, size: 22.0),
                      splashRadius: 22,
                      tooltip: 'Рейтинг и список УК',
                      onPressed: onUkDialog,
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.menu_rounded, color: uiAccent, size: 24.0),
                      splashRadius: 22,
                      tooltip: 'Меню карты',
                      onPressed: onMapMenuSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  isNightMode
                      ? 'Ночной режим · карта, события и камеры'
                      : 'Дневной режим · карта города с улицами',
                  style: TextStyle(
                    color: uiTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

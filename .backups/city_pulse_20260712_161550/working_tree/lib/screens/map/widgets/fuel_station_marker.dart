/// 3D-styled marker for fuel stations (АЗС) on the map.
/// Shows brand color, fuel price badge on tap, animated pulse.
/// Brand-colored glossy pin with depth shadow + gradient.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../theme/pulse_colors.dart';

/// Brand → color mapping (matches real brand identity).
const _brandColors = {
  'ЛУКОЙЛ': Color(0xFFFF6600),       // orange
  'ГАЗПРОМНЕФТЬ': Color(0xFF0078D4), // blue
  'ГАЗПРОМ': Color(0xFF0078D4),
  'РОСНЕФТЬ': Color(0xFFFFCC00),     // yellow
  'ТНК': Color(0xFFE31937),          // red
  'СУРГУТНЕФТЕГАЗ': Color(0xFF0066B3),
  'SHELL': Color(0xFFFFD500),        // yellow-red
  'ОКИС-С': Color(0xFF00A859),       // green
  'НЕТ': Color(0xFF7C4DFF),          // violet default
};

Color _brandColor(String brand) {
  final b = brand.toUpperCase().trim();
  for (final key in _brandColors.keys) {
    if (b.contains(key)) return _brandColors[key]!;
  }
  return PulseColors.primary;
}

class FuelStationMarker {
  /// Build a [Marker] for a single fuel station.
  static Marker build({
    required double lat,
    required double lon,
    required String brand,
    required String name,
    required Map<String, double> prices,
    required String updatedAt,
    required bool showPrice,
    required bool isDayMode,
    String preferredFuel = 'АИ-95',
    VoidCallback? onTap,
    Animation<double>? pulseAnimation,
  }) {
    return Marker(
      point: LatLng(lat, lon),
      width: showPrice ? 78 : 30,
      height: showPrice ? 44 : 36,
      child: _FuelStationView(
        brand: brand,
        name: name,
        prices: prices,
        updatedAt: updatedAt,
        showPrice: showPrice,
        preferredFuel: preferredFuel,
        isDayMode: isDayMode,
        onTap: onTap,
        pulseAnimation: pulseAnimation,
      ),
    );
  }
}

class _FuelStationView extends StatelessWidget {
  final String brand;
  final String name;
  final Map<String, double> prices;
  final String updatedAt;
  final bool showPrice;
  final String preferredFuel;
  final bool isDayMode;
  final VoidCallback? onTap;
  final Animation<double>? pulseAnimation;

  const _FuelStationView({
    required this.brand,
    required this.name,
    required this.prices,
    required this.updatedAt,
    required this.showPrice,
    required this.preferredFuel,
    required this.isDayMode,
    this.onTap,
    this.pulseAnimation,
  });

  double? get _preferredPrice {
    if (prices.containsKey(preferredFuel)) return prices[preferredFuel];
    // fallback АИ-95 → АИ-92 → ДТ → first
    for (final f in ['АИ-95', 'АИ-92', 'ДТ']) {
      if (prices.containsKey(f)) return prices[f];
    }
    return prices.values.isNotEmpty ? prices.values.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _brandColor(brand);
    final marker = GestureDetector(
      onTap: onTap,
      child: _buildPin(color),
    );

    if (pulseAnimation == null) return marker;

    return AnimatedBuilder(
      animation: pulseAnimation!,
      builder: (context, child) {
        final t = (pulseAnimation!.value * 2 * 3.14159);
        final scale = 1.0 + 0.04 * (0.5 + 0.5 * (t.sin));
        return Transform.scale(scale: scale, child: child);
      },
      child: marker,
    );
  }

  Widget _buildPin(Color color) {
    if (!showPrice) {
      // Compact: teardrop pin with fuel pump icon
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Drop shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: 16,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Pin body
          Container(
            width: 28,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(color, Colors.white, 0.25)!,
                  color,
                  Color.lerp(color, Colors.black, 0.40)!,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.local_gas_station_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      );
    }

    // Expanded: pin + price badge
    final price = _preferredPrice;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Drop shadow
        Positioned(
          bottom: 0,
          child: Container(
            width: 50,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // Pin body (compact, since badge sits on top)
        Container(
          width: 26,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, 0.25)!,
                color,
                Color.lerp(color, Colors.black, 0.40)!,
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(13),
              bottomLeft: Radius.circular(13),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.55),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.local_gas_station_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
        ),
        // Price badge floating above
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price != null ? price.toStringAsFixed(price >= 100 ? 0 : 2) : '—',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '₽',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

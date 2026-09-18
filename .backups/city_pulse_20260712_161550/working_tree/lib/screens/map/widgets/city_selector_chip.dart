// lib/screens/map/widgets/city_selector_chip.dart
// Горизонтальная таблетка для выбора города в верхнем блоке.
import 'package:flutter/material.dart';
import '../../../data/city_config.dart';
import '../../../services/city_provider.dart';

class CitySelectorChip extends StatelessWidget {
  const CitySelectorChip({
    super.key,
    required this.activeCity,
    required this.onCitySelected,
    required this.textColor,
    required this.accentColor,
    required this.panelColor,
  });

  final CityConfig activeCity;
  final ValueChanged<CityConfig> onCitySelected;
  final Color textColor;
  final Color accentColor;
  final Color panelColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CityConfig>(
      onSelected: onCitySelected,
      color: panelColor.withOpacity(0.95),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 36),
      itemBuilder: (context) => CityConfig.all.map((city) {
        final isActive = city.id == activeCity.id;
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
                  color: isActive ? accentColor : textColor.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: accentColor, size: 14),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(activeCity.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              activeCity.name,
              style: TextStyle(
                color: textColor.withOpacity(0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: textColor.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful-обёртка, слушающая CityProvider
class CitySelectorWidget extends StatefulWidget {
  const CitySelectorWidget({
    super.key,
    required this.textColor,
    required this.accentColor,
    required this.panelColor,
    required this.onCityChanged,
  });

  final Color textColor;
  final Color accentColor;
  final Color panelColor;
  final ValueChanged<CityConfig> onCityChanged;

  @override
  State<CitySelectorWidget> createState() => _CitySelectorWidgetState();
}

class _CitySelectorWidgetState extends State<CitySelectorWidget> {
  final _provider = CityProvider();

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onCityChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onCityChanged);
    super.dispose();
  }

  void _onCityChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CitySelectorChip(
      activeCity: _provider.activeCity,
      onCitySelected: (city) {
        _provider.switchCity(city);
        widget.onCityChanged(city);
      },
      textColor: widget.textColor,
      accentColor: widget.accentColor,
      panelColor: widget.panelColor,
    );
  }
}

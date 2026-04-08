import 'package:flutter/material.dart';

class GpsLocationWidget extends StatelessWidget {
  const GpsLocationWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isGpsLocation,
  });

  final double? latitude;
  final double? longitude;
  final bool isGpsLocation;

  @override
  Widget build(BuildContext context) {
    if (latitude != null && longitude != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          isGpsLocation
              ? 'Точные GPS координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
              : 'Координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)} (взяты с карты)',
          style: TextStyle(
            color: isGpsLocation ? Colors.greenAccent : Colors.white54,
            fontSize: 12,
            fontWeight: isGpsLocation ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Откройте форму с карты, чтобы подставить координаты и адрес.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}

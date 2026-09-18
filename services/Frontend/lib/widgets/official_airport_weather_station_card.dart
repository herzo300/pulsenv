import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/city_weather_service.dart';

/// Официальная метеостанция «Аэропорт Нижневартовск» (WMO 23933 / USNN).
/// Единственный сертифицированный источник метеоданных для города Нижневартовска.
class OfficialAirportWeatherStationCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const OfficialAirportWeatherStationCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ОФИЦИАЛЬНАЯ МЕТЕОСТАНЦИЯ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Аэропорт Нижневартовск • WMO 23933 (USNN)',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 12),
                    SizedBox(width: 4),
                    Text(
                      '1 СТАНЦИЯ',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Описание метеопоста
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white60, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Нижневартовск обслуживается одной сертифицированной агрометеорологической станцией в аэропорту. Все городские показатели фиксируются её высокоточными датчиками.',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Сетка официальных параметров станции
          Row(
            children: [
              Expanded(
                child: _buildStationParam(
                  Icons.thermostat_rounded,
                  'Температура',
                  snapshot.temperatureC != null ? '${snapshot.temperatureC! > 0 ? "+" : ""}${snapshot.temperatureC!.round()}°C' : '—',
                  'Ощущ. ${snapshot.feelsLikeC?.round() ?? "—"}°C',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStationParam(
                  Icons.compress_rounded,
                  'Давление QNH',
                  snapshot.pressureMmHg != null ? '${snapshot.pressureMmHg!.round()} мм' : '—',
                  'Норма 755 мм',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStationParam(
                  Icons.air_rounded,
                  'Ветер ВПП',
                  snapshot.windSpeedMs != null ? '${snapshot.windSpeedMs!.toStringAsFixed(1)} м/с' : '—',
                  'Порывы ${snapshot.windGustsMs?.round() ?? "—"} м/с',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStationParam(
                  Icons.visibility_rounded,
                  'Видимость',
                  snapshot.visibilityM != null ? '${(snapshot.visibilityM! / 1000).toStringAsFixed(1)} км' : '> 10 км',
                  'Влажность ${snapshot.humidityPct ?? "—"}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationParam(IconData icon, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00E5FF), size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
          ),
          Text(
            sub,
            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

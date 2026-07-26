/// Air Quality Card — displays real-time AQI from /api/air-quality.
/// Used on the map screen (city overlay) and About screen.
/// Source: Open-Meteo Air Quality (primary), OpenAQ v3 (optional), WAQI (fallback).
library;

import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/app_branding.dart';
import '../services/backend_api_service.dart';
import '../theme/pulse_colors.dart';
import 'app_ui.dart';

/// Color & label by European AQI band.
class _AqiBand {
  final Color color;
  final String label;
  final IconData icon;
  const _AqiBand(this.color, this.label, this.icon);
}

_AqiBand _bandFor(int? euAqi, int? usAqi) {
  final v = euAqi ?? usAqi;
  if (v == null) return _AqiBand(PulseColors.textTertiary, 'нет данных', Icons.help_outline_rounded);
  if (v <= 20) return const _AqiBand(Color(0xFF00E676), 'отличное', Icons.sentiment_very_satisfied_rounded);
  if (v <= 40) return const _AqiBand(Color(0xFFA0E85B), 'хорошее', Icons.sentiment_satisfied_rounded);
  if (v <= 60) return const _AqiBand(Color(0xFFFFC857), 'умеренное', Icons.sentiment_neutral_rounded);
  if (v <= 80) return const _AqiBand(Color(0xFFFF9800), 'плохое', Icons.sentiment_dissatisfied_rounded);
  if (v <= 100) return const _AqiBand(Color(0xFFFF5722), 'очень плохое', Icons.sentiment_very_dissatisfied_rounded);
  return const _AqiBand(Color(0xFFB71C1C), 'опасное', Icons.warning_amber_rounded);
}

class AirQualityCard extends StatefulWidget {
  final String city; // 'nizhnevartovsk' | 'novosibirsk'
  final bool compact;
  final EdgeInsets? margin;

  const AirQualityCard({
    super.key,
    required this.city,
    this.compact = false,
    this.margin,
  });

  @override
  State<AirQualityCard> createState() => _AirQualityCardState();
}

class _AirQualityCardState extends State<AirQualityCard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await BackendApiService.instance.get('/api/weather/eco-health?city=${widget.city}');
      if (resp.statusCode == 200) {
        final d = json.decode(resp.body) as Map<String, dynamic>;
        d['pm25'] = d['pm2_5'] ?? d['pm25'];
        setState(() => _data = d);
      } else {
        setState(() => _error = 'HTTP ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: AppPanel(
        child: SizedBox(
          height: widget.compact ? 56 : 88,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        ),
      );
    }
    if (_error != null || _data == null) {
      return Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: AppPanel(
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: PulseColors.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Качество воздуха: ${_data?['summary'] ?? _error ?? 'недоступно'}',
                style: AppTextStyles.bodyMuted,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _load,
              tooltip: 'Обновить',
            ),
          ],
        ),
        ),
      );
    }
    final d = _data!;
    final euAqi = (d['european_aqi'] as num?)?.toInt();
    final usAqi = (d['us_aqi'] as num?)?.toInt();
    final band = _bandFor(euAqi, usAqi);
    final cityLabel = (d['city'] as String?) ?? AppBranding.appName;
    final source = (d['source'] as String?) ?? '—';

    if (widget.compact) {
      return Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: AppPanel(
        backgroundColor: band.color.withOpacity(0.10),
        child: InkWell(
          onTap: _load,
          child: Row(
            children: [
              Icon(band.icon, color: band.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('AQI ', style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant)),
                        Text(
                          euAqi?.toString() ?? usAqi?.toString() ?? '—',
                          style: AppTextStyles.cardTitle.copyWith(color: band.color),
                        ),
                        const SizedBox(width: 8),
                        Text(band.label, style: AppTextStyles.body.copyWith(color: band.color)),
                      ],
                    ),
                    Text(
                      '${cityLabel} · PM2.5 ${_fmt(d['pm25'])} µg/m³',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(source, style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        ),
      );
    }

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, color: band.color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Качество воздуха', style: AppTextStyles.cardTitle),
                    Text(cityLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _load,
                tooltip: 'Обновить',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: band.color,
                  borderRadius: AppRadii.md,
                  boxShadow: [
                    BoxShadow(
                      color: band.color.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    euAqi?.toString() ?? usAqi?.toString() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(band.label.toUpperCase(),
                        style: AppTextStyles.cardTitle.copyWith(color: band.color)),
                    const SizedBox(height: 2),
                    if (euAqi != null && usAqi != null)
                      Text('EAQI $euAqi · USAQI $usAqi', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Icon(band.icon, color: band.color, size: 28),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('PM2.5', _fmt(d['pm25']), 'µg/m³'),
              _chip('PM10', _fmt(d['pm10']), 'µg/m³'),
              _chip('NO₂', _fmt(d['no2']), 'µg/m³'),
              _chip('O₃', _fmt(d['o3']), 'µg/m³'),
              _chip('SO₂', _fmt(d['so2']), 'µg/m³'),
              _chip('CO', _fmt(d['co']), 'µg/m³'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Источник: $source', style: AppTextStyles.caption),
              if (d['observed_at'] != null)
                Flexible(
                  child: Text(
                    d['observed_at'].toString().substring(0, 16),
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (d['advisory'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'ИИ-СОВЕТНИК ГЕРМЕСА',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _advisoryTile(
              icon: Icons.health_and_safety_rounded,
              color: Colors.redAccent,
              title: 'Метеочувствительность',
              text: d['advisory']['health'] ?? 'Без рекомендаций',
            ),
            const SizedBox(height: 6),
            _advisoryTile(
              icon: Icons.masks_rounded,
              color: Colors.orangeAccent,
              title: 'Аллергикам и астматикам',
              text: d['advisory']['allergy'] ?? 'Без рекомендаций',
            ),
            const SizedBox(height: 6),
            _advisoryTile(
              icon: Icons.baby_changing_station_rounded,
              color: Colors.greenAccent,
              title: 'Прогулки с детьми',
              text: d['advisory']['kids'] ?? 'Без рекомендаций',
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _advisoryTile({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.12), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String name, String value, String unit) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppRadii.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$name ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          Text(value, style: AppTextStyles.body.copyWith(fontSize: 12)),
          Text(' $unit', style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      if (v >= 100) return v.toStringAsFixed(0);
      if (v >= 10) return v.toStringAsFixed(1);
      return v.toStringAsFixed(2);
    }
    return v.toString();
  }
}

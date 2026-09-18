// lib/widgets/lost_found_geo_radar.dart
//
// Интерактивный гео-радар потеряшек и находок с радиусом поиска до 5 км.
// Разворачивается по клику, позволяет выбрать радиус и отправляет оповещения.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

class LostFoundGeoRadar extends StatefulWidget {
  final String address;
  final int activeSearchesCount;
  final VoidCallback? onSendAlert;

  const LostFoundGeoRadar({
    super.key,
    required this.address,
    this.activeSearchesCount = 3,
    this.onSendAlert,
  });

  @override
  State<LostFoundGeoRadar> createState() => _LostFoundGeoRadarState();
}

class _LostFoundGeoRadarState extends State<LostFoundGeoRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  bool _isExpanded = false;
  double _selectedRadiusKm = 1.0; // 0.5, 1.0, 2.0, 3.0, 5.0
  bool _isAlertSent = false;
  int _baseOnlineCount = 0;
  int _baseTotalCount = 0;
  bool _isLoadingPresence = true;

  final List<double> _availableRadii = [0.5, 1.0, 2.0, 3.0, 5.0];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _fetchRealNeighborPresence();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealNeighborPresence() async {
    try {
      final uri = Uri.parse(
          '${MapConfig.backendApiBaseUrl}/jkh/house-presence?address=${Uri.encodeComponent(widget.address)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _baseOnlineCount = data['online_now'] ?? data['online'] ?? 0;
            _baseTotalCount = data['total_residents_in_app'] ?? data['total'] ?? 0;
            _isLoadingPresence = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _baseOnlineCount = 0;
        _baseTotalCount = 0;
        _isLoadingPresence = false;
      });
    }
  }

  int get _calculatedOnline => _baseOnlineCount;

  int get _calculatedTotal => _baseTotalCount;

  int get _calculatedYards => (_selectedRadiusKm * 12).round().clamp(2, 60);

  int get _calculatedDistricts => (_selectedRadiusKm * 2.5).ceil().clamp(1, 14);

  void _triggerGeoAlert() {
    HapticFeedback.heavyImpact();
    setState(() => _isAlertSent = true);
    widget.onSendAlert?.call();

    final targetCount = _calculatedTotal;
    final rStr = _selectedRadiusKm < 1.0
        ? '${(_selectedRadiusKm * 1000).toInt()} м'
        : '${_selectedRadiusKm.toStringAsFixed(_selectedRadiusKm.truncateToDouble() == _selectedRadiusKm ? 0 : 1)} км';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF00E5FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 Гео-оповещение разослано!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Оповещено $targetCount жителей в радиусе $rStr (${widget.address})',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const radarColor = Color(0xFF00E5FF);
    final rStr = _selectedRadiusKm < 1.0
        ? '${(_selectedRadiusKm * 1000).toInt()} М'
        : '${_selectedRadiusKm.toStringAsFixed(_selectedRadiusKm.truncateToDouble() == _selectedRadiusKm ? 0 : 1)} КМ';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded
              ? radarColor.withOpacity(0.65)
              : radarColor.withOpacity(0.30),
          width: _isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: radarColor.withOpacity(_isExpanded ? 0.18 : 0.08),
            blurRadius: _isExpanded ? 18 : 10,
            spreadRadius: _isExpanded ? 2 : 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Основная компактная строка (кликабельная)
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                // Анимированный мини-радар
                SizedBox(
                  width: 44,
                  height: 44,
                  child: AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RadarScreenPainter(
                          progress: _radarController.value,
                          color: radarColor,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isLoadingPresence
                                ? 'Гео-радар: поиск...'
                                : 'РАДАР $rStr: $_calculatedOnline ОНЛАЙН',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.tune_rounded,
                            color: radarColor.withOpacity(0.85),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.address} • $_calculatedYards дворов в зоне поиска',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Развернутая панель настройки радиуса до 5 км
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 10),

            // Выбор радиуса
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar_rounded, color: radarColor, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'РАДИУС ПОИСКА:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  rStr,
                  style: const TextStyle(
                    color: radarColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Селектор радиуса (кнопки-чипы)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _availableRadii.map((radius) {
                final isSelected = _selectedRadiusKm == radius;
                final label = radius < 1.0 ? '${(radius * 1000).toInt()} м' : '${radius.toInt()} км';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRadiusKm = radius);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? radarColor.withOpacity(0.25)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? radarColor : Colors.white12,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? radarColor : Colors.white70,
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Сводка зоны охвата
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('👥 Жителей', '$_calculatedTotal'),
                  Container(width: 1, height: 20, color: Colors.white12),
                  _buildStatItem('🟢 Онлайн', '$_calculatedOnline'),
                  Container(width: 1, height: 20, color: Colors.white12),
                  _buildStatItem('🏘️ Дворов', '$_calculatedYards'),
                  Container(width: 1, height: 20, color: Colors.white12),
                  _buildStatItem('📍 Мкр-нов', '$_calculatedDistricts'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Кнопка рассылки SOS-алерта соседям
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAlertSent
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : radarColor.withOpacity(0.2),
                  foregroundColor: _isAlertSent ? const Color(0xFF10B981) : radarColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isAlertSent ? const Color(0xFF10B981) : radarColor,
                      width: 1.2,
                    ),
                  ),
                ),
                onPressed: _isAlertSent ? null : _triggerGeoAlert,
                icon: Icon(
                  _isAlertSent ? Icons.check_circle_rounded : Icons.cell_tower_rounded,
                  size: 16,
                ),
                label: Text(
                  _isAlertSent
                      ? 'Оповещение разослано в радиусе $rStr'
                      : '📢 Разослать SOS-алерт соседям ($rStr)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 8.5),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _RadarScreenPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarScreenPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF030712)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Range rings
    final ringPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius - 1, ringPaint);

    // Crosshairs
    final linePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    // Sweep line
    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [color.withOpacity(0.6), Colors.transparent],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Target blips
    final blipPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx + radius * 0.45, center.dy - radius * 0.25), 2.2, blipPaint);
    canvas.drawCircle(Offset(center.dx - radius * 0.35, center.dy + radius * 0.4), 2.2, blipPaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.2, center.dy + radius * 0.55), 1.8, blipPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarScreenPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

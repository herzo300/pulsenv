import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_metrics_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AppMetricsService _metricsService = AppMetricsService.instance;
  Timer? _refreshTimer;
  Map<String, dynamic>? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await _metricsService.sendHeartbeat(screen: 'admin_dashboard');
      final metrics = await _metricsService.fetchMetrics();
      if (!mounted) {
        return;
      }
      setState(() {
        _metrics = metrics;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090E1F),
        elevation: 0,
        title: const Text(
          'ADMIN METRICS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _buildHeadline(),
                      const SizedBox(height: 16),
                      _buildMetricGrid(),
                      const SizedBox(height: 16),
                      _buildActivitySection(),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(
                        title: 'Активные платформы',
                        icon: Icons.devices_rounded,
                        values: _readMap('active_platforms'),
                      ),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(
                        title: 'Активные версии',
                        icon: Icons.system_update_rounded,
                        values: _readMap('active_app_versions'),
                      ),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(
                        title: 'Активные экраны',
                        icon: Icons.dashboard_customize_rounded,
                        values: _readMap('active_screens'),
                      ),
                      const SizedBox(height: 16),
                      _buildTopRoutesCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.white54),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить метрики',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _refresh,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1736), Color(0xFF101A28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF21F3C3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Системная телеметрия приложения',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Последняя активность: ${_readString('last_activity_at', fallback: 'нет данных')}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Окно активности IP: ${_readInt('active_window_seconds')} сек',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    final tiles = <Widget>[
      _buildMetricCard(
        label: 'IP сейчас',
        value: _readInt('active_unique_ips').toString(),
        accent: const Color(0xFF00E5FF),
        icon: Icons.radar_rounded,
      ),
      _buildMetricCard(
        label: 'IP всего',
        value: _readInt('total_unique_ips').toString(),
        accent: const Color(0xFF8B5CF6),
        icon: Icons.public_rounded,
      ),
      _buildMetricCard(
        label: 'Пик IP',
        value: _readInt('peak_active_unique_ips').toString(),
        accent: const Color(0xFFF59E0B),
        icon: Icons.show_chart_rounded,
      ),
      _buildMetricCard(
        label: 'Heartbeat',
        value: _readInt('total_heartbeats').toString(),
        accent: const Color(0xFF21F3C3),
        icon: Icons.favorite_rounded,
      ),
      _buildMetricCard(
        label: 'Запросов',
        value: _readInt('total_requests').toString(),
        accent: const Color(0xFF38BDF8),
        icon: Icons.sync_alt_rounded,
      ),
      _buildMetricCard(
        label: 'За час',
        value: _readInt('requests_last_hour').toString(),
        accent: const Color(0xFFFF6B6B),
        icon: Icons.schedule_rounded,
      ),
      _buildMetricCard(
        label: 'За сутки',
        value: _readInt('requests_last_24_hours').toString(),
        accent: const Color(0xFF4ADE80),
        icon: Icons.today_rounded,
      ),
      _buildMetricCard(
        label: 'За неделю',
        value: _readInt('requests_last_7_days').toString(),
        accent: const Color(0xFF94A3B8),
        icon: Icons.date_range_rounded,
      ),
      _buildMetricCard(
        label: 'Uptime',
        value: _readString('uptime_human', fallback: '-'),
        accent: const Color(0xFFCBD5E1),
        icon: Icons.timer_outlined,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: tiles,
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text(
                'Активность за час / сутки / неделю',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Голубая линия: запросы. Зеленая линия: уникальные IP по heartbeat в корзине времени.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildActivityChartCard(
            title: 'Последний час',
            subtitle: '5-минутные корзины',
            accent: const Color(0xFF38BDF8),
            data: _readSeries('hour'),
          ),
          const SizedBox(height: 14),
          _buildActivityChartCard(
            title: 'Последние сутки',
            subtitle: 'Почасовая активность',
            accent: const Color(0xFF4ADE80),
            data: _readSeries('day'),
          ),
          const SizedBox(height: 14),
          _buildActivityChartCard(
            title: 'Последняя неделя',
            subtitle: 'Дневная динамика',
            accent: const Color(0xFFF59E0B),
            data: _readSeries('week'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChartCard({
    required String title,
    required String subtitle,
    required Color accent,
    required List<_ActivityDatum> data,
  }) {
    final requestsTotal = data.fold<int>(0, (sum, item) => sum + item.requests);
    final uniqueIpsPeak = data.fold<int>(0, (peak, item) => math.max(peak, item.uniqueIps));
    final labels = data.isEmpty
        ? const <String>['-', '-', '-']
        : <String>[
            data.first.label,
            data[data.length ~/ 2].label,
            data.last.label,
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 172,
            width: double.infinity,
            child: CustomPaint(
              painter: _ActivityChartPainter(
                data: data,
                requestColor: const Color(0xFF38BDF8),
                ipColor: const Color(0xFF21F3C3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLegendDot(const Color(0xFF38BDF8), 'Запросы: $requestsTotal'),
              const SizedBox(width: 14),
              _buildLegendDot(const Color(0xFF21F3C3), 'Пик IP: $uniqueIpsPeak'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: labels
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: label == labels.first
                          ? TextAlign.left
                          : label == labels.last
                              ? TextAlign.right
                              : TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> values,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (values.isEmpty)
            const Text('Нет активных данных', style: TextStyle(color: Colors.white54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopRoutesCard() {
    final routes = (_metrics?['top_routes'] as List<dynamic>? ?? const <dynamic>[]);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 10),
              Text(
                'Топ маршрутов backend',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (routes.isEmpty)
            const Text('Пока нет статистики маршрутов', style: TextStyle(color: Colors.white54))
          else
            ...routes.map((item) {
              final route = item is Map<String, dynamic> ? item : <String, dynamic>{};
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        route['path']?.toString() ?? '-',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${route['hits'] ?? 0}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Map<String, dynamic> _readMap(String key) {
    final value = _metrics?[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  List<_ActivityDatum> _readSeries(String bucketKey) {
    final activitySeries = _metrics?['activity_series'];
    if (activitySeries is! Map) {
      return const <_ActivityDatum>[];
    }

    final dynamic seriesRaw = activitySeries[bucketKey];
    if (seriesRaw is! List) {
      return const <_ActivityDatum>[];
    }

    return seriesRaw
        .whereType<Map>()
        .map(
          (item) => _ActivityDatum(
            label: item['label']?.toString() ?? '-',
            requests: int.tryParse(item['requests']?.toString() ?? '') ?? 0,
            uniqueIps: int.tryParse(item['unique_ips']?.toString() ?? '') ?? 0,
          ),
        )
        .toList();
  }

  int _readInt(String key) {
    final value = _metrics?[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readString(String key, {required String fallback}) {
    final value = _metrics?[key];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _ActivityDatum {
  const _ActivityDatum({
    required this.label,
    required this.requests,
    required this.uniqueIps,
  });

  final String label;
  final int requests;
  final int uniqueIps;
}

class _ActivityChartPainter extends CustomPainter {
  const _ActivityChartPainter({
    required this.data,
    required this.requestColor,
    required this.ipColor,
  });

  final List<_ActivityDatum> data;
  final Color requestColor;
  final Color ipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.white.withOpacity(0.02);
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      backgroundPaint,
    );

    for (int step = 1; step <= 4; step++) {
      final y = size.height * step / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.length < 2) {
      return;
    }

    final maxValue = data.fold<int>(
      1,
      (peak, item) => math.max(peak, math.max(item.requests, item.uniqueIps)),
    );
    final chartWidth = size.width - 24;
    final chartHeight = size.height - 20;
    final xStep = chartWidth / math.max(1, data.length - 1);

    final requestsPath = Path();
    final ipsPath = Path();
    final requestsFillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final dx = 12 + i * xStep;
      final requestY = 8 + chartHeight - (data[i].requests / maxValue) * chartHeight;
      final ipY = 8 + chartHeight - (data[i].uniqueIps / maxValue) * chartHeight;

      if (i == 0) {
        requestsPath.moveTo(dx, requestY);
        ipsPath.moveTo(dx, ipY);
        requestsFillPath
          ..moveTo(dx, size.height - 6)
          ..lineTo(dx, requestY);
      } else {
        requestsPath.lineTo(dx, requestY);
        ipsPath.lineTo(dx, ipY);
        requestsFillPath.lineTo(dx, requestY);
      }
    }

    requestsFillPath
      ..lineTo(12 + (data.length - 1) * xStep, size.height - 6)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [requestColor.withOpacity(0.22), requestColor.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(requestsFillPath, fillPaint);

    final requestPaint = Paint()
      ..color = requestColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ipPaint = Paint()
      ..color = ipColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(requestsPath, requestPaint);
    canvas.drawPath(ipsPath, ipPaint);

    for (int i = 0; i < data.length; i++) {
      final dx = 12 + i * xStep;
      final requestY = 8 + chartHeight - (data[i].requests / maxValue) * chartHeight;
      final ipY = 8 + chartHeight - (data[i].uniqueIps / maxValue) * chartHeight;

      canvas.drawCircle(
        Offset(dx, requestY),
        2.5,
        Paint()..color = requestColor,
      );
      canvas.drawCircle(
        Offset(dx, ipY),
        2.2,
        Paint()..color = ipColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.requestColor != requestColor ||
        oldDelegate.ipColor != ipColor;
  }
}

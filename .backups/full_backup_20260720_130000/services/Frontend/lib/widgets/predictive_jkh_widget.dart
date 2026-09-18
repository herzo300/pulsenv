import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import 'app_ui.dart';

class PredictiveJkhWidget extends StatefulWidget {
  final String city;
  const PredictiveJkhWidget({super.key, required this.city});

  @override
  State<PredictiveJkhWidget> createState() => _PredictiveJkhWidgetState();
}

class _PredictiveJkhWidgetState extends State<PredictiveJkhWidget> {
  List<dynamic> _alerts = [];
  bool _loading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchPredictiveJkh();
  }

  Future<void> _fetchPredictiveJkh() async {
    try {
      final resp = await BackendApiService.instance.get('/api/dispatcher/predictive-jkh?city=${widget.city}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          final List<dynamic> fetchedAlerts = data['alerts'] ?? [];
          final filtered = fetchedAlerts.where((a) => a['risk_level'] == 'Критический' || a['risk_level'] == 'Повышенный').toList();
          if (mounted) {
            setState(() {
              _alerts = filtered;
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching predictive JKH alerts: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _alerts.isEmpty) return const SizedBox.shrink();

    final alert = _alerts.first;
    final isCritical = alert['risk_level'] == 'Критический';
    final Color riskColor = isCritical ? const Color(0xFFFF3333) : const Color(0xFFFF9900);
    final IconData riskIcon = isCritical ? Icons.emergency_share_rounded : Icons.report_problem_rounded;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: riskColor.withOpacity(0.18),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: AppPanel(
            borderColor: riskColor.withOpacity(0.35),
            backgroundColor: const Color(0xFF0D0D0D).withOpacity(0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(riskIcon, color: riskColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alert['risk_level'].toUpperCase()} РИСК АВАРИИ ЖКХ',
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert['address'] ?? 'Нижневартовск',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                Text(
                  alert['description'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: riskColor.withOpacity(0.15), width: 0.8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_rounded, color: riskColor, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Рекомендация: ${alert['recommendation'] ?? ""}',
                          style: TextStyle(
                            color: riskColor.withOpacity(0.95),
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
  );
}
}

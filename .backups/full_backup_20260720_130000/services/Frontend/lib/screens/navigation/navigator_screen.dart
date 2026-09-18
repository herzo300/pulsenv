import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/navigation_history_service.dart';
import '../map/widgets/map_glass_panel.dart';

class NavigatorScreen extends StatefulWidget {
  final Function(NavigationTrack track) onTrackSelected;
  final VoidCallback onClearTrack;
  final NavigationTrack? selectedTrack;
  final VoidCallback? onStartTracking;

  const NavigatorScreen({
    super.key,
    required this.onTrackSelected,
    required this.onClearTrack,
    this.selectedTrack,
    this.onStartTracking,
  });

  @override
  State<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends State<NavigatorScreen> {
  final _navService = NavigationHistoryService.instance;
  List<NavigationTrack> _tracks = [];
  Timer? _metricsTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    if (_navService.isTracking) {
      _startMetricsTimer();
    }
  }

  @override
  void didUpdateWidget(covariant NavigatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload tracks when the widget is updated (e.g. after tracking stops)
    if (oldWidget.selectedTrack != widget.selectedTrack) {
      _loadTracks();
    }
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final list = await _navService.getTracks();
    if (mounted) {
      setState(() {
        _tracks = list;
      });
    }
  }

  void _startMetricsTimer() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _stopMetricsTimer() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
    setState(() {
      _secondsElapsed = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} м';
    }
    return '${(meters / 1000).toStringAsFixed(2)} км';
  }

  Future<void> _toggleTracking() async {
    if (_navService.isTracking) {
      final track = await _navService.stopTracking();
      _stopMetricsTimer();
      if (track != null) {
        widget.onTrackSelected(track);
      }
      _loadTracks();
    } else {
      await _navService.startTracking();
      _startMetricsTimer();
      widget.onStartTracking?.call();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = _navService.isTracking;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: MapGlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        padding: EdgeInsets.zero,
        fillColor: const Color(0xEA0B0F19),
        blurSigma: 26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: Color(0xFF00E5FF), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Навигатор • Маршруты',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Live tracking panel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTracking
                    ? const Color(0xFFEF4444).withAlpha(16)
                    : Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isTracking
                      ? const Color(0xFFEF4444).withAlpha(80)
                      : Colors.white.withAlpha(12),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (isTracking) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ИДЕТ ЗАПИСЬ ПУТИ...',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('ВРЕМЯ', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_secondsElapsed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('РАССТОЯНИЕ', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(
                              _formatDistance(_navService.currentTrackPoints.isEmpty ? 0.0 : _getCurrentTrackDistance()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _toggleTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTracking ? const Color(0xFFEF4444) : const Color(0xFF00E5FF),
                        foregroundColor: isTracking ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(
                        isTracking ? 'Остановить запись' : 'Начать запись маршрута',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.selectedTrack != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Показан: ${widget.selectedTrack!.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClearTrack,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Скрыть', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // History list
            Expanded(
              child: _tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'История поездок пуста',
                        style: TextStyle(color: Colors.white30, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _tracks.length,
                      itemBuilder: (ctx, index) {
                        final track = _tracks[index];
                        final isSelected = widget.selectedTrack?.id == track.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00E5FF).withAlpha(20)
                                : Colors.white.withAlpha(6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00E5FF).withAlpha(120)
                                  : Colors.white.withAlpha(12),
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              widget.onTrackSelected(track);
                              Navigator.of(context).pop();
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isSelected ? const Color(0xFF00E5FF) : Colors.white).withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.route_rounded,
                                color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              track.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatDistance(track.distanceMeters)} • ${track.date.day.toString().padLeft(2, '0')}.${track.date.month.toString().padLeft(2, '0')}.${track.date.year}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E293B),
                                    title: const Text('Удалить маршрут?', style: TextStyle(color: Colors.white)),
                                    content: const Text('Этот маршрут будет навсегда удален из истории.', style: TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(c).pop(false),
                                        child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(c).pop(true),
                                        child: const Text('Удалить', style: TextStyle(color: Color(0xFFEF4444))),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _navService.deleteTrack(track.id);
                                  if (isSelected) {
                                    widget.onClearTrack();
                                  }
                                  _loadTracks();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double _getCurrentTrackDistance() {
    double total = 0.0;
    final pts = _navService.currentTrackPoints;
    for (int i = 0; i < pts.length - 1; i++) {
      total += Geolocator.distanceBetween(
        pts[i].latitude,
        pts[i].longitude,
        pts[i + 1].latitude,
        pts[i + 1].longitude,
      );
    }
    return total;
  }
}

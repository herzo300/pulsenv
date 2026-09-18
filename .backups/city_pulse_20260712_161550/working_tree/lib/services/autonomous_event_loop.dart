import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../map/map_config.dart';

/// ──────────────────────────────────────────────────────────────
/// AUTONOMOUS EVENT LOOP SERVICE (ECC Autonomous Loops Skill)
/// ──────────────────────────────────────────────────────────────
///
/// This service runs a persistent background loop that:
///   1. Polls the backend for new city events
///   2. Compares against known "baseline" for the city
///   3. Emits only significant deviations via stream
///   4. Tracks a rolling history per stat for sparklines
///
/// This eliminates the need for manual refresh and makes
/// the app feel like a living, breathing monitoring tool.
/// ──────────────────────────────────────────────────────────────

class CityEventSnapshot {
  final int totalComplaints;
  final int resolvedComplaints;
  final int activeComplaints;
  final Map<String, int> categoryCounts;
  final DateTime timestamp;
  final String? aiSummary;

  /// Rolling history for sparkline rendering (last 12 snapshots)
  final List<int> totalHistory;
  final List<int> resolvedHistory;
  final List<int> activeHistory;

  const CityEventSnapshot({
    required this.totalComplaints,
    required this.resolvedComplaints,
    required this.activeComplaints,
    required this.categoryCounts,
    required this.timestamp,
    this.aiSummary,
    this.totalHistory = const [],
    this.resolvedHistory = const [],
    this.activeHistory = const [],
  });

  factory CityEventSnapshot.empty() => CityEventSnapshot(
        totalComplaints: 0,
        resolvedComplaints: 0,
        activeComplaints: 0,
        categoryCounts: const {},
        timestamp: DateTime.now(),
      );

  /// True if this snapshot represents a significant change from [previous].
  bool isSignificantChange(CityEventSnapshot previous) {
    if ((totalComplaints - previous.totalComplaints).abs() >= 1) return true;
    if ((resolvedComplaints - previous.resolvedComplaints).abs() >= 1) {
      return true;
    }
    if ((activeComplaints - previous.activeComplaints).abs() >= 1) return true;
    return false;
  }
}

class AutonomousEventLoop {
  AutonomousEventLoop._();
  static final AutonomousEventLoop instance = AutonomousEventLoop._();

  Timer? _pollTimer;
  CityEventSnapshot _lastSnapshot = CityEventSnapshot.empty();

  /// Rolling history buffers (max 12 data points for sparklines)
  final List<int> _totalHistory = [];
  final List<int> _resolvedHistory = [];
  final List<int> _activeHistory = [];
  static const int _maxHistory = 12;

  final StreamController<CityEventSnapshot> _controller =
      StreamController<CityEventSnapshot>.broadcast();

  /// Stream of city event snapshots — only emits on significant changes.
  Stream<CityEventSnapshot> get events => _controller.stream;

  /// The most recent snapshot (for synchronous access).
  CityEventSnapshot get lastSnapshot => _lastSnapshot;

  /// Start the autonomous polling loop.
  ///
  /// [interval] controls how frequently we poll (default: 30 seconds).
  void start({Duration interval = const Duration(seconds: 30)}) {
    if (_pollTimer != null) return; // already running
    debugPrint('[AutonomousEventLoop] Starting with interval: $interval');

    // Immediate first poll
    _poll();

    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  /// Stop the polling loop.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('[AutonomousEventLoop] Stopped.');
  }

  /// Force an immediate refresh (e.g., after submitting a complaint).
  Future<void> forceRefresh() => _poll();

  Future<void> _poll() async {
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/reports');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = json.decode(utf8.decode(response.bodyBytes));
      final reports = data is List ? data : (data['reports'] ?? []) as List;

      final categoryCounts = <String, int>{};
      int resolved = 0;
      int active = 0;

      for (final report in reports) {
        final category = (report['category'] ?? 'Прочее') as String;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

        final status = (report['status'] ?? '').toString().toLowerCase();
        if (status == 'resolved' || status == 'решено') {
          resolved++;
        } else {
          active++;
        }
      }

      final total = reports.length;

      // Update rolling history
      _addToHistory(_totalHistory, total);
      _addToHistory(_resolvedHistory, resolved);
      _addToHistory(_activeHistory, active);

      final snapshot = CityEventSnapshot(
        totalComplaints: total,
        resolvedComplaints: resolved,
        activeComplaints: active,
        categoryCounts: categoryCounts,
        timestamp: DateTime.now(),
        totalHistory: List.unmodifiable(_totalHistory),
        resolvedHistory: List.unmodifiable(_resolvedHistory),
        activeHistory: List.unmodifiable(_activeHistory),
      );

      // Only emit on significant changes or first poll
      if (_lastSnapshot.totalComplaints == 0 ||
          snapshot.isSignificantChange(_lastSnapshot)) {
        _lastSnapshot = snapshot;
        _controller.add(snapshot);
        debugPrint(
            '[AutonomousEventLoop] Emitted: total=$total resolved=$resolved active=$active');
      } else {
        // Still update last snapshot silently for history
        _lastSnapshot = snapshot;
      }
    } catch (e) {
      debugPrint('[AutonomousEventLoop] Poll error: $e');
    }
  }

  void _addToHistory(List<int> history, int value) {
    history.add(value);
    if (history.length > _maxHistory) {
      history.removeAt(0);
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

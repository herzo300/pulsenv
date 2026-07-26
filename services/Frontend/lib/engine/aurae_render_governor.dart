import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuraeVisualTier { calm, deep, ritual }

/// Central budget for animated AURAE scenes.
///
/// Keep this small and dependency-free so render-heavy widgets can consult it
/// without pulling app state into painters.
class AuraeRenderGovernor extends ChangeNotifier with WidgetsBindingObserver {
  AuraeRenderGovernor._();
  static final AuraeRenderGovernor instance = AuraeRenderGovernor._();

  bool _appVisible = true;
  AuraeVisualTier _tier = AuraeVisualTier.calm;

  bool get appVisible => _appVisible;
  AuraeVisualTier get tier => _tier;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPerformancePreference();
  }

  Future<void> _loadSavedPerformancePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final highPerf = prefs.getBool('high_performance_mode') ?? false;
      setTier(highPerf ? AuraeVisualTier.ritual : AuraeVisualTier.calm);
    } catch (_) {}
  }

  void disposeGovernor() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void setTier(AuraeVisualTier tier) {
    if (_tier == tier) return;
    _tier = tier;
    notifyListeners();
  }

  int targetFps({
    required bool reducedMotion,
    int requestedFps = 60,
    bool heavy = false,
  }) {
    if (!_appVisible) return 0;
    if (reducedMotion) return heavy ? 12 : 24;
    final cap = switch (_tier) {
      AuraeVisualTier.calm => heavy ? 24 : 30,
      AuraeVisualTier.deep => heavy ? 30 : 60,
      AuraeVisualTier.ritual => requestedFps,
    };
    return requestedFps.clamp(1, cap).toInt();
  }

  Duration frameInterval({
    required bool reducedMotion,
    int requestedFps = 60,
    bool heavy = false,
  }) {
    final fps = targetFps(
      reducedMotion: reducedMotion,
      requestedFps: requestedFps,
      heavy: heavy,
    );
    if (fps <= 0) return const Duration(days: 1);
    return Duration(milliseconds: (1000 / fps).round());
  }

  double particleScale({required bool reducedMotion}) {
    if (reducedMotion) return 0.18;
    return switch (_tier) {
      AuraeVisualTier.calm => 0.45,
      AuraeVisualTier.deep => 0.72,
      AuraeVisualTier.ritual => 1.0,
    };
  }

  double blurScale({required bool reducedMotion}) {
    if (reducedMotion) return 0.25;
    return switch (_tier) {
      AuraeVisualTier.calm => 0.55,
      AuraeVisualTier.deep => 0.8,
      AuraeVisualTier.ritual => 1.0,
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextVisible = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached ||
      AppLifecycleState.hidden =>
        false,
    };
    if (_appVisible == nextVisible) return;
    _appVisible = nextVisible;
    notifyListeners();
  }
}

/// Shared time-of-day helpers for hub backgrounds and living scenes.
class AuraCircadian {
  AuraCircadian._();

  /// 0 during day, ramps from 17:00, peaks 20:00–04:00, eases toward dawn.
  static double nightDimStrength([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final minutes = dt.hour * 60 + dt.minute;

    if (minutes >= 20 * 60 || minutes < 5 * 60) {
      if (minutes >= 20 * 60) {
        final progress = (minutes - 20 * 60) / (4 * 60);
        return (0.38 + progress * 0.62).clamp(0.0, 1.0);
      }
      final progress = minutes / (5 * 60);
      return (1.0 - progress * 0.48).clamp(0.52, 1.0);
    }
    if (minutes >= 17 * 60) {
      final progress = (minutes - 17 * 60) / (3 * 60);
      return progress * 0.38;
    }
    return 0.0;
  }

  static bool isNightish([DateTime? now]) => nightDimStrength(now) >= 0.35;
}

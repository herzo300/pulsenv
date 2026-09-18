import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import '../../../theme/pulse_categories.dart';

/// Глобальный ValueNotifier для синхронизации пульсации между бэджами.
/// Обновляется через Ticker в PulseAnimationHost (не Timer.periodic).
final ValueNotifier<double> _pulseProgress = ValueNotifier(0.0);

/// Хост пульсирующей анимации на основе Ticker.
/// Создаёт один Ticker, который обновляет _pulseProgress.
/// Ticker автоматически паузится когда приложение в фоне.
/// Заменяет старый Timer.periodic(16ms), который работал вечно.
class _PulseTickerHost {
  static bool _started = false;
  static Ticker? _ticker;

  static void ensureRunning() {
    if (_started) return;
    _started = true;
    _ticker = Ticker((elapsed) {
      _pulseProgress.value = (elapsed.inMilliseconds % 3200) / 3200.0;
    });
    _ticker!.start();
  }
}

class _SyncPulseAnimation extends Animation<double> {
  _SyncPulseAnimation(this.notifier);
  final ValueNotifier<double> notifier;

  @override
  void addListener(VoidCallback listener) => notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => notifier.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  double get value => notifier.value;
}

/// Compact brand mark for map chrome — icon + short label, no long title.
class PulseAppBadge extends StatelessWidget {
  const PulseAppBadge({
    super.key,
    required this.isNightMode,
    required this.accent,
    required this.textPrimary,
    this.cityName = 'Нижневартовск',
    this.compact = true,
    this.showLabel = true,
    this.category,
  });

  final bool isNightMode;
  final Color accent;
  final Color textPrimary;
  final String cityName;
  final bool compact;
  final bool showLabel;
  final String? category;

  @override
  Widget build(BuildContext context) {
    _PulseTickerHost.ensureRunning();
    // 28px minimum touch target for the compact badge.
    final box = compact ? 28.0 : 42.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 11 : 14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isNightMode
                  ? [
                      accent.withAlpha(42),
                      const Color(0xFF0B1B33),
                    ]
                  : [
                      accent.withAlpha(28),
                      const Color(0xFFE8FAFF),
                    ],
            ),
            border: Border.all(
              color: accent.withAlpha(isNightMode ? 150 : 100),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(isNightMode ? 70 : 40),
                blurRadius: compact ? 10 : 16,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 10 : 13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (category != null)
                  AnimatedBuilder(
                    animation: _pulseProgress,
                    builder: (context, _) {
                      final double val = _pulseProgress.value;
                      double scale = 1.0;
                      if (val < 0.2) {
                        scale = 1.0 + math.sin(val * 5 * math.pi) * 0.18;
                      } else if (val < 0.4) {
                        scale = 1.0 + math.sin((val - 0.2) * 5 * math.pi) * 0.10;
                      }
                      
                      final iconData = PulseCategories.iconFor(category);
                      
                      return Transform.scale(
                        scale: scale,
                        child: Center(
                          child: Icon(
                            iconData,
                            color: accent,
                            size: compact ? 15 : 20,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Lottie.asset(
                    'assets/animations/pulse.json',
                    controller: _SyncPulseAnimation(_pulseProgress),
                    fit: BoxFit.contain,
                  ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    width: compact ? 8 : 10,
                    height: compact ? 8 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(
                        color: isNightMode
                            ? const Color(0xFF020617)
                            : Colors.white,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: compact ? 8 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Пульс',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: compact ? 12 : 15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                cityName,
                style: TextStyle(
                  color: accent.withAlpha(isNightMode ? 220 : 180),
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

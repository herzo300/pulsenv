import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';

class SecurityLockScreen extends StatelessWidget {
  const SecurityLockScreen({
    super.key,
    required this.referenceCode,
  });

  final String referenceCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PulseColors.backgroundRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: PulseColors.primary.withOpacity(0.18),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 52,
                      color: PulseColors.primary,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Service unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PulseColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This build cannot run in the current device environment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PulseColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ref: $referenceCode',
                      style: const TextStyle(
                        color: PulseColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

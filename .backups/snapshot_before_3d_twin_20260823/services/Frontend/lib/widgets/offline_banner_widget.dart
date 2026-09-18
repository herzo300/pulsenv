import 'package:flutter/material.dart';

/// Top banner showing offline mode status and cached data timestamp.
class OfflineBannerWidget extends StatelessWidget {
  final bool isOffline;
  final String lastSyncTime;

  const OfflineBannerWidget({
    super.key,
    required this.isOffline,
    this.lastSyncTime = '14:30',
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: Colors.amberAccent, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.amberAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Офлайн-режим — сохраненные данные от $lastSyncTime',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

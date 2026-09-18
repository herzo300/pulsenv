import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';

class QuickIntroCard extends StatelessWidget {
  const QuickIntroCard({
    super.key,
    required this.hasGps,
    required this.isGpsLocation,
    required this.category,
    required this.isDefaultCategory,
    required this.smartSummary,
    required this.smartSeverity,
    required this.aiProcessing,
    required this.onAutoFill,
  });

  final bool hasGps;
  final bool isGpsLocation;
  final String category;
  final bool isDefaultCategory;
  final String? smartSummary;
  final int? smartSeverity;
  final bool aiProcessing;
  final VoidCallback onAutoFill;

  Color get _primary => PulseColors.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Фото + 2 слова',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                      'Загрузите фото и скажите, например: «Тут яма». AI сам выберет категорию и подтянет адрес по GPS.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                icon: hasGps ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                label: hasGps
                    ? (isGpsLocation
                        ? 'Точный GPS включен'
                        : 'Точка взята с карты')
                    : 'Координаты еще не получены',
                active: hasGps,
              ),
              _buildStatusChip(
                icon: Icons.sell_rounded,
                label: 'Категория: $category',
                active: !isDefaultCategory,
              ),
              if (smartSummary != null && smartSummary!.isNotEmpty)
                _buildStatusChip(
                  icon: Icons.description_outlined,
                  label: smartSummary!,
                  active: true,
                ),
              if (smartSeverity != null)
                _buildStatusChip(
                  icon: Icons.priority_high_rounded,
                  label: 'Приоритет AI: $smartSeverity/3',
                  active: smartSeverity! >= 2,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: aiProcessing ? null : onAutoFill,
              icon: aiProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(
                  aiProcessing ? 'AI заполняет...' : 'Заполнить автоматически'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(18),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _primary.withAlpha(24) : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? _primary.withAlpha(110) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.white70),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

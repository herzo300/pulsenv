import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final int xp;
  final int streak;
  final int reportsCount;
  final int resolvedCount;

  const ProfileStats({
    super.key,
    required this.xp,
    required this.streak,
    required this.reportsCount,
    required this.resolvedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('XP', '', Icons.star_rounded, Colors.amberAccent),
          _statItem('Стрик', ' дн', Icons.local_fire_department_rounded, Colors.orangeAccent),
          _statItem('Сигналы', '', Icons.report_problem_rounded, Colors.cyanAccent),
          _statItem('Решено', '', Icons.check_circle_rounded, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

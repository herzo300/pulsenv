import 'package:flutter/material.dart';
import '../../../widgets/premium/pulse_liquid_glass.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final String rankTitle;
  final int level;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.rankTitle,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return PulseLiquidGlass(
      borderRadius: 24,
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF00F0FF).withOpacity(0.3),
            child: CircleAvatar(
              radius: 38,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            username.isNotEmpty ? username : 'Активист Нижневартовска',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4)),
            ),
            child: Text(
              'Уровень  • ',
              style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

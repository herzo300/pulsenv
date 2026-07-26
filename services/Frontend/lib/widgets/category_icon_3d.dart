import 'package:flutter/material.dart';

/// Pseudo-3D category icons rendered via CustomPainter.
/// Designed to look like premium 3D renders with depth and glow.
class CategoryIcon3D extends StatelessWidget {
  final String category;
  final String? title;
  final double size;
  final bool isActive;

  const CategoryIcon3D({
    super.key,
    required this.category,
    this.title,
    this.size = 54,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _CategoryIcon3DConfig.forCategory(category, title);
    return CustomPaint(
      size: Size(size, size),
      painter: _Icon3DPainter(config: config, isActive: isActive),
    );
  }
}

class _CategoryIcon3DConfig {
  final List<Color> gradient;
  final Color shadowColor;
  final Color highlightColor;
  final IconData icon;
  final String emoji;

  const _CategoryIcon3DConfig({
    required this.gradient,
    required this.shadowColor,
    required this.highlightColor,
    required this.icon,
    required this.emoji,
  });

  static _CategoryIcon3DConfig forCategory(String category, [String? title]) {
    final cat = category.toLowerCase();
    final tLower = (title ?? '').toLowerCase();

    // 0. ЧП / Чрезвычайные ситуации / Пожары / Потопы
    if (cat == 'чп' || cat.contains('чп') || cat.contains('чрезвыч') || cat.contains('пожар') || cat.contains('опасн') || cat.contains('потоп')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFF4D4D), Color(0xFFDC2626), Color(0xFF7F1D1D)],
        shadowColor: Color(0xFFEF4444),
        highlightColor: Color(0xFFFEE2E2),
        icon: Icons.warning_amber_rounded,
        emoji: '🚨',
      );
    }
    // 0.1. Газоснабжение
    if (cat.contains('газ')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFF7C2D12)],
        shadowColor: Color(0xFFEA580C),
        highlightColor: Color(0xFFFFEDD5),
        icon: Icons.local_fire_department_rounded,
        emoji: '🔥',
      );
    }
    // 0.2. Водоснабжение и канализация
    if (cat.contains('водоснабж') || cat.contains('канализац')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0C4A6E)],
        shadowColor: Color(0xFF0284C7),
        highlightColor: Color(0xFFE0F2FE),
        icon: Icons.water_drop_rounded,
        emoji: '💧',
      );
    }
    // 0.3. Отопление
    if (cat.contains('отоплен') || cat.contains('тепло')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFF991B1B)],
        shadowColor: Color(0xFFEF4444),
        highlightColor: Color(0xFFFEE2E2),
        icon: Icons.thermostat_rounded,
        emoji: '🌡️',
      );
    }
    // 0.4. Социальная сфера / Трудовое право
    if (cat.contains('социальн') || cat.contains('труд') || cat.contains('право')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFC084FC), Color(0xFF9333EA), Color(0xFF581C87)],
        shadowColor: Color(0xFF9333EA),
        highlightColor: Color(0xFFF3E8FF),
        icon: Icons.groups_rounded,
        emoji: '👥',
      );
    }
    // 0.5. Благоустройство / Дворы / Парки / Скамейки
    if (cat.contains('благоустройст') || cat.contains('парк') || cat.contains('сквер') || cat.contains('двор') || cat.contains('площадк')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF064E3B)],
        shadowColor: Color(0xFF10B981),
        highlightColor: Color(0xFFA7F3D0),
        icon: Icons.park_rounded,
        emoji: '🏞️',
      );
    }
    // 1. ДТП / Аварии
    if (cat.contains('дтп') || cat.contains('авар')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFF6B6B), Color(0xFFEF4444), Color(0xFF991B1B)],
        shadowColor: Color(0xFFFF4444),
        highlightColor: Color(0xFFFFCDD2),
        icon: Icons.car_crash_rounded,
        emoji: '🚗',
      );
    }
    // 2. ЖКХ / Водопровод / Отопление
    if (cat.contains('жкх') || cat.contains('коммун') || cat.contains('лифт')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF1E40AF)],
        shadowColor: Color(0xFF3B82F6),
        highlightColor: Color(0xFFBFDBFE),
        icon: Icons.plumbing_rounded,
        emoji: '🔧',
      );
    }
    // 3. Дороги / Ямы
    if (cat.contains('дорог') || cat.contains('яма') || cat.contains('асфальт')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFF92400E)],
        shadowColor: Color(0xFFF59E0B),
        highlightColor: Color(0xFFFDE68A),
        icon: Icons.construction_rounded,
        emoji: '🚧',
      );
    }
    // 4. Освещение / Свет
    if (cat.contains('свет') || cat.contains('освещ') || cat.contains('фонар')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFDE68A), Color(0xFFFACC15), Color(0xFF713F12)],
        shadowColor: Color(0xFFFACC15),
        highlightColor: Color(0xFFFEFBE4),
        icon: Icons.lightbulb_rounded,
        emoji: '💡',
      );
    }
    // 5. Экология
    if (cat.contains('экол') || cat.contains('природ') || cat.contains('дерев') || cat.contains('зелен')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF6EE7B7), Color(0xFF10B981), Color(0xFF065F46)],
        shadowColor: Color(0xFF10B981),
        highlightColor: Color(0xFFD1FAE5),
        icon: Icons.eco_rounded,
        emoji: '🌿',
      );
    }
    // 6. Общественный транспорт
    if (cat.contains('транспорт') || cat.contains('автобус') || cat.contains('маршрут')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFA78BFA), Color(0xFF7C3AED), Color(0xFF3B0764)],
        shadowColor: Color(0xFF7C3AED),
        highlightColor: Color(0xFFEDE9FE),
        icon: Icons.directions_bus_rounded,
        emoji: '🚌',
      );
    }
    // 7. Мероприятия / События / Фильмы
    if (cat.contains('меропр') || cat.contains('событ') || cat.contains('афиш') || cat.contains('кино')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF9A8D4), Color(0xFFEC4899), Color(0xFF831843)],
        shadowColor: Color(0xFFEC4899),
        highlightColor: Color(0xFFFCE7F3),
        icon: Icons.celebration_rounded,
        emoji: '🎉',
      );
    }
    // 8. Камеры видеонаблюдения
    if (cat.contains('камер') || cat.contains('cctv') || cat.contains('видео')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF94A3B8), Color(0xFF475569), Color(0xFF0F172A)],
        shadowColor: Color(0xFF475569),
        highlightColor: Color(0xFFE2E8F0),
        icon: Icons.videocam_rounded,
        emoji: '📷',
      );
    }
    // 9. Животные (Собаки/Кошки)
    if (cat.contains('животн') || cat.contains('собак') || cat.contains('кошк') || cat.contains('пёс')) {
      if (tLower.contains('кош') || tLower.contains('кот') || tLower.contains('кис')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFF7C2D12)],
          shadowColor: Color(0xFFF97316),
          highlightColor: Color(0xFFFFEDD5),
          icon: Icons.pets_rounded,
          emoji: '🐈',
        );
      }
      if (tLower.contains('собак') || tLower.contains('пес') || tLower.contains('пёс') || tLower.contains('щен') || tLower.contains('лайк')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFF7C2D12)],
          shadowColor: Color(0xFFF97316),
          highlightColor: Color(0xFFFFEDD5),
          icon: Icons.pets_rounded,
          emoji: '🐕',
        );
      }
      if (tLower.contains('птиц') || tLower.contains('вороб') || tLower.contains('голуб') || tLower.contains('попуг')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFF7C2D12)],
          shadowColor: Color(0xFFF97316),
          highlightColor: Color(0xFFFFEDD5),
          icon: Icons.pets_rounded,
          emoji: '🐦',
        );
      }
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFF7C2D12)],
        shadowColor: Color(0xFFF97316),
        highlightColor: Color(0xFFFFEDD5),
        icon: Icons.pets_rounded,
        emoji: '🐾',
      );
    }
    // 10. Вещи / Бюро находок
    if (cat.contains('вещ') || cat.contains('находк') || cat.contains('потер') || cat.contains('кошелек')) {
      if (tLower.contains('ключ')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.vpn_key_rounded,
          emoji: '🔑',
        );
      }
      if (tLower.contains('телефон') || tLower.contains('смартфон') || tLower.contains('айфон') || tLower.contains('iphone')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.phone_android_rounded,
          emoji: '📱',
        );
      }
      if (tLower.contains('карт') || tLower.contains('паспорт') || tLower.contains('документ') || tLower.contains('права') || tLower.contains('снилс')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.badge_rounded,
          emoji: '🪪',
        );
      }
      if (tLower.contains('кошель') || tLower.contains('портмоне') || tLower.contains('деньг') || tLower.contains('купюр')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.account_balance_wallet_rounded,
          emoji: '👛',
        );
      }
      if (tLower.contains('велосипед') || tLower.contains('самокат')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.pedal_bike_rounded,
          emoji: '🚲',
        );
      }
      if (tLower.contains('наушник')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.headphones_rounded,
          emoji: '🎧',
        );
      }
      if (tLower.contains('очк')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.visibility_rounded,
          emoji: '👓',
        );
      }
      if (tLower.contains('зонт')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.umbrella_rounded,
          emoji: '🌂',
        );
      }
      if (tLower.contains('час')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.watch_rounded,
          emoji: '⌚',
        );
      }
      if (tLower.contains('сумка') || tLower.contains('рюкзак') || tLower.contains('пакет')) {
        return const _CategoryIcon3DConfig(
          gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
          shadowColor: Color(0xFF0D9488),
          highlightColor: Color(0xFFCCFBF1),
          icon: Icons.shopping_bag_rounded,
          emoji: '👜',
        );
      }
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF6EE7B7), Color(0xFF0D9488), Color(0xFF115E59)],
        shadowColor: Color(0xFF0D9488),
        highlightColor: Color(0xFFCCFBF1),
        icon: Icons.shopping_bag_rounded,
        emoji: '🎒',
      );
    }
    // 11. Мусор / Свалки / Контейнеры
    if (cat.contains('мусор') || cat.contains('свалк') || cat.contains('отход') || cat.contains('помойка')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF9CA3AF), Color(0xFF4B5563), Color(0xFF1F2937)],
        shadowColor: Color(0xFF4B5563),
        highlightColor: Color(0xFFF3F4F6),
        icon: Icons.delete_outline_rounded,
        emoji: '🗑️',
      );
    }
    // 12. Снег / Лед / Гололед
    if (cat.contains('снег') || cat.contains('лед') || cat.contains('налед') || cat.contains('сугроб')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0369A1)],
        shadowColor: Color(0xFF38BDF8),
        highlightColor: Colors.white,
        icon: Icons.ac_unit_rounded,
        emoji: '❄️',
      );
    }
    // 13. Пожары / Дым
    if (cat.contains('пожар') || cat.contains('дым') || cat.contains('огонь') || cat.contains('возгоран')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFCA5A5), Color(0xFFEF4444), Color(0xFF7F1D1D)],
        shadowColor: Color(0xFFEF4444),
        highlightColor: Color(0xFFFEF2F2),
        icon: Icons.local_fire_department_rounded,
        emoji: '🔥',
      );
    }
    // 14. Затопления / Протечки воды
    if (cat.contains('затопл') || cat.contains('потоп') || cat.contains('протеч') || cat.contains('вода')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF7DD3FC), Color(0xFF0284C7), Color(0xFF0F172A)],
        shadowColor: Color(0xFF0284C7),
        highlightColor: Color(0xFFF0F9FF),
        icon: Icons.water_drop_rounded,
        emoji: '💧',
      );
    }
    // 15. Безопасность / Правопорядок / Драка
    if (cat.contains('безопасн') || cat.contains('полиц') || cat.contains('драка') || cat.contains('хулиган')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF93C5FD), Color(0xFF2563EB), Color(0xFF1E3A8A)],
        shadowColor: Color(0xFF2563EB),
        highlightColor: Color(0xFFEFF6FF),
        icon: Icons.shield_rounded,
        emoji: '🛡️',
      );
    }
    // 16. Парковки / Газоны
    if (cat.contains('парковк') || cat.contains('газон') || cat.contains('стоянк')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF14532D)],
        shadowColor: Color(0xFF22C55E),
        highlightColor: Color(0xFFF0FDF4),
        icon: Icons.local_parking_rounded,
        emoji: '🅿️',
      );
    }
    // 17. Шум / Громкая музыка
    if (cat.contains('шум') || cat.contains('громко') || cat.contains('музык')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF472B6), Color(0xFFDB2777), Color(0xFF5B0727)],
        shadowColor: Color(0xFFDB2777),
        highlightColor: Color(0xFFFDF2F8),
        icon: Icons.volume_up_rounded,
        emoji: '📢',
      );
    }
    // 18. Медицина / Больницы
    if (cat.contains('медицин') || cat.contains('больниц') || cat.contains('аптек') || cat.contains('врач')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFCA5A5), Color(0xFFDC2626), Color(0xFF7F1D1D)],
        shadowColor: Color(0xFFDC2626),
        highlightColor: Color(0xFFFEF2F2),
        icon: Icons.local_hospital_rounded,
        emoji: '🏥',
      );
    }
    // 19. Дети / Детские площадки / Школы
    if (cat.contains('дет') || cat.contains('площадк') || cat.contains('школ') || cat.contains('сад')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFDE047), Color(0xFFCA8A04), Color(0xFF713F12)],
        shadowColor: Color(0xFFCA8A04),
        highlightColor: Color(0xFFFEFCE8),
        icon: Icons.child_care_rounded,
        emoji: '🎪',
      );
    }
    // 20. Стройка / Строительство
    if (cat.contains('стройк') || cat.contains('строит') || cat.contains('забор')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFFDBA74), Color(0xFFD97706), Color(0xFF7C2D12)],
        shadowColor: Color(0xFFD97706),
        highlightColor: Color(0xFFFFF7ED),
        icon: Icons.business_rounded,
        emoji: '🏗️',
      );
    }
    // 21. Торговля / Рынки
    if (cat.contains('торговл') || cat.contains('рынок') || cat.contains('магазин') || cat.contains('киоск')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFC084FC), Color(0xFF9333EA), Color(0xFF581C87)],
        shadowColor: Color(0xFF9333EA),
        highlightColor: Color(0xFFFAF5FF),
        icon: Icons.storefront_rounded,
        emoji: '🏪',
      );
    }
    // 22. Спорт / Стадионы
    if (cat.contains('спорт') || cat.contains('стадион') || cat.contains('площадк') || cat.contains('тренажер')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF6EE7B7), Color(0xFF059669), Color(0xFF064E3B)],
        shadowColor: Color(0xFF059669),
        highlightColor: Color(0xFFECFDF5),
        icon: Icons.sports_soccer_rounded,
        emoji: '⚽',
      );
    }
    // 23. Вандализм / Граффити / Реклама
    if (cat.contains('вандал') || cat.contains('граффит') || cat.contains('реклам') || cat.contains('объявлен')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFF7F1D1D)],
        shadowColor: Color(0xFFDC2626),
        highlightColor: Color(0xFFFEF2F2),
        icon: Icons.format_paint_rounded,
        emoji: '🎨',
      );
    }
    // 24. Связь / Интернет
    if (cat.contains('связь') || cat.contains('интернет') || cat.contains('кабел') || cat.contains('провайдер')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0C4A6E)],
        shadowColor: Color(0xFF0284C7),
        highlightColor: Color(0xFFF0F9FF),
        icon: Icons.wifi_tethering_rounded,
        emoji: '🔌',
      );
    }
    // 25. Туризм / Достопримечательности / Парки
    if (cat.contains('туризм') || cat.contains('памятн') || cat.contains('парк') || cat.contains('сквер')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFF4ADE80), Color(0xFF16A34A), Color(0xFF14532D)],
        shadowColor: Color(0xFF16A34A),
        highlightColor: Color(0xFFF0FDF4),
        icon: Icons.forest_rounded,
        emoji: '🌳',
      );
    }
    // 26. Культура / Музеи / Театры
    if (cat.contains('культур') || cat.contains('музей') || cat.contains('театр') || cat.contains('библиот')) {
      return const _CategoryIcon3DConfig(
        gradient: [Color(0xFFF472B6), Color(0xFFC084FC), Color(0xFF581C87)],
        shadowColor: Color(0xFFC084FC),
        highlightColor: Color(0xFFFAF5FF),
        icon: Icons.museum_rounded,
        emoji: '🏛️',
      );
    }
    // 27. Прочее / Другое
    return const _CategoryIcon3DConfig(
      gradient: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF0C4A6E)],
      shadowColor: Color(0xFF0EA5E9),
      highlightColor: Color(0xFFE0F2FE),
      icon: Icons.info_rounded,
      emoji: '📌',
    );
  }
}

class _Icon3DPainter extends CustomPainter {
  final _CategoryIcon3DConfig config;
  final bool isActive;

  const _Icon3DPainter({required this.config, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // === Outer glow ===
    if (isActive) {
      final glowPaint = Paint()
        ..color = config.shadowColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 2, glowPaint);
    }

    // === Shadow disc (3D depth effect) ===
    final shadowPaint = Paint()
      ..color = config.shadowColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 3, center.dy + 5),
        width: radius * 1.8,
        height: radius * 0.5,
      ),
      shadowPaint,
    );

    // === Main sphere body ===
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.9,
      colors: [
        config.highlightColor.withOpacity(0.95),
        config.gradient[0],
        config.gradient[1],
        config.gradient[2],
      ],
      stops: const [0.0, 0.25, 0.6, 1.0],
    );

    final bodyPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, bodyPaint);

    // === Rim light (bottom-right bright edge) ===
    final rimGradient = RadialGradient(
      center: const Alignment(0.6, 0.6),
      radius: 0.55,
      colors: [
        config.gradient[0].withOpacity(0.6),
        Colors.transparent,
      ],
    );
    final rimPaint = Paint()
      ..shader = rimGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, rimPaint);

    // === Specular highlight (top-left bright spot) ===
    final highlightCenter = Offset(
      center.dx - radius * 0.28,
      center.dy - radius * 0.32,
    );
    final highlightGradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0.0),
      ],
    );
    final hlPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: highlightCenter, radius: radius * 0.4),
      );
    canvas.drawCircle(highlightCenter, radius * 0.4, hlPaint);

    // === Border ring ===
    final borderPaint = Paint()
      ..color = config.gradient[0].withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(_Icon3DPainter old) =>
      old.config != config || old.isActive != isActive;
}

/// Wrapper that combines 3D sphere + emoji icon overlay
class Category3DBadge extends StatelessWidget {
  final String category;
  final String? title;
  final double size;
  final bool isActive;

  const Category3DBadge({
    super.key,
    required this.category,
    this.title,
    this.size = 54,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _CategoryIcon3DConfig.forCategory(category, title);
    final iconSize = size * 0.42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CategoryIcon3D(category: category, title: title, size: size, isActive: isActive),
          Text(
            config.emoji,
            style: TextStyle(
              fontSize: iconSize,
              // Slight top-left shadow to simulate 3D depth
              shadows: [
                Shadow(
                  color: config.shadowColor.withOpacity(0.5),
                  offset: const Offset(1.5, 2),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Demo grid of all category icons
class CategoryIconsDemo extends StatelessWidget {
  const CategoryIconsDemo({super.key});

  static const _categories = [
    'ДТП',
    'ЖКХ',
    'Дороги',
    'Освещение',
    'Экология',
    'Транспорт',
    'Мероприятия',
    'Камеры',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _categories.map((cat) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Category3DBadge(category: cat, size: 60),
            const SizedBox(height: 4),
            Text(
              cat,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

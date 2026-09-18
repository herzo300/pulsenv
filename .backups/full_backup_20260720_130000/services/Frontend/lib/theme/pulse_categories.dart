import 'package:flutter/material.dart';

import 'pulse_category_colors.dart';

/// Shared category names aligned with `public/map_script.js` CATEGORIES.
abstract final class PulseCategories {
  static const Map<String, String> aliases = {
    'ЧС и аварии': 'ЧП',
    'Бытовой мусор': 'Мусор',
    'Здравоохранение': 'Медицина',
  };

  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Прочее';
    return aliases[trimmed] ?? trimmed;
  }

  static Color colorFor(String? category) =>
      PulseCategoryColors.forCategory(normalize(category ?? ''));

  static IconData iconFor(String? category) {
    final name = normalize(category ?? '');
    return _icons[name] ?? Icons.report_problem_outlined;
  }

  /// Complaint form + API categories (web-aligned).
  static const List<String> formCategories = [
    'ЧП',
    'ЖКХ',
    'Благоустройство',
    'Дороги',
    'Освещение',
    'Транспорт',
    'Экология',
    'Безопасность',
    'Снег/Наледь',
    'Медицина',
    'Образование',
    'Парковки',
    'Строительство',
    'Животные',
    'Вещи',
    'Мероприятие',
    'Прочее',
  ];


  /// Map filter dropdown (most common civic layers).
  static List<(String, IconData, Color)> get mapFilterOptions => [
        for (final name in const [
          'ЧП',
          'ЖКХ',
          'Благоустройство',
          'Дороги',
          'Освещение',
          'Транспорт',
          'Экология',
          'Безопасность',
          'Снег/Наледь',
          'Медицина',
          'Образование',
          'Парковки',
          'Строительство',
          'Животные',
          'Вещи',
          'Мероприятие',
          'Прочее',
        ])
          (name, iconFor(name), colorFor(name)),
      ];

  static const Map<String, IconData> _icons = {
    'ЧП': Icons.warning_rounded,
    'ЖКХ': Icons.plumbing_rounded,
    'Дороги': Icons.edit_road_rounded,
    'Благоустройство': Icons.nature_people_rounded,
    'Транспорт': Icons.commute_rounded,
    'Освещение': Icons.lightbulb_rounded,
    'Газоснабжение': Icons.gas_meter_rounded,
    'Водоснабжение и канализация': Icons.plumbing_rounded,
    'Отопление': Icons.thermostat_rounded,
    'Связь': Icons.sensors_rounded,
    'Мусор': Icons.delete_sweep_rounded,
    'Экология': Icons.eco_rounded,
    'Детские площадки': Icons.child_care_rounded,
    'Спортивные площадки': Icons.sports_rounded,
    'Парки и скверы': Icons.forest_rounded,
    'Парковки': Icons.local_parking_rounded,
    'Лифты и подъезды': Icons.elevator_rounded,
    'Строительство': Icons.engineering_rounded,
    'Безопасность': Icons.shield_rounded,
    'Снег/Наледь': Icons.ac_unit_rounded,
    'Медицина': Icons.medical_services_rounded,
    'Образование': Icons.school_rounded,
    'Социальная сфера': Icons.people_alt_rounded,
    'Животные': Icons.pets_rounded,
    'Вещи': Icons.shopping_bag_rounded,
    'Торговля': Icons.storefront_rounded,
    'Трудовое право': Icons.badge_rounded,
    'Мероприятие': Icons.celebration_rounded,
    'Камеры': Icons.videocam_rounded,
    'Бюро находок': Icons.manage_search_rounded,
    'Прочее': Icons.more_horiz_rounded,
  };
}

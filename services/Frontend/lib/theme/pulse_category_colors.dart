import 'package:flutter/material.dart';

import 'pulse_colors.dart';

/// Map / web category colors aligned with `public/map_script.js` CATEGORIES.
abstract final class PulseCategoryColors {
  static final Map<String, Color> byName = {
    'ЧП': Color(0xFFFF3D00),
    'ЖКХ': Color(0xFFF97316),
    'Дороги': Color(0xFFEF4444),
    'Благоустройство': Color(0xFF22C55E),
    'Транспорт': Color(0xFF0EA5C7),
    'Освещение': Color(0xFFEAB308),
    'Газоснабжение': Color(0xFFF97316),
    'Водоснабжение и канализация': Color(0xFF0EA5E9),
    'Отопление': Color(0xFFF43F5E),
    'Связь': Color(0xFF6366F1),
    'Мусор': Color(0xFF84CC16),
    'Бытовой мусор': Color(0xFF84CC16),
    'Экология': Color(0xFF00E676),
    'Детские площадки': Color(0xFFEC4899),
    'Спортивные площадки': Color(0xFF8B5CF6),
    'Парки и скверы': Color(0xFF059669),
    'Парковки': Color(0xFF6366F1),
    'Лифты и подъезды': Color(0xFF64748B),
    'Строительство': Color(0xFFD97706),
    'Безопасность': Color(0xFFFF3D00),
    'Снег/Наледь': Color(0xFF38BDF8),
    'Медицина': PulseColors.primary,
    'Здравоохранение': PulseColors.primary,
    'Образование': Color(0xFF8B5CF6),
    'Социальная сфера': Color(0xFF6366F1),
    'Животные': Color(0xFFF59E0B),
    'Вещи': Color(0xFF8B5CF6),
    'Торговля': Color(0xFF00E676),
    'Трудовое право': Color(0xFF64748B),
    'Мероприятие': Color(0xFFD946EF),
    'Камеры': Color(0xFF6366F1),
    'Бюро находок': Color(0xFFD946EF),
    'ЧС и аварии': Color(0xFFFF3D00),
    'Прочее': Color(0xFF64748B),
  };

  static Color forCategory(String? category) {
    if (category == null || category.isEmpty) {
      return byName['Прочее']!;
    }
    final normalized = PulseCategoriesAliases.resolve(category);
    return byName[normalized] ?? byName[category] ?? byName['Прочее']!;
  }

  static Color statusColor(String? status) {
    switch (status) {
      case 'resolved':
      case 'closed':
        return PulseColors.success;
      case 'in_progress':
        return PulseColors.warning;
      case 'open':
      case 'pending':
      default:
        return PulseColors.primary;
    }
  }
}

/// Avoid circular import with pulse_categories.dart.
abstract final class PulseCategoriesAliases {
  static String resolve(String raw) {
    const aliases = {
      'ЧС и аварии': 'ЧП',
      'Бытовой мусор': 'Мусор',
      'Здравоохранение': 'Медицина',
    };
    final trimmed = raw.trim();
    return aliases[trimmed] ?? trimmed;
  }
}

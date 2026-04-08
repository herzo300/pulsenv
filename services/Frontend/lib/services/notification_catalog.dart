import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';

class NotificationCategoryDescriptor {
  const NotificationCategoryDescriptor({
    required this.name,
    required this.icon,
    required this.color,
    required this.soundAsset,
    this.aliases = const <String>[],
  });

  final String name;
  final IconData icon;
  final Color color;
  final String soundAsset;
  final List<String> aliases;
}

class NotificationCatalog {
  NotificationCatalog._();

  static const List<NotificationCategoryDescriptor> _defaults = [
    NotificationCategoryDescriptor(
      name: 'ЖКХ',
      icon: Icons.apartment_rounded,
      color: PulseColors.primary,
      soundAsset: 'cat_zhkh.wav',
      aliases: ['Водоснабжение и канализация', 'Отопление', 'Лифты и подъезды', 'Бытовой мусор'],
    ),
    NotificationCategoryDescriptor(
      name: 'Дороги',
      icon: Icons.car_repair_rounded,
      color: PulseColors.negative,
      soundAsset: 'cat_roads.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Благоустройство',
      icon: Icons.park_rounded,
      color: Color(0xFF8BC34A),
      soundAsset: 'cat_garden.wav',
      aliases: ['Парки и скверы', 'Детские площадки', 'Спортивные площадки'],
    ),
    NotificationCategoryDescriptor(
      name: 'Транспорт',
      icon: Icons.directions_bus_rounded,
      color: Color(0xFF60A5FA),
      soundAsset: 'cat_transport.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Экология',
      icon: Icons.eco_rounded,
      color: PulseColors.success,
      soundAsset: 'cat_ecology.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Безопасность',
      icon: Icons.shield_outlined,
      color: PulseColors.warning,
      soundAsset: 'cat_safety.wav',
      aliases: ['ЧП'],
    ),
    NotificationCategoryDescriptor(
      name: 'Освещение',
      icon: Icons.lightbulb_outline_rounded,
      color: Color(0xFFFDE047),
      soundAsset: 'cat_light.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Снег/Наледь',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF38BDF8),
      soundAsset: 'cat_snow.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Медицина',
      icon: Icons.local_hospital_outlined,
      color: Color(0xFFFB7185),
      soundAsset: 'cat_med.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Образование',
      icon: Icons.school_rounded,
      color: Color(0xFF818CF8),
      soundAsset: 'cat_edu.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Парковки',
      icon: Icons.local_parking_rounded,
      color: Color(0xFFD6A36F),
      soundAsset: 'cat_parking.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Животные',
      icon: Icons.pets_rounded,
      color: Color(0xFFA78BFA),
      soundAsset: 'cat_other.wav',
    ),
    NotificationCategoryDescriptor(
      name: 'Прочее',
      icon: Icons.more_horiz_rounded,
      color: PulseColors.neutral,
      soundAsset: 'cat_other.wav',
      aliases: ['Социальная сфера', 'Торговля', 'Связь', 'Строительство', 'Трудовое право'],
    ),
  ];

  static final Map<String, NotificationCategoryDescriptor> _lookup = () {
    final map = <String, NotificationCategoryDescriptor>{};
    for (final descriptor in _defaults) {
      map[_normalizeKey(descriptor.name)] = descriptor;
      for (final alias in descriptor.aliases) {
        map[_normalizeKey(alias)] = descriptor;
      }
    }
    return map;
  }();

  static List<NotificationCategoryDescriptor> get defaults =>
      List<NotificationCategoryDescriptor>.unmodifiable(_defaults);

  static String normalize(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) {
      return 'Прочее';
    }
    final descriptor = _lookup[_normalizeKey(rawCategory)];
    return descriptor?.name ?? rawCategory.trim();
  }

  static NotificationCategoryDescriptor describe(String? rawCategory) {
    final normalized = normalize(rawCategory);
    return _lookup[_normalizeKey(normalized)] ??
        const NotificationCategoryDescriptor(
          name: 'Прочее',
          icon: Icons.more_horiz_rounded,
          color: PulseColors.neutral,
          soundAsset: 'cat_other.wav',
        );
  }

  static List<NotificationCategoryDescriptor> mergeServerCategories(
    Iterable<String> categories,
  ) {
    final result = <NotificationCategoryDescriptor>[];
    final seen = <String>{};

    for (final descriptor in _defaults) {
      final normalized = descriptor.name;
      seen.add(normalized);
      result.add(descriptor);
    }

    for (final rawName in categories) {
      final normalized = normalize(rawName);
      if (seen.add(normalized)) {
        result.add(
          NotificationCategoryDescriptor(
            name: normalized,
            icon: describe(normalized).icon,
            color: describe(normalized).color,
            soundAsset: describe(normalized).soundAsset,
          ),
        );
      }
    }

    return result;
  }

  static String _normalizeKey(String value) => value.trim().toLowerCase();
}

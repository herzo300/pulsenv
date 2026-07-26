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

  static List<NotificationCategoryDescriptor> _defaults = [
    NotificationCategoryDescriptor(
      name: 'ЧП',
      icon: Icons.warning_rounded,
      color: PulseColors.negative,
      soundAsset: 'cat_safety.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'ЖКХ',
      icon: Icons.home_work_rounded,
      color: PulseColors.primary,
      soundAsset: 'cat_zhkh.mp3',
      aliases: ['Водоснабжение и канализация', 'Отопление', 'Лифты и подъезды', 'Бытовой мусор', 'Мусор', 'Газоснабжение'],
    ),
    NotificationCategoryDescriptor(
      name: 'Дороги',
      icon: Icons.edit_road_rounded,
      color: PulseColors.negative,
      soundAsset: 'cat_roads.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Освещение',
      icon: Icons.lightbulb_rounded,
      color: const Color(0xFFFDE047),
      soundAsset: 'cat_light.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Транспорт',
      icon: Icons.directions_bus_rounded,
      color: const Color(0xFF60A5FA),
      soundAsset: 'cat_transport.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Экология',
      icon: Icons.eco_rounded,
      color: PulseColors.success,
      soundAsset: 'cat_ecology.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Безопасность',
      icon: Icons.shield_rounded,
      color: PulseColors.warning,
      soundAsset: 'cat_safety.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Снег/Наледь',
      icon: Icons.ac_unit_rounded,
      color: const Color(0xFF38BDF8),
      soundAsset: 'cat_snow.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Медицина',
      icon: Icons.medical_services_rounded,
      color: const Color(0xFFFB7185),
      soundAsset: 'cat_med.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Образование',
      icon: Icons.school_rounded,
      color: const Color(0xFF818CF8),
      soundAsset: 'cat_edu.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Парковки',
      icon: Icons.local_parking_rounded,
      color: const Color(0xFFD6A36F),
      soundAsset: 'cat_parking.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Строительство',
      icon: Icons.construction_rounded,
      color: const Color(0xFFFFC857),
      soundAsset: 'cat_roads.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Животные',
      icon: Icons.pets_rounded,
      color: const Color(0xFFA78BFA),
      soundAsset: 'cat_animals.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Вещи',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF8B5CF6),
      soundAsset: 'cat_other.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Мероприятие',
      icon: Icons.local_activity_rounded,
      color: const Color(0xFFD946EF),
      soundAsset: 'cat_event.mp3',
    ),
    NotificationCategoryDescriptor(
      name: 'Прочее',
      icon: Icons.more_horiz_rounded,
      color: PulseColors.neutral,
      soundAsset: 'cat_other.mp3',
      aliases: ['Социальная сфера', 'Торговля', 'Связь', 'Трудовое право', 'Благоустройство'],
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
          soundAsset: 'cat_other.mp3',
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

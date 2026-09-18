// lib/core/living/aura_theme_catalog.dart
//
// Каталог 10 премиальных тем для движка AuraLivingBackground.
//
// Каждая тема — продуманный арт-образ: комбинация шейдера (AuraWeather),
// фирменной палитры (4 цвета: фон, акцент1, акцент2, блик) и тюнинга
// параметров (speed/bloom/blur/particleDensity). Названия отражают характер.
//
// Темы:
//   1. Северное Сияние (Aurora Borealis) — полярная магия
//   2. Неоновый Токио (Neon Tokyo) — киберпанк-дождь
//   3. Золотая Сакура (Golden Sakura) — тёплая весна
//   4. Глубокий Космос (Deep Cosmos) — медитативная бесконечность
//   5. Жидкое Золото (Liquid Gold) — роскошь, премиум
//   6. Полярная Ночь (Polar Night) — ледяная тишина
//   7. Жар-Птица (Phoenix Fire) — пламенное возрождение
//   8. Изумрудный Лес (Emerald Forest) — природное спокойствие
//   9. Голубая Лагуна (Blue Lagoon) — тропический покой
//  10. Квантовый Голограмм (Quantum Hologram) — футуристичный интерфейс
//
// Выбор темы персистентный (SharedPreferences) через AuraThemeService.
import 'package:flutter/material.dart';

import 'aura_living_engine.dart';

/// Именованная премиум-тема.
class AuraTheme {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  /// Базовый шейдер движка.
  final AuraWeather weather;

  /// Фирменная палитра: [фон, акцент1, акцент2, блик].
  final List<Color> palette;

  /// Параметры тюнинга атмосферы.
  final double speed;
  final double bloom;
  final double blur;
  final double particleDensity;
  final double depth;

  /// Премиум-сигнатура (дополнительные частицы/свечение).
  final bool premiumSignature;

  /// Цвет для превью-чипа в пикере (акцент1).
  Color get previewColor => palette.length > 1 ? palette[1] : const Color(0xFF4AD7B8);

  const AuraTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.weather,
    required this.palette,
    this.speed = 1.0,
    this.bloom = 0.55,
    this.blur = 16,
    this.particleDensity = 0.5,
    this.depth = 0.55,
    this.premiumSignature = false,
  });

  /// Построить сцену для AuraLivingBackground.
  AuraLivingScene toScene({String? backgroundImage}) {
    return AuraLivingScene(
      weather: weather,
      practice: AuraPractice.premium,
      palette: palette,
      speed: speed,
      bloom: bloom,
      blur: blur,
      particleDensity: particleDensity,
      depth: depth,
      premiumSignature: premiumSignature,
      backgroundImage: backgroundImage,
    );
  }
}

/// Каталог всех тем. Порядок = порядок в пикере.
abstract final class AuraThemeCatalog {
  AuraThemeCatalog._();

  /// Дефолтная тема (используется если выбор не задан).
  static const defaultTheme = auroraBorealis;

  static const auroraBorealis = AuraTheme(
    id: 'aurora_borealis',
    name: 'Северное Сияние',
    subtitle: 'Полярная магия',
    icon: Icons.nights_stay_rounded,
    weather: AuraWeather.aurora,
    palette: [
      Color(0xFF001428), // глубокая полярная ночь
      Color(0xFF00FF87), // изумрудный зелёный сияния
      Color(0xFF6EA8FF), // ледяной голубой
      Color(0xFFE8C547), // золотая россыпь звёзд
    ],
    speed: 0.7,
    bloom: 0.65,
    blur: 18,
    particleDensity: 0.55,
    depth: 0.6,
    premiumSignature: true,
  );

  static const neonTokyo = AuraTheme(
    id: 'neon_tokyo',
    name: 'Неоновый Токио',
    subtitle: 'Киберпанк-дождь',
    icon: Icons.bolt_rounded,
    weather: AuraWeather.cyberpunk,
    palette: [
      Color(0xFF0A0014), // чёрно-фиолетовая ночь
      Color(0xFFFF006E), // магента-неон
      Color(0xFF00F5FF), // циан-неон
      Color(0xFFFFEA00), // кислотный жёлтый
    ],
    speed: 1.3,
    bloom: 0.75,
    blur: 12,
    particleDensity: 0.7,
    depth: 0.5,
    premiumSignature: true,
  );

  static const goldenSakura = AuraTheme(
    id: 'golden_sakura',
    name: 'Золотая Сакура',
    subtitle: 'Тёплая весна',
    icon: Icons.local_florist_rounded,
    weather: AuraWeather.sakura,
    palette: [
      Color(0xFF1A0F0A), // тёплый коричневый фон
      Color(0xFFFFB7C5), // нежно-розовый лепесток
      Color(0xFFFFD700), // золотое солнце
      Color(0xFFFF8C69), // персиковый закат
    ],
    speed: 0.6,
    bloom: 0.55,
    blur: 16,
    particleDensity: 0.6,
    depth: 0.5,
    premiumSignature: true,
  );

  static const deepCosmos = AuraTheme(
    id: 'deep_cosmos',
    name: 'Глубокий Космос',
    subtitle: 'Медитативная бесконечность',
    icon: Icons.auto_awesome_rounded,
    weather: AuraWeather.cosmos,
    palette: [
      Color(0xFF050010), // абсолютная пустота
      Color(0xFF7B2CBF), // фиолетовая туманность
      Color(0xFFFF6AAE), // розовая сверхновая
      Color(0xFF80D8FF), // голубые далёкие звёзды
    ],
    speed: 0.4,
    bloom: 0.7,
    blur: 20,
    particleDensity: 0.45,
    depth: 0.75,
    premiumSignature: true,
  );

  static const stellarNebula = AuraTheme(
    id: 'stellar_nebula',
    name: 'Звёздная Туманность',
    subtitle: 'Пыль сверхновых и магента',
    icon: Icons.blur_on_rounded,
    weather: AuraWeather.nebula,
    palette: [
      Color(0xFF0A0018), // глубокий космический вакуум
      Color(0xFFFF007F), // неоновая магента
      Color(0xFF7928CA), // фиолетовый ультрафиолет
      Color(0xFF00DFD8), // сияющий аквамарин
    ],
    speed: 0.65,
    bloom: 0.8,
    blur: 16,
    particleDensity: 0.6,
    depth: 0.7,
    premiumSignature: true,
  );

  static const digitalGravity = AuraTheme(
    id: 'digital_gravity',
    name: 'Цифровая Гравитация',
    subtitle: 'Сингулярность и горизонт событий',
    icon: Icons.all_inclusive_rounded,
    weather: AuraWeather.blackHole,
    palette: [
      Color(0xFF02040A), // гравитационная пустота
      Color(0xFF00E5FF), // электрический горизонт
      Color(0xFF3B82F6), // релятивистский синий
      Color(0xFF10B981), // квантовый изумруд
    ],
    speed: 0.8,
    bloom: 0.75,
    blur: 12,
    particleDensity: 0.65,
    depth: 0.8,
    premiumSignature: true,
  );

  static const liquidGold = AuraTheme(
    id: 'liquid_gold',
    name: 'Жидкое Золото',
    subtitle: 'Расплавленное золото Югры',
    icon: Icons.monetization_on_rounded,
    weather: AuraWeather.fluid,
    palette: [
      Color(0xFF1A1000), // тёмная бронза
      Color(0xFFFFD700), // чистое золото
      Color(0xFFB8860B), // тёмное золото
      Color(0xFFFFF8DC), // кремовый блик
    ],
    speed: 0.5,
    bloom: 0.6,
    blur: 14,
    particleDensity: 0.5,
    depth: 0.65,
    premiumSignature: true,
  );

  static const premiumGlass = AuraTheme(
    id: 'premium_glass',
    name: 'Дорогое Стекло',
    subtitle: 'Сапфировый матовый хрусталь',
    icon: Icons.diamond_rounded,
    weather: AuraWeather.voronoi,
    palette: [
      Color(0xFF070D18), // глубокий сапфир
      Color(0xFF93C5FD), // призматический лед
      Color(0xFFE2E8F0), // шелковистый блик стекла
      Color(0xFFFFFFFF), // алмазный свет
    ],
    speed: 0.35,
    bloom: 0.5,
    blur: 24,
    particleDensity: 0.4,
    depth: 0.6,
    premiumSignature: true,
  );

  static const polarNight = AuraTheme(
    id: 'polar_night',
    name: 'Полярная Ночь',
    subtitle: 'Ледяная тишина',
    icon: Icons.ac_unit_rounded,
    weather: AuraWeather.snow,
    palette: [
      Color(0xFF0A1622), // морозная тьма
      Color(0xFFA5C9FF), // ледяной голубой
      Color(0xFFE0F7FA), // иней
      Color(0xFF4FC3F7), // морозный акцент
    ],
    speed: 0.3,
    bloom: 0.45,
    blur: 22,
    particleDensity: 0.65,
    depth: 0.7,
    premiumSignature: false,
  );

  static const phoenixFire = AuraTheme(
    id: 'phoenix_fire',
    name: 'Жар-Птица',
    subtitle: 'Пламенное возрождение',
    icon: Icons.local_fire_department_rounded,
    weather: AuraWeather.candle,
    palette: [
      Color(0xFF1A0500), // обугленный фон
      Color(0xFFFF4500), // оранжевое пламя
      Color(0xFFFFD700), // золотое ядро
      Color(0xFFFF1493), // малиновая вспышка
    ],
    speed: 1.1,
    bloom: 0.8,
    blur: 10,
    particleDensity: 0.7,
    depth: 0.45,
    premiumSignature: true,
  );

  static const emeraldForest = AuraTheme(
    id: 'emerald_forest',
    name: 'Изумрудный Лес',
    subtitle: 'Природное спокойствие',
    icon: Icons.forest_rounded,
    weather: AuraWeather.aura,
    palette: [
      Color(0xFF0A1F0A), // глубокая хвоя
      Color(0xFF50C878), // изумруд
      Color(0xFF228B22), // лесной зелёный
      Color(0xFFF0E68C), // хакти-солнечный луч
    ],
    speed: 0.5,
    bloom: 0.5,
    blur: 18,
    particleDensity: 0.55,
    depth: 0.6,
    premiumSignature: false,
  );

  static const blueLagoon = AuraTheme(
    id: 'blue_lagoon',
    name: 'Голубая Лагуна',
    subtitle: 'Тропический покой',
    icon: Icons.water_rounded,
    weather: AuraWeather.water,
    palette: [
      Color(0xFF001F3F), // глубокий океан
      Color(0xFF00CED1), // бирюзовый
      Color(0xFF4FC3F7), // небесно-голубой
      Color(0xFFE0F7FA), // пена
    ],
    speed: 0.6,
    bloom: 0.55,
    blur: 16,
    particleDensity: 0.5,
    depth: 0.6,
    premiumSignature: false,
  );

  static const quantumHologram = AuraTheme(
    id: 'quantum_hologram',
    name: 'Квантовый Голограмм',
    subtitle: 'Футуристичный интерфейс',
    icon: Icons.memory_rounded,
    weather: AuraWeather.hologram,
    palette: [
      Color(0xFF050A14), // цифровой чёрный
      Color(0xFF00FFCC), // голограммный циан
      Color(0xFF7DF9FF), // электрический голубой
      Color(0xFFBF00FF), // квантовый фиолетовый
    ],
    speed: 1.0,
    bloom: 0.7,
    blur: 11,
    particleDensity: 0.6,
    depth: 0.55,
    premiumSignature: true,
  );

  /// Все темы в порядке отображения.
  static const List<AuraTheme> all = [
    auroraBorealis,
    neonTokyo,
    goldenSakura,
    deepCosmos,
    stellarNebula,
    digitalGravity,
    liquidGold,
    premiumGlass,
    polarNight,
    phoenixFire,
    emeraldForest,
    blueLagoon,
    quantumHologram,
  ];

  /// Найти тему по id. Возвращает [defaultTheme] если не найдена.
  static AuraTheme byId(String? id) {
    if (id == null) return defaultTheme;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return defaultTheme;
  }
}

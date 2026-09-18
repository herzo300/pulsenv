import 'package:flutter/material.dart';

enum AuraWeather {
  aura,
  fog,
  rain,
  water,
  cosmos,
  aurora,
  dawn,
  sunset,
  candle,
  breath,
  tropical,
  // Global expansion weathers
  sakura, // 🌸 Cherry blossom — Japan
  snow, // ❄️ Gentle snowfall — winter/universal
  ocean, // 🌊 Deep ocean waves — sleep/calm
  fireflies, // ✨ Hotaru — Japan summer nights
  incense, // 🪔 Sacred smoke — India/spiritual
  // GPU shader-based immersive effects
  fluid, // 🌊 Fluid simulation — touch interactive
  fractal, // 🔮 Mandelbrot fractal zoom
  voronoi, // 💎 Voronoi crystal structures
  waveFunc, // ⚛️ Quantum wave function
  inkDiffuse, // 🖌️ Ink diffusion in water
  
  // New 30+ Expansion Pack
  starfield, // 🌟 Pulsating star background
  nebula, // 🌌 Colorful space nebula
  blackHole, // 🕳️ Gravitational distortion
  supernova, // 💥 High bloom explosion
  cyberpunk, // 🌆 Neon rain glitch
  neon, // 💡 Pure neon lights
  matrix, // 📟 Digital green rain
  glitch, // ⚡ Spatial distortion
  hologram, // 💿 Transparent flickering
  technoCivic, // 🌆 Glowing neon techno city pulse
}

enum AuraPractice {
  home,
  breathwork,
  meditation,
  sleep,
  focus,
  sos,
  premium,
}

@immutable
class AuraLivingScene {
  final AuraWeather weather;
  final AuraPractice practice;
  final List<Color> palette;
  final double speed;
  final double bloom;
  final double particleDensity;
  final double blur;
  final double depth;
  final double breathPhase;
  final double audioEnergy;
  final bool premiumSignature;

  /// Пользовательское фото как фон (URL или asset-path).
  /// Если задано — рендерится как нижний слой с Ken Burns-анимацией,
  /// шейдеры AuraLiving поверх с полупрозрачностью (живой эффект).
  /// null — процедурный фон как раньше.
  final String? backgroundImage;

  const AuraLivingScene({
    required this.weather,
    required this.practice,
    required this.palette,
    this.speed = 1.0,
    this.bloom = 0.55,
    this.particleDensity = 0.55,
    this.blur = 18,
    this.depth = 0.55,
    this.breathPhase = 0.0,
    this.audioEnergy = 0.0,
    this.premiumSignature = false,
    this.backgroundImage,
  });

  AuraLivingScene copyWith({
    AuraWeather? weather,
    AuraPractice? practice,
    List<Color>? palette,
    double? speed,
    double? bloom,
    double? particleDensity,
    double? blur,
    double? depth,
    double? breathPhase,
    double? audioEnergy,
    bool? premiumSignature,
    String? backgroundImage,
  }) {
    return AuraLivingScene(
      weather: weather ?? this.weather,
      practice: practice ?? this.practice,
      palette: palette ?? this.palette,
      speed: speed ?? this.speed,
      bloom: bloom ?? this.bloom,
      particleDensity: particleDensity ?? this.particleDensity,
      blur: blur ?? this.blur,
      depth: depth ?? this.depth,
      breathPhase: breathPhase ?? this.breathPhase,
      audioEnergy: audioEnergy ?? this.audioEnergy,
      premiumSignature: premiumSignature ?? this.premiumSignature,
      backgroundImage: backgroundImage ?? this.backgroundImage,
    );
  }

  Color get primary =>
      palette.isNotEmpty ? palette.first : const Color(0xFF4AD7B8);

  Color get secondary =>
      palette.length > 1 ? palette[1] : const Color(0xFFE8C547);

  Color get tertiary =>
      palette.length > 2 ? palette[2] : const Color(0xFF7E63FF);
}

class AuraLivingEngine {
  const AuraLivingEngine._();

  static AuraLivingScene resolve({
    required int mood,
    required int streak,
    required int meditationMinutes,
    required int practicesCompleted,
    required bool isPremium,
    required int hour,
    AuraPractice practice = AuraPractice.home,
    double audioEnergy = 0,
    double breathPhase = 0,
  }) {
    final timeWeather = _weatherForTime(hour);
    final moodWeather = _weatherForMood(mood);
    final weather = practice == AuraPractice.home
        ? moodWeather ?? timeWeather
        : _weatherForPractice(practice);
    final progress = (practicesCompleted / 80).clamp(0.0, 1.0);
    final streakGlow = (streak / 21).clamp(0.0, 1.0);
    final depth = (meditationMinutes / 600).clamp(0.0, 1.0);

    return AuraLivingScene(
      weather: weather,
      practice: practice,
      palette: _paletteFor(weather, mood, hour),
      speed: _speedFor(weather) * (1.0 - depth * 0.18),
      bloom: 0.44 + streakGlow * 0.26 + progress * 0.18,
      particleDensity: 0.32 + progress * 0.34 + (isPremium ? 0.12 : 0.0),
      blur: 14 + depth * 12,
      depth: 0.42 + depth * 0.38 + progress * 0.12,
      breathPhase: breathPhase,
      audioEnergy: audioEnergy,
      premiumSignature: isPremium || practicesCompleted >= 12 || streak >= 7,
    );
  }

  static AuraLivingScene practice(
    AuraPractice practice, {
    double intensity = 0.5,
    double breathPhase = 0.0,
    double audioEnergy = 0.0,
    bool premiumSignature = false,
  }) {
    final weather = _weatherForPractice(practice);
    return AuraLivingScene(
      weather: weather,
      practice: practice,
      palette: _paletteFor(weather, 0, DateTime.now().hour),
      speed: _speedFor(weather) * (0.72 + intensity * 0.55),
      bloom: 0.44 + intensity * 0.28,
      particleDensity: 0.30 + intensity * 0.36,
      blur: 16 + intensity * 10,
      depth: 0.45 + intensity * 0.35,
      breathPhase: breathPhase,
      audioEnergy: audioEnergy,
      premiumSignature: premiumSignature,
    );
  }

  static String shaderAssetFor(AuraWeather weather) {
    switch (weather) {
      case AuraWeather.aura:
        return 'shaders/aura_theme.frag';
      case AuraWeather.fog:
        return 'shaders/fog_theme.frag';
      case AuraWeather.rain:
        return 'shaders/rain_ambient.frag';
      case AuraWeather.water:
        return 'shaders/water_theme.frag';
      case AuraWeather.cosmos:
        return 'shaders/cosmos_theme.frag';
      case AuraWeather.aurora:
        return 'shaders/aurora_theme.frag';
      case AuraWeather.dawn:
        return 'shaders/aurora_theme.frag';
      case AuraWeather.sunset:
        return 'shaders/water_theme.frag';
      case AuraWeather.candle:
        return 'shaders/candle.frag';
      case AuraWeather.breath:
        return 'shaders/breath_ring.frag';
      case AuraWeather.tropical:
        return 'shaders/candle.frag';
      case AuraWeather.sakura:
        return 'shaders/aura_theme.frag'; // soft base — sakura particles via CustomPainter
      case AuraWeather.snow:
        return 'shaders/fog_theme.frag'; // cool fog base — snow particles via CustomPainter
      case AuraWeather.ocean:
        return 'shaders/water_theme.frag'; // deep water base
      case AuraWeather.fireflies:
        return 'shaders/cosmos_theme.frag'; // dark sky base — fireflies via particles
      case AuraWeather.incense:
        return 'shaders/candle.frag';
      case AuraWeather.fluid:
        return 'shaders/fluid_sim.frag';
      case AuraWeather.fractal:
        return 'shaders/fractal_zoom.frag';
      case AuraWeather.voronoi:
        return 'shaders/voronoi_crystal.frag';
      case AuraWeather.waveFunc:
        return 'shaders/wave_function.frag';
      case AuraWeather.inkDiffuse:
        return 'shaders/ink_diffusion.frag';
      case AuraWeather.starfield:
        return 'shaders/cosmos_theme.frag';
      case AuraWeather.nebula:
        return 'shaders/cosmos_theme.frag';
      case AuraWeather.blackHole:
        return 'shaders/cosmos_theme.frag';
      case AuraWeather.supernova:
        return 'shaders/cosmos_theme.frag';
      case AuraWeather.cyberpunk:
        return 'shaders/rain_ambient.frag';
      case AuraWeather.neon:
        return 'shaders/aura_theme.frag';
      case AuraWeather.matrix:
        return 'shaders/fog_theme.frag';
      case AuraWeather.glitch:
        return 'shaders/aura_theme.frag';
      case AuraWeather.hologram:
        return 'shaders/water_theme.frag';
      case AuraWeather.technoCivic:
        return 'shaders/aura_theme.frag';
    }
  }

  static AuraWeather _weatherForTime(int hour) {
    if (hour < 5) return AuraWeather.cosmos;
    if (hour < 8) return AuraWeather.dawn;
    if (hour < 10) return AuraWeather.aurora;
    if (hour < 17) return AuraWeather.aura;
    if (hour < 20) return AuraWeather.sunset;
    if (hour < 22) return AuraWeather.water;
    return AuraWeather.fog;
  }

  static AuraWeather? _weatherForMood(int mood) {
    switch (mood) {
      case 1:
        return AuraWeather.rain;
      case 2:
        return AuraWeather.fog;
      case 3:
        return AuraWeather.water;
      case 4:
        return AuraWeather.aura;
      case 5:
        return AuraWeather.aurora;
      case 6:
        return AuraWeather.candle;
      case 7:
        return AuraWeather.cosmos;
      default:
        return null;
    }
  }

  static AuraWeather _weatherForPractice(AuraPractice practice) {
    switch (practice) {
      case AuraPractice.home:
        return AuraWeather.aura;
      case AuraPractice.breathwork:
        return AuraWeather.breath;
      case AuraPractice.meditation:
        return AuraWeather.water;
      case AuraPractice.sleep:
        return AuraWeather.cosmos;
      case AuraPractice.focus:
        return AuraWeather.candle;
      case AuraPractice.sos:
        return AuraWeather.fluid;
      case AuraPractice.premium:
        return AuraWeather.aurora;
    }
  }

  static double _speedFor(AuraWeather weather) {
    switch (weather) {
      case AuraWeather.fog:
        return 0.42;
      case AuraWeather.water:
        return 0.62;
      case AuraWeather.cosmos:
        return 0.36;
      case AuraWeather.candle:
        return 0.78;
      case AuraWeather.breath:
        return 0.58;
      case AuraWeather.rain:
        return 0.86;
      case AuraWeather.aurora:
        return 0.50;
      case AuraWeather.dawn:
        return 0.36;
      case AuraWeather.sunset:
        return 0.34;
      case AuraWeather.aura:
        return 0.55;
      case AuraWeather.tropical:
        return 0.48;
      case AuraWeather.sakura:
        return 0.30; // very gentle, contemplative
      case AuraWeather.snow:
        return 0.22; // slow, peaceful
      case AuraWeather.ocean:
        return 0.40; // rhythmic waves
      case AuraWeather.fireflies:
        return 0.34; // subtle floating
      case AuraWeather.incense:
        return 0.28;
      case AuraWeather.fluid:
        return 0.45;
      case AuraWeather.fractal:
        return 0.20;
      case AuraWeather.voronoi:
        return 0.35;
      case AuraWeather.waveFunc:
        return 0.38;
      case AuraWeather.inkDiffuse:
        return 0.25;
      case AuraWeather.starfield:
        return 0.15; // Slow pulsating
      case AuraWeather.nebula:
        return 0.20;
      case AuraWeather.blackHole:
        return 0.10; // Very slow and dense
      case AuraWeather.supernova:
        return 0.85; // Fast explosion
      case AuraWeather.cyberpunk:
        return 0.90; // Fast rain
      case AuraWeather.neon:
        return 0.55;
      case AuraWeather.matrix:
        return 0.95; // Digital speed
      case AuraWeather.glitch:
        return 1.20; // Erratic
      case AuraWeather.hologram:
        return 0.40;
      case AuraWeather.technoCivic:
        return 0.65;
    }
  }

  static List<Color> _paletteFor(AuraWeather weather, int mood, int hour) {
    final List<Color> basePalette = _getBasePalette(weather, mood);
    return _adjustPaletteForCircadian(basePalette, hour);
  }

  static List<Color> _adjustPaletteForCircadian(List<Color> baseColors, int hour) {
    // Night: 21:00 - 05:00 -> dim and shift towards deep space indigo
    if (hour >= 21 || hour < 5) {
      return baseColors.map((color) {
        return Color.lerp(color, const Color(0xFF04000C), 0.58)!;
      }).toList();
    }
    // Dawn: 05:00 - 09:00 -> blend in warm sunrise gold
    if (hour >= 5 && hour < 9) {
      return baseColors.map((color) {
        return Color.lerp(color, const Color(0xFFFFB58A), 0.38)!;
      }).toList();
    }
    // Sunset: 17:00 - 21:00 -> blend in twilight violet-rose
    if (hour >= 17 && hour < 21) {
      return baseColors.map((color) {
        return Color.lerp(color, const Color(0xFFC77DFF), 0.38)!;
      }).toList();
    }
    return baseColors;
  }

  static List<Color> _getBasePalette(AuraWeather weather, int mood) {
    switch (weather) {
      case AuraWeather.aura:
        return const [
          Color(0xFF4AD7B8),
          Color(0xFFE8C547),
          Color(0xFF7E63FF),
          Color(0xFF10243A),
        ];
      case AuraWeather.fog:
        return const [
          Color(0xFF111827),
          Color(0xFF9BA5C9),
          Color(0xFF5C647A),
          Color(0xFF243041),
        ];
      case AuraWeather.rain:
        return const [
          Color(0xFF071827),
          Color(0xFF2C8CFF),
          Color(0xFF4AD7B8),
          Color(0xFF0A3142),
        ];
      case AuraWeather.water:
        return const [
          Color(0xFF021420),
          Color(0xFF00C2C7),
          Color(0xFF2C8CFF),
          Color(0xFF94D2BD),
        ];
      case AuraWeather.cosmos:
        return const [
          Color(0xFF080014),
          Color(0xFFB65CFF),
          Color(0xFFFF6AAE),
          Color(0xFF80D8FF),
        ];
      case AuraWeather.aurora:
        return const [
          Color(0xFF000428),
          Color(0xFF00FF87),
          Color(0xFF6EA8FF),
          Color(0xFFE8C547),
        ];
      case AuraWeather.dawn:
        return const [
          Color(0xFF07121E),
          Color(0xFFFFB58A),
          Color(0xFFFFD6A5),
          Color(0xFF8ED8D1),
        ];
      case AuraWeather.sunset:
        return const [
          Color(0xFF140918),
          Color(0xFFFF8A5C),
          Color(0xFFC77DFF),
          Color(0xFFFFD166),
        ];
      case AuraWeather.candle:
        return const [
          Color(0xFF140A02),
          Color(0xFFFFB347),
          Color(0xFFE85D3F),
          Color(0xFFFFE0A3),
        ];
      case AuraWeather.breath:
        return const [
          Color(0xFF06121A),
          Color(0xFF4AD7B8),
          Color(0xFF7E63FF),
          Color(0xFFE8C547),
        ];
      case AuraWeather.tropical:
        return const [
          Color(0xFF0D1A08),
          Color(0xFFFFB347),
          Color(0xFF2ECC71),
          Color(0xFFFF6B5B),
          Color(0xFFFFF0C0),
        ];
      case AuraWeather.sakura:
        return const [
          Color(0xFF120810), // dark plum night
          Color(0xFFFCB9C5), // 桜色 sakura pink
          Color(0xFFBBA0CB), // 藤色 wisteria
          Color(0xFFF5E6D3), // warm petal white
        ];
      case AuraWeather.snow:
        return const [
          Color(0xFF0A1020), // deep winter night
          Color(0xFFD6E8F0), // ice blue
          Color(0xFFA8C8E8), // frost
          Color(0xFFF0F4FF), // snow white
        ];
      case AuraWeather.ocean:
        return const [
          Color(0xFF020A18), // deep abyss
          Color(0xFF0066AA), // ocean blue
          Color(0xFF00A8B5), // turquoise
          Color(0xFF88D4E8), // shallow water
        ];
      case AuraWeather.fireflies:
        return const [
          Color(0xFF050A04), // dark forest night
          Color(0xFFE8D44D), // firefly glow
          Color(0xFF6B8F3C), // moss green
          Color(0xFFC8FF4D), // bright glow
        ];
      case AuraWeather.incense:
        return const [
          Color(0xFF100808),
          Color(0xFFD4A574),
          Color(0xFF8B6D4C),
          Color(0xFFFFDDBB),
        ];
      case AuraWeather.fluid:
        return const [
          Color(0xFF040820),
          Color(0xFF2080FF),
          Color(0xFF60FFD0),
          Color(0xFFFF8040)
        ];
      case AuraWeather.fractal:
        return const [
          Color(0xFF000010),
          Color(0xFFB65CFF),
          Color(0xFFFF6AAE),
          Color(0xFF00FFCC)
        ];
      case AuraWeather.voronoi:
        return const [
          Color(0xFF080412),
          Color(0xFF80D8FF),
          Color(0xFFE0C0FF),
          Color(0xFFFFF0D0)
        ];
      case AuraWeather.waveFunc:
        return const [
          Color(0xFF000818),
          Color(0xFF4488FF),
          Color(0xFF88FFDD),
          Color(0xFFFF88CC)
        ];
      case AuraWeather.inkDiffuse:
        return const [
          Color(0xFFF0ECE0),
          Color(0xFF1A1A2E),
          Color(0xFF3A3A5E),
          Color(0xFF8888AA)
        ];
      case AuraWeather.starfield:
        return const [
          Color(0xFF030008),
          Color(0xFF80D8FF),
          Color(0xFFFFFFFF),
          Color(0xFFE0C0FF)
        ];
      case AuraWeather.nebula:
        return const [
          Color(0xFF080014),
          Color(0xFFFF0080),
          Color(0xFF00FFCC),
          Color(0xFF4400FF)
        ];
      case AuraWeather.blackHole:
        return const [
          Color(0xFF000000),
          Color(0xFF1A0033),
          Color(0xFFFF5500),
          Color(0xFF4400AA)
        ];
      case AuraWeather.supernova:
        return const [
          Color(0xFF220000),
          Color(0xFFFFFF00),
          Color(0xFFFF0000),
          Color(0xFFFFFFFF)
        ];
      case AuraWeather.cyberpunk:
        return const [
          Color(0xFF0A001A),
          Color(0xFFFF0055),
          Color(0xFF00FFFF),
          Color(0xFFFFD700)
        ];
      case AuraWeather.neon:
        return const [
          Color(0xFF050505),
          Color(0xFF00FF00),
          Color(0xFFFF00FF),
          Color(0xFF00FFFF)
        ];
      case AuraWeather.matrix:
        return const [
          Color(0xFF001100),
          Color(0xFF00FF00),
          Color(0xFF008800),
          Color(0xFFCCFFCC)
        ];
      case AuraWeather.glitch:
        return const [
          Color(0xFF111111),
          Color(0xFFFF0000),
          Color(0xFF0000FF),
          Color(0xFF00FF00)
        ];
      case AuraWeather.hologram:
        return const [
          Color(0xFF001A22),
          Color(0xFF00FFFF),
          Color(0xFF0088AA),
          Color(0xFFFFFFFF)
        ];
      case AuraWeather.technoCivic:
        return const [
          Color(0xFF05081C), // deep space civic night
          Color(0xFF00FFCC), // techno neon cyan
          Color(0xFFF59E0B), // golden cyber-amber
          Color(0xFF6366F1), // neon indigo
        ];
    }
  }
}

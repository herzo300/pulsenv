# Splash Screens — План миграции на единую дизайн-систему

## Проблема

6 splash-экранов полностью игнорируют `PulseColors` и `AppTextStyles`:

| Экран | Строк | Своя палитра | Шрифты | Статус |
|-------|-------|-------------|--------|--------|
| `splash_screen.dart` | 918 | Золотая (`#FFB84D`, `#FFD979`) | Orbitron, IBM Plex Sans, Exo 2, Manrope, JetBrains Mono | ⚠️ Частично использует PulseColors |
| `cyber_splash_screen.dart` | 980 | Кибер (`#020814`, `#00E5FF`, `#1DE9B6`, `#448AFF`, `#7C4DFF`) | Orbitron, Inter | ⚠️ Частично использует PulseColors |
| `swamp_splash_screen.dart` | ~350 | Болотная (`#0A0F0D`, `#AABB22`, `#558833`) | RussoOne, Inter, VT323 | ❌ Полностью изолирован |
| `gravity_splash_screen.dart` | ~? | TBD | TBD | ❓ Не изучен |
| `monitor_splash_screen.dart` | ~? | TBD | Orbitron, Inter | ❌ Полностью изолирован |
| `ai_core_splash_screen.dart` | ~? | TBD | TBD | ❓ Не изучен |

## Решение

### Вариант A: Удалить лишние экраны (Рекомендуется)
Оставить **один** `splash_screen.dart`, остальные — удалить или сделать темами внутри него.

### Вариант B: Привести к дизайн-системе
Для каждого экрана:
1. Заменить захардкоженные цвета на `PulseColors` или создать тематические расширения
2. Заменить `GoogleFonts.*` на `AppTextStyles`
3. Использовать `AppPanel` вместо кастомных glass-панелей

### Вариант C: Создать `SplashTheme` абстракцию
```dart
abstract class SplashTheme {
  Color get background;
  Color get primary;
  TextStyle get titleStyle;
  // ...
}

class GoldSplashTheme extends SplashTheme { ... }
class CyberSplashTheme extends SplashTheme { ... }
class SwampSplashTheme extends SplashTheme { ... }
```

## Конкретные изменения для `splash_screen.dart`

### 1. Заменить захардкоженные цвета

```dart
// БЫЛО:
Shadow(color: Color(0x99FFB84D), blurRadius: 18)
const Color(0xFF20150A)
const Color(0xFFFFD979)

// СТАЛО (использовать PulseColors.accentGold + варианты):
Shadow(color: PulseColors.accentGold.withOpacity(0.6), blurRadius: 18)
PulseColors.background.withOpacity(0.08)  // для тёмных поверхносей
PulseColors.accentGold  // вместо #FFB84D
```

### 2. Заменить GoogleFonts на AppTextStyles

```dart
// БЫЛО:
GoogleFonts.orbitron(fontSize: 30, fontWeight: FontWeight.w800, ...)
GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, ...)
GoogleFonts.exo2(fontSize: 25, fontWeight: FontWeight.w700, ...)
GoogleFonts.manrope(fontSize: 14, height: 1.5, ...)
GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, ...)

// СТАЛО:
AppTextStyles.title           // для "НИЖНЕВАРТОВСК"
AppTextStyles.overline        // для "НЕФТЕГАЗОВАЯ СТОЛИЦА"
AppTextStyles.section         // для "ПУЛЬС ГОРОДА"
AppTextStyles.body            // для описания
AppTextStyles.mono            // для "v1.0.0"
```

### 3. Создать расширения PulseColors для splash-темы

```dart
// В pulse_colors.dart добавить:
abstract final class SplashColors {
  // Gold theme (main splash)
  static const Color goldPrimary = accentGold;
  static const Color goldLight = Color(0xFFFFD979);
  static const Color goldDark = Color(0xFF26180A);
  
  // Cyber theme
  static const Color cyberDeep = Color(0xFF020814);
  static const Color cyberTeal = Color(0xFF1DE9B6);
  static const Color cyberBlue = Color(0xFF448AFF);
  
  // Swamp theme
  static const Color swampDeep = Color(0xFF0A0F0D);
  static const Color swampPrimary = Color(0xFFAABB22);
  static const Color swampSecondary = Color(0xFF558833);
}
```

## Приоритет выполнения

1. **P0**: `splash_screen.dart` (главный экран, видит каждый пользователь)
2. **P1**: `cyber_splash_screen.dart` (второй по частоте)
3. **P2**: `swamp_splash_screen.dart` (специфичная тема, можно оставить как Easter egg)
4. **P3**: Остальные (низкий приоритет, редко используются)

## Оценка усилий

| Вариант | Время | Сложность | Поддержка |
|---------|-------|-----------|-----------|
| A — Удалить лишние | 2 часа | Низкая | Отлично |
| B — Привести к системе | 8 часов | Высокая | Хорошо |
| C — SplashTheme абстракция | 6 часов | Средняя | Отлично |

**Рекомендация**: Вариант A — оставить 1-2 splash-экрана, остальные удалить. 
Каждый splash — это 700-900 строк кода, который трудно поддерживать.

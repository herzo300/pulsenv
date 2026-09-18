# 🌌 Инструкция по созданию голографических интерфейсов (Обучение Гермеса)

Этот документ содержит полный учебный курс и спецификацию по программированию неоновых голограмм, шейдеров искажения и футуристических HUD-интерфейсов для ИИ-ассистента **Гермеса** (и разработчиков приложения СообщиО / City Pulse).

---

## 1. Анатомия голографического эффекта в GLSL

Настоящая голограмма на экране состоит из 5 оптических явлений, которые мы воспроизводим математически в фрагментном шейдере:

1. **Сетка сканлайнов (Scanlines)**: бегущие горизонтальные темные и светлые полосы, имитирующие развертку старого ЭЛТ-монитора или проектора.
2. **Голографическая сетка (Holographic Grid)**: неоновая решетка, создающая ощущение цифровой структуры.
3. **Хроматическая аберрация (Chromatic Aberration)**: расслоение RGB-каналов по краям из-за несовершенства линз проектора (красный сдвигается в одну сторону, синий — в другую).
4. **Преломление света (Glassmorphic Blur/Distortion)**: искажение фонового изображения по синусоидальной волне.
5. **Неоновый сканер (Neon Sweep)**: яркая горизонтальная полоса сканирования, периодически проходящая сверху вниз.

---

## 2. Математические формулы шейдера

### А. Сканлайны
Генерируются через функцию синуса от координаты `Y` экрана с добавлением времени для анимации движения полос:
$$\text{scanline} = \sin(uv.y \times \text{density} + \text{time} \times \text{speed}) \times \text{strength}$$

### Б. Хроматическая аберрация
Для расслоения каналов мы делаем три выборки из текстуры с разным смещением UV координат относительно центра экрана:
$$\text{uv}_R = \text{uv} + \text{offset}$$
$$\text{uv}_B = \text{uv} - \text{offset}$$
$$\text{color} = (R(\text{uv}_R), G(\text{uv}), B(\text{uv}_B))$$

### В. Волновая деформация
Для создания эффекта «дрожания» проекции мы смещаем координату `X` в зависимости от синуса координаты `Y`:
$$\text{offset}_X = \sin(uv.y \times \text{freq} + \text{time} \times \text{speed}) \times \text{amplitude}$$

---

## 3. Интеграция шейдеров в Flutter

Для подключения шейдера во Flutter выполните следующие шаги:

### Шаг 1. Регистрация в `pubspec.yaml`
```yaml
flutter:
  shaders:
    - shaders/hologram.frag
```

### Шаг 2. Инициализация во Flutter
```dart
import 'dart:ui' as ui;

Future<ui.FragmentShader> loadHologramShader() async {
  final program = await ui.FragmentProgram.fromAsset('shaders/hologram.frag');
  return program.fragmentShader();
}
```

### Шаг 3. Рендеринг в CustomPainter
```dart
class HologramPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  HologramPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Передаем uniform-переменные в шейдер
    shader.setFloat(0, time); // u_time
    shader.setFloat(1, size.width); // u_resolution X
    shader.setFloat(2, size.height); // u_resolution Y

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

---

## 4. Базовый код шейдера (hologram.frag)

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;
uniform sampler2D u_texture;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    
    // 1. Искажение UV (эффект помех)
    float wave = sin(uv.y * 10.0 + u_time * 2.0) * 0.003;
    vec2 distortedUv = vec2(uv.x + wave, uv.y);
    
    // 2. Хроматическая аберрация
    float abDist = 0.005;
    float r = texture(u_texture, distortedUv + vec2(abDist, 0.0)).r;
    float g = texture(u_texture, distortedUv).g;
    float b = texture(u_texture, distortedUv - vec2(abDist, 0.0)).b;
    
    vec4 baseColor = vec4(r, g, b, 1.0);
    
    // 3. Бегущий неоновый сканер
    float scanPos = fract(u_time * 0.2);
    float scanLine = smoothstep(0.02, 0.0, abs(uv.y - scanPos)) * 0.4;
    
    // 4. Сетка сканлайнов
    float scanlineVal = sin(uv.y * 250.0) * 0.04;
    
    // Результат (бирюзовый/неоновый оттенок голограммы)
    vec3 holoColor = baseColor.rgb + vec3(0.0, scanLine, scanLine * 0.5);
    holoColor += vec3(0.0, 0.8, 1.0) * (scanlineVal + 0.05);
    
    fragColor = vec4(holoColor, baseColor.a);
}
```

---

## 5. Инструкции для Гермеса при разработке UI

1. **Использовать RepaintBoundary**: Всегда оборачивать виджеты с шейдером в `RepaintBoundary`, чтобы избежать повторного рендеринга всего экрана при анимации шейдера.
2. **Предусматривать Canvas-fallback**: На старых устройствах, не поддерживающих OpenGL/Vulkan шейдеры во Flutter, автоматически переключаться на `HologramCanvasEffect` (отрисовка сетки и линий через стандартный Canvas API).
3. **Управление цветом**: Использовать палитру HSL с высокой насыщенностью (Cyan `#00E5FF`, Magenta `#FF007F`) для создания эффекта светящегося газа.

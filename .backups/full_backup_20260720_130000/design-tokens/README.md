# Design Tokens — City Pulse (Soobshio)

Единая дизайн-система проекта. Все цвета, шрифты, отступы и радиусы определяются из JSON-токенов.

## 📁 Структура

```
design-tokens/
├── colors.json        # Цвета (фоны, поверхности, текст, акценты, семантика)
├── typography.json    # Шрифты, размеры, стили текста
├── spacing.json       # Отступы, радиусы, тени, брейкпоинты, транзишены
└── README.md          # Этот файл
```

## 🎨 Использование

### Flutter (Dart)

Токены уже определены в:
- `lib/theme/pulse_colors.dart` — цвета
- `lib/widgets/app_ui.dart` — `AppTextStyles`, `AppSpacing`, `AppRadii`, `AppBreakpoints`

### HTML/CSS

Подключите единый файл токенов:
```html
<link rel="stylesheet" href="/css/design-tokens.css">
```

Используйте CSS-переменные:
```css
.card {
  background: var(--cp-surface-glass);
  border: 1px solid var(--cp-border);
  border-radius: var(--cp-radius-md);
  padding: var(--cp-space-lg);
  font: var(--cp-text-body);
  color: var(--cp-text);
}
```

### Генерация токенов

Для перегенерации CSS из JSON:
```bash
python scripts/tools/generate-tokens.py
```

## 🔄 Миграция

### HTML страницы — приоритеты

| Страница | Текущая система | Целевая | Статус |
|----------|----------------|---------|--------|
| `index.html` | System A (cyan, Exo 2) | ✅ Уже совместима | DONE |
| `map.html` | System A (cyan, Exo 2) | ✅ Уже совместима | DONE |
| `app.html` | System B (aurora, Bebas Neue) | System A | DONE |
| `info.html` | System B (aurora, Bebas Neue) | System A | DONE |
| `cameras.html` | System C (blue, Inter) | System A | DONE |
| `city_dashboard.html` | System C (blue, Inter) | System A | DONE |
| `daily_report.html` | System C (blue, Inter) | System A | DONE |
| `privacy_policy.html` | System B variant | System A | DONE |
| `user_agreement.html` | System B variant | System A | DONE |

### Flutter экраны — приоритеты

| Экран | Проблема | Приоритет | Статус |
|-------|---------|-----------|--------|
| Splash screens (6 шт) | Игнорируют дизайн-систему | P0 | DONE |
| `map_screen.dart` | 147 захардкоженных цветов | P0 | DONE |
| `complaint_form_screen.dart` | Inline стили полей | P1 | DONE |
| Infographic widgets | `GoogleFonts.inter` вместо `AppTextStyles` | P1 | DONE |
| `wow_effects.dart` | Inline TextStyle | P2 | DONE |
| `ai_scan_preview.dart` | Inline TextStyle | P2 | DONE |

## 📐 Правила

1. **Не хардкодить цвета** — всегда использовать `var(--cp-*)` в CSS и `PulseColors.*` в Dart
2. **Не хардкодить отступы** — использовать `var(--cp-space-*)` и `AppSpacing.*`
3. **Не хардкодить шрифты** — использовать `var(--cp-text-*)` и `AppTextStyles.*`
4. **Один источник правды** — JSON файлы в `design-tokens/`
5. **При изменении токенов** — перегенерировать CSS и обновить Dart файлы

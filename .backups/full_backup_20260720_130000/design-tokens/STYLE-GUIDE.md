# City Pulse — Visual Style Guide / Component Catalog

> Единая дизайн-система для City Pulse (Soobshio) — Нижневартовск

## 📋 Оглавление

1. [Философия дизайна](#философия-дизайна)
2. [Цветовая палитра](#цветовая-палитра)
3. [Типографика](#типографика)
4. [Отступы и сетка](#отступы-и-сетка)
5. [Компоненты](#компоненты)
6. [Анимации](#анимации)
7. [Платформы](#платформы)

---

## Философия дизайна

**Концепция**: «Операторский неон» — спокойный, профессиональный civic-tech интерфейс

**Ключевые принципы**:
- 🧊 **Glass-morphism** — полупрозрачные панели с backdrop-blur
- 🌊 **Aurora-градиенты** — мягкие цветовые волны на фоне
- 💎 **Чёткая иерархия** — Exo 2 заголовки, Manrope текст, JetBrains Mono данные
- 🎯 **Функциональность** — дизайн служит данным, не наоборот

---

## Цветовая палитра

### Primary Accent

| Токен | Hex | Использование |
|-------|-----|--------------|
| `--cp-primary` / `PulseColors.primary` | `#00E5FF` | Кнопки, ссылки, активные элементы |
| `--cp-primary-soft` / `PulseColors.primarySoft` | `#7DF2FF` | Hover-состояния, мягкие акценты |
| `--cp-primary-deep` / `PulseColors.primaryDeep` | `#0EA5C7` | Light mode primary |

### Semantic Colors

| Токен | Hex | Использование |
|-------|-----|--------------|
| `--cp-success` / `PulseColors.success` | `#00E676` | Успешные операции, online-статус |
| `--cp-warning` / `PulseColors.warning` | `#FFC857` | Предупреждения, золотые акценты |
| `--cp-negative` / `PulseColors.negative` | `#FF3D00` | Ошибки, критические статусы |
| `--cp-accent-violet` / `PulseColors.accentViolet` | `#7C4DFF` | Вторичные акценты, градиенты |
| `--cp-neutral` / `PulseColors.neutral` | `#90A4AE` | Отключённые элементы, placeholder |

### Surface Colors (Dark Mode)

| Токен | Hex | Использование |
|-------|-----|--------------|
| `--cp-bg` / `PulseColors.background` | `#020617` | Основной фон |
| `--cp-bg-raised` / `PulseColors.backgroundRaised` | `#08111F` | Приподнятый фон |
| `--cp-surface` / `PulseColors.surface` | `#0C1628` | Поверхность карточек |
| `--cp-surface-soft` / `PulseColors.surfaceSoft` | `#112036` | Мягкая поверхность |
| `--cp-surface-elevated` / `PulseColors.surfaceElevated` | `#16263D` | Приподнятая поверхность |
| `--cp-surface-glass` / `PulseColors.surfaceGlass` | `rgba(17,28,49,0.8)` | Glass-панели |

### Text Colors

| Токен | Hex | Использование |
|-------|-----|--------------|
| `--cp-text` / `PulseColors.textPrimary` | `#E6FAFF` | Основной текст |
| `--cp-text-secondary` / `PulseColors.textSecondary` | `#8EAFC2` | Вторичный текст, подписи |
| `--cp-text-tertiary` / `PulseColors.textTertiary` | `#66849A` | Третичный текст, version info |

### ❌ Запрещённые цвета

Эти цвета **НЕЛЬЗЯ** использовать — они создают визуальный шум:

| Цвет | Причина |
|------|---------|
| `#3b82f6` (blue) | Конфликтует с primary cyan |
| `#00f0ff` (slightly different cyan) | 16 hue единиц от primary — использовать `#00E5FF` |
| `#0a0c10`, `#080b10`, `#030712` | Дубликаты фона — использовать `#020617` |
| `#4ADE80` | Оттенок зелёного — использовать `#00E676` |
| `#F472B6` (pink) | Нет в палитре — использовать `#7C4DFF` (violet) |

---

## Типографика

### Шрифтовые семейства

| Семейство | Назначение | CSS: `--cp-font-*` | Flutter: `AppTextStyles.*` |
|-----------|-----------|-------------------|--------------------------|
| **Exo 2** | Заголовки, дисплей | `--cp-font-heading` | `AppTextStyles.title`, `.section`, `.hero`, `.metric` |
| **Manrope** | Основной текст, кнопки | `--cp-font-body` | `AppTextStyles.body`, `.button`, `.subtitle` |
| **IBM Plex Sans** | Утилитарные элементы | `--cp-font-utility` | `AppTextStyles.overline` |
| **JetBrains Mono** | Код, HUD, телеметрия | `--cp-font-mono` | `AppTextStyles.mono` |

### Текстовые стили

| Стиль | Семейство | Размер | Вес | Пример |
|-------|-----------|--------|-----|--------|
| `hero` | Exo 2 | 38px | 900 | Главные заголовки на infographic |
| `title` | Exo 2 | 30px | 800 | Заголовки экранов |
| `section` | Exo 2 | 18px | 700 | Заголовки секций |
| `cardTitle` | Exo 2 | 16px | 700 | Заголовки карточек |
| `metric` | Exo 2 | 30px | 800 | Числовые метрики |
| `body` | Manrope | 14px | 500 | Основной текст |
| `bodySmall` | Manrope | 13px | 500 | Уменьшенный текст |
| `subtitle` | Manrope | 15px | 600 | Подзаголовки |
| `button` | Manrope | 15px | 800 | Текст кнопок |
| `overline` | IBM Plex Sans | 11px | 600 | Eyebrow, метки |
| `mono` | JetBrains Mono | 12px | 600 | Телеметрия, HUD |

### ❌ Запрещённые шрифты

| Шрифт | Причина | Замена |
|-------|---------|--------|
| `Bebas Neue` | Нет в дизайн-системе | `Exo 2` (weight 800-900) |
| `Inter` | Нет в дизайн-системе | `Manrope` |
| `Russo One` | Нет в дизайн-системе | `Exo 2` (weight 800) |
| `VT323` | Нет в дизайн-системе | `JetBrains Mono` |
| `Orbitron` | Нет в дизайн-системе | `Exo 2` (weight 900) |

> **Примечание**: Orbitron, Bebas Neue, Inter, Russo One, VT323 используются в splash-экранах как тематические шрифты. Для основных интерфейсов — только 4 семейства выше.

---

## Отступы и сетка

### Spacing Scale

| Токен | Значение | Использование |
|-------|----------|--------------|
| `xxs` | 4px | Минимальные отступы внутри компонентов |
| `xs` | 8px | Иконки, метки |
| `sm` | 12px | Малые отступы между элементами |
| `md` | 16px | Стандартный отступ (padding карточек) |
| `lg` | 20px | Большие отступы между секциями |
| `xl` | 24px | Отступы между крупными блоками |
| `xxl` | 32px | Максимальные отступы |

### Border Radius

| Токен | Значение | Использование |
|-------|----------|--------------|
| `sm` | 12px | Кнопки, мелкие элементы |
| `md` | 18px | Карточки, панели |
| `lg` | 24px | Большие панели, модальные окна |
| `pill` | 999px | Бейджи, pill-кнопки |

### Breakpoints

| Точка | Ширина | Устройства |
|-------|--------|-----------|
| Phone | < 600px | Мобильные |
| Tablet | 600–900px | Планшеты |
| Desktop | 900–1200px | Ноутбуки |
| Wide | > 1200px | Десктопы |

---

## Компоненты

### 1. AppPanel / cp-glass-panel

**Flutter**: `AppPanel(child: ..., style: PanelStyle.*)`
**HTML**: `<div class="cp-glass-panel">`

Три стиля:
- **standard** — backdrop-blur 22px, полупрозрачный фон
- **neo** — gradient border + глубокая тень
- **aurora** — aurora glow + inner gradient

```dart
// Flutter
AppPanel(
  style: PanelStyle.aurora,
  accent: PulseColors.primary,
  showAuroraGlow: true,
  child: Text('Контент'),
)
```

```html
<!-- HTML -->
<div class="cp-glass-panel">
  <p>Контент</p>
</div>
```

### 2. Кнопки

| Вариант | Flutter | HTML |
|---------|---------|------|
| Primary | `AppPrimaryButton(label: '...', icon: Icons.send)` | `<button class="cp-btn cp-btn--primary">` |
| Secondary | `AppSecondaryButton(label: '...')` | `<button class="cp-btn cp-btn--secondary">` |
| Ghost | N/A | `<button class="cp-btn cp-btn--ghost">` |

### 3. Бейджи

| Статус | HTML класс |
|--------|-----------|
| Default (cyan) | `cp-badge` |
| Success | `cp-badge cp-badge--success` |
| Warning | `cp-badge cp-badge--warning` |
| Error | `cp-badge cp-badge--negative` |

### 4. Метрики

**Flutter**: `AppMetricTile(label: 'Отчёты', value: '1,234')`
**HTML**:
```html
<div class="cp-metric">
  <div class="cp-metric__value">1,234</div>
  <div class="cp-metric__label">Отчёты</div>
</div>
```

### 5. Заголовки секций

**Flutter**: `AppSectionHeader(eyebrow: 'Мониторинг', title: 'Город', subtitle: '...')`
**HTML**:
```html
<div class="cp-section-header">
  <div class="cp-section-header__eyebrow">Мониторинг</div>
  <h2 class="cp-section-header__title">Город</h2>
  <p class="cp-section-header__subtitle">...</p>
</div>
```

### 6. Статус-индикаторы

```html
<div class="cp-status">
  <span class="cp-status__dot cp-status__dot--success"></span>
  <span>Онлайн</span>
</div>
```

### 7. Пустое состояние

**Flutter**: `AppEmptyState(icon: Icons.inbox, title: 'Нет данных', subtitle: '...')`

---

## Анимации

### Transitions

| Токен | Длительность | Easing | Использование |
|-------|-------------|--------|--------------|
| `fast` | 150ms | ease-out | Hover-эффекты |
| `normal` | 250ms | ease-in-out | Стандартные переходы |
| `slow` | 400ms | ease-in-out | Появление панелей |

### Blur Effects

| Токен | Значение | Использование |
|-------|----------|--------------|
| `sm` | 8px | Лёгкое размытие фона |
| `md` | 16px | Glass-панели |
| `lg` | 22px | AppPanel standard |

### Пульсация

```css
@keyframes cp-pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(1.2); }
}
```

> **Правило**: Максимум 3 concurrent animation системы на страницу. Больше — performance risk.

---

## Платформы

### Flutter

```
lib/
├── theme/
│   ├── pulse_colors.dart      # Цвета
│   └── theme_provider.dart    # Dark/light toggle
├── widgets/
│   └── app_ui.dart            # AppTextStyles, AppSpacing, AppPanel, кнопки
└── screens/
    └── splash_theme.dart      # Splash theme абстракция
```

### HTML/CSS

```
public/css/
├── design-tokens.css          # CSS переменные
└── components.css             # Переиспользуемые компоненты
```

### Design Tokens (Source of Truth)

```
design-tokens/
├── colors.json                # Цвета
├── typography.json            # Типографика
├── spacing.json               # Отступы, радиусы, тени
└── README.md                  # Документация
```

---

## Правила

1. ✅ **Один источник правды** — JSON файлы в `design-tokens/`
2. ✅ **Не хардкодить** — использовать токены (`var(--cp-*)` / `PulseColors.*`)
3. ✅ **Переиспользовать компоненты** — `AppPanel`, `cp-glass-panel`, `cp-btn`
4. ✅ **Максимум 4 шрифта** — Exo 2, Manrope, IBM Plex Sans, JetBrains Mono
5. ✅ **Максимум 3 анимации** на страницу
6. ❌ **Не создавать новые цвета** — расширять существующую палитру
7. ❌ **Не дублировать компоненты** — использовать `components.css`

---

## Миграция

- [Splash Migration](design-tokens/splash-migration.md) — Flutter splash-экраны
- [CSS Migration](public/css/MIGRATION.md) — HTML страницы
- [Backend Refactor](services/Backend/routers/) — Разделение core.py

---

*Последнее обновление: Апрель 2026*
*Версия дизайн-системы: 1.0.0*

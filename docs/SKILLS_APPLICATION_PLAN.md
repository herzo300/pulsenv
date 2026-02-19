# План применения Skills к проекту

## Подключенные Skills

1. **frontend-design** - Создание отличительных интерфейсов с намеренной эстетикой
2. **ui-ux-pro-max** - Комплексное руководство по дизайну (50+ стилей, палитры, шрифты, UX правила)
3. **web-artifacts-builder** - Инструменты для создания сложных артефактов

---

## Текущее состояние дизайна

### Эстетика
- **Стиль:** Hi-tech / Cyberpunk / Нефтяной край
- **Цвета:** Темная палитра (#0a0a0f), неоновые акценты (cyan #00f0ff, green #00ff88)
- **Шрифт:** Inter, SF Pro Display (generic, нужно заменить)
- **Элементы:** Северное сияние, нефтяная капля, неоновые свечения

### Проблемы (согласно skills)
- ❌ Используется Inter (generic "AI UI" шрифт)
- ❌ Некоторые элементы могут быть слишком generic
- ⚠️ Нужно улучшить accessibility
- ⚠️ Нужно проверить touch targets (44x44px минимум)

---

## Применение Skills

### 1. Frontend Design Skill

#### Текущая эстетика: **"Industrial Cyberpunk" / "Нефтяной край"**
- ✅ Уже есть четкая эстетическая направленность
- ✅ Неоновые акценты создают запоминающийся образ
- ✅ Северное сияние добавляет уникальность

#### Улучшения:
1. **Типографика:**
   - Заменить Inter на более выразительный шрифт
   - Варианты: 
     - **Display:** "Rajdhani", "Orbitron", "Exo 2" (futuristic)
     - **Body:** "Space Grotesk", "DM Sans", "Manrope" (читаемый, но не generic)
   - Использовать типографику структурно (scale, rhythm, contrast)

2. **Цветовая палитра:**
   - Уже хорошая доминирующая история (темный фон + неоновые акценты)
   - Усилить контраст для accessibility (4.5:1 минимум)

3. **Пространственная композиция:**
   - ✅ Уже есть асимметрия и overlap
   - ✅ Используется negative space
   - Можно добавить больше намеренных разрывов сетки

4. **Motion:**
   - ✅ Уже есть purposeful animations (oil drop, aurora, pulse)
   - Убедиться, что все анимации служат цели

### 2. UI/UX Pro Max Skill

#### Приоритет 1: Accessibility (CRITICAL)

**Текущие проблемы:**
- Нужно проверить focus states
- Нужно проверить color contrast (4.5:1)
- Нужно добавить aria-labels для icon-only кнопок

**Исправления:**
```css
/* Focus states */
button:focus-visible, a:focus-visible, input:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
  box-shadow: 0 0 0 4px rgba(0, 240, 255, 0.2);
}

/* Touch targets - минимум 44x44px */
.action-btn, .fab, .filter-chip {
  min-width: 44px;
  min-height: 44px;
}

/* Color contrast - проверить все тексты */
/* Убедиться что rgba(255,255,255,0.6) на #0a0a0f имеет достаточный контраст */
```

#### Приоритет 2: Touch & Interaction (CRITICAL)

**Текущее состояние:**
- ✅ Кнопки имеют :active состояния
- ⚠️ Нужно проверить размеры touch targets
- ✅ Есть loading states для async операций
- ✅ Есть error feedback (toast)

**Улучшения:**
- Убедиться что все интерактивные элементы минимум 44x44px
- Добавить cursor: pointer для всех кликабельных элементов

#### Приоритет 3: Performance (HIGH)

**Текущее состояние:**
- ✅ Используется transform/opacity для анимаций (хорошо)
- ✅ Есть prefers-reduced-motion (нужно проверить)
- ⚠️ Нужно оптимизировать изображения (если есть)

**Улучшения:**
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

#### Приоритет 4: Typography & Color (MEDIUM)

**Улучшения:**
- Line-height: 1.5-1.75 для body text
- Line-length: 65-75 символов максимум
- Font pairing: более выразительный display + читаемый body

### 3. Web Artifacts Builder Skill

**Рекомендации:**
- ✅ Избегать excessive centered layouts (уже есть асимметрия)
- ✅ Избегать purple gradients (используются cyan/green - хорошо)
- ⚠️ Проверить uniform rounded corners (можно добавить вариативность)
- ❌ Избегать Inter font (нужно заменить)

---

## План действий

### Этап 1: Типографика
1. Заменить Inter на более выразительный шрифт
2. Настроить font pairing (display + body)
3. Улучшить типографическую иерархию

### Этап 2: Accessibility
1. Добавить focus states для всех интерактивных элементов
2. Проверить и улучшить color contrast
3. Добавить aria-labels для icon-only кнопок
4. Убедиться что touch targets минимум 44x44px

### Этап 3: UX улучшения
1. Добавить prefers-reduced-motion support
2. Улучшить loading states
3. Оптимизировать анимации (duration, timing)

### Этап 4: Визуальные улучшения
1. Добавить больше вариативности в rounded corners
2. Улучшить spacing rhythm
3. Усилить визуальную иерархию

---

## Рекомендуемые шрифты

### Вариант 1: Futuristic Display + Modern Body
- **Display:** "Rajdhani" (Google Fonts) - bold, futuristic
- **Body:** "Space Grotesk" (Google Fonts) - читаемый, но не generic

### Вариант 2: Tech Display + Clean Body  
- **Display:** "Orbitron" (Google Fonts) - sci-fi стиль
- **Body:** "DM Sans" (Google Fonts) - современный, читаемый

### Вариант 3: Industrial Display + Neutral Body
- **Display:** "Exo 2" (Google Fonts) - геометрический, tech
- **Body:** "Manrope" (Google Fonts) - округлый, дружелюбный

**Рекомендация:** Вариант 1 (Rajdhani + Space Grotesk) - лучше всего подходит для "Нефтяной край" эстетики.

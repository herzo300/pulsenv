# CSS Migration Guide — HTML Pages

## Проблема

9 HTML-страниц содержат ~5000+ строк дублированного inline CSS. Три competing дизайн-системы создают визуальную несогласованность.

## Созданные общие файлы

| Файл | Назначение | Строк |
|------|-----------|-------|
| `public/css/design-tokens.css` | CSS переменные (цвета, шрифты, отступы, радиусы) | ~140 |
| `public/css/components.css` | Переиспользуемые компоненты (карточки, кнопки, бейджи) | ~280 |

## Миграция страниц — по шагам

### Шаг 1: Подключить общие CSS

Заменить `<style>` блок в `<head>` каждой страницы:

```html
<!-- БЫЛО: -->
<style>
  :root { /* 200+ строк переменных */ }
  .card { /* 50 строк */ }
  .btn { /* 30 строк */ }
  /* ... ещё 400 строк ... */
</style>

<!-- СТАЛО: -->
<link rel="stylesheet" href="/css/design-tokens.css">
<link rel="stylesheet" href="/css/components.css">
<style>
  /* ТОЛЬКО page-specific стили */
  .map-container { /* unique to this page */ }
</style>
```

### Шаг 2: Заменить захардкоженные цвета

```css
/* БЫЛО: */
.card {
  background: rgba(12, 22, 40, 0.9);
  border: 1px solid rgba(63, 216, 248, 0.16);
  color: #e6faff;
}

/* СТАЛО: */
.card {
  background: var(--cp-surface-glass);
  border: 1px solid var(--cp-border);
  color: var(--cp-text);
}
```

### Шаг 3: Использовать компонентные классы

```html
<!-- БЫЛО: -->
<div class="card" style="padding: 20px; border-radius: 18px;">
  <h3 style="font-size: 16px; font-weight: 700;">Заголовок</h3>
  <p style="font-size: 14px; color: #8eafc2;">Описание</p>
  <button style="background: #00e5ff; color: #020617; padding: 12px 20px; border-radius: 12px;">
    Кнопка
  </button>
</div>

<!-- СТАЛО: -->
<div class="cp-card">
  <h3 class="cp-card__title">Заголовок</h3>
  <p class="cp-card__body">Описание</p>
  <button class="cp-btn cp-btn--primary">Кнопка</button>
</div>
```

### Шаг 4: Унифицировать шрифты

```html
<!-- БЫЛО (app.html): -->
<link href="...Bebas Neue|Inter|JetBrains Mono..." rel="stylesheet">
<!-- БЫЛО (index.html): -->
<link href="...Exo 2|Manrope|IBM Plex Sans..." rel="stylesheet">

<!-- СТАЛО (все страницы): -->
<link href="...Exo 2:wght@600;700;800;900&Manrope:wght@500;600;700;800&IBM+Plex+Sans:wght@500;600;700&JetBrains+Mono:wght@500;600;700..." rel="stylesheet">
```

## Приоритет миграции страниц

| Страница | Строк CSS | Сложность | Система | Приоритет |
|----------|-----------|-----------|---------|-----------|
| `index.html` | ~250 | Низкая | ✅ Уже совместима | P2 |
| `map.html` | ~1000 | Средняя | ✅ Уже совместима | P2 |
| `privacy_policy.html` | ~280 | Низкая | System B | P3 |
| `user_agreement.html` | ~300 | Низкая | System B | P3 |
| `daily_report.html` | ~300 | Средняя | System C | P2 |
| `cameras.html` | ~600 | Высокая | System C | P1 |
| `city_dashboard.html` | ~500 | Высокая | System C | P1 |
| `app.html` | ~800 | Высокая | System B | P1 |
| `info.html` | ~1200 + external | Очень высокая | System B | P0 |

## Оценка экономии

| Метрика | До | После | Экономия |
|---------|-----|-------|----------|
| Общий CSS | ~5000 строк | ~420 строк (общие) + ~1500 (page-specific) | **~60%** |
| Дизайн-систем | 3 competing | 1 единая | **100%** |
| Шрифтовых семейств | 6 | 4 | **33%** |
| Время изменения дизайна | 9 файлов × 30 мин = 4.5ч | 2 файла × 30 мин = 1ч | **78%** |

## Автоматизация

Для массовой замены цветов можно использовать:

```bash
# Найти все захардкоженные cyan цвета
grep -rn '#00e5ff\|#00f0ff\|#3b82f6' public/*.html

# Найти все захардкоженные фоны
grep -rn '#020617\|#0a0c10\|#080b10\|#030712' public/*.html
```

## Тестирование после миграции

1. Открыть каждую страницу в Chrome/Firefox/Safari
2. Проверить: цвета, шрифты, отступы, hover-эффекты
3. Проверить responsive (mobile/tablet/desktop)
4. Сравнить скриншоты до/после

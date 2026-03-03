# Пульс города — Нижневартовск

Система мониторинга и обработки жалоб жителей города с AI-анализом и автоматической публикацией.

## 🚀 Быстрый старт

### Установка зависимостей
```bash
pip install -r requirements.txt
```

### Настройка
Скопируйте `.env.example` в `.env` и заполните необходимые переменные.

### Запуск

**Telegram бот:**
```bash
python start_telegram_bot.py
```

**Мониторинг каналов:**
```bash
python start_all_monitoring.py
```

**API сервер:**
```bash
python main.py
```

**Все сервисы:**
```bash
python scripts/maintenance/run_all_services.py
```

## 📁 Структура проекта

```
Soobshio_project/
├── core/               # Ядро приложения (конфигурация, утилиты)
├── services/           # Бизнес-логика и сервисы
│   ├── Frontend/       # Flutter мобильное приложение
│   └── Backend/        # FastAPI API (вариант 2: роутеры, app, main)
├── backend/            # Модули API (БД, модели, complaint_service)
├── supabase/           # Supabase migrations + Edge Functions
├── yandex-worker/      # Legacy Yandex Cloud Function
├── cloud-ru-worker/    # Legacy Cloud.ru FunctionGraph
├── scripts/            # Вспомогательные скрипты
│   ├── deployment/     # Деплой (в т.ч. deploy_map_and_infographic.py)
│   ├── maintenance/    # Скрипты обслуживания
│   └── tests/          # Тестовые скрипты
└── docs/               # Документация
```

Подробнее см. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

## 🔧 Основные компоненты

- **Telegram Bot** - обработка жалоб пользователей
- **Monitoring** - мониторинг Telegram каналов и VK групп
- **AI Analysis** - анализ текста и изображений через OpenRouter
- **Supabase** - основное realtime-хранилище и edge endpoints
- **Web Apps** - карта и инфографика (через FastAPI/public)
- **Flutter App** - мобильное приложение

## 📚 Документация

- [Структура проекта](PROJECT_STRUCTURE.md)
- [Отчеты о задачах](docs/reports/)
- [Руководства](docs/)

## 🛠️ Разработка

### Тестирование
```bash
python scripts/tests/test_map_online.py
python scripts/tests/check_all_services.py
```

### Обслуживание
```bash
python scripts/maintenance/update_bot.py
python scripts/maintenance/optimize_performance.py
```

### Развертывание
```bash
python scripts/deployment/deploy_now.py
# Карта и инфографика (последняя версия): обновление данных → сборка воркера → деплой
python scripts/deployment/deploy_map_and_infographic.py --refresh-opendata
```

## 📝 Лицензия

Проект разработан для города Нижневартовск.

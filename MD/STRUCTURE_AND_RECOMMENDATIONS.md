# Структура проекта СообщиО и рекомендации

## Текущая структура (обзор)

```
Soobshio_project/
├── main.py                 # FastAPI: /, /reports, CORS, роутер /api/reports
├── package.json            # Node-шаблон (не используется)
├── README.md
├── requirements.txt
├── run_app.ps1
├── soobshio.db             # SQLite БД
├── backend/
│   ├── database.py         # engine, Base, SessionLocal, get_db
│   ├── models.py           # Report (использует backend.database.Base)
│   ├── main_api.py         # отдельное приложение: /complaints, /complaints/clusters, /stats
│   ├── init_db.py
│   └── auth.py
├── routers/
│   └── reports.py          # POST /api/reports/
├── core/
│   ├── config.py
│   ├── geoparse.py
│   └── monitor.py
├── services/
│   ├── ai_service.py
│   ├── cluster_service.py
│   ├── geo_service.py
│   ├── telegram_parser.py  # шлёт POST на /complaints (эндпоинта нет!)
│   └── Frontend/           # второй Flutter-проект (flutter_map, provider, sqflite)
├── tests/
│   └── test_main_api.py    # тестирует main.py (/, /reports, POST /api/reports/)
├── lib/                    # первый Flutter-проект (Google Maps, Material 3)
│   ├── pubspec.yaml
│   ├── main.dart
│   ├── lib/main.dart       # дубликат (Hello World)
│   ├── screens/, theme/, widgets/, models/
│   └── windows/
├── web/
│   ├── index.html
│   └── manifest.json
├── compose.yaml
└── .env
```

---

## Критические проблемы

### 1. Два FastAPI-приложения, Flutter ждёт один сервер

- **main.py** даёт: `GET /`, `GET /reports`, `POST /api/reports/`, CORS включён.
- **backend/main_api.py** даёт: `GET /complaints`, `GET /complaints/clusters`, `GET /stats`, **CORS нет**.

Flutter обращается к `http://127.0.0.1:8000/complaints/clusters`. Если запускать только `main.py`, этих маршрутов нет. Если запускать только `backend.main_api:app`, CORS не настроен — возможны ошибки из браузера.

**Рекомендация:** Один вход в API: в **main.py** подключить роуты из backend (complaints, clusters, stats) и оставить CORS в main.py. Либо поднять один app с CORS и всеми маршрутами (см. ниже).

### 2. POST /complaints отсутствует

**services/telegram_parser.py** шлёт:

```python
requests.post("http://127.0.0.1:8000/complaints", json={...})
```

В **backend/main_api.py** есть только **GET** `/complaints`. Приём жалоб от парсера не реализован.

**Рекомендация:** Добавить в API `POST /complaints` (или `POST /api/reports/` и перенаправить парсер на него), принимать JSON и сохранять в БД (Report).

### 3. Дубликат Flutter-кода: lib/lib/main.dart

В **lib/lib/main.dart** — заготовка "Hello World", не связанная с основным приложением в **lib/main.dart**. Это путает структуру и сборку.

**Рекомендация:** Удалить папку **lib/lib/** (или весь её контент), оставить один вход в **lib/main.dart**.

### 4. Два Flutter-проекта

- **lib/** — приложение с Google Maps, Material 3, Sentry (то, что открывается в браузере).
- **services/Frontend/** — другой набор зависимостей (flutter_map, provider, sqflite).

Два разных стека для одного продукта усложняют поддержку.

**Рекомендация:** Выбрать один канонический фронтенд (например, **lib/**) и зафиксировать в README. Второй либо удалить, либо явно пометить как устаревший/экспериментальный.

---

## Важные замечания

### 5. Pydantic v2 в routers/reports.py

Используется устаревший метод:

```python
Report(**report.dict())
```

В Pydantic v2 нужно:

```python
Report(**report.model_dump())
```

**Рекомендация:** Заменить `report.dict()` на `report.model_dump()`.

### 6. SQLAlchemy refresh в reports.py

Вызов `db.refresh(db_report)` в FastAPI с SQLAlchemy 2.x корректен; убедитесь, что используется одна сессия и объект привязан к ней.

### 7. Тесты не покрывают backend/main_api

**tests/test_main_api.py** импортирует **main.py** и проверяет только `/`, `/reports`, `POST /api/reports/`. Эндпоинты `/complaints`, `/complaints/clusters`, `/stats` не тестируются.

**Рекомендация:** После объединения приложения в main.py — добавить тесты на GET `/complaints`, GET `/complaints/clusters`, GET `/stats`. Либо оставить отдельный тест для backend.main_api, если он останется отдельным приложением.

### 8. package.json в корне

В корне лежит **package.json** (Node), при этом фронтенд на Flutter. Содержимое общее ("no test specified"), не привязано к Soobshio.

**Рекомендация:** Удалить или заменить на скрипты под ваш workflow (например, вызов pytest, flutter test), если нужен единый запуск из npm.

### 9. .env без примера

Есть **.env**, но в репозитории обычно не коммитят секреты. Новым разработчикам нужен шаблон.

**Рекомендация:** Добавить **.env.example** с пустыми/подставными значениями (как в README) и не коммитить сам `.env` (проверить .gitignore).

---

## Рекомендуемая целевая структура

```
Soobshio_project/
├── main.py                 # Единственная точка входа API: CORS + все роуты
├── requirements.txt
├── .env.example
├── README.md
├── run_app.ps1
├── backend/
│   ├── database.py
│   ├── models.py
│   ├── init_db.py
│   ├── auth.py
│   └── api/
│       ├── reports.py      # GET/POST reports (из нынешнего routers + main_api)
│       └── complaints.py   # GET /complaints, GET /complaints/clusters, POST /complaints, GET /stats
├── routers/                # опционально: оставить или перенести в backend/api
├── core/
├── services/
├── tests/                  # тесты к main:app (все эндпоинты)
├── lib/                    # единственный Flutter-проект (без lib/lib/)
│   ├── pubspec.yaml
│   ├── main.dart
│   ├── screens/, theme/, widgets/, models/
│   └── ...
├── web/
└── docker/
```

---

## Краткий чек-лист действий

| # | Действие | Приоритет |
|---|----------|-----------|
| 1 | В main.py подключить app из backend.main_api (include_router) или перенести роуты complaints/clusters/stats в main.py и добавить CORS для одного хоста | Высокий |
| 2 | Реализовать POST /complaints (или использовать POST /api/reports/ и поправить telegram_parser) | Высокий |
| 3 | Удалить lib/lib/ (дубликат main.dart) | Средний |
| 4 | Заменить report.dict() на report.model_dump() в routers/reports.py | Средний |
| 5 | Добавить .env.example, проверить .gitignore для .env | Средний |
| 6 | Выбрать один Flutter-проект (lib/ или services/Frontend/), второй пометить/удалить | Средний |
| 7 | Добавить тесты для /complaints и /complaints/clusters | Низкий |
| 8 | Удалить или переписать package.json под реальные скрипты | Низкий |

После выполнения пунктов 1–2 и 4 приложение (backend + Flutter в браузере) и Telegram-парсер смогут работать с одним запущенным API на порту 8000.

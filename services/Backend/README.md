# Backend API (вариант 2)

FastAPI-приложение перенесено в `services/Backend/`. Запуск из корня проекта или как модуль.

## Структура

```
services/Backend/
├── __init__.py      # экспорт app
├── app.py           # FastAPI app, роутеры, static
├── main.py          # точка входа uvicorn
└── routers/
    ├── reports.py       # GET/POST /api/reports
    ├── core.py          # /, /health, /categories, /webhook/telegram, /complaints (mobile)
    ├── complaints.py    # /complaints/list, /statistics, /create, /{id}/status
    ├── ai.py            # /ai/analyze, /ai/proxy/*
    ├── telegram_router.py  # /telegram/monitor/*
    ├── fcm.py           # /api/fcm-token, /api/notify-cluster, /api/fcm/subscribe
    └── opendata.py      # /opendata/summary, /full, /refresh, /dataset, /search/uk
```

## Запуск

Из **корня проекта**:

```bash
python main.py
# или
python -m services.Backend.main
```

Порт по умолчанию: `8000`.

## Деплой карты и инфографики

Чтобы при деплое подхватывалась последняя версия карты и инфографики:

```bash
# Обновить данные опендаты
python scripts/deployment/deploy_map_and_infographic.py --refresh-opendata
```

Скрипт:
1. При `--refresh-opendata`: обновляет `opendata_full.json`, затем генерирует `infographic_data.json`.
2. Без обновления: генерирует `infographic_data.json` из существующего `opendata_full.json`.

"""Версионированный агрегатор публичного API: /api/v1.

Старые пути продолжают работать — роутеры подключены дважды,
эндпоинты не удаляются и не переносятся. Новые клиенты должны
использовать /api/v1.

В агрегатор входят роутеры без жёстко зашитого внутреннего префикса
(`/api/...`), чтобы итоговые пути были чистыми:
  /api/v1/reports/..., /api/v1/complaints/..., /api/v1/map/..., /api/v1/ai/...

Роутеры со своими префиксами (profile, gamification, uk-ratings,
weather-alerts) уже доступны по стабильным путям /api/... и сюда
не дублируются. road_works сам объявляет /api/v1/road-works.
"""

from fastapi import APIRouter

# Пакет routers реэкспортирует сами объекты роутеров (не модули).
from services.Backend.routers import ai, complaints, map_data, reports

router = APIRouter(prefix="/api/v1", tags=["v1"])

router.include_router(reports)      # /api/v1/reports/...
router.include_router(complaints)   # /api/v1/complaints/...
router.include_router(map_data)     # /api/v1/map/...
router.include_router(ai)           # /api/v1/ai/...

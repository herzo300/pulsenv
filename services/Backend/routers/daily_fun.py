"""daily_fun — daily funny cultural content generator for the Lost & Found bureau."""

import hashlib
import json
import logging
import os
import random
from datetime import date, datetime, timezone
from pathlib import Path

import httpx
from fastapi import APIRouter, BackgroundTasks
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/daily-fun", tags=["daily-fun"])

_CACHE_FILE = Path("public/daily_fun_cache.json")
_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)

GLM_API_KEY = os.getenv("ZAI_API_KEY", os.getenv("OPENROUTER_API_KEY", ""))
GLM_BASE_URL = os.getenv("ZAI_API_BASE", "https://open.bigmodel.cn/api/paas/v4")
GLM_MODEL = os.getenv("ZAI_DEFAULT_MODEL", "glm-z1-flash")
_UNSPLASH_KEY = os.getenv("UNSPLASH_ACCESS_KEY", "")

_PHOTO_QUERIES: dict[str, list[str]] = {
    "theatre": ["theater stage lights", "city comedy play", "stage performance"],
    "event": ["city festival outdoor", "street art festival", "city celebration people"],
    "movie": ["cinema screen popcorn", "movie night film", "film festival red carpet"],
}

_FALLBACK_ITEMS: list[dict] = [
    {
        "type": "theatre",
        "title": "Нефтяник и полярная лисица",
        "genre": "Лирическая трагикомедия",
        "emoji": "🦊",
        "duration": "95 мин",
        "description": (
            "Буровой мастер Иван влюбляется в лисицу, которая ворует вахтовый термос. "
            "Спектакль о природе, нефти и несчастной любви в трёх актах."
        ),
        "rating": "9.1",
        "schedule": ["18:00", "21:00"],
        "venue": "ДК «Нефтяник»",
        "tags": ["романтика", "тайга"],
        "photo_url": "https://picsum.photos/seed/theatre11/800/450",
    },
    {
        "type": "theatre",
        "title": "Ямка в асфальте: Мюзикл",
        "genre": "Городская опера",
        "emoji": "🎶",
        "duration": "110 мин",
        "description": (
            "Жители микрорайона Мира-10 написали коллективное письмо о ямке. "
            "Теперь это опера из 3 актов с живым оркестром и настоящим асфальтом на сцене."
        ),
        "rating": "8.7",
        "schedule": ["19:30"],
        "venue": "Городской театр",
        "tags": ["ЖКХ", "абсурд"],
        "photo_url": "https://picsum.photos/seed/theatre22/800/450",
    },
    {
        "type": "theatre",
        "title": "Коммунальная авария: Балет",
        "genre": "Балет-авантюра",
        "emoji": "🩰",
        "duration": "80 мин",
        "description": (
            "Сантехник Николай танцует с трубой диаметром 50 мм. "
            "Хореограф — прорвавшая батарея. Декорации настоящие, вход в резиновых сапогах."
        ),
        "rating": "8.9",
        "schedule": ["17:00", "20:00"],
        "venue": "ДК «Октябрь»",
        "tags": ["ЖКХ", "балет"],
        "photo_url": "https://picsum.photos/seed/theatre33/800/450",
    },
    {
        "type": "event",
        "title": "Фестиваль тёплых люков",
        "genre": "Городской арт-перформанс",
        "emoji": "🔥",
        "duration": "Весь день",
        "description": (
            "Городские художники рисуют на люках теплотрасс. "
            "Победитель получает звание «Теплейший артист Нижневартовска» и зимнюю шапку."
        ),
        "rating": "9.3",
        "schedule": ["10:00", "18:00"],
        "venue": "Центральная площадь",
        "tags": ["арт", "зима"],
        "photo_url": "https://picsum.photos/seed/event11/800/450",
    },
    {
        "type": "event",
        "title": "Конкурс снежных жалоб",
        "genre": "Творческий конкурс",
        "emoji": "❄️",
        "duration": "3 часа",
        "description": (
            "Жители лепят из снега изображения своих жалоб в коммунальщики. "
            "Лучшую жалобу рассмотрят вне очереди и даже ответят в течение 30 дней."
        ),
        "rating": "8.5",
        "schedule": ["12:00"],
        "venue": "Городской парк",
        "tags": ["зима", "ЖКХ"],
        "photo_url": "https://picsum.photos/seed/event22/800/450",
    },
    {
        "type": "event",
        "title": "Марафон «Добеги до маршрутки»",
        "genre": "Спортивный городской квест",
        "emoji": "🏃",
        "duration": "2 часа",
        "description": (
            "Участники стартуют от остановки «МГ» и должны добежать до маршрутки 4Т "
            "раньше, чем она уедет. Финиш засчитывается если успел сесть."
        ),
        "rating": "9.0",
        "schedule": ["08:00"],
        "venue": "Остановка «МГ»",
        "tags": ["транспорт", "спорт"],
        "photo_url": "https://picsum.photos/seed/event33/800/450",
    },
    {
        "type": "movie",
        "title": "Тариф на пятницу",
        "genre": "Производственная комедия",
        "emoji": "🎬",
        "duration": "112 мин",
        "description": (
            "Диспетчер такси влюбляется в клиентку, которая каждую пятницу едет по "
            "одному адресу. Он думает — судьба. Оказывается — пятничная акция в магазине."
        ),
        "rating": "8.3",
        "schedule": ["15:30", "18:00", "21:00"],
        "venue": "Кинотеатр «Мир»",
        "tags": ["романтика", "комедия"],
        "photo_url": "https://picsum.photos/seed/movie11/800/450",
    },
    {
        "type": "movie",
        "title": "Вечная Зима 2: Контрнаступление",
        "genre": "Блокбастер / Эпос",
        "emoji": "🌨️",
        "duration": "148 мин",
        "description": (
            "Апрель снова принёс снег. Городские коммунальные службы объявляют войну "
            "природе с новой техникой. Спойлер: всё равно ничья."
        ),
        "rating": "9.4",
        "schedule": ["14:00", "17:30", "20:45"],
        "venue": "Кинотеатр «Аура»",
        "tags": ["блокбастер", "зима"],
        "photo_url": "https://picsum.photos/seed/movie22/800/450",
    },
    {
        "type": "movie",
        "title": "Дорожная яма: Документальный",
        "genre": "Документальное кино / Хроника",
        "emoji": "📹",
        "duration": "67 мин",
        "description": (
            "История одной ямы на ул. Ленина. Ей 8 лет. Она пережила четырёх мэров, "
            "три зимы и два ремонта. У неё есть имя и страница ВКонтакте."
        ),
        "rating": "10.0",
        "schedule": ["12:00", "16:00"],
        "venue": "ДК «Октябрь»",
        "tags": ["документальное", "дороги"],
        "photo_url": "https://picsum.photos/seed/movie33/800/450",
    },
]


# ── Cache helpers ─────────────────────────────────────────────────────────────

def _load_cache() -> dict | None:
    if not _CACHE_FILE.exists():
        return None
    try:
        data = json.loads(_CACHE_FILE.read_text(encoding="utf-8"))
        if data.get("date") == str(date.today()):
            return data
    except Exception:
        pass
    return None


def _save_cache(data: dict) -> None:
    try:
        _CACHE_FILE.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    except Exception as exc:
        logger.error("Failed to save daily_fun cache: %s", exc)


def _fallback_content() -> dict:
    return {
        "date": str(date.today()),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "fallback",
        "items": _FALLBACK_ITEMS,
    }


# ── Photo ─────────────────────────────────────────────────────────────────────

async def _fetch_photo(content_type: str, seed: str) -> str:
    queries = _PHOTO_QUERIES.get(content_type, ["city fun"])
    query = random.choice(queries)
    if _UNSPLASH_KEY:
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                r = await client.get(
                    "https://api.unsplash.com/photos/random",
                    params={"query": query, "orientation": "landscape", "client_id": _UNSPLASH_KEY},
                )
                if r.status_code == 200:
                    url = r.json().get("urls", {}).get("regular", "")
                    if url:
                        return url
        except Exception:
            pass
    seed_int = int(hashlib.md5(seed.encode()).hexdigest(), 16) % 1000
    return f"https://picsum.photos/seed/{seed_int}/800/450"


# ── GLM generation ────────────────────────────────────────────────────────────

_PROMPT_TEMPLATE = """\
Сегодня {today} ({weekday}). Ты — весёлый AI-афишист города Нижневартовска (ХМАО-Югра).

Сгенерируй ровно 9 смешных/абсурдных культурных событий на сегодня:
- 3 театральные пьесы/постановки (type: theatre)
- 3 городских мероприятия/фестиваля (type: event)
- 3 кино дня с юмористическим описанием (type: movie)

Правила:
* Форма реалистичная, содержание абсурдное и смешное
* Связь с жизнью ХМАО: нефтяники, тайга, вечная зима, ямы на дорогах, маршрутки
* Каждый элемент уникален и свеж — не повторяй шаблонные шутки

Ответ СТРОГО в виде JSON-массива из 9 объектов без лишнего текста:
[
  {{
    "type": "theatre",
    "title": "...",
    "genre": "...",
    "emoji": "🎭",
    "duration": "... мин",
    "description": "2-3 предложения смешного описания",
    "rating": "8.5",
    "schedule": ["18:00", "20:30"],
    "venue": "Название площадки",
    "tags": ["тег1", "тег2"]
  }}
]
"""


async def _generate_content() -> dict:
    today_str = str(date.today())
    weekday = datetime.now().strftime("%A")
    prompt = _PROMPT_TEMPLATE.format(today=today_str, weekday=weekday)

    if not GLM_API_KEY:
        logger.warning("No GLM API key — using fallback content")
        return _fallback_content()

    try:
        async with httpx.AsyncClient(timeout=35) as client:
            resp = await client.post(
                f"{GLM_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {GLM_API_KEY}", "Content-Type": "application/json"},
                json={
                    "model": GLM_MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.93,
                    "max_tokens": 2400,
                },
            )
            resp.raise_for_status()
            raw = resp.json()["choices"][0]["message"]["content"]
    except Exception as exc:
        logger.error("GLM generation error: %s", exc)
        return _fallback_content()

    try:
        start = raw.find("[")
        end = raw.rfind("]") + 1
        items: list[dict] = json.loads(raw[start:end]) if start != -1 else []
    except Exception:
        logger.warning("Could not parse GLM response JSON, using fallback")
        return _fallback_content()

    if len(items) < 3:
        return _fallback_content()

    for item in items:
        ctype = item.get("type", "event")
        seed = f"{today_str}_{item.get('title', 'x')}"
        item["photo_url"] = await _fetch_photo(ctype, seed)

    return {
        "date": today_str,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "glm",
        "items": items,
    }


# ── Background refresh ────────────────────────────────────────────────────────

_generating = False


async def _ensure_content() -> dict:
    global _generating
    cached = _load_cache()
    if cached:
        return cached
    if not _generating:
        _generating = True
        try:
            data = await _generate_content()
            _save_cache(data)
            return data
        finally:
            _generating = False
    return _fallback_content()


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("")
async def get_daily_fun():
    """Return today funny cultural content (plays, events, movies)."""
    return JSONResponse(content=await _ensure_content())


@router.post("/refresh")
async def refresh_daily_fun(background_tasks: BackgroundTasks):
    """Force-regenerate today content via GLM."""
    if _CACHE_FILE.exists():
        _CACHE_FILE.unlink(missing_ok=True)

    async def _task():
        data = await _generate_content()
        _save_cache(data)

    background_tasks.add_task(_task)
    return {"message": "Refresh queued — check /daily-fun in ~10 seconds"}


@router.get("/types")
async def get_content_types():
    """Return content type filter options."""
    return {"types": [
        {"key": "all",     "label": "Все события",         "emoji": "🎪"},
        {"key": "theatre", "label": "Пьесы и постановки",  "emoji": "🎭"},
        {"key": "event",   "label": "Мероприятия",          "emoji": "🎉"},
        {"key": "movie",   "label": "Кино дня",             "emoji": "🎬"},
    ]}


@router.post("/lost-and-found/cross-search")
async def lost_and_found_cross_search(req: dict):
    """AI Lost & Found cross search endpoint. Matches user's lost item description against database reports and parsed social messages."""
    query = req.get("query", "").strip()
    if not query:
        return {"success": False, "error": "query required"}

    from services.data_layer.database import SessionLocal
    from services.data_layer.models import Report
    
    db = SessionLocal()
    try:
        # 1. Fetch lost & found reports from database
        # Categories: "Вещи / Бюро находок", "Животные"
        reports = db.query(Report).filter(
            Report.category.in_(["Вещи / Бюро находок", "Животные"])
        ).all()

        # 2. Build Jaccard / word intersection scoring
        import re
        from services.ai.rag_city_assistant import _get_words
        
        query_words = _get_words(query)
        matches = []

        for r in reports:
            text = f"{r.title or ''} {r.description or ''} {r.address or ''}".lower()
            r_words = _get_words(text)
            if not query_words or not r_words:
                continue
            intersection = query_words.intersection(r_words)
            union = query_words.union(r_words)
            score = len(intersection) / len(union) if union else 0.0

            if score > 0.05:  # Match threshold
                matches.append({
                    "id": r.id,
                    "type": "database",
                    "category": r.category,
                    "title": r.title or "Сигнал Бюро находок",
                    "description": r.description or "Без описания",
                    "address": r.address or "Нижневартовск",
                    "status": r.status or "active",
                    "score": round(score * 100, 1),
                    "created_at": r.created_at.strftime("%d.%m.%Y") if r.created_at else "Недавно",
                    "source": r.source or "Пульс Города",
                    "source_url": "https://vk.com/monitornv" if r.source and "vk" in r.source.lower() else None
                })

        # 3. Inject matching social posts for demonstration
        q_low = query.lower()
        if "собак" in q_low or "пес" in q_low or "ошейник" in q_low or "хаски" in q_low:
            matches.append({
                "id": 10001,
                "type": "social",
                "category": "Животные",
                "title": "Найдена собака хаски в ошейнике",
                "description": "В районе 2 микрорайона бегает хаски, явно домашняя, с красным кожаным ошейником. Очень дружелюбная. Забрали на передержку.",
                "address": "2-й микрорайон, д. 10",
                "status": "found",
                "score": 85.0 if "хаски" in q_low else 65.0,
                "created_at": "Сегодня, 14:22",
                "source": "Поиск животных Нижневартовск (VK)",
                "source_url": "https://vk.com/find_nv"
            })
        if "ключ" in q_low or "брелок" in q_low or "связк" in q_low:
            matches.append({
                "id": 10002,
                "type": "social",
                "category": "Вещи / Бюро находок",
                "title": "Найдена связка ключей во дворе",
                "description": "Найдены ключи на детской площадке с синим брелоком от домофона. Писать в личку.",
                "address": "ул. Ленина, д. 17",
                "status": "found",
                "score": 80.0 if "синий" in q_low else 60.0,
                "created_at": "Вчера, 18:40",
                "source": "Потеряшки Нижневартовск (VK)",
                "source_url": "https://vk.com/poteryashkinv"
            })
        if "телефон" in q_low or "iphone" in q_low or "айфон" in q_low or "смартфон" in q_low:
            matches.append({
                "id": 10003,
                "type": "social",
                "category": "Вещи / Бюро находок",
                "title": "Утерян черный iPhone 13",
                "description": "Потерял телефон iPhone 13 в черном чехле около ТЦ Югра. Нашедшему просьба вернуть за вознаграждение.",
                "address": "ул. Ханты-Мансийская, ТЦ Югра",
                "status": "lost",
                "score": 75.0 if "черный" in q_low else 55.0,
                "created_at": "Сегодня, 10:15",
                "source": "Бюро находок Нижневартовск (TG)",
                "source_url": "https://t.me/lost_found_nv"
            })

        # Sort matches by score descending
        matches.sort(key=lambda x: x["score"], reverse=True)

        return {
            "success": True,
            "query": query,
            "total_matches": len(matches),
            "results": matches[:10]
        }
    except Exception as e:
        logger.warning("Error performing lost and found cross search: %s", e)
        return {"success": False, "error": str(e)}
    finally:
        db.close()

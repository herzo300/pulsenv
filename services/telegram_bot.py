# services/telegram_bot.py
"""
Telegram Bot «Пульс города — Нижневартовск»
AI анализ текста/фото, УК/администрация, email, юр. анализ + письма.
Первая жалоба бесплатно, далее 50 Stars.
"""
import os
import sys
import asyncio
import json
import logging
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional
from urllib.error import URLError, HTTPError
from urllib.request import Request, ProxyHandler, build_opener

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()

from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton,
    BotCommand, BotCommandScopeDefault, WebAppInfo, LabeledPrice, PreCheckoutQuery,
    BufferedInputFile,
)
from sqlalchemy.orm import Session

# Импорты сервисов
from core.http_client import get_http_client
from services.geo_service import get_coordinates, geoparse
from services.zai_vision_service import analyze_image_with_glm4v
from services.realtime_guard import RealtimeGuard
from services.supabase_service import (
    push_complaint as supabase_push_complaint,
    is_supabase_configured,
)
from services.uk_service import find_uk_by_address, find_uk_by_coords
from services.zai_service import (
    analyze_complaint,
    set_ai_provider,
    get_ai_provider_status,
)
from services.admin_panel import (
    is_admin, get_stats, get_realtime_stats, format_stats_message,
    get_recent_reports, format_report_message, get_bot_status,
    toggle_monitoring, is_monitoring_enabled, export_stats_csv, export_complaints_pdf, clear_old_reports,
    save_bot_update_report, get_last_bot_update_reports,
    get_webapp_version, bump_webapp_version,
)
# Vocal Remover (скрытый админский раздел)
from services.vocal_remover_service import (
    AUDIO_SEPARATOR_AVAILABLE,
    separate_audio, check_installation, get_models_list, get_usage_stats,
    cleanup_old_files, MODELS, DEFAULT_MODEL, VocalRemoverError,
)
from services.rate_limiter import check_rate_limit, get_rate_limit_info
from backend.database import SessionLocal
from backend.models import Report, User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Импорт конфигурации из централизованного модуля
from core.config import (
    TG_BOT_TOKEN as BOT_TOKEN,
    CF_WORKER,
    PUBLIC_API_BASE_URL,
    SUPABASE_FUNCTIONS_URL,
    ADMIN_TELEGRAM_IDS,
    RATE_LIMIT_COMPLAINT,
    RATE_LIMIT_ADMIN,
    RATE_LIMIT_GENERAL,
)

# Константы приложения
ADMIN_EMAIL = "nvartovsk@n-vartovsk.ru"
ADMIN_NAME = "Администрация г. Нижневартовска"
ADMIN_PHONE = "8 (3466) 24-15-01"
COMPLAINT_STARS = 50
DIGEST_STARS = 30  # платный раздел: разовая сводка за день
DIGEST_SUBSCRIBE_STARS = 100  # подписка на ежедневные сводки на месяц
UVR5_MINIAPP_URL = os.getenv("UVR5_MINIAPP_URL", "").strip()

EMOJI = {
    "ЖКХ": "🏘️", "Дороги": "🛣️", "Благоустройство": "🌳", "Транспорт": "🚌",
    "Экология": "♻️", "Животные": "🐶", "Торговля": "🛒", "Безопасность": "🚨",
    "Снег/Наледь": "❄️", "Освещение": "💡", "Медицина": "🏥", "Образование": "🏫",
    "Связь": "📶", "Строительство": "🚧", "Парковки": "🅿️", "Социальная сфера": "👥",
    "Трудовое право": "📄", "Прочее": "❔", "Газоснабжение": "🔥",
    "Водоснабжение и канализация": "💧", "Отопление": "🌡️", "Бытовой мусор": "🗑️",
    "Лифты и подъезды": "🏢", "Парки и скверы": "🌲", "Спортивные площадки": "⚽",
    "Детские площадки": "🎠",
}
CATEGORIES = list(EMOJI.keys())
STATUS_ICON = {"open": "🔴", "pending": "🟡", "resolved": "✅"}
MENU_BUTTONS = {"📝 Новая жалоба", "🗺️ Карта", "📊 Инфографика", "👤 Профиль"}

LEGAL_PROMPT = (
    "Ты — юрист по жилищному и муниципальному праву РФ, специализация — Нижневартовск (ХМАО-Югра).\n"
    "Проанализируй жалобу и составь ОФИЦИАЛЬНОЕ ПИСЬМО-ОБРАЩЕНИЕ.\n\n"
    "ЖАЛОБА:\nКатегория: {category}\nАдрес: {address}\nУК: {uk_name}\nОписание: {description}\n\n"
    "ЗАДАЧА:\n"
    "1. Определи нарушенные нормативные акты (ЖК РФ, ПП РФ №491, ПП РФ №354, "
    "местные НПА г. Нижневартовска, НПА ХМАО-Югры)\n"
    "2. Укажи конкретные статьи и пункты\n"
    "3. Определи ответственного: УК, администрация, ресурсоснабжающая организация\n"
    "4. Составь текст официального письма-обращения от имени жителя\n"
    "5. Укажи сроки рассмотрения по закону\n"
    "6. Предложи порядок действий при отказе\n\n"
    "ФОРМАТ ОТВЕТА:\n"
    "Сначала краткий юридический анализ (3-5 пунктов),\n"
    "затем ПОЛНЫЙ ТЕКСТ ПИСЬМА (готовый к отправке).\n"
    "Отвечай на русском языке."
)

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()
bot_guard = RealtimeGuard()
user_sessions: dict = {}
_webapp_base_cache: dict = {"url": None, "mode": None, "checked_at": 0.0}

# ═══ HELPERS ═══
def _get_webapp_url() -> str:
    # Cache successful endpoint selection to avoid repeated network probes.
    now = time.time()
    if (
        _webapp_base_cache["url"]
        and _webapp_base_cache["mode"]
        and (now - _webapp_base_cache["checked_at"] < 600)
    ):
        return _webapp_base_cache["url"]

    candidates = []
    webapp_url = os.getenv("WEBAPP_URL", "").strip()
    supabase_webapp = os.getenv("SUPABASE_WEBAPP_URL", "").strip()
    supabase_url = os.getenv("SUPABASE_URL", "").strip()
    supabase_bucket = os.getenv("SUPABASE_WEBAPP_BUCKET", "webapp").strip() or "webapp"
    public_api = (PUBLIC_API_BASE_URL or "").strip()

    # 1) Explicit Supabase web frontend URL (highest priority).
    if supabase_webapp:
        candidates.append((supabase_webapp, "auto", "supabase_webapp_url"))
    # 2) Supabase Storage public bucket URL (static map.html/info.html).
    if supabase_url:
        storage_base = f"{supabase_url.rstrip('/')}/storage/v1/object/public/{supabase_bucket}"
        candidates.append((storage_base, "static", "supabase_storage"))
        # Common bucket fallbacks if custom bucket is missing.
        for b in ("web", "public"):
            if b != supabase_bucket:
                candidates.append((f"{supabase_url.rstrip('/')}/storage/v1/object/public/{b}", "static", f"supabase_storage_{b}"))

    # 3) Generic WEBAPP_URL override.
    if webapp_url:
        candidates.append((webapp_url, "auto", "webapp_url"))
    # 4) Public API static hosting fallback.
    if public_api:
        candidates.append((public_api, "pretty", "public_api"))

    # Tunnel URL as a local/dev fallback.
    tunnel = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel, "r", encoding="utf-8") as f:
            tunnel_url = f.read().strip()
            if tunnel_url:
                candidates.append((tunnel_url, "auto", "tunnel"))

    # Deduplicate preserving order
    unique_candidates = []
    seen = set()
    for base, mode, source in candidates:
        base = base.rstrip("/")
        key = (base, mode)
        if base and key not in seen:
            unique_candidates.append((base, mode, source))
            seen.add(key)

    # Probe endpoints: map/info must be reachable and should look like current UI.
    for base, mode, source in unique_candidates:
        selected_mode = _probe_webapp_mode(base, mode, require_fresh_marker=True)
        if selected_mode:
            _webapp_base_cache["url"] = base
            _webapp_base_cache["mode"] = selected_mode
            _webapp_base_cache["checked_at"] = now
            return base

    # Second pass: accept reachable legacy pages if fresh markers are absent.
    for base, mode, source in unique_candidates:
        selected_mode = _probe_webapp_mode(base, mode, require_fresh_marker=False)
        if selected_mode:
            _webapp_base_cache["url"] = base
            _webapp_base_cache["mode"] = selected_mode
            _webapp_base_cache["checked_at"] = now
            logger.warning(f"WebApp legacy fallback activated: {base} ({selected_mode})")
            return base

    # Last resort: keep previous behavior.
    fallback = webapp_url or public_api or (unique_candidates[0][0] if unique_candidates else "")
    fallback_mode = "pretty"
    _webapp_base_cache["url"] = fallback
    _webapp_base_cache["mode"] = fallback_mode
    _webapp_base_cache["checked_at"] = now
    return fallback

def _probe_webapp_mode(base_url: str, mode: str, require_fresh_marker: bool) -> Optional[str]:
    """Try candidate mode(s) and return selected mode if endpoint is valid."""
    if mode == "pretty":
        return "pretty" if _is_webapp_base_alive(base_url, "pretty", require_fresh_marker) else None
    if mode == "static":
        return "static" if _is_webapp_base_alive(base_url, "static", require_fresh_marker) else None
    # auto mode: try pretty first, then static
    if _is_webapp_base_alive(base_url, "pretty", require_fresh_marker):
        return "pretty"
    if _is_webapp_base_alive(base_url, "static", require_fresh_marker):
        return "static"
    return None

def _is_webapp_base_alive(base_url: str, mode: str = "pretty", require_fresh_marker: bool = True) -> bool:
    """Fast probe for WebApp endpoints without using system proxy.
    mode='pretty'  -> /map and /info
    mode='static'  -> /map.html and /info.html
    """
    opener = build_opener(ProxyHandler({}))
    if mode == "static":
        probe = (("/map.html", "splash-start-btn"), ("/info.html", "pulse-info-btn"))
    else:
        probe = (("/map", "splash-start-btn"), ("/info", "pulse-info-btn"))

    for path, marker in probe:
        url = f"{base_url.rstrip('/')}{path}"
        req = Request(url, headers={"User-Agent": "SoobshioBot/1.0"})
        try:
            with opener.open(req, timeout=6) as resp:
                status = getattr(resp, "status", 0)
                if status != 200:
                    return False
                content_type = (resp.headers.get("Content-Type") or "").lower()
                if "text/html" not in content_type and "text/plain" not in content_type:
                    return False
                body = resp.read(180000).decode("utf-8", errors="ignore")
                # Reject stale worker pages without latest navigation/splash markers.
                if require_fresh_marker and marker not in body:
                    logger.warning(f"WebApp probe stale content {url}: marker '{marker}' not found")
                    return False
        except HTTPError as e:
            # Any explicit HTTP error means this base is not suitable for WebApp.
            logger.warning(f"WebApp probe failed {url}: HTTP {e.code}")
            return False
        except URLError as e:
            logger.warning(f"WebApp probe failed {url}: {e.reason}")
            return False
        except Exception as e:
            logger.warning(f"WebApp probe failed {url}: {e}")
            return False
    return True

def _versioned_webapp_url(path: str) -> str:
    """Ссылка на WebApp с текущей версией и anti-cache."""
    base = _get_webapp_url().rstrip("/")
    webapp_version = get_webapp_version() or int(time.time())
    nocache = int(time.time())
    selected_mode = _webapp_base_cache.get("mode") or "pretty"
    clean_path = path.lstrip("/")

    # If Supabase Storage static hosting is selected, map pretty paths to html files.
    if selected_mode == "static":
        if clean_path == "map":
            clean_path = "map.html"
        elif clean_path.startswith("info?"):
            clean_path = "info.html?" + clean_path.split("?", 1)[1]
        elif clean_path == "info":
            clean_path = "info.html"

    sep = "&" if "?" in clean_path else "?"
    return f"{base}/{clean_path}{sep}v={webapp_version}&t={nocache}"


def _uvr5_webapp_url() -> str:
    """Возвращает URL mini app UVR5: env override или public route /uvr5."""
    if UVR5_MINIAPP_URL:
        return UVR5_MINIAPP_URL
    base = _get_webapp_url().rstrip("/")
    return f"{base}/uvr5"

def _db(): return SessionLocal()

def get_or_create_user(db: Session, tg_user: types.User) -> User:
    user = db.query(User).filter(User.telegram_id == tg_user.id).first()
    if not user:
        user = User(telegram_id=tg_user.id, username=tg_user.username,
                     first_name=tg_user.first_name, last_name=tg_user.last_name)
        db.add(user); db.commit(); db.refresh(user)
    return user

def _user_complaint_count(db: Session, user_id: int) -> int:
    return db.query(Report).filter(Report.user_id == user_id).count()

def _emoji(cat: str) -> str: return EMOJI.get(cat, "❔")
def _sv_url(lat, lon): return f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}"
def _map_url(lat, lon): return f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"

def _geo_buttons(lat, lon):
    return [InlineKeyboardButton(text="👁 Street View", url=_sv_url(lat, lon)),
            InlineKeyboardButton(text="📌 Карта", url=_map_url(lat, lon))]

def _confirm_buttons(lat=None, lon=None):
    rows = []
    if lat and lon: rows.append(_geo_buttons(lat, lon))
    rows.append([InlineKeyboardButton(text="✅ Подтвердить", callback_data="confirm")])
    rows.append([InlineKeyboardButton(text="🔒 Анонимно", callback_data="confirm_anon")])
    rows.append([InlineKeyboardButton(text="🏷️ Изменить категорию", callback_data="change_cat")])
    rows.append([InlineKeyboardButton(text="❌ Отменить", callback_data="cancel")])
    return rows

def _uk_text(uk_info):
    if uk_info:
        t = f"\n🏢 *УК: {uk_info['name']}*\n"
        if uk_info.get("email"): t += f"📧 {uk_info['email']}\n"
        if uk_info.get("phone"): t += f"📞 {uk_info['phone']}\n"
        if uk_info.get("director"): t += f"👤 {uk_info['director']}\n"
        return t
    return f"\n🏛️ *{ADMIN_NAME}*\n📧 {ADMIN_EMAIL}\n📞 {ADMIN_PHONE}\n"

async def _find_uk(lat, lon, address):
    if lat and lon: return await find_uk_by_coords(lat, lon)
    if address: return find_uk_by_address(address)
    return None

def main_kb():
    """Главное меню бота - только Профиль и Вход"""
    return ReplyKeyboardMarkup(keyboard=[
        [KeyboardButton(text="👤 Профиль")],
        [KeyboardButton(text="🚪 Вход")],
    ], resize_keyboard=True)

def categories_kb():
    buttons, row = [], []
    for cat in CATEGORIES:
        row.append(InlineKeyboardButton(text=f"{_emoji(cat)} {cat}", callback_data=f"cat:{cat}"))
        if len(row) == 2: buttons.append(row); row = []
    if row: buttons.append(row)
    return InlineKeyboardMarkup(inline_keyboard=buttons)

async def _notify_subscribers(report):
    db = _db()
    try:
        subs = db.query(User).filter(User.notify_new == 1).all()
        text = (f"🔔 *Новая проблема*\n\n{_emoji(report.category)} *{report.category}*\n"
                f"📍 {report.address or '—'}\n📝 {(report.title or '')[:100]}")
        sent = 0
        for u in subs:
            if not u.telegram_id or u.id == report.user_id: continue
            try: await bot.send_message(u.telegram_id, text, parse_mode="Markdown"); sent += 1
            except: pass
            if sent >= 50: break
    except Exception as e: logger.error(f"Notify: {e}")
    finally: db.close()

# ═══ COMMANDS ═══
@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    """Команда /start - приветствие с минимальным меню (Профиль и Вход)"""
    # Принудительно обновляем меню при каждом /start для гарантии актуальности
    await message.answer(
        "🏙️ *Пульс города — Нижневартовск*\n\n"
        "Добро пожаловать! Выберите действие:",
        parse_mode="Markdown",
        reply_markup=main_kb())
    
    # Логируем для отладки
    logger.info(f"Команда /start от пользователя {message.from_user.id}")

@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "❓ *Справка*\n\n"
        "📝 /new — Новая жалоба\n"
        "🗺️ /map — Карта + рейтинг УК\n"
        "📊 /info — Инфографика города\n"
        "👤 /profile — Профиль\n"
""
        "*Как подать жалобу:*\n"
        "1. Отправьте текст или фото\n"
        "2. AI определит категорию, адрес и УК\n"
        "3. Выберите: анонимное письмо или юр. анализ + письмо\n\n"
        "Первая жалоба бесплатно, далее 50 ⭐",
        parse_mode="Markdown", reply_markup=main_kb())

@dp.message(Command("map"))
async def cmd_map(message: types.Message):
    """Команда /map - открывает карту (требует авторизации)"""
    uid = message.from_user.id
    
    # Проверка авторизации
    if not user_sessions.get(uid, {}).get("authorized"):
        await message.answer(
            "🔒 Для доступа к карте необходимо войти.\n"
            "Нажмите кнопку '🚪 Вход' в меню.",
            reply_markup=main_kb()
        )
        return
    
    map_url = _versioned_webapp_url("map")
    info_url = _versioned_webapp_url("info")
    buttons = [
        [InlineKeyboardButton(text="🗺️ Открыть карту", web_app=WebAppInfo(url=map_url))],
        [InlineKeyboardButton(text="📊 Перейти к инфографике", web_app=WebAppInfo(url=info_url))],
        [InlineKeyboardButton(text="🌍 OpenStreetMap", url="https://www.openstreetmap.org/#map=13/60.9344/76.5531")],
    ]
    await message.answer(
        "🗺️ *Карта проблем Нижневартовска*\n\n"
        "Интерактивная карта городских проблем:\n"
        "• Жалобы с real-time обновлениями\n"
        "• Рейтинг 42 управляющих компаний\n"
        "• Фильтрация по категориям, статусам и датам\n"
        "• Северное сияние в фоне\n\n"
        "Используйте фильтры для поиска нужных проблем.",
        parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))

@dp.message(Command("info"))
async def cmd_info(message: types.Message):
    """Команда /info - открывает инфографику (требует авторизации)"""
    uid = message.from_user.id
    
    # Проверка авторизации
    if not user_sessions.get(uid, {}).get("authorized"):
        await message.answer(
            "🔒 Для доступа к инфографике необходимо войти.\n"
            "Нажмите кнопку '🚪 Вход' в меню.",
            reply_markup=main_kb()
        )
        return
    
    info_url = _versioned_webapp_url("info")
    map_url = _versioned_webapp_url("map")
    buttons = [
        [InlineKeyboardButton(text="📊 Открыть инфографику", web_app=WebAppInfo(url=info_url))],
        [InlineKeyboardButton(text="🗺️ Перейти к карте", web_app=WebAppInfo(url=map_url))],
    ]
    await message.answer(
        "📊 *Инфографика Нижневартовска*\n\n"
        "72 датасета открытых данных:\n"
        "• Бюджет и финансы\n"
        "• ЖКХ и коммунальные услуги\n"
        "• Транспорт и дороги\n"
        "• Образование и здравоохранение\n"
        "• Благоустройство и экология\n\n"
        "Северное сияние в фоне ✨",
        parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))

@dp.message(Command("profile"))
async def cmd_profile(message: types.Message):
    db = _db()
    try:
        user = get_or_create_user(db, message.from_user)
        my_reports = db.query(Report).filter(Report.user_id == user.id).count()
        my_resolved = db.query(Report).filter(Report.user_id == user.id, Report.status == "resolved").count()
        balance = user.balance or 0
        reg_date = user.created_at.strftime("%d.%m.%Y") if user.created_at else "—"
        notify_on = getattr(user, "notify_new", 0) == 1
        free = "✅ Да" if my_reports == 0 else "❌ Использована"
        text = (f"👤 *Профиль*\n\n"
                f"👋 {message.from_user.first_name or ''}\n"
                f"📅 Регистрация: {reg_date}\n\n"
                f"📝 Жалоб: {my_reports} · ✅ Решено: {my_resolved}\n"
                f"💰 Баланс: {balance} ⭐\n"
                f"🎁 Бесплатная жалоба: {free}\n"
                f"🔔 Уведомления: {'✅' if notify_on else '❌'}")
        notify_btn = "🔕 Выкл" if notify_on else "🔔 Вкл уведомления"
        buttons = [
            [InlineKeyboardButton(text="📋 Мои жалобы", callback_data="my_complaints")],
            [InlineKeyboardButton(text="💳 Пополнить", callback_data="topup_menu")],
            [InlineKeyboardButton(text="🔒 Платный раздел", callback_data="paid_section")],
            [InlineKeyboardButton(text=notify_btn, callback_data="toggle_notify")],
            [InlineKeyboardButton(text="ℹ️ О проекте", callback_data="about_project")],
        ]
        await message.answer(text, parse_mode="Markdown",
                             reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally: db.close()

@dp.callback_query(F.data == "new_complaint")
async def cb_new_complaint(callback: types.CallbackQuery):
    """Обработчик создания новой жалобы через кнопку"""
    await callback.answer()
    await cmd_new(callback.message)

@dp.message(Command("new"))
async def cmd_new(message: types.Message):
    """Создание новой жалобы - требует авторизации"""
    uid = message.from_user.id
    
    # Проверка авторизации
    if not user_sessions.get(uid, {}).get("authorized"):
        await message.answer(
            "🔒 Для создания жалобы необходимо войти.\n"
            "Нажмите кнопку '🚪 Вход' в меню.",
            reply_markup=main_kb()
        )
        return
    
    # Rate limiting
    if not check_rate_limit(uid, "complaint"):
        await message.answer(
            "⏳ Слишком много запросов. Пожалуйста, подождите немного перед созданием новой жалобы.",
            reply_markup=main_kb()
        )
        return
    user_sessions[message.from_user.id] = {"state": "waiting_complaint"}
    await message.answer("📝 *Новая жалоба*\n\nОтправьте текст или фото.\nAI определит категорию, адрес и УК.\n/cancel — отмена",
        parse_mode="Markdown")

@dp.message(Command("cancel"))
async def cmd_cancel(message: types.Message):
    user_sessions.pop(message.from_user.id, None)
    await message.answer("❌ Отменено.", reply_markup=main_kb())

@dp.message(Command("admin"))
async def cmd_admin(message: types.Message):
    """Админ-панель — доступ только для администраторов"""
    uid = message.from_user.id
    
    if not is_admin(uid):
        await message.answer("❌ Доступ запрещён. Эта команда доступна только администраторам.")
        return
    
    # Rate limiting для админов (более мягкий)
    if not check_rate_limit(uid, "admin"):
        await message.answer("⏳ Слишком много запросов. Пожалуйста, подождите немного.")
        return
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📊 Статистика", callback_data="admin:stats")],
        [InlineKeyboardButton(text="📋 Последние жалобы", callback_data="admin:reports")],
        [InlineKeyboardButton(text="⚙️ Управление ботом", callback_data="admin:control")],
        [InlineKeyboardButton(text="📤 Экспорт CSV", callback_data="admin:export")],
        [InlineKeyboardButton(text="📄 Экспорт PDF", callback_data="admin:export_pdf")],
        [InlineKeyboardButton(text="🗑️ Очистка данных", callback_data="admin:cleanup")],
    ])
    
    await message.answer(
        "🔐 *Админ-панель*\n\n"
        "Выберите действие:",
        reply_markup=keyboard,
        parse_mode="Markdown"
    )

@dp.callback_query(F.data == "admin:stats")
async def cb_admin_stats(callback: types.CallbackQuery):
    """Показать статистику"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    db = _db()
    try:
        stats = get_stats(db)
        realtime_stats = await get_realtime_stats()
        msg = format_stats_message(stats, realtime_stats)
        
        keyboard = InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(text="🔄 Обновить", callback_data="admin:stats")],
            [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")],
        ])
        
        await callback.message.edit_text(msg, reply_markup=keyboard, parse_mode="Markdown")
    finally:
        db.close()
    
    await callback.answer()

@dp.callback_query(F.data == "admin:reports")
async def cb_admin_reports(callback: types.CallbackQuery):
    """Показать последние жалобы"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    db = _db()
    try:
        reports = get_recent_reports(db, limit=10)
        
        if not reports:
            await callback.message.edit_text(
                "📋 *Последние жалобы*\n\nЖалоб пока нет.",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")]
                ]),
                parse_mode="Markdown"
            )
            await callback.answer()
            return
        
        # Показываем первую жалобу с навигацией
        report = reports[0]
        msg = format_report_message(report)
        
        keyboard = InlineKeyboardMarkup(inline_keyboard=[
            [
                InlineKeyboardButton(text="◀️", callback_data=f"admin:report:0"),
                InlineKeyboardButton(text=f"1/{len(reports)}", callback_data="admin:report:info"),
                InlineKeyboardButton(text="▶️", callback_data=f"admin:report:1"),
            ],
            [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")],
        ])
        
        await callback.message.edit_text(msg, reply_markup=keyboard, parse_mode="Markdown")
        callback.message.from_user = callback.from_user  # Сохраняем для навигации
        callback.message._reports_list = reports  # Временное хранилище
    finally:
        db.close()
    
    await callback.answer()

@dp.callback_query(F.data.startswith("admin:report:"))
async def cb_admin_report_nav(callback: types.CallbackQuery):
    """Навигация по жалобам"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    try:
        idx = int(callback.data.split(":")[-1])
    except:
        await callback.answer("❌ Ошибка", show_alert=True)
        return
    
    db = _db()
    try:
        reports = get_recent_reports(db, limit=10)
        
        if idx < 0 or idx >= len(reports):
            await callback.answer("❌ Нет такой жалобы", show_alert=True)
            return
        
        report = reports[idx]
        msg = format_report_message(report)
        
        keyboard = InlineKeyboardMarkup(inline_keyboard=[
            [
                InlineKeyboardButton(text="◀️", callback_data=f"admin:report:{max(0, idx-1)}"),
                InlineKeyboardButton(text=f"{idx+1}/{len(reports)}", callback_data="admin:report:info"),
                InlineKeyboardButton(text="▶️", callback_data=f"admin:report:{min(len(reports)-1, idx+1)}"),
            ],
            [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")],
        ])
        
        await callback.message.edit_text(msg, reply_markup=keyboard, parse_mode="Markdown")
    finally:
        db.close()
    
    await callback.answer()

def _format_last_update_report(reports: list) -> str:
    """Форматирует блок последних отчётов об обновлениях."""
    if not reports:
        return ""
    r = reports[0]
    ok = "✅" if r.get("success") else "❌"
    ts = r.get("timestamp", "")[:19].replace("T", " ")
    ver = r.get("webapp_version", "—")
    det = r.get("details", "")
    err = r.get("error", "")
    line = f"{ok} {ts} | v{ver}"
    if det:
        line += f" | {det}"
    if err:
        line += f" | {err}"
    return f"\n📋 *Последнее обновление:*\n{line}\n"


@dp.callback_query(F.data == "admin:control")
async def cb_admin_control(callback: types.CallbackQuery, skip_answer: bool = False):
    """Управление ботом. skip_answer=True если callback.answer() уже вызван."""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return

    status = get_bot_status()
    monitoring_status = "🟢 Включен" if status["monitoring_enabled"] else "🔴 Выключен"
    webapp_v = get_webapp_version()
    last_reports = get_last_bot_update_reports(limit=1)
    update_block = _format_last_update_report(last_reports)

    ai_status = get_ai_provider_status()
    msg = (
        "⚙️ *Управление ботом*\n\n"
        f"📊 Всего жалоб: *{status['total_reports']}*\n"
        f"👥 Пользователей: *{status['total_users']}*\n"
        f"🔴 Открыто: *{status['open_reports']}*\n"
        f"✅ Решено: *{status['resolved_reports']}*\n\n"
        f"📡 Мониторинг: {monitoring_status}\n"
""
        f"💾 Кэш AI: *{status.get('ai_cache_valid', 0)}* записей\n"
        f"🤖 AI провайдер: *{ai_status.get('active', 'zai')}*\n"
        f"🗺️ Версия карты/инфографики: *{webapp_v}*"
        f"{update_block}"
    )

    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔄 Обновить бота", callback_data="admin:update_bot")],
        [InlineKeyboardButton(text="📋 История обновлений", callback_data="admin:update_reports")],
        [
            InlineKeyboardButton(
                text="🟢 Включить" if not status["monitoring_enabled"] else "🔴 Выключить",
                callback_data="admin:toggle_monitoring"
            )
        ],
        [
            InlineKeyboardButton(text="🔄 Обработать очередь Firebase", callback_data="admin:process_queue"),
            InlineKeyboardButton(text="🧹 Очистить кэш AI", callback_data="admin:clear_cache"),
        ],
        [InlineKeyboardButton(text="🤖 AI-провайдер", callback_data="admin:ai_provider")],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")],
    ])

    await callback.message.edit_text(msg, reply_markup=keyboard, parse_mode="Markdown")
    if not skip_answer:
        await callback.answer()

@dp.callback_query(F.data == "admin:update_bot")
async def cb_admin_update_bot(callback: types.CallbackQuery):
    """Обновление бота: версия карты/инфографики + меню команд.
    Не вызываем callback.answer() здесь — cb_admin_control вызовет его один раз.
    Двойной вызов вызывает ошибку Telegram API «query_id is invalid».
    """
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return

    try:
        new_v = bump_webapp_version()
        await setup_menu()
        # Проверка: команды действительно обновились
        cmds = await bot.get_my_commands()
        expected = {"start", "help", "new", "map", "info", "profile"}
        have = {c.command for c in cmds}
        missing = expected - have
        details = f"Команды: {len(have)}/6. Отсутствуют: {missing or 'нет'}"
        save_bot_update_report(success=True, webapp_version=new_v, details=details)
        await callback.message.answer(
            f"✅ *Бот обновлён*\n\n"
            f"🗺️ Версия карты/инфографики: *{new_v}*\n"
            f"📋 Меню команд обновлено\n"
            f"📋 {details}\n\n"
            "Все новые ссылки на карту и инфографику будут с актуальной версией.",
            parse_mode="Markdown"
        )
    except Exception as e:
        logger.error(f"Update bot error: {e}")
        save_bot_update_report(
            success=False, webapp_version=get_webapp_version(),
            details="", error=str(e)
        )
        await callback.message.answer(f"❌ Ошибка обновления: {e}")
    await cb_admin_control(callback, skip_answer=False)

@dp.callback_query(F.data == "admin:update_reports")
async def cb_admin_update_reports(callback: types.CallbackQuery):
    """Показать историю обновлений бота"""
    if not is_admin(callback.from_user.id):
        await callback.answer("Доступ запрещён", show_alert=True)
        return

    reports = get_last_bot_update_reports(limit=10)
    if not reports:
        text = "История обновлений пуста."
    else:
        lines = ["*История обновлений бота* (последние 10):\n"]
        for i, r in enumerate(reports, 1):
            ok = "OK" if r.get("success") else "ERR"
            ts = (r.get("timestamp") or "")[:19].replace("T", " ")
            ver = r.get("webapp_version", "-")
            det = r.get("details", "")
            err = r.get("error", "")
            line = f"{i}. [{ok}] {ts} | v{ver}"
            if det:
                line += f" | {det}"
            if err:
                line += f" | {err[:80]}"
            lines.append(line)
        text = "\n".join(lines)

    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Назад", callback_data="admin:control")],
    ])
    await callback.message.edit_text(text, reply_markup=keyboard, parse_mode="Markdown")
    await callback.answer()


@dp.callback_query(F.data == "admin:toggle_monitoring")
async def cb_admin_toggle_monitoring(callback: types.CallbackQuery):
    """Переключить мониторинг"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    new_state = toggle_monitoring()
    status_text = "🟢 включен" if new_state else "🔴 выключен"
    
    await callback.answer(f"Мониторинг {status_text}", show_alert=True)
    await cb_admin_control(callback, skip_answer=True)

@dp.callback_query(F.data == "admin:process_queue")
async def cb_admin_process_queue(callback: types.CallbackQuery):
    """Обработать очередь Firebase"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    from services.firebase_queue import process_queue, get_queue_stats

    queue_before = get_queue_stats()["size"]
    try:
        await process_queue()
        queue_after = get_queue_stats()["size"]
        processed = queue_before - queue_after
        await callback.answer(f"Обработано: {processed} из {queue_before}", show_alert=True)
    except Exception as e:
        logger.error(f"Queue processing error: {e}")
        await callback.answer(f"Ошибка: {e}", show_alert=True)

    await cb_admin_control(callback, skip_answer=True)

@dp.callback_query(F.data == "admin:clear_cache")
async def cb_admin_clear_cache(callback: types.CallbackQuery):
    """Очистить кэш AI"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    from services.ai_cache import clear_cache, get_cache_stats
    
    cache_before = get_cache_stats()["total"]
    clear_cache()
    cache_after = get_cache_stats()["total"]
    
    await callback.answer(f"Кэш очищен: {cache_before} -> {cache_after}", show_alert=True)
    await cb_admin_control(callback, skip_answer=True)  # Обновляем панель


@dp.callback_query(F.data == "admin:ai_provider")
async def cb_admin_ai_provider(callback: types.CallbackQuery):
    """Меню выбора AI-провайдера текста."""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return

    status = get_ai_provider_status()
    active = status.get("active", "zai")
    zai_ok = "✅" if status.get("zai_configured") else "❌"
    or_ok = "✅" if status.get("openrouter_configured") else "❌"

    text = (
        "🤖 *AI-провайдер анализа текста*\n\n"
        f"Текущий: *{active}*\n\n"
        f"{zai_ok} zai ({status.get('zai_model')})\n"
        f"{or_ok} openrouter ({status.get('openrouter_model')})\n"
        "ℹ️ keyword — rule-based fallback"
    )
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="✅ Z.AI", callback_data="admin:ai:set:zai")],
        [InlineKeyboardButton(text="✅ OpenRouter", callback_data="admin:ai:set:openrouter")],
        [InlineKeyboardButton(text="✅ Keyword fallback", callback_data="admin:ai:set:keyword")],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:control")],
    ])
    await callback.message.edit_text(text, parse_mode="Markdown", reply_markup=keyboard)
    await callback.answer()


@dp.callback_query(F.data.startswith("admin:ai:set:"))
async def cb_admin_ai_set(callback: types.CallbackQuery):
    """Смена AI-провайдера в runtime."""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return

    provider = callback.data.split(":")[-1]
    ok = set_ai_provider(provider)
    if not ok:
        await callback.answer("❌ Неверный провайдер", show_alert=True)
        return
    await callback.answer(f"✅ AI провайдер: {provider}", show_alert=True)
    await cb_admin_ai_provider(callback)

@dp.callback_query(F.data == "admin:export")
async def cb_admin_export(callback: types.CallbackQuery):
    """Экспорт данных в CSV"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    db = _db()
    try:
        csv_data = export_stats_csv(db)
        
        # Отправляем как файл
        from io import BytesIO
        bio = BytesIO()
        bio.write(csv_data.encode('utf-8-sig'))  # UTF-8 BOM для Excel
        bio.seek(0)
        
        await callback.message.answer_document(
            BufferedInputFile(bio.read(), filename=f"stats_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"),
            caption="📤 Экспорт статистики (CSV)"
        )
        
        await callback.answer("✅ Данные экспортированы")
    except Exception as e:
        logger.error(f"Export error: {e}")
        await callback.answer(f"❌ Ошибка: {e}", show_alert=True)
    finally:
        db.close()


@dp.callback_query(F.data == "admin:export_pdf")
async def cb_admin_export_pdf(callback: types.CallbackQuery):
    """Экспорт краткой сводки по жалобам в PDF"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    db = _db()
    try:
        # Экспортируем последние 50 жалоб за последние 30 дней
        pdf_data = export_complaints_pdf(db, days=30, limit=50)
        
        await callback.message.answer_document(
            BufferedInputFile(pdf_data, filename=f"complaints_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"),
            caption="📄 Краткая сводка по жалобам (PDF)\n\nВключает:\n• Общую статистику\n• Топ категорий\n• Список последних жалоб"
        )
        
        await callback.answer("✅ PDF сводка создана")
    except ImportError:
        await callback.answer("❌ Установите reportlab: pip install reportlab", show_alert=True)
    except Exception as e:
        logger.error(f"PDF export error: {e}")
        await callback.answer(f"❌ Ошибка: {e}", show_alert=True)
    finally:
        db.close()

@dp.callback_query(F.data == "admin:cleanup")
async def cb_admin_cleanup(callback: types.CallbackQuery):
    """Очистка старых данных"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="🗑️ Удалить старше 90 дней", callback_data="admin:cleanup:90"),
            InlineKeyboardButton(text="🗑️ Удалить старше 180 дней", callback_data="admin:cleanup:180"),
        ],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="admin:back")],
    ])
    
    await callback.message.edit_text(
        "🗑️ *Очистка данных*\n\n"
        "⚠️ Будет удалены только решённые жалобы старше указанного периода.\n"
        "Выберите период:",
        reply_markup=keyboard,
        parse_mode="Markdown"
    )
    await callback.answer()

@dp.callback_query(F.data.startswith("admin:cleanup:"))
async def cb_admin_cleanup_execute(callback: types.CallbackQuery):
    """Выполнить очистку"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    try:
        days = int(callback.data.split(":")[-1])
    except:
        await callback.answer("❌ Ошибка", show_alert=True)
        return
    
    db = _db()
    try:
        deleted = clear_old_reports(db, days=days)
        await callback.answer(f"Удалено жалоб: {deleted}", show_alert=True)
        await cb_admin_control(callback, skip_answer=True)
    except Exception as e:
        logger.error(f"Cleanup error: {e}")
        await callback.answer(f"❌ Ошибка: {e}", show_alert=True)
    finally:
        db.close()

@dp.callback_query(F.data == "admin:back")
async def cb_admin_back(callback: types.CallbackQuery):
    """Вернуться в главное меню админ-панели"""
    if not is_admin(callback.from_user.id):
        await callback.answer("❌ Доступ запрещён", show_alert=True)
        return
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📊 Статистика", callback_data="admin:stats")],
        [InlineKeyboardButton(text="📋 Последние жалобы", callback_data="admin:reports")],
        [InlineKeyboardButton(text="⚙️ Управление ботом", callback_data="admin:control")],
        [InlineKeyboardButton(text="📤 Экспорт CSV", callback_data="admin:export")],
        [InlineKeyboardButton(text="📄 Экспорт PDF", callback_data="admin:export_pdf")],
        [InlineKeyboardButton(text="🗑️ Очистка данных", callback_data="admin:cleanup")],
    ])
    
    await callback.message.edit_text(
        "🔐 *Админ-панель*\n\n"
        "Выберите действие:",
        reply_markup=keyboard,
        parse_mode="Markdown"
    )
    await callback.answer()

# ═══════════════════════════════════════════════════════════════════════════════
# VOCAL REMOVER — Скрытый раздел для админов (MDX-Net Voc_FT / Inst3)
# Команда: /vocalremover
# ═══════════════════════════════════════════════════════════════════════════════

# Временные сессии для vocal remover
vocal_sessions: dict = {}

@dp.message(Command("vocalremover"))
async def cmd_vocalremover(message: types.Message):
    """Скрытая команда для удаления вокала из аудио (только для админов)"""
    uid = message.from_user.id
    
    if not is_admin(uid):
        # Скрытая команда — просто игнорируем для не-админов
        return
    
    # Проверяем установку
    is_installed, status_msg = await check_installation()
    
    vr_buttons = [
        [InlineKeyboardButton(text="📤 Загрузить аудио", callback_data="vr:upload")],
        [InlineKeyboardButton(text="🎵 Модели", callback_data="vr:models")],
        [InlineKeyboardButton(text="📊 Статистика", callback_data="vr:stats")],
        [InlineKeyboardButton(text="🗑️ Очистка кэша", callback_data="vr:cleanup")],
    ]
    vr_buttons.append([InlineKeyboardButton(text="🌐 UVR5 Mini App", web_app=WebAppInfo(url=_uvr5_webapp_url()))])
    vr_buttons.append([InlineKeyboardButton(text="❌ Закрыть", callback_data="vr:close")])
    keyboard = InlineKeyboardMarkup(inline_keyboard=vr_buttons)
    
    status_icon = "✅" if is_installed else "⚠️"
    
    await message.answer(
        f"🎤 *VocalRemover*\n"
        f"_MDX-Net Voc\\_FT / Inst3_\n\n"
        f"{status_icon} Статус:\n{status_msg}\n\n"
        f"Отправьте аудио/голосовое сообщение или нажмите «Загрузить аудио».",
        parse_mode="Markdown",
        reply_markup=keyboard
    )

@dp.callback_query(F.data == "vr:upload")
async def cb_vr_upload(callback: types.CallbackQuery):
    """Начать загрузку аудио"""
    if not is_admin(callback.from_user.id):
        return
    
    vocal_sessions[callback.from_user.id] = {"state": "waiting_audio", "model": DEFAULT_MODEL}
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔙 Назад", callback_data="vr:back")],
    ])
    
    await callback.message.edit_text(
        "📤 *Загрузка аудио*\n\n"
        "Отправьте аудиофайл, голосовое сообщение или видео.\n\n"
        "Поддерживаемые форматы:\n"
        "• MP3, WAV, FLAC, OGG, M4A\n"
        "• Видео (извлечётся аудиодорожка)\n\n"
        f"Текущая модель: `{DEFAULT_MODEL}`",
        parse_mode="Markdown",
        reply_markup=keyboard
    )
    await callback.answer()

@dp.callback_query(F.data == "vr:models")
async def cb_vr_models(callback: types.CallbackQuery):
    """Показать доступные модели"""
    if not is_admin(callback.from_user.id):
        return
    
    buttons = []
    for key, info in MODELS.items():
        buttons.append([InlineKeyboardButton(
            text=f"{'✓ ' if key == DEFAULT_MODEL else ''}{info['name']}",
            callback_data=f"vr:model:{key}"
        )])
    buttons.append([InlineKeyboardButton(text="🔙 Назад", callback_data="vr:back")])
    
    await callback.message.edit_text(
        f"{get_models_list()}\n\n"
        f"Выберите модель для обработки:",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
    )
    await callback.answer()

@dp.callback_query(F.data.startswith("vr:model:"))
async def cb_vr_select_model(callback: types.CallbackQuery):
    """Выбрать модель"""
    if not is_admin(callback.from_user.id):
        return
    
    model_key = callback.data.split(":")[2]
    if model_key not in MODELS:
        await callback.answer("❌ Неизвестная модель", show_alert=True)
        return
    
    uid = callback.from_user.id
    if uid not in vocal_sessions:
        vocal_sessions[uid] = {}
    vocal_sessions[uid]["model"] = model_key
    vocal_sessions[uid]["state"] = "waiting_audio"
    
    model_info = MODELS[model_key]
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📤 Загрузить аудио", callback_data="vr:upload")],
        [InlineKeyboardButton(text="🔙 Назад", callback_data="vr:back")],
    ])
    
    await callback.message.edit_text(
        f"✅ Модель выбрана: *{model_info['name']}*\n"
        f"_{model_info['description']}_\n\n"
        f"Теперь отправьте аудиофайл для обработки.",
        parse_mode="Markdown",
        reply_markup=keyboard
    )
    await callback.answer(f"Модель: {model_info['name']}")

@dp.callback_query(F.data == "vr:stats")
async def cb_vr_stats(callback: types.CallbackQuery):
    """Статистика использования"""
    if not is_admin(callback.from_user.id):
        return
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔙 Назад", callback_data="vr:back")],
    ])
    
    await callback.message.edit_text(
        get_usage_stats(),
        parse_mode="Markdown",
        reply_markup=keyboard
    )
    await callback.answer()

@dp.callback_query(F.data == "vr:cleanup")
async def cb_vr_cleanup(callback: types.CallbackQuery):
    """Очистка старых файлов"""
    if not is_admin(callback.from_user.id):
        return
    
    deleted = await cleanup_old_files(max_age_hours=24)
    
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔙 Назад", callback_data="vr:back")],
    ])
    
    await callback.message.edit_text(
        f"🗑️ *Очистка кэша*\n\n"
        f"Удалено папок: {deleted}\n"
        f"(файлы старше 24 часов)",
        parse_mode="Markdown",
        reply_markup=keyboard
    )
    await callback.answer(f"Удалено: {deleted}")

@dp.callback_query(F.data == "vr:back")
async def cb_vr_back(callback: types.CallbackQuery):
    """Назад в меню VocalRemover"""
    if not is_admin(callback.from_user.id):
        return
    
    is_installed, status_msg = await check_installation()
    status_icon = "✅" if is_installed else "⚠️"
    
    vr_buttons = [
        [InlineKeyboardButton(text="📤 Загрузить аудио", callback_data="vr:upload")],
        [InlineKeyboardButton(text="🎵 Модели", callback_data="vr:models")],
        [InlineKeyboardButton(text="📊 Статистика", callback_data="vr:stats")],
        [InlineKeyboardButton(text="🗑️ Очистка кэша", callback_data="vr:cleanup")],
    ]
    vr_buttons.append([InlineKeyboardButton(text="🌐 UVR5 Mini App", web_app=WebAppInfo(url=_uvr5_webapp_url()))])
    vr_buttons.append([InlineKeyboardButton(text="❌ Закрыть", callback_data="vr:close")])
    keyboard = InlineKeyboardMarkup(inline_keyboard=vr_buttons)
    
    await callback.message.edit_text(
        f"🎤 *VocalRemover*\n"
        f"_MDX-Net Voc\\_FT / Inst3_\n\n"
        f"{status_icon} Статус:\n{status_msg}\n\n"
        f"Отправьте аудио/голосовое сообщение или нажмите «Загрузить аудио».",
        parse_mode="Markdown",
        reply_markup=keyboard
    )
    await callback.answer()

@dp.callback_query(F.data == "vr:close")
async def cb_vr_close(callback: types.CallbackQuery):
    """Закрыть меню VocalRemover"""
    if not is_admin(callback.from_user.id):
        return
    
    vocal_sessions.pop(callback.from_user.id, None)
    await callback.message.delete()
    await callback.answer()

# Обработчик аудио для VocalRemover
@dp.message(F.audio | F.voice | F.video | F.video_note | F.document)
async def handle_audio_for_vr(message: types.Message):
    """Обработка аудио для VocalRemover (только для админов в режиме ожидания)"""
    uid = message.from_user.id
    
    # Проверяем, что это админ в режиме VocalRemover
    session = vocal_sessions.get(uid)
    if not session or session.get("state") != "waiting_audio":
        return  # Пропускаем, если не в режиме VocalRemover
    
    if not is_admin(uid):
        return
    
    if not AUDIO_SEPARATOR_AVAILABLE:
        await message.answer(
            "❌ audio-separator не установлен.\n"
            "Установите: `pip install audio-separator[cpu]`",
            parse_mode="Markdown"
        )
        return
    
    # Определяем тип файла
    file_obj = None
    file_name = "audio"
    
    if message.audio:
        file_obj = message.audio
        file_name = message.audio.file_name or f"audio_{message.audio.file_id[:8]}.mp3"
    elif message.voice:
        file_obj = message.voice
        file_name = f"voice_{message.voice.file_id[:8]}.ogg"
    elif message.video:
        file_obj = message.video
        file_name = message.video.file_name or f"video_{message.video.file_id[:8]}.mp4"
    elif message.video_note:
        file_obj = message.video_note
        file_name = f"videonote_{message.video_note.file_id[:8]}.mp4"
    elif message.document:
        # Проверяем MIME-тип
        mime = message.document.mime_type or ""
        if mime.startswith("audio/") or mime.startswith("video/") or \
           message.document.file_name.lower().endswith(('.mp3', '.wav', '.flac', '.ogg', '.m4a', '.mp4', '.mkv', '.webm')):
            file_obj = message.document
            file_name = message.document.file_name or f"file_{message.document.file_id[:8]}"
        else:
            return  # Не аудио/видео файл
    
    if not file_obj:
        return
    
    # Проверяем размер (макс 50 МБ)
    if file_obj.file_size and file_obj.file_size > 50 * 1024 * 1024:
        await message.answer("❌ Файл слишком большой. Максимум: 50 МБ")
        return
    
    model_key = session.get("model", DEFAULT_MODEL)
    model_info = MODELS.get(model_key, MODELS[DEFAULT_MODEL])
    
    status_msg = await message.answer(
        f"🔄 *Обработка...*\n\n"
        f"📁 Файл: `{file_name}`\n"
        f"🎵 Модель: {model_info['name']}\n\n"
        f"⏳ Это может занять несколько минут...",
        parse_mode="Markdown"
    )
    
    try:
        # Скачиваем файл
        file = await bot.get_file(file_obj.file_id)
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file_name).suffix) as tmp_input:
            await bot.download_file(file.file_path, tmp_input)
            input_path = tmp_input.name
        
        # Обрабатываем
        vocals_path, instrumental_path, info = await separate_audio(
            input_path=input_path,
            model_key=model_key,
            output_format="mp3",
            user_id=uid,
        )
        
        # Отправляем результаты
        result_text = (
            f"✅ *Готово!*\n\n"
            f"📁 Исходный файл: `{file_name}`\n"
            f"🎵 Модель: {model_info['name']}\n"
            f"⏱️ Время: {info.get('duration_sec', 0):.1f}с"
        )
        
        await status_msg.edit_text(result_text, parse_mode="Markdown")
        
        # Отправляем файлы
        if vocals_path and os.path.exists(vocals_path):
            with open(vocals_path, 'rb') as f:
                await message.answer_audio(
                    BufferedInputFile(f.read(), filename=f"vocals_{Path(file_name).stem}.mp3"),
                    caption="🎤 Вокал"
                )
        
        if instrumental_path and os.path.exists(instrumental_path):
            with open(instrumental_path, 'rb') as f:
                await message.answer_audio(
                    BufferedInputFile(f.read(), filename=f"instrumental_{Path(file_name).stem}.mp3"),
                    caption="🎸 Инструментал"
                )
        
        # Очистка
        os.unlink(input_path)
        if vocals_path and os.path.exists(vocals_path):
            os.unlink(vocals_path)
        if instrumental_path and os.path.exists(instrumental_path):
            os.unlink(instrumental_path)
        
        # Сбрасываем сессию
        vocal_sessions[uid]["state"] = None
        
    except VocalRemoverError as e:
        await status_msg.edit_text(f"❌ *Ошибка:* {e}", parse_mode="Markdown")
    except Exception as e:
        logger.error(f"VocalRemover error: {e}", exc_info=True)
        await status_msg.edit_text(f"❌ *Ошибка обработки:* {e}", parse_mode="Markdown")
    finally:
        # Очистка временного файла
        try:
            if 'input_path' in locals():
                os.unlink(input_path)
        except:
            pass

@dp.message(Command("sync"))
async def cmd_sync(message: types.Message):
    await message.answer("🔄 Синхронизация...")
    db = _db()
    try:
        reports = db.query(Report).order_by(Report.created_at.desc()).limit(100).all()
        if not reports: await message.answer("Нет жалоб.", reply_markup=main_kb()); return
        pushed, errors = 0, 0
        for r in reports:
            try:
                fb = {"category": r.category, "summary": r.title, "text": (r.description or "")[:2000],
                      "address": r.address, "lat": r.lat, "lng": r.lng, "source": r.source or "sqlite",
                      "source_name": "bot", "post_link": "", "provider": "sync", "report_id": r.id,
                      "supporters": r.supporters or 0}
                if r.uk_name: fb["uk_name"] = r.uk_name
                if r.uk_email: fb["uk_email"] = r.uk_email
                doc_id = await _push_realtime_complaint(fb)
                pushed += 1 if doc_id else 0; errors += 0 if doc_id else 1
            except: errors += 1
            await asyncio.sleep(0.1)
        await message.answer(f"✅ {pushed} отправлено, {errors} ошибок", reply_markup=main_kb())
    except Exception as e: await message.answer(f"❌ {e}", reply_markup=main_kb())
    finally: db.close()

# ═══ MENU BUTTON HANDLERS ═══
@dp.message(F.text == "👤 Профиль")
async def btn_profile(message: types.Message):
    """Обработчик кнопки Профиль"""
    await cmd_profile(message)

@dp.message(F.text == "🚪 Вход")
async def btn_login(message: types.Message):
    """Обработчик кнопки Вход - список: Карта проблем, Инфографика, Профиль"""
    map_url = _versioned_webapp_url("map")
    info_url = _versioned_webapp_url("info")
    buttons = [
        [InlineKeyboardButton(text="🗺️ Карта проблем", web_app=WebAppInfo(url=map_url))],
        [InlineKeyboardButton(text="📊 Инфографика", web_app=WebAppInfo(url=info_url))],
        [InlineKeyboardButton(text="👤 Профиль", callback_data="show_profile")],
    ]
    await message.answer(
        "🚪 *Вход выполнен*\n\n"
        "Доступные разделы:\n"
        "🗺️ Карта проблем — проблемы города\n"
        "📊 Инфографика — статистика\n"
        "👤 Профиль — жалобы, баланс, настройки",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    
    uid = message.from_user.id
    if uid not in user_sessions:
        user_sessions[uid] = {}
    user_sessions[uid]["authorized"] = True


@dp.callback_query(F.data == "show_profile")
async def cb_show_profile(callback: types.CallbackQuery):
    """Показать профиль по кнопке из меню входа"""
    await callback.answer()
    # Переиспользуем cmd_profile: нужен объект с from_user и answer
    class _Msg:
        from_user = callback.from_user
        async def answer(self, *a, **k):
            return await callback.message.answer(*a, **k)
    await cmd_profile(_Msg())

# ═══ PROFILE CALLBACKS ═══
@dp.callback_query(F.data == "about_project")
async def cb_about_project(callback: types.CallbackQuery):
    await callback.message.edit_text(
        "ℹ️ *Пульс города — Нижневартовск*\n\n"
        "AI мониторинг городских проблем.\n"
        "8 TG-каналов + 8 VK-пабликов.\n\n"
        "🤖 AI: Z.AI (GLM-4.7)\n"
        "📊 72 датасета opendata\n"
        "🏢 42 управляющих компании\n"
        "📧 Автоматическая отправка жалоб\n"
        "⚖️ Юридический анализ + письма",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")]
        ]))
    await callback.answer()

@dp.callback_query(F.data == "topup_menu")
async def cb_topup_menu(callback: types.CallbackQuery):
    buttons = [
        [InlineKeyboardButton(text="50 ⭐ (1 жалоба)", callback_data="topup_50")],
        [InlineKeyboardButton(text="100 ⭐ (2 жалобы)", callback_data="topup_100")],
        [InlineKeyboardButton(text="200 ⭐ (4 жалобы)", callback_data="topup_200")],
        [InlineKeyboardButton(text="500 ⭐ (10 жалоб)", callback_data="topup_500")],
        [InlineKeyboardButton(text="1000 ⭐ (20 жалоб) 🎁", callback_data="topup_1000")],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")],
    ]
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        current_balance = user.balance or 0
        await callback.message.edit_text(
            f"💳 *Пополнение баланса*\n\n"
            f"💰 Текущий баланс: *{current_balance} ⭐*\n\n"
            f"Выберите сумму для пополнения:\n"
            f"• 50 ⭐ = 1 жалоба\n"
            f"• 100 ⭐ = 2 жалобы\n"
            f"• 200 ⭐ = 4 жалобы\n"
            f"• 500 ⭐ = 10 жалоб\n"
            f"• 1000 ⭐ = 20 жалоб + бонус 🎁\n\n"
            f"💡 Первая жалоба всегда бесплатна!",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally:
        db.close()
    await callback.answer()

@dp.callback_query(F.data.startswith("topup_"))
async def cb_topup(callback: types.CallbackQuery):
    amount = int(callback.data.split("_")[1])
    
    # Calculate bonus for large amounts
    bonus = 0
    if amount >= 1000:
        bonus = 100  # 10% bonus
        description = f"Пополнение баланса на {amount} ⭐ + бонус {bonus} ⭐ = {amount + bonus} ⭐ всего!"
    elif amount >= 500:
        bonus = 25  # 5% bonus
        description = f"Пополнение баланса на {amount} ⭐ + бонус {bonus} ⭐ = {amount + bonus} ⭐ всего!"
    else:
        description = f"Пополнение баланса на {amount} ⭐ для отправки жалоб"
    
    await bot.send_invoice(
        chat_id=callback.message.chat.id,
        title=f"Пополнение {amount} ⭐" + (f" + {bonus} ⭐ бонус" if bonus > 0 else ""),
        description=description,
        payload=f"topup_{amount}_{bonus}",
        provider_token=None,  # For Telegram Stars, provider_token is not needed
        currency="XTR",
        prices=[LabeledPrice(label=f"{amount} Stars" + (f" + {bonus} бонус" if bonus > 0 else ""), amount=amount + bonus)])
    await callback.answer()

@dp.callback_query(F.data == "back_profile")
async def cb_back_profile(callback: types.CallbackQuery):
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        my_reports = db.query(Report).filter(Report.user_id == user.id).count()
        my_resolved = db.query(Report).filter(Report.user_id == user.id, Report.status == "resolved").count()
        balance = user.balance or 0
        reg_date = user.created_at.strftime("%d.%m.%Y") if user.created_at else "—"
        notify_on = getattr(user, "notify_new", 0) == 1
        free = "✅ Да" if my_reports == 0 else "❌ Использована"
        text = (f"👤 *Профиль*\n\n"
                f"👋 {callback.from_user.first_name or ''}\n"
                f"📅 Регистрация: {reg_date}\n\n"
                f"📝 Жалоб: {my_reports} · ✅ Решено: {my_resolved}\n"
                f"💰 Баланс: {balance} ⭐\n"
                f"🎁 Бесплатная жалоба: {free}\n"
                f"🔔 Уведомления: {'✅' if notify_on else '❌'}")
        notify_btn = "🔕 Выкл" if notify_on else "🔔 Вкл уведомления"
        buttons = [
            [InlineKeyboardButton(text="📋 Мои жалобы", callback_data="my_complaints")],
            [InlineKeyboardButton(text="💳 Пополнить", callback_data="topup_menu")],
            [InlineKeyboardButton(text="🔒 Платный раздел", callback_data="paid_section")],
            [InlineKeyboardButton(text=notify_btn, callback_data="toggle_notify")],
            [InlineKeyboardButton(text="ℹ️ О проекте", callback_data="about_project")],
        ]
        await callback.message.edit_text(text, parse_mode="Markdown",
                                         reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally:
        db.close()
    await callback.answer()

# ═══ ПЛАТНЫЙ РАЗДЕЛ (скрытый в Профиле) ═══
def _has_digest_subscription(user) -> bool:
    """Подписка на сводки активна (digest_subscription_until хранится в UTC, наивный datetime)."""
    until = getattr(user, "digest_subscription_until", None)
    if not until:
        return False
    return until >= datetime.utcnow()


@dp.callback_query(F.data == "paid_section")
async def cb_paid_section(callback: types.CallbackQuery):
    """Меню платного раздела: сводка за день и подписка на месяц."""
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        sub_line = ""
        if _has_digest_subscription(user):
            until = user.digest_subscription_until
            sub_line = f"\n✅ *Подписка на сводки активна до* {until.strftime('%d.%m.%Y')}.\n"
        else:
            sub_line = f"\n📅 *Подписка на месяц* — {DIGEST_SUBSCRIBE_STARS} ⭐ (ежедневные сводки без доп. платы).\n"
        body = (
            "🔒 *Платный раздел*\n\n"
            "Доступ к аналитике и сводкам по городу.\n"
            f"{sub_line}\n"
            f"📊 *Разовая сводка за день* — {DIGEST_STARS} ⭐\n"
            "Жалобы и происшествия за сегодня, краткий анализ и советы."
        )
        buttons = [
            [InlineKeyboardButton(text=f"📊 Сводка за день ({DIGEST_STARS} ⭐)" + (" ✓ по подписке" if _has_digest_subscription(user) else ""), callback_data="digest_day")],
            [InlineKeyboardButton(text=f"📅 Подписка на месяц ({DIGEST_SUBSCRIBE_STARS} ⭐)", callback_data="digest_subscribe")],
            [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")],
        ]
        await callback.message.edit_text(body, parse_mode="Markdown",
                                        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally:
        db.close()
    await callback.answer()

@dp.callback_query(F.data == "digest_subscribe")
async def cb_digest_subscribe(callback: types.CallbackQuery):
    """Оформление подписки на ежедневные сводки на месяц за 100 ⭐."""
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        balance = user.balance or 0
        if balance < DIGEST_SUBSCRIBE_STARS:
            await callback.message.edit_text(
                f"💰 Недостаточно средств.\n\n"
                f"Подписка на месяц — *{DIGEST_SUBSCRIBE_STARS} ⭐*. Ваш баланс: *{balance} ⭐*.",
                parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text="💳 Пополнить", callback_data="topup_menu")],
                    [InlineKeyboardButton(text="◀️ В платный раздел", callback_data="paid_section")],
                ]))
            await callback.answer()
            return
        user.balance = balance - DIGEST_SUBSCRIBE_STARS
        now_utc = datetime.utcnow()
        start = user.digest_subscription_until
        if start and start >= now_utc:
            user.digest_subscription_until = start + timedelta(days=30)
        else:
            user.digest_subscription_until = now_utc + timedelta(days=30)
        db.commit()
        until_str = user.digest_subscription_until.strftime("%d.%m.%Y")
        await callback.message.edit_text(
            f"✅ *Подписка оформлена*\n\n"
            f"Ежедневные сводки доступны до *{until_str}* без доп. оплаты.\n"
            f"Списано {DIGEST_SUBSCRIBE_STARS} ⭐. Баланс: *{user.balance} ⭐*.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="📊 Сводка за день", callback_data="digest_day")],
                [InlineKeyboardButton(text="◀️ В платный раздел", callback_data="paid_section")],
            ]))
    except Exception as e:
        logger.exception("digest_subscribe")
        await callback.message.edit_text(f"❌ Ошибка: {e}", reply_markup=InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(text="◀️ Назад", callback_data="paid_section")],
        ]))
    finally:
        db.close()
    await callback.answer()

@dp.callback_query(F.data == "digest_day")
async def cb_digest_day(callback: types.CallbackQuery):
    """Сводка за день: по подписке бесплатно, иначе списание 30 ⭐."""
    from services.daily_digest_service import generate_today_digest_text

    uid = callback.from_user.id
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        balance = user.balance or 0
        has_sub = _has_digest_subscription(user)
        if not has_sub and balance < DIGEST_STARS:
            await callback.message.edit_text(
                f"💰 Недостаточно средств.\n\n"
                f"Сводка за день стоит *{DIGEST_STARS} ⭐*. Ваш баланс: *{balance} ⭐*.\n\n"
                f"Или оформите подписку на месяц за *{DIGEST_SUBSCRIBE_STARS} ⭐* — сводки без доп. платы.",
                parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text="💳 Пополнить", callback_data="topup_menu")],
                    [InlineKeyboardButton(text=f"📅 Подписка ({DIGEST_SUBSCRIBE_STARS} ⭐)", callback_data="digest_subscribe")],
                    [InlineKeyboardButton(text="◀️ В платный раздел", callback_data="paid_section")],
                ]))
            await callback.answer()
            return
        if not has_sub:
            user.balance = balance - DIGEST_STARS
        db.commit()
        await callback.message.edit_text("⏳ Формирую сводку за сегодня…")
        digest = await generate_today_digest_text()
        await callback.message.answer(digest, parse_mode=None)
        status = "По подписке, без списания." if has_sub else f"Списано {DIGEST_STARS} ⭐."
        await callback.message.edit_text(
            f"📊 *Сводка за день*\n\n{status} Баланс: *{user.balance or 0} ⭐*.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="📊 Ещё сводка", callback_data="digest_day")],
                [InlineKeyboardButton(text="◀️ В платный раздел", callback_data="paid_section")],
            ]))
    except Exception as e:
        logger.exception("digest_day")
        await callback.message.edit_text(
            f"❌ Ошибка при формировании сводки: {e}",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="◀️ Назад", callback_data="paid_section")],
            ]))
    finally:
        db.close()
    await callback.answer()

@dp.callback_query(F.data == "my_complaints")
async def cb_my_complaints(callback: types.CallbackQuery):
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        reports = db.query(Report).filter(Report.user_id == user.id).order_by(Report.created_at.desc()).limit(10).all()
        if not reports:
            await callback.message.edit_text("📋 У вас пока нет жалоб.\n\nОтправьте текст или фото для создания.",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")]]))
            await callback.answer(); return
        lines = ["📋 *Мои жалобы* (последние 10):\n"]
        for r in reports:
            icon = STATUS_ICON.get(r.status, "⚪")
            date = r.created_at.strftime("%d.%m") if r.created_at else ""
            lines.append(f"{icon} {_emoji(r.category)} #{r.id} {(r.title or '')[:40]} ({date})")
        await callback.message.edit_text("\n".join(lines), parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")]]))
    finally:
        db.close()
    await callback.answer()

@dp.callback_query(F.data == "toggle_notify")
async def cb_toggle_notify(callback: types.CallbackQuery):
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        user.notify_new = 0 if getattr(user, "notify_new", 0) == 1 else 1
        db.commit()
        state = "включены ✅" if user.notify_new == 1 else "выключены ❌"
        await callback.answer(f"🔔 Уведомления {state}", show_alert=True)
    finally:
        db.close()

# ═══ PHOTO HANDLER ═══
@dp.message(F.photo)
async def handle_photo(message: types.Message):
    uid = message.from_user.id
    session = user_sessions.get(uid, {})
    if session.get("state") not in (None, "waiting_complaint"):
        user_sessions[uid] = {"state": "waiting_complaint"}

    wait_msg = await message.answer("📸 Анализирую фото...")
    try:
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        await bot.download_file(file.file_path, tmp.name)
        tmp.close()

        # Vision analysis
        try:
            vision_result = await analyze_image_with_glm4v(tmp.name, "Опиши городскую проблему на фото. Укажи категорию, адрес если виден, описание проблемы.")
        except Exception as e:
            logger.warning(f"Vision analysis error: {e}")
            vision_result = None
        
        caption = message.caption or ""
        combined_text = f"{caption}\n\nАнализ фото: {vision_result}" if vision_result else caption

        if not combined_text.strip():
            await wait_msg.edit_text("❌ Не удалось распознать фото. Добавьте описание.")
            return

        # AI analysis
        try:
            result = await analyze_complaint(combined_text)
            if not result:
                await wait_msg.edit_text(
                    "⚠️ AI временно недоступен. Продолжаем без анализа.\n\n"
                    "Выберите категорию вручную:",
                    reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                        [InlineKeyboardButton(text=cat, callback_data=f"cat:{cat}")]
                        for cat in CATEGORIES[:10]
                    ])
                )
                user_sessions[uid] = {"state": "manual_category", "description": combined_text[:2000], "photo_file_id": photo.file_id}
                return
        except Exception as e:
            logger.error(f"AI analysis error: {e}", exc_info=True)
            await wait_msg.edit_text(
                f"⚠️ Ошибка анализа: {e}\n\nВыберите категорию вручную:",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text=cat, callback_data=f"cat:{cat}")]
                    for cat in CATEGORIES[:10]
                ])
            )
            user_sessions[uid] = {"state": "manual_category", "description": combined_text[:2000], "photo_file_id": photo.file_id}
            return
        
        if not result.get("relevant", True):
            await wait_msg.edit_text("🤔 Не похоже на городскую проблему. Попробуйте описать подробнее.")
            user_sessions.pop(uid, None)
            return

        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", combined_text[:150])
        lat, lon = None, None

        if address:
            coords = await get_coordinates(address)
            if coords:
                lat, lon = coords["lat"], coords["lon"]

        # Find UK
        uk_info = await _find_uk(lat, lon, address)

        user_sessions[uid] = {
            "state": "confirming",
            "category": category, "address": address, "description": combined_text[:2000],
            "title": summary[:200], "lat": lat, "lon": lon,
            "uk_info": uk_info, "photo_file_id": photo.file_id,
            "is_anonymous": False, "vision_text": vision_result,
        }

        text = (f"📸 *Анализ фото*\n\n"
                f"{_emoji(category)} Категория: *{category}*\n"
                f"📍 Адрес: {address or 'не определён'}\n"
                f"📝 {summary[:300]}")
        if uk_info:
            text += _uk_text(uk_info)
        text += "\n\nПодтвердите или измените:"

        await wait_msg.edit_text(text, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))
        os.unlink(tmp.name)
    except Exception as e:
        logger.error(f"Photo error: {e}")
        await wait_msg.edit_text(f"❌ Ошибка: {e}")

# ═══ TEXT HANDLER ═══
@dp.message(F.text)
async def handle_text(message: types.Message):
    uid = message.from_user.id
    text = message.text.strip()

    # Skip menu buttons
    if text in MENU_BUTTONS:
        return

    session = user_sessions.get(uid, {})
    if session.get("state") not in (None, "waiting_complaint"):
        return

    if len(text) < 5:
        await message.answer("✏️ Слишком короткое сообщение. Опишите проблему подробнее.")
        return

    wait_msg = await message.answer("🤖 Анализирую...")
    try:
        result = await analyze_complaint(text)
        if not result:
            # Fallback если AI недоступен
            await wait_msg.edit_text(
                "⚠️ AI временно недоступен. Продолжаем без анализа.\n\n"
                "Выберите категорию вручную:",
                reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                    [InlineKeyboardButton(text=cat, callback_data=f"cat:{cat}")]
                    for cat in CATEGORIES[:10]
                ])
            )
            user_sessions[uid] = {"state": "manual_category", "description": text[:2000]}
            return
        
        if not result.get("relevant", True):
            await wait_msg.edit_text("🤔 Не похоже на городскую проблему.\nОпишите конкретную проблему: что, где, когда.")
            user_sessions.pop(uid, None)
            return

        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", text[:150])
        lat, lon = None, None

        if address:
            try:
                coords = await get_coordinates(address)
                if coords:
                    lat, lon = coords["lat"], coords["lon"]
            except Exception as e:
                logger.warning(f"Geocoding error: {e}")

        uk_info = await _find_uk(lat, lon, address)

        user_sessions[uid] = {
            "state": "confirming",
            "category": category, "address": address, "description": text[:2000],
            "title": summary[:200], "lat": lat, "lon": lon,
            "uk_info": uk_info, "is_anonymous": False,
        }

        resp = (f"🤖 *AI анализ*\n\n"
                f"{_emoji(category)} Категория: *{category}*\n"
                f"📍 Адрес: {address or 'не определён'}\n"
                f"📝 {summary[:300]}")
        if uk_info:
            resp += _uk_text(uk_info)
        resp += "\n\nПодтвердите или измените:"

        await wait_msg.edit_text(resp, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))
    except Exception as e:
        logger.error(f"Text error: {e}", exc_info=True)
        await wait_msg.edit_text(
            f"❌ Ошибка анализа: {e}\n\n"
            "Попробуйте описать проблему более подробно или выберите категорию вручную.",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text=cat, callback_data=f"cat:{cat}")]
                for cat in CATEGORIES[:10]
            ])
        )

# ═══ CONFIRM / PAYMENT / SEND ═══
async def _save_report(uid, is_anonymous=False):
    """Сохраняет жалобу в БД и Firebase, возвращает (report, db, user)."""
    session = user_sessions.get(uid, {})
    session["is_anonymous"] = is_anonymous
    db = _db()
    user = db.query(User).filter(User.telegram_id == uid).first()
    if not user:
        user = User(telegram_id=uid); db.add(user); db.commit(); db.refresh(user)

    report = Report(
        user_id=user.id,
        title=(session.get("title") or "")[:200],
        description=(session.get("description") or "")[:2000],
        lat=session.get("lat"), lng=session.get("lon"),
        address=session.get("address"),
        category=session.get("category", "Прочее"),
        status="open", source="bot",
    )
    uk_info = session.get("uk_info")
    if uk_info:
        report.uk_name = uk_info.get("name")
        report.uk_email = uk_info.get("email")
    db.add(report); db.commit(); db.refresh(report)
    session["report_id"] = report.id
    user_sessions[uid] = session


    # Notify subscribers
    try: await _notify_subscribers(report)
    except: pass

    return report, db, user

@dp.callback_query(F.data == "confirm")
async def cb_confirm(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "confirming":
        await callback.answer("Сессия истекла. /new", show_alert=True); return

    report, db, user = await _save_report(uid, is_anonymous=False)
    db.close()
    
    text = f"✅ Жалоба #{report.id} сохранена.\n\n"
    if session.get("uk_info"):
        text += _uk_text(session.get("uk_info"))
    
    if hasattr(callback.message, 'edit_text'):
        await callback.message.edit_text(text, parse_mode="Markdown", reply_markup=None)
    else:
        await callback.message.answer(text, parse_mode="Markdown", reply_markup=None)
    user_sessions.pop(uid, None)
    await callback.answer()

@dp.callback_query(F.data == "confirm_anon")
async def cb_confirm_anon(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "confirming":
        await callback.answer("Сессия истекла. /new", show_alert=True); return

    report, db, user = await _save_report(uid, is_anonymous=True)
    db.close()
    
    text = f"✅ Жалоба #{report.id} (анонимно) сохранена.\n\n"
    if session.get("uk_info"):
        text += _uk_text(session.get("uk_info"))
        
    if hasattr(callback.message, 'edit_text'):
        await callback.message.edit_text(text, parse_mode="Markdown", reply_markup=None)
    else:
        await callback.message.answer(text, parse_mode="Markdown", reply_markup=None)
    user_sessions.pop(uid, None)
    await callback.answer()

# ═══ CATEGORY CHANGE ═══
@dp.callback_query(F.data == "change_cat")
async def cb_change_cat(callback: types.CallbackQuery):
    await callback.message.edit_text("🏷️ Выберите категорию:", reply_markup=categories_kb())
    await callback.answer()

@dp.callback_query(F.data.startswith("cat:"))
async def cb_category_select(callback: types.CallbackQuery):
    """Обработчик выбора категории (ручной или при ошибке AI)"""
    uid = callback.from_user.id
    session = user_sessions.get(uid, {})
    
    if not session:
        await callback.answer("Сессия истекла.", show_alert=True)
        return
    
    category = callback.data[4:]  # "cat:Категория" -> "Категория"
    
    # Если это ручной выбор категории (после ошибки AI)
    if session.get("state") == "manual_category":
        description = session.get("description", "")
        photo_file_id = session.get("photo_file_id")
        
        # Пытаемся извлечь адрес из описания
        address = None
        lat, lon = None, None
        
        if description:
            try:
                coords = await get_coordinates(description)
                if coords:
                    lat, lon = coords["lat"], coords["lon"]
            except:
                pass
        
        uk_info = await _find_uk(lat, lon, address)
        
        user_sessions[uid] = {
            "state": "confirming",
            "category": category,
            "address": address,
            "description": description[:2000],
            "title": description[:200] if description else "Жалоба",
            "lat": lat,
            "lon": lon,
            "uk_info": uk_info,
            "is_anonymous": False,
            "photo_file_id": photo_file_id,
        }
        
        resp = (f"📋 *Категория выбрана*\n\n"
                f"{_emoji(category)} Категория: *{category}*\n"
                f"📍 Адрес: {address or 'не определён'}\n"
                f"📝 {description[:300] if description else '—'}")
        if uk_info:
            resp += _uk_text(uk_info)
        resp += "\n\nПодтвердите или измените:"
        
        await callback.message.edit_text(resp, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))
        await callback.answer()
        return
    
    # Обычный выбор категории (изменение существующей)
    session["category"] = category
    user_sessions[uid] = session
    
    await callback.message.edit_reply_markup(
        reply_markup=categories_kb()
    )
    await callback.answer(f"Категория: {category}")

# REMOVED DUPLICATE cb_select_cat - функционал перенесён в cb_category_select выше

@dp.callback_query(F.data == "cancel")
async def cb_cancel(callback: types.CallbackQuery):
    user_sessions.pop(callback.from_user.id, None)
    await callback.message.edit_text("❌ Отменено.", reply_markup=None)
    await callback.answer()

# ═══ OPENDATA CALLBACKS ═══
@dp.callback_query(F.data.startswith("od:"))
async def cb_opendata(callback: types.CallbackQuery):
    dataset = callback.data[3:]
    url = _versioned_webapp_url(f"info?dataset={dataset}")
    buttons = [[InlineKeyboardButton(text="📊 Открыть", web_app=WebAppInfo(url=url))]]
    await callback.message.edit_reply_markup(reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await callback.answer()

# ═══ SETUP & MAIN ═══
async def setup_menu():
    """Установка меню бота и описания в Telegram"""
    menu_version = int(time.time())
    
    # Удаляем старые команды
    try:
        await bot.delete_my_commands(scope=BotCommandScopeDefault())
        logger.info("Старые команды удалены")
    except Exception as e:
        logger.debug(f"Ошибка удаления команд: {e}")
    
    # Устанавливаем команды
    commands = [
        BotCommand(command="start", description="Главная"),
        BotCommand(command="help", description="Справка"),
        BotCommand(command="new", description="Новая жалоба"),
        BotCommand(command="map", description="Карта проблем"),
        BotCommand(command="info", description="Инфографика"),
        BotCommand(command="profile", description="Профиль"),
    ]
    await bot.set_my_commands(commands, scope=BotCommandScopeDefault())
    
    # Описание бота (показывается при открытии чата)
    try:
        await bot.set_my_description(
            description=(
                "Пульс города — Нижневартовск.\n"
                "Карта проблем, инфографика, жалобы.\n"
                "AI-мониторинг, 72 датасета opendata."
            ),
            language_code="ru"
        )
        await bot.set_my_short_description(
            short_description="Карта проблем, инфографика, жалобы в УК и администрацию",
            language_code="ru"
        )
        logger.info("Описание бота обновлено")
    except Exception as e:
        logger.debug(f"Описание бота: {e}")
    
    logger.info(f"Меню бота установлено (версия: {menu_version})")

async def main(use_webhook: bool = False, webhook_url: str = None):
    """
    Запуск бота.
    
    Args:
        use_webhook: Использовать webhook вместо polling
        webhook_url: URL для webhook (требуется если use_webhook=True)
    """
    await setup_menu()
    
    if use_webhook and webhook_url:
        # Webhook режим — не конфликтует с другими экземплярами
        webhook_path = f"{webhook_url.rstrip('/')}/webhook/telegram"
        await bot.set_webhook(webhook_path, drop_pending_updates=True)
        logger.info(f"Бот запущен в webhook режиме: {webhook_path}")
        # Webhook будет обрабатываться FastAPI/Flask
        return
    
    # Polling режим — требует эксклюзивного доступа
    try:
        await bot.delete_webhook(drop_pending_updates=True)
    except Exception as e:
        logger.debug(f"delete_webhook: {e}")
    logger.info("Бот запущен - Пульс города Нижневартовск")
    await dp.start_polling(bot)


async def process_webhook_update(update_data: dict):
    """Обработать update от webhook."""
    from aiogram.types import Update
    update = Update.model_validate(update_data)
    await dp.feed_update(bot, update)

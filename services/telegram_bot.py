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
from datetime import datetime
from typing import Optional

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
from services.geo_service import get_coordinates, geoparse
from services.zai_vision_service import analyze_image_with_glm4v
from services.realtime_guard import RealtimeGuard
from services.firebase_service import push_complaint as firebase_push
from services.uk_service import find_uk_by_address, find_uk_by_coords
from services.zai_service import analyze_complaint
from services.admin_panel import (
    is_admin, get_stats, get_firebase_stats, format_stats_message,
    get_recent_reports, format_report_message, get_bot_status,
    toggle_monitoring, is_monitoring_enabled, export_stats_csv, clear_old_reports,
    save_bot_update_report, get_last_bot_update_reports,
    get_webapp_version, bump_webapp_version,
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

# ═══ HELPERS ═══
def _get_webapp_url() -> str:
    url = os.getenv("WEBAPP_URL", "")
    if url: return url
    tunnel = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel, "r") as f: return f.read().strip()
    return CF_WORKER

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

# ═══ EMAIL ═══
def _build_complaint_email(session, recipient_name):
    rid = session.get("report_id", "?")
    cat = session.get("category", "Прочее")
    addr = session.get("address") or "не указан"
    desc = session.get("description", "")[:1500]
    title = session.get("title", "")[:200]
    lat, lon = session.get("lat"), session.get("lon")
    anon = session.get("is_anonymous", False)
    subject = f"Жалоба №{rid} — {cat} — Пульс города Нижневартовск"
    lines = [f"Уважаемый {recipient_name},", "",
             "Через систему «Пульс города — Нижневартовск» поступила жалоба:"]
    if anon: lines.append("(отправлено анонимно)")
    lines += ["", f"Номер: #{rid}", f"Категория: {cat}", f"Адрес: {addr}"]
    if lat and lon:
        lines.append(f"Координаты: {lat:.5f}, {lon:.5f}")
        lines.append(f"Карта: {_map_url(lat, lon)}")
    lines += ["", "Описание проблемы:", title, "", desc, "",
              "---", "Просим рассмотреть обращение и принять меры.",
              "С уважением, система «Пульс города — Нижневартовск»"]
    return subject, "\n".join(lines)

def _build_legal_email(session, recipient_name, legal_text):
    """Составляет юридическое письмо на основе AI-анализа."""
    rid = session.get("report_id", "?")
    cat = session.get("category", "Прочее")
    addr = session.get("address") or "не указан"
    subject = f"Обращение №{rid} — {cat} — юридический анализ — Пульс города"
    lines = [f"Уважаемый {recipient_name},", "",
             "Через систему «Пульс города — Нижневартовск» направляется обращение",
             "с юридическим обоснованием:", "",
             legal_text, "",
             "---", "Просим рассмотреть в установленные законом сроки.",
             "С уважением, система «Пульс города — Нижневартовск»"]
    return subject, "\n".join(lines)

async def _send_email_via_worker(to_email, subject, body):
    try:
        async with get_http_client(timeout=15.0) as client:
            r = await client.post(f"{CF_WORKER}/send-email", json={
                "to_email": to_email, "to_name": "", "subject": subject,
                "body": body, "from_name": "Пульс города — Нижневартовск"})
        data = r.json()
        return {"ok": data.get("ok") and not data.get("fallback")}
    except Exception as e:
        logger.error(f"Email error: {e}")
        return {"ok": False}

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
        "🔄 /sync — Синхронизация Firebase\n\n"
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
    
    # Always use timestamp to bypass cache
    version = int(__import__("time").time())
    buttons = [
        [InlineKeyboardButton(text="🗺️ Открыть карту", web_app=WebAppInfo(url=f"{CF_WORKER}/map?v={version}"))],
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
    
    # Always use timestamp to bypass cache
    version = int(__import__("time").time())
    buttons = [
        [InlineKeyboardButton(text="📊 Инфографика", web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={version}"))],
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
        [InlineKeyboardButton(text="📤 Экспорт данных", callback_data="admin:export")],
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
        firebase_stats = await get_firebase_stats()
        msg = format_stats_message(stats, firebase_stats)
        
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

    msg = (
        "⚙️ *Управление ботом*\n\n"
        f"📊 Всего жалоб: *{status['total_reports']}*\n"
        f"👥 Пользователей: *{status['total_users']}*\n"
        f"🔴 Открыто: *{status['open_reports']}*\n"
        f"✅ Решено: *{status['resolved_reports']}*\n\n"
        f"📡 Мониторинг: {monitoring_status}\n"
        f"📦 Очередь Firebase: *{status.get('firebase_queue_size', 0)}*\n"
        f"💾 Кэш AI: *{status.get('ai_cache_valid', 0)}* записей\n"
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

@dp.callback_query(F.data == "admin:export")
async def cb_admin_export(callback: types.CallbackQuery):
    """Экспорт данных"""
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
            caption="📤 Экспорт статистики"
        )
        
        await callback.answer("✅ Данные экспортированы")
    except Exception as e:
        logger.error(f"Export error: {e}")
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
        [InlineKeyboardButton(text="📤 Экспорт данных", callback_data="admin:export")],
        [InlineKeyboardButton(text="🗑️ Очистка данных", callback_data="admin:cleanup")],
    ])
    
    await callback.message.edit_text(
        "🔐 *Админ-панель*\n\n"
        "Выберите действие:",
        reply_markup=keyboard,
        parse_mode="Markdown"
    )
    await callback.answer()

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
                doc_id = await firebase_push(fb)
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
    """Обработчик кнопки Вход - открывает главное меню с доступом к функциям"""
    # Always use timestamp to bypass cache
    version = int(__import__("time").time())
    buttons = [
        [InlineKeyboardButton(text="🗺️ Карта", web_app=WebAppInfo(url=f"{CF_WORKER}/map?v={version}"))],
        [InlineKeyboardButton(text="📝 Новая жалоба", callback_data="new_complaint")],
        [InlineKeyboardButton(text="📊 Инфографика", web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={version}"))],
    ]
    await message.answer(
        "🚪 *Вход выполнен*\n\n"
        "Доступные функции:\n"
        "🗺️ Карта — проблемы города\n"
        "📝 Новая жалоба — создать жалобу\n"
        "📊 Инфографика — статистика\n\n"
        "Первая жалоба — бесплатно, далее 50 ⭐",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    
    # Сохраняем сессию как авторизованную
    uid = message.from_user.id
    if uid not in user_sessions:
        user_sessions[uid] = {}
    user_sessions[uid]["authorized"] = True

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
        [InlineKeyboardButton(text="⭐ 50 Stars", callback_data="topup_50")],
        [InlineKeyboardButton(text="⭐ 100 Stars", callback_data="topup_100")],
        [InlineKeyboardButton(text="⭐ 200 Stars", callback_data="topup_200")],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")],
    ]
    await callback.message.edit_text(
        "💳 *Пополнение баланса*\n\nВыберите сумму:",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await callback.answer()

@dp.callback_query(F.data.startswith("topup_"))
async def cb_topup(callback: types.CallbackQuery):
    amount = int(callback.data.split("_")[1])
    await bot.send_invoice(
        chat_id=callback.message.chat.id,
        title=f"Пополнение {amount} ⭐",
        description=f"Пополнение баланса на {amount} Stars для отправки жалоб",
        payload=f"topup_{amount}",
        currency="XTR",
        prices=[LabeledPrice(label=f"{amount} Stars", amount=amount)])
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
            [InlineKeyboardButton(text=notify_btn, callback_data="toggle_notify")],
            [InlineKeyboardButton(text="ℹ️ О проекте", callback_data="about_project")],
        ]
        await callback.message.edit_text(text, parse_mode="Markdown",
                                         reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
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

    # Firebase
    try:
        await firebase_push({
            "category": report.category, "summary": report.title,
            "text": (report.description or "")[:2000],
            "address": report.address, "lat": report.lat, "lng": report.lng,
            "source": "bot", "source_name": "telegram_bot",
            "provider": "user", "report_id": report.id,
        })
    except: pass

    # Notify subscribers
    try: await _notify_subscribers(report)
    except: pass

    return report, db, user

async def _show_send_options(target, session):
    """Показывает кнопки отправки: анонимное письмо / юр. анализ."""
    uk_info = session.get("uk_info")
    text = f"✅ Жалоба #{session.get('report_id')} сохранена.\n\n"
    if uk_info:
        text += _uk_text(uk_info)
        text += "\nВыберите способ отправки:"
    else:
        text += f"🏛️ УК не определена. Письмо будет направлено в администрацию.\n\n{ADMIN_NAME}\n📧 {ADMIN_EMAIL}\n\nВыберите способ отправки:"

    buttons = [
        [InlineKeyboardButton(text="✉️ Отправить анонимно", callback_data="send_anon")],
        [InlineKeyboardButton(text="⚖️ Юр. анализ + письмо", callback_data="legal_send")],
        [InlineKeyboardButton(text="❌ Не отправлять", callback_data="skip_send")],
    ]
    if hasattr(target, 'edit_text'):
        await target.edit_text(text, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    else:
        await target.answer(text, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))

@dp.callback_query(F.data == "confirm")
async def cb_confirm(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "confirming":
        await callback.answer("Сессия истекла. /new", show_alert=True); return

    # Save report
    report, db, user = await _save_report(uid, is_anonymous=False)
    complaint_count = _user_complaint_count(db, user.id)
    db.close()

    # First complaint free, else 50 Stars
    if complaint_count <= 1:
        # First complaint — free
        await _show_send_options(callback.message, session)
    else:
        # Need payment
        session["state"] = "awaiting_payment"
        user_sessions[uid] = session
        await bot.send_invoice(
            chat_id=callback.message.chat.id,
            title="Отправка жалобы — 50 ⭐",
            description=f"Жалоба #{report.id}: {session.get('category')} — {(session.get('address') or 'адрес не указан')[:50]}",
            payload=f"complaint_{report.id}",
            currency="XTR",
            prices=[LabeledPrice(label="Отправка жалобы", amount=COMPLAINT_STARS)])
    await callback.answer()

@dp.callback_query(F.data == "confirm_anon")
async def cb_confirm_anon(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "confirming":
        await callback.answer("Сессия истекла. /new", show_alert=True); return

    report, db, user = await _save_report(uid, is_anonymous=True)
    complaint_count = _user_complaint_count(db, user.id)
    db.close()

    if complaint_count <= 1:
        await _show_send_options(callback.message, session)
    else:
        session["state"] = "awaiting_payment"
        user_sessions[uid] = session
        await bot.send_invoice(
            chat_id=callback.message.chat.id,
            title="Отправка жалобы — 50 ⭐",
            description=f"Жалоба #{report.id} (анонимно): {session.get('category')}",
            payload=f"complaint_{report.id}",
            currency="XTR",
            prices=[LabeledPrice(label="Отправка жалобы", amount=COMPLAINT_STARS)])
    await callback.answer()

@dp.callback_query(F.data == "send_anon")
async def cb_send_anon(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session:
        await callback.answer("Сессия истекла.", show_alert=True); return

    uk_info = session.get("uk_info")
    to_email = uk_info.get("email") if uk_info and uk_info.get("email") else ADMIN_EMAIL
    to_name = uk_info.get("name") if uk_info else ADMIN_NAME

    subject, body = _build_complaint_email(session, to_name)
    result = await _send_email_via_worker(to_email, subject, body)

    if result.get("ok"):
        text = f"✅ Анонимное письмо отправлено!\n\n📧 Получатель: {to_name}\n✉️ {to_email}"
    else:
        text = f"⚠️ Не удалось отправить email.\nЖалоба #{session.get('report_id')} сохранена в системе."

    await callback.message.edit_text(text, reply_markup=None)
    user_sessions.pop(uid, None)
    await callback.answer()

@dp.callback_query(F.data == "legal_send")
async def cb_legal_send(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session:
        await callback.answer("Сессия истекла.", show_alert=True); return

    await callback.message.edit_text("⚖️ Юридический анализ...\nСоставляю официальное письмо...")

    uk_info = session.get("uk_info")
    uk_name = uk_info.get("name") if uk_info else ADMIN_NAME

    # AI legal analysis
    prompt = LEGAL_PROMPT.format(
        category=session.get("category", "Прочее"),
        address=session.get("address") or "не указан",
        uk_name=uk_name,
        description=(session.get("description") or "")[:1500],
    )
    try:
        legal_result = await analyze_complaint(prompt)
        legal_text = legal_result.get("summary", "")
        # If AI returned structured data instead of text, use description
        if len(legal_text) < 100:
            # Direct Z.AI call for legal text
            async with get_http_client(timeout=60.0) as client:
                r = await client.post(
                    f"https://api.z.ai/api/paas/v4/chat/completions",
                    json={"model": "glm-4.7-flash",
                          "messages": [{"role": "user", "content": prompt}],
                          "max_tokens": 4096},
                    headers={"Authorization": f"Bearer {os.getenv('ZAI_API_KEY', '')}",
                             "Content-Type": "application/json"})
                if r.status_code == 200:
                    d = r.json()
                    legal_text = d["choices"][0]["message"].get("content", "")
                    if not legal_text:
                        legal_text = d["choices"][0]["message"].get("reasoning_content", "")
    except Exception as e:
        logger.error(f"Legal analysis error: {e}")
        legal_text = ""

    if not legal_text or len(legal_text) < 50:
        await callback.message.edit_text(
            "⚠️ Не удалось выполнить юридический анализ.\n"
            "Жалоба сохранена. Попробуйте отправить анонимно.",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="✉️ Отправить анонимно", callback_data="send_anon")]]))
        return

    # Show analysis to user
    preview = legal_text[:3000]
    await callback.message.edit_text(
        f"⚖️ *Юридический анализ*\n\n{preview}",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(text="📨 Отправить в УК + администрацию", callback_data="legal_confirm")],
            [InlineKeyboardButton(text="❌ Не отправлять", callback_data="skip_send")]]))

    session["legal_text"] = legal_text
    user_sessions[uid] = session

@dp.callback_query(F.data == "legal_confirm")
async def cb_legal_confirm(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or not session.get("legal_text"):
        await callback.answer("Сессия истекла.", show_alert=True); return

    legal_text = session["legal_text"]
    uk_info = session.get("uk_info")
    results = []

    # Send to UK
    if uk_info and uk_info.get("email"):
        subj, body = _build_legal_email(session, uk_info["name"], legal_text)
        r = await _send_email_via_worker(uk_info["email"], subj, body)
        results.append(f"📧 {uk_info['name']}: {'✅' if r.get('ok') else '❌'}")

    # Send to administration
    subj, body = _build_legal_email(session, ADMIN_NAME, legal_text)
    r = await _send_email_via_worker(ADMIN_EMAIL, subj, body)
    results.append(f"📧 {ADMIN_NAME}: {'✅' if r.get('ok') else '❌'}")

    text = "📨 *Результат отправки:*\n\n" + "\n".join(results)
    text += f"\n\n⚖️ Жалоба #{session.get('report_id')} с юридическим обоснованием отправлена."
    await callback.message.edit_text(text, parse_mode="Markdown", reply_markup=None)
    user_sessions.pop(uid, None)
    await callback.answer()

@dp.callback_query(F.data == "skip_send")
async def cb_skip_send(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    rid = session.get("report_id", "?") if session else "?"
    await callback.message.edit_text(f"📋 Жалоба #{rid} сохранена в системе.\nПисьмо не отправлено.", reply_markup=None)
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

@dp.callback_query(F.data.startswith("cat:"))
async def cb_select_cat(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session:
        await callback.answer("Сессия истекла.", show_alert=True)
        return
    
    new_cat = callback.data[4:]
    
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
            except Exception as e:
                logger.debug(f"Geocoding error: {e}")
        
        uk_info = await _find_uk(lat, lon, address)
        
        user_sessions[uid] = {
            "state": "confirming",
            "category": new_cat,
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
                f"{_emoji(new_cat)} Категория: *{new_cat}*\n"
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
    session["category"] = new_cat
    user_sessions[uid] = session

    lat, lon = session.get("lat"), session.get("lon")
    text = (f"🏷️ Категория изменена: *{_emoji(new_cat)} {new_cat}*\n"
            f"📍 Адрес: {session.get('address') or 'не определён'}\n"
            f"📝 {(session.get('title') or '')[:200]}")
    uk_info = session.get("uk_info")
    if uk_info:
        text += _uk_text(uk_info)
    text += "\n\nПодтвердите:"
    await callback.message.edit_text(text, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))
    await callback.answer()

@dp.callback_query(F.data == "cancel")
async def cb_cancel(callback: types.CallbackQuery):
    user_sessions.pop(callback.from_user.id, None)
    await callback.message.edit_text("❌ Отменено.", reply_markup=None)
    await callback.answer()

# ═══ PAYMENT HANDLERS ═══
@dp.pre_checkout_query()
async def on_pre_checkout(query: PreCheckoutQuery):
    await bot.answer_pre_checkout_query(query.id, ok=True)

@dp.message(F.successful_payment)
async def on_successful_payment(message: types.Message):
    payload = message.successful_payment.invoice_payload
    amount = message.successful_payment.total_amount
    uid = message.from_user.id

    if payload.startswith("topup_"):
        # Balance top-up
        db = _db()
        try:
            user = get_or_create_user(db, message.from_user)
            user.balance = (user.balance or 0) + amount
            db.commit()
            await message.answer(f"✅ Баланс пополнен на {amount} ⭐\n💰 Текущий баланс: {user.balance} ⭐",
                reply_markup=main_kb())
        finally:
            db.close()

    elif payload.startswith("complaint_"):
        # Complaint payment — show send options
        session = user_sessions.get(uid)
        if session:
            session["state"] = "paid"
            user_sessions[uid] = session
            await message.answer(f"✅ Оплата {amount} ⭐ принята!", reply_markup=main_kb())
            await _show_send_options(message, session)
        else:
            await message.answer("✅ Оплата принята. Сессия истекла — жалоба сохранена в системе.",
                reply_markup=main_kb())

# ═══ OPENDATA CALLBACKS ═══
@dp.callback_query(F.data.startswith("od:"))
async def cb_opendata(callback: types.CallbackQuery):
    dataset = callback.data[3:]
    url = f"{CF_WORKER}/info?dataset={dataset}&v={int(__import__('time').time())}"
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

async def main():
    await setup_menu()
    # Сброс webhook — при polling webhook не должен быть установлен
    try:
        await bot.delete_webhook(drop_pending_updates=True)
    except Exception as e:
        logger.debug(f"delete_webhook: {e}")
    logger.info("Бот запущен - Пульс города Нижневартовск")
    await dp.start_polling(bot)

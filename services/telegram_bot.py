# services/telegram_bot.py
"""
Telegram Bot «Пульс города — Нижневартовск»
Все функции: команды, AI анализ текста/фото,
Street View, УК/администрация, email, анонимные жалобы,
юридический анализ (Telegram Stars), WebApp карта, Firebase RTDB,
RealtimeGuard дедупликация, opendata, ЧП.
"""

import os
import sys
import asyncio
import json
import logging
import tempfile
import time

import httpx

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton,
    InlineKeyboardMarkup, InlineKeyboardButton,
    BotCommand, BotCommandScopeDefault,
    WebAppInfo, LabeledPrice, PreCheckoutQuery,
)
from sqlalchemy import func
from sqlalchemy.orm import Session

from services.geo_service import get_coordinates, geoparse
from services.zai_vision_service import analyze_image_with_glm4v
from services.realtime_guard import RealtimeGuard
from services.firebase_service import push_complaint as firebase_push
from services.uk_service import find_uk_by_address, find_uk_by_coords
from backend.database import SessionLocal
from backend.models import Report, User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ═══ КОНФИГУРАЦИЯ ═══
BOT_TOKEN = os.getenv("TG_BOT_TOKEN", "")
CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"

ADMIN_EMAIL = "nvartovsk@n-vartovsk.ru"
ADMIN_NAME = "Администрация г. Нижневартовска"
ADMIN_PHONE = "8 (3466) 24-15-01"
LEGAL_ANALYSIS_STARS = 50

EMOJI = {
    "ЖКХ": "🏘️", "Дороги": "🛣️", "Благоустройство": "🌳", "Транспорт": "🚌",
    "Экология": "♻️", "Животные": "🐶", "Торговля": "🛒", "Безопасность": "🚨",
    "Снег/Наледь": "❄️", "Освещение": "💡", "Медицина": "🏥", "Образование": "🏫",
    "Связь": "📶", "Строительство": "🚧", "Парковки": "🅿️", "Социальная сфера": "👥",
    "Трудовое право": "📄", "Прочее": "❔", "ЧП": "🚨", "Газоснабжение": "🔥",
    "Водоснабжение и канализация": "💧", "Отопление": "🌡️", "Бытовой мусор": "🗑️",
    "Лифты и подъезды": "🏢", "Парки и скверы": "🌲", "Спортивные площадки": "⚽",
    "Детские площадки": "🎠",
}
CATEGORIES = list(EMOJI.keys())
STATUS_ICON = {"open": "🔴", "pending": "🟡", "resolved": "✅"}

LEGAL_PROMPT = (
    "Ты — юрист-консультант по жилищному и муниципальному праву РФ.\n"
    "Проанализируй жалобу жителя Нижневартовска и дай юридическую оценку.\n\n"
    "ЖАЛОБА:\nКатегория: {category}\nАдрес: {address}\nОписание: {description}\n\n"
    "ЗАДАЧА:\n"
    "1. Определи, какие нормативные акты нарушены\n"
    "2. Укажи конкретные статьи и пункты\n"
    "3. Определи ответственного: УК, администрация, ресурсоснабжающая организация\n"
    "4. Предложи порядок действий\n"
    "5. Оцени шансы на решение проблемы\n"
    "6. Укажи сроки рассмотрения\n\n"
    "Отвечай структурированно, на русском языке."
)

# Кнопки главного меню (обновлённые)
MENU_BUTTONS = {
    "📝 Новая жалоба", "🗺️ Карта", "📂 Данные города",
    "👤 Профиль", "🚨 ЧП",
}

# ═══ ИНИЦИАЛИЗАЦИЯ ═══
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()
bot_guard = RealtimeGuard()
user_sessions: dict = {}


# ═══ ХЕЛПЕРЫ ═══

def _get_webapp_url() -> str:
    url = os.getenv("WEBAPP_URL", "")
    if url:
        return url
    tunnel = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel, "r") as f:
            return f.read().strip()
    return CF_WORKER

def _db():
    return SessionLocal()

def get_or_create_user(db: Session, tg_user: types.User) -> User:
    user = db.query(User).filter(User.telegram_id == tg_user.id).first()
    if not user:
        user = User(telegram_id=tg_user.id, username=tg_user.username,
                     first_name=tg_user.first_name, last_name=tg_user.last_name)
        db.add(user); db.commit(); db.refresh(user)
    return user

def _emoji(cat: str) -> str:
    return EMOJI.get(cat, "❔")

def _sv_url(lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"

def _map_url(lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"

def _geo_buttons(lat: float, lon: float) -> list:
    return [
        InlineKeyboardButton(text="👁 Street View", url=_sv_url(lat, lon)),
        InlineKeyboardButton(text="📌 Карта", url=_map_url(lat, lon)),
    ]

def _confirm_buttons(lat=None, lon=None) -> list:
    rows = []
    if lat and lon:
        rows.append(_geo_buttons(lat, lon))
    rows.append([InlineKeyboardButton(text="✅ Подтвердить", callback_data="confirm")])
    rows.append([InlineKeyboardButton(text="🔒 Отправить анонимно", callback_data="confirm_anon")])
    rows.append([InlineKeyboardButton(text="🏷️ Изменить категорию", callback_data="change_cat")])
    rows.append([InlineKeyboardButton(text="❌ Отменить", callback_data="cancel")])
    return rows

def _uk_text(uk_info: dict | None) -> str:
    if uk_info:
        t = f"\n🏢 *УК: {uk_info['name']}*\n"
        if uk_info.get("email"): t += f"📧 {uk_info['email']}\n"
        if uk_info.get("phone"): t += f"📞 {uk_info['phone']}\n"
        if uk_info.get("director"): t += f"👤 {uk_info['director']}\n"
        return t
    return f"\n🏛️ *{ADMIN_NAME}*\n📧 {ADMIN_EMAIL}\n📞 {ADMIN_PHONE}\n"

async def _find_uk(lat, lon, address) -> dict | None:
    if lat and lon:
        return await find_uk_by_coords(lat, lon)
    if address:
        return find_uk_by_address(address)
    return None

def _truncate_msg(text: str, limit: int = 4000) -> str:
    return text[:limit - 50] + "\n```" if len(text) > limit else text

# ═══ КЛАВИАТУРЫ ═══

def main_kb():
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="📝 Новая жалоба"), KeyboardButton(text="🗺️ Карта")],
            [KeyboardButton(text="📂 Данные города"), KeyboardButton(text="🚨 ЧП")],
            [KeyboardButton(text="👤 Профиль")],
        ],
        resize_keyboard=True,
    )

def categories_kb():
    buttons, row = [], []
    for cat in CATEGORIES:
        row.append(InlineKeyboardButton(text=f"{_emoji(cat)} {cat}", callback_data=f"cat:{cat}"))
        if len(row) == 2:
            buttons.append(row); row = []
    if row:
        buttons.append(row)
    return InlineKeyboardMarkup(inline_keyboard=buttons)

# ═══ EMAIL ═══

def _build_complaint_email(session: dict, recipient_name: str) -> tuple[str, str]:
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
    lines += ["", f"📋 Номер: #{rid}", f"🏷️ Категория: {cat}", f"📍 Адрес: {addr}"]
    if lat and lon:
        lines.append(f"🗺️ Координаты: {lat:.5f}, {lon:.5f}")
        lines.append(f"🔗 Карта: {_map_url(lat, lon)}")
    lines += ["", "📝 Описание проблемы:", title, "", desc, "",
              "---", "Просим рассмотреть обращение и принять меры.",
              "С уважением, система «Пульс города — Нижневартовск»"]
    return subject, "\n".join(lines)

async def _send_email_via_worker(to_email: str, subject: str, body: str) -> dict:
    proxy = os.getenv("CLOUDFLARE_PROXY_URL", CF_WORKER)
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(f"{proxy}/send-email", json={
                "to_email": to_email, "to_name": "",
                "subject": subject, "body": body,
                "from_name": "Пульс города — Нижневартовск",
            })
        data = r.json()
        if data.get("ok") and not data.get("fallback"):
            return {"ok": True, "fallback": False, "mailto": None}
        return {"ok": False, "fallback": data.get("fallback", False), "mailto": data.get("mailto")}
    except Exception as e:
        logger.error(f"CF email error: {e}")
        return {"ok": False, "fallback": False, "mailto": None}


# ═══ КОМАНДЫ ═══

@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    webapp_url = _get_webapp_url()
    buttons = []
    if webapp_url:
        buttons.append([InlineKeyboardButton(
            text="📊 Инфографика города",
            web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={int(time.time())}"),
        )])
        buttons.append([InlineKeyboardButton(
            text="🗺️ Открыть карту",
            web_app=WebAppInfo(url=f"{webapp_url}/map?v={int(time.time())}"),
        )])
    await message.answer(
        "🏙️ *Пульс города — Нижневартовск*\n\n"
        "Система мониторинга городских проблем в реальном времени.\n"
        "AI анализирует жалобы, определяет категорию, адрес и ответственную УК.\n"
        "Мониторинг 8 Telegram-каналов и 8 VK-пабликов.\n\n"
        "📝 Отправьте текст или фото — создам жалобу\n"
        "🗺️ Карта — все проблемы на карте с рейтингом УК\n"
        "🚨 ЧП — серьёзные происшествия\n\n"
        "👇 Выберите действие:",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons) if buttons else None,
    )
    await message.answer("Меню:", reply_markup=main_kb())


@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "❓ *Справка — Пульс города*\n\n"
        "📝 /new — Создать жалобу\n"
        "🗺️ /map — Карта проблем + статистика + рейтинг УК\n"
        "🚨 /chp — Чрезвычайные происшествия\n"
        "📂 /opendata — Данные города\n"
        "👤 /profile — Профиль, мои жалобы, о проекте\n"
        "🔄 /sync — Синхронизация Firebase\n\n"
        "*Как подать жалобу:*\n"
        "1. Отправьте текст или фото\n"
        "2. AI определит категорию, адрес и УК\n"
        "3. Подтвердите — жалоба на карте",
        parse_mode="Markdown", reply_markup=main_kb(),
    )


@dp.message(Command("map"))
async def cmd_map(message: types.Message):
    webapp_url = _get_webapp_url()
    buttons = []
    if webapp_url:
        buttons.append([InlineKeyboardButton(
            text="🗺️ Открыть карту",
            web_app=WebAppInfo(url=f"{webapp_url}/map?v={int(time.time())}"),
        )])
    buttons.append([InlineKeyboardButton(
        text="🌍 OpenStreetMap",
        url="https://www.openstreetmap.org/#map=13/60.9344/76.5531",
    )])
    await message.answer(
        "🗺️ *Карта проблем Нижневартовска*\n\n"
        "На карте: жалобы, статистика в реальном времени,\n"
        "рейтинг всех 42 управляющих компаний,\n"
        "фильтры по датам, категориям и статусу.",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons),
    )


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

        text = (
            f"👤 *Профиль*\n\n"
            f"👋 {message.from_user.first_name or ''} {message.from_user.last_name or ''}\n"
            f"🆔 @{message.from_user.username or '—'}\n"
            f"📅 Регистрация: {reg_date}\n\n"
            f"📊 *Активность:*\n"
            f"📝 Жалоб подано: {my_reports}\n"
            f"✅ Решено: {my_resolved}\n\n"
            f"💰 *Баланс: {balance} ⭐*\n"
            f"🔔 Уведомления: {'✅ Вкл' if notify_on else '❌ Выкл'}\n"
        )

        notify_btn = "🔕 Выкл уведомления" if notify_on else "🔔 Вкл уведомления"
        buttons = [
            [InlineKeyboardButton(text="📋 Мои жалобы", callback_data="my_complaints")],
            [InlineKeyboardButton(text="💳 Пополнить баланс", callback_data="topup_menu")],
            [InlineKeyboardButton(text=notify_btn, callback_data="toggle_notify")],
            [InlineKeyboardButton(text="ℹ️ О проекте", callback_data="about_project")],
        ]
        webapp_url = _get_webapp_url()
        if webapp_url:
            buttons.insert(0, [InlineKeyboardButton(
                text="🗺️ Карта моих жалоб", web_app=WebAppInfo(url=f"{webapp_url}/map?v={int(time.time())}"))])

        await message.answer(text, parse_mode="Markdown",
                             reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally:
        db.close()


@dp.message(Command("chp"))
async def cmd_chp(message: types.Message):
    """ЧП — серьёзные происшествия из мониторинга."""
    db = _db()
    try:
        # Ищем жалобы категории ЧП + Безопасность + серьёзные
        chp_cats = ["ЧП", "Безопасность"]
        reports = (
            db.query(Report)
            .filter(Report.category.in_(chp_cats))
            .order_by(Report.created_at.desc()).limit(15).all()
        )
        if not reports:
            await message.answer("🚨 *ЧП*\n\nСерьёзных происшествий не зафиксировано.",
                                 parse_mode="Markdown", reply_markup=main_kb())
            return

        text = f"🚨 *Чрезвычайные происшествия*\n📊 Найдено: {len(reports)}\n\n"
        for r in reports:
            st = STATUS_ICON.get(r.status, "⚪")
            date = r.created_at.strftime("%d.%m %H:%M") if r.created_at else "—"
            text += f"{st} *{r.category}* · {date}\n"
            text += f"   {(r.title or r.description or '—')[:80]}\n"
            if r.address:
                text += f"   📍 {r.address[:50]}\n"
            text += "\n"

        await message.answer(text, parse_mode="Markdown", reply_markup=main_kb())
    finally:
        db.close()


@dp.message(Command("new"))
async def cmd_new(message: types.Message):
    user_sessions[message.from_user.id] = {"state": "waiting_complaint"}
    await message.answer(
        "📝 *Новая жалоба*\n\n"
        "Отправьте:\n• Текст с описанием проблемы\n• Или фото\n\n"
        "AI определит категорию, адрес и УК.\n/cancel — отмена",
        parse_mode="Markdown",
    )


@dp.message(Command("my"))
async def cmd_my(message: types.Message):
    db = _db()
    try:
        user = db.query(User).filter(User.telegram_id == message.from_user.id).first()
        if not user:
            await message.answer("📋 У вас пока нет жалоб.", reply_markup=main_kb())
            return
        reports = db.query(Report).filter(Report.user_id == user.id).order_by(Report.created_at.desc()).limit(10).all()
        if not reports:
            await message.answer("📋 У вас пока нет жалоб.", reply_markup=main_kb())
            return
        text = f"📋 *Ваши жалобы ({len(reports)}):*\n\n"
        for r in reports:
            st = STATUS_ICON.get(r.status, "⚪")
            text += f"{st} #{r.id} {_emoji(r.category)} {r.category}\n"
            text += f"   {(r.title or '')[:60]}\n"
            if r.address: text += f"   📍 {r.address}\n"
            text += "\n"
        await message.answer(text, parse_mode="Markdown", reply_markup=main_kb())
    finally:
        db.close()


@dp.message(Command("cancel"))
async def cmd_cancel(message: types.Message):
    user_sessions.pop(message.from_user.id, None)
    await message.answer("❌ Отменено.", reply_markup=main_kb())


@dp.message(Command("sync"))
async def cmd_sync(message: types.Message):
    await message.answer("🔄 Синхронизация с Firebase...")
    db = _db()
    try:
        reports = db.query(Report).order_by(Report.created_at.desc()).limit(100).all()
        if not reports:
            await message.answer("📋 Нет жалоб.", reply_markup=main_kb()); return
        pushed, errors = 0, 0
        for r in reports:
            try:
                fb_data = {
                    "category": r.category, "summary": r.title,
                    "text": (r.description or "")[:2000],
                    "address": r.address, "lat": r.lat, "lng": r.lng,
                    "source": r.source or "sqlite",
                    "source_name": getattr(r, "telegram_channel", None) or "bot",
                    "post_link": "", "provider": "sync", "report_id": r.id,
                    "supporters": r.supporters or 0, "supporters_notified": r.supporters_notified or 0,
                }
                if r.uk_name: fb_data["uk_name"] = r.uk_name
                if r.uk_email: fb_data["uk_email"] = r.uk_email
                doc_id = await firebase_push(fb_data)
                pushed += 1 if doc_id else 0
                errors += 0 if doc_id else 1
            except Exception: errors += 1
            await asyncio.sleep(0.1)
        await message.answer(f"✅ Синхронизация: {pushed} отправлено, {errors} ошибок", reply_markup=main_kb())
    except Exception as e:
        await message.answer(f"❌ Ошибка: {e}", reply_markup=main_kb())
    finally:
        db.close()


@dp.message(Command("opendata"))
async def cmd_opendata(message: types.Message):
    await message.answer("📂 Загружаю данные...")
    try:
        from services.opendata_service import get_all_summaries
        result = await get_all_summaries()
        if not result.get("success"):
            await message.answer("❌ Ошибка загрузки", reply_markup=main_kb()); return
        datasets = result.get("datasets", {})
        text = f"📂 *Открытые данные Нижневартовска*\n\n"
        total_rows = 0
        for key, ds in datasets.items():
            total_rows += ds.get("total_rows", 0)
            text += f"{ds.get('icon', '📄')} *{ds.get('name', key)}*: {ds.get('total_rows', 0)}\n"
        text += f"\n📊 *{len(datasets)}* датасетов, *{total_rows}* записей"

        buttons, row = [], []
        for key, ds in datasets.items():
            row.append(InlineKeyboardButton(
                text=f"{ds.get('icon', '📄')} {ds.get('name', key)[:16]}",
                callback_data=f"od:{key}"))
            if len(row) == 2: buttons.append(row); row = []
        if row: buttons.append(row)
        buttons.append([InlineKeyboardButton(text="🔄 Обновить", callback_data="od:refresh")])
        buttons.insert(0, [InlineKeyboardButton(
            text="📊 Инфографика города",
            web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={int(time.time())}"),
        )])
        await message.answer(text, parse_mode="Markdown",
                             reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    except Exception as e:
        await message.answer(f"❌ Ошибка: {e}", reply_markup=main_kb())


# ═══ КНОПКИ МЕНЮ ═══

@dp.message(F.text == "📝 Новая жалоба")
async def btn_new(message: types.Message):
    await cmd_new(message)

@dp.message(F.text == "🗺️ Карта")
async def btn_map(message: types.Message):
    await cmd_map(message)

@dp.message(F.text == "📂 Данные города")
async def btn_opendata(message: types.Message):
    await cmd_opendata(message)

@dp.message(F.text == "🚨 ЧП")
async def btn_chp(message: types.Message):
    await cmd_chp(message)

@dp.message(F.text == "👤 Профиль")
async def btn_profile(message: types.Message):
    await cmd_profile(message)


# ═══ CALLBACKS: ПРОФИЛЬ ═══

@dp.callback_query(F.data == "about_project")
async def cb_about_project(callback: types.CallbackQuery):
    await callback.answer()
    await callback.message.answer(
        "ℹ️ *Пульс города — Нижневартовск*\n\n"
        "Система мониторинга городских проблем.\n\n"
        "🎯 *Основные задачи:*\n"
        "• Сбор жалоб жителей через AI-анализ текста и фото\n"
        "• Автоматическое определение категории, адреса и ответственной УК\n"
        "• Мониторинг 8 Telegram-каналов + 8 VK-пабликов в реальном времени\n"
        "• Отображение всех проблем на интерактивной карте\n"
        "• Рейтинг 42 управляющих компаний по количеству жалоб\n"
        "• Автоматическая отправка жалоб в УК при 10+ поддержавших\n"
        "• Юридический AI-анализ с указанием статей законов\n\n"
        "⚙️ *Функционал:*\n"
        "• 27 категорий проблем\n"
        "• EXIF GPS из фото + геокодинг перекрёстков\n"
        "• Google Street View ссылки\n"
        "• Анонимные жалобы\n"
        "• Push-уведомления о новых проблемах\n"
        "• Открытые данные Нижневартовска (72 датасета)\n"
        "• Инфографика с бюджетом и статистикой\n\n"
        "🤖 AI: Z.AI GLM-4.7-Flash (текст) + GLM-4.6V-Flash (фото)\n"
        "© 2026 Пульс города",
        parse_mode="Markdown", reply_markup=main_kb(),
    )


@dp.callback_query(F.data == "topup_menu")
async def cb_topup_menu(callback: types.CallbackQuery):
    buttons = [
        [InlineKeyboardButton(text="⭐ 50 Stars", callback_data="topup_50"),
         InlineKeyboardButton(text="⭐ 100 Stars", callback_data="topup_100")],
        [InlineKeyboardButton(text="⭐ 200 Stars", callback_data="topup_200"),
         InlineKeyboardButton(text="⭐ 500 Stars", callback_data="topup_500")],
        [InlineKeyboardButton(text="◀️ Назад", callback_data="back_profile")],
    ]
    await callback.message.edit_text(
        "💳 *Пополнение баланса*\n\n50 ⭐ = 1 юридический анализ",
        parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await callback.answer()


@dp.callback_query(F.data.startswith("topup_"))
async def cb_topup(callback: types.CallbackQuery):
    amount = int(callback.data.split("_")[1])
    await bot.send_invoice(
        chat_id=callback.from_user.id,
        title=f"Пополнение — {amount} ⭐",
        description=f"Пополнение на {amount} Stars",
        payload=f"topup_{amount}", currency="XTR",
        prices=[LabeledPrice(label=f"{amount} Stars", amount=amount)],
    )
    await callback.answer()


@dp.callback_query(F.data == "back_profile")
async def cb_back_profile(callback: types.CallbackQuery):
    await callback.answer()
    await cmd_profile(callback.message)


@dp.callback_query(F.data == "my_complaints")
async def cb_my_complaints(callback: types.CallbackQuery):
    await callback.answer()
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        reports = db.query(Report).filter(Report.user_id == user.id).order_by(Report.created_at.desc()).limit(10).all()
        if not reports:
            await callback.message.answer("📭 У вас пока нет жалоб.", reply_markup=main_kb()); return
        text = f"📋 *Ваши жалобы ({len(reports)}):*\n\n"
        for r in reports:
            st = STATUS_ICON.get(r.status, "⚪")
            text += f"{st} {_emoji(r.category)} *{r.category}*\n"
            text += f"   {(r.title or r.description or '—')[:60]}\n"
            text += f"   📅 {r.created_at.strftime('%d.%m.%Y') if r.created_at else '—'}\n\n"
        await callback.message.answer(text, parse_mode="Markdown", reply_markup=main_kb())
    finally:
        db.close()


@dp.callback_query(F.data == "toggle_notify")
async def cb_toggle_notify(callback: types.CallbackQuery):
    db = _db()
    try:
        user = get_or_create_user(db, callback.from_user)
        current = getattr(user, "notify_new", 0) or 0
        user.notify_new = 0 if current else 1
        db.commit()
        await callback.answer(f"🔔 {'Включены' if user.notify_new else 'Выключены'}")
        await cmd_profile(callback.message)
    finally:
        db.close()


async def _notify_subscribers(report: Report):
    db = _db()
    try:
        subscribers = db.query(User).filter(User.notify_new == 1).all()
        if not subscribers: return
        text = (f"🔔 *Новая проблема*\n\n{_emoji(report.category)} *{report.category}*\n"
                f"📍 {report.address or '—'}\n📝 {(report.title or report.description or '')[:100]}")
        sent = 0
        for u in subscribers:
            if not u.telegram_id or u.id == report.user_id: continue
            try:
                await bot.send_message(u.telegram_id, text, parse_mode="Markdown"); sent += 1
            except Exception: pass
            if sent >= 50: break
        if sent: logger.info(f"🔔 Push: {sent} уведомлены о #{report.id}")
    except Exception as e: logger.error(f"Notify error: {e}")
    finally: db.close()


# ═══ ОБРАБОТКА ФОТО ═══

@dp.message(F.photo)
async def handle_photo(message: types.Message):
    uid = message.from_user.id
    if bot_guard.is_duplicate(f"bot_photo:{uid}", message.message_id): return
    await message.answer("🤖 Анализирую фото через AI...")

    category, description, address = "Прочее", message.caption or "Фото проблемы", None
    severity, has_vehicle, plates = "средняя", False, None
    location_hints, exif_lat, exif_lon = None, None, None

    try:
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        await bot.download_file(file.file_path, tmp.name); tmp.close()
        result = await analyze_image_with_glm4v(tmp.name, message.caption or "")
        os.unlink(tmp.name)
        category = result.get("category", "Прочее")
        description = result.get("description", message.caption or "Фото проблемы")
        address = result.get("address")
        severity = result.get("severity", "средняя")
        has_vehicle = result.get("has_vehicle_violation", False)
        plates = result.get("plates")
        location_hints = result.get("location_hints")
        exif_lat = result.get("exif_lat"); exif_lon = result.get("exif_lon")
    except Exception as e: logger.error(f"Photo analysis error: {e}")

    lat, lon, geo_source = None, None, None
    if exif_lat and exif_lon:
        lat, lon, geo_source = exif_lat, exif_lon, "exif_gps"
        if not address:
            try:
                from services.geo_service import reverse_geocode
                address = await reverse_geocode(exif_lat, exif_lon) or address
            except Exception: pass
    else:
        geo_text = f"{message.caption or ''} {description}"
        geo = await geoparse(geo_text, ai_address=address, location_hints=location_hints)
        lat, lon = geo.get("lat"), geo.get("lng")
        geo_source = geo.get("geo_source")
        if geo.get("address"): address = geo["address"]

    if has_vehicle:
        prefix = f"🚗 Нарушение парковки (гос.номер: {plates}). " if plates else "🚗 Нарушение парковки. "
        description = prefix + description

    uk_info = await _find_uk(lat, lon, address)
    user_sessions[uid] = {
        "state": "confirm", "category": category, "description": description,
        "address": address, "lat": lat, "lon": lon, "severity": severity, "uk_info": uk_info,
    }
    bot_guard.mark_processed(f"bot_photo:{uid}", message.message_id)

    e = _emoji(category)
    lines = [f"📸 *Результат анализа:*\n", f"{e} Категория: *{category}*",
             f"📍 Адрес: {address or 'Не определён'}"]
    if lat and lon:
        lines.append(f"🗺️ {lat:.5f}, {lon:.5f}")
        if geo_source == "exif_gps": lines.append("📡 _Из EXIF фото_")
    lines.append(f"⚠️ Серьёзность: {severity}")
    if has_vehicle:
        lines.append("🚗 *Нарушение парковки*")
        if plates: lines.append(f"🔢 Номер: *{plates}*")
    lines.append(_uk_text(uk_info))
    lines.append(f"📝 {description[:200]}")
    await message.answer("\n".join(lines), parse_mode="Markdown",
                         reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))


# ═══ ОБРАБОТКА ТЕКСТА ═══

@dp.message(F.text)
async def handle_text(message: types.Message):
    uid = message.from_user.id
    text = message.text.strip()
    if text.startswith("/") or text in MENU_BUTTONS: return
    if bot_guard.is_duplicate(f"bot:{uid}", message.message_id): return
    if len(text) < 5:
        await message.answer("Текст слишком короткий.", reply_markup=main_kb()); return

    await message.answer("🤖 Анализирую через AI...")
    category, address, summary, location_hints = "Прочее", None, text[:100], None
    try:
        result = await analyze_complaint(text)
        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", text[:100])
        location_hints = result.get("location_hints")
    except Exception as e: logger.error(f"Text analysis error: {e}")

    geo = await geoparse(text, ai_address=address, location_hints=location_hints)
    lat, lon = geo.get("lat"), geo.get("lng")
    if geo.get("address"): address = geo["address"]

    uk_info = await _find_uk(lat, lon, address)
    user_sessions[uid] = {
        "state": "confirm", "category": category, "description": text,
        "summary": summary, "address": address, "lat": lat, "lon": lon, "uk_info": uk_info,
    }
    bot_guard.mark_processed(f"bot:{uid}", message.message_id)

    e = _emoji(category)
    resp = f"🤖 *AI анализ:*\n\n{e} Категория: *{category}*\n📍 Адрес: {address or 'Не определён'}\n"
    if lat and lon: resp += f"🗺️ {lat:.4f}, {lon:.4f}\n"
    resp += _uk_text(uk_info)
    resp += f"\n📝 {summary}\n"
    await message.answer(resp, parse_mode="Markdown",
                         reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)))

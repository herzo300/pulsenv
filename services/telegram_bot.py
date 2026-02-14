# services/telegram_bot.py
"""
Telegram Bot «Пульс города — Нижневартовск»
Все функции: 10 команд, 7 кнопок меню, AI анализ текста/фото,
Street View, УК/администрация, email, анонимные жалобы,
юридический анализ (Telegram Stars), WebApp карта, Firebase RTDB,
RealtimeGuard дедупликация, opendata.
"""

import os
import sys
import asyncio
import json
import logging
import tempfile

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
async def main():
    logger.info("🚀 Запуск бота Пульс города...")
    logger.info(f"⏱️ RealtimeGuard: {bot_guard.startup_time.isoformat()}")
    await setup_menu()
    # Фоновое автообновление opendata раз в сутки
    try:
        from services.opendata_updater import auto_update_loop
        asyncio.create_task(auto_update_loop())
        logger.info("🔄 Автообновление opendata запущено")
    except Exception as e:
        logger.warning(f"⚠️ Opendata updater не запущен: {e}")
    await dp.start_polling(bot)
from services.zai_vision_service import analyze_image_with_glm4v
from services.realtime_guard import RealtimeGuard
from services.firebase_service import push_complaint as firebase_push
from services.uk_service import find_uk_by_address, find_uk_by_coords
from backend.database import SessionLocal
from backend.models import Report, User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════

BOT_TOKEN = os.getenv("TG_BOT_TOKEN", "")
CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"

ADMIN_EMAIL = "nvartovsk@n-vartovsk.ru"
ADMIN_NAME = "Администрация г. Нижневартовска"
ADMIN_PHONE = "8 (3466) 24-15-01"

LEGAL_ANALYSIS_STARS = 50  # 50 Stars ≈ 100₽

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

STATUS_ICON = {"open": "🔴", "pending": "🟡", "resolved": "✅"}

LEGAL_PROMPT = (
    "Ты — юрист-консультант по жилищному и муниципальному праву РФ.\n"
    "Проанализируй жалобу жителя Нижневартовска и дай юридическую оценку.\n\n"
    "ЖАЛОБА:\nКатегория: {category}\nАдрес: {address}\nОписание: {description}\n\n"
    "ЗАДАЧА:\n"
    "1. Определи, какие нормативные акты нарушены (ЖК РФ, КоАП, ГК РФ, "
    "местные НПА ХМАО/Нижневартовска, СанПиН, СНиП, ПП РФ и т.д.)\n"
    "2. Укажи конкретные статьи и пункты\n"
    "3. Определи ответственного: УК, администрация, ресурсоснабжающая организация\n"
    "4. Предложи порядок действий: куда обращаться, в какой последовательности\n"
    "5. Оцени шансы на решение проблемы (высокие/средние/низкие)\n"
    "6. Укажи сроки рассмотрения обращения по закону\n\n"
    "Отвечай структурированно, на русском языке. Будь конкретен — указывай "
    "номера статей, названия законов, сроки в днях."
)

MENU_BUTTONS = {
    "📝 Новая жалоба", "📋 Мои жалобы", "📊 Статистика",
    "🗺️ Карта", "🏷️ Категории", "📂 Данные города", "ℹ️ О проекте",
}

# ═══════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()
bot_guard = RealtimeGuard()
user_sessions: dict = {}


# ═══════════════════════════════════════════════════════
# ХЕЛПЕРЫ
# ═══════════════════════════════════════════════════════

def _get_webapp_url() -> str:
    """URL для Telegram Web App: .env → tunnel_url.txt → CF Worker fallback."""
    url = os.getenv("WEBAPP_URL", "")
    if url:
        return url
    tunnel = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tunnel_url.txt")
    if os.path.exists(tunnel):
        with open(tunnel, "r") as f:
            return f.read().strip()
    return CF_WORKER


def _db():
    """Создаёт сессию БД. Вызывающий код должен закрыть через db.close()."""
    return SessionLocal()


def get_db():
    """Generator-версия для совместимости."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_or_create_user(db: Session, tg_user: types.User) -> User:
    user = db.query(User).filter(User.telegram_id == tg_user.id).first()
    if not user:
        user = User(
            telegram_id=tg_user.id,
            username=tg_user.username,
            first_name=tg_user.first_name,
            last_name=tg_user.last_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        logger.info(f"Новый пользователь: {tg_user.first_name} ({tg_user.id})")
    return user


def _emoji(cat: str) -> str:
    return EMOJI.get(cat, "❔")


def _sv_url(lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"


def _map_url(lat: float, lon: float) -> str:
    return f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"


def _geo_buttons(lat: float, lon: float) -> list:
    """Street View + Google Maps кнопки."""
    return [
        InlineKeyboardButton(text="👁 Street View", url=_sv_url(lat, lon)),
        InlineKeyboardButton(text="📌 Карта", url=_map_url(lat, lon)),
    ]


def _confirm_buttons(lat=None, lon=None) -> list:
    """Кнопки подтверждения жалобы."""
    rows = []
    if lat and lon:
        rows.append(_geo_buttons(lat, lon))
    rows.append([InlineKeyboardButton(text="✅ Подтвердить", callback_data="confirm")])
    rows.append([InlineKeyboardButton(text="🔒 Отправить анонимно", callback_data="confirm_anon")])
    rows.append([InlineKeyboardButton(text="🏷️ Изменить категорию", callback_data="change_cat")])
    rows.append([InlineKeyboardButton(text="❌ Отменить", callback_data="cancel")])
    return rows


def _uk_text(uk_info: dict | None) -> str:
    """Блок текста про УК или администрацию."""
    if uk_info:
        t = f"\n🏢 *УК: {uk_info['name']}*\n"
        if uk_info.get("email"):
            t += f"📧 {uk_info['email']}\n"
        if uk_info.get("phone"):
            t += f"📞 {uk_info['phone']}\n"
        if uk_info.get("director"):
            t += f"👤 {uk_info['director']}\n"
        return t
    return f"\n🏛️ *{ADMIN_NAME}*\n📧 {ADMIN_EMAIL}\n📞 {ADMIN_PHONE}\n"


async def _find_uk(lat, lon, address) -> dict | None:
    """Ищет УК по координатам или адресу."""
    if lat and lon:
        return await find_uk_by_coords(lat, lon)
    if address:
        return find_uk_by_address(address)
    return None


# ═══════════════════════════════════════════════════════
# КЛАВИАТУРЫ
# ═══════════════════════════════════════════════════════

def main_kb():
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="📝 Новая жалоба"), KeyboardButton(text="📋 Мои жалобы")],
            [KeyboardButton(text="📊 Статистика"), KeyboardButton(text="🗺️ Карта")],
            [KeyboardButton(text="📂 Данные города"), KeyboardButton(text="🏷️ Категории")],
            [KeyboardButton(text="ℹ️ О проекте")],
        ],
        resize_keyboard=True,
    )


def categories_kb():
    buttons, row = [], []
    for cat in CATEGORIES:
        row.append(InlineKeyboardButton(text=f"{_emoji(cat)} {cat}", callback_data=f"cat:{cat}"))
        if len(row) == 2:
            buttons.append(row)
            row = []
    if row:
        buttons.append(row)
    return InlineKeyboardMarkup(inline_keyboard=buttons)


# ═══════════════════════════════════════════════════════
# EMAIL
# ═══════════════════════════════════════════════════════

def _build_complaint_email(session: dict, recipient_name: str) -> tuple[str, str]:
    """Формирует (subject, body) для email жалобы."""
    rid = session.get("report_id", "?")
    cat = session.get("category", "Прочее")
    addr = session.get("address") or "не указан"
    desc = session.get("description", "")[:1500]
    title = session.get("title", "")[:200]
    lat, lon = session.get("lat"), session.get("lon")
    anon = session.get("is_anonymous", False)

    subject = f"Жалоба №{rid} — {cat} — Пульс города Нижневартовск"

    lines = [
        f"Уважаемый {recipient_name},",
        "",
        "Через систему «Пульс города — Нижневартовск» поступила жалоба:",
    ]
    if anon:
        lines.append("(отправлено анонимно)")
    lines += ["", f"📋 Номер: #{rid}", f"🏷️ Категория: {cat}", f"📍 Адрес: {addr}"]
    if lat and lon:
        lines.append(f"🗺️ Координаты: {lat:.5f}, {lon:.5f}")
        lines.append(f"🔗 Карта: {_map_url(lat, lon)}")
    lines += ["", "📝 Описание проблемы:", title, "", desc, "",
              "---", "Просим рассмотреть обращение и принять меры.",
              "С уважением, система «Пульс города — Нижневартовск»"]
    return subject, "\n".join(lines)


async def _send_email_via_worker(to_email: str, subject: str, body: str) -> dict:
    """Отправляет email через CF Worker. Возвращает {ok, fallback, mailto}."""
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
            logger.info(f"📧 Email отправлен: {to_email}")
            return {"ok": True, "fallback": False, "mailto": None}
        return {"ok": False, "fallback": data.get("fallback", False), "mailto": data.get("mailto")}
    except Exception as e:
        logger.error(f"CF email error: {e}")
        return {"ok": False, "fallback": False, "mailto": None}


def _truncate_msg(text: str, limit: int = 4000) -> str:
    """Обрезает текст до лимита Telegram."""
    return text[:limit - 50] + "\n```" if len(text) > limit else text


# ═══════════════════════════════════════════════════════
# КОМАНДЫ (10 штук)
# ═══════════════════════════════════════════════════════

@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    await message.answer(
        "👋 Добро пожаловать в *Пульс города*!\n\n"
        "Я помогу сообщить о проблемах в Нижневартовске.\n\n"
        "📝 Отправьте текст или фото — я проанализирую жалобу через AI\n"
        "🗺️ Все жалобы отображаются на карте\n"
        "📊 Статистика обновляется в реальном времени\n\n"
        "Выберите действие в меню 👇",
        parse_mode="Markdown", reply_markup=main_kb(),
    )


@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "❓ *Справка — Пульс города*\n\n"
        "📝 /new — Создать жалобу\n"
        "📋 /my — Мои жалобы\n"
        "📊 /stats — Статистика\n"
        "🗺️ /map — Карта проблем\n"
        "🏷️ /categories — Категории\n"
        "📂 /opendata — Данные города\n"
        "🔄 /sync — Синхронизация Firebase\n"
        "ℹ️ /about — О проекте\n\n"
        "*Как подать жалобу:*\n"
        "1. Отправьте текст с описанием проблемы\n"
        "2. Или отправьте фото проблемы\n"
        "3. AI определит категорию и адрес\n"
        "4. Подтвердите или измените категорию\n"
        "5. Жалоба сохранится в базе и на карте",
        parse_mode="Markdown", reply_markup=main_kb(),
    )


@dp.message(Command("stats"))
async def cmd_stats(message: types.Message):
    db = _db()
    try:
        total = db.query(Report).count()
        open_c = db.query(Report).filter(Report.status.in_(["open", "pending"])).count()
        resolved = db.query(Report).filter(Report.status == "resolved").count()
        top = (
            db.query(Report.category, func.count(Report.id))
            .group_by(Report.category)
            .order_by(func.count(Report.id).desc())
            .limit(5).all()
        )
        top_text = "".join(f"  {_emoji(c)} {c}: {n}\n" for c, n in top)
        await message.answer(
            f"📊 *Статистика — Пульс города*\n\n"
            f"📋 Всего жалоб: *{total}*\n"
            f"🔴 Открыто: *{open_c}*\n"
            f"✅ Решено: *{resolved}*\n\n"
            f"🏷️ *Топ категорий:*\n{top_text}",
            parse_mode="Markdown", reply_markup=main_kb(),
        )
    finally:
        db.close()


@dp.message(Command("categories"))
async def cmd_categories(message: types.Message):
    text = "🏷️ *Категории жалоб (27):*\n\n"
    text += "".join(f"{_emoji(c)} {c}\n" for c in CATEGORIES)
    await message.answer(text, parse_mode="Markdown", reply_markup=main_kb())


@dp.message(Command("map"))
async def cmd_map(message: types.Message):
    db = _db()
    try:
        total = db.query(Report).count()
        with_coords = db.query(Report).filter(Report.lat.isnot(None), Report.lng.isnot(None)).count()
        open_c = db.query(Report).filter(Report.status.in_(["open", "pending"])).count()
        resolved = db.query(Report).filter(Report.status == "resolved").count()
        recent = (
            db.query(Report)
            .filter(Report.lat.isnot(None), Report.lng.isnot(None))
            .order_by(Report.created_at.desc()).limit(5).all()
        )

        text = (
            f"🗺️ *Карта проблем Нижневартовска*\n\n"
            f"📋 Всего жалоб: *{total}*\n"
            f"📍 С координатами: *{with_coords}*\n"
            f"🔴 Открыто: *{open_c}*\n"
            f"✅ Решено: *{resolved}*\n"
        )
        if recent:
            text += "\n📌 *Последние на карте:*\n"
            for r in recent:
                st = STATUS_ICON.get(r.status, "⚪")
                text += f"{st} #{r.id} {_emoji(r.category)} {r.category}"
                if r.address:
                    text += f" — {r.address[:40]}"
                text += "\n"

        buttons = []
        webapp_url = _get_webapp_url()
        if webapp_url:
            buttons.append([InlineKeyboardButton(
                text="🗺️ Открыть карту (Web App)",
                web_app=WebAppInfo(url=f"{webapp_url}/map"),
            )])
        buttons.append([InlineKeyboardButton(
            text="🌍 Открыть карту (OpenStreetMap)",
            url="https://www.openstreetmap.org/#map=13/60.9344/76.5531",
        )])
        if recent:
            buttons.append([InlineKeyboardButton(text="📍 Показать точки на карте", callback_data="map_points")])

        await message.answer(text, parse_mode="Markdown",
                             reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    finally:
        db.close()


@dp.message(Command("about"))
async def cmd_about(message: types.Message):
    await message.answer(
        "ℹ️ *Пульс города — Нижневартовск*\n\n"
        "Система мониторинга городских проблем.\n\n"
        "🤖 AI анализ жалоб (Z.AI GLM-4.7-Flash)\n"
        "📡 Мониторинг 8 Telegram-каналов + 8 VK пабликов\n"
        "🗺️ Интерактивная карта проблем\n"
        "💾 База данных с историей\n"
        "📊 Статистика в реальном времени\n"
        "📂 Открытые данные Нижневартовска\n"
        "📸 Анализ фото + EXIF GPS\n"
        "🛡️ Фильтрация: только реалтайм, без дублей\n\n"
        "🏷️ 27 категорий проблем\n"
        "🌍 Геокодинг адресов + перекрёстки\n"
        "📱 Telegram бот + Web-карта\n"
        "👁 Google Street View ссылки\n\n"
        "© 2026 Пульс города",
        parse_mode="Markdown", reply_markup=main_kb(),
    )


@dp.message(Command("new"))
async def cmd_new(message: types.Message):
    user_sessions[message.from_user.id] = {"state": "waiting_complaint"}
    await message.answer(
        "📝 *Новая жалоба*\n\n"
        "Отправьте:\n• Текст с описанием проблемы\n• Или фото проблемы\n\n"
        "AI автоматически определит категорию и адрес.\n"
        "Для отмены отправьте /cancel",
        parse_mode="Markdown",
    )


@dp.message(Command("my"))
async def cmd_my(message: types.Message):
    db = _db()
    try:
        user = db.query(User).filter(User.telegram_id == message.from_user.id).first()
        if not user:
            await message.answer("📋 У вас пока нет жалоб.\nОтправьте текст или фото, чтобы создать первую!", reply_markup=main_kb())
            return
        reports = (
            db.query(Report).filter(Report.user_id == user.id)
            .order_by(Report.created_at.desc()).limit(10).all()
        )
        if not reports:
            await message.answer("📋 У вас пока нет жалоб.", reply_markup=main_kb())
            return
        text = f"📋 *Ваши жалобы ({len(reports)}):*\n\n"
        for r in reports:
            st = STATUS_ICON.get(r.status, "⚪")
            text += f"{st} #{r.id} {_emoji(r.category)} {r.category}\n"
            text += f"   {r.title[:60]}\n"
            if r.address:
                text += f"   📍 {r.address}\n"
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
    """Синхронизация SQLite → Firebase RTDB."""
    await message.answer("🔄 Синхронизация с Firebase...")
    db = _db()
    try:
        reports = db.query(Report).order_by(Report.created_at.desc()).limit(100).all()
        if not reports:
            await message.answer("📋 Нет жалоб для синхронизации.", reply_markup=main_kb())
            return
        pushed, errors = 0, 0
        for r in reports:
            try:
                doc_id = await firebase_push({
                    "category": r.category, "summary": r.title,
                    "text": (r.description or "")[:2000],
                    "address": r.address, "lat": r.lat, "lng": r.lng,
                    "source": r.source or "sqlite",
                    "source_name": getattr(r, "telegram_channel", None) or "bot",
                    "post_link": "", "provider": "sync", "report_id": r.id,
                })
                pushed += 1 if doc_id else 0
                errors += 0 if doc_id else 1
            except Exception:
                errors += 1
            await asyncio.sleep(0.1)
        await message.answer(
            f"✅ Синхронизация завершена\n\n"
            f"📤 Отправлено: {pushed}\n❌ Ошибок: {errors}\n📋 Всего: {len(reports)}",
            reply_markup=main_kb(),
        )
    except Exception as e:
        logger.error(f"Sync error: {e}")
        await message.answer(f"❌ Ошибка синхронизации: {e}", reply_markup=main_kb())
    finally:
        db.close()


@dp.message(Command("opendata"))
async def cmd_opendata(message: types.Message):
    """Открытые данные Нижневартовска."""
    await message.answer("📂 Загружаю данные с портала data.n-vartovsk.ru...")
    try:
        from services.opendata_service import get_all_summaries
        result = await get_all_summaries()
        if not result.get("success"):
            await message.answer("❌ Ошибка загрузки данных", reply_markup=main_kb())
            return

        datasets = result.get("datasets", {})
        updated = result.get("updated_at", "?")
        text = f"📂 *Открытые данные Нижневартовска*\n🕐 Обновлено: {(updated or '?')[:16]}\n\n"
        total_rows = 0
        for key, ds in datasets.items():
            total_rows += ds.get("total_rows", 0)
            text += f"{ds.get('icon', '📄')} *{ds.get('name', key)}*: {ds.get('total_rows', 0)}\n"
        text += f"\n📊 *{len(datasets)}* датасетов, *{total_rows}* записей\nИсточник: data.n-vartovsk.ru"

        buttons, row = [], []
        for key, ds in datasets.items():
            row.append(InlineKeyboardButton(
                text=f"{ds.get('icon', '📄')} {ds.get('name', key)[:16]}",
                callback_data=f"od:{key}",
            ))
            if len(row) == 2:
                buttons.append(row)
                row = []
        if row:
            buttons.append(row)
        buttons.append([InlineKeyboardButton(text="🔄 Обновить данные", callback_data="od:refresh")])

        webapp_url = _get_webapp_url()
        if webapp_url:
            buttons.insert(0, [InlineKeyboardButton(
                text="🌐 Открыть Web App", web_app=WebAppInfo(url=f"{webapp_url}/map"),
            )])
        await message.answer(text, parse_mode="Markdown",
                             reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    except Exception as e:
        logger.error(f"Opendata error: {e}")
        await message.answer(f"❌ Ошибка: {e}", reply_markup=main_kb())


# ═══════════════════════════════════════════════════════
# КНОПКИ МЕНЮ (7 текстовых)
# ═══════════════════════════════════════════════════════

@dp.message(F.text == "📝 Новая жалоба")
async def btn_new(message: types.Message):
    await cmd_new(message)

@dp.message(F.text == "📋 Мои жалобы")
async def btn_my(message: types.Message):
    await cmd_my(message)

@dp.message(F.text == "📊 Статистика")
async def btn_stats(message: types.Message):
    await cmd_stats(message)

@dp.message(F.text == "🗺️ Карта")
async def btn_map(message: types.Message):
    await cmd_map(message)

@dp.message(F.text == "🏷️ Категории")
async def btn_categories(message: types.Message):
    await cmd_categories(message)

@dp.message(F.text == "📂 Данные города")
async def btn_opendata(message: types.Message):
    await cmd_opendata(message)

@dp.message(F.text == "ℹ️ О проекте")
async def btn_about(message: types.Message):
    await cmd_about(message)


# ═══════════════════════════════════════════════════════
# ОБРАБОТКА ФОТО
# ═══════════════════════════════════════════════════════

@dp.message(F.photo)
async def handle_photo(message: types.Message):
    uid = message.from_user.id
    if bot_guard.is_duplicate(f"bot_photo:{uid}", message.message_id):
        return

    await message.answer("🤖 Анализирую фото через AI...")

    # --- Анализ изображения ---
    category, description, address = "Прочее", message.caption or "Фото проблемы", None
    severity, has_vehicle, plates = "средняя", False, None
    location_hints, exif_lat, exif_lon = None, None, None

    try:
        photo = message.photo[-1]
        file = await bot.get_file(photo.file_id)
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
        await bot.download_file(file.file_path, tmp.name)
        tmp.close()

        caption = message.caption or ""
        result = await analyze_image_with_glm4v(tmp.name, caption)
        os.unlink(tmp.name)

        category = result.get("category", "Прочее")
        description = result.get("description", caption or "Фото проблемы")
        address = result.get("address")
        severity = result.get("severity", "средняя")
        has_vehicle = result.get("has_vehicle_violation", False)
        plates = result.get("plates")
        location_hints = result.get("location_hints")
        exif_lat = result.get("exif_lat")
        exif_lon = result.get("exif_lon")
    except Exception as e:
        logger.error(f"Photo analysis error: {e}")

    # --- Геопарсинг ---
    lat, lon, geo_source = None, None, None
    if exif_lat and exif_lon:
        lat, lon, geo_source = exif_lat, exif_lon, "exif_gps"
        if not address:
            try:
                from services.geo_service import reverse_geocode
                address = await reverse_geocode(exif_lat, exif_lon) or address
            except Exception:
                pass
    else:
        caption = message.caption or ""
        geo_text = f"{caption} {description}" if caption else description
        geo = await geoparse(geo_text, ai_address=address, location_hints=location_hints)
        lat, lon = geo.get("lat"), geo.get("lng")
        geo_source = geo.get("geo_source")
        if geo.get("address"):
            address = geo["address"]

    # --- Нарушение парковки ---
    if has_vehicle:
        prefix = f"🚗 Нарушение парковки (гос.номер: {plates}). " if plates else "🚗 Нарушение парковки. "
        description = prefix + description

    # --- УК ---
    uk_info = await _find_uk(lat, lon, address)

    # --- Сессия ---
    user_sessions[uid] = {
        "state": "confirm", "category": category, "description": description,
        "address": address, "lat": lat, "lon": lon, "severity": severity, "uk_info": uk_info,
    }
    bot_guard.mark_processed(f"bot_photo:{uid}", message.message_id)

    # --- Ответ ---
    e = _emoji(category)
    lines = [f"📸 *Результат анализа фото:*\n", f"{e} Категория: *{category}*",
             f"📍 Адрес: {address or 'Не определён'}"]
    if lat and lon:
        lines.append(f"🗺️ Координаты: {lat:.5f}, {lon:.5f}")
        if geo_source == "exif_gps":
            lines.append("📡 _Координаты из EXIF фото_")
    lines.append(f"⚠️ Серьёзность: {severity}")
    if has_vehicle:
        lines.append("🚗 *Нарушение парковки*")
        if plates:
            lines.append(f"🔢 Гос.номер: *{plates}*")
    lines.append(_uk_text(uk_info))
    lines.append(f"📝 {description[:200]}")

    await message.answer(
        "\n".join(lines), parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)),
    )


# ═══════════════════════════════════════════════════════
# ОБРАБОТКА ТЕКСТА (жалобы)
# ═══════════════════════════════════════════════════════

@dp.message(F.text)
async def handle_text(message: types.Message):
    uid = message.from_user.id
    text = message.text.strip()

    if text.startswith("/") or text in MENU_BUTTONS:
        return

    if bot_guard.is_duplicate(f"bot:{uid}", message.message_id):
        return

    if len(text) < 5:
        await message.answer("Текст слишком короткий. Опишите проблему подробнее.", reply_markup=main_kb())
        return

    await message.answer("🤖 Анализирую текст через AI...")

    # --- AI анализ ---
    category, address, summary, location_hints = "Прочее", None, text[:100], None
    try:
        result = await analyze_complaint(text)
        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", text[:100])
        location_hints = result.get("location_hints")
    except Exception as e:
        logger.error(f"Text analysis error: {e}")

    # --- Геопарсинг ---
    geo = await geoparse(text, ai_address=address, location_hints=location_hints)
    lat, lon = geo.get("lat"), geo.get("lng")
    if geo.get("address"):
        address = geo["address"]

    # --- УК ---
    uk_info = await _find_uk(lat, lon, address)

    # --- Сессия ---
    user_sessions[uid] = {
        "state": "confirm", "category": category, "description": text,
        "summary": summary, "address": address, "lat": lat, "lon": lon, "uk_info": uk_info,
    }
    bot_guard.mark_processed(f"bot:{uid}", message.message_id)

    # --- Ответ ---
    e = _emoji(category)
    resp = f"🤖 *Результат AI анализа:*\n\n{e} Категория: *{category}*\n📍 Адрес: {address or 'Не определён'}\n"
    if lat and lon:
        resp += f"🗺️ Координаты: {lat:.4f}, {lon:.4f}\n"
    resp += _uk_text(uk_info)
    resp += f"\n📝 {summary}\n"

    await message.answer(
        resp, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=_confirm_buttons(lat, lon)),
    )


# ═══════════════════════════════════════════════════════
# CALLBACK: ПОДТВЕРЖДЕНИЕ ЖАЛОБЫ
# ═══════════════════════════════════════════════════════

@dp.callback_query(F.data.in_({"confirm", "confirm_anon"}))
async def cb_confirm(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    is_anon = callback.data == "confirm_anon"

    if not session or session.get("state") != "confirm":
        await callback.answer("Сессия истекла. Отправьте жалобу заново.")
        return

    db = _db()
    try:
        # Пользователь
        if is_anon:
            db_user_id, source_label = None, "Аноним"
        else:
            db_user = get_or_create_user(db, callback.from_user)
            db_user_id = db_user.id
            source_label = f"@{callback.from_user.username or callback.from_user.first_name}"

        # Сохранение в SQLite
        report = Report(
            user_id=db_user_id,
            title=(session.get("summary") or session["description"])[:200],
            description=session["description"],
            lat=session.get("lat"), lng=session.get("lon"),
            address=session.get("address"), category=session["category"],
            status="open",
            source="anonymous" if is_anon else f"telegram_bot:{uid}",
        )
        db.add(report)
        db.commit()
        db.refresh(report)

        # Firebase RTDB
        try:
            await firebase_push({
                "category": report.category, "summary": report.title,
                "text": report.description, "address": report.address,
                "lat": report.lat, "lng": report.lng,
                "source": "anonymous" if is_anon else f"telegram_bot:{uid}",
                "source_name": source_label, "post_link": "",
                "provider": "bot", "report_id": report.id,
            })
        except Exception as fb_err:
            logger.error(f"Firebase push error: {fb_err}")

        # Формируем ответ
        uk_info = session.get("uk_info")
        anon_badge = "🔒 _Анонимная жалоба_\n" if is_anon else ""
        text = (
            f"✅ *Жалоба #{report.id} сохранена!*\n\n{anon_badge}"
            f"{_emoji(report.category)} *{report.category}*\n"
            f"📍 {report.address or 'Адрес не указан'}\n"
        )
        if report.lat and report.lng:
            text += f"🗺️ {report.lat:.4f}, {report.lng:.4f}\n"
        text += "\n💾 Сохранено в базе данных\n"

        # Кнопки
        kb_rows = []
        if report.lat and report.lng:
            kb_rows.append(_geo_buttons(report.lat, report.lng))

        # Переход в ask_send
        user_sessions[uid] = {
            "state": "ask_send", "report_id": report.id,
            "category": report.category, "title": report.title,
            "description": report.description, "address": report.address,
            "lat": report.lat, "lon": report.lng,
            "uk_info": uk_info, "is_anonymous": is_anon,
        }

        # Кнопки отправки
        if uk_info and uk_info.get("email"):
            text += (
                f"\n🏢 Дом обслуживает *{uk_info['name']}*\n"
                f"📧 {uk_info['email']}\n"
            )
            if uk_info.get("phone"):
                text += f"📞 {uk_info['phone']}\n"
            text += "\n📩 *Отправить жалобу в УК по email?*"
            kb_rows.append([
                InlineKeyboardButton(text="✅ Да, отправить в УК", callback_data="send_to_uk:yes"),
                InlineKeyboardButton(text="❌ Нет", callback_data="send_to_uk:no"),
            ])
            kb_rows.append([InlineKeyboardButton(text="🏛️ Отправить в администрацию", callback_data="send_to_admin:yes")])
        else:
            text += (
                f"\n🏛️ *{ADMIN_NAME}*\n📧 {ADMIN_EMAIL}\n📞 {ADMIN_PHONE}\n"
                f"\n📩 *Отправить жалобу в администрацию по email?*"
            )
            kb_rows.append([
                InlineKeyboardButton(text="✅ Да, отправить", callback_data="send_to_admin:yes"),
                InlineKeyboardButton(text="❌ Нет, спасибо", callback_data="send_to_uk:no"),
            ])

        # Юридический анализ
        kb_rows.append([InlineKeyboardButton(text="⚖️ Юридический анализ (50 ⭐)", callback_data="legal_analysis")])

        await callback.message.edit_text(
            text, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=kb_rows),
        )
        logger.info(f"✅ Жалоба #{report.id} от {source_label}")

    except Exception as e:
        logger.error(f"DB error: {e}")
        await callback.answer("❌ Ошибка сохранения")
    finally:
        db.close()


# ═══════════════════════════════════════════════════════
# CALLBACK: КАТЕГОРИЯ
# ═══════════════════════════════════════════════════════

@dp.callback_query(F.data == "change_cat")
async def cb_change_cat(callback: types.CallbackQuery):
    await callback.message.edit_text("🏷️ Выберите категорию:", reply_markup=categories_kb())


@dp.callback_query(F.data.startswith("cat:"))
async def cb_select_cat(callback: types.CallbackQuery):
    uid = callback.from_user.id
    cat = callback.data.split(":", 1)[1]
    session = user_sessions.get(uid)
    if not session:
        await callback.answer("Сессия истекла.")
        return

    session["category"] = cat
    text = (
        f"🤖 *Категория изменена:*\n\n"
        f"{_emoji(cat)} Категория: *{cat}*\n"
        f"📍 Адрес: {session.get('address') or 'Не определён'}\n\n"
        f"📝 {session.get('summary', session['description'][:100])}\n"
    )
    await callback.message.edit_text(
        text, parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(text="✅ Подтвердить", callback_data="confirm")],
            [InlineKeyboardButton(text="🔒 Отправить анонимно", callback_data="confirm_anon")],
            [InlineKeyboardButton(text="🏷️ Изменить категорию", callback_data="change_cat")],
            [InlineKeyboardButton(text="❌ Отменить", callback_data="cancel")],
        ]),
    )


@dp.callback_query(F.data == "cancel")
async def cb_cancel(callback: types.CallbackQuery):
    user_sessions.pop(callback.from_user.id, None)
    await callback.message.edit_text("❌ Отменено.")
    await callback.message.answer("Главное меню:", reply_markup=main_kb())


# ═══════════════════════════════════════════════════════
# CALLBACK: ОТПРАВКА EMAIL В УК / АДМИНИСТРАЦИЮ
# ═══════════════════════════════════════════════════════

@dp.callback_query(F.data == "send_to_uk:yes")
async def cb_send_to_uk(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "ask_send":
        await callback.answer("Сессия истекла.")
        return

    uk_info = session.get("uk_info")
    if not uk_info or not uk_info.get("email"):
        await callback.answer("❌ Email УК не найден")
        return

    uk_email, uk_name = uk_info["email"], uk_info.get("name", "УК")
    subject, body = _build_complaint_email(session, uk_name)

    await callback.answer("📧 Отправляю...")
    result = await _send_email_via_worker(uk_email, subject, body)

    if result["ok"]:
        await callback.message.edit_text(
            f"✅ *Жалоба отправлена в {uk_name}!*\n\n"
            f"📧 {uk_email}\n📋 Жалоба #{session.get('report_id')}\n\n"
            f"Ожидайте ответа от управляющей компании.",
            parse_mode="Markdown",
        )
        await callback.message.answer(
            f"📩 *Также отправить в администрацию?*\n🏛️ {ADMIN_NAME}\n📧 {ADMIN_EMAIL}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[[
                InlineKeyboardButton(text="✅ Да", callback_data="send_to_admin:yes"),
                InlineKeyboardButton(text="❌ Нет", callback_data="send_to_uk:no"),
            ]]),
        )
    else:
        short_body = body[:3500]
        text = _truncate_msg(
            f"📧 *Жалоба для отправки в {uk_name}:*\n\n"
            f"📬 Адрес: `{uk_email}`\n\n"
            f"Скопируйте текст ниже и отправьте на email УК:\n\n```\n{short_body}\n```"
        )
        kb_rows = []
        if result.get("mailto"):
            kb_rows.append([InlineKeyboardButton(text=f"📧 Открыть почту ({uk_name[:20]})", url=result["mailto"])])
        kb_rows.append([InlineKeyboardButton(text="🏛️ Отправить в администрацию", callback_data="send_to_admin:yes")])
        kb_rows.append([InlineKeyboardButton(text="👌 Готово", callback_data="send_to_uk:no")])
        await callback.message.edit_text(text, parse_mode="Markdown",
                                         reply_markup=InlineKeyboardMarkup(inline_keyboard=kb_rows))


@dp.callback_query(F.data == "send_to_admin:yes")
async def cb_send_to_admin(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "ask_send":
        await callback.answer("Сессия истекла.")
        return

    subject, body = _build_complaint_email(session, ADMIN_NAME)
    await callback.answer("📧 Отправляю...")
    result = await _send_email_via_worker(ADMIN_EMAIL, subject, body)

    if result["ok"]:
        await callback.message.edit_text(
            f"✅ *Жалоба отправлена в администрацию!*\n\n"
            f"🏛️ {ADMIN_NAME}\n📧 {ADMIN_EMAIL}\n"
            f"📋 Жалоба #{session.get('report_id')}\n\nОжидайте ответа.",
            parse_mode="Markdown",
        )
    else:
        short_body = body[:3500]
        text = _truncate_msg(
            f"📧 *Жалоба для отправки в администрацию:*\n\n"
            f"📬 Адрес: `{ADMIN_EMAIL}`\n\n"
            f"Скопируйте текст ниже и отправьте на email:\n\n```\n{short_body}\n```"
        )
        kb_rows = []
        if result.get("mailto"):
            kb_rows.append([InlineKeyboardButton(text="📧 Открыть почту (администрация)", url=result["mailto"])])
        kb_rows.append([InlineKeyboardButton(text="👌 Готово", callback_data="send_to_uk:no")])
        await callback.message.edit_text(text, parse_mode="Markdown",
                                         reply_markup=InlineKeyboardMarkup(inline_keyboard=kb_rows))
        return

    user_sessions.pop(uid, None)
    await callback.message.answer("Главное меню:", reply_markup=main_kb())


@dp.callback_query(F.data == "send_to_uk:no")
async def cb_send_skip(callback: types.CallbackQuery):
    user_sessions.pop(callback.from_user.id, None)
    await callback.message.edit_text("👌 Хорошо, жалоба сохранена в базе.\nВы всегда можете отправить её позже.")
    await callback.message.answer("Главное меню:", reply_markup=main_kb())


# ═══════════════════════════════════════════════════════
# ЮРИДИЧЕСКИЙ АНАЛИЗ (Telegram Stars)
# ═══════════════════════════════════════════════════════

@dp.callback_query(F.data == "legal_analysis")
async def cb_legal_analysis(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session or session.get("state") != "ask_send":
        await callback.answer("Сессия истекла.")
        return

    report_id = session.get("report_id", 0)
    await callback.answer()
    await bot.send_invoice(
        chat_id=uid,
        title="⚖️ Юридический анализ жалобы",
        description=(
            f"AI-анализ жалобы #{report_id} с точки зрения законодательства РФ:\n"
            "• Какие законы нарушены\n• Конкретные статьи и пункты\n"
            "• Куда обращаться и в каком порядке\n"
            "• Сроки рассмотрения\n• Оценка шансов на решение"
        ),
        payload=f"legal_{report_id}_{uid}",
        currency="XTR",
        prices=[LabeledPrice(label="Юридический анализ", amount=LEGAL_ANALYSIS_STARS)],
        provider_token="",
    )


@dp.pre_checkout_query()
async def on_pre_checkout(pre_checkout: PreCheckoutQuery):
    if pre_checkout.invoice_payload.startswith("legal_"):
        await bot.answer_pre_checkout_query(pre_checkout.id, ok=True)
    else:
        await bot.answer_pre_checkout_query(pre_checkout.id, ok=False, error_message="Неизвестный тип оплаты")


@dp.message(F.successful_payment)
async def on_successful_payment(message: types.Message):
    payment = message.successful_payment
    if not payment.invoice_payload.startswith("legal_"):
        return

    uid = message.from_user.id
    session = user_sessions.get(uid)
    if not session:
        await message.answer("❌ Сессия истекла. Оплата получена, но данные жалобы не найдены.", reply_markup=main_kb())
        return

    report_id = session.get("report_id", "?")
    category = session.get("category", "Прочее")
    address = session.get("address") or "не указан"
    description = session.get("description", "")[:2000]

    await message.answer(
        f"✅ Оплата получена ({LEGAL_ANALYSIS_STARS} ⭐)\n\n"
        f"⚖️ Запускаю юридический анализ жалобы #{report_id}...\nЭто займёт 10-20 секунд.",
    )

    try:
        prompt = LEGAL_PROMPT.format(category=category, address=address, description=description)
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post(
                "https://api.z.ai/api/paas/v4/chat/completions",
                json={
                    "model": "glm-4.7-flash",
                    "messages": [
                        {"role": "system", "content": "Ты — опытный юрист по жилищному праву РФ."},
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": 4096,
                },
                headers={
                    "Authorization": f"Bearer {os.getenv('ZAI_API_KEY', '')}",
                    "Content-Type": "application/json",
                },
            )
        if r.status_code != 200:
            raise Exception(f"Z.AI error: {r.status_code}")

        data = r.json()
        msg = data["choices"][0]["message"]
        analysis = msg.get("content") or msg.get("reasoning_content", "")
        if not analysis:
            raise Exception("Пустой ответ от AI")

        # Разбиваем длинный текст на чанки
        full_text = (
            f"⚖️ *Юридический анализ жалобы #{report_id}*\n"
            f"🏷️ {category} | 📍 {address}\n{'─' * 30}\n\n{analysis}"
        )
        chunks = []
        while full_text:
            if len(full_text) <= 4000:
                chunks.append(full_text)
                break
            cut = full_text[:4000].rfind("\n")
            if cut < 100:
                cut = 4000
            chunks.append(full_text[:cut])
            full_text = full_text[cut:]

        for chunk in chunks:
            try:
                await message.answer(chunk, parse_mode="Markdown")
            except Exception:
                await message.answer(chunk)

        logger.info(f"⚖️ Юридический анализ #{report_id} для {uid} — готов")

    except Exception as e:
        logger.error(f"Legal analysis error: {e}")
        await message.answer(
            f"❌ Ошибка юридического анализа: {e}\n\n"
            f"Оплата получена. Попробуйте позже или обратитесь в поддержку.",
            reply_markup=main_kb(),
        )

    await message.answer("Главное меню:", reply_markup=main_kb())


# ═══════════════════════════════════════════════════════
# CALLBACK: КАРТА + OPENDATA
# ═══════════════════════════════════════════════════════

@dp.callback_query(F.data == "map_points")
async def cb_map_points(callback: types.CallbackQuery):
    db = _db()
    try:
        recent = (
            db.query(Report)
            .filter(Report.lat.isnot(None), Report.lng.isnot(None))
            .order_by(Report.created_at.desc()).limit(5).all()
        )
        if not recent:
            await callback.answer("Нет жалоб с координатами")
            return

        await callback.answer("📍 Отправляю точки...")
        for r in recent:
            await callback.message.answer_venue(
                latitude=float(r.lat), longitude=float(r.lng),
                title=f"{_emoji(r.category)} {r.category} #{r.id}",
                address=r.address or f"{r.lat:.4f}, {r.lng:.4f}",
            )
            await asyncio.sleep(0.3)

        await callback.message.answer(
            f"📍 Показано {len(recent)} точек на карте.\nНажмите на любую, чтобы открыть в картах.",
            reply_markup=main_kb(),
        )
    finally:
        db.close()


@dp.callback_query(F.data.startswith("od:"))
async def cb_opendata(callback: types.CallbackQuery):
    key = callback.data.split(":", 1)[1]

    if key == "refresh":
        await callback.answer("🔄 Обновляю...")
        try:
            from services.opendata_service import refresh_all_datasets
            await refresh_all_datasets()
            await callback.answer("✅ Данные обновлены")
        except Exception as e:
            await callback.answer(f"❌ {e}")
        return

    if key == "back":
        await callback.answer()
        await cmd_opendata(callback.message)
        return

    await callback.answer("📂 Загружаю...")
    try:
        data_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "opendata_full.json")
        if not os.path.exists(data_file):
            await callback.message.answer("❌ Данные не загружены. Используйте /opendata", reply_markup=main_kb())
            return

        with open(data_file, "r", encoding="utf-8") as f:
            all_data = json.load(f)

        ds = all_data.get(key)
        if not ds:
            await callback.message.answer(f"❌ Датасет '{key}' не найден", reply_markup=main_kb())
            return

        rows = ds.get("rows", [])
        total = ds.get("total", len(rows))
        text = f"{ds.get('icon', '📄')} *{ds.get('name', key)}*\n📊 Записей: *{total}*\n\n"

        for i, row in enumerate(rows[:10], 1):
            title = (row.get("TITLE") or row.get("TITLESM") or row.get("NAME") or
                     row.get("FIO") or row.get("DEPARTMENT") or row.get("ORGANIZATION") or
                     row.get("STREET") or row.get("OBJECT") or row.get("SECTION") or
                     row.get("FUEL_TYPE") or row.get("PERIOD") or "")
            if not title:
                for v in row.values():
                    if isinstance(v, str) and 2 < len(v) < 100:
                        title = v
                        break
            text += f"*{i}.* {str(title)[:70]}\n"
            addr = row.get("ADR") or row.get("ADDRESS") or row.get("ADRESS") or ""
            if addr:
                text += f"   📍 {str(addr)[:50]}\n"
            tel = row.get("TEL") or row.get("PHONE") or ""
            if tel:
                text += f"   📞 {tel}\n"
            fio = row.get("FIO") or row.get("DIRECTOR") or ""
            if fio and fio != title:
                text += f"   👤 {fio[:40]}\n"
            cnt = row.get("CNT") or row.get("COUNT") or row.get("CAPACITY") or ""
            if cnt:
                text += f"   📊 Кол-во: {cnt}\n"
            text += "\n"

        if total > 10:
            text += f"_...и ещё {total - 10} записей_\n"
        text += "\nИсточник: data.n-vartovsk.ru"

        if len(text) > 4000:
            text = text[:3950] + "\n\n_...обрезано_"

        await callback.message.answer(
            text, parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="← Назад к списку", callback_data="od:back")]
            ]),
        )
    except Exception as e:
        logger.error(f"Opendata detail error: {e}")
        await callback.message.answer(f"❌ Ошибка: {e}", reply_markup=main_kb())


# ═══════════════════════════════════════════════════════
# ЗАПУСК
# ═══════════════════════════════════════════════════════

async def setup_menu():
    commands = [
        BotCommand(command="start", description="🏠 Главное меню"),
        BotCommand(command="help", description="❓ Помощь"),
        BotCommand(command="new", description="📝 Новая жалоба"),
        BotCommand(command="my", description="📋 Мои жалобы"),
        BotCommand(command="stats", description="📊 Статистика"),
        BotCommand(command="map", description="🗺️ Карта проблем"),
        BotCommand(command="opendata", description="📂 Данные города"),
        BotCommand(command="categories", description="🏷️ Категории"),
        BotCommand(command="about", description="ℹ️ О проекте"),
        BotCommand(command="sync", description="🔄 Синхронизация Firebase"),
    ]
    await bot.set_my_commands(commands, scope=BotCommandScopeDefault())
    logger.info("✅ Меню бота установлено (10 команд)")


async def main():
    logger.info("🚀 Запуск бота Пульс города...")
    logger.info(f"⏱️ RealtimeGuard: {bot_guard.startup_time.isoformat()}")
    await setup_menu()
    await dp.start_polling(bot)

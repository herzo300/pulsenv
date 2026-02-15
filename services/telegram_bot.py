# services/telegram_bot.py
"""
Telegram Bot «Пульс города — Нижневартовск»
AI анализ текста/фото, УК/администрация, email, юр. анализ + письма.
Первая жалоба бесплатно, далее 50 Stars.
"""
import os, sys, asyncio, json, logging, tempfile, time
import httpx
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv; load_dotenv()
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton,
    BotCommand, BotCommandScopeDefault, WebAppInfo, LabeledPrice, PreCheckoutQuery,
)
from sqlalchemy.orm import Session
from services.geo_service import get_coordinates, geoparse
from services.zai_vision_service import analyze_image_with_glm4v
from services.realtime_guard import RealtimeGuard
from services.firebase_service import push_complaint as firebase_push
from services.uk_service import find_uk_by_address, find_uk_by_coords
from services.zai_service import analyze_complaint
from backend.database import SessionLocal
from backend.models import Report, User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.getenv("TG_BOT_TOKEN", "")
CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"
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
    return ReplyKeyboardMarkup(keyboard=[
        [KeyboardButton(text="📝 Новая жалоба"), KeyboardButton(text="🗺️ Карта")],
        [KeyboardButton(text="📊 Инфографика"), KeyboardButton(text="👤 Профиль")],
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
        async with httpx.AsyncClient(timeout=15.0) as client:
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
    buttons = [
        [InlineKeyboardButton(text="📊 Инфографика", web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={int(time.time())}"))],
        [InlineKeyboardButton(text="🗺️ Карта", web_app=WebAppInfo(url=f"{CF_WORKER}/map?v={int(time.time())}"))],
    ]
    await message.answer(
        "🏙️ *Пульс города — Нижневартовск*\n\n"
        "AI мониторинг городских проблем.\n"
        "8 TG-каналов + 8 VK-пабликов.\n\n"
        "📝 Отправьте текст или фото — создам жалобу\n"
        "🗺️ Карта — проблемы + рейтинг УК\n"
        "📊 Инфографика — бюджет, статистика\n\n"
        "Первая жалоба — бесплатно, далее 50 ⭐",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await message.answer("Меню:", reply_markup=main_kb())

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
    buttons = [
        [InlineKeyboardButton(text="🗺️ Открыть карту", web_app=WebAppInfo(url=f"{CF_WORKER}/map?v={int(time.time())}"))],
        [InlineKeyboardButton(text="🌍 OpenStreetMap", url="https://www.openstreetmap.org/#map=13/60.9344/76.5531")],
    ]
    await message.answer("🗺️ *Карта проблем*\n\nЖалобы, рейтинг 42 УК, фильтры.",
        parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))

@dp.message(Command("info"))
async def cmd_info(message: types.Message):
    buttons = [[InlineKeyboardButton(text="📊 Инфографика", web_app=WebAppInfo(url=f"{CF_WORKER}/info?v={int(time.time())}"))]]
    await message.answer("📊 *Инфографика Нижневартовска*\n\n72 датасета: бюджет, ЖКХ, транспорт, образование.",
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

@dp.message(Command("new"))
async def cmd_new(message: types.Message):
    user_sessions[message.from_user.id] = {"state": "waiting_complaint"}
    await message.answer("📝 *Новая жалоба*\n\nОтправьте текст или фото.\nAI определит категорию, адрес и УК.\n/cancel — отмена",
        parse_mode="Markdown")

@dp.message(Command("cancel"))
async def cmd_cancel(message: types.Message):
    user_sessions.pop(message.from_user.id, None)
    await message.answer("❌ Отменено.", reply_markup=main_kb())

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
@dp.message(F.text == "📝 Новая жалоба")
async def btn_new(message: types.Message):
    await cmd_new(message)

@dp.message(F.text == "🗺️ Карта")
async def btn_map(message: types.Message):
    await cmd_map(message)

@dp.message(F.text == "📊 Инфографика")
async def btn_info(message: types.Message):
    await cmd_info(message)

@dp.message(F.text == "👤 Профиль")
async def btn_profile(message: types.Message):
    await cmd_profile(message)

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
        vision_result = await analyze_image_with_glm4v(tmp.name, "Опиши городскую проблему на фото. Укажи категорию, адрес если виден, описание проблемы.")
        caption = message.caption or ""
        combined_text = f"{caption}\n\nАнализ фото: {vision_result}" if vision_result else caption

        if not combined_text.strip():
            await wait_msg.edit_text("❌ Не удалось распознать фото. Добавьте описание.")
            return

        # AI analysis
        result = await analyze_complaint(combined_text)
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
        if not result.get("relevant", True):
            await wait_msg.edit_text("🤔 Не похоже на городскую проблему.\nОпишите конкретную проблему: что, где, когда.")
            user_sessions.pop(uid, None)
            return

        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", text[:150])
        lat, lon = None, None

        if address:
            coords = await get_coordinates(address)
            if coords:
                lat, lon = coords["lat"], coords["lon"]

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
        logger.error(f"Text error: {e}")
        await wait_msg.edit_text(f"❌ Ошибка: {e}")

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
            import httpx as _hx
            async with _hx.AsyncClient(timeout=60.0) as client:
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
async def cb_select_cat(callback: types.CallbackQuery):
    uid = callback.from_user.id
    session = user_sessions.get(uid)
    if not session:
        await callback.answer("Сессия истекла.", show_alert=True); return
    new_cat = callback.data[4:]
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
    url = f"{CF_WORKER}/info?dataset={dataset}&v={int(time.time())}"
    buttons = [[InlineKeyboardButton(text="📊 Открыть", web_app=WebAppInfo(url=url))]]
    await callback.message.edit_reply_markup(reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await callback.answer()

# ═══ SETUP & MAIN ═══
async def setup_menu():
    commands = [
        BotCommand(command="start", description="🏠 Главная"),
        BotCommand(command="help", description="❓ Справка"),
        BotCommand(command="new", description="📝 Новая жалоба"),
        BotCommand(command="map", description="🗺️ Карта"),
        BotCommand(command="info", description="📊 Инфографика"),
        BotCommand(command="profile", description="👤 Профиль"),
    ]
    await bot.set_my_commands(commands, scope=BotCommandScopeDefault())
    logger.info("✅ Меню бота установлено")

async def main():
    await setup_menu()
    logger.info("🚀 Бот запущен — Пульс города Нижневартовск")
    await dp.start_polling(bot)

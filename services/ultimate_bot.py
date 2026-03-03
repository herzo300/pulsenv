"""
Ultimate Telegram Bot — «Пульс города Нижневартовск»
Объединение V1 и V2: AI анализ, мониторинг, админка и вокал-ремувер.
"""
import os
import sys
import asyncio
import logging
import tempfile
from pathlib import Path
from datetime import datetime, timezone

from aiogram import Bot, Dispatcher, types, F, Router
from aiogram.filters import Command, BaseFilter
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton,
    BotCommand, BotCommandScopeDefault, Message, CallbackQuery, WebAppInfo
)

# Добавляем корень проекта в путь
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Импорты сервисов
from services.geo_service import get_coordinates
from services.realtime_guard import RealtimeGuard
from services.supabase_service import push_complaint as supabase_push_complaint
from services.zai_service import analyze_complaint, get_ai_provider_status
from services.rate_limiter import check_rate_limit
from services.vocal_remover_service import (
    separate_audio, check_installation as uvr_check, MODELS as UVR_MODELS
)
from backend.database import SessionLocal
from backend.models import Report, User
from core.config import (
    TG_BOT_TOKEN as BOT_TOKEN,
    ADMIN_TELEGRAM_IDS,
)

# ══════════════════════════════════════════════════════════════════════════════
# ЛОГИРОВАНИЕ И ИНИЦИАЛИЗАЦИЯ
# ══════════════════════════════════════════════════════════════════════════════
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("UltimateBot")

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())
guard = RealtimeGuard()
router = Router()

# ══════════════════════════════════════════════════════════════════════════════
# FSM И ФИЛЬТРЫ
# ══════════════════════════════════════════════════════════════════════════════
class ComplaintStates(StatesGroup):
    waiting_complaint = State()
    confirming = State()
    selecting_category = State()
    awaiting_payment = State()

class UvrStates(StatesGroup):
    waiting_audio = State()
    selecting_model = State()

class AdminFilter(BaseFilter):
    async def __call__(self, message: Message) -> bool:
        is_adm = message.from_user.id in ADMIN_TELEGRAM_IDS
        logger.debug(f"AdminFilter check: user_id={message.from_user.id}, is_admin={is_adm}")
        return is_adm

# ══════════════════════════════════════════════════════════════════════════════
# КОНСТАНТЫ И КЛАВИАТУРЫ
# ══════════════════════════════════════════════════════════════════════════════
EMOJI = {
    "ЖКХ": "🏘️", "Дороги": "🛣️", "Благоустройство": "🌳", "Транспорт": "🚌",
    "Экология": "♻️", "Животные": "🐶", "Торговля": "🛒", "Безопасность": "🚨",
    "Снег/Наледь": "❄️", "Освещение": "💡", "Медицина": "🏥", "Образование": "🏫",
    "Связь": "📶", "Строительство": "🚧", "Парковки": "🅿️", "Прочее": "❔",
}

def main_kb(user_id: int = None):
    from services.admin_panel import get_webapp_version
    from core.config import PUBLIC_API_BASE_URL, ADMIN_TELEGRAM_IDS, USE_SUPABASE_PRIMARY, SUPABASE_URL
    ver = get_webapp_version() or int(__import__("time").time())
    
    is_admin = user_id in ADMIN_TELEGRAM_IDS if user_id else False
    
    if USE_SUPABASE_PRIMARY and SUPABASE_URL:
        # Используем НОВЫЕ эндпоинты Mapper-Puls и Info-Puls в Storage для гарантированного рендеринга HTML
        map_url = f"{SUPABASE_URL}/storage/v1/object/public/apps/map.html?v={ver}"
        info_url = f"{SUPABASE_URL}/storage/v1/object/public/apps/info.html?v={ver}"
        has_https = True
    else:
        map_url = f"{PUBLIC_API_BASE_URL}/map?v={ver}"
        info_url = f"{PUBLIC_API_BASE_URL}/infographic?v={ver}"
        has_https = PUBLIC_API_BASE_URL.startswith("https://")
    
    kb = [
        [KeyboardButton(text="📝 Новая жалоба")],
    ]
    
    if has_https:
        kb.append([
            KeyboardButton(text="🗺️ Карта", web_app=WebAppInfo(url=map_url))
        ])
    else:
        kb.append([
            KeyboardButton(text="🗺️ Карта")
        ])
    
    kb.append([
        KeyboardButton(text="👤 Профиль")
    ])
    
    if is_admin:
        kb.append([KeyboardButton(text="🔐 Админ-панель")])
        
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True)

def admin_kb(user_id: int = None):
    """Клавиатура для админ-панели"""
    from services.admin_panel import get_webapp_version
    from core.config import PUBLIC_API_BASE_URL, SUPABASE_URL, USE_SUPABASE_PRIMARY
    
    ver = get_webapp_version() or int(__import__("time").time())
        
    map_url = f"{SUPABASE_URL}/storage/v1/object/public/apps/map.html?v={ver}" if USE_SUPABASE_PRIMARY else f"{PUBLIC_API_BASE_URL}/map?v={ver}"
    
    kb = [
        [KeyboardButton(text="📝 Новая жалоба")], # Админ тоже может подать
        [KeyboardButton(text="🗺️ Управление картой", web_app=WebAppInfo(url=map_url))],
        [KeyboardButton(text="✂️ Sound Separator")],
        [KeyboardButton(text="🔄 Синхронизировать с Supabase")],
        [KeyboardButton(text="🏠 Главное меню")]
    ]
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True)

# ══════════════════════════════════════════════════════════════════════════════
# ХЭНДЛЕРЫ КОМАНД
# ══════════════════════════════════════════════════════════════════════════════
@router.message(Command("start"))
async def cmd_start(message: Message, state: FSMContext):
    await state.clear()
    await message.answer(
        "🏙️ *Пульс города — Нижневартовск*\n\n"
        "Добро пожаловать в единую систему мониторинга городских проблем!\n\n"
        "📝 Опишите проблему или отправьте фото\n"
        "🗺️ Посмотрите карту проблем\n"
        "📊 Изучите открытые данные города",
        parse_mode="Markdown",
        reply_markup=main_kb(message.from_user.id)
    )

@router.message(Command("new"))
@router.message(F.text == "📝 Новая жалоба")
async def cmd_new(message: Message, state: FSMContext):
    if not check_rate_limit(message.from_user.id, "complaint"):
        await message.answer("⏳ Слишком много запросов. Подождите немного.")
        return
    await state.set_state(ComplaintStates.waiting_complaint)
    await message.answer("📝 *Новая жалоба*\n\nОтправьте текст или фото проблемы. /cancel — для отмены.", parse_mode="Markdown")

@router.message(F.text == "🗺️ Карта")
@router.message(Command("map"))
async def cmd_map_text(message: Message):
    from core.config import PUBLIC_API_BASE_URL, USE_SUPABASE_PRIMARY, SUPABASE_URL
    from services.admin_panel import get_webapp_version
    
    try: ver = get_webapp_version()
    except: ver = 1
    
    if USE_SUPABASE_PRIMARY and SUPABASE_URL:
        link = f"{SUPABASE_URL}/storage/v1/object/public/apps/map.html?v={ver or 100}"
    else:
        link = f"{PUBLIC_API_BASE_URL}/map?v={ver or 100}"

    await message.answer(
        f"🗺️ *Карта проблем*\n\n"
        f"Просмотр всех заявок на карте города:\n{link}\n\n"
        "💡 Используйте кнопку в меню для открытия встроенного приложения.",
        parse_mode="Markdown"
    )

@router.message(F.text == "📊 Статистика")
@router.message(Command("info"))
async def cmd_stats_text(message: Message):
    from core.config import PUBLIC_API_BASE_URL, USE_SUPABASE_PRIMARY, SUPABASE_URL
    from services.admin_panel import get_webapp_version
    
    try: ver = get_webapp_version()
    except: ver = 1
    
    if USE_SUPABASE_PRIMARY and SUPABASE_URL:
        link = f"{SUPABASE_URL}/storage/v1/object/public/apps/info.html?v={ver or 100}"
    else:
        link = f"{PUBLIC_API_BASE_URL}/infographic?v={ver or 100}"

    await message.answer(
        f"📊 *Статистика и аналитика*\n\n"
        f"Открытые данные города:\n{link}",
        parse_mode="Markdown"
    )

@router.message(Command("cancel"))
@router.message(F.text == "❌ Отмена")
async def cmd_cancel(message: Message, state: FSMContext):
    await state.clear()
    await message.answer("❌ Действие отменено.", reply_markup=main_kb(message.from_user.id))

@router.message(Command("profile"))
@router.message(F.text == "👤 Профиль")
async def cmd_profile(message: Message):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.telegram_id == message.from_user.id).first()
        reports_count = db.query(Report).filter(Report.user_id == user.id).count() if user else 0
        
        profile_text = (
            f"👤 *Ваш профиль*\n\n"
            f"📝 Жалоб отправлено: {reports_count}\n\n"
            f"🛠️ *Функции бота:*\n"
            f"• 📝 *Новая жалоба* — сообщить о городской проблеме (AI определит категорию и координаты).\n"
            f"• 🗺️ *Карта* — посмотреть все актуальные обращения на интерактивной HDBSCAN-карте.\n"
            f"• 👤 *Профиль* — ваш личный кабинет."
        )
        if message.from_user.id in ADMIN_TELEGRAM_IDS:
            profile_text += "\n• 🔐 *Админ-панель* — управление, статистика и вокал-ремувер."
            
        await message.answer(profile_text, parse_mode="Markdown")
    finally:
        db.close()

@router.message(Command("help"))
@router.message(F.text == "❓ Помощь")
async def cmd_help(message: Message):
    await message.answer(
        "❓ *Помощь*\n\n"
        "Бот позволяет отправлять жалобы о городских проблемах.\n"
        "1. Нажмите «Новая жалоба».\n"
        "2. Опишите проблему или отправьте фото.\n"
        "3. Подтвердите отправку.\n\n"
        "Для просмотра карты и статистики используйте встроенное приложение (кнопки в меню).",
        parse_mode="Markdown"
    )

# ══════════════════════════════════════════════════════════════════════════════
# VOCAL REMOVER (ADMIN ONLY)
# ══════════════════════════════════════════════════════════════════════════════
@router.message(Command("uvr"), AdminFilter())
async def cmd_uvr(message: Message, state: FSMContext):
    is_ready, status = await uvr_check()
    await message.answer(f"🎵 *Vocal Remover API*\n\n{status}\n\nОтправьте аудиофайл или голосовое сообщение.", parse_mode="Markdown")
    await state.set_state(UvrStates.waiting_audio)

@router.message(UvrStates.waiting_audio, F.audio | F.voice)
async def handle_uvr_audio(message: Message, state: FSMContext):
    file_id = message.audio.file_id if message.audio else message.voice.file_id
    await state.update_data(file_id=file_id)
    
    buttons = []
    for k, v in UVR_MODELS.items():
        buttons.append([InlineKeyboardButton(text=v['name'], callback_data=f"uvr_mod:{k}")])
    
    await message.answer("Выберите модель для разделения:", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    await state.set_state(UvrStates.selecting_model)

@router.callback_query(F.data.startswith("uvr_mod:"), UvrStates.selecting_model)
async def process_uvr(callback: CallbackQuery, state: FSMContext):
    model_key = callback.data.split(":")[1]
    data = await state.get_data()
    file_id = data.get("file_id")
    
    await callback.message.edit_text(f"⏳ Начинаю обработку...\nМодель: {model_key}\n\n1. Загрузка файла на сервер...")
    
    tmp_path = None
    try:
        file = await bot.get_file(file_id)
        # Use .wav for better compatibility or keep .mp3 as requested
        suffix = os.path.splitext(file.file_path)[1] or ".mp3"
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp_path = tmp.name
            
        logger.info(f"Downloading file to {tmp_path}")
        await bot.download_file(file.file_path, tmp_path)
        
        await callback.message.edit_text(f"⏳ Модель: {model_key}\n\n1. ✅ Файл загружен\n2. 🔄 Отправка в MVSEP...")
        
        vocals, instrumental, info = await separate_audio(tmp_path, model_key=model_key)
        
        await callback.message.edit_text(f"⏳ Модель: {model_key}\n\n1. ✅ Файл загружен\n2. ✅ Обработано в cloud\n3. 🔄 Отправка вам...")
        
        if vocals and os.path.exists(vocals):
            await bot.send_audio(callback.from_user.id, types.FSInputFile(vocals), caption=f"🎤 Вокал (модель: {model_key})")
        if instrumental and os.path.exists(instrumental):
            await bot.send_audio(callback.from_user.id, types.FSInputFile(instrumental), caption=f"🎸 Инструментал (модель: {model_key})")
                
        await callback.message.delete()
    except Exception as e:
        import traceback
        err_detail = str(e)
        logger.error(f"UVR Error: {traceback.format_exc()}")
        await callback.message.edit_text(
            f"❌ Ошибка UVR:\n\n`{err_detail}`\n\n"
            f"Модель: {model_key}\n"
            f"Проверьте настройки API или попробуйте позже.", 
            parse_mode="Markdown"
        )
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try: os.remove(tmp_path)
            except: pass
        await state.clear()

# ══════════════════════════════════════════════════════════════════════════════
# ОБРАБОТКА ЖАЛОБ
# ══════════════════════════════════════════════════════════════════════════════

@router.message(ComplaintStates.waiting_complaint, F.text)
async def handle_complaint_text(message: Message, state: FSMContext):
    text = message.text.strip()
    if len(text) < 10:
        await message.answer("✏️ Опишите проблему подробнее (минимум 10 символов).")
        return

    wait_msg = await message.answer("🤖 Анализирую...")
    try:
        result = await analyze_complaint(text)
        if not result or not result.get("relevant", True):
            await wait_msg.edit_text("🤔 Это не похоже на городскую проблему. Опишите конкретнее.")
            return

        category = result.get("category", "Прочее")
        address = result.get("address")
        summary = result.get("summary", text[:150])
        lat, lon = None, None

        if address:
            coords = await get_coordinates(address)
            if coords and isinstance(coords, tuple) and len(coords) >= 2:
                lat, lon = coords[0], coords[1]
            elif coords and isinstance(coords, dict):
                lat, lon = coords.get("lat"), coords.get("lon")

        await state.update_data(
            category=category, address=address, description=text,
            title=summary, lat=lat, lon=lon
        )
        await state.set_state(ComplaintStates.confirming)

        response = (
            f"🤖 *AI анализ*\n\n"
            f"{EMOJI.get(category, '❔')} Категория: *{category}*\n"
            f"📍 Адрес: {address or 'не определён'}\n"
            f"📝 {summary[:300]}\n\n"
            "Подтвердите отправку:"
        )
        
        buttons = [[InlineKeyboardButton(text="✅ Подтвердить", callback_data="confirm")],
                   [InlineKeyboardButton(text="❌ Отмена", callback_data="cancel")]]
        await wait_msg.edit_text(response, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons))
    except Exception as e:
        logger.error(f"Complaint error: {e}")
        await wait_msg.edit_text(f"❌ Ошибка: {e}")

@router.callback_query(ComplaintStates.confirming, F.data == "confirm")
async def process_confirm(callback: CallbackQuery, state: FSMContext):
    data = await state.get_data()
    await callback.message.edit_text("⏳ Сохраняю жалобу...")
    
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.telegram_id == callback.from_user.id).first()
        if not user:
            user = User(telegram_id=callback.from_user.id, username=callback.from_user.username)
            db.add(user); db.commit(); db.refresh(user)
            
        report = Report(user_id=user.id, title=data.get("title"), description=data.get("description"),
                        category=data.get("category"), address=data.get("address"),
                        lat=data.get("lat"), lng=data.get("lon"), status="open")
        db.add(report); db.commit(); db.refresh(report)
        
        try:
            await supabase_push_complaint({
                "id": report.id, "title": report.title, "description": report.description,
                "category": report.category, "address": report.address, "status": "open",
                "lat": report.lat, "lng": report.lng, "source": "bot",
                "created_at": datetime.now(timezone.utc).isoformat()
            })
        except: pass

        await callback.message.edit_text(f"✅ Жалоба принята!\n\nНомер: #NRV{report.id}")
    except Exception as e:
        await callback.message.edit_text(f"❌ Ошибка: {e}")
    finally:
        db.close(); await state.clear()

# ══════════════════════════════════════════════════════════════════════════════
# АДМИН-ПАНЕЛЬ
# ══════════════════════════════════════════════════════════════════════════════
@router.message(F.text == "🔐 Админ-панель", AdminFilter())
@router.message(Command("admin"), AdminFilter())
async def cmd_admin(message: Message):
    logger.info(f"Admin Panel request from user {message.from_user.id}")
    wait = await message.answer("⏳ Загрузка статистики...")
    
    from services.admin_panel import get_stats, format_stats_message, get_realtime_stats
    db = SessionLocal()
    try:
        stats = get_stats(db)
        logger.debug("Local stats gathered")
        
        r_stats = await get_realtime_stats()
        logger.debug("Realtime stats gathered")
        
        text = format_stats_message(stats, r_stats)
        text = text.replace("*", "").replace("_", "").replace("`", "")
        
        await wait.edit_text(
            f"🔐 Админ-панель\n\n{text}", 
            reply_markup=admin_kb(message.from_user.id)
        )
    except Exception as e:
        logger.error(f"Error in cmd_admin: {e}")
        await wait.edit_text(f"🔐 Админ-панель (ошибка данных)\n\nПроизошла ошибка: {e}", 
                           reply_markup=admin_kb(message.from_user.id))
    finally:
        db.close()

@router.message(F.text == "📊 Полная статистика", AdminFilter())
async def cmd_admin_stats(message: Message):
    # Псевдоним для /admin для кнопок
    await cmd_admin(message)

@router.message(F.text == "🎵 Vocal Remover (UVR)", AdminFilter())
@router.message(Command("uvr"), AdminFilter())
async def cmd_uvr_btn(message: Message, state: FSMContext):
    # Calling the actual command
    await cmd_uvr(message, state)

@router.message(F.text == "✂️ Sound Separator", AdminFilter())
async def cmd_separator_btn(message: Message, state: FSMContext):
    # For now sound separator use the same UVR logic but we can distinguish later
    await cmd_uvr(message, state)

@router.message(F.text == "🏠 Главное меню")
async def cmd_back_to_main(message: Message):
    await message.answer("🏠 Возвращаемся в главное меню.", reply_markup=main_kb(message.from_user.id))

@router.message(F.text == "🔄 Синхронизировать с Supabase", AdminFilter())
@router.message(Command("sync_db"), AdminFilter())
async def cmd_sync_db(message: Message):
    wait = await message.answer("🔄 Начинаю синхронизацию локальной базы с Supabase (Postgres)...")
    db = SessionLocal()
    try:
        reports = db.query(Report).all()
        count = 0
        for r in reports:
            success = await supabase_push_complaint({
                "id": r.id, "title": r.title, "description": r.description,
                "category": r.category, "address": r.address, "status": r.status,
                "lat": r.lat, "lng": r.lng, "source": r.source,
                "created_at": r.created_at.isoformat() if r.created_at else datetime.now(timezone.utc).isoformat()
            })
            if success: count += 1
        await wait.edit_text(f"✅ Синхронизация завершена! Обработано записей: {count}")
    finally:
        db.close()

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════════════════════
async def main():
    dp.include_router(router)
    # Пожалуй, стоит добавить команды в меню
    commands = [
        BotCommand(command="start", description="Запустить бота"),
        BotCommand(command="new", description="Новая жалоба"),
        BotCommand(command="map", description="Карта проблем"),
        BotCommand(command="info", description="Инфографика"),
        BotCommand(command="profile", description="Профиль"),
    ]
    await bot.set_my_commands(commands, scope=BotCommandScopeDefault())
    
    logger.info("🚀 Ultimate Bot запущен")
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())

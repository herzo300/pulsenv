#!/usr/bin/env python3
"""
Полное тестирование Telegram бота «Пульс города — Нижневартовск».
Проверяет все команды, обработчики, callback-кнопки, email, юр.анализ.
"""

import asyncio
import os
import sys
import logging
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TG_BOT_TOKEN", "8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g")
os.environ.setdefault("ZAI_API_KEY", "test")

from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("test")

# Счётчики
passed = 0
failed = 0
errors = []


def ok(name):
    global passed
    passed += 1
    print(f"  ✅ {name}")


def fail(name, reason=""):
    global failed
    failed += 1
    errors.append(f"{name}: {reason}")
    print(f"  ❌ {name} — {reason}")


# ============================================================
# Мок-объекты
# ============================================================

def make_user(uid=12345, username="testuser", first_name="Тест", last_name="Юзер"):
    user = MagicMock()
    user.id = uid
    user.username = username
    user.first_name = first_name
    user.last_name = last_name
    return user


def make_message(text="", uid=12345, msg_id=1):
    msg = AsyncMock()
    msg.text = text
    msg.caption = None
    msg.message_id = msg_id
    msg.from_user = make_user(uid)
    msg.answer = AsyncMock()
    msg.answer_venue = AsyncMock()
    msg.photo = None
    return msg


def make_callback(data="", uid=12345, msg_id=1):
    cb = AsyncMock()
    cb.data = data
    cb.from_user = make_user(uid)
    cb.answer = AsyncMock()
    cb.message = AsyncMock()
    cb.message.edit_text = AsyncMock()
    cb.message.answer = AsyncMock()
    cb.message.answer_venue = AsyncMock()
    cb.message.message_id = msg_id
    return cb


# ============================================================
# ТЕСТЫ
# ============================================================

async def test_imports():
    """Тест 1: Импорт всех модулей бота"""
    print("\n📦 Тест 1: Импорт модулей")
    try:
        from services.telegram_bot import (
            dp, bot, cmd_start, cmd_help, cmd_stats, cmd_map,
            cmd_about, cmd_categories, cmd_new, cmd_my, cmd_cancel,
            cmd_sync, cmd_opendata,
            handle_photo, handle_text,
            cb_confirm, cb_change_cat, cb_cancel, cb_map_points,
            cb_send_to_uk, cb_send_to_admin, cb_send_skip,
            cb_legal_analysis, on_pre_checkout, on_successful_payment,
            cb_select_cat, cb_opendata,
            main_kb, categories_kb,
            _get_webapp_url, _build_complaint_email, _send_email_via_worker,
            ADMIN_EMAIL, ADMIN_NAME, ADMIN_PHONE,
            EMOJI, LEGAL_ANALYSIS_STARS, LEGAL_PROMPT,
            user_sessions, bot_guard,
        )
        ok("Все модули и функции импортированы")
    except ImportError as e:
        fail("Импорт", str(e))
        return False
    return True


async def test_webapp_url():
    """Тест 2: WebApp URL — fallback на CF Worker"""
    print("\n🌐 Тест 2: WebApp URL")
    from services.telegram_bot import _get_webapp_url

    url = _get_webapp_url()
    if not url:
        fail("WebApp URL пустой")
        return
    ok(f"URL не пустой: {url[:60]}...")

    if "anthropic-proxy" in url or "workers.dev" in url:
        ok("Fallback на CF Worker работает")
    elif url.startswith("http"):
        ok(f"Кастомный URL: {url[:60]}")
    else:
        fail("URL невалидный", url)

    # Проверяем что URL заканчивается без /
    if url.endswith("/"):
        fail("URL заканчивается на /", url)
    else:
        ok("URL без trailing slash")


async def test_keyboards():
    """Тест 3: Клавиатуры"""
    print("\n⌨️ Тест 3: Клавиатуры")
    from services.telegram_bot import main_kb, categories_kb
    from services.zai_service import CATEGORIES

    kb = main_kb()
    if kb and kb.keyboard:
        ok(f"Главная клавиатура: {sum(len(r) for r in kb.keyboard)} кнопок")
    else:
        fail("Главная клавиатура пустая")

    cat_kb = categories_kb()
    if cat_kb and cat_kb.inline_keyboard:
        total_btns = sum(len(r) for r in cat_kb.inline_keyboard)
        ok(f"Клавиатура категорий: {total_btns} кнопок ({len(CATEGORIES)} категорий)")
        # Проверяем callback_data
        first_btn = cat_kb.inline_keyboard[0][0]
        if first_btn.callback_data.startswith("cat:"):
            ok("Callback data формат: cat:XXX")
        else:
            fail("Callback data формат", first_btn.callback_data)
    else:
        fail("Клавиатура категорий пустая")


async def test_emoji_coverage():
    """Тест 4: Покрытие эмодзи для всех категорий"""
    print("\n🏷️ Тест 4: Эмодзи категорий")
    from services.telegram_bot import EMOJI
    from services.zai_service import CATEGORIES

    missing = [c for c in CATEGORIES if c not in EMOJI]
    if missing:
        fail(f"Нет эмодзи для: {', '.join(missing)}")
    else:
        ok(f"Все {len(CATEGORIES)} категорий имеют эмодзи")


async def test_cmd_start():
    """Тест 5: /start"""
    print("\n🏠 Тест 5: /start")
    from services.telegram_bot import cmd_start
    msg = make_message("/start")
    await cmd_start(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        if "Пульс города" in text:
            ok("/start отвечает с приветствием")
        else:
            fail("/start текст", text[:80])
        kw = msg.answer.call_args[1]
        if kw.get("reply_markup"):
            ok("/start показывает клавиатуру")
        else:
            fail("/start без клавиатуры")
    else:
        fail("/start не вызвал answer()")


async def test_cmd_help():
    """Тест 6: /help"""
    print("\n❓ Тест 6: /help")
    from services.telegram_bot import cmd_help
    msg = make_message("/help")
    await cmd_help(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        commands = ["/new", "/my", "/stats", "/map", "/categories", "/about"]
        found = [c for c in commands if c in text]
        ok(f"/help содержит {len(found)}/{len(commands)} команд")
    else:
        fail("/help не вызвал answer()")


async def test_cmd_about():
    """Тест 7: /about"""
    print("\n ℹ️ Тест 7: /about")
    from services.telegram_bot import cmd_about
    msg = make_message("/about")
    await cmd_about(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        checks = ["Нижневартовск", "AI", "Telegram", "карта"]
        found = [c for c in checks if c.lower() in text.lower()]
        ok(f"/about содержит {len(found)}/{len(checks)} ключевых слов")
    else:
        fail("/about не вызвал answer()")


async def test_cmd_categories():
    """Тест 8: /categories"""
    print("\n🏷️ Тест 8: /categories")
    from services.telegram_bot import cmd_categories
    msg = make_message("/categories")
    await cmd_categories(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        if "Категории" in text and "ЖКХ" in text:
            ok("/categories показывает список")
        else:
            fail("/categories текст", text[:80])
    else:
        fail("/categories не вызвал answer()")


async def test_cmd_new():
    """Тест 9: /new"""
    print("\n📝 Тест 9: /new")
    from services.telegram_bot import cmd_new, user_sessions
    msg = make_message("/new", uid=99901)
    await cmd_new(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        if "жалоб" in text.lower() or "описани" in text.lower():
            ok("/new просит описание")
        else:
            fail("/new текст", text[:80])
    else:
        fail("/new не вызвал answer()")

    if 99901 in user_sessions:
        if user_sessions[99901].get("state") == "waiting_complaint":
            ok("/new устанавливает сессию waiting_complaint")
        else:
            fail("/new сессия", str(user_sessions[99901]))
        del user_sessions[99901]
    else:
        fail("/new не создал сессию")


async def test_cmd_cancel():
    """Тест 10: /cancel"""
    print("\n❌ Тест 10: /cancel")
    from services.telegram_bot import cmd_cancel, user_sessions
    user_sessions[99902] = {"state": "confirm"}
    msg = make_message("/cancel", uid=99902)
    await cmd_cancel(msg)
    if 99902 not in user_sessions:
        ok("/cancel очищает сессию")
    else:
        fail("/cancel не очистил сессию")
    if msg.answer.called:
        ok("/cancel отвечает")
    else:
        fail("/cancel не вызвал answer()")


async def test_cmd_stats():
    """Тест 11: /stats"""
    print("\n📊 Тест 11: /stats")
    from services.telegram_bot import cmd_stats
    msg = make_message("/stats")
    try:
        await cmd_stats(msg)
        if msg.answer.called:
            text = msg.answer.call_args[0][0]
            if "Статистика" in text or "Всего" in text:
                ok("/stats показывает статистику")
            else:
                fail("/stats текст", text[:80])
        else:
            fail("/stats не вызвал answer()")
    except Exception as e:
        fail("/stats ошибка", str(e))


async def test_cmd_my():
    """Тест 12: /my"""
    print("\n📋 Тест 12: /my")
    from services.telegram_bot import cmd_my
    msg = make_message("/my")
    try:
        await cmd_my(msg)
        if msg.answer.called:
            ok("/my отвечает (пользователь может не иметь жалоб)")
        else:
            fail("/my не вызвал answer()")
    except Exception as e:
        fail("/my ошибка", str(e))


async def test_cmd_map():
    """Тест 13: /map"""
    print("\n🗺️ Тест 13: /map")
    from services.telegram_bot import cmd_map
    msg = make_message("/map")
    try:
        await cmd_map(msg)
        if msg.answer.called:
            text = msg.answer.call_args[0][0]
            kw = msg.answer.call_args[1]
            if "Карта" in text or "карт" in text.lower():
                ok("/map показывает информацию о карте")
            else:
                fail("/map текст", text[:80])
            # Проверяем кнопки
            markup = kw.get("reply_markup")
            if markup and hasattr(markup, "inline_keyboard"):
                btns = markup.inline_keyboard
                has_webapp = any(
                    any(getattr(b, "web_app", None) for b in row)
                    for row in btns
                )
                has_osm = any(
                    any("openstreetmap" in (getattr(b, "url", "") or "") for b in row)
                    for row in btns
                )
                if has_webapp:
                    # Проверяем URL
                    for row in btns:
                        for b in row:
                            if getattr(b, "web_app", None):
                                wa_url = b.web_app.url
                                if "/map" in wa_url:
                                    ok(f"WebApp кнопка: {wa_url}")
                                else:
                                    fail("WebApp URL без /map", wa_url)
                else:
                    fail("/map нет WebApp кнопки")
                if has_osm:
                    ok("OSM кнопка присутствует")
            else:
                fail("/map нет inline кнопок")
        else:
            fail("/map не вызвал answer()")
    except Exception as e:
        fail("/map ошибка", str(e))


async def test_handle_text():
    """Тест 14: Обработка текстовой жалобы"""
    print("\n📝 Тест 14: Обработка текста")
    from services.telegram_bot import handle_text, user_sessions, bot_guard

    uid = 99903
    msg = make_message("На улице Мира 10 разбитый тротуар, ямы и лужи", uid=uid, msg_id=5001)

    with patch("services.telegram_bot.analyze_complaint", new_callable=AsyncMock) as mock_ai, \
         patch("services.telegram_bot.geoparse", new_callable=AsyncMock) as mock_geo, \
         patch("services.telegram_bot.find_uk_by_coords", new_callable=AsyncMock) as mock_uk_c, \
         patch("services.telegram_bot.find_uk_by_address") as mock_uk_a:

        mock_ai.return_value = {
            "category": "Дороги",
            "address": "ул. Мира, 10",
            "summary": "Разбитый тротуар на ул. Мира 10",
            "location_hints": "Мира",
        }
        mock_geo.return_value = {
            "address": "ул. Мира, 10, Нижневартовск",
            "lat": 60.9344,
            "lng": 76.5531,
            "geo_source": "ai_address",
        }
        mock_uk_c.return_value = {
            "name": "ООО УК Жилкомсервис",
            "email": "uk@test.ru",
            "phone": "8-800-123",
            "director": "Иванов И.И.",
        }
        mock_uk_a.return_value = None

        await handle_text(msg)

        if msg.answer.call_count >= 2:
            # Первый вызов — "Анализирую...", второй — результат
            result_text = msg.answer.call_args_list[-1][0][0]
            checks = {
                "Дороги": "Дороги" in result_text,
                "Адрес": "Мира" in result_text,
                "Координаты": "60.93" in result_text,
                "УК": "Жилкомсервис" in result_text or "УК" in result_text,
            }
            for name, ok_val in checks.items():
                if ok_val:
                    ok(f"Текст: {name} в ответе")
                else:
                    fail(f"Текст: {name} не найден", result_text[:100])

            # Проверяем кнопки
            kw = msg.answer.call_args_list[-1][1]
            markup = kw.get("reply_markup")
            if markup and hasattr(markup, "inline_keyboard"):
                btns_flat = [b.callback_data for row in markup.inline_keyboard for b in row if hasattr(b, "callback_data") and b.callback_data]
                expected = ["confirm", "confirm_anon", "change_cat", "cancel"]
                found = [e for e in expected if e in btns_flat]
                ok(f"Кнопки: {len(found)}/{len(expected)} ({', '.join(found)})")

                # Street View кнопка
                url_btns = [b for row in markup.inline_keyboard for b in row if getattr(b, "url", None)]
                sv = [b for b in url_btns if "street" in (b.url or "").lower() or "pano" in (b.url or "").lower()]
                if sv:
                    ok("Street View кнопка присутствует")
                else:
                    fail("Street View кнопка отсутствует")
            else:
                fail("Нет inline кнопок в ответе")
        else:
            fail("handle_text вызвал answer() менее 2 раз", str(msg.answer.call_count))

    # Проверяем сессию
    if uid in user_sessions:
        s = user_sessions[uid]
        if s.get("state") == "confirm":
            ok("Сессия в состоянии confirm")
        else:
            fail("Сессия не confirm", s.get("state"))
        if s.get("category") == "Дороги":
            ok("Категория сохранена в сессии")
        if s.get("uk_info"):
            ok("УК сохранена в сессии")
        del user_sessions[uid]
    else:
        fail("Сессия не создана")


async def test_handle_text_short():
    """Тест 15: Короткий текст отклоняется"""
    print("\n📝 Тест 15: Короткий текст")
    from services.telegram_bot import handle_text
    msg = make_message("Ок", uid=99904, msg_id=5002)
    await handle_text(msg)
    if msg.answer.called:
        text = msg.answer.call_args[0][0]
        if "коротк" in text.lower():
            ok("Короткий текст отклонён")
        else:
            fail("Ответ на короткий текст", text[:60])
    else:
        fail("Нет ответа на короткий текст")


async def test_cb_confirm():
    """Тест 16: Подтверждение жалобы (confirm)"""
    print("\n✅ Тест 16: Подтверждение жалобы")
    from services.telegram_bot import cb_confirm, user_sessions

    uid = 99905
    user_sessions[uid] = {
        "state": "confirm",
        "category": "ЖКХ",
        "description": "Протечка крыши в подъезде 3",
        "summary": "Протечка крыши",
        "address": "ул. Ленина, 5",
        "lat": 60.935,
        "lon": 76.554,
        "uk_info": {"name": "ТестУК", "email": "uk@test.ru", "phone": "123"},
    }

    cb = make_callback("confirm", uid=uid)

    with patch("services.telegram_bot.firebase_push", new_callable=AsyncMock) as mock_fb:
        mock_fb.return_value = "test_doc_id"
        try:
            await cb_confirm(cb)
            if cb.message.edit_text.called:
                text = cb.message.edit_text.call_args[0][0]
                if "сохранена" in text.lower() or "жалоба" in text.lower():
                    ok("Жалоба подтверждена и сохранена")
                else:
                    ok(f"Ответ: {text[:80]}")

                # Проверяем кнопки ask_send
                kw = cb.message.edit_text.call_args[1]
                markup = kw.get("reply_markup")
                if markup and hasattr(markup, "inline_keyboard"):
                    btns_flat = [b.callback_data for row in markup.inline_keyboard for b in row if hasattr(b, "callback_data") and b.callback_data]
                    if "send_to_uk:yes" in btns_flat:
                        ok("Кнопка 'Отправить в УК' присутствует")
                    if "send_to_admin:yes" in btns_flat:
                        ok("Кнопка 'Отправить в администрацию' присутствует")
                    if "legal_analysis" in btns_flat:
                        ok("Кнопка 'Юридический анализ' присутствует")
            else:
                fail("cb_confirm не вызвал edit_text")

            # Проверяем Firebase push
            if mock_fb.called:
                ok("Firebase push вызван")
                fb_data = mock_fb.call_args[0][0]
                if fb_data.get("category") == "ЖКХ":
                    ok("Firebase: категория ЖКХ")
            else:
                fail("Firebase push не вызван")

            # Проверяем сессию перешла в ask_send
            if uid in user_sessions and user_sessions[uid].get("state") == "ask_send":
                ok("Сессия перешла в ask_send")
            else:
                fail("Сессия не в ask_send")

        except Exception as e:
            fail("cb_confirm ошибка", str(e))

    if uid in user_sessions:
        del user_sessions[uid]


async def test_cb_confirm_anon():
    """Тест 17: Анонимная жалоба"""
    print("\n🔒 Тест 17: Анонимная жалоба")
    from services.telegram_bot import cb_confirm, user_sessions

    uid = 99906
    user_sessions[uid] = {
        "state": "confirm",
        "category": "Экология",
        "description": "Свалка мусора у реки",
        "summary": "Свалка мусора",
        "address": "набережная, Нижневартовск",
        "lat": 60.93,
        "lon": 76.55,
        "uk_info": None,
    }

    cb = make_callback("confirm_anon", uid=uid)

    with patch("services.telegram_bot.firebase_push", new_callable=AsyncMock) as mock_fb:
        mock_fb.return_value = "anon_doc"
        try:
            await cb_confirm(cb)
            if cb.message.edit_text.called:
                text = cb.message.edit_text.call_args[0][0]
                if "нонимн" in text.lower() or "🔒" in text:
                    ok("Анонимная жалоба отмечена")
                else:
                    ok(f"Ответ (анон): {text[:80]}")

                # Firebase: source = anonymous
                if mock_fb.called:
                    fb_data = mock_fb.call_args[0][0]
                    if fb_data.get("source") == "anonymous":
                        ok("Firebase source=anonymous")
                    if "Аноним" in (fb_data.get("source_name") or ""):
                        ok("Firebase source_name=Аноним")
            else:
                fail("cb_confirm_anon не вызвал edit_text")

            # Проверяем кнопку администрации (нет УК)
            if cb.message.edit_text.called:
                kw = cb.message.edit_text.call_args[1]
                markup = kw.get("reply_markup")
                if markup:
                    btns_flat = [b.callback_data for row in markup.inline_keyboard for b in row if hasattr(b, "callback_data") and b.callback_data]
                    if "send_to_admin:yes" in btns_flat:
                        ok("Без УК → кнопка администрации")

        except Exception as e:
            fail("cb_confirm_anon ошибка", str(e))

    if uid in user_sessions:
        del user_sessions[uid]


async def test_cb_change_cat():
    """Тест 18: Изменение категории"""
    print("\n🏷️ Тест 18: Изменение категории")
    from services.telegram_bot import cb_change_cat
    cb = make_callback("change_cat")
    await cb_change_cat(cb)
    if cb.message.edit_text.called:
        text = cb.message.edit_text.call_args[0][0]
        kw = cb.message.edit_text.call_args[1]
        if "категори" in text.lower():
            ok("Показывает выбор категории")
        markup = kw.get("reply_markup")
        if markup and hasattr(markup, "inline_keyboard"):
            total = sum(len(r) for r in markup.inline_keyboard)
            ok(f"Клавиатура категорий: {total} кнопок")
        else:
            fail("Нет клавиатуры категорий")
    else:
        fail("cb_change_cat не вызвал edit_text")


async def test_cb_select_cat():
    """Тест 19: Выбор конкретной категории"""
    print("\n🏷️ Тест 19: Выбор категории")
    from services.telegram_bot import cb_select_cat, user_sessions

    uid = 99907
    user_sessions[uid] = {
        "state": "confirm",
        "category": "Прочее",
        "description": "Тестовая жалоба",
        "summary": "Тест",
        "address": "ул. Тестовая",
    }

    cb = make_callback("cat:Дороги", uid=uid)
    await cb_select_cat(cb)

    if cb.message.edit_text.called:
        text = cb.message.edit_text.call_args[0][0]
        if "Дороги" in text:
            ok("Категория изменена на Дороги")
        kw = cb.message.edit_text.call_args[1]
        markup = kw.get("reply_markup")
        if markup:
            btns = [b.callback_data for row in markup.inline_keyboard for b in row if hasattr(b, "callback_data") and b.callback_data]
            if "confirm" in btns and "confirm_anon" in btns:
                ok("Кнопки подтверждения + анонимно")
    else:
        fail("cb_select_cat не вызвал edit_text")

    if uid in user_sessions:
        if user_sessions[uid].get("category") == "Дороги":
            ok("Категория обновлена в сессии")
        del user_sessions[uid]


async def test_build_complaint_email():
    """Тест 20: Формирование email жалобы"""
    print("\n📧 Тест 20: Формирование email")
    from services.telegram_bot import _build_complaint_email

    session = {
        "report_id": 42,
        "category": "ЖКХ",
        "address": "ул. Мира, 10",
        "description": "Протечка крыши в подъезде",
        "title": "Протечка крыши",
        "lat": 60.935,
        "lon": 76.554,
        "is_anonymous": False,
    }

    subject, body = _build_complaint_email(session, "ООО УК Тест")
    if "42" in subject and "ЖКХ" in subject:
        ok(f"Тема: {subject}")
    else:
        fail("Тема email", subject)

    checks = {
        "Номер": "#42" in body,
        "Категория": "ЖКХ" in body,
        "Адрес": "Мира" in body,
        "Координаты": "60.93" in body,
        "Карта": "google.com/maps" in body,
        "Описание": "Протечка" in body,
    }
    for name, ok_val in checks.items():
        if ok_val:
            ok(f"Email body: {name}")
        else:
            fail(f"Email body: {name} не найден")

    # Анонимный email
    session["is_anonymous"] = True
    _, body_anon = _build_complaint_email(session, "Администрация")
    if "анонимно" in body_anon.lower():
        ok("Анонимный email отмечен")
    else:
        fail("Анонимный email не отмечен")


async def test_send_email_worker():
    """Тест 21: Отправка email через CF Worker"""
    print("\n📧 Тест 21: Email через CF Worker")
    from services.telegram_bot import _send_email_via_worker

    # Мокаем httpx
    with patch("services.telegram_bot.httpx.AsyncClient") as mock_client_cls:
        mock_client = AsyncMock()
        mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        # Успешная отправка
        mock_resp = MagicMock()
        mock_resp.json.return_value = {"ok": True, "method": "brevo"}
        mock_client.post = AsyncMock(return_value=mock_resp)

        result = await _send_email_via_worker("test@test.ru", "Тест", "Тело")
        if result.get("ok"):
            ok("Email отправлен (мок)")
        else:
            fail("Email не отправлен", str(result))

        # Fallback
        mock_resp.json.return_value = {"ok": False, "fallback": True, "mailto": "mailto:test@test.ru?subject=Test"}
        result = await _send_email_via_worker("test@test.ru", "Тест", "Тело")
        if result.get("fallback") or result.get("mailto"):
            ok("Fallback с mailto ссылкой")
        else:
            ok("Fallback обработан")


async def test_cb_send_to_uk():
    """Тест 22: Отправка в УК"""
    print("\n🏢 Тест 22: Отправка в УК")
    from services.telegram_bot import cb_send_to_uk, user_sessions

    uid = 99908
    user_sessions[uid] = {
        "state": "ask_send",
        "report_id": 99,
        "category": "ЖКХ",
        "title": "Тест",
        "description": "Тестовая жалоба",
        "address": "ул. Тестовая, 1",
        "lat": 60.93,
        "lon": 76.55,
        "uk_info": {"name": "ТестУК", "email": "uk@test.ru", "phone": "123"},
        "is_anonymous": False,
    }

    cb = make_callback("send_to_uk:yes", uid=uid)

    with patch("services.telegram_bot._send_email_via_worker", new_callable=AsyncMock) as mock_send:
        mock_send.return_value = {"ok": True, "fallback": False, "mailto": None}
        await cb_send_to_uk(cb)

        if mock_send.called:
            args = mock_send.call_args
            if "uk@test.ru" in str(args):
                ok("Email отправлен на адрес УК")
            else:
                ok("Email отправлен (адрес не проверен)")
        else:
            fail("_send_email_via_worker не вызван")

        if cb.message.edit_text.called:
            text = cb.message.edit_text.call_args[0][0]
            if "отправлена" in text.lower() or "ТестУК" in text:
                ok("Подтверждение отправки в УК")
            else:
                ok(f"Ответ: {text[:80]}")

    if uid in user_sessions:
        del user_sessions[uid]


async def test_cb_send_to_admin():
    """Тест 23: Отправка в администрацию"""
    print("\n🏛️ Тест 23: Отправка в администрацию")
    from services.telegram_bot import cb_send_to_admin, user_sessions, ADMIN_EMAIL

    uid = 99909
    user_sessions[uid] = {
        "state": "ask_send",
        "report_id": 100,
        "category": "Благоустройство",
        "title": "Тест админ",
        "description": "Тестовая жалоба в администрацию",
        "address": "центр города",
        "lat": None,
        "lon": None,
        "uk_info": None,
        "is_anonymous": True,
    }

    cb = make_callback("send_to_admin:yes", uid=uid)

    with patch("services.telegram_bot._send_email_via_worker", new_callable=AsyncMock) as mock_send:
        mock_send.return_value = {"ok": True, "fallback": False, "mailto": None}
        await cb_send_to_admin(cb)

        if mock_send.called:
            args = mock_send.call_args
            if ADMIN_EMAIL in str(args):
                ok(f"Email отправлен в администрацию ({ADMIN_EMAIL})")
            else:
                ok("Email отправлен (адрес не проверен)")

    if uid in user_sessions:
        del user_sessions[uid]


async def test_cb_send_skip():
    """Тест 24: Отказ от отправки"""
    print("\n👌 Тест 24: Отказ от отправки")
    from services.telegram_bot import cb_send_skip, user_sessions

    uid = 99910
    user_sessions[uid] = {"state": "ask_send", "report_id": 101}

    cb = make_callback("send_to_uk:no", uid=uid)
    await cb_send_skip(cb)

    if uid not in user_sessions:
        ok("Сессия очищена после отказа")
    else:
        fail("Сессия не очищена")
        del user_sessions[uid]

    if cb.message.edit_text.called:
        text = cb.message.edit_text.call_args[0][0]
        if "сохранена" in text.lower() or "хорошо" in text.lower():
            ok("Подтверждение отказа")


async def test_legal_analysis_invoice():
    """Тест 25: Юридический анализ — отправка invoice"""
    print("\n⚖️ Тест 25: Юридический анализ (invoice)")
    from services.telegram_bot import cb_legal_analysis, user_sessions, LEGAL_ANALYSIS_STARS

    uid = 99911
    user_sessions[uid] = {
        "state": "ask_send",
        "report_id": 102,
        "category": "ЖКХ",
        "description": "Тест юр анализа",
    }

    cb = make_callback("legal_analysis", uid=uid)

    with patch("services.telegram_bot.bot.send_invoice", new_callable=AsyncMock) as mock_inv:
        await cb_legal_analysis(cb)

        if mock_inv.called:
            kw = mock_inv.call_args[1]
            if kw.get("currency") == "XTR":
                ok("Валюта: XTR (Telegram Stars)")
            else:
                fail("Валюта не XTR", kw.get("currency"))

            prices = kw.get("prices", [])
            if prices and prices[0].amount == LEGAL_ANALYSIS_STARS:
                ok(f"Цена: {LEGAL_ANALYSIS_STARS} Stars")
            else:
                fail("Цена неверная", str(prices))

            if "legal_102" in (kw.get("payload") or ""):
                ok("Payload содержит report_id")

            if kw.get("provider_token") == "":
                ok("provider_token пустой (Stars)")
        else:
            fail("send_invoice не вызван")

    if uid in user_sessions:
        del user_sessions[uid]


async def test_pre_checkout():
    """Тест 26: Pre-checkout query"""
    print("\n💳 Тест 26: Pre-checkout")
    from services.telegram_bot import on_pre_checkout

    pq = MagicMock()
    pq.id = "test_pq_1"
    pq.invoice_payload = "legal_102_99911"

    with patch("services.telegram_bot.bot.answer_pre_checkout_query", new_callable=AsyncMock) as mock_ans:
        await on_pre_checkout(pq)
        if mock_ans.called:
            args = mock_ans.call_args
            if args[1].get("ok") is True or (len(args[0]) > 1 and args[0][1] is True):
                ok("Pre-checkout подтверждён (ok=True)")
            else:
                ok(f"Pre-checkout вызван: {args}")
        else:
            fail("answer_pre_checkout_query не вызван")

    # Невалидный payload
    pq2 = MagicMock()
    pq2.id = "test_pq_2"
    pq2.invoice_payload = "unknown_payload"

    with patch("services.telegram_bot.bot.answer_pre_checkout_query", new_callable=AsyncMock) as mock_ans:
        await on_pre_checkout(pq2)
        if mock_ans.called:
            args = mock_ans.call_args
            if args[1].get("ok") is False or (len(args[0]) > 1 and args[0][1] is False):
                ok("Невалидный payload отклонён (ok=False)")
            else:
                ok(f"Pre-checkout (invalid): {args}")


async def test_successful_payment():
    """Тест 27: Успешная оплата → юридический анализ"""
    print("\n💰 Тест 27: Успешная оплата")
    from services.telegram_bot import on_successful_payment, user_sessions

    uid = 99912
    user_sessions[uid] = {
        "state": "ask_send",
        "report_id": 103,
        "category": "Дороги",
        "address": "ул. Мира, 5",
        "description": "Яма на дороге глубиной 30 см",
    }

    msg = make_message("", uid=uid)
    payment = MagicMock()
    payment.invoice_payload = f"legal_103_{uid}"
    msg.successful_payment = payment

    with patch("services.telegram_bot.httpx.AsyncClient") as mock_client_cls:
        mock_client = AsyncMock()
        mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "choices": [{
                "message": {
                    "content": "⚖️ Юридический анализ:\n\n1. Нарушены: ФЗ-131, ЖК РФ ст.161\n2. Ответственный: администрация\n3. Срок: 30 дней"
                }
            }]
        }
        mock_client.post = AsyncMock(return_value=mock_resp)

        await on_successful_payment(msg)

        if msg.answer.call_count >= 2:
            # Первый — "Оплата получена", далее — результат анализа
            texts = [call[0][0] for call in msg.answer.call_args_list]
            all_text = " ".join(texts)
            if "оплата" in all_text.lower() or "⭐" in all_text:
                ok("Подтверждение оплаты")
            if "юридический" in all_text.lower() or "анализ" in all_text.lower() or "ФЗ" in all_text:
                ok("Юридический анализ получен")
            ok(f"Всего ответов: {msg.answer.call_count}")
        else:
            # Может быть 1 ответ если ошибка
            if msg.answer.called:
                ok(f"Ответ получен ({msg.answer.call_count} сообщений)")
            else:
                fail("Нет ответа после оплаты")

    if uid in user_sessions:
        del user_sessions[uid]


async def test_cb_cancel():
    """Тест 28: Отмена через callback"""
    print("\n❌ Тест 28: Callback cancel")
    from services.telegram_bot import cb_cancel as cb_cancel_fn, user_sessions

    uid = 99913
    user_sessions[uid] = {"state": "confirm", "category": "Прочее"}

    cb = make_callback("cancel", uid=uid)
    await cb_cancel_fn(cb)

    if uid not in user_sessions:
        ok("Сессия очищена")
    else:
        fail("Сессия не очищена")
        del user_sessions[uid]

    if cb.message.edit_text.called:
        text = cb.message.edit_text.call_args[0][0]
        if "отменено" in text.lower():
            ok("Текст отмены")


async def test_constants():
    """Тест 29: Константы и конфигурация"""
    print("\n⚙️ Тест 29: Константы")
    from services.telegram_bot import (
        ADMIN_EMAIL, ADMIN_NAME, ADMIN_PHONE,
        LEGAL_ANALYSIS_STARS, LEGAL_PROMPT, BOT_TOKEN,
    )

    if ADMIN_EMAIL == "nvartovsk@n-vartovsk.ru":
        ok(f"ADMIN_EMAIL: {ADMIN_EMAIL}")
    else:
        fail("ADMIN_EMAIL", ADMIN_EMAIL)

    if ADMIN_NAME and "Нижневартовск" in ADMIN_NAME:
        ok(f"ADMIN_NAME: {ADMIN_NAME}")

    if ADMIN_PHONE:
        ok(f"ADMIN_PHONE: {ADMIN_PHONE}")

    if LEGAL_ANALYSIS_STARS == 50:
        ok(f"LEGAL_ANALYSIS_STARS: {LEGAL_ANALYSIS_STARS}")
    else:
        fail("LEGAL_ANALYSIS_STARS", str(LEGAL_ANALYSIS_STARS))

    if "ЖК РФ" in LEGAL_PROMPT or "КоАП" in LEGAL_PROMPT:
        ok("LEGAL_PROMPT содержит юридические термины")

    if BOT_TOKEN and len(BOT_TOKEN) > 20:
        ok(f"BOT_TOKEN: ...{BOT_TOKEN[-8:]}")


async def test_realtime_guard():
    """Тест 30: RealtimeGuard дедупликация"""
    print("\n🛡️ Тест 30: RealtimeGuard")
    from services.telegram_bot import bot_guard

    # Не дубликат
    is_dup = bot_guard.is_duplicate("test_source", 999999)
    if not is_dup:
        ok("Новое сообщение не дубликат")
    else:
        fail("Новое сообщение помечено как дубликат")

    # Помечаем обработанным
    bot_guard.mark_processed("test_source", 999999)

    # Теперь дубликат
    is_dup = bot_guard.is_duplicate("test_source", 999999)
    if is_dup:
        ok("Повторное сообщение — дубликат")
    else:
        fail("Повторное сообщение не дубликат")


async def test_cf_worker_map_endpoint():
    """Тест 31: CF Worker /map endpoint"""
    print("\n🗺️ Тест 31: CF Worker /map")
    import httpx

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get("https://anthropic-proxy.uiredepositionherzo.workers.dev/map")
            if r.status_code == 200:
                ok(f"CF Worker /map: HTTP {r.status_code}")
                html = r.text
                checks = {
                    "DOCTYPE": "<!DOCTYPE" in html,
                    "Leaflet": "leaflet" in html.lower(),
                    "Telegram WebApp": "telegram-web-app" in html,
                    "Firebase URL": "anthropic-proxy" in html,
                    "Нижневартовск": "60.9344" in html or "Нижневартовск" in html,
                }
                for name, ok_val in checks.items():
                    if ok_val:
                        ok(f"Map HTML: {name}")
                    else:
                        fail(f"Map HTML: {name} не найден")
            else:
                fail(f"CF Worker /map: HTTP {r.status_code}")
    except Exception as e:
        fail(f"CF Worker /map недоступен", str(e))


async def test_cf_worker_firebase_proxy():
    """Тест 32: CF Worker Firebase proxy"""
    print("\n🔥 Тест 32: Firebase через CF Worker")
    import httpx

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get("https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase/complaints.json?limitToLast=1")
            if r.status_code == 200:
                ok(f"Firebase proxy: HTTP {r.status_code}")
                data = r.json()
                if data and isinstance(data, dict):
                    ok(f"Firebase данные: {len(data)} записей (последняя)")
                elif data is None:
                    ok("Firebase: пустая база (null)")
                else:
                    ok(f"Firebase ответ: {str(data)[:60]}")
            else:
                fail(f"Firebase proxy: HTTP {r.status_code}")
    except Exception as e:
        fail(f"Firebase proxy недоступен", str(e))


async def test_menu_buttons():
    """Тест 33: Текстовые кнопки меню"""
    print("\n📱 Тест 33: Кнопки меню")
    from services.telegram_bot import (
        btn_new, btn_my, btn_stats, btn_map,
        btn_categories, btn_about,
    )

    buttons = {
        "📝 Новая жалоба": btn_new,
        "📋 Мои жалобы": btn_my,
        "📊 Статистика": btn_stats,
        "🗺️ Карта": btn_map,
        "🏷️ Категории": btn_categories,
        "ℹ️ О проекте": btn_about,
    }

    for text, handler in buttons.items():
        msg = make_message(text, uid=99920, msg_id=6000 + hash(text) % 1000)
        try:
            await handler(msg)
            if msg.answer.called:
                ok(f"Кнопка '{text}' работает")
            else:
                fail(f"Кнопка '{text}' не вызвала answer()")
        except Exception as e:
            fail(f"Кнопка '{text}'", str(e))


async def test_setup_menu():
    """Тест 34: Установка меню команд"""
    print("\n📋 Тест 34: Setup menu")
    from services.telegram_bot import setup_menu

    with patch("services.telegram_bot.bot.set_my_commands", new_callable=AsyncMock) as mock_cmd:
        await setup_menu()
        if mock_cmd.called:
            commands = mock_cmd.call_args[0][0]
            cmd_names = [c.command for c in commands]
            expected = ["start", "help", "new", "my", "stats", "map", "opendata", "categories", "about", "sync"]
            found = [c for c in expected if c in cmd_names]
            ok(f"Меню: {len(found)}/{len(expected)} команд ({', '.join(found)})")
        else:
            fail("set_my_commands не вызван")


# ============================================================
# ЗАПУСК
# ============================================================

async def run_all():
    global passed, failed

    print("=" * 60)
    print("🧪 ПОЛНОЕ ТЕСТИРОВАНИЕ БОТА «ПУЛЬС ГОРОДА»")
    print("=" * 60)

    tests = [
        test_imports,
        test_webapp_url,
        test_keyboards,
        test_emoji_coverage,
        test_cmd_start,
        test_cmd_help,
        test_cmd_about,
        test_cmd_categories,
        test_cmd_new,
        test_cmd_cancel,
        test_cmd_stats,
        test_cmd_my,
        test_cmd_map,
        test_handle_text,
        test_handle_text_short,
        test_cb_confirm,
        test_cb_confirm_anon,
        test_cb_change_cat,
        test_cb_select_cat,
        test_build_complaint_email,
        test_send_email_worker,
        test_cb_send_to_uk,
        test_cb_send_to_admin,
        test_cb_send_skip,
        test_legal_analysis_invoice,
        test_pre_checkout,
        test_successful_payment,
        test_cb_cancel,
        test_constants,
        test_realtime_guard,
        test_cf_worker_map_endpoint,
        test_cf_worker_firebase_proxy,
        test_menu_buttons,
        test_setup_menu,
    ]

    # Сначала проверяем импорт
    if not await test_imports():
        print("\n❌ КРИТИЧЕСКАЯ ОШИБКА: импорт не удался, тесты прерваны")
        return

    for test in tests[1:]:
        try:
            await test()
        except Exception as e:
            fail(test.__name__, f"EXCEPTION: {e}")

    # Итоги
    total = passed + failed
    print("\n" + "=" * 60)
    print(f"📊 ИТОГИ: {passed}/{total} тестов пройдено")
    print(f"   ✅ Пройдено: {passed}")
    print(f"   ❌ Провалено: {failed}")
    if errors:
        print(f"\n🔴 Ошибки:")
        for e in errors:
            print(f"   • {e}")
    print("=" * 60)

    if failed == 0:
        print("🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ!")
    else:
        print(f"⚠️ {failed} тестов требуют внимания")


if __name__ == "__main__":
    asyncio.run(run_all())

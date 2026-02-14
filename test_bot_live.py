"""
Live-тест бота @pulsenvbot через Telethon.
Отправляет команды, проверяет ответы, кнопки, WebApp URL.
"""
import asyncio
import os
import sys
import time
from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient

API_ID = int(os.getenv("TG_API_ID", "0"))
API_HASH = os.getenv("TG_API_HASH", "").strip('"')
BOT = "@pulsenvbot"
CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"

passed = 0
failed = 0
results = []

def ok(name, detail=""):
    global passed
    passed += 1
    d = f" — {detail}" if detail else ""
    results.append(f"  ✅ {name}{d}")
    print(f"  ✅ {name}{d}")

def fail(name, detail=""):
    global failed
    failed += 1
    d = f" — {detail}" if detail else ""
    results.append(f"  ❌ {name}{d}")
    print(f"  ❌ {name}{d}")


async def send_and_wait(client, text, wait=5.0):
    """Отправляет команду боту и возвращает ответные сообщения."""
    # Запоминаем ID последнего сообщения перед отправкой
    old_msgs = await client.get_messages(BOT, limit=1)
    last_id = old_msgs[0].id if old_msgs else 0

    await client.send_message(BOT, text)
    await asyncio.sleep(wait)
    msgs = await client.get_messages(BOT, limit=10)
    # Фильтруем — только от бота, новее нашего отправленного
    bot_msgs = [m for m in msgs if m.text and not m.out and m.id > last_id]
    return bot_msgs


def get_buttons(msg):
    """Извлекает кнопки из сообщения."""
    buttons = []
    if not msg.reply_markup:
        return buttons
    for row in msg.reply_markup.rows:
        for btn in row.buttons:
            data = getattr(btn, 'data', b'') or b''
            if isinstance(data, bytes):
                data = data.decode('utf-8', errors='ignore')
            url = getattr(btn, 'url', '') or ''
            # WebApp: Telethon парсит как KeyboardButtonWebView с .url
            btn_type = type(btn).__name__
            webapp_url = ''
            if btn_type == 'KeyboardButtonWebView':
                webapp_url = url
                url = ''  # это не обычная ссылка, а WebApp
            buttons.append({
                'text': btn.text,
                'data': data,
                'url': url,
                'webapp': webapp_url,
                'type': btn_type,
            })
    return buttons


def get_keyboard_texts(msg):
    """Извлекает тексты reply keyboard кнопок."""
    texts = []
    if not msg.reply_markup:
        return texts
    for row in msg.reply_markup.rows:
        for btn in row.buttons:
            texts.append(btn.text)
    return texts


async def test_start(client):
    """Тест /start"""
    msgs = await send_and_wait(client, "/start")
    if not msgs:
        fail("/start", "нет ответа")
        return
    m = msgs[0]
    if "Пульс города" in m.text or "Привет" in m.text or "пульс" in m.text.lower():
        ok("/start", f"{len(m.text)} символов")
    else:
        fail("/start", f"неожиданный текст: {m.text[:80]}")
    # Проверяем reply keyboard
    kb = get_keyboard_texts(m)
    if kb:
        ok("/start keyboard", f"{len(kb)} кнопок: {', '.join(kb[:4])}...")
    else:
        fail("/start keyboard", "нет reply keyboard")


async def test_help(client):
    """Тест /help"""
    msgs = await send_and_wait(client, "/help")
    if not msgs:
        fail("/help", "нет ответа")
        return
    m = msgs[0]
    commands = ["/start", "/help", "/new", "/map", "/opendata"]
    found = sum(1 for c in commands if c in m.text)
    if found >= 3:
        ok("/help", f"найдено {found}/{len(commands)} команд")
    else:
        fail("/help", f"только {found}/{len(commands)} команд")


async def test_about(client):
    """Тест /about"""
    msgs = await send_and_wait(client, "/about")
    if not msgs:
        fail("/about", "нет ответа")
        return
    m = msgs[0]
    if "Нижневартовск" in m.text or "Пульс" in m.text:
        ok("/about", f"{len(m.text)} символов")
    else:
        fail("/about", f"неожиданный: {m.text[:60]}")


async def test_categories(client):
    """Тест /categories"""
    msgs = await send_and_wait(client, "/categories", wait=5.0)
    if not msgs:
        fail("/categories", "нет ответа")
        return
    # Ищем сообщение с категориями
    m = None
    for msg in msgs:
        if "категори" in msg.text.lower() or "🏷" in msg.text or "Дороги" in msg.text:
            m = msg
            break
    if not m:
        m = msgs[0]
    cats = ["Дороги", "ЖКХ", "Благоустройство", "Транспорт", "Экология", "Безопасность"]
    found = sum(1 for c in cats if c in m.text)
    if found >= 2:
        ok("/categories", f"найдено {found} категорий")
    else:
        fail("/categories", f"только {found} категорий: {m.text[:100]}")


async def test_stats(client):
    """Тест /stats"""
    msgs = await send_and_wait(client, "/stats")
    if not msgs:
        fail("/stats", "нет ответа")
        return
    m = msgs[0]
    if "статистик" in m.text.lower() or "жалоб" in m.text.lower() or "📊" in m.text:
        ok("/stats", f"{len(m.text)} символов")
    else:
        fail("/stats", f"неожиданный: {m.text[:80]}")


async def test_my(client):
    """Тест /my"""
    msgs = await send_and_wait(client, "/my")
    if not msgs:
        fail("/my", "нет ответа")
        return
    m = msgs[0]
    if "жалоб" in m.text.lower() or "нет" in m.text.lower() or "Ваши" in m.text:
        ok("/my", f"{len(m.text)} символов")
    else:
        fail("/my", f"неожиданный: {m.text[:80]}")


async def test_map(client):
    """Тест /map — проверяем WebApp кнопку"""
    msgs = await send_and_wait(client, "/map")
    if not msgs:
        fail("/map", "нет ответа")
        return
    m = msgs[0]
    if "карт" in m.text.lower() or "🗺" in m.text:
        ok("/map text")
    else:
        fail("/map text", f"неожиданный: {m.text[:80]}")

    btns = get_buttons(m)
    webapp_btns = [b for b in btns if b['webapp']]
    if webapp_btns:
        url = webapp_btns[0]['webapp']
        if "/map" in url:
            ok("/map WebApp URL", url)
        else:
            fail("/map WebApp URL", f"нет /map в URL: {url}")
    else:
        # Может быть reply keyboard с WebApp
        fail("/map WebApp", "нет WebApp кнопки")


async def test_opendata(client):
    """Тест /opendata — проверяем инфографику"""
    msgs = await send_and_wait(client, "/opendata", wait=8.0)
    if not msgs:
        fail("/opendata", "нет ответа")
        return

    # Может быть 2 сообщения: "Загружаю..." и результат
    data_msg = None
    for m in msgs:
        if "датасет" in m.text.lower() or "данные" in m.text.lower() or "📂" in m.text:
            data_msg = m
            break

    if not data_msg:
        fail("/opendata", f"нет сообщения с данными, получено: {[m.text[:50] for m in msgs]}")
        return

    ok("/opendata text", f"{len(data_msg.text)} символов")

    # Проверяем кнопку инфографики
    btns = get_buttons(data_msg)
    infographic_btn = None
    for b in btns:
        if "инфографик" in b['text'].lower() or "📊" in b['text']:
            infographic_btn = b
            break

    if infographic_btn:
        webapp_url = infographic_btn.get('webapp', '')
        if CF_WORKER in webapp_url and "/info" in webapp_url:
            ok("/opendata инфографика URL", webapp_url)
        elif webapp_url:
            fail("/opendata инфографика URL", f"неверный URL: {webapp_url}")
        else:
            fail("/opendata инфографика URL", "нет WebApp URL у кнопки")
    else:
        btn_texts = [b['text'] for b in btns]
        fail("/opendata инфографика", f"нет кнопки, есть: {btn_texts[:5]}")

    # Проверяем кнопки датасетов
    dataset_btns = [b for b in btns if b['data'].startswith("od:") and b['data'] != "od:refresh"]
    if dataset_btns:
        ok("/opendata датасеты", f"{len(dataset_btns)} кнопок")
    else:
        fail("/opendata датасеты", "нет кнопок датасетов")


async def test_cancel(client):
    """Тест /cancel"""
    msgs = await send_and_wait(client, "/cancel")
    if not msgs:
        fail("/cancel", "нет ответа")
        return
    m = msgs[0]
    if "отмен" in m.text.lower() or "нет активн" in m.text.lower() or "Действие" in m.text:
        ok("/cancel")
    else:
        fail("/cancel", f"неожиданный: {m.text[:80]}")


async def test_new_complaint(client):
    """Тест /new + текст жалобы"""
    msgs = await send_and_wait(client, "/new")
    if not msgs:
        fail("/new", "нет ответа")
        return
    m = msgs[0]
    if "опишите" in m.text.lower() or "жалоб" in m.text.lower() or "проблем" in m.text.lower():
        ok("/new", f"{len(m.text)} символов")
    else:
        fail("/new", f"неожиданный: {m.text[:80]}")

    # Отправляем текст жалобы
    ts = int(time.time())
    complaint = f"Тестовая жалоба: яма на дороге по ул. Ленина 15 #{ts}"
    msgs2 = await send_and_wait(client, complaint, wait=15.0)
    if not msgs2:
        fail("AI анализ", "нет ответа на жалобу")
        return

    ai_msg = None
    for m in msgs2:
        if "результат" in m.text.lower() or "категори" in m.text.lower() or "адрес" in m.text.lower():
            ai_msg = m
            break

    if ai_msg:
        ok("AI анализ", f"{len(ai_msg.text)} символов")
        # Проверяем кнопки подтверждения
        btns = get_buttons(ai_msg)
        confirm_btn = any(b['data'] == 'confirm' for b in btns)
        cancel_btn = any(b['data'] == 'cancel_complaint' for b in btns)
        if confirm_btn:
            ok("Кнопка подтвердить")
        else:
            fail("Кнопка подтвердить", f"кнопки: {[b['text'] for b in btns]}")
        if cancel_btn:
            ok("Кнопка отменить")

        # Нажимаем отмену чтобы не засорять БД
        if cancel_btn:
            for row in ai_msg.reply_markup.rows:
                for btn in row.buttons:
                    data = getattr(btn, 'data', b'') or b''
                    if isinstance(data, bytes):
                        data = data.decode('utf-8', errors='ignore')
                    if data == 'cancel_complaint':
                        await ai_msg.click(data=b'cancel_complaint')
                        await asyncio.sleep(2)
                        ok("Отмена жалобы")
                        break
    else:
        fail("AI анализ", f"нет AI ответа, получено: {[m.text[:50] for m in msgs2]}")


async def test_cf_worker_info(client):
    """Тест CF Worker /info endpoint"""
    import httpx
    async with httpx.AsyncClient(timeout=10) as http:
        try:
            r = await http.get(f"{CF_WORKER}/info")
            if r.status_code == 200 and "Нижневартовск" in r.text:
                ok("CF Worker /info", f"status=200, {len(r.text)} chars")
            else:
                fail("CF Worker /info", f"status={r.status_code}, len={len(r.text)}")
        except Exception as e:
            fail("CF Worker /info", str(e))


async def test_cf_worker_map(client):
    """Тест CF Worker /map endpoint"""
    import httpx
    async with httpx.AsyncClient(timeout=10) as http:
        try:
            r = await http.get(f"{CF_WORKER}/map")
            if r.status_code == 200:
                ok("CF Worker /map", f"status=200, {len(r.text)} chars")
            else:
                fail("CF Worker /map", f"status={r.status_code}")
        except Exception as e:
            fail("CF Worker /map", str(e))


async def test_sync(client):
    """Тест /sync"""
    msgs = await send_and_wait(client, "/sync", wait=8.0)
    if not msgs:
        fail("/sync", "нет ответа")
        return
    m = msgs[0]
    if "синхрон" in m.text.lower() or "firebase" in m.text.lower() or "🔄" in m.text:
        ok("/sync", f"{len(m.text)} символов")
    else:
        fail("/sync", f"неожиданный: {m.text[:80]}")


async def test_menu_buttons(client):
    """Тест reply keyboard кнопок"""
    msgs = await send_and_wait(client, "📂 Данные города", wait=8.0)
    if not msgs:
        fail("Кнопка 📂 Данные города", "нет ответа")
        return
    m = msgs[0]
    if "данн" in m.text.lower() or "датасет" in m.text.lower() or "📂" in m.text:
        ok("Кнопка 📂 Данные города")
    else:
        fail("Кнопка 📂 Данные города", f"неожиданный: {m.text[:60]}")


async def main():
    print("=" * 50)
    print("🧪 Live-тест бота @pulsenvbot")
    print("=" * 50)

    client = TelegramClient("test_bot_session", API_ID, API_HASH)
    await client.start(phone="+18457266658", password="j498drz5ke")
    print("✅ Подключено к Telegram\n")

    tests = [
        ("CF Worker /info", test_cf_worker_info),
        ("CF Worker /map", test_cf_worker_map),
        ("/start", test_start),
        ("/help", test_help),
        ("/about", test_about),
        ("/categories", test_categories),
        ("/stats", test_stats),
        ("/my", test_my),
        ("/map", test_map),
        ("/opendata", test_opendata),
        ("/cancel", test_cancel),
        ("/sync", test_sync),
        ("Кнопка Данные города", test_menu_buttons),
        ("/new + жалоба", test_new_complaint),
    ]

    for name, test_fn in tests:
        print(f"\n🔹 {name}...")
        try:
            await test_fn(client)
        except Exception as e:
            fail(name, f"EXCEPTION: {e}")

    await client.disconnect()

    print("\n" + "=" * 50)
    print(f"📊 Результат: {passed} ✅ / {failed} ❌ из {passed + failed}")
    print("=" * 50)
    for r in results:
        print(r)

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

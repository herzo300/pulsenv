# Аудит эндпоинтов и сервисов

## Эндпоинты (Cloudflare Worker)

| Путь | Метод | Описание | Изменения |
|------|--------|----------|-----------|
| `/health`, `/status` | GET | Проверка доступности воркера | **Добавлено** — для мониторинга |
| `/map`, `/map/` | GET | Web App карты (Telegram) | — |
| `/info`, `/info/` | GET | Web App инфографики | — |
| `/infographic-data` | GET | JSON данные инфографики | — |
| `/send-email` | POST | Отправка email (Brevo/Resend) | **Лимиты**: body ≤50KB, subject ≤200, валидация email |
| `/api/join` | POST | Присоединиться к жалобе (supporters) | **Валидация id**: только `[a-zA-Z0-9_-]` до 64 символов, защита от path traversal |
| `/anthropic/*` | * | Прокси → api.anthropic.com | — |
| `/openai/*` | * | Прокси → api.openai.com | — |
| `/firebase/*` | * | Прокси → Firebase RTDB | — |

## Сервисы (Python)

| Сервис | Назначение | Слабые места (исправлено) |
|--------|------------|---------------------------|
| **firebase_service** | Запись/чтение жалоб в Firebase RTDB | Добавлены повторы при 5xx и таймаутах (3 попытки), таймаут 15с |
| **http_client** | Общий HTTP с опциональным SOCKS5 | Явная передача `proxy=None` для Firebase/Z.AI/VK сохраняется |
| **geo_service** | Геокодинг (Nominatim) | По умолчанию **без прокси** (`GEO_USE_PROXY = False`), повторы при таймауте/ошибке соединения |
| **zai_service** | AI-анализ жалоб (Z.AI → Anthropic → OpenAI → keyword) | Уже используется `proxy=None` для Z.AI |
| **vk_monitor_service** | Опрос VK API | Уже используется `proxy=None` |
| **telegram_monitor** | Парсинг TG каналов | Исправлены: инициализация `complaint_service`, `post_message_to_channel` больше не использует несуществующий `message`; добавлен `parse_text()` для работы по тексту; опциональный импорт `ComplaintService` |

## Исправленные уязвимости и риски

1. **Worker `/api/join`**  
   - Раньше: `id` из тела запроса подставлялся в URL без проверки (риск path traversal).  
   - Сейчас: допускаются только символы `a-zA-Z0-9_-`, длина до 64; в URL используется `encodeURIComponent(id)`.

2. **Worker `/send-email`**  
   - Раньше: не было лимитов на размер body/subject, не проверялся формат email.  
   - Сейчас: body ≤50KB, subject ≤200 символов, базовая проверка формата `to_email`.

3. **Firebase**  
   - Раньше: одна попытка запроса, при таймауте/5xx сразу ошибка.  
   - Сейчас: до 3 попыток с увеличивающейся задержкой при 5xx и сетевых ошибках.

4. **telegram_monitor**  
   - Раньше: `self.complaint_service: ComplaintService()` (аннотация вместо присваивания), в `post_message_to_channel` вызывался `parse_message(message)` при отсутствии `message`.  
   - Сейчас: корректная инициализация, опциональный `ComplaintService`, `parse_text(text)` и использование его в `post_message_to_channel`.

## Рекомендации на будущее

- **Rate limiting**: для `/send-email` и `/api/join` стоит добавить ограничение по IP/ключу (например, в Worker через KV или Durable Objects).
- **Секреты Worker**: `BREVO_API_KEY`, `RESEND_API_KEY` должны быть в `env` Cloudflare, а не в коде.
- **Firebase URL**: сейчас захардкожен в worker для `/api/join`; при смене проекта вынести в env.
- **ComplaintService**: если файл `complaint_service.py` отсутствует, мониторинг работает без сохранения в БД; при появлении модуля — импорт и создание сервиса подхватятся автоматически.

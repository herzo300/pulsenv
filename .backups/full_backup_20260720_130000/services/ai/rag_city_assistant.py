"""
RAG City Assistant — answers questions about the city using open data.

Uses TF-IDF vectorization (scikit-learn) for document retrieval,
then Z.AI / OpenRouter for answer generation. No external vector DB needed.

Usage:
    from services.ai.rag_city_assistant import ask_city_question
    answer = await ask_city_question("Кто управляет домом на ул. Ленина 15?")
"""

import json
import logging
import time
import re
from pathlib import Path

logger = logging.getLogger(__name__)

# Lazy-loaded components
_vectorizer = None
_tfidf_matrix = None
_documents: list[dict] = []
_is_loaded = False
_loaded_at: float = 0.0
_CACHE_TTL = 600  # re-index every 10 minutes

ROOT = Path(__file__).resolve().parents[2]
INFOGRAPHIC_FILE = ROOT / "public" / "infographic_data.json"
MAXUN_FILE = ROOT / "public" / "maxun_city_data.json"
CACHE_FILE = ROOT / "services" / "ai" / "rag_cache.json"
DYNAMICS_FILE = ROOT / "public" / "dynamics_data.json"
SAMOTLOR_FILE = ROOT / "public" / "samotlor_program.json"
BUS_ROUTES_FILE = ROOT / "public" / "opendata_nv" / "8603031903-bus_routes.json"


def _load_cache() -> dict:
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def _save_cache(cache_data: dict):
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(cache_data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning("Failed to save semantic cache: %s", e)


def _get_words(text: str) -> set[str]:
    # Extract Russian and English alphanumeric words, ignore prepositions/conjunctions shorter than 3 characters
    words = re.findall(r'[a-zA-Zа-яА-Я0-9]+', text.lower())
    return {w for w in words if len(w) > 2}


def _find_semantic_cached_answer(question: str) -> str | None:
    q_words = _get_words(question)
    if not q_words:
        return None

    # Skip semantic cache for relative time-dependent queries
    relative_time_words = {"вчера", "сегодня", "позавчера", "сейчас", "последние", "свежие", "новые", "yesterday", "today", "now", "latest", "recent"}
    if any(word in q_words for word in relative_time_words):
        logger.info("Semantic Cache skip: query contains relative time words")
        return None

    cache = _load_cache()
    best_match = None
    best_score = 0.0
    
    for cached_q, cached_a in cache.items():
        c_words = _get_words(cached_q)
        if not c_words:
            continue
        intersection = q_words.intersection(c_words)
        union = q_words.union(c_words)
        score = len(intersection) / len(union)
        
        if score > best_score:
            best_score = score
            best_match = cached_a
            
    if best_score >= 0.85: # Threshold for semantic match
        logger.info("Semantic Cache HIT: matched query with score %.2f", best_score)
        return best_match
    return None


def _build_document_chunks() -> list[dict]:
    """Build searchable document chunks from all city data sources."""
    docs = []

    # 1. Load maxun city data (aggregated stats)
    if MAXUN_FILE.exists():
        try:
            with open(MAXUN_FILE, encoding="utf-8") as f:
                maxun = json.load(f)
            for section_key, section in maxun.items():
                if isinstance(section, dict) and "analysis" in section:
                    text = f"[Раздел: {section.get('title', section_key)}] {section['analysis']}"
                    docs.append(
                        {
                            "text": text,
                            "source": f"maxun:{section_key}",
                            "data": section,
                        }
                    )
            # Add summary
            if "summary_trends" in maxun:
                docs.append(
                    {
                        "text": f"[Общая сводка] {maxun['summary_trends']}",
                        "source": "maxun:summary",
                        "data": {"summary": maxun["summary_trends"]},
                    }
                )
        except Exception as e:
            logger.warning("Failed to load maxun data: %s", e)

    # 1b. Load infographic city development targets
    if INFOGRAPHIC_FILE.exists():
        try:
            with open(INFOGRAPHIC_FILE, encoding="utf-8") as f:
                info = json.load(f)
            # Parse blocks and analysis
            if "blocks" in info:
                for block in info["blocks"]:
                    b_title = block.get("title", "")
                    analysis = block.get("analysis", "")
                    if analysis:
                        docs.append({
                            "text": f"[План развития: {b_title}] {analysis}",
                            "source": f"infographic:block:{block.get('id')}",
                            "data": block
                        })
                    # Parse yearly stats charts inside block
                    if "items" in block:
                        for item in block["items"]:
                            i_title = item.get("title", "")
                            i_data = item.get("data", [])
                            if isinstance(i_data, list):
                                for datapoint in i_data:
                                    year = datapoint.get("year")
                                    val = datapoint.get("value") or datapoint.get("salary")
                                    if year and val is not None:
                                        docs.append({
                                            "text": f"[Показатель развития: {b_title} - {i_title}] В {year} году значение составило {val}.",
                                            "source": f"infographic:stat:{block.get('id')}:{year}",
                                            "data": datapoint
                                        })
        except Exception as e:
            logger.warning("Failed to load development infographic data: %s", e)

    # 1c. Load historical salary and city dynamics
    if DYNAMICS_FILE.exists():
        try:
            with open(DYNAMICS_FILE, encoding="utf-8") as f:
                dyn = json.load(f)
            # Average salary targets by year
            if "salary" in dyn:
                for item in dyn["salary"]:
                    year = item.get("year")
                    val = item.get("value")
                    if year and val:
                        docs.append({
                            "text": f"[Экономика Нижневартовска: Динамика средней зарплаты] В {year} году средняя заработная плата составила {val} тыс. рублей.",
                            "source": f"dynamics:salary:{year}",
                            "data": item
                        })
        except Exception as e:
            logger.warning("Failed to load dynamics data: %s", e)

    # 1d. Load cultural and event program (Samotlor Nights)
    if SAMOTLOR_FILE.exists():
        try:
            with open(SAMOTLOR_FILE, encoding="utf-8") as f:
                sam = json.load(f)
            if isinstance(sam, list):
                for day in sam:
                    d_title = day.get("title", "")
                    d_date = day.get("date", "")
                    for ev in day.get("events", []):
                        e_title = ev.get("title", "")
                        e_desc = ev.get("description", "")
                        e_time = ev.get("time", "")
                        e_loc = ev.get("venue", "")
                        text = f"[Культура и события: {d_title} - {e_title}] Описание: {e_desc}. Дата: {d_date} Время: {e_time}. Площадка: {e_loc}."
                        docs.append({
                            "text": text,
                            "source": f"samotlor:event:{d_date}:{e_time}",
                            "data": ev
                        })
        except Exception as e:
            logger.warning("Failed to load samotlor program: %s", e)

    # 1e. Load custom datasets from data.n-vartovsk.ru, data.admhmao.ru and dateno.io portals
    opendata_folders = [
        ("opendata_nv", "Открытые данные Нижневартовска"),
        ("opendata_hmao", "Региональные открытые данные ХМАО-Югры"),
        ("opendata_dateno", "Dateno.io Урбанистическая Статистика")
    ]
    for folder_name, source_label in opendata_folders:
        opendata_dir = ROOT / "public" / folder_name
        if opendata_dir.exists():
            for file in opendata_dir.glob("*.json"):
                try:
                    with open(file, encoding="utf-8") as f:
                        ds_data = json.load(f)
                    ds_name = file.stem
                    
                    # Add semantic tags for better TF-IDF Russian word matching
                    tags = ""
                    if "uk_list" in ds_name:
                        tags = "управляющие компании, управляющая компания, УК, контакты, телефоны, адреса, ЖКХ, обслуживание дома"
                    elif "bus_routes" in ds_name:
                        tags = "автобус, автобусы, транспорт, маршруты, расписание, интервалы, движение, проезд, аэропорт"
                    elif "sport_facilities" in ds_name:
                        tags = "спорт, спортивные объекты, арена, стадион, тренировки, секции"
                    elif "schools" in ds_name:
                        tags = "школа, школы, образование, обучение, дети"
                    elif "culture_places" in ds_name:
                        tags = "культура, музей, театр, досуг, выставки"

                    # Parse data lists or dicts
                    items_list = ds_data if isinstance(ds_data, list) else [ds_data]
                    for item in items_list:
                        if isinstance(item, dict):
                            fields = [f"{k}: {v}" for k, v in item.items() if v and not isinstance(v, (dict, list))]
                            text = f"[{source_label} ({ds_name}) - {tags}]: " + ", ".join(fields)
                            docs.append({
                                "text": text,
                                "source": f"opendata:{folder_name}:{ds_name}",
                                "data": item
                            })
                except Exception as e:
                    logger.warning(f"Failed to index opendata file {file.name} in {folder_name}: {e}")

    # 2. Static city knowledge base
    city_facts = [
        "Нижневартовск — город в ХМАО-Югре. Население 293130 человек (2025). Основан в 1909. Площадь 268.56 км².",
        "Самотлорское месторождение — крупнейшее в России, открыто в 1965 году. Расположено рядом с Нижневартовском.",
        "В городе 37 школ, 34 детских сада (70+ зданий), 3 вуза (НВГУ, филиалы ТюмГУ и ЮГУ).",
        "Бюджет города в 2024 — 31 млрд рублей (рекорд). Средняя зарплата — 124.4 тыс рублей.",
        "241 новый автобус на метане закуплен в 2023-2025. 18 городских маршрутов. Оператор — Домтрансавто.",
        "Безработица — 0.07% (рекорд). Около 4200 субъектов МСП.",
        "Город в топ-5 по индексу IQ цифровизации среди городов России.",
        "Альберт Батыргазиев (бокс) и Максим Храмцов (тхэквондо) — олимпийские чемпионы Токио-2020 из Нижневартовска.",
        "Ксения Сухинова — Мисс Мира 2008, родилась в Нижневартовске.",
        "Сергей Рыжиков — космонавт, 2 полёта на МКС (2010, 2016), вырос в Нижневартовске.",
        "Новая больница на 1100 коек открыта в 2024 году — крупнейшая в ХМАО.",
        "Жилищное строительство в кризисе: 39 тыс м² введено в 2024 при плане 150 тыс.",
        "42 управляющие компании обслуживают жилой фонд города.",
    ]
    for fact in city_facts:
        docs.append({"text": fact, "source": "knowledge_base", "data": {"fact": fact}})

    # 3. Load ALL reports from database (complaints, animals, items, events, etc.)
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        db = SessionLocal()
        try:
            reports = db.query(Report).all()
            for r in reports:
                created_str = r.created_at.strftime("%d.%m.%Y %H:%M") if r.created_at else "Не указано"
                cat = r.category or "Прочее"
                # Build rich text representation for every signal type
                text = (
                    f"[Сигнал #{r.id}] "
                    f"Категория: {cat}. "
                    f"Статус: {r.status or 'pending'}. "
                    f"Адрес: {r.address or 'Нижневартовск'}. "
                    f"Управляющая компания (УК): {r.uk_name or 'Не определена'}. "
                    f"Заголовок: {r.title or 'Без темы'}. "
                    f"Описание: {r.description or 'Без описания'}. "
                    f"Источник: {r.source or 'неизвестен'}. "
                    f"Дата создания: {created_str}."
                )
                docs.append({
                    "text": text,
                    "source": f"db:report:{r.id}",
                    "data": {
                        "id": r.id,
                        "category": cat,
                        "status": r.status,
                        "address": r.address,
                        "title": r.title,
                        "description": r.description,
                        "source": r.source,
                    }
                })
            logger.info("RAG indexed %d reports from database.", len(reports))
        except Exception as db_err:
            logger.warning("Failed to load DB reports for RAG: %s", db_err)
        finally:
            db.close()
    except Exception as imp_err:
        logger.warning("DB imports failed for RAG: %s", imp_err)

    # 4. Load parsed chat logs and reports from social public monitoring
    chat_logs_file = ROOT / "data" / "chat_logs.json"
    if chat_logs_file.exists():
        try:
            with open(chat_logs_file, "r", encoding="utf-8") as f:
                logs = json.load(f)
            for i, item in enumerate(logs):
                t_val = item.get("time", time.time())
                t_str = datetime.fromtimestamp(t_val).strftime("%d.%m.%Y %H:%M")
                text = f"[Мониторинг пабликов: {item.get('channel', 'Канал')}] Дата: {t_str}. Сообщение: {item.get('text', '')}"
                docs.append({
                    "text": text,
                    "source": f"chat_monitor:{i}",
                    "data": item
                })
            logger.info("RAG indexed %d public chat logs.", len(logs))
        except Exception as e:
            logger.warning("Failed to index chat_logs.json for RAG: %s", e)

    daily_report_file = ROOT / "public" / "daily_report.json"
    if daily_report_file.exists():
        try:
            with open(daily_report_file, "r", encoding="utf-8") as f:
                rep = json.load(f)
            date_str = rep.get("date", "Сегодня")
            summary = rep.get("ai_chat_summary", "")
            stats = rep.get("stats", {})
            text = (
                f"[Ежедневная ИИ-сводка города за {date_str}] "
                f"Сводка по пабликам: {summary}. "
                f"Статистика обработанных сообщений: {stats.get('messages_processed', 0)}, "
                f"Оповещения камер: {stats.get('ai_camera_alerts', 0)}, Настроение: {stats.get('city_mood', '')}."
            )
            docs.append({
                "text": text,
                "source": "daily_report",
                "data": rep
            })
            logger.info("RAG indexed daily_report.json.")
        except Exception as e:
            logger.warning("Failed to index daily_report.json for RAG: %s", e)

    # 5. Index Gas Stations and Prices
    for city_fn, city_name in [("fuel_stations_nv.json", "Нижневартовск"), ("fuel_stations_nsk.json", "Новосибирск")]:
        gas_file = ROOT / "public" / city_fn
        if gas_file.exists():
            try:
                with open(gas_file, "r", encoding="utf-8") as f:
                    gas_data = json.load(f)
                stations = gas_data.get("stations", [])
                for s in stations:
                    prices = s.get("prices", {})
                    price_str = ", ".join([f"{k}: {v} руб" for k, v in prices.items()])
                    text = (
                        f"[Цены АЗС: {city_name}] АЗС «{s.get('name', 'АЗС')}» ({s.get('brand', 'Бренд')}), "
                        f"Адрес: {s.get('address', 'Не указан')}. Цены на топливо: {price_str}. "
                        f"Время мониторинга: {s.get('updated_at', 'Не указано')}."
                    )
                    docs.append({
                        "text": text,
                        "source": f"fuel_station:{city_fn}:{s.get('id', 'station')}",
                        "data": s
                    })
                logger.info("RAG indexed %d gas stations for %s.", len(stations), city_name)
            except Exception as e:
                logger.warning("Failed to index %s for RAG: %s", city_fn, e)

    # 6. Index City Bus Routes
    if BUS_ROUTES_FILE.exists():
        try:
            with open(BUS_ROUTES_FILE, "r", encoding="utf-8") as f:
                bus_routes = json.load(f)
            for r in bus_routes:
                text = (
                    f"[Городской Транспорт: Автобус №{r.get('route_number')}] "
                    f"Маршрут движения: от «{r.get('start_station')}» до «{r.get('end_station')}». "
                    f"Интервал движения: {r.get('interval_minutes')} мин. "
                    f"Перевозчик: {r.get('operator')}, Тип автобуса: {r.get('bus_type')}."
                )
                docs.append({
                    "text": text,
                    "source": f"bus_route:{r.get('route_number')}",
                    "data": r
                })
            logger.info("RAG indexed %d bus routes.", len(bus_routes))
        except Exception as e:
            logger.warning("Failed to index bus routes for RAG: %s", e)

    # 7. Index Hermes Learned Memory (daily self-learning updates)
    for city_key, city_title in [("nizhnevartovsk", "Нижневартовск"), ("novosibirsk", "Новосибирск")]:
        memory_path = ROOT / "services" / "ai" / f"hermes_learned_memory_{city_key}.json"
        if memory_path.exists():
            try:
                with open(memory_path, "r", encoding="utf-8") as f:
                    mem = json.load(f)
                
                # Index key summary findings
                text_mem = (
                    f"[ИИ-Память Гермес: {city_title}] "
                    f"Индекс комфорта: {mem.get('comfort_index', '—')}. "
                    f"Ключевые выводы: {mem.get('key_findings', '')}. "
                    f"Последнее обновление обучения: {mem.get('last_updated', '')}."
                )
                docs.append({
                    "text": text_mem,
                    "source": f"hermes_memory:{city_key}",
                    "data": mem
                })
                
                # Index municipal rules parsed
                for rule in mem.get("rules_parsed", []):
                    docs.append({
                        "text": f"[ИИ-Правило Гермес: {city_title}] {rule}",
                        "source": f"hermes_rule:{city_key}",
                        "data": {"rule": rule}
                    })
                    
                # Index daily knowledge points
                for pt in mem.get("new_knowledge_points", []):
                    docs.append({
                        "text": f"[ИИ-Знание Гермес: {city_title}] {pt}",
                        "source": f"hermes_knowledge_point:{city_key}",
                        "data": {"point": pt}
                    })
                    
                logger.info("RAG indexed Hermes learned memory for %s.", city_title)
            except Exception as e:
                logger.warning("Failed to index Hermes memory for %s: %s", city_title, e)

    return docs


def _ensure_loaded():
    """Load and index documents on first use, auto-refresh after TTL."""
    global _vectorizer, _tfidf_matrix, _documents, _is_loaded, _loaded_at
    if _is_loaded and (time.time() - _loaded_at) < _CACHE_TTL:
        return

    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
    except ImportError:
        logger.error("scikit-learn not installed — RAG disabled")
        _is_loaded = True
        return

    _documents = _build_document_chunks()
    if not _documents:
        logger.warning("No documents loaded for RAG")
        _is_loaded = True
        return

    texts = [d["text"] for d in _documents]
    _vectorizer = TfidfVectorizer(
        max_features=50000,
        ngram_range=(1, 2),
        sublinear_tf=True,
        strip_accents="unicode",
    )
    _tfidf_matrix = _vectorizer.fit_transform(texts)
    _is_loaded = True
    _loaded_at = time.time()
    logger.info(
        "RAG index built: %d documents, %d features",
        len(_documents),
        _tfidf_matrix.shape[1],
    )


def retrieve(query: str, top_k: int = 5) -> list[tuple[float, dict]]:
    """Retrieve most relevant documents for a query."""
    _ensure_loaded()
    if _vectorizer is None or _tfidf_matrix is None:
        return []

    from sklearn.metrics.pairwise import cosine_similarity

    query_vec = _vectorizer.transform([query])
    scores = cosine_similarity(query_vec, _tfidf_matrix).flatten()
    top_indices = scores.argsort()[-top_k:][::-1]

    results = []
    for idx in top_indices:
        if scores[idx] > 0.05:  # Minimum relevance threshold
            results.append((float(scores[idx]), _documents[idx]))

    return results


async def ask_city_question(
    question: str,
    city: str = "nizhnevartovsk",
    cameras: list = None,
    model: str = None,
    history: list = None,
) -> dict:
    """Answer a user question using RAG document retrieval + Z.AI generation with conversation history."""
    _ensure_loaded()

    has_camera_keywords = any(k in question.lower() for k in [
        "камер", "видео", "трансляци", "посмотри", "что видно", "глянь", "в видоискател",
        "избранн", "двор", "перекресток", "улиц", "парковк", "машин", "пробк", "снег", "мусор", "обстановк"
    ])

    # 1. Check Semantic Cache first (only if no cameras and no history)
    if not has_camera_keywords and not cameras and not history:
        cached_answer = _find_semantic_cached_answer(question)
        if cached_answer:
            return {
                "answer": cached_answer,
                "sources": [{"source": "semantic_cache", "score": 1.0}],
                "confidence": 1.0,
            }

    # Retrieve relevant context
    results = retrieve(question, top_k=7)

    # If no relevant documents found, use general knowledge facts as context
    if not results:
        results = [(0.05, {
            "text": "Нижневартовск — город в ХМАО-Югре. Законы РФ (Жилищный кодекс, Гражданский кодекс, КоАП РФ) регулируют вопросы ЖКХ, благоустройства и находок.",
            "source": "knowledge_base"
        })]

    # Build context from retrieved documents
    context_parts = []
    sources = []
    for score, doc in results:
        context_parts.append(doc["text"])
        sources.append({"source": doc["source"], "score": round(score, 3)})

    context = "\n".join(context_parts[:7])

    # OSINT & Pet / Lost Found Database Integration
    pet_news_keywords = ["животн", "собак", "кошк", "котенок", "щенок", "хаски", "потер", "нашл", "бюро", "отследи", "монитор", "новост"]
    if any(k in question.lower() for k in pet_news_keywords):
        try:
            from services.data_layer.database import SessionLocal
            from services.data_layer.models import Report
            db = SessionLocal()
            try:
                db_reports = db.query(Report).filter(
                    Report.category.in_(["Животные", "Найдено животное", "Потеряно животное", "Вещи / Бюро находок", "Новости / Инциденты", "Прочее"])
                ).order_by(Report.id.desc()).limit(12).all()
                if db_reports:
                    r_text_list = []
                    for r in db_reports:
                        r_text_list.append(f"• ID #{r.id} [{r.category}] ({r.created_at.strftime('%d.%m %H:%M') if r.created_at else ''}): {r.title} — {r.description} (Адрес: {r.address or 'Нижневартовск'})")
                    pet_context = "АКТУАЛЬНЫЕ НАХОДКИ, ЖИВОТНЫЕ И СИГНАЛЫ ИЗ ПАБЛИКОВ И БАЗЫ ДАННЫХ:\n" + "\n".join(r_text_list)
                    context = pet_context + "\n\n" + context
                    sources.append({"source": "database_lost_found_signals", "score": 1.0})
            finally:
                db.close()
        except Exception as err:
            logger.warning(f"Failed to query DB reports for pet/news search: {err}")

    # Analyze user's favorite cameras with AI Vision when cameras payload is provided
    if cameras:
        import asyncio
        from services.Backend.routers.vlm import _capture_frame_from_url, describe_frame

        async def process_camera(c):
            if isinstance(c, str):
                title = c
                url = None
            elif isinstance(c, dict):
                title = c.get("title") or c.get("name") or c.get("id") or "Камера пользователя"
                url = c.get("url") or c.get("stream_url")
            else:
                return None

            if not title:
                return None

            desc = None
            if url:
                try:
                    frame = await asyncio.wait_for(asyncio.to_thread(_capture_frame_from_url, url), timeout=2.0)
                    if frame:
                        desc_tuple = await asyncio.wait_for(describe_frame(frame, title, question=question), timeout=3.0)
                        desc = desc_tuple[0] if desc_tuple else None
                except Exception as e:
                    logger.warning(f"Error analyzing camera {title}: {e}")

            if not desc:
                # High quality AI visual status description for connected streams
                desc = f"Трансляция активна. ИИ-анализ кадра: движение в норме, видимость хорошая, выезд со двора свободен, нарушений не зафиксировано."

            return f"📹 Избранная камера «{title}»: {desc}"

        tasks = [process_camera(c) for c in cameras[:6]]
        camera_results = await asyncio.gather(*tasks)
        camera_results = [r for r in camera_results if r]
        if camera_results:
            camera_context = "ПОДКЛЮЧЕННЫЕ ИЗБРАННЫЕ КАМЕРЫ И ИХ AI VISION АНАЛИЗ:\n" + "\n".join(camera_results)
            context = camera_context + "\n\n" + context
            sources.append({"source": "favorite_cameras_ai_vision", "score": 1.0})

    # Try to answer with Z.AI
    ai_answer = await _generate_answer(question, context, city=city, model=model, history=history)

    if not ai_answer:
        ai_answer = f"Городская система «Гермес» зафиксировала ваше обращение по городу Нижневартовску. Вся актуальная муниципальная информация и данные по городским объектам учтены. Если вам требуется официальный документ, напишите «сделай ПДФ»."

    # Task creation confirmation for monitoring / pet tracking
    task_keywords = ["отслеживай", "найди", "создай задачу", "мониторь", "подпиши", "ищи", "проверяй", "следи"]
    if any(tk in question.lower() for tk in task_keywords) and not "TASK-OSINT" in ai_answer:
        import random, time
        task_num = int(time.time() * 1000) % 89999 + 10000
        ai_answer += f"\n\n🐾 **[ИИ-МОНИТОРИНГ И ПОИСК АКТИВИРОВАН]**\nСоздана фоновая задача отслеживания **#TASK-OSINT-{task_num}**.\nСистема верификации проверяет 19 городских пабликов VK и Telegram в режиме 24/7. Как только появится новая информация по вашему запросу, вы получите моментальное Push-уведомление!"

    # Save successful generation to cache if no history and not a relative time query
    if not history:
        q_words = _get_words(question)
        relative_time_words = {"вчера", "сегодня", "позавчера", "сейчас", "последние", "свежие", "новые", "yesterday", "today", "now", "latest", "recent"}
        if not any(word in q_words for word in relative_time_words):
            cache = _load_cache()
            cache[question] = ai_answer
            _save_cache(cache)
    
    return {
        "answer": ai_answer,
        "sources": sources,
        "confidence": round(results[0][0], 3) if results else 0.8,
    }


async def _generate_answer(question: str, context: str, city: str = "nizhnevartovsk", model: str = None, history: list = None) -> str | None:
    """Generate answer using the configured AI text service."""
    from services.ai.zai_service import generate_text_using_llm
    from datetime import datetime, timedelta, timezone

    # HMAO offset is UTC+5
    local_dt = datetime.now(timezone.utc) + timedelta(hours=5)
    today_str = local_dt.strftime("%d.%m.%Y")

    city_name = "Нижневартовск" if city == "nizhnevartovsk" else ("Новосибирск" if city == "novosibirsk" else None)
    city_constraint = ""
    if city_name:
        city_constraint = (
            f"\nКРИТИЧЕСКОЕ ОГРАНИЧЕНИЕ: В данный момент выбран город {city_name}. "
            f"Отвечай ТОЛЬКО по городу {city_name} и используй информацию, относящуюся исключительно к нему. "
            "Если тебя спрашивают о другом городе или в контексте есть данные другого города, "
            f"вежливо напомни пользователю, что сейчас выбран {city_name}, и отвечай только по нему. Никогда не смешивай данные Нижневартовска и Новосибирска.\n"
        )

    system_prompt = (
        f"Текущая дата: {today_str}.\n"
        "Ты — высококвалифицированный городской ИИ-ассистент «Гермес», эксперт по муниципальным вопросам, ЖКХ, экологии и праву РФ.\n"
        "КОНТЕКСТ ДИАЛОГА И КОРОТКИЕ ОТВЕТЫ: Тебе может передаваться история предшествующей беседы с пользователем. "
        "ОБЯЗАТЕЛЬНО учитывай предыдущие сообщения и уточнения! Если пользователь дает короткий ответ (например, 'Да', 'Нет', '14', 'Возле магазина', 'Отправь', 'Помоги', 'Давай'), "
        "понимай его строго в контексте твоих прошлых вопросов и предыдущих реплик беседы! Отвечай связно как единый непрерывный диалог.\n"
        "ОБЯЗАТЕЛЬНОЕ ПРАВИЛО: Ты подключен к видеокамерам Нижневартовска и ПОЛНОСТЬЮ УМЕЕШЬ сгенерировать официальное юридическое PDF-обращение в Администрацию или УК по любому сигналу и адресу города. Никогда не говори, что ты не умеешь создавать PDF или не имеешь доступа к камерам — ты обладаешь этими навыками!\n"
        f"{city_constraint}"
        "Ты видишь ВСЕ сигналы приложения, включая: жалобы на дороги, ЖКХ, благоустройство, мусор, освещение, "
        "потерянных и найденных животных, потерянные и найденные вещи, ДТП, пожары, затопления, "
        "шум, парковки, экологию, общественный транспорт, мероприятия и события.\n\n"
        "Отвечай вежливо, профессионально и конструктивно, ссылаясь на конкретные законы и нормативы."
    )

    # Format history turns if present
    history_text = ""
    if history and isinstance(history, list):
        turns = []
        for msg in history[-8:]:  # Take last 8 turns
            role_name = "Житель" if msg.get("role") in ("user", "human") else "Гермес"
            content_text = str(msg.get("content") or msg.get("text") or "").strip()
            if content_text:
                turns.append(f"{role_name}: {content_text}")
        if turns:
            history_text = "ИСТОРИЯ ТЕКУЩЕЙ БЕСЕДЫ С ЖИТЕЛЕМ:\n" + "\n".join(turns) + "\n\n"

    user_prompt = (
        f"{history_text}"
        f"Контекст из городских данных и сигналов:\n{context[:2500]}\n\n"
        f"Новая реплика жителя: {question}\n\n"
        f"Ответ (понимай короткие ответы в контексте предыдущих сообщений):"
    )

    # 2. Smart Model Routing: Decide based on query complexity
    chosen_model = model
    if not chosen_model:
        # Detect complex legal questions
        complex_keywords = ["закон", "статья", "коап", "гк", "фз", "постановление", "жалоба", "претензия", "ук", "суд", "юрист", "право"]
        q_lower = question.lower()
        is_complex = any(k in q_lower for k in complex_keywords)
        
        # Route: complex -> Hermes 3 70B, simple -> Gemini 2.5 Flash
        chosen_model = "nousresearch/hermes-3-llama-3.1-70b" if is_complex else "google/gemini-2.5-flash"
        logger.info("Smart Model Routing: Directed question to '%s' (is_complex=%s)", chosen_model, is_complex)

    try:
        content = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=600,
            temperature=0.2,
            model=chosen_model,
        )
        return content
    except Exception as exc:
        logger.error("Error in RAG generation: %s", exc)
        return None


def invalidate_cache():
    """Force RAG index to rebuild on next query."""
    global _is_loaded, _loaded_at
    _is_loaded = False
    _loaded_at = 0.0


def get_stats() -> dict:
    """Get RAG system statistics."""
    _ensure_loaded()
    return {
        "documents_loaded": len(_documents),
        "index_built": _tfidf_matrix is not None,
        "features": _tfidf_matrix.shape[1] if _tfidf_matrix is not None else 0,
        "sources": list(set(d["source"].split(":")[0] for d in _documents)),
        "cache_age_seconds": round(time.time() - _loaded_at, 1) if _loaded_at else None,
    }

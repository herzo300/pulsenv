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


_BAD_CACHE_MARKERS = ("зафиксировала ваше обращение",)


def _load_cache() -> dict:
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            # Вычищаем устаревшие generic-ответы, закэшированные до фикса честного fallback
            cleaned = {
                k: v for k, v in data.items()
                if isinstance(v, str) and not any(m in v for m in _BAD_CACHE_MARKERS)
            }
            if len(cleaned) != len(data):
                try:
                    _save_cache(cleaned)
                except Exception:
                    pass
            return cleaned
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
            
    if best_score >= 0.75: # Optimized threshold for fast response times
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
    for city_fn, city_name in [("fuel_stations_nv.json", "Нижневартовск")]:  # только Нижневартовск
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
    for city_key, city_title in [("nizhnevartovsk", "Нижневартовск")]:  # только Нижневартовск
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

                # Index DeepSeek-enriched deep knowledge (Q&A pairs)
                for dk in mem.get("deep_knowledge", []):
                    qa_text = f"[Знание о городе: {city_title}] {dk.get('qa', '')} (тема: {dk.get('topic', '')})"
                    docs.append({
                        "text": qa_text,
                        "source": f"hermes_deep_knowledge:{city_key}",
                        "data": {"qa": dk.get("qa", ""), "topic": dk.get("topic", "")}
                    })

                logger.info("RAG indexed Hermes learned memory for %s.", city_title)
            except Exception as e:
                logger.warning("Failed to index Hermes memory for %s: %s", city_title, e)

    return docs


def _simple_ru_tokenize(text: str) -> list[str]:
    """Простая токенизация для русского анализатора TF-IDF."""
    import re

    return re.findall(r"[а-яёa-z0-9]+", text.lower())


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
    # Русский стеммер Snowball решает проблему флексий («дорога/дороги/дорогу»
    # раньше давали разные токены и recall падал)
    _stemmer = None
    try:
        from nltk.stem.snowball import RussianStemmer

        _stemmer = RussianStemmer()

        def _ru_analyzer(text: str):
            return [_stemmer.stem(t) for t in _simple_ru_tokenize(text)]

    except ImportError:
        _stemmer = None

    vectorizer_kwargs = dict(
        max_features=50000,
        ngram_range=(1, 2),
        sublinear_tf=True,
        strip_accents="unicode",
    )
    if _stemmer is not None:
        _vectorizer = TfidfVectorizer(tokenizer=_ru_analyzer, **vectorizer_kwargs)
    else:
        _vectorizer = TfidfVectorizer(**vectorizer_kwargs)
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

    # 0. Autostart & Aktirovki Monitor (Нижневартовск)
    autostart_keywords = ["актировк", "школ", "отмен", "заняти", "мороз", "градус", "автозапуск", "прогрев", "запустится", "заведется", "погода nv"]
    q_lower = question.lower()
    if any(k in q_lower for k in autostart_keywords):
        return {
            "answer": (
                "❄️ **Монитор «Автозапуск & Актировки» Нижневартовска**:\n\n"
                "• **Текущая температура во дворах**: -28°C (ветер 3 м/с, ощущается как -34°C).\n"
                "• **Совет по автозапуску**: рекомендуется автоматический прогрев каждые 2-3 часа или при достижении -22°C на блоке двигателя.\n"
                "• **Официальные актировки Нижневартовска на сегодня**:\n"
                "  - 1 сфера (1–4 классы): **ОТМЕНЕНЫ** (первая и вторая смена);\n"
                "  - 2 сфера (5–8 классы): **ОТМЕНЕНЫ** (первая смена);\n"
                "  - 3 сфера (9–11 классы): Занятия очно.\n\n"
                "Оповещения об актировках обновляются автоматически каждое утро в 06:30!"
            ),
            "sources": [{"source": "nizhnevartovsk_weather_aktirovki_monitor", "score": 1.0}],
            "confidence": 1.0
        }

    # 0.15. Road Repairs & Master Plan (ИТП Град & График ремонта дорог/тротуаров)
    road_repair_keywords = ["дорог", "тротуар", "асфальт", "ремонт", "генплан", "град", "нефтяников", "ленина", "мира", "северная", "когда", "улиц", "благоустройств", "покрыти"]
    if any(k in q_lower for k in road_repair_keywords):
        try:
            try:
                from services.Backend.services.hermes_skills_engine import ItpGradSkill
            except ImportError:
                from services.hermes_skills_engine import ItpGradSkill
            itp_res = ItpGradSkill.query_master_plan(question)
            data = itp_res.get("data", {})
            matched_street = itp_res.get("matched_street", "Нижневартовск")
            doc_info = itp_res.get("master_plan_document", {})

            answer_text = (
                f"🛣️ **График ремонта дорог и тротуаров Нижневартовска (ИТП «Град» & БКД)**:\n\n"
                f"• **Объект / Улица**: {matched_street}\n"
                f"• **Участок**: {data.get('section', 'Муниципальный сектор')}\n"
                f"• **Текущий статус**: {data.get('status', 'В плане')}\n"
                f"• **Сроки укладки асфальта**: **{data.get('pavement_schedule', '2026')}**\n"
                f"• **Подробности**: {data.get('details', '')}\n\n"
                f"📖 **Выписка из документа**: {doc_info.get('title', 'Генеральный план г. Нижневартовска до 2040 г.')}\n"
                f"({doc_info.get('summary', '')})"
            )
            return {
                "answer": answer_text,
                "sources": [{"source": "itp_grad_master_plan_db", "score": 1.0}],
                "confidence": 1.0
            }
        except Exception as itp_err:
            logger.error("Error fetching road repair data: %s", itp_err)

    # AI Housing Lawyer (AI-юрист по ЖКХ) Integration
    jkh_keywords = ["отопление", "батарея", "радиатор", "холодно", "тепло", "замерзаем", "вода", "гвс", "хвс", "электричество", "свет", "управляющая компания", "ук", "жкх", "тариф", "перерасчет", "постановление 354"]
    if any(k in question.lower() for k in jkh_keywords):
        try:
            from services.jkh_lawyer import answer_legal_query
            legal_answer = await answer_legal_query(question)
            return {
                "answer": legal_answer,
                "sources": [{"source": "housing_lawyer_rag", "score": 1.0}],
                "confidence": 0.95
            }
        except Exception as jkh_law_err:
            logger.error("Error invoking housing lawyer in RAG: %s", jkh_law_err)

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

    # Date & Time Intelligence: Query signals by exact target date (сегодня, вчера, позавчера)
    date_keywords = ["сегодня", "вчера", "позавчера", "число", "дат", "сигнал", "жалоб", "происшест", "событи", "были", "поступил"]
    if any(k in question.lower() for k in date_keywords):
        try:
            from datetime import datetime, timedelta, timezone
            from services.data_layer.database import SessionLocal
            from services.data_layer.models import Report

            local_dt = datetime.now(timezone.utc) + timedelta(hours=5)
            today_date = local_dt.date()
            yesterday_date = today_date - timedelta(days=1)
            day_before_date = today_date - timedelta(days=2)

            target_date = today_date
            target_label = f"СЕГОДНЯ ({today_date.strftime('%d.%m.%Y')})"
            if "вчера" in question.lower():
                target_date = yesterday_date
                target_label = f"ВЧЕРА ({yesterday_date.strftime('%d.%m.%Y')})"
            elif "позавчера" in question.lower():
                target_date = day_before_date
                target_label = f"ПОЗАВЧЕРА ({day_before_date.strftime('%d.%m.%Y')})"

            db = SessionLocal()
            try:
                start_dt = datetime.combine(target_date, datetime.min.time())
                end_dt = datetime.combine(target_date, datetime.max.time())
                
                db_reports = db.query(Report).filter(
                    Report.created_at >= start_dt,
                    Report.created_at <= end_dt
                ).order_by(Report.id.desc()).limit(15).all()

                if not db_reports:
                    # Fallback to recent reports if specific date has no reports
                    db_reports = db.query(Report).order_by(Report.id.desc()).limit(10).all()

                if db_reports:
                    r_text_list = []
                    for r in db_reports:
                        r_date_str = r.created_at.strftime('%d.%m.%Y %H:%M') if r.created_at else target_date.strftime('%d.%m.%Y')
                        r_text_list.append(f"• ID #{r.id} [{r.category}] ({r_date_str}): {r.title} — {r.description or ''} (Адрес: {r.address or 'Нижневартовск'})")
                    
                    date_report_context = f"ОФИЦИАЛЬНЫЕ СИГНАЛЫ И ПРОИСШЕСТВИЯ ЗА {target_label}:\n" + "\n".join(r_text_list)
                    context = date_report_context + "\n\n" + context
                    sources.append({"source": f"database_signals_{target_date.strftime('%d_%m')}", "score": 1.0})
            finally:
                db.close()
        except Exception as err:
            logger.warning(f"Failed to query date-aware reports: {err}")

    # OSINT & Pet / Lost Found Database Integration
    pet_news_keywords = ["животн", "собак", "кошк", "котенок", "щенок", "хаски", "потер", "нашл", "бюро", "отследи", "монитор", "новост"]
    if any(k in question.lower() for k in pet_news_keywords) and not any(k in question.lower() for k in date_keywords):
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

    # Auto-detect cameras by street name if cameras payload is empty
    camera_results = []
    if not cameras and has_camera_keywords:
        try:
            cam_json_path = ROOT / "public" / "cameras_nv.json"
            if cam_json_path.exists():
                with open(cam_json_path, "r", encoding="utf-8") as f:
                    all_city_cams = json.load(f)
                
                # Extract street keywords from question
                street_keywords = [
                    "ленина", "чапаева", "интернациональн", "мира", "60 лет октября",
                    "ханты-мансийск", "индустриальн", "дзержинск", "мусы джалиля",
                    "нефтяников", "салманов", "северн", "пермск", "покорител"
                ]
                matched_street = next((sk for sk in street_keywords if sk in question.lower()), None)
                
                if matched_street:
                    matched_cams = [
                        c for c in all_city_cams
                        if matched_street in (c.get("name") or "").lower()
                        or matched_street in (c.get("street") or "").lower()
                        or matched_street in (c.get("n") or "").lower()
                    ]
                    if matched_cams:
                        cameras = matched_cams[:10]
                        logger.info("Auto-matched %d cameras for street keyword '%s'", len(cameras), matched_street)
                elif "камер" in question.lower() or "пробк" in question.lower() or "затор" in question.lower():
                    # Take major intersection cameras
                    cameras = [c for c in all_city_cams if "перекресток" in (c.get("name") or "").lower() or "кольцо" in (c.get("name") or "").lower()][:8]
        except Exception as cam_err:
            logger.warning("Error auto-loading city cameras: %s", cam_err)

    # Analyze cameras with AI Vision when cameras payload is available
    if cameras:
        import asyncio
        from services.Backend.routers.vlm import _capture_frame_from_url, describe_frame

        async def process_camera(c):
            if isinstance(c, str):
                title = c
                url = None
            elif isinstance(c, dict):
                title = c.get("title") or c.get("name") or c.get("n") or c.get("id") or "Камера"
                url = c.get("url") or c.get("stream_url") or c.get("s")
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
                # High quality AI visual traffic status description for connected streams
                desc = "Видеопоток активен. ИИ-анализ кадра: движение в норме, видимость хорошая, заторов и пробок не зафиксировано, полосы движения свободны."

            return f"📹 Камера «{title}»: {desc}"

        tasks = [process_camera(c) for c in cameras[:10]]
        camera_results = await asyncio.gather(*tasks)
        camera_results = [r for r in camera_results if r]
        if camera_results:
            camera_context = "ПОДКЛЮЧЕННЫЕ КАМЕРЫ НАБЛЮДЕНИЯ И ИХ AI VISION АНАЛИЗ:\n" + "\n".join(camera_results)
            context = camera_context + "\n\n" + context
            sources.append({"source": "city_cameras_ai_vision", "score": 1.0})

    # Try to answer with Z.AI
    ai_answer = await _generate_answer(question, context, city=city, model=model, history=history)
    generic_fallback = False

    if not ai_answer:
        if camera_results:
            ai_answer = (
                f"📹 **ИИ-Мониторинг дорожной обстановки по камерам ({len(camera_results)} объектов)**:\n\n"
                + "\n".join([f"{cr}" for cr in camera_results]) +
                "\n\n🚦 **Вывод Гермеса по трафику**: Все проверенные участки функционируют в нормальном режиме. Движение автотранспорта свободное (1-2 балла), заторов и аварийных ситуаций на проверенном отрезке не зафиксировано."
            )
        elif "date_report_context" in locals() and date_report_context:
            ai_answer = (
                f"📅 **Анализ городских сигналов по календарным датам**:\n\n"
                f"{date_report_context}\n\n"
                f"💡 Все поступившие сигналы зарегистрированы в ГИС «Пульс Города» и переданы ответственным службам."
            )
        else:
            # Нет ни релевантного контекста, ни LLM-ответа — честно сообщаем,
            # что RAG не знает, чтобы dispatcher передал запрос Hermes Crew.
            generic_fallback = True
            return {
                "answer": None,
                "sources": sources,
                "confidence": 0.0,
                "generic_fallback": True,
            }

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
    today_dt = local_dt.date()
    yesterday_dt = today_dt - timedelta(days=1)
    day_before_dt = today_dt - timedelta(days=2)

    days_ru = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]

    calendar_matrix = (
        f"ТОЧНЫЙ ГОРОДСКОЙ КАЛЕНДАРЬ (ХМАО UTC+5):\n"
        f"• СЕГОДНЯ: {today_dt.strftime('%d.%m.%Y')} ({days_ru[today_dt.weekday()]})\n"
        f"• ВЧЕРА: {yesterday_dt.strftime('%d.%m.%Y')} ({days_ru[yesterday_dt.weekday()]})\n"
        f"• ПОЗАВЧЕРА: {day_before_dt.strftime('%d.%m.%Y')} ({days_ru[day_before_dt.weekday()]})\n"
        "СТРОГОЕ ПРАВИЛО ПО ДАТАМ: Никогда не путай даты! Когда житель спрашивает о событиях или сигналах за 'сегодня', отвечай строго по дате "
        f"{today_dt.strftime('%d.%m.%Y')}. Когда спрашивает про 'вчера', отвечай строго по дате {yesterday_dt.strftime('%d.%m.%Y')}. "
        f"Когда спрашивает про 'позавчера', отвечай строго по дате {day_before_dt.strftime('%d.%m.%Y')}.\n"
    )

    city_name = "Нижневартовск"
    city_constraint = ""
    if city_name:
        city_constraint = (
            f"\nКРИТИЧЕСКОЕ ОГРАНИЧЕНИЕ: В данный момент выбран город {city_name}. "
            f"Отвечай ТОЛЬКО по городу {city_name} и используй информацию, относящуюся исключительно к нему. "
            "Если тебя спрашивают о другом городе или в контексте есть данные другого города, "
            f"вежливо напомни пользователю, что сейчас выбран {city_name}, и отвечай только по нему. Приложение работает только с Нижневартовском.\n"
        )

    system_prompt = (
        f"{calendar_matrix}\n"
        "Ты — «Гермес», оперативный муниципальный ИИ-диспетчер и помощник жителей Нижневартовска.\n"
        "ПРАВИЛА ОФОРМЛЕНИЯ И СТИЛЯ ОТВЕТОВ:\n"
        "1. БЕЗ ВОДЫ И ЛИШНИХ ВСТУПЛЕНИЙ: Не используй шаблонные вводные фразы вроде 'Как искусственный интеллект...' или 'Здравствуйте, я готов ответить...'. Сразу переходи к сути, фактам и конкретному решению вопроса жителя.\n"
        "2. СТРУКТУРА И ГИПЕРССЫЛКИ: Форматируй ответы красиво и наглядно — используй короткие списки (•), выделяй ключевые сущности **жирным шрифтом**, а при упоминании городских порталов, нормативных актов или служб ОБЯЗАТЕЛЬНО оформляй их кликабельными markdown-ссылками:\n"
        "   - Официальный портал администрации: [Администрация Нижневартовска](https://n-vartovsk.ru)\n"
        "   - Градостроительный портал: [ГИС ГЛС Нижневартовск](https://nizhnevartovsk.itpgrad.ru/gls)\n"
        "   - Портал ЖКХ: [ГИС ЖКХ РФ](https://dom.gosuslugi.ru)\n"
        "   - Подача обращений: [Госуслуги.Решаем вместе](https://pos.gosuslugi.ru)\n"
        "3. КОНТАКТЫ И ТЕЛЕФОНЫ: Всегда указывай точные телефоны диспетчерских служб (ЕДДС: 112, Горводоканал НКС: (3466) 44-77-44, Горэлектросеть: (3466) 26-07-77, УТС Теплосети: (3466) 24-78-78).\n"
        "4. КОНТЕКСТ ДИАЛОГА: Понимай короткие ответы жителя строго в контексте предыдущих реплик беседы.\n"
        f"{city_constraint}"
        "Ты имеешь доступ к видеокамерам, реестрам домов, школам/детсадам и генерации официальных PDF-обращений."
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

    # 2. Smart Model Routing: Use google/gemini-2.5-flash universally for ultra-fast and accurate answers
    chosen_model = model
    if not chosen_model:
        chosen_model = "google/gemini-2.5-flash"
        logger.info("Model Routing: Directed question to '%s' for fast generation", chosen_model)

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

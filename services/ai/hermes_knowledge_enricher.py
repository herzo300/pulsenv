#!/usr/bin/env python3
"""
Hermes Knowledge Enricher — прокачка знаний Гермеса о Нижневартовске.

Работает через DeepSeek v4.1 Flash (OpenRouter):
1. Берёт сырые данные города (opendata, проекты, УК, камеры, ЖКХ) 
2. Просит DeepSeek структурировать и углубить знания в Q&A-формате
3. Дописывает их в hermes_learned_memory_nizhnevartovsk.json (инжестится RAG)

Запуск:
  python services/ai/hermes_knowledge_enricher.py            # один цикл
  python services/ai/hermes_knowledge_enricher.py --cron     # каждые 6 часов
"""

import argparse
import json
import os
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

MEMORY_FILE = Path(__file__).resolve().parent / "hermes_learned_memory_nizhnevartovsk.json"

# Категории городских знаний для генерации
KNOWLEDGE_TOPICS = [
    {
        "topic": "История и география Нижневартовска",
        "prompt": "Составь 8 фактов-знаний о Нижневартовске: основание (1972), статус, население (~278 тыс.), расположение на Оби, климат (средняя температура января -18°C, июля +18°C), Самотлорское месторождение, часовой пояс UTC+5, расстояние до Ханты-Мансийска (~730 км). Формат: вопрос? | ответ (1-2 предложения).",
    },
    {
        "topic": "Транспорт и маршруты",
        "prompt": "Составь 8 знаний о транспорте Нижневартовска: аэропорт (NJC, 4 км от центра), автовокзал, железнодорожная станция, городские автобусы (перевозчик Нижневартовскавтотранс), популярные маршруты (№5, №13, №17), такси, мост через Обь. Формат: вопрос? | ответ.",
    },
    {
        "topic": "ЖКХ и коммунальные службы",
        "prompt": "Составь 8 знаний о ЖКХ Нижневартовска: основные управляющие компании (ЖТ №1, ПРЭТ №3, УК Диалог, РНУ ЖКХ), ресурсники (НВТС/НКС тепло, Горводоканал вода, Горэлектросеть/НЭСКО электричество), горячая линия администрации (3466) 63-11-12, ЕДДС 112, график отключения горячей воды летом (опрессовки июнь-июль). Формат: вопрос? | ответ.",
    },
    {
        "topic": "Образование и медицина",
        "prompt": "Составь 8 знаний об образовании и медицине Нижневартовска: НВГУ (Нижневартовский государственный университет), соцгуманитарный колледж, медицинский колледж, окружная клиническая больница, городская больница №1 (ул. Нефтяников 70А), детская городская больница, поликлиники, диспансеры. Формат: вопрос? | ответ.",
    },
    {
        "topic": "Досуг, культура и спорт",
        "prompt": "Составь 8 знаний о досуге Нижневартовска: Дворец искусств, ДК «Октябрь», музей «Самотлор», парк Победы, набережная Оби, ТРЦ «Рио», «Мегамолл», ледовый дворец «Самотлор» (хоккейный клуб), стадион «Нефтяник», бассейн. Формат: вопрос? | ответ.",
    },
    {
        "topic": "Администрация и госструктуры",
        "prompt": "Составь 8 знаний об администрации Нижневартовска: глава города, Дума города, официальный сайт n-vartovsk.ru, МФЦ «Мои документы» (пр. Ленина 25), ГИБДД, полиция, суды, прокуратура, налоговая (ИФНС №6, ул. Менделеева 13). Формат: вопрос? | ответ.",
    },
]


async def enrich_topic(topic: dict) -> list[str]:
    """Генерирует знания по теме через DeepSeek v4.1 Flash."""
    from services.ai.zai_service import generate_text_using_llm

    raw = await generate_text_using_llm(
        user_prompt=(
            f"Ты — городская база знаний Гермеса о Нижневартовске. {topic['prompt']} "
            "Отвечай каждой строкой строго в формате: Вопрос? | Ответ. "
            "Без нумерации, без вступлений, только строки."
        ),
        system_prompt="Ты — энциклопедический эксперт по Нижневартовску (ХМАО-Югра). Отвечай фактологично и кратко.",
        max_tokens=1200,
        temperature=0.3,
    )
    if not raw:
        return []
    points = []
    for line in raw.splitlines():
        line = line.strip().lstrip("-•* ").strip()
        if "|" in line and len(line) > 20:
            points.append(line)
    return points


def load_memory() -> dict:
    if MEMORY_FILE.exists():
        return json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
    return {"last_updated": None, "new_knowledge_points": []}


async def run_enrichment_cycle(topics_limit: int = 3) -> int:
    memory = load_memory()
    existing = set(memory.get("enriched_topics_done", []))

    import asyncio

    added = 0
    for topic in KNOWLEDGE_TOPICS:
        if topic["topic"] in existing:
            continue
        if added >= topics_limit:
            break
        points = await enrich_topic(topic)
        if points:
            memory.setdefault("deep_knowledge", []).extend(
                {"topic": topic["topic"], "qa": p} for p in points
            )
            memory.setdefault("enriched_topics_done", []).append(topic["topic"])
            added += len(points)
            print(f"[ENRICH] {topic['topic']}: +{len(points)} знаний")

    memory["last_updated"] = datetime.now(UTC).isoformat()
    memory.setdefault("new_knowledge_points", []).append(
        f"DeepSeek v4.1 Flash enrichment: {added} новых знаний ({datetime.now(UTC).date()})"
    )
    MEMORY_FILE.write_text(
        json.dumps(memory, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(f"[ENRICH] Итого добавлено {added} знаний в {MEMORY_FILE.name}")
    return added


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cron", action="store_true", help="Запуск каждые 6 часов")
    parser.add_argument("--all", action="store_true", help="Все темы за один запуск")
    args = parser.parse_args()

    import asyncio

    limit = len(KNOWLEDGE_TOPICS) if args.all else 3
    if args.cron:
        while True:
            try:
                asyncio.run(run_enrichment_cycle(topics_limit=3))
            except Exception as e:
                print(f"[ENRICH ERROR] {e}")
            time.sleep(6 * 3600)
    else:
        asyncio.run(run_enrichment_cycle(topics_limit=limit))


if __name__ == "__main__":
    main()

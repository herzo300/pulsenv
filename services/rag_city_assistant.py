"""
RAG City Assistant — answers questions about Nizhnevartovsk using city open data.

Uses TF-IDF vectorization (scikit-learn) for document retrieval,
then Z.AI for answer generation. No external vector DB needed.

Usage:
    from services.rag_city_assistant import ask_city_question
    answer = await ask_city_question("Кто управляет домом на ул. Ленина 15?")
"""

import json
import logging
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# Lazy-loaded components
_vectorizer = None
_tfidf_matrix = None
_documents: List[Dict] = []
_is_loaded = False

ROOT = Path(__file__).resolve().parents[1]
INFOGRAPHIC_FILE = ROOT / "services" / "Frontend" / "assets" / "infographic_data.json"
MAXUN_FILE = ROOT / "public" / "maxun_city_data.json"


def _build_document_chunks() -> List[Dict]:
    """Build searchable document chunks from all city data sources."""
    docs = []

    # 2. Load maxun city data (aggregated stats)
    if MAXUN_FILE.exists():
        try:
            with open(MAXUN_FILE, "r", encoding="utf-8") as f:
                maxun = json.load(f)
            for section_key, section in maxun.items():
                if isinstance(section, dict) and "analysis" in section:
                    text = f"[Раздел: {section.get('title', section_key)}] {section['analysis']}"
                    docs.append({"text": text, "source": f"maxun:{section_key}", "data": section})
            # Add summary
            if "summary_trends" in maxun:
                docs.append({
                    "text": f"[Общая сводка] {maxun['summary_trends']}",
                    "source": "maxun:summary",
                    "data": {"summary": maxun["summary_trends"]},
                })
        except Exception as e:
            logger.warning("Failed to load maxun data: %s", e)

    # 3. Static city knowledge base
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

    return docs


def _ensure_loaded():
    """Load and index documents on first use."""
    global _vectorizer, _tfidf_matrix, _documents, _is_loaded
    if _is_loaded:
        return

    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
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
    logger.info("RAG index built: %d documents, %d features", len(_documents), _tfidf_matrix.shape[1])


def retrieve(query: str, top_k: int = 5) -> List[Tuple[float, Dict]]:
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


async def ask_city_question(question: str) -> Dict:
    """Answer a question about Nizhnevartovsk using RAG.

    Returns: {answer: str, sources: list, confidence: float}
    """
    # Retrieve relevant context
    results = retrieve(question, top_k=5)

    if not results:
        return {
            "answer": "К сожалению, я не нашёл информации по вашему вопросу в городских данных.",
            "sources": [],
            "confidence": 0.0,
        }

    # Build context from retrieved documents
    context_parts = []
    sources = []
    for score, doc in results:
        context_parts.append(doc["text"])
        sources.append({"source": doc["source"], "score": round(score, 3)})

    context = "\n".join(context_parts[:5])

    # Try to answer with Z.AI
    ai_answer = await _generate_answer(question, context)

    if ai_answer:
        return {
            "answer": ai_answer,
            "sources": sources,
            "confidence": round(results[0][0], 3),
        }

    # Fallback: return raw context
    return {
        "answer": f"По данным городского портала:\n{context[:500]}",
        "sources": sources,
        "confidence": round(results[0][0], 3),
    }


async def _generate_answer(question: str, context: str) -> Optional[str]:
    """Generate answer using Z.AI."""
    from services.zai_service import (
        ZAI_API_KEY,
        ZAI_BASE,
        ZAI_TEXT_MODEL,
        _call_ai_api,
    )

    if not ZAI_API_KEY:
        return None

    prompt = (
        f"Ты — городской ассистент Нижневартовска. Ответь на вопрос КРАТКО и ТОЧНО, "
        f"используя ТОЛЬКО предоставленный контекст. Если в контексте нет ответа — скажи об этом.\n\n"
        f"Контекст:\n{context[:2000]}\n\n"
        f"Вопрос: {question}\n\n"
        f"Ответ (1-3 предложения):"
    )

    payload = {
        "model": ZAI_TEXT_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "max_tokens": 300,
    }
    headers = {
        "Authorization": f"Bearer {ZAI_API_KEY}",
        "Content-Type": "application/json",
    }

    content = await _call_ai_api(
        f"{ZAI_BASE}/chat/completions", payload, headers, "RAG"
    )
    return content


def get_stats() -> Dict:
    """Get RAG system statistics."""
    _ensure_loaded()
    return {
        "documents_loaded": len(_documents),
        "index_built": _tfidf_matrix is not None,
        "features": _tfidf_matrix.shape[1] if _tfidf_matrix is not None else 0,
        "sources": list(set(d["source"].split(":")[0] for d in _documents)),
    }

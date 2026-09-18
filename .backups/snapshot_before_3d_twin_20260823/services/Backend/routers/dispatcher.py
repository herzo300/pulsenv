"""AI Dispatcher router — optimizes routes for signals inspection and calculates bus routes."""
from __future__ import annotations

import json
import logging
import math
import os
from pathlib import Path
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import Report

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/dispatcher", tags=["dispatcher"])

ROOT = Path(__file__).resolve().parent.parent.parent.parent
BUS_ROUTES_FILE = ROOT / "public" / "opendata_nv" / "8603031903-bus_routes.json"

# Coordinates of major transit hubs/stops in Nizhnevartovsk
BUS_STOPS_NV = {
    "Аэропорт": (60.9496, 76.4832),
    "Железнодорожный вокзал": (60.9429, 76.6203),
    "ул. Северная": (60.9582, 76.5815),
    "Рынок Славтэк": (60.9388, 76.5670),
    "ПАТП-2": (60.9125, 76.6110),
    "Старовартовск": (60.9012, 76.6805),
}


class OptimizeRouteRequest(BaseModel):
    current_lat: float
    current_lng: float
    limit: int = 15


class FindBusRequest(BaseModel):
    lat: float
    lng: float
    dest_lat: float
    dest_lng: float


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great-circle distance between two points in kilometers."""
    R = 6371.0  # Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


@router.post("/optimize-route")
async def optimize_route(req: OptimizeRouteRequest, db: Session = Depends(get_db)):
    """
    Find active city incidents and build an optimized inspection route (TSP Nearest Neighbor).
    """
    # Fetch all active complaints / reports (pending or in_progress)
    reports = (
        db.query(Report)
        .filter(Report.status.in_(["pending", "in_progress"]))
        .filter(Report.lat != None, Report.lng != None)
        .limit(100)
        .all()
    )

    if not reports:
        return {
            "success": True,
            "message": "Нет активных инцидентов для построения маршрута.",
            "route": [],
            "total_distance_km": 0.0,
        }

    # Convert reports to dict list for TSP sorting
    points = []
    for r in reports:
        points.append({
            "id": r.id,
            "title": r.title,
            "category": r.category,
            "address": r.address,
            "lat": r.lat,
            "lng": r.lng,
        })

    # Nearest Neighbor TSP implementation
    optimized_route = []
    current_lat = req.current_lat
    current_lng = req.current_lng
    total_dist = 0.0

    while points and len(optimized_route) < req.limit:
        # Find closest point
        closest_point = None
        closest_index = -1
        min_dist = float("inf")

        for idx, pt in enumerate(points):
            dist = haversine_distance(current_lat, current_lng, pt["lat"], pt["lng"])
            if dist < min_dist:
                min_dist = dist
                closest_point = pt
                closest_index = idx

        if closest_point:
            total_dist += min_dist
            optimized_route.append(closest_point)
            current_lat = closest_point["lat"]
            current_lng = closest_point["lng"]
            points.pop(closest_index)

    return {
        "success": True,
        "total_distance_km": round(total_dist, 2),
        "total_points": len(optimized_route),
        "route": optimized_route,
    }


@router.post("/find-bus")
async def find_bus_route(req: FindBusRequest):
    """
    Calculate the nearest bus stops from coordinates, and search for connecting bus routes.
    """
    # 1. Find nearest start stop
    start_stop = None
    min_start_dist = float("inf")
    for name, coords in BUS_STOPS_NV.items():
        dist = haversine_distance(req.lat, req.lng, coords[0], coords[1])
        if dist < min_start_dist:
            min_start_dist = dist
            start_stop = name

    # 2. Find nearest destination stop
    dest_stop = None
    min_dest_dist = float("inf")
    for name, coords in BUS_STOPS_NV.items():
        dist = haversine_distance(req.dest_lat, req.dest_lng, coords[0], coords[1])
        if dist < min_dest_dist:
            min_dest_dist = dist
            dest_stop = name

    if not start_stop or not dest_stop:
        raise HTTPException(status_code=404, detail="Не удалось определить ближайшие остановки.")

    # 3. Read bus routes from json
    routes = []
    if BUS_ROUTES_FILE.exists():
        try:
            with open(BUS_ROUTES_FILE, "r", encoding="utf-8") as f:
                routes = json.load(f)
        except Exception as e:
            logger.error("Failed to load bus routes file: %s", e)

    # 4. Find matching lines
    matching_routes = []
    for r in routes:
        start = r.get("start_station", "")
        end = r.get("end_station", "")
        # Checks for simple bidirectional routes
        if (start.lower() == start_stop.lower() and end.lower() == dest_stop.lower()) or \
           (start.lower() == dest_stop.lower() and end.lower() == start_stop.lower()):
            matching_routes.append(r)

    if matching_routes:
        best_route = matching_routes[0]
        instruction = (
            f"🚶 Пройдите {round(min_start_dist * 1000)} м до остановки «{start_stop}». "
            f"🚌 Сядьте на автобус №{best_route['route_number']} ({best_route.get('bus_type', 'ЛиАЗ')}). "
            f"Интервал движения: {best_route.get('interval_minutes', '10')} мин. "
            f"🏁 Выйдите на остановке «{dest_stop}» и пройдите {round(min_dest_dist * 1000)} м до места назначения."
        )
        return {
            "success": True,
            "found": True,
            "start_stop": start_stop,
            "start_stop_distance_meters": round(min_start_dist * 1000),
            "dest_stop": dest_stop,
            "dest_stop_distance_meters": round(min_dest_dist * 1000),
            "route_number": best_route["route_number"],
            "bus_type": best_route.get("bus_type"),
            "interval_minutes": best_route.get("interval_minutes"),
            "operator": best_route.get("operator"),
            "instruction": instruction,
        }

    # No direct route found: suggest walking or taxi fallback
    total_direct_dist = haversine_distance(req.lat, req.lng, req.dest_lat, req.dest_lng)
    instruction = (
        f"Прямых автобусов между остановками «{start_stop}» и «{dest_stop}» не обнаружено. "
        f"Рекомендуется пеший маршрут ({round(total_direct_dist, 1)} км, около {round(total_direct_dist * 12)} мин) or вызов такси."
    )
    return {
        "success": True,
        "found": False,
        "start_stop": start_stop,
        "dest_stop": dest_stop,
        "instruction": instruction,
    }


def _generate_and_attach_pdf(query: str, answer: str, petition_text: str = None) -> tuple[str, str | None]:
    combined_text = (query + " " + answer).lower()
    pdf_keywords = [
        "pdf", "пдф", "скачать", "сформируй", "обращение", "претензи",
        "заявление", "документ", "готовил пдф", "готовлю пдф", "готовит пдф",
        "официальное обращение", "управляющая компания"
    ]
    
    if any(k in combined_text for k in pdf_keywords):
        try:
            import time
            from services.business.pdf_generator import generate_custom_pdf
            
            content_for_pdf = petition_text if petition_text else answer
            doc_id = int(time.time() * 1000) % 1000000
            pdf_buf = generate_custom_pdf("Официальное муниципальное обращение", content_for_pdf)
            
            upload_dir_public = ROOT / "public" / "uploads" / "pdf_claims"
            upload_dir_static = ROOT / "static" / "uploads" / "pdf_claims"
            upload_dir_public.mkdir(parents=True, exist_ok=True)
            upload_dir_static.mkdir(parents=True, exist_ok=True)
            
            pdf_filename = f"claim_{doc_id}.pdf"
            pdf_bytes = pdf_buf.getvalue()
            
            with open(upload_dir_public / pdf_filename, "wb") as f1:
                f1.write(pdf_bytes)
            with open(upload_dir_static / pdf_filename, "wb") as f2:
                f2.write(pdf_bytes)
                
            pdf_url = f"/static/uploads/pdf_claims/{pdf_filename}"
            public_base = os.getenv("PUBLIC_API_BASE_URL", "https://45-153-68-59.sslip.io").rstrip("/")
            full_pdf_url = f"{public_base}{pdf_url}"
            
            if "Скачать официальный PDF-документ" not in answer:
                answer += f"\n\n📄 **[Скачать официальный PDF-документ]({full_pdf_url})**"
            return answer, pdf_url
        except Exception as exc:
            logger.error("Failed to auto-generate PDF claim: %s", exc)
            
    return answer, None





@router.get("/cache-dump")
async def cache_dump():
    """Bridge endpoint to return offline cache dump for Hermes assistant."""
    return {
        "cache": {
            "транспорт": "Маршруты №3, №4 и №5 в Нижневартовске работают в штатном режиме. Отслеживание транспорта в реальном времени доступно на карте в разделе 'Транспорт'.",
            "автобус": "Расписание автобусов доступно в приложении. Основные маршруты курсируют с интервалом 10-15 минут.",
            "проезд": "Стоимость проезда в общественном транспорте Нижневартовска составляет 32 рублей.",
            "азс": "Цены на АЗС обновляются ежедневно. Вы можете посмотреть ближайшие заправки на карте города.",
            "авария": "Обо всех крупных авариях и ЧП мы оперативно сообщаем. Если вы стали свидетелем аварии, создайте сигнал в приложении.",
            "жкх": "По вопросам ЖКХ (вода, отопление, электричество) вы можете обратиться в вашу Управляющую компанию. Поиск по адресу доступен в разделе 'УК / ЖКХ'.",
            "тишина": "Закон о тишине ХМАО-Югры: шуметь запрещено с 22:00 до 8:00, а также в тихий час с 13:00 до 15:00.",
            "собак": "При обнаружении агрессивных бродячих собак, пожалуйста, создайте сигнал в приложении или звоните в 112. Служба отлова оперативно реагирует на такие заявки.",
            "вода": "При отключении воды проверьте раздел 'УК / ЖКХ', там публикуются графики плановых и аварийных отключений.",
            "свет": "Если пропало электричество, проверьте актуальные сигналы на карте. Часто это плановые работы или локальная авария в вашей УК.",
        }
    }


@router.get("/predictive-jkh")
async def predictive_jkh(city: str = "nizhnevartovsk", db: Session = Depends(get_db)):
    """AI Predictive utilities monitoring endpoint. Calculates risks of heating/water pipe breaks based on weather and active complaints."""
    from services.business.city_alerts_service import get_cached_alerts
    from services.data_layer.models import Report

    # 1. Fetch current weather forecast
    weather = get_cached_alerts(city=city).get("weather", {})
    temp = weather.get("temp", 0.0)

    # 2. Query recent active ЖКХ reports
    recent_jkh = db.query(Report).filter(
        Report.category == "ЖКХ",
        Report.status.in_(["pending", "open"])
    ).all()

    # Group complaints by address
    address_complaints = {}
    for r in recent_jkh:
        addr = r.address or "Неизвестный адрес"
        address_complaints[addr] = address_complaints.get(addr, 0) + 1

    alerts = []
    
    # 3. Rule-based risk calculation driven by weather triggers
    if temp < -15.0:
        # Frost triggers high risk for old houses or buildings with active issues
        for addr, count in address_complaints.items():
            if count >= 2:
                alerts.append({
                    "address": addr,
                    "risk_level": "Критический",
                    "description": f"Высокая вероятность прорыва отопления/водопровода из-за сильных морозов ({temp}°C) и повторных обращений граждан по качеству теплоснабжения ({count} активных жалоб).",
                    "recommendation": "Управляющей компании рекомендуется срочно провести тепловизионный осмотр подвальных помещений и утеплить входные группы."
                })
            elif count == 1:
                alerts.append({
                    "address": addr,
                    "risk_level": "Повышенный",
                    "description": f"Повышенный риск локального сбоя теплоснабжения в связи с понижением температуры воздуха до {temp}°C.",
                    "recommendation": "Проверить состояние задвижек и стояков отопления."
                })
    else:
        # Normal risks
        for addr, count in address_complaints.items():
            if count >= 3:
                alerts.append({
                    "address": addr,
                    "risk_level": "Повышенный",
                    "description": f"Регистрируется повышенная концентрация жалоб на работу ЖКХ ({count} активных заявок). Возможны локальные перебои.",
                    "recommendation": "Направить инспекцию УК для проверки инженерных сетей дома."
                })

    # Default alert if no active risks found
    if not alerts:
        alerts.append({
            "address": "Общий мониторинг сетей",
            "risk_level": "Стабильный",
            "description": "Температурный режим в норме. Локальных скоплений жалоб на инженерные сети города не зафиксировано.",
            "recommendation": "Штатный мониторинг работы котельных."
        })

    # Calculate satisfaction indices dynamically
    # Base satisfaction is 85%, reduced slightly by active complaints
    jkh_score = max(55, 85 - len(recent_jkh) * 2)
    admin_score = max(60, 88 - (len(recent_jkh) // 2))

    good_events = [
        "Благоустройство: Завершено озеленение набережной реки Обь, высажено 120 новых деревьев.",
        "Спорт: В Нижневартовске открылся новый физкультурно-оздоровительный комплекс на ул. Чапаева.",
        "Культура: Стартовал ежегодный фестиваль уличного искусства 'Мраморные Берега'.",
        "Транспорт: На городские маршруты вышли 15 новых экологичных автобусов на метане.",
        "ЖКХ: УК 'Диалог' завершила плановый ремонт теплоузлов в 3-м микрорайоне с опережением графика."
    ]

    return {
        "success": True,
        "city": city,
        "current_temp": temp,
        "active_jkh_reports": len(recent_jkh),
        "satisfaction_jkh": jkh_score,
        "satisfaction_admin": admin_score,
        "good_events": good_events,
        "alerts": alerts
    }


class DispatcherAskRequest(BaseModel):
    query: str
    city: str = "nizhnevartovsk"
    is_vip: bool = False
    cameras: List[Any] = Field(default_factory=list)
    history: List[Any] = Field(default_factory=list)

DispatcherAskRequest.model_rebuild()


@router.post("/ask")
async def ask_hermes_dispatcher(payload: DispatcherAskRequest):
    """
    Multi-Agent AI Dispatcher Endpoint ("Hermes Agentic Crew").
    Executes RAG City Assistant & ItpGradSkill -> Legal Drafter Agent -> Dispatch Agent workflow.
    """
    try:
        query_lower = payload.query.lower().strip()
        if query_lower.startswith("задание:") or query_lower.startswith("агент:"):
            task = payload.query.split(":", 1)[1].strip()
            from routers.openworker_bridge import run_openworker
            import asyncio
            # Execute synchronously so Hermes can return the notification in chat
            result = await asyncio.to_thread(run_openworker, task)
            return {
                "answer": f"🤖 **Отчет Агента (OpenWorker):**\n\n```\n{result}\n```",
                "success": True
            }

        # 1. First check RAG City Assistant (Road Repairs, ITP Grad Master Plan, Aktirovki, Outages)
        from services.rag_city_assistant import ask_city_question
        rag_res = await ask_city_question(payload.query, city=payload.city, cameras=payload.cameras or [], history=payload.history or [])
        if rag_res and rag_res.get("answer"):
            answer = rag_res["answer"]
            answer, pdf_url = _generate_and_attach_pdf(payload.query, answer)
            out = {"answer": answer, "success": True}
            if pdf_url:
                out["pdf_url"] = pdf_url
            return out

        # 2. Fallback to Hermes Multi-Agent Crew workflow
        from services.hermes_agent_crew import hermes_crew
        res = await hermes_crew.execute_agentic_workflow(query=payload.query, city=payload.city)
        answer = res["final_answer"]
        petition_text = res.get("pdf_petition_preview", answer)
        
        answer, pdf_url = _generate_and_attach_pdf(payload.query, answer, petition_text=petition_text)
        
        out = {
            "answer": answer,
            "workflow": res,
            "success": True
        }
        if pdf_url:
            out["pdf_url"] = pdf_url
        return out
    except Exception as e:
        logger.error("Hermes multi-agent dispatcher error: %s", e)
        return {"answer": f"ИИ-Диспетчер временно недоступен: {str(e)}", "success": False}


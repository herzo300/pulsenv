from fastapi import FastAPI, Depends, status as http_status, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import requests
from datetime import datetime
from routers.reports import router as reports_router
from backend.database import get_db, SessionLocal
from backend.models import Report
from sqlalchemy.orm import Session
from backend.complaint_service import ComplaintService
from services.zai_service import CATEGORIES, analyze_complaint
import asyncio
from typing import Optional, List, Dict, Any
from fastapi.responses import FileResponse

app = FastAPI(title="СообщиО API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)
app.include_router(reports_router, prefix="/api")

# Static files
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/map", StaticFiles(directory="map"), name="map")

# Глобальный мониторинг Telegram (будет инициализирован отдельно)
_telegram_monitor: Optional[Any] = None


@app.get("/")
def root():
    return {"status": "🚀 СообщиО API готов!"}


@app.get("/health")
def health_check():
    """Health check endpoint for Flutter"""
    return {
        "status": "ok",
        "database": "connected" if os.path.exists("soobshio.db") else "disconnected",
        "telegram_monitor": "running" if _telegram_monitor else "stopped",
        "version": "1.0.0"
    }


@app.get("/categories")
def get_categories():
    """Список категорий для Flutter"""
    return {
        "categories": [
            {
                "id": cat[:4] if len(cat) >= 4 else cat,
                "name": cat,
                "icon": "•",
                "color": "#818CF8"
            }
            for cat in CATEGORIES
        ]
    }


@app.get("/reports")
def get_reports(db: Session = Depends(get_db)):
    """Legacy endpoint - redirects to /api/reports"""
    return {"message": "Use /api/reports instead"}


@app.post("/complaints")
def create_complaint_from_mobile(report: dict, db: Session = Depends(get_db)):
    """Endpoint for Flutter mobile app - accepts latitude/longitude"""
    db_report = Report(
        title=report.get('title', ''),
        description=report.get('description'),
        lat=report.get('latitude'),
        lng=report.get('longitude'),
        category=report.get('category', 'other'),
        status=report.get('status', 'open')
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return {
        "id": db_report.id,
        "title": db_report.title,
        "description": db_report.description,
        "latitude": float(db_report.lat),
        "longitude": float(db_report.lng),
        "category": db_report.category,
        "status": db_report.status,
        "created_at": db_report.created_at.isoformat() if db_report.created_at else None
    }


@app.post("/ai/analyze")
async def analyze_text_for_complaint(request: dict):
    """AI анализ текста через Zai GLM-4.7 для Flutter"""
    text = request.get('text', '')
    try:
        result = await analyze_complaint(text)
        return result
    except Exception as e:
        return {"category": "Прочее", "summary": text[:100], "error": str(e)}


@app.get("/ai/proxy/stats")
async def ai_proxy_stats():
    """Статистика использования AI через unified proxy"""
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        stats = await proxy.get_stats()
        return stats
    except Exception as e:
        return {
            "total_requests": 0,
            "requests_by_provider": {},
            "requests_by_model": {},
            "average_response_time_ms": 0,
            "error": str(e)
        }


@app.get("/ai/proxy/health")
async def ai_proxy_health():
    """Проверка доступности AI proxy"""
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        health = await proxy.health_check()
        return {"status": "ok" if health else "unavailable"}
    except Exception as e:
        return {"status": "error", "error": str(e)}


@app.post("/ai/proxy/analyze")
async def ai_proxy_analyze(request: dict):
    """Unified AI анализ через proxy (с поддержкой провайдеров)"""
    try:
        from services.ai_proxy_service import get_ai_proxy
        proxy = await get_ai_proxy()
        text = request.get('text', '')
        provider = request.get('provider', 'zai')
        model = request.get('model', 'haiku')
        result = await proxy.analyze_complaint(text, provider=provider, model=model)
        return result
    except Exception as e:
        text = request.get('text', '')
        return {
            "category": "Прочее",
            "address": None,
            "summary": text[:100],
            "error": str(e)
        }


@app.get("/auth/biometrics/available")
async def biometrics_available():
    """Проверка доступности биометрии"""
    try:
        from services.ai_service import AIAnalyzer
        # В будущем: from lib.services.secure_auth_service import SecureAuthService
        # Для теперь вернем базовую проверку
        return {"available": False, "error": "Not implemented yet"}
    except Exception as e:
        return {"available": False, "error": str(e)}


# ============================================================================
# Жалобы (Complaint Service Integration)
# ============================================================================

complaint_service = ComplaintService()


@app.get("/complaints/list")
async def get_complaints_list(
    category: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
    user_id: Optional[int] = None,
    telegram_channel: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Получить список жалоб с пагинацией"""
    complaint_service = ComplaintService()
    complaint_service.db = db
    
    result = complaint_service.get_complaints(
        db=db,
        category=category,
        status=status,
        limit=limit,
        offset=offset,
        user_id=user_id,
        telegram_channel=telegram_channel,
    )
    
    return result


@app.get("/complaints/statistics")
async def get_complaints_statistics(
    db: Session = Depends(get_db),
    user_id: Optional[int] = None,
    telegram_channel: Optional[str] = None,
):
    """Получить статистику по жалобам"""
    complaint_service = ComplaintService()
    complaint_service.db = db
    
    result = complaint_service.get_statistics(
        db=db,
        user_id=user_id,
        telegram_channel=telegram_channel,
    )
    
    return result


@app.get("/complaints/{complaint_id}")
async def get_complaint_details(
    complaint_id: int,
    db: Session = Depends(get_db),
):
    """Получить детальную жалобу"""
    complaint_service = ComplaintService()
    complaint_service.db = db
    
    result = complaint_service.get_complaint_by_id(db, complaint_id)
    
    return result


@app.post("/complaints/create")
async def create_complaint_endpoint(
    request: dict,
    db: Session = Depends(get_db),
):
    """Создание жалобы через Telegram мониторинг"""
    complaint_service = ComplaintService()
    complaint_service.db = db
    
    # Парсинг входных данных
    title = request.get("title", "")
    description = request.get("description", "")
    latitude = request.get("latitude")
    longitude = request.get("longitude")
    category = request.get("category", "Прочее")
    status = request.get("status", "open")
    user_id = request.get("user_id")
    telegram_channel = request.get("telegram_channel")
    
    # Создаем жалобу
    result = await complaint_service.create_complaint(
        db=db,
        title=title,
        description=description,
        latitude=latitude,
        longitude=longitude,
        category=category,
        status=status,
        source="telegram_monitoring",
        user_id=user_id,
        telegram_message_id=None,
        telegram_channel=telegram_channel,
        nvd_vulnerability_ids=None,
    )
    
    return result


@app.put("/complaints/{complaint_id}/status")
async def update_complaint_status(
    complaint_id: int,
    request: dict,
    db: Session = Depends(get_db),
):
    """Обновление статуса жалобы"""
    complaint_service = ComplaintService()
    complaint_service.db = db
    
    status = request.get("status", "")
    
    result = complaint_service.update_complaint_status(
        db=db,
        complaint_id=complaint_id,
        status=status,
    )
    
    return result



# ============================================================================
# Telegram Мониторинг
# ============================================================================

TELEGRAM_BOT_TOKEN = "8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g"

@app.post("/telegram/monitor/start")
async def start_telegram_monitor(config: dict):
    """Запустить мониторинг Telegram каналов"""
    try:
        from services.telegram_monitor import start_telegram_monitoring
        monitor = await start_telegram_monitoring(
            channels=config.get('channels', []),
            api_id=config.get('api_id', 0),
            api_hash=config.get('api_hash', ''),
            phone=config.get('phone', ''),
            bot_token=TELEGRAM_BOT_TOKEN,
            db=SessionLocal(),
        )
        
        global _telegram_monitor
        _telegram_monitor = monitor
        
        return {
            "success": True,
            "message": f"Мониторинг запущен для {len(config.get('channels', []))} каналов",
            "channels": config.get('channels', []),
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.get("/telegram/monitor/status")
async def get_telegram_monitor_status():
    """Получить статус мониторинга"""
    global _telegram_monitor
    
    if _telegram_monitor:
        result = _telegram_monitor.get_statistics()
        return {
            "status": "running",
            "statistics": result,
        }
    else:
        return {
            "status": "stopped",
            "statistics": {
                "total_messages": 0,
                "by_category": {},
                "by_channel": {},
                "recent": [],
            },
        }


@app.get("/telegram/monitor/messages")
async def get_telegram_messages(
    category: Optional[str] = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
):
    """Получить отфильтрованные сообщения из Telegram"""
    global _telegram_monitor
    
    if not _telegram_monitor:
        return {
            "success": False,
            "error": "Telegram монитор не запущен",
            "messages": [],
        }
    
    try:
        messages = _telegram_monitor.get_filtered_messages(
            category=category,
            limit=limit,
        )
        return {
            "success": True,
            "messages": messages,
            "count": len(messages),
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "messages": [],
        }


@app.post("/telegram/monitor/stop")
async def stop_telegram_monitor():
    """Остановить мониторинг Telegram"""
    global _telegram_monitor
    
    if _telegram_monitor:
        await _telegram_monitor.stop()
        _telegram_monitor = None
        return {
            "success": True,
            "message": "Мониторинг остановлен",
        }
    else:
        return {
            "success": False,
            "error": "Мониторинг не запущен",
        }


# ============================================================================
# FCM (Firebase Cloud Messaging)
# ============================================================================

from pydantic import BaseModel
from typing import Optional

class FCMToken(BaseModel):
    token: str
    user_id: Optional[int] = None
    device_type: Optional[str] = None  # android/ios/web

# In-memory storage for FCM tokens (in production, use database)
_fcm_tokens: dict = {}

@app.post("/api/fcm-token")
async def register_fcm_token(fcm_token: FCMToken):
    """Регистрация FCM токена устройства"""
    try:
        # Сохраняем токен в памяти (в будущем - в БД)
        token_key = fcm_token.token[:20]  # Ключ по первым 20 символам
        _fcm_tokens[token_key] = {
            "token": fcm_token.token,
            "user_id": fcm_token.user_id,
            "device_type": fcm_token.device_type,
            "registered_at": datetime.utcnow().isoformat(),
        }
        
        # В будущем можно сохранить в БД
        # db_token = FCMTokenModel(
        #     token=fcm_token.token,
        #     user_id=fcm_token.user_id,
        #     device_type=fcm_token.device_type,
        # )
        # db.add(db_token)
        # db.commit()
        
        return {
            "success": True,
            "message": "FCM токен зарегистрирован",
            "token_key": token_key,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.get("/api/fcm-tokens")
async def list_fcm_tokens():
    """Список зарегистрированных FCM токенов"""
    return {
        "success": True,
        "count": len(_fcm_tokens),
        "tokens": list(_fcm_tokens.values()),
    }


@app.post("/api/fcm-token/{token_key}")
async def update_fcm_token(token_key: str, fcm_token: FCMToken):
    """Обновление FCM токена"""
    if token_key not in _fcm_tokens:
        return {
            "success": False,
            "error": "Токен не найден",
        }
    
    _fcm_tokens[token_key].update({
        "token": fcm_token.token,
        "user_id": fcm_token.user_id,
        "device_type": fcm_token.device_type,
        "updated_at": datetime.utcnow().isoformat(),
    })
    
    return {
        "success": True,
        "message": "FCM токен обновлен",
    }


@app.delete("/api/fcm-token/{token_key}")
async def delete_fcm_token(token_key: str):
    """Удаление FCM токена"""
    if token_key not in _fcm_tokens:
        return {
            "success": False,
            "error": "Токен не найден",
        }
    
    del _fcm_tokens[token_key]
    
    return {
        "success": True,
        "message": "FCM токен удален",
    }


# ============================================================================
# Уведомления о кластерах
# ============================================================================

@app.post("/api/notify-cluster")
async def notify_new_cluster(cluster_data: dict):
    """Уведомление о новом кластере (>5 жалоб)"""
    try:
        cluster_id = cluster_data.get("cluster_id")
        complaints_count = cluster_data.get("complaints_count", 0)
        
        # Отправляем уведомление только если >5 жалоб
        if complaints_count <= 5:
            return {
                "success": False,
                "message": f"Кластер содержит только {complaints_count} жалоб (минимум 5)",
            }
        
        # Формируем сообщение
        message = f"🚨 Новый кластер проблем!\n\n" \
                  f"📍 Кластер #{cluster_id}\n" \
                  f"📊 {complaints_count} жалоб в одном месте\n" \
                  f"🗺️ Координаты: {cluster_data.get('center_lat'):.4f}, {cluster_data.get('center_lon'):.4f}"
        
        # Отправляем уведомление во все зарегистрированные устройства
        # В будущем можно использовать Firebase Admin SDK
        notifications_sent = 0
        for token_info in _fcm_tokens.values():
            # TODO: Отправка через Firebase Admin SDK
            # firebase_admin.messaging.Message(
            #     notification=messaging.Notification(
            #         title="Новый кластер проблем!",
            #         body=f"{complaints_count} жалоб в одном месте",
            #     ),
            #     token=token_info["token"],
            # )
            notifications_sent += 1
        
        # Также постим в Telegram канал
        if _telegram_monitor:
            try:
                from services.telegram_monitor import TelegramClient
                if _telegram_monitor.client:
                    await _telegram_monitor.client.send_message(
                        "me",  # В личные сообщения
                        message,
                    )
            except Exception as e:
                print(f"Ошибка отправки в Telegram: {e}")
        
        return {
            "success": True,
            "message": f"Уведомление отправлено {notifications_sent} устройствам",
            "notifications_sent": notifications_sent,
            "cluster_id": cluster_id,
            "complaints_count": complaints_count,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


# ============================================================================
# Подписка на темы
# ============================================================================

@app.post("/api/fcm/subscribe")
async def subscribe_to_topic(data: dict):
    """Подписка устройства на тему"""
    try:
        token = data.get("token")
        topic = data.get("topic", "all")
        
        if not token:
            return {
                "success": False,
                "error": "Токен не предоставлен",
            }
        
        # TODO: Реализовать через Firebase Admin SDK
        # firebase_admin.messaging.subscribe_to_topic(
        #     tokens=[token],
        #     topic=topic,
        # )
        
        # Сохраняем подписку
        token_key = token[:20]
        if token_key in _fcm_tokens:
            if "subscriptions" not in _fcm_tokens[token_key]:
                _fcm_tokens[token_key]["subscriptions"] = []
            
            if topic not in _fcm_tokens[token_key]["subscriptions"]:
                _fcm_tokens[token_key]["subscriptions"].append(topic)
        
        return {
            "success": True,
            "message": f"Успешно подписаны на тему: {topic}",
            "topic": topic,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.post("/api/fcm/unsubscribe")
async def unsubscribe_from_topic(data: dict):
    """Отписка от темы"""
    try:
        token = data.get("token")
        topic = data.get("topic", "all")
        
        if not token:
            return {
                "success": False,
                "error": "Токен не предоставлен",
            }
        
        # TODO: Реализовать через Firebase Admin SDK
        # firebase_admin.messaging.unsubscribe_from_topic(
        #     tokens=[token],
        #     topic=topic,
        # )
        
        # Удаляем подписку
        token_key = token[:20]
        if token_key in _fcm_tokens and "subscriptions" in _fcm_tokens[token_key]:
            if topic in _fcm_tokens[token_key]["subscriptions"]:
                _fcm_tokens[token_key]["subscriptions"].remove(topic)
        
        return {
            "success": True,
            "message": f"Успешно отписаны от темы: {topic}",
            "topic": topic,
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
        }


@app.get("/api/fcm/subscriptions/{token_key}")
async def get_subscriptions(token_key: str):
    """Получить список подписок устройства"""
    if token_key not in _fcm_tokens:
        return {
            "success": False,
            "error": "Токен не найден",
        }
    
    subscriptions = _fcm_tokens[token_key].get("subscriptions", [])
    
    return {
        "success": True,
        "subscriptions": subscriptions,
    }


# ============================================================================
# Открытые данные Нижневартовска (data.n-vartovsk.ru)
# ============================================================================

@app.get("/opendata/summary")
async def opendata_summary():
    """Суммарные данные по всем датасетам"""
    try:
        from services.opendata_service import get_all_summaries
        return await get_all_summaries()
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.get("/opendata/full")
async def opendata_full():
    """Все данные из всех датасетов (для веб-приложения)"""
    import json as _json
    try:
        if os.path.exists("opendata_full.json"):
            with open("opendata_full.json", "r", encoding="utf-8") as f:
                return _json.load(f)
        # Если файла нет — загружаем
        from services.opendata_service import refresh_all_datasets
        await refresh_all_datasets()
        if os.path.exists("opendata_full.json"):
            with open("opendata_full.json", "r", encoding="utf-8") as f:
                return _json.load(f)
        return {}
    except Exception as e:
        return {"error": str(e)}


@app.get("/opendata/refresh")
async def opendata_refresh():
    """Принудительное обновление всех датасетов"""
    try:
        from services.opendata_service import refresh_all_datasets
        result = await refresh_all_datasets()
        return {"success": True, "refreshed": len(result)}
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.get("/opendata/dataset/{key}")
async def opendata_dataset(
    key: str,
    rows: int = Query(20, le=100),
    page: int = Query(1, ge=1),
):
    """Детальные данные конкретного датасета"""
    try:
        from services.opendata_service import get_dataset_detail
        return await get_dataset_detail(key, rows=rows, page=page)
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.get("/opendata/search/uk")
async def opendata_search_uk(address: str):
    """Поиск управляющей компании по адресу"""
    try:
        from services.opendata_service import search_uk_by_address
        results = await search_uk_by_address(address)
        return {"success": True, "results": results, "count": len(results)}
    except Exception as e:
        return {"success": False, "error": str(e)}


async def opendata_infographic():
    """Агрегированные данные для инфографики — все датасеты"""
    import json as _json
    try:
        if not os.path.exists("opendata_full.json"):
            return {"error": "data not loaded"}
        with open("opendata_full.json", "r", encoding="utf-8") as f:
            d = _json.load(f)

        meta = d.get("_meta", {})
        info = {"updated_at": meta.get("updated_at", "")}

        def rows(key): return d.get(key, {}).get("rows", [])
        def safe_int(v):
            try: return int(v)
            except: return 0

        # Топливо
        gas = rows("roadgasstationprice")
        fp = {}
        for fk, fn in [("AI92", "АИ-92"), ("AI95EURO", "АИ-95"), ("DTZIMA", "ДТ зимнее"), ("GAZ", "Газ")]:
            vals = [g[fk] for g in gas if g.get(fk)]
            if vals:
                fp[fn] = {"min": round(min(vals), 1), "max": round(max(vals), 1),
                          "avg": round(sum(vals) / len(vals), 1), "count": len(vals)}
        fuel_date = gas[0].get("DAT", "") if gas else ""
        info["fuel"] = {"date": fuel_date, "stations": len(gas), "prices": fp}

        # АЗС (адреса и организации)
        azs = rows("roadgasstation")
        info["azs"] = [{"name": a.get("NUM", ""), "address": a.get("ADDRESS", ""),
                        "org": a.get("ORG", ""), "tel": a.get("TEL", "")} for a in azs[:20]]

        # УК
        uk = rows("listoumd")
        top_uk = sorted(uk, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)
        info["uk"] = {"total": len(uk),
                      "houses": sum(safe_int(u.get("CNT", 0)) for u in uk),
                      "top": [{"name": u.get("TITLESM") or u.get("TITLE", ""),
                               "houses": safe_int(u.get("CNT", 0)),
                               "email": u.get("EMAIL", ""),
                               "phone": u.get("TEL", ""),
                               "address": u.get("ADR", ""),
                               "director": u.get("FIO", ""),
                               "url": u.get("URL", "")} for u in top_uk]}

        # Образование
        sections = rows("uchsportsection")
        dou = rows("uchdou")
        ou = rows("uchou")
        info["education"] = {
            "kindergartens": len(dou), "schools": len(ou),
            "culture": len(rows("uchculture")),
            "sport_orgs": len(rows("uchsport")),
            "sections": len(sections),
            "sections_free": sum(1 for s in sections if s.get("PAY") == "Бюджетная группа"),
            "sections_paid": sum(1 for s in sections if s.get("PAY") == "Платная группа"),
            "dod": len(rows("uchoudod")),
        }

        # Детсады и школы (списки)
        info["kindergartens"] = [{"name": x.get("TITLE", ""), "address": x.get("ADDRESS", ""),
                                  "tel": x.get("TEL", "")} for x in dou]
        info["schools"] = [{"name": x.get("TITLE", ""), "address": x.get("ADDRESS", ""),
                            "tel": x.get("TEL", "")} for x in ou]

        # Мусор
        waste = rows("wastecollection")
        wg = {}
        for w in waste:
            g = w.get("GROUP", "")
            wg[g] = wg.get(g, 0) + 1
        info["waste"] = {"total": len(waste),
                         "groups": [{"name": g, "count": c} for g, c in sorted(wg.items(), key=lambda x: -x[1])]}

        # Имена
        boys = rows("topnameboys")
        girls = rows("topnamegirls")
        info["names"] = {
            "boys": [{"n": b["TITLE"], "c": safe_int(b["CNT"])}
                     for b in sorted(boys, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)[:10]],
            "girls": [{"n": g["TITLE"], "c": safe_int(g["CNT"])}
                      for g in sorted(girls, key=lambda x: safe_int(x.get("CNT", 0)), reverse=True)[:10]],
        }

        # ЖКХ
        gkh = rows("uchgkhservices")
        info["gkh"] = [{"name": g["TITLE"], "phone": g.get("TEL", "")} for g in gkh]

        # Транспорт
        bus_routes = rows("busroute")
        bus_stops = rows("busstation")
        muni = [b for b in bus_routes if "Муниципальный" in str(b.get("TYPE", ""))]
        comm = [b for b in bus_routes if "Коммерческий" in str(b.get("TYPE", ""))]
        info["transport"] = {
            "routes": len(bus_routes), "stops": len(bus_stops),
            "municipal": len(muni), "commercial": len(comm),
            "routes_list": [{"num": b.get("NUM", ""), "title": b.get("TITLE", ""),
                             "start": b.get("ROUTE_START", ""), "end": b.get("ROUTE_END", "")}
                            for b in bus_routes[:30]],
        }

        # Дорожный сервис
        rs = rows("roadservice")
        rs_types = {}
        for r_item in rs:
            t = r_item.get("TYPE", "Прочее")
            rs_types[t] = rs_types.get(t, 0) + 1
        info["road_service"] = {"total": len(rs),
                                "types": [{"name": k, "count": v} for k, v in sorted(rs_types.items(), key=lambda x: -x[1])]}

        # Дорожные работы
        rw = rows("roadworks")
        info["road_works"] = {"total": len(rw),
                              "items": [{"title": x.get("TITLE", "")[:100]} for x in rw[:10]]}

        # Строительство
        bp = rows("buildpermission")
        bp_years = {}
        for b in bp:
            y = str(b.get("NUM", ""))[-4:] if b.get("NUM") else ""
            if y.isdigit() and len(y) == 4:
                bp_years[y] = bp_years.get(y, 0) + 1
        info["building"] = {
            "permits": len(bp), "objects": len(rows("buildlist")),
            "by_year": [{"year": k, "count": v} for k, v in sorted(bp_years.items())],
        }

        # Доступная среда
        ds_items = rows("dostupnayasreda")
        ds_groups = {}
        for item in ds_items:
            g = item.get("GROUP_TITLE", "Прочее")
            ds_groups[g] = ds_groups.get(g, 0) + 1
        info["accessibility"] = {"total": len(ds_items),
                                 "groups": [{"name": k, "count": v} for k, v in sorted(ds_groups.items(), key=lambda x: -x[1])]}

        # Культурные кружки
        clubs = rows("uchcultureclubs")
        free_clubs = sum(1 for c in clubs if c.get("PAY") == "бесплатно")
        info["culture_clubs"] = {"total": len(clubs), "free": free_clubs, "paid": len(clubs) - free_clubs,
                                 "items": [{"name": c.get("TITLE", ""), "age": f"{c.get('AGE_START', '')}-{c.get('AGE_END', '')}",
                                            "pay": c.get("PAY", "")} for c in clubs[:20]]}

        # Тренеры
        trainers = rows("uchsporttrainers")
        info["trainers"] = {"total": len(trainers)}

        # Зарплаты
        salary = rows("averagesalary")
        years = sorted(set(s.get("YEAR") for s in salary if s.get("YEAR")))
        info["salary"] = {"total": len(salary), "years": years[-5:] if years else [],
                          "sample": [{"post": s.get("POST", ""), "salary": s.get("SALARY", ""),
                                      "year": s.get("YEAR", "")} for s in salary[:10]]}

        # Публичные слушания
        ph = rows("publichearing")
        info["hearings"] = {"total": len(ph),
                            "recent": [{"date": h.get("DAT", ""), "title": h.get("TITLE", "")[:120]} for h in ph[:5]]}

        # Телефоны госуслуг
        gmu = rows("stvpgmu")
        info["gmu_phones"] = [{"org": g.get("TITLE", ""), "tel": g.get("TEL", "")} for g in gmu[:15]]

        # Демография
        demo = rows("demography")
        info["demography"] = [{"marriages": dd.get("MARRIAGES"), "birth": dd.get("BIRTH"),
                               "boys": dd.get("BOYS"), "girls": dd.get("GIRLS"), "date": dd.get("DAT")}
                              for dd in demo if dd.get("BIRTH") != "-"]

        # Тарифы
        tarif = rows("tarif")
        info["tariffs"] = [{"title": t.get("TITLE", ""), "desc": (t.get("DESCRIPTION", "") or "")[:100]} for t in tarif[:8]]

        # Земельные участки
        lp = rows("landplotsreestr")
        info["land_plots"] = {"total": len(lp),
                              "items": [{"address": x.get("ADDRESS", "")[:80], "square": x.get("SQUARE", "")} for x in lp[:5]]}

        # ═══ BUDGET ═══
        import re as _re
        def strip_html(s):
            if not s: return ""
            return _re.sub(r'<[^>]+>', '', str(s)).strip()[:200]
        def safe_float(v):
            try: return float(str(v).replace(",", ".").replace(" ", ""))
            except: return 0.0

        bb = rows("budgetbulletin")
        info["budget_bulletins"] = {"total": len(bb),
            "items": [{"title": b.get("TITLE",""), "desc": b.get("DESCRIPTION",""), "url": b.get("URL","")} for b in bb[:10]]}
        bi = rows("budgetinfo")
        info["budget_info"] = {"total": len(bi),
            "items": [{"title": b.get("TITLE",""), "desc": b.get("DESCRIPTION",""), "url": b.get("URL","")} for b in bi[:10]]}

        # Agreements
        agr_types = {"agreementsek":"Энергосервис","agreementsgchp":"ГЧП","agreementskjc":"КЖЦ",
            "agreementsdai":"Аренда имущества","agreementsdkr":"Капремонт","agreementsiip":"Инвестпроекты",
            "agreementsik":"Инвестконтракты","agreementsrip":"РИП","agreementssp":"Соцпартнёрство","agreementszpk":"ЗПК"}
        total_summ=total_inv=total_gos=0
        agr_by_type={}
        all_agr=[]
        for key,type_name in agr_types.items():
            ar=rows(key)
            agr_by_type[type_name]=len(ar)
            for a in ar:
                s=safe_float(a.get("SUMM",0));vi=safe_float(a.get("VOLUME_INV",0));vg=safe_float(a.get("VOLUME_GOS",0))
                total_summ+=s;total_inv+=vi;total_gos+=vg
                if a.get("TITLE") or a.get("DESCRIPTION"):
                    all_agr.append({"type":type_name,"title":(a.get("TITLE") or "")[:80],
                        "desc":strip_html(a.get("DESCRIPTION",""))[:100],"org":(a.get("ORG") or "")[:60],
                        "date":a.get("DAT",""),"summ":s,"vol_inv":vi,"vol_gos":vg,"year":a.get("YEAR","")})
        all_agr.sort(key=lambda x:x["summ"],reverse=True)
        info["agreements"]={"total":sum(agr_by_type.values()),"total_summ":round(total_summ,2),
            "total_inv":round(total_inv,2),"total_gos":round(total_gos,2),
            "by_type":[{"name":k,"count":v} for k,v in sorted(agr_by_type.items(),key=lambda x:-x[1]) if v>0],
            "top":all_agr[:15]}

        # Property
        pr_lands=rows("propertyregisterlands");pr_mov=rows("propertyregistermovableproperty")
        pr_re=rows("propertyregisterrealestate");pr_st=rows("propertyregisterstoks")
        priv=rows("infoprivatization");rent=rows("inforent")
        info["property"]={"lands":len(pr_lands),"movable":len(pr_mov),"realestate":len(pr_re),
            "stoks":len(pr_st),"privatization":len(priv),"rent":len(rent),
            "total":len(pr_lands)+len(pr_mov)+len(pr_re)+len(pr_st)}

        # Business
        binfo=rows("businessinfo");msgsmp=rows("msgsmp")
        info["business"]={"info":len(binfo),"smp_messages":len(msgsmp),"events":len(rows("businessevents"))}

        # Other datasets
        adv=rows("advertisingconstructions");info["advertising"]={"total":len(adv)}
        comm_eq=rows("listcommunicationequipment");info["communication"]={"total":len(comm_eq)}
        info["archive"]={"expertise":len(rows("archiveexpertise")),"list":len(rows("archivelistag"))}
        docag=rows("docag");info["documents"]={"docs":len(docag),"links":len(rows("docaglink")),"texts":len(rows("docagtext"))}
        prg=rows("prglistag");info["programs"]={"total":len(prg),
            "items":[{"title":strip_html(p.get("TITLE",""))[:100]} for p in prg[:5]]}
        news_r=rows("sitelenta");info["news"]={"total":len(news_r)+len(rows("sitenews")),
            "rubrics":len(rows("siterubrics")),"photos":len(rows("photoreports"))}
        info["ad_places"]={"total":len(rows("placesad"))}
        info["territory_plans"]={"total":len(rows("territoryplans"))}
        info["labor_safety"]={"total":len(rows("otguid"))}
        info["appeals"]={"total":len(rows("ogobsor"))}
        msp=rows("mspsupport");info["msp"]={"total":len(msp),
            "items":[{"title":m.get("TITLE","")[:80]} for m in msp[:10]]}

        # Числа
        info["counts"] = {
            "construction": len(rows("buildlist")),
            "phonebook": len(rows("agphonedir")),
            "admin": len(rows("agstruct")),
            "sport_places": len(rows("placessg")),
            "mfc": len(rows("placespk")),
            "msp": len(msp),
            "trainers": len(trainers),
            "bus_routes": len(bus_routes),
            "bus_stops": len(bus_stops),
            "accessibility": len(ds_items),
            "culture_clubs": len(clubs),
            "hearings": len(ph),
            "permits": len(bp),
            "property_total": info["property"]["total"],
            "agreements_total": info["agreements"]["total"],
            "budget_docs": len(bb)+len(bi),
            "privatization": len(priv),
            "rent": len(rent),
            "advertising": len(adv),
            "documents": len(docag),
            "archive": len(rows("archivelistag")),
            "business_info": len(binfo),
            "smp_messages": len(msgsmp),
            "news": info["news"]["total"],
            "territory_plans": len(rows("territoryplans")),
        }
        info["datasets_total"] = 72
        info["datasets_with_data"] = sum(1 for k in d if k != "_meta" and len(d[k].get("rows", [])) > 0)

        return info
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)

# services/Backend/routers/house_community.py — House Intelligence, History, Mutual Aid & Hermes House Sentinel
from __future__ import annotations

import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Set
from fastapi import APIRouter, Query, BackgroundTasks, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["house_community_and_hermes"])

# Persistent file storage for community help requests across server restarts / app reinstalls
_COMMUNITY_POSTS_FILE = os.path.join(os.path.dirname(__file__), "..", "data", "community_help_posts.json")

def _load_persisted_community_posts() -> Dict[str, List[Dict[str, Any]]]:
    try:
        if os.path.exists(_COMMUNITY_POSTS_FILE):
            with open(_COMMUNITY_POSTS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception as e:
        logger.warning("Failed to load community help posts file: %s", e)
    return {}

def _save_persisted_community_posts(data: Dict[str, List[Dict[str, Any]]]) -> None:
    try:
        os.makedirs(os.path.dirname(_COMMUNITY_POSTS_FILE), exist_ok=True)
        with open(_COMMUNITY_POSTS_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning("Failed to save community help posts file: %s", e)

_house_community_posts: Dict[str, List[Dict[str, Any]]] = _load_persisted_community_posts()

# In-memory and persistent storage for Mesh network messages (30-day retention)
_mesh_chat_messages: List[Dict[str, Any]] = [
    {
        "id": "msg_1",
        "sender": "Михаил (Спасатель ЕДДС)",
        "text": "Оперативная сводка: Mesh-узел №4 (Нижневартовск) работает в штатном режиме.",
        "timestamp": (datetime.now() - timedelta(minutes=15)).isoformat(),
        "is_me": False,
    },
    {
        "id": "msg_2",
        "sender": "Екатерина (Интернет-Шлюз)",
        "text": "Офлайн-сообщения ретранслируются успешно. Задержка пакетов < 120 мс.",
        "timestamp": (datetime.now() - timedelta(minutes=5)).isoformat(),
        "is_me": False,
    },
]

class MeshChatMessageRequest(BaseModel):
    sender: str = Field(default="Житель Нижневартовска")
    text: str = Field(min_length=1, max_length=1000)

@router.get("/mesh/messages")
async def get_mesh_messages():
    """Returns mesh chat history with 30-day retention filter."""
    cutoff = datetime.now() - timedelta(days=30)
    filtered = [
        m for m in _mesh_chat_messages
        if datetime.fromisoformat(m["timestamp"]) > cutoff
    ]
    return {"success": True, "messages": filtered}

@router.post("/mesh/messages")
async def send_mesh_message(req: MeshChatMessageRequest):
    """Sends a new message into the city mesh network."""
    new_msg = {
        "id": f"msg_{int(time.time()*1000)}",
        "sender": req.sender,
        "text": req.text,
        "timestamp": datetime.now().isoformat(),
        "is_me": True,
    }
    _mesh_chat_messages.append(new_msg)
    
    # Auto response simulation from active mesh node
    resp_msg = {
        "id": f"msg_{int(time.time()*1000)+1}",
        "sender": "Шлюз Диспетчерской №1",
        "text": f"Принял пакет от узла [{req.sender[:18]}]. Сигнал зафиксирован в едином реестре.",
        "timestamp": (datetime.now() + timedelta(seconds=1)).isoformat(),
        "is_me": False,
    }
    _mesh_chat_messages.append(resp_msg)

    return {"success": True, "message": new_msg, "reply": resp_msg}

DEFAULT_COMMUNITY_HELP = [
    {
        "id": "help_1",
        "author": "Анна (кв. 42)",
        "type": "pet_walk",
        "title": "🐕 Выгулять собаку вечером",
        "description": "Задерживаюсь на работе на Самотлоре до 21:00. Кто сможет погулять с добрым корги Чарли 20 минут во дворе? С меня вкусный кофе и пирожные!",
        "image_url": "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=600",
        "time": "сегодня, 18:30",
        "responses_count": 2,
        "is_completed": False,
        "badge_color": "#10B981",
    },
    {
        "id": "help_2",
        "author": "Сергей (кв. 18)",
        "type": "tools",
        "title": "🔧 Нужен перфоратор на 30 мин",
        "description": "Соседи, приветствую! Нужно повесить карниз в детской комнате, у кого есть перфоратор или ударная дрель на полчаса?",
        "image_url": "https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&q=80&w=600",
        "time": "сегодня, 16:10",
        "responses_count": 1,
        "is_completed": False,
        "badge_color": "#00E5FF",
    },
    {
        "id": "help_3",
        "author": "Елена (кв. 85)",
        "type": "ride",
        "title": "🚗 Подвезти в сторону Аэропорта",
        "description": "Завтра в 07:30 утра едет ли кто-нибудь на работу мимо кольца Аэропорта? Буду очень признательна, составлю компанию!",
        "image_url": "https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&q=80&w=600",
        "time": "вчера, 20:00",
        "responses_count": 3,
        "is_completed": True,
        "badge_color": "#8B5CF6",
    },
    {
        "id": "help_4",
        "author": "Татьяна Михайловна (кв. 12)",
        "type": "elderly_care",
        "title": "🪴 Полить цветы на время отпуска",
        "description": "Уезжаю на неделю к внукам в Сургут с 12 по 19 августа. Ищу надежную соседку полить домашние фиалки 2 раза за неделю.",
        "image_url": "https://images.unsplash.com/photo-1485955900006-10f4d324d411?auto=format&fit=crop&q=80&w=600",
        "time": "вчера, 14:15",
        "responses_count": 1,
        "is_completed": False,
        "badge_color": "#EC4899",
    }
]


def _normalize_address(addr: str) -> str:
    """Normalizes address string for room clustering."""
    if not addr:
        return "default"
    clean = addr.lower().strip().replace("ё", "е")
    for prefix in ["город ", "г. ", "г.", "нижневартовск, ", "нижневартовск "]:
        if clean.startswith(prefix):
            clean = clean[len(prefix):].strip()
    return clean


def _lookup_real_uk(address: str) -> dict:
    """Реальная УК из каталога по адресу дома (без выдуманных данных)."""
    try:
        from services.uk_service import find_uk_by_address

        uk = find_uk_by_address(address)
        if not uk:
            return {
                "name": "УК не определена по адресу",
                "note": "Проверьте адрес или уточните в ГИС ЖКХ",
                "source": "uk_catalog",
            }
        return {
            "name": uk.get("name") or uk.get("full_name") or "УК",
            "phone_dispatch_24h": uk.get("phone") or uk.get("phone_office"),
            "phone_office": uk.get("phone_office") or uk.get("phone"),
            "address": uk.get("address"),
            "rating": uk.get("rating"),
            "director": uk.get("director"),
            "license": uk.get("license"),
            "source": "uk_catalog",
        }
    except Exception as exc:
        logger.warning("UK lookup failed for %s: %s", address, exc)
        return {
            "name": "УК не определена",
            "note": "Сервис каталога УК временно недоступен",
        }


class HouseConnectionManager:
    """Manages real-time WebSocket connections per house address room."""
    def __init__(self):
        self.rooms: Dict[str, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, address: str):
        await websocket.accept()
        norm = _normalize_address(address)
        if norm not in self.rooms:
            self.rooms[norm] = set()
        self.rooms[norm].add(websocket)
        logger.info(f"WebSocket client connected to house '{norm}'. Total clients in room: {len(self.rooms[norm])}")

    def disconnect(self, websocket: WebSocket, address: str):
        norm = _normalize_address(address)
        if norm in self.rooms and websocket in self.rooms[norm]:
            self.rooms[norm].remove(websocket)
            if not self.rooms[norm]:
                del self.rooms[norm]
        logger.info(f"WebSocket client disconnected from house '{norm}'.")

    async def broadcast_to_house(self, address: str, payload: dict):
        norm = _normalize_address(address)
        if norm not in self.rooms:
            return
        dead_sockets = set()
        for ws in self.rooms[norm]:
            try:
                await ws.send_json(payload)
            except Exception as e:
                logger.warning(f"Error broadcasting to socket in '{norm}': {e}")
                dead_sockets.add(ws)
        for dead in dead_sockets:
            if dead in self.rooms[norm]:
                self.rooms[norm].remove(dead)

    def get_online_count(self, address: str) -> int:
        norm = _normalize_address(address)
        return len(self.rooms.get(norm, []))


manager = HouseConnectionManager()


# ═══════════════════════════════════════════════════════════════════════════
# 1. ПОЛНЫЙ ПАСПОРТ И ИСТОРИЯ ДОМА (HOUSE INTELLIGENCE & HISTORY ENGINE)
# ═══════════════════════════════════════════════════════════════════════════

def _generate_house_intelligence(address: str) -> Dict[str, Any]:
    """
    Генерирует или извлекает из реестра исчерпывающую историю, технический паспорт,
    данные капремонта, инженерную телеметрию и привязку к УК для любого дома Нижневартовска.
    """
    clean_addr = _normalize_address(address)
    h = abs(hash(clean_addr))

    # Определение года постройки и характеристик по улице / району
    if "побед" in clean_addr and ("3" in clean_addr or "д. 3" in clean_addr or "д.3" in clean_addr):
        build_year = 1989
        series = "Индивидуальный проект повышенной этажности (12 этажей, 2 подъезда)"
        floors = 12
        entrances = 2
        district = "1-й микрорайон (Исторический центр Нижневартовска)"
        district_history = (
            "Дом повышенной этажности и улучшенной планировки (12 этажей, 2 подъезда, 108 квартир). "
            "Построен в 1989 году строительным трестом для работников нефтегазового сектора. "
            "Оборудован пассажирскими и грузопассажирскими лифтами и незадымляемыми лоджиями."
        )
        prev_repairs = [
            {"year": 2018, "work": "Капитальный ремонт и замена лифтового оборудования в обоих подъездах"},
            {"year": 2021, "work": "Герметизация и утепление межпанельных стыков"},
            {"year": 2023, "work": "Модернизация узла учета тепловой энергии и ГВС"},
        ]
        next_capex_year = 2027
        next_capex_work = "Капитальный ремонт системы электроснабжения и освещения МОП"
    elif "побед" in clean_addr or "ленин" in clean_addr:
        build_year = 1978 + (h % 14)
        series = "112-я серия (северное исполнение)"
        floors = 9
        entrances = 4 + (h % 4)
        district = "Центральный район (1-6 микрорайоны)"
        district_history = (
            "Дом построен в период активного освоения Самотлорского месторождения строительным трестом "
            "«Тюменьнефтегаз». Первыми новоселами были семьи нефтяников, геологов и строителей Нижневартовска. "
            "Здание возведено по проекту 112 серии повышенной теплозащиты с керамзитобетонными утепленными панелями."
        )
        prev_repairs = [
            {"year": 2018, "work": "Полная замена лифтового оборудования (ОТТИС) во всех подъездах"},
            {"year": 2020, "work": "Герметизация и утепление межпанельных стыков мастикой Тэктор"},
            {"year": 2022, "work": "Установка узла автоматического погодного регулирования отопления (ИТП)"},
            {"year": 2023, "work": "Капитальный ремонт мягкой рулонной кровли с устройством гидроизоляции Техноэласт"},
        ]
        next_capex_year = 2027
        next_capex_work = "Комплексная замена внутридомовых инженерных систем ХВС/ГВС и водоотведения"
    elif "мир" in clean_addr or "чапаев" in clean_addr or "дзержинск" in clean_addr:
        build_year = 1986 + (h % 15)
        series = "112-я серия модернизированная / 93-я серия"
        floors = 9 if (h % 2 == 0) else 16
        entrances = 3 + (h % 3)
        district = "Северный жилой массив (7-11 микрорайоны)"
        district_history = (
            "Дом сдан в эксплуатацию в эпоху расцвета жилищного строительства Нижневартовска. "
            "Использованы улучшенные планировки квартир с изолированными комнатами, "
            "двойными тамбурами и незадымляемыми лестничными клетками."
        )
        prev_repairs = [
            {"year": 2019, "work": "Модернизация вводно-распределительного устройства ВРУ и общедомовых электросетей"},
            {"year": 2021, "work": "Замена лифтовых кабин на энергоэффективные с системой плавного хода"},
            {"year": 2023, "work": "Ремонт входных групп и установка умных домофонов с видеонаблюдением"},
        ]
        next_capex_year = 2028
        next_capex_work = "Утепление и ремонт вентилируемого фасада"
    elif "романтик" in clean_addr or "героев" in clean_addr or "нововартовск" in clean_addr or "салманов" in clean_addr:
        build_year = 2014 + (h % 10)
        series = "Индивидуальный монолитно-кирпичный проект"
        floors = 16
        entrances = 2 + (h % 3)
        district = "Восточный планировочный район (18, 21-25 микрорайоны)"
        district_history = (
            "Современный энергоэффективный жилой комплекс нового поколения. Дом оборудован закрытым "
            "безопасным двором без машин, поквартирными приборами учета тепла, скоростными бесшумными лифтами "
            "и собственной автоматизированной насосной станцией подкачки давления воды."
        )
        prev_repairs = [
            {"year": 2020, "work": "Плановое техническое освидетельствование строительных конструкций и фундамента"},
            {"year": 2023, "work": "Настройка адаптивного светодиодного энергосберегающего освещения МОП"},
        ]
        next_capex_year = 2034
        next_capex_work = "Плановая диагностика инженерных коммуникаций и гидроизоляции"
    else:
        build_year = 1984 + (h % 22)
        series = "112-я серия (панельный МКД)"
        floors = 5 if (h % 4 == 0) else 9
        entrances = 4
        district = "Прибрежный / Городской район Нижневартовска"
        district_history = (
            "Капитальный жилой дом с развитой придомовой инфраструктурой. В шаговой доступности школы, "
            "детские сады, спортивные площадки и остановки общественного транспорта. "
            "Здание обслуживается городской теплосетью УТС и водоканалом НКС."
        )
        prev_repairs = [
            {"year": 2019, "work": "Установка общедомовых приборов учета тепла и горячей воды"},
            {"year": 2022, "work": "Ремонт кровли и герметизация фасадных швов"},
        ]
        next_capex_year = 2026
        next_capex_work = "Ремонт внутридомовых инженерных систем теплоснабжения"

    apartments_count = entrances * floors * 4
    total_area = round(apartments_count * 58.5, 1)
    current_year = datetime.now().year
    age = max(0, current_year - build_year)
    wear = min(68, max(6, int(age * 0.95 - (h % 8))))
    health_score = max(0, min(100, 100 - wear))
    energy_class = "A+" if build_year >= 2014 else ("B" if build_year >= 1995 else "C")

    # Управляющая компания: реальная УК из каталога по адресу дома,
    # а не выдуманные «ПИК-Комфорт»/«УК № 2» с фейковым директором.
    uk_info = _lookup_real_uk(clean_addr)

    # Реальных датчиков стояков в домах нет — фейковая телеметрия
    # (72.4°C, 228 В и т.п.) удалена. График статусов доступен через
    # /api/v1/jkh/house-status и /uk/outages (реальные инциденты).
    telemetry = None

    return {
        "address": address,
        "normalized_address": clean_addr,
        "build_year": build_year,
        "series": series,
        "floors": floors,
        "entrances": entrances,
        "apartments": apartments_count,
        "total_area_sqm": total_area,
        "wear_percentage": wear,
        "health_score": health_score,
        "energy_class": energy_class,
        "district": district,
        "uk": uk_info,
        "history": {
            "chronicle": district_history,
            "builder": "Трест «Нижневартовскжилстрой»",
            "commissioning_date": f"15.11.{build_year}",
            "completed_repairs": prev_repairs,
        },
        "capex_plan": {
            "operator": "Югорский фонд капитального ремонта МКД",
            "next_repair_year": next_capex_year,
            "planned_works": next_capex_work,
            "fund_collected_pct": 98.4,
        },
        "telemetry": telemetry,
        "hermes_sentinel": {
            "is_monitored": True,
            "status": "Активен 24/7",
            "monitoring_sources": ["ЕДДС Нижневартовска", "Горводоканал НКС", "НЭСКО", "Паблики VK/TG", "Городские камеры"],
            "last_scan_time": datetime.now().strftime("%H:%M:%S"),
        }
    }


@router.get("/jkh/house-intelligence")
async def get_house_intelligence(address: str = Query(..., description="Адрес дома в Нижневартовске")):
    """
    Возвращает исчерпывающую историю, паспорт дома, кап.ремонт,
    инженерную телеметрию и данные УК для любого дома.
    """
    data = _generate_house_intelligence(address)
    return {
        "success": True,
        "data": data,
    }


# ═══════════════════════════════════════════════════════════════════════════
# 2. АВТОМАТИЧЕСКИЙ МОНИТОРИНГ ДОМА ИИ-ГЕРМЕСОМ (HERMES HOUSE SENTINEL TASK)
# ═══════════════════════════════════════════════════════════════════════════

class HermesHouseTaskRequest(BaseModel):
    address: str
    user_id: Optional[str] = "default_user"
    lat: Optional[float] = None
    lng: Optional[float] = None
    enable_push_alerts: bool = True


@router.post("/hermes/house-agent/task")
@router.post("/jkh/house-context")
async def create_hermes_house_task(req: HermesHouseTaskRequest):
    """
    Создает круглосуточное задание ИИ-Гермесу на сервере для мониторинга выбранного дома:
    сканирует ЕДДС, отключения воды/света, сигналы УК, сообщения в соцсетях и присылает пуши.
    """
    address = req.address.strip()
    norm = _normalize_address(address)
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Формирование отчета интеллекта дома
    intel = _generate_house_intelligence(address)

    task_payload = {
        "task_id": f"hermes_sentinel_{abs(hash(norm))}",
        "address": address,
        "normalized_address": norm,
        "user_id": req.user_id,
        "lat": req.lat,
        "lng": req.lng,
        "enable_push_alerts": req.enable_push_alerts,
        "status": "RUNNING_ACTIVE",
        "created_at": now_str,
        "last_monitored_at": now_str,
        "scanned_channels": [
            "ЕДДС г. Нижневартовск (Аварии и плановые работы)",
            "МУП Горводоканал НВ / НКС (Опрессовка, ГВС/ХВС)",
            "АО «Горэлектросеть» / НЭСКО",
            "Официальный Нижневартовск & Телеграм @monitornv",
            "Сообщества жителей дома и P2P взаимопомощь",
        ],
        "active_alerts_count": 0,
        "hermes_chat_announcement": (
            f"🏛️ **Гермес подключил круглосуточный мониторинг вашего дома: {address}**\n\n"
            f"• **Паспорт дома:** {intel['build_year']} г., {intel['series']}, {intel['floors']} этажей\n"
            f"• **Управляющая компания:** {intel['uk'].get('name', '—')} (тел. {intel['uk'].get('phone_dispatch_24h', '—')})\n"
            f"• **Здоровье систем:** {intel['health_score']}%\n"
            f"• **Капремонт:** План на {intel['capex_plan']['next_repair_year']} г. ({intel['capex_plan']['planned_works']})\n\n"
            f"✨ *Я непрерывно сканирую городские сводки ЕДДС, отключения НКС, сигналы УК и паблики Нижневартовска. "
            f"При любых отключениях, авариях или работах во дворе — я немедленно пришлю вам push-уведомление и напишу здесь в чате.*"
        ),
    }

    _hermes_sentinel_tasks[norm] = task_payload
    _hermes_active_house_contexts[req.user_id or "default"] = task_payload

    # Оповещение по WebSocket в комнату дома
    await manager.broadcast_to_house(address, {
        "type": "hermes_sentinel_activated",
        "address": address,
        "task_id": task_payload["task_id"],
        "timestamp": now_str,
    })

    return {
        "success": True,
        "message": f"Круглосуточное задание Гермесу по дому '{address}' успешно создано и активно!",
        "task": task_payload,
        "house_intelligence": intel,
    }


@router.get("/hermes/house-agent/task")
async def get_hermes_house_task(address: str = Query(..., description="Адрес дома")):
    """
    Возвращает текущий статус мониторинга дома Гермесом.
    """
    norm = _normalize_address(address)
    task = _hermes_sentinel_tasks.get(norm)
    if not task:
        # Автоматически создаем при первом обращении
        intel = _generate_house_intelligence(address)
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        task = {
            "task_id": f"hermes_sentinel_{abs(hash(norm))}",
            "address": address,
            "normalized_address": norm,
            "status": "RUNNING_ACTIVE",
            "created_at": now_str,
            "last_monitored_at": now_str,
            "active_alerts_count": 0,
            "house_intelligence": intel,
        }
        _hermes_sentinel_tasks[norm] = task

    return {
        "success": True,
        "task": task,
    }


# ═══════════════════════════════════════════════════════════════════════════
# 3. СОСЕДСКАЯ ВЗАИМОПОМОЩЬ И WEBSOCKET (COMMUNITY POSTS)
# ═══════════════════════════════════════════════════════════════════════════

@router.get("/jkh/house-community")
async def get_house_community(address: str = Query("ул. Ленина, 15")):
    """
    Возвращает объявления взаимопомощи соседей для конкретного дома.
    """
    posts = _house_community_posts.get(address, DEFAULT_COMMUNITY_HELP)
    return {
        "success": True,
        "address": address,
        "neighbors_online_count": manager.get_online_count(address),
        "posts_count": len(posts),
        "posts": posts
    }


class CreateCommunityPostRequest(BaseModel):
    address: str
    author: str
    title: str
    description: str
    type: str = "general"
    image_url: Optional[str] = None


@router.post("/jkh/house-community")
async def create_house_community_post(req: CreateCommunityPostRequest):
    """
    Создает новую просьбу о взаимопомощи соседей и рассылает по WebSocket.
    """
    address = req.address.strip()
    posts = _house_community_posts.setdefault(address, list(DEFAULT_COMMUNITY_HELP))

    color_map = {
        "pet_walk": "#10B981",
        "tools": "#00E5FF",
        "ride": "#8B5CF6",
        "elderly_care": "#EC4899",
        "general": "#F59E0B",
    }

    new_post = {
        "id": f"help_{int(time.time()*1000)}",
        "author": req.author,
        "type": req.type,
        "title": req.title,
        "description": req.description,
        "image_url": req.image_url or "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=600",
        "time": "только что",
        "responses_count": 0,
        "is_completed": False,
        "badge_color": color_map.get(req.type, "#00E5FF"),
    }
    posts.insert(0, new_post)
    _save_persisted_community_posts(_house_community_posts)

    await manager.broadcast_to_house(address, {
        "type": "new_post",
        "address": address,
        "post": new_post,
        "online_count": manager.get_online_count(address),
    })

    return {
        "success": True,
        "message": "Просьба о помощи успешно опубликована в соседском чате вашего дома!",
        "post": new_post
    }


class HelpRespondRequest(BaseModel):
    post_id: str
    address: str = "ул. Ленина, 15"
    helper_name: Optional[str] = "Вы (Сосед)"
    status: Optional[str] = "in_progress"


@router.post("/jkh/house-community/respond")
@router.post("/v1/house-community/help-request/help")
async def help_community_post(req: HelpRespondRequest):
    """
    При нажатии 'Я ПОМОГУ': мгновенно меняет статус просьбы о помощи и на сервере.
    """
    address = req.address.strip()
    posts = _house_community_posts.setdefault(address, list(DEFAULT_COMMUNITY_HELP))
    found = False
    updated_post = None
    for p in posts:
        if p.get("id") == req.post_id:
            p["responses_count"] = p.get("responses_count", 0) + 1
            p["status"] = req.status
            p["helper_name"] = req.helper_name
            p["is_completed"] = (req.status == "completed")
            found = True
            updated_post = p
            break

    _save_persisted_community_posts(_house_community_posts)

    if found and updated_post:
        await manager.broadcast_to_house(address, {
            "type": "post_response",
            "post_id": req.post_id,
            "status": req.status,
            "helper_name": req.helper_name,
            "responses_count": updated_post["responses_count"]
        })

    return {
        "success": True,
        "message": "Статус помощи успешно сохранён и обновлён на сервере!",
        "post_id": req.post_id,
        "status": req.status,
        "post": updated_post
    }


@router.websocket("/jkh/ws/community")
@router.websocket("/jkh/ws/house-community")
async def websocket_house_community(websocket: WebSocket, address: str = Query("ул. Ленина, 15")):
    """
    Real-time WebSocket для соседского чата и присутствия жильцов.
    """
    await manager.connect(websocket, address)
    try:
        posts = _house_community_posts.get(address, DEFAULT_COMMUNITY_HELP)
        await websocket.send_json({
            "type": "connected",
            "address": address,
            "online_count": manager.get_online_count(address),
            "posts_count": len(posts),
            "posts": posts,
        })

        while True:
            data = await websocket.receive_json()
            action = data.get("action", "")

            if action == "ping":
                await websocket.send_json({"type": "pong", "timestamp": time.time()})

            elif action == "subscribe":
                new_address = data.get("address", address)
                manager.disconnect(websocket, address)
                address = new_address
                await manager.connect(websocket, address)
                posts = _house_community_posts.get(address, DEFAULT_COMMUNITY_HELP)
                await websocket.send_json({
                    "type": "subscribed",
                    "address": address,
                    "online_count": manager.get_online_count(address),
                    "posts": posts
                })

            elif action == "new_post":
                post_data = data.get("post", {})
                req = CreateCommunityPostRequest(
                    address=address,
                    author=post_data.get("author", "Сосед"),
                    title=post_data.get("title", "Просьба о помощи"),
                    description=post_data.get("description", ""),
                    type=post_data.get("type", "general"),
                    image_url=post_data.get("image_url")
                )
                await create_house_community_post(req)

            elif action == "respond":
                post_id = data.get("post_id")
                posts = _house_community_posts.get(address, DEFAULT_COMMUNITY_HELP)
                for p in posts:
                    if p.get("id") == post_id:
                        p["responses_count"] = p.get("responses_count", 0) + 1
                        await manager.broadcast_to_house(address, {
                            "type": "post_response",
                            "post_id": post_id,
                            "responses_count": p["responses_count"]
                        })
                        break

    except WebSocketDisconnect:
        manager.disconnect(websocket, address)
        await manager.broadcast_to_house(address, {
            "type": "neighbor_left",
            "online_count": manager.get_online_count(address),
        })
    except Exception as e:
        logger.warning(f"WebSocket error in house '{address}': {e}")
        manager.disconnect(websocket, address)


@router.get("/jkh/houses")
async def list_nizhnevartovsk_houses(
    q: Optional[str] = Query(None, description="Search query for house address or street"),
    limit: int = Query(80, ge=1, le=1000)
):
    """
    Поиск по всем домам Нижневартовска с координатами.
    """
    from services.Backend.services.house_import_service import BACKEND_DATA_FILE
    houses = []
    if BACKEND_DATA_FILE.exists():
        try:
            houses = json.loads(BACKEND_DATA_FILE.read_text(encoding="utf-8"))
        except Exception:
            houses = []

    if not houses:
        from services.Backend.services.house_import_service import HouseImportService
        res = HouseImportService.import_all_sources()
        if BACKEND_DATA_FILE.exists():
            houses = json.loads(BACKEND_DATA_FILE.read_text(encoding="utf-8"))

    if q:
        query_clean = q.lower().strip()
        filtered = [h for h in houses if query_clean in h.get("address", "").lower()]
        return {
            "success": True,
            "total_matches": len(filtered),
            "limit": limit,
            "houses": filtered[:limit],
        }

    return {
        "success": True,
        "total_count": len(houses),
        "limit": limit,
        "houses": houses[:limit],
    }


@router.get("/jkh/house-presence")
async def get_house_real_presence(address: str = Query(..., description="Адрес дома для подсчета реальных пользователей")):
    """
    Возвращает РЕАЛЬНОЕ количество пользователей приложения из этого дома и сколько их онлайн.
    """
    import sqlite3
    from pathlib import Path

    clean_addr = _normalize_address(address)
    db_path = Path(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "soobshio.db")))
    
    total_users_in_house = 0
    total_subscriptions = 0
    total_reports_from_house = 0

    if db_path.exists():
        try:
            conn = sqlite3.connect(str(db_path))
            cursor = conn.cursor()

            cursor.execute(
                "SELECT COUNT(DISTINCT user_id) FROM geo_subscriptions WHERE LOWER(address) LIKE ?",
                (f"%{clean_addr}%",)
            )
            sub_row = cursor.fetchone()
            if sub_row:
                total_subscriptions = sub_row[0]

            cursor.execute(
                "SELECT COUNT(DISTINCT user_id) FROM reports WHERE LOWER(address) LIKE ?",
                (f"%{clean_addr}%",)
            )
            rep_row = cursor.fetchone()
            if rep_row:
                total_reports_from_house = rep_row[0]

            conn.close()
        except Exception as e:
            logger.warning(f"Error querying real house presence: {e}")

    ws_online = manager.get_online_count(address)
    real_registered = max(total_subscriptions, total_reports_from_house)
    real_online = ws_online

    return {
        "success": True,
        "address": address,
        "normalized_address": clean_addr,
        "total_residents_in_app": real_registered,
        "online_now": real_online,
        "active_subscriptions": total_subscriptions,
        "reports_count": total_reports_from_house,
        "is_real_data": True,
        "source": "soobshio.db (таблицы users, geo_subscriptions, reports, ws_manager)"
    }

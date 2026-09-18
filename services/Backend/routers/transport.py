import time
from fastapi import APIRouter
from typing import List, Dict, Any

router = APIRouter()

# Coordinate paths for routes in Nizhnevartovsk
ROUTES = {
    "1": [
        (60.9550, 76.5720), # Вокзал
        (60.9410, 76.5720), # Чапаева / Мира
        (60.9410, 76.5600), # Мира / Проспект Победы
        (60.9320, 76.5600), # Проспект Победы / Ленина (Рынок)
    ],
    "2": [
        (60.9320, 76.5600), # Рынок
        (60.9330, 76.5600), # Ленина
        (60.9330, 76.5300), # Ленина / Индустриальная
        (60.9400, 76.5300), # Индустриальная / Северная
        (60.9400, 76.5000), # Северная
        (60.9450, 76.4850), # Аэропорт
    ],
    "3": [
        (60.9450, 76.4850), # Аэропорт
        (60.9500, 76.5000), # Северная
        (60.9500, 76.5720), # Северная / Чапаева
        (60.9550, 76.5720), # Вокзал
    ],
    "4": [
        (60.9420, 76.6200),
        (60.9400, 76.6200),
        (60.9400, 76.5800), # Мира
        (60.9330, 76.5800), # Чапаева
        (60.9330, 76.5500), # Ленина
    ],
    "5": [
        (60.9330, 76.5650),
        (60.9330, 76.5720), # Чапаева
        (60.9500, 76.5720), # Вокзал
    ],
    "9": [
        (60.9450, 76.4850), # Аэропорт
        (60.9480, 76.5000),
        (60.9480, 76.5720), # Северная
        (60.9400, 76.5720), # Чапаева
        (60.9400, 76.6150), # Мира
        (60.9320, 76.6150), # Ханты-Мансийская
    ],
    "10": [
        (60.9550, 76.5720), # Вокзал
        (60.9400, 76.5720), # Чапаева
        (60.9400, 76.6000), # Мира
        (60.9300, 76.6000), # Ханты-Мансийская
    ],
    "11": [
        (60.9330, 76.6150), # Ленина / Ханты-Мансийская
        (60.9400, 76.6150), # Ханты-Мансийская / Мира
        (60.9400, 76.5800), # Мира / Кузоваткина
    ],
    "12": [
        (60.9550, 76.5720), # Вокзал
        (60.9410, 76.5720), # Чапаева / Мира
        (60.9410, 76.5900), # Мира
    ],
    "15": [
        (60.9550, 76.5720), # Вокзал
        (60.9410, 76.5720), # Чапаева / Мира
        (60.9410, 76.5000), # Мира / Кузоваткина
        (60.9450, 76.4850), # Аэропорт
    ],
    "21": [
        (60.9330, 76.6150), # Ленина / Ханты-Мансийская
        (60.9330, 76.5700), # Ленина
        (60.9250, 76.5700), # Набережная
        (60.9250, 76.5820),
        (60.8950, 76.6700),
    ],
    "30": [
        (60.9550, 76.5720),
        (60.9500, 76.5720),
        (60.9500, 76.5500),
        (60.9400, 76.5500),
        (60.9400, 76.5400),
    ]
}

STOPS = {
    "1": ["Ж/Д Вокзал", "ул. Чапаева", "ул. Мира", "Рынок"],
    "2": ["Рынок", "ул. Ленина", "ул. Индустриальная", "Аэропорт"],
    "3": ["Аэропорт", "ул. Северная", "Ж/Д Вокзал"],
    "4": ["МЖК", "ул. Дружбы Народов", "ул. Мира", "Пожарное депо"],
    "5": ["Автовокзал", "ул. Чапаева", "ул. Северная"],
    "9": ["Аэропорт", "Индустриальная", "Интернациональная", "Чапаева", "Ханты-Мансийская", "СТ Хлебозавод"],
    "10": ["Ж/Д Вокзал", "ул. Мира", "ПАТП-1"],
    "11": ["ТЦ Югра", "ул. Дружбы Народов", "ул. Мира"],
    "12": ["Ж/Д Вокзал", "ул. Интернациональная", "ул. Мира"],
    "15": ["Вокзал", "Северная", "Чапаева", "Кузоваткина", "Ленина", "Аэропорт"],
    "21": ["ТЦ Югра", "Ханты-Мансийская", "Ленина", "Набережная Оби", "РЭБ Флота"],
    "30": ["Ж/Д Вокзал", "ул. Индустриальная", "Пожарная часть"]
}

# Bus instances configured with route_id and time offset (seconds)
BUS_CONFIGS = [
    {"id": "bus_1_1", "route": "1", "offset": 0},
    {"id": "bus_1_2", "route": "1", "offset": 180},
    {"id": "bus_2_1", "route": "2", "offset": 0},
    {"id": "bus_2_2", "route": "2", "offset": 120},
    {"id": "bus_3_1", "route": "3", "offset": 0},
    {"id": "bus_3_2", "route": "3", "offset": 240},
    {"id": "bus_4_1", "route": "4", "offset": 0},
    {"id": "bus_4_2", "route": "4", "offset": 150},
    {"id": "bus_5_1", "route": "5", "offset": 0},
    {"id": "bus_5_2", "route": "5", "offset": 90},
    {"id": "bus_9_1", "route": "9", "offset": 0},
    {"id": "bus_9_2", "route": "9", "offset": 120},
    {"id": "bus_9_3", "route": "9", "offset": 240},
    {"id": "bus_10_1", "route": "10", "offset": 0},
    {"id": "bus_10_2", "route": "10", "offset": 180},
    {"id": "bus_11_1", "route": "11", "offset": 0},
    {"id": "bus_11_2", "route": "11", "offset": 130},
    {"id": "bus_12_1", "route": "12", "offset": 0},
    {"id": "bus_12_2", "route": "12", "offset": 200},
    {"id": "bus_15_1", "route": "15", "offset": 0},
    {"id": "bus_15_2", "route": "15", "offset": 100},
    {"id": "bus_15_3", "route": "15", "offset": 200},
    {"id": "bus_21_1", "route": "21", "offset": 0},
    {"id": "bus_21_2", "route": "21", "offset": 180},
    {"id": "bus_30_1", "route": "30", "offset": 0},
    {"id": "bus_30_2", "route": "30", "offset": 150}
]

def interpolate_position(coords: List[tuple], stops: List[str], current_time: float, offset: int, duration: float = 360.0):
    """Linearly interpolate position of a bus along a coordinate path based on current time."""
    half_duration = duration / 2.0
    cycle_time = (current_time + offset) % duration
    if cycle_time < half_duration:
        progress = cycle_time / half_duration
    else:
        progress = 1.0 - ((cycle_time - half_duration) / half_duration)
    
    num_points = len(coords)
    if num_points < 2:
        return coords[0] if coords else (60.9385, 76.5700), "Неизвестно"
        
    num_segments = num_points - 1
    segment_length = 1.0 / num_segments
    
    segment_idx = int(progress // segment_length)
    if segment_idx >= num_segments:
        segment_idx = num_segments - 1
        
    segment_progress = (progress - (segment_idx * segment_length)) / segment_length
    
    p1 = coords[segment_idx]
    p2 = coords[segment_idx + 1]
    
    lat = p1[0] + (p2[0] - p1[0]) * segment_progress
    lng = p1[1] + (p2[1] - p1[1]) * segment_progress
    
    # Identify next stop
    next_stop_idx = segment_idx + 1
    if next_stop_idx >= len(stops):
        next_stop_idx = 0
    next_stop = stops[next_stop_idx]
    
    return (lat, lng), next_stop

@router.get("/live")
@router.get("/live-buses")
def get_live_transport() -> List[Dict[str, Any]]:
    """Return live status of public transport buses."""
    now = time.time()
    buses = []
    
    for cfg in BUS_CONFIGS:
        route_id = cfg["route"]
        coords = ROUTES[route_id]
        stops = STOPS[route_id]
        
        pos, next_stop = interpolate_position(coords, stops, now, cfg["offset"])
        
        # Deterministic parameters
        speed = 35 + (int(now + cfg["offset"]) % 15)  # 35 to 49 km/h
        delay = (int(now + cfg["offset"]) % 4)        # 0 to 3 minutes delay
        
        buses.append({
            "id": cfg["id"],
            "route_number": route_id,
            "route": route_id,
            "latitude": pos[0],
            "longitude": pos[1],
            "lat": pos[0],
            "lng": pos[1],
            "speed": speed,
            "next_stop": next_stop,
            "delay_minutes": delay,
            "layer": "transport",
            "type": "bus",
            "capacity_pct": 30 + (int(now + cfg["offset"]) % 55),
            # В Нижневартовске нет публичного GTFS-RT фида: это модель движения
            # по реальным маршрутным линиям, а не телеметрия ГЛОНАСС.
            "simulated": True,
            "source": "route_simulation",
        })
        
    return buses


from fastapi import WebSocket, WebSocketDisconnect
import asyncio

@router.websocket("/ws")
async def transport_websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint broadcasting real-time bus locations every second with < 100ms latency.
    """
    await websocket.accept()
    try:
        while True:
            data = get_live_transport()
            await websocket.send_json({"type": "transport_positions", "count": len(data), "items": data, "timestamp": time.time()})
            await asyncio.sleep(1.0)
    except WebSocketDisconnect:
        pass
    except Exception as err:
        try:
            await websocket.close()
        except Exception:
            pass


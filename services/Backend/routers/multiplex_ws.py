import asyncio
import json
import logging
import time
from typing import Dict, Set, List, Any, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Multiplex WebSocket Hub"])

class MultiplexConnectionManager:
    """
    High-Performance Multiplexed Real-Time WebSocket Hub (<50ms delivery).
    Allows clients to subscribe to multiple channels over a single persistent connection.
    """
    def __init__(self):
        # topic -> Set[WebSocket]
        self._topic_subscribers: Dict[str, Set[WebSocket]] = {}
        # websocket -> Set[topic]
        self._client_topics: Dict[WebSocket, Set[str]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self._client_topics[ws] = {"system", "global_alerts"}
            for t in self._client_topics[ws]:
                self._topic_subscribers.setdefault(t, set()).add(ws)
        logger.info(f"[MultiplexWS] Client connected. Total active: {len(self._client_topics)}")

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            topics = self._client_topics.pop(ws, set())
            for t in topics:
                subscribers = self._topic_subscribers.get(t)
                if subscribers:
                    subscribers.discard(ws)
                    if not subscribers:
                        self._topic_subscribers.pop(t, None)
        logger.info(f"[MultiplexWS] Client disconnected. Remaining: {len(self._client_topics)}")

    async def subscribe(self, ws: WebSocket, topics: List[str]):
        async with self._lock:
            if ws not in self._client_topics:
                return
            for topic in topics:
                clean_topic = topic.strip().lower()
                if not clean_topic:
                    continue
                self._client_topics[ws].add(clean_topic)
                self._topic_subscribers.setdefault(clean_topic, set()).add(ws)

    async def unsubscribe(self, ws: WebSocket, topics: List[str]):
        async with self._lock:
            if ws not in self._client_topics:
                return
            for topic in topics:
                clean_topic = topic.strip().lower()
                self._client_topics[ws].discard(clean_topic)
                if clean_topic in self._topic_subscribers:
                    self._topic_subscribers[clean_topic].discard(ws)

    async def broadcast_to_topic(self, topic: str, payload: Dict[str, Any]):
        clean_topic = topic.strip().lower()
        subscribers = list(self._topic_subscribers.get(clean_topic, set()))
        if not subscribers:
            return

        message = {
            "topic": clean_topic,
            "timestamp": time.time(),
            "data": payload,
        }
        json_str = json.dumps(message, ensure_ascii=False)

        dead_sockets = []
        for ws in subscribers:
            try:
                await ws.send_text(json_str)
            except Exception:
                dead_sockets.append(ws)

        if dead_sockets:
            for ws in dead_sockets:
                await self.disconnect(ws)

    def get_online_count(self, topic: Optional[str] = None) -> int:
        if topic:
            return len(self._topic_subscribers.get(topic.strip().lower(), set()))
        return len(self._client_topics)

multiplex_hub = MultiplexConnectionManager()


@router.websocket("/ws/multiplex")
@router.websocket("/api/ws/multiplex")
@router.websocket("/api/ws/realtime")
async def multiplex_websocket_endpoint(websocket: WebSocket):
    await multiplex_hub.connect(websocket)
    try:
        # Initial greeting with server stats
        await websocket.send_json({
            "type": "welcome",
            "hub": "CityPulse-Multiplex-v2",
            "server_time": time.time(),
            "active_connections": multiplex_hub.get_online_count(),
            "default_topics": ["system", "global_alerts"],
        })

        while True:
            text = await websocket.receive_text()
            try:
                msg = json.loads(text)
            except Exception:
                continue

            action = msg.get("action", "")

            if action == "ping":
                await websocket.send_json({
                    "type": "pong",
                    "timestamp": time.time(),
                    "client_ts": msg.get("timestamp"),
                })

            elif action == "subscribe":
                topics = msg.get("topics", [])
                if isinstance(topics, str):
                    topics = [topics]
                await multiplex_hub.subscribe(websocket, topics)
                await websocket.send_json({
                    "type": "subscribed",
                    "topics": list(multiplex_hub._client_topics.get(websocket, [])),
                })

            elif action == "unsubscribe":
                topics = msg.get("topics", [])
                if isinstance(topics, str):
                    topics = [topics]
                await multiplex_hub.unsubscribe(websocket, topics)
                await websocket.send_json({
                    "type": "unsubscribed",
                    "topics": list(multiplex_hub._client_topics.get(websocket, [])),
                })

            elif action == "publish":
                topic = msg.get("topic", "")
                payload = msg.get("payload", {})
                if topic:
                    await multiplex_hub.broadcast_to_topic(topic, payload)

    except WebSocketDisconnect:
        await multiplex_hub.disconnect(websocket)
    except Exception as e:
        logger.warning(f"[MultiplexWS] Error in socket: {e}")
        await multiplex_hub.disconnect(websocket)

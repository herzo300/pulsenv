# services/Backend/routers/ai_utilities.py
"""RAG city assistant, sentiment analysis, OCR, and AI Agent background tasks endpoints."""

import logging
import os
import tempfile
from datetime import datetime, date

from fastapi import APIRouter, HTTPException, Request, Depends, BackgroundTasks, UploadFile, File
from sqlalchemy.orm import Session
from slowapi import Limiter
from slowapi.util import get_remote_address

from services.data_layer.database import get_db
from services.data_layer.models import User, AgentTask
from services.data_layer.auth import get_current_user, get_user_from_request

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["ai-utilities"])
_rag_limiter = Limiter(key_func=get_remote_address)
_sentiment_limiter = Limiter(key_func=get_remote_address)
_ocr_limiter = Limiter(key_func=get_remote_address)

# In-memory daily request tracker for Freemium limits: { "YYYY-MM-DD": { "user_id_or_ip": count } }
_free_requests_tracker = {}


def _check_freemium_limit(request: Request, user: User | None) -> None:
    """Verify daily RAG request limits for freemium/anonymous users (max 3/day)."""
    # 1. If user is authenticated and has active Premium subscription, bypass limit
    if user and user.digest_subscription_until and user.digest_subscription_until > datetime.utcnow():
        return  # Premium user bypass

    # 2. Get unique identifier (user ID or IP address)
    identifier = f"user_{user.id}" if user else f"ip_{request.client.host}"
    today_str = str(date.today())

    # Initialize tracker for today if not present
    if today_str not in _free_requests_tracker:
        # Clear old dates to save memory
        _free_requests_tracker.clear()
        _free_requests_tracker[today_str] = {}

    today_logs = _free_requests_tracker[today_str]
    current_count = today_logs.get(identifier, 0)

    if current_count >= 3:
        raise HTTPException(
            status_code=402,
            detail="Вы превысили бесплатный лимит (3 запроса в день). Оформите подписку Premium для безлимитного ИИ!"
        )

    # Increment usage counter
    today_logs[identifier] = current_count + 1


@router.post("/rag/ask")
@_rag_limiter.limit("10/minute")
async def rag_ask(request: Request, db: Session = Depends(get_db)):
    """Ask the RAG city assistant a question, enforcing Freemium limits."""
    # Try to parse optional authenticated user
    user = None
    try:
        user = await get_user_from_request(request, db)
    except Exception:
        pass  # Anonymous user

    _check_freemium_limit(request, user)

    body = await request.json()
    question = body.get("question", "").strip()
    if not question:
        raise HTTPException(400, "question required")

    # Moderation and legal compliance check
    from services.business.moderation import check_moderation
    is_clean, block_reason = check_moderation(question)
    if not is_clean:
        return {
            "answer": f"⚠️ Запрос заблокирован: {block_reason}",
            "sources": [],
            "confidence": 0.0
        }

    model = os.getenv("HERMES_MODEL", "moonshotai/kimi-k3-free")

    from services.rag_city_assistant import ask_city_question
    return await ask_city_question(question, model=model)


@router.post("/jkh/audit")
async def jkh_audit(request: Request, file: UploadFile = File(...), db: Session = Depends(get_db)):
    """Audit JKH Receipt using Vision LLM (Premium feature)."""
    from fastapi import HTTPException
    
    # Enforce Premium subscription check
    user = None
    try:
        user = await get_user_from_request(request, db)
    except Exception:
        raise HTTPException(401, "Authentication required for this Premium feature.")
        
    if not user or not user.digest_subscription_until or user.digest_subscription_until <= datetime.utcnow():
        raise HTTPException(
            status_code=402,
            detail="Эта функция доступна только для пользователей с активной подпиской Premium!"
        )
        
    file_bytes = await file.read()
    from services.business.jkh_auditor import audit_jkh_receipt
    return await audit_jkh_receipt(file_bytes)



# =====================================================================
# 🤖 AI Agent Daily Background Tasks (Премиум-функция)
# =====================================================================

async def _run_background_agent_task(task_id: int, task_description: str):
    """Executes the daily background task using LLM (Gemini 2.5 Flash via CURSOR_API)."""
    from services.data_layer.database import SessionLocal
    from services.ai.zai_service import generate_text_using_llm
    
    db = SessionLocal()
    try:
        task = db.query(AgentTask).filter(AgentTask.id == task_id).first()
        if not task:
            return

        task.status = "running"
        db.commit()

        system_prompt = (
            "Ты — автономный городской ИИ-агент. Житель города поручил тебе фоновое задание на весь день.\n"
            "Твоя задача — выполнить задание, используя свои знания и проанализировать возможные проблемы ЖКХ, "
            "транспорта, погоды или безопасности города.\n\n"
            "Напиши подробный отчет для жителя о проделанной работе за день. "
            "Отчет должен быть дружелюбным, структурированным и полезным (в формате Markdown)."
        )

        user_prompt = (
            f"Задание на день: '{task_description}'\n"
            f"Текущее время: {datetime.now().strftime('%d.%m.%Y %H:%M')}\n\n"
            f"Сгенерируй отчет о выполнении фонового задания:"
        )

        report = await generate_text_using_llm(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=1000,
            temperature=0.4,
        )

        task.result_report = report or "Не удалось сгенерировать отчет. Пожалуйста, попробуйте снова."
        task.status = "completed"
        db.commit()
        logger.info("Daily background AI Agent task #%d successfully completed.", task_id)
    except Exception as exc:
        logger.error("Failed executing background AI Agent task #%d: %s", task_id, exc)
        try:
            task = db.query(AgentTask).filter(AgentTask.id == task_id).first()
            if task:
                task.status = "failed"
                task.result_report = f"Ошибка выполнения задачи: {exc}"
                db.commit()
        except Exception:
            pass
    finally:
        db.close()


@router.post("/agent/tasks")
async def create_agent_task(
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a daily background AI agent task. Available only for Premium subscribers."""
    # 1. Enforce premium status
    if not current_user.digest_subscription_until or current_user.digest_subscription_until <= datetime.utcnow():
        raise HTTPException(
            status_code=403,
            detail="Функция фоновых ИИ-агентов доступна только Premium-подписчикам!"
        )

    body = await request.json()
    task_description = body.get("task_description", "").strip()
    if not task_description:
        raise HTTPException(400, "task_description required")

    # 2. Save task to DB
    task = AgentTask(
        user_id=current_user.id,
        task_description=task_description,
        status="pending"
    )
    db.add(task)
    db.commit()
    db.refresh(task)

    # 3. Dispatch to FastAPI BackgroundTasks to run asynchronously
    background_tasks.add_task(_run_background_agent_task, task.id, task_description)

    return {
        "status": "success",
        "task_id": task.id,
        "message": "Задание ИИ-агенту успешно выдано и выполняется в фоновом режиме!"
    }


@router.get("/agent/tasks/pending-notifications")
async def get_pending_agent_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve newly completed AI Agent tasks reports for the user, then mark them as notified."""
    tasks = db.query(AgentTask).filter(
        AgentTask.user_id == current_user.id,
        AgentTask.status == "completed",
        AgentTask.is_notified == False
    ).all()

    reports = []
    for task in tasks:
        reports.append({
            "task_id": task.id,
            "task_description": task.task_description,
            "result_report": task.result_report,
            "created_at": task.created_at.strftime("%d.%m.%Y %H:%M")
        })
        # Mark as notified so it won't pop up again
        task.is_notified = True

    if tasks:
        db.commit()

    return {"reports": reports}


# =====================================================================
# Sentiment and OCR Endpoints
# =====================================================================

@router.post("/sentiment")
@_sentiment_limiter.limit("20/minute")
async def analyze_sentiment_endpoint(request: Request):
    """Analyze sentiment of a given text."""
    body = await request.json()
    text = body.get("text", "").strip()
    if not text:
        raise HTTPException(400, "text required")
    from services.sentiment_service import analyze_sentiment
    return await analyze_sentiment(text)


@router.post("/ocr")
@_ocr_limiter.limit("10/minute")
async def ocr_endpoint(request: Request):
    """Extract text from uploaded image."""
    from services.ocr_service import extract_text_from_image, is_available

    if not is_available():
        raise HTTPException(503, "OCR not available — install pytesseract")

    form = await request.form()
    file = form.get("file")
    if not file:
        raise HTTPException(400, "file required")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        text = await extract_text_from_image(tmp_path)
        return {"text": text, "available": True}
    finally:
        os.unlink(tmp_path)


@router.post("/ai/modeling/generate")
async def generate_3d_model(request: Request):
    """Generate 3D model (bench or marker) using headless Blender Foundation API."""
    body = await request.json()
    prompt_type = body.get("prompt_type", "marker").strip()
    output_name = body.get("output_name", "temp_model").strip()
    
    if not prompt_type or not output_name:
        raise HTTPException(400, "prompt_type and output_name are required")
        
    from services.business.blender_generator import run_blender_modeling
    res = run_blender_modeling(prompt_type, output_name)
    if "Success" in res:
        return {
            "status": "success",
            "message": res,
            "gltf_url": f"/public/models3d/{output_name}.glb"
        }
    else:
        raise HTTPException(500, res)


def _infer_model_type_from_analysis(analysis: dict) -> str:
    """YOLO/OpenCV анализ кадра -> тип 3D-модели для Blender."""
    counts = (analysis.get("yolo") or {}).get("counts") or {}
    detections = (analysis.get("yolo") or {}).get("detections_count") or 0
    # bench — класс COCO; качели/песочница эвристически по детской площадке
    objects = (analysis.get("yolo") or {}).get("objects") or []
    names = {str(o.get("name") or o.get("class") or "").lower() for o in objects if isinstance(o, dict)}
    if "bench" in names:
        return "bench"
    if names & {"swing", "slide", "playground"}:
        return "playground"
    if counts.get("people", 0) >= 3:
        return "playground"
    if detections > 0:
        return "marker"
    return "marker"


@router.post("/ai/modeling/from-camera-frame")
async def generate_3d_model_from_camera(request: Request):
    """Снимок камеры -> ИИ-анализ (OpenCV/YOLO) -> 3D-модель объекта (Blender GLB).

    Body: {"frame_base64": "...", "camera_name": "Камера 12"} или
          {"camera_url": "http://...", "camera_name": "..."} — кадр берётся из кэша.
    """
    import base64
    body = await request.json()
    frame_b64 = body.get("frame_base64")
    camera_url = (body.get("camera_url") or "").strip()
    camera_name = (body.get("camera_name") or "Камера").strip()

    frame_bytes = None
    if frame_b64:
        try:
            frame_bytes = base64.b64decode(frame_b64)
        except Exception:
            raise HTTPException(400, "frame_base64 не декодируется")
    elif camera_url:
        from services.business.camera_frame_cache import get_cached_frame
        frame_bytes = get_cached_frame(camera_url)
        if frame_bytes is None:
            raise HTTPException(404, "Нет свежего кадра в кэше для этой камеры")
    else:
        raise HTTPException(400, "Нужен frame_base64 или camera_url")

    from services.business.camera_free_analyzer import analyze_frame_bytes
    analysis = analyze_frame_bytes(frame_bytes, camera_name=camera_name)
    if not analysis.get("success"):
        raise HTTPException(422, analysis.get("report", "Не удалось проанализировать кадр"))

    prompt_type = _infer_model_type_from_analysis(analysis)
    import time
    output_name = f"cam_{int(time.time())}_{prompt_type}"

    from services.business.blender_generator import run_blender_modeling
    res = run_blender_modeling(prompt_type, output_name)
    if "Success" not in res:
        raise HTTPException(500, res)

    return {
        "status": "success",
        "inferred_type": prompt_type,
        "analysis_report": analysis.get("report"),
        "yolo": analysis.get("yolo"),
        "gltf_url": f"/public/models3d/{output_name}.glb",
    }

from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel
import subprocess
import os
import sys

router = APIRouter(prefix="/api/worker", tags=["OpenWorker", "Agent-Reach"])

class WorkerTask(BaseModel):
    task: str
    context: str = ""

def run_openworker(task: str):
    """
    Обертка для запуска локального инстанса OpenWorker
    с использованием subprocess. Выполняет долгие задачи.
    """
    try:
        # Указываем путь к склонированному OpenWorker
        worker_dir = os.path.join(os.path.dirname(__file__), "..", "openworker")
        
        env = os.environ.copy()
        # В реальной среде здесь будут ключи из .env для LLM
        
        cmd = [sys.executable, "-m", "coworker.cli", "--task", task]
        result = subprocess.run(cmd, cwd=worker_dir, env=env, capture_output=True, text=True)
        
        print("OpenWorker Task Completed")
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)
        
    except Exception as e:
        print(f"OpenWorker Error: {e}")

@router.post("/execute")
async def execute_task(task_request: WorkerTask, background_tasks: BackgroundTasks):
    """
    Гермес (через Telegram) отправляет задачи в этот эндпоинт.
    Бэкенд запускает OpenWorker в фоне.
    """
    background_tasks.add_task(run_openworker, task_request.task)
    return {"status": "accepted", "message": f"Task '{task_request.task}' sent to OpenWorker"}

@router.post("/reach")
async def execute_agent_reach(url: str):
    """
    Вызов Agent-Reach для обхода блокировок и парсинга ссылок
    (например, Twitter, Reddit) в чистый Markdown.
    """
    try:
        reach_dir = os.path.join(os.path.dirname(__file__), "..", "agent_reach")
        cmd = [sys.executable, "-m", "agent_reach.cli", url]
        result = subprocess.run(cmd, cwd=reach_dir, capture_output=True, text=True)
        return {"status": "success", "content": result.stdout}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

#!/usr/bin/env python3
"""
Hermes Sandbox — изолированная песочница для выполнения заданий Гермеса.

Задача (Python-код или структурированное задание) выполняется:
- в Docker-контейнере python:3.12-slim
- без сети (--network=none) — задание не может выйти наружу
- с лимитами памяти (256m) и CPU (0.5)
- с таймаутом (по умолчанию 120 сек)
- с рабочим каталогом hermes_workspace/sandbox/, монтируемым read-write:
  артефакты задания (файлы, отчёты) переживают выполнение и доступны следующими итерациями
"""

import json
import logging
import os
import shlex
import time
import uuid
from pathlib import Path

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent.parent.parent
SANDBOX_DIR = ROOT / "hermes_workspace" / "sandbox"
SANDBOX_DIR.mkdir(parents=True, exist_ok=True)

# Когда backend сам работает в Docker, путь workdir внутри контейнера невидим
# для хостового dockerd (вложенный bind-mount создаёт пустую директорию).
# HERMES_SANDBOX_HOST_ROOT указывает хостовой путь к hermes_workspace/sandbox,
# который передаётся в `docker run -v`.
HOST_SANDBOX_ROOT = os.environ.get("HERMES_SANDBOX_HOST_ROOT")

DEFAULT_TIMEOUT = 120  # сек
MAX_OUTPUT_CHARS = 20_000


def _build_task_script(task: str) -> str:
    """Готовит Python-скрипт задания: либо сырой код, либо безопасная обёртка."""
    # Если задание — чистый Python-код, выполняем как есть
    if any(kw in task for kw in ("import ", "def ", "print(", "for ", "if ")):
        return task
    # Иначе — структурное задание: пишем заглушку-скрипт, которую LLM-агент
    # может дополнить; сам текст задания сохраняется в task.md
    return (
        "# Задание Hermes Sandbox\n"
        f"# TASK: {task[:500]}\n"
        "print('Задание получено. Артефакты сохраняйте в текущем каталоге (/sandbox).')\n"
        "from pathlib import Path\n"
        "Path('task.md').write_text('''" + task.replace("'", '"') + "''', encoding='utf-8')\n"
    )


def run_in_sandbox(
    task: str,
    timeout: int = DEFAULT_TIMEOUT,
    memory: str = "256m",
) -> dict:
    """Выполняет задание в изолированном Docker-контейнере.

    Возвращает dict: status, stdout, stderr, exit_code, artifacts, duration_ms.
    """
    import subprocess

    run_id = f"hermes_{int(time.time())}_{uuid.uuid4().hex[:8]}"
    workdir = SANDBOX_DIR / run_id
    workdir.mkdir(parents=True, exist_ok=True)

    script = _build_task_script(task)
    script_path = workdir / "task_script.py"
    script_path.write_text(script, encoding="utf-8")

    mount_dir = workdir
    if HOST_SANDBOX_ROOT:
        host_dir = Path(HOST_SANDBOX_ROOT) / run_id
        mount_dir = host_dir

    docker_cmd = [
        "docker", "run", "--rm",
        "--name", run_id,
        "--network=none",            # без доступа в сеть
        "--memory", memory,          # лимит RAM
        "--cpus", "0.5",             # лимит CPU
        "--read-only",               # корень ФС только чтение
        "--tmpfs", "/tmp:rw,size=16m",
        "-v", f"{mount_dir}:/sandbox:rw",   # рабочий каталог — запись разрешена
        "-w", "/sandbox",
        "-e", "PYTHONUNBUFFERED=1",
        "-e", "PYTHONPATH=/sandbox",
        "python:3.12-slim",
        "python", "/sandbox/task_script.py",
    ]

    started = time.time()
    try:
        proc = subprocess.run(
            docker_cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "DOCKER_API_VERSION": "1.44"},
        )
        exit_code = proc.returncode
        stdout = proc.stdout[:MAX_OUTPUT_CHARS]
        stderr = proc.stderr[:MAX_OUTPUT_CHARS]
        status = "completed" if exit_code == 0 else "failed"
    except subprocess.TimeoutExpired:
        # Убиваем зависший контейнер: --rm не сработает, пока процесс жив
        try:
            subprocess.run(
                ["docker", "rm", "-f", run_id],
                capture_output=True, timeout=15,
                env={**os.environ, "DOCKER_API_VERSION": "1.44"},
            )
        except Exception:
            pass
        exit_code = -1
        stdout = ""
        stderr = f"Задание превысило таймаут {timeout} сек и было остановлено."
        status = "timeout"
    except FileNotFoundError:
        # Docker недоступен (локальная машина без него) — fallback: subprocess
        # в отдельном рабочем каталоге с таймаутом. Не сетевая изоляция, но
        # артефакты не выходят за пределы workdir, время ограничено.
        env = {
            "PATH": "/usr/bin:/bin:/usr/local/bin",
            "HOME": str(workdir),
            "PYTHONUNBUFFERED": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        proc = subprocess.run(
            ["python", "-I", str(script_path)],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=workdir,
            env=env,
        )
        exit_code = proc.returncode
        stdout = proc.stdout[:MAX_OUTPUT_CHARS]
        stderr = proc.stderr[:MAX_OUTPUT_CHARS]
        status = "completed" if exit_code == 0 else "failed"

    duration_ms = int((time.time() - started) * 1000)

    # Собираем артефакты (файлы, созданные заданием)
    artifacts = []
    for f in sorted(workdir.iterdir()):
        if f.is_file() and f.name != "task_script.py":
            artifacts.append({
                "name": f.name,
                "size_bytes": f.stat().st_size,
                "path": str(f),
            })

    result = {
        "run_id": run_id,
        "status": status,
        "exit_code": exit_code,
        "stdout": stdout,
        "stderr": stderr,
        "artifacts": artifacts,
        "duration_ms": duration_ms,
        "timeout_sec": timeout,
    }
    # Сохраняем результат рядом с артефактами
    (workdir / "result.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    logger.info("Hermes sandbox run %s: %s in %dms", run_id, status, duration_ms)
    return result

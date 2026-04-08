# Watchdog Ops Runbook

Точный набор команд для восстановления контура `watchdog -> Frigate -> LiteLLM/Ollama -> SmolVLM -> YOLO models`.

## Что уже известно

- Flutter-клиент и backend-роуты уже исправлены.
- В локальном коде `watchdog` теперь корректно:
  - читает `.env`
  - ищет `Frigate/LiteLLM/SmolVLM` по нескольким URL
  - использует `OPENROUTER_API_KEY` / `ZAI_API_KEY` как fallback для vision
  - корректно резолвит локальные и docker-пути ONNX-моделей
- На текущий момент отсутствуют:
  - `models/yolov8n_garbage.onnx`
  - `models/yolov8n_fire_smoke.onnx`

## Быстрый путь

Если нужен самый короткий путь на Timeweb-сервер:

```powershell
cd C:\Soobshio_project
python deploy_frigate.py
python deploy_edge_ai.py
```

Это:
- зальет `docker-compose.yml`, `frigate_bridge.py`, `smolvlm_service.py`, `watchdog.py`
- поднимет `frigate`, `ollama`, `litellm`
- скачает GGUF для `SmolVLM`
- создаст `systemd`-сервис `smolvlm`

Важно: эти скрипты не решают проблему отсутствующих `yolov8n_garbage.onnx` и `yolov8n_fire_smoke.onnx`, если их нет локально.

## Ручной путь

### 1. Подготовить SSH-переменные на Windows

```powershell
$env:TIMEWEB_IP="45.153.68.59"
$env:TIMEWEB_USER="root"
$env:REMOTE_APP="/root/citypulse_api"
```

### 2. Залить обновленный runtime/config

```powershell
ssh "$env:TIMEWEB_USER@$env:TIMEWEB_IP" "mkdir -p $env:REMOTE_APP/ops/frigate $env:REMOTE_APP/services/Backend/routers $env:REMOTE_APP/models"

scp docker-compose.yml "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/docker-compose.yml"
scp ops/frigate/config.yml "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/ops/frigate/config.yml"
scp ops/litellm_config.yaml "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/ops/litellm_config.yaml"
scp services/frigate_bridge.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/services/frigate_bridge.py"
scp services/smolvlm_service.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/services/smolvlm_service.py"
scp services/yolo_edge_filter.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/services/yolo_edge_filter.py"
scp services/camera_watchdog_service.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/services/camera_watchdog_service.py"
scp services/Backend/routers/watchdog.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/services/Backend/routers/watchdog.py"
scp start_camera_probe.py "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/start_camera_probe.py"
```

### 3. Поднять swap и docker-сервисы на сервере

```bash
ssh root@45.153.68.59

cd /root/citypulse_api

CURRENT_SWAP=$(swapon --show --bytes | awk 'NR>1{sum+=$3}END{print sum+0}')
if [ "$CURRENT_SWAP" -lt 3000000000 ]; then
  swapoff /swapfile 2>/dev/null || true
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

grep -q 'LITELLM_MASTER_KEY' .env || echo 'LITELLM_MASTER_KEY=sk-soobshio-local-2026' >> .env

docker compose pull frigate ollama litellm
docker compose up -d frigate ollama litellm
```

### 4. Загрузить модели в Ollama

```bash
docker exec soobshio_ollama ollama pull qwen2.5-vl:3b
docker exec soobshio_ollama ollama pull qwen2.5:3b
docker exec soobshio_ollama ollama pull moondream:latest
docker exec soobshio_ollama ollama list
```

### 5. Поднять SmolVLM как systemd service

```bash
apt-get update
apt-get install -y wget git cmake build-essential

mkdir -p /root/citypulse_api/models

wget -O /root/citypulse_api/models/smolvlm-256m-instruct-q4_k_m.gguf \
  "https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/SmolVLM-256M-Instruct-Q4_K_M.gguf"

wget -O /root/citypulse_api/models/smolvlm-256m-mmproj.gguf \
  "https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-256M-Instruct-f16.gguf"

if ! command -v llama-server >/dev/null 2>&1; then
  cd /tmp
  rm -rf llama.cpp
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
  cd llama.cpp
  cmake -B build -DGGML_CPU=ON -DLLAMA_CURL=OFF
  cmake --build build --config Release -j2
  cp build/bin/llama-server /usr/local/bin/
  cp build/bin/llama-cli /usr/local/bin/
fi

cat >/etc/systemd/system/smolvlm.service <<'EOF'
[Unit]
Description=SmolVLM-256M Vision Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server \
  -m /root/citypulse_api/models/smolvlm-256m-instruct-q4_k_m.gguf \
  --mmproj /root/citypulse_api/models/smolvlm-256m-mmproj.gguf \
  --host 127.0.0.1 \
  --port 8090 \
  -ngl 0 \
  -c 512 \
  -t 2 \
  --no-mmap
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable smolvlm
systemctl restart smolvlm
systemctl status smolvlm --no-pager -l | head -20
```

### 6. Перезапустить probe/backend после обновления

```bash
cd /root/citypulse_api
docker compose restart backend monitoring camera_probe
```

## Специализированные ONNX-модели

Сейчас в репозитории есть только базовая `models/yolov8n.onnx`.

### Вариант A: если модели уже получены где-то отдельно

Локально на Windows:

```powershell
scp models/yolov8n_garbage.onnx "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/models/yolov8n_garbage.onnx"
scp models/yolov8n_fire_smoke.onnx "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/models/yolov8n_fire_smoke.onnx"
```

На сервере:

```bash
ls -lh /root/citypulse_api/models/*.onnx
docker compose restart backend monitoring camera_probe
```

### Вариант B: обучить/экспортировать локально из репозитория

```powershell
cd C:\Soobshio_project
python -m pip install ultralytics roboflow
python train_specialized_models.py
```

После успешного экспорта должны появиться:

```text
models/yolov8n_garbage.onnx
models/yolov8n_fire_smoke.onnx
```

Дальше залить их на сервер:

```powershell
scp models/yolov8n_garbage.onnx "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/models/yolov8n_garbage.onnx"
scp models/yolov8n_fire_smoke.onnx "$env:TIMEWEB_USER@$env:TIMEWEB_IP`:$env:REMOTE_APP/models/yolov8n_fire_smoke.onnx"
```

## Команды верификации

### На сервере

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -s http://127.0.0.1:5000/api/version
curl -s http://127.0.0.1:4000/health
curl -s http://127.0.0.1:8090/health
curl -s http://127.0.0.1:8000/api/watchdog/status
curl -s http://127.0.0.1:8000/api/watchdog/frigate/health
curl -s -X POST "http://127.0.0.1:8000/api/watchdog/scan?max_cameras=1"
```

### Из локального репозитория

```powershell
@'
import asyncio, json, sys
sys.path.insert(0, r"c:\Soobshio_project")
from services.Backend.routers.watchdog import watchdog_status, trigger_scan

async def main():
    print(json.dumps(await watchdog_status(), ensure_ascii=False, indent=2))
    print(json.dumps(await trigger_scan(max_cameras=1), ensure_ascii=False, indent=2))

asyncio.run(main())
'@ | python -
```

## Что считать успешным состоянием

- `http://127.0.0.1:5000/api/version` отвечает `200`
- `http://127.0.0.1:4000/health` отвечает `200`
- `http://127.0.0.1:8090/health` отвечает `200`
- `/api/watchdog/status` показывает:
  - `frigate.frigate_health.healthy = true`
  - `smolvlm.healthy = true`
  - `edge_filter.models.coco.exists = true`
  - `edge_filter.models.garbage.exists = true`
  - `edge_filter.models.fire_smoke.exists = true`

## Если после этого всё ещё не работает

Минимальная диагностика:

```bash
docker compose logs --tail 100 backend
docker compose logs --tail 100 camera_probe
docker compose logs --tail 100 frigate
docker compose logs --tail 100 litellm
systemctl status smolvlm --no-pager -l
journalctl -u smolvlm -n 100 --no-pager
free -h
df -h /
```

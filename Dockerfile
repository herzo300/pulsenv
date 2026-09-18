# =============================================================================
# Stage 1: builder — install build deps and compile Python wheels
# =============================================================================
FROM python:3.12-slim-bookworm AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Build-time dependencies (gcc, g++, libpq-dev) — these do NOT leak into production
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# =============================================================================
# Stage 2: runtime — lean production image (no gcc/g++, only libpq5)
# =============================================================================
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

# Runtime dependencies only.
# libpq5 is the shared library needed by psycopg2 at runtime (no -dev, no compilers).
# docker.io-cli + curl: CLI для Hermes Sandbox (запуск заданий в изолированных
# контейнерах через смонтированный /var/run/docker.sock).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libpq5 \
    libglib2.0-0 \
    git \
    docker.io \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled site-packages from the builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Selective copy — only what the application actually needs
COPY core/ /app/core/
COPY services/ /app/services/
COPY public/ /app/public/
COPY alembic/ /app/alembic/
COPY ops/ /app/ops/
COPY main.py /app/main.py
COPY start_all_monitoring.py /app/start_all_monitoring.py
COPY start_camera_probe.py /app/start_camera_probe.py
COPY scripts/maintenance/ /app/scripts/maintenance/
COPY scripts/lost_found_daily_pipeline.py /app/scripts/lost_found_daily_pipeline.py
COPY scripts/hermes_city_changes_monitor.py /app/scripts/hermes_city_changes_monitor.py
COPY models/ /app/models/
COPY requirements.txt /app/requirements.txt
COPY data/uk_catalog.json /app/data/uk_catalog.json


# uvloop is Linux-only; on Windows the code falls back to the asyncio event loop.
# This image runs on Linux, so uvloop is always available here.

# Create unprivileged user, required directories, and set ownership
RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /app/static/uploads /app/logs /app/data /app/models \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Production: 2 workers with uvloop for concurrency.
# Note: uvloop is Linux-only (falls back to asyncio on Windows during local dev).
CMD ["uvicorn", "services.Backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--loop", "uvloop"]

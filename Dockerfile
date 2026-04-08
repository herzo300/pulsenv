FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    gcc \
    g++ \
    libpq-dev \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

COPY . /app

# Copy YOLO model if exists (exported locally via export_yolo_model.py)
RUN mkdir -p /app/models

RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /app/static/uploads /app/logs /app/data \
    && chown -R appuser:appuser /app


USER appuser

EXPOSE 8000

CMD ["uvicorn", "services.Backend.app:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]

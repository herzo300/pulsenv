#!/bin/bash
# Initial Ollama model bootstrap for the Soobshio stack.
# Run after the first docker-compose up:
#   docker exec -it soobshio_ollama bash /init_models.sh

set -e

echo "==============================================="
echo "  Ollama Model Loader - Soobshio"
echo "==============================================="

echo ""
echo "[1/4] Pulling Qwen2.5-VL 3B..."
ollama pull qwen2.5vl:3b
echo "OK: qwen2.5vl:3b"

echo ""
echo "[2/4] Pulling Qwen2.5 3B for interactive local routes..."
ollama pull qwen2.5:3b
echo "OK: qwen2.5:3b"

echo ""
echo "[3/4] Pulling Qwen3 4B Q4_K_M for batch/background..."
ollama pull qwen3:4b-q4_K_M
echo "OK: qwen3:4b-q4_K_M"

echo ""
echo "[4/4] Pulling Moondream..."
ollama pull moondream:latest
echo "OK: moondream:latest"

echo ""
echo "Installed models:"
ollama list

echo ""
echo "Interactive test:"
echo "  curl http://ollama:11434/api/generate -d '{\"model\":\"qwen2.5:3b\",\"prompt\":\"Hello\"}'"
echo "Batch test:"
echo "  curl http://ollama:11434/api/generate -d '{\"model\":\"qwen3:4b-q4_K_M\",\"prompt\":\"Hello\"}'"

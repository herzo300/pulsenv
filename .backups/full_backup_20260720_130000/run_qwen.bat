@echo off
set OPENAI_API_KEY=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
set OPENAI_BASE_URL=https://openrouter.ai/api/v1
set QWEN_MODEL_ID=qwen/qwen3.6-plus

qwen --auth-type openai --model %QWEN_MODEL_ID% %*

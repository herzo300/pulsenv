# OpenClaude Lite

Lightweight local CLI with an OpenClaude-like workflow.

Features:
- Works from any project directory after installation.
- Reads `.env.local` and `.env` from the current project tree.
- Talks to any OpenAI-compatible API, including LiteLLM and local gateways.
- Supports text chat, interactive REPL, image prompts, and model listing.

Default behavior:
- Base URL: `http://127.0.0.1:4000/v1`
- API key source: `LITELLM_MASTER_KEY`
- Model: `qwen-mini`

Install on the current PC:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\openclaude_lite\install_user.ps1
```

After installation:

```powershell
oclaude --print-config
oclaude "Explain this repository"
openclaude --list-models
```

Per-project overrides:
- `OPENCLAUDE_BASE_URL`
- `OPENCLAUDE_API_KEY`
- `OPENCLAUDE_MODEL`
- `LITELLM_URL`
- `LITELLM_MASTER_KEY`
- `LITELLM_MODEL`

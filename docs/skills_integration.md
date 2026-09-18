# Integration of Developer & AI Skills (rtk, skills, openserp)

This project integrates three powerful developer and AI assistant enhancement packages: `rtk`, `skills`, and `openserp`.

## 1. rtk (Token Compression Proxy)
`rtk` is a tool for optimizing agent/AI terminal runs by compressing tokens and caching prompts.
- **Config**: Local scripts and environment configuration.
- **Usage**: When launching agent tasks in terminal environments (e.g., executing Python backend or Flutter tasks), run them through the token proxy to minimize token overhead.

## 2. skills (Design Engineering Rules)
Inspired by `emilkowalski/skills`, this project enforces strict styling constraints directly inside IDEs:
- Enforced globally via `.cursorrules` in Cursor.
- Configured via `.vscode/settings.json` in VS Code.
- These rules instruct AI code assistants (Cursor, Copilot, Gemini Antigravity) to always use:
  - Curated HSL colors (no default raw colors).
  - Physics-based spring animations.
  - Interactive micro-animations (scale-on-press, custom tilts).
  - Clean modular architecture interfaces.

## 3. openserp (Self-Hosted SERP Scraper)
`openserp` is a self-hosted search engine API that allows retrieving Google/Bing search results programmatically without needing external API keys.
- **Docker Compose Service**:
  We have configured a self-hosted `openserp` service in the main `docker-compose.yml` running on port `7000`.
- **Startup**:
  To start OpenSERP, simply run:
  ```bash
  docker compose up -d openserp
  ```
- **Usage**:
  Query the local instance via HTTP:
  ```bash
  curl "http://localhost:7000/google/search?q=Нижневартовск+события"
  ```

# OpenClaude-Lite Installation Plan

Goal: provide a local, globally callable CLI with an OpenClaude-like workflow
without using the leaked fork.

Constraints:
- No new Python dependencies.
- Keep changes isolated from existing app code.
- Prefer existing LiteLLM / OpenAI-compatible endpoints already used in the repo.

Implementation steps:
1. Add a standalone Python CLI under `tools/openclaude_lite/`.
2. Support `.env` discovery so the CLI works across different projects.
3. Support OpenAI-compatible chat completions and model listing.
4. Add a user installer that copies the CLI into the user profile and creates
   `oclaude` / `openclaude` command wrappers.
5. Verify syntax, wrapper installation, and resolved runtime configuration.

Simplifications:
- Use the standard library only.
- Default to LiteLLM on `http://127.0.0.1:4000/v1`.
- Store global defaults in `%USERPROFILE%\.openclaude-lite.json`.

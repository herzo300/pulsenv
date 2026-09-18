#!/usr/bin/env python3
"""OpenClaude-like CLI over any OpenAI-compatible endpoint."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_BASE_URL = "http://127.0.0.1:4000/v1"
DEFAULT_MODEL = "qwen-mini"
CONFIG_PATH = Path.home() / ".openclaude-lite.json"
ENV_FILES = (".env.local", ".env")


def _load_dotenv_files(start_dir: Path) -> None:
    """Load project env files into the process if keys are not already set."""
    for current in (start_dir, *start_dir.parents):
        for env_name in ENV_FILES:
            env_path = current / env_name
            if env_path.is_file():
                _load_dotenv_file(env_path)


def _load_dotenv_file(path: Path) -> None:
    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _load_user_config() -> dict[str, Any]:
    if not CONFIG_PATH.is_file():
        return {}
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def _normalize_base_url(raw_url: str | None) -> str:
    url = (raw_url or "").strip().rstrip("/")
    if not url:
        return DEFAULT_BASE_URL
    if url.endswith("/v1"):
        return url
    return f"{url}/v1"


def _resolve_base_url(config: dict[str, Any], cli_value: str | None) -> str:
    if cli_value:
        return _normalize_base_url(cli_value)
    if os.getenv("OPENCLAUDE_BASE_URL"):
        return _normalize_base_url(os.environ["OPENCLAUDE_BASE_URL"])
    if os.getenv("LITELLM_URL"):
        return _normalize_base_url(os.environ["LITELLM_URL"])
    return _normalize_base_url(str(config.get("base_url") or DEFAULT_BASE_URL))


def _resolve_api_key(config: dict[str, Any], cli_value: str | None) -> str:
    if cli_value:
        return cli_value
    if os.getenv("OPENCLAUDE_API_KEY"):
        return os.environ["OPENCLAUDE_API_KEY"]

    env_name = (
        os.getenv("OPENCLAUDE_API_KEY_ENV")
        or str(config.get("api_key_env") or "")
        or "LITELLM_MASTER_KEY"
    )
    env_name = env_name.strip()
    if env_name and os.getenv(env_name):
        return os.environ[env_name]
    if os.getenv("OPENAI_API_KEY"):
        return os.environ["OPENAI_API_KEY"]
    return ""


def _resolve_model(config: dict[str, Any], cli_value: str | None) -> str:
    if cli_value:
        return cli_value
    for env_name in ("OPENCLAUDE_MODEL", "LITELLM_MODEL", "OPENAI_MODEL"):
        if os.getenv(env_name):
            return os.environ[env_name]
    return str(config.get("model") or DEFAULT_MODEL)


def _resolved_config(args: argparse.Namespace) -> dict[str, Any]:
    config = _load_user_config()
    return {
        "base_url": _resolve_base_url(config, args.base_url),
        "api_key": _resolve_api_key(config, args.api_key),
        "model": _resolve_model(config, args.model),
        "timeout": int(args.timeout),
        "temperature": args.temperature,
        "max_tokens": args.max_tokens,
    }


def _request(
    method: str,
    url: str,
    payload: dict[str, Any] | None,
    headers: dict[str, str],
    timeout: int,
) -> tuple[int, str]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url=url, data=body, method=method)
    for key, value in headers.items():
        request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def _request_stream(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> None:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url=url, data=body, method="POST")
    for key, value in headers.items():
        request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line or not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    print()
                    return
                try:
                    chunk = json.loads(data)
                except json.JSONDecodeError:
                    continue
                delta = (
                    chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
                )
                if delta:
                    print(delta, end="", flush=True)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {error_body}") from exc


def _build_user_content(
    prompt: str, image_path: str | None
) -> list[dict[str, Any]] | str:
    if not image_path:
        return prompt
    path = Path(image_path).expanduser().resolve()
    image_b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    return [
        {"type": "text", "text": prompt},
        {
            "type": "image_url",
            "image_url": {"url": f"data:{mime};base64,{image_b64}"},
        },
    ]


def _chat_payload(
    system_prompt: str | None,
    prompt: str,
    history: list[dict[str, Any]] | None,
    image_path: str | None,
    cfg: dict[str, Any],
    stream: bool,
) -> dict[str, Any]:
    messages: list[dict[str, Any]] = []
    if history:
        messages.extend(history)
    elif system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    messages.append(
        {
            "role": "user",
            "content": _build_user_content(prompt=prompt, image_path=image_path),
        }
    )
    payload: dict[str, Any] = {
        "model": cfg["model"],
        "messages": messages,
        "temperature": cfg["temperature"],
        "stream": stream,
    }
    if cfg["max_tokens"] is not None:
        payload["max_tokens"] = cfg["max_tokens"]
    return payload


def _headers(api_key: str) -> dict[str, str]:
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    return headers


def _extract_message_text(raw_response: str) -> str:
    data = json.loads(raw_response)
    return data.get("choices", [{}])[0].get("message", {}).get("content", "")


def _print_json(data: Any) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def _print_effective_config(cfg: dict[str, Any]) -> None:
    redacted = dict(cfg)
    api_key = redacted.get("api_key", "")
    redacted["api_key"] = f"{api_key[:4]}..." if api_key else ""
    _print_json(redacted)


def _list_models(cfg: dict[str, Any]) -> int:
    status, body = _request(
        method="GET",
        url=f"{cfg['base_url']}/models",
        payload=None,
        headers=_headers(cfg["api_key"]),
        timeout=cfg["timeout"],
    )
    if status != 200:
        print(body, file=sys.stderr)
        return 1

    data = json.loads(body)
    _print_json(data)
    return 0


def _single_shot(args: argparse.Namespace, cfg: dict[str, Any]) -> int:
    prompt = " ".join(args.prompt).strip() or "Describe the current repository."
    payload = _chat_payload(
        system_prompt=args.system,
        prompt=prompt,
        history=None,
        image_path=args.image,
        cfg=cfg,
        stream=args.stream,
    )
    if args.stream:
        try:
            _request_stream(
                url=f"{cfg['base_url']}/chat/completions",
                payload=payload,
                headers=_headers(cfg["api_key"]),
                timeout=cfg["timeout"],
            )
            return 0
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 1

    status, body = _request(
        method="POST",
        url=f"{cfg['base_url']}/chat/completions",
        payload=payload,
        headers=_headers(cfg["api_key"]),
        timeout=cfg["timeout"],
    )
    if status != 200:
        print(body, file=sys.stderr)
        return 1

    if args.json:
        print(body)
    else:
        print(_extract_message_text(body))
    return 0


def _interactive_chat(args: argparse.Namespace, cfg: dict[str, Any]) -> int:
    print(f"OpenClaude Lite connected to {cfg['base_url']} with model {cfg['model']}")
    print("Commands: /exit /reset /models /config")
    history: list[dict[str, Any]] = []
    if args.system:
        history.append({"role": "system", "content": args.system})

    while True:
        try:
            prompt = input("you> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0

        if not prompt:
            continue
        if prompt in {"/exit", "/quit"}:
            return 0
        if prompt == "/reset":
            history = history[:1] if history and history[0]["role"] == "system" else []
            print("history cleared")
            continue
        if prompt == "/config":
            _print_effective_config(cfg)
            continue
        if prompt == "/models":
            _list_models(cfg)
            continue

        payload = _chat_payload(
            system_prompt=args.system,
            prompt=prompt,
            history=history,
            image_path=None,
            cfg=cfg,
            stream=False,
        )
        status, body = _request(
            method="POST",
            url=f"{cfg['base_url']}/chat/completions",
            payload=payload,
            headers=_headers(cfg["api_key"]),
            timeout=cfg["timeout"],
        )
        if status != 200:
            print(body, file=sys.stderr)
            continue

        reply = _extract_message_text(body)
        print(f"ai> {reply}")
        history.append({"role": "user", "content": prompt})
        history.append({"role": "assistant", "content": reply})


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="oclaude",
        description="OpenClaude-like CLI over LiteLLM or any OpenAI-compatible API.",
    )
    parser.add_argument(
        "prompt", nargs="*", help="Prompt text. If omitted, starts interactive chat."
    )
    parser.add_argument("--system", help="Optional system prompt.")
    parser.add_argument("--model", help="Override model name.")
    parser.add_argument("--base-url", help="Override base URL.")
    parser.add_argument("--api-key", help="Override API key.")
    parser.add_argument(
        "--timeout", type=int, default=120, help="HTTP timeout in seconds."
    )
    parser.add_argument(
        "--temperature", type=float, default=0.2, help="Sampling temperature."
    )
    parser.add_argument(
        "--max-tokens", type=int, default=None, help="Optional max_tokens."
    )
    parser.add_argument(
        "--image", help="Optional image path for vision-capable models."
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print raw JSON response for one-shot prompts.",
    )
    parser.add_argument(
        "--list-models", action="store_true", help="List available models."
    )
    parser.add_argument(
        "--print-config", action="store_true", help="Print resolved runtime config."
    )
    parser.add_argument(
        "--stream",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Enable or disable response streaming for one-shot prompts.",
    )
    return parser


def main() -> int:
    _load_dotenv_files(Path.cwd())
    parser = _build_parser()
    args = parser.parse_args()
    cfg = _resolved_config(args)

    if args.print_config:
        _print_effective_config(cfg)
        return 0
    if args.list_models:
        return _list_models(cfg)
    if args.prompt:
        return _single_shot(args, cfg)
    return _interactive_chat(args, cfg)


if __name__ == "__main__":
    raise SystemExit(main())

"""Compatibility shim for the relocated agent runtime module."""

from services.ai import agent_runtime as _impl
from services.ai.agent_runtime import *  # noqa: F401,F403

_call_chat_completion = _impl._call_chat_completion


async def run_agent_task(db, request):
    """Proxy that preserves the historical patch point used by tests."""
    original = _impl._call_chat_completion
    _impl._call_chat_completion = _call_chat_completion
    try:
        return await _impl.run_agent_task(db, request)
    finally:
        _impl._call_chat_completion = original

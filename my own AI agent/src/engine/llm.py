"""Local LLM client — talks to Ollama on your machine (no cloud API)."""

from __future__ import annotations

import json
from typing import Any

import httpx

from config.settings import OLLAMA_BASE_URL, OLLAMA_MODEL


class OllamaError(RuntimeError):
    pass


def chat(
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """
    Call Ollama /api/chat. Returns the assistant message dict.
    Supports tool calling when the model supports it (qwen2.5, llama3.1, etc.).
    """
    payload: dict[str, Any] = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "stream": False,
    }
    if tools:
        payload["tools"] = tools

    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload)
            response.raise_for_status()
    except httpx.ConnectError as e:
        raise OllamaError(
            "Cannot connect to Ollama. Install from https://ollama.com/download "
            f"and run: ollama pull {OLLAMA_MODEL}"
        ) from e
    except httpx.HTTPStatusError as e:
        raise OllamaError(f"Ollama HTTP error: {e.response.text}") from e

    data = response.json()
    message = data.get("message")
    if not message:
        raise OllamaError(f"Unexpected Ollama response: {json.dumps(data)[:500]}")
    return message


def message_text(message: dict[str, Any]) -> str:
    return str(message.get("content") or "")


def message_tool_calls(message: dict[str, Any]) -> list[dict[str, Any]]:
    return list(message.get("tool_calls") or [])

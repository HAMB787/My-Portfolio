"""
Core agent loop — local Ollama + data tools.

Flow:
  1. Build messages (system + history + user)
  2. Call Ollama with tool definitions
  3. If tool_calls → permission check → run tool → append result
  4. Repeat until text reply or max rounds
"""

from __future__ import annotations

import json
from typing import Any

from config.settings import MAX_TOOL_ROUNDS
from src.engine.context import build_system_prompt
from src.engine.llm import OllamaError, chat, message_text, message_tool_calls
from src.permissions.gate import check_permission
from src.tools.registry import get_all_tools, run_tool


def _tool_schemas() -> list[dict[str, Any]]:
    return [t.to_openai_tool() for t in get_all_tools()]


def run_agent_turn(user_message: str, history: list[dict]) -> str:
    messages: list[dict[str, Any]] = [
        {"role": "system", "content": build_system_prompt()},
        *history,
        {"role": "user", "content": user_message},
    ]
    tools = _tool_schemas()

    for _ in range(MAX_TOOL_ROUNDS):
        try:
            assistant = chat(messages, tools=tools)
        except OllamaError as e:
            return str(e)

        tool_calls = message_tool_calls(assistant)
        if not tool_calls:
            return message_text(assistant) or "(empty response)"

        # Ollama tool-call turn: append assistant message then tool results
        messages.append(assistant)

        for call in tool_calls:
            fn = call.get("function") or {}
            name = fn.get("name", "")
            raw_args = fn.get("arguments", "{}")
            try:
                args = json.loads(raw_args) if isinstance(raw_args, str) else raw_args
            except json.JSONDecodeError:
                args = {}

            decision = check_permission(name, args)
            if decision == "deny":
                result = f"Permission denied for tool '{name}'."
            elif decision == "ask":
                result = f"Tool '{name}' needs user approval (blocked in auto mode)."
            else:
                result = run_tool(name, args)

            messages.append(
                {
                    "role": "tool",
                    "content": result,
                    "tool_name": name,
                }
            )

    return "Stopped: reached max tool rounds. Try a simpler question."

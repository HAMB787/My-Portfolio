"""Base tool interface (inspired by Tool.ts)."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class Tool(ABC):
    """Every agent capability implements this interface."""

    name: str
    description: str

    @abstractmethod
    def parameters_schema(self) -> dict[str, Any]:
        """JSON schema for LLM tool parameters."""

    @abstractmethod
    def run(self, arguments: dict[str, Any]) -> str:
        """Execute the tool and return a string result for the LLM."""

    def is_read_only(self) -> bool:
        return True

    def is_destructive(self) -> bool:
        return False

    def to_openai_tool(self) -> dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters_schema(),
            },
        }

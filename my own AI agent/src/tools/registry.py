"""Tool registry — data analytics tools for the local agent."""

from __future__ import annotations

from typing import Any

from src.tools.base import Tool
from src.tools.describe_data import DescribeDataTool
from src.tools.list_datasets import ListDatasetsTool
from src.tools.load_dataset import LoadDatasetTool
from src.tools.run_sql import RunSqlTool

_TOOLS: list[Tool] = [
    ListDatasetsTool(),
    LoadDatasetTool(),
    DescribeDataTool(),
    RunSqlTool(),
]


def get_all_tools() -> list[Tool]:
    return list(_TOOLS)


def get_tool_by_name(name: str) -> Tool | None:
    for tool in _TOOLS:
        if tool.name == name:
            return tool
    return None


def run_tool(name: str, arguments: dict[str, Any]) -> str:
    tool = get_tool_by_name(name)
    if tool is None:
        return f"Error: unknown tool '{name}'"
    return tool.run(arguments)

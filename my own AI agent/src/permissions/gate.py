"""Permission gate — block dangerous SQL and destructive loads."""

from __future__ import annotations

import re
from typing import Any, Literal

from src.tools.registry import get_tool_by_name

PermissionDecision = Literal["allow", "deny", "ask"]

_WRITE_SQL = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE|REPLACE|GRANT|REVOKE)\b",
    re.IGNORECASE,
)


def check_permission(tool_name: str, arguments: dict[str, Any]) -> PermissionDecision:
    tool = get_tool_by_name(tool_name)
    if tool is None:
        return "deny"

    if tool_name == "run_sql":
        query = str(arguments.get("query", ""))
        if _WRITE_SQL.search(query):
            return "deny"
        return "allow"

    if tool_name == "load_dataset":
        # Replacing a table is allowed in auto mode for thesis demo;
        # change to "ask" if you want manual confirm in CLI later.
        return "allow"

    if tool.is_destructive():
        return "ask"

    return "allow"

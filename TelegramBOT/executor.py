"""Secure sandbox for LLM-generated pandas/matplotlib code."""

from __future__ import annotations

import ast
import asyncio
import io
import logging
import re
from typing import Any

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import seaborn as sns  # noqa: E402

logger = logging.getLogger(__name__)

SECURITY_VALIDATION_MSG = "Generated code failed security validation."
NO_RESULT_MSG = "No result or chart was produced. Try rephrasing your question."

RUNTIME_BANNED = (
    "__import__",
    "open(",
    "eval(",
    "exec(",
    "compile(",
    "globals(",
    "locals(",
    "getattr(",
    "setattr(",
    "breakpoint(",
    "input(",
)

SAFE_BUILTINS: dict[str, Any] = {
    "print": print,
    "len": len,
    "range": range,
    "enumerate": enumerate,
    "zip": zip,
    "sum": sum,
    "min": min,
    "max": max,
    "round": round,
    "sorted": sorted,
    "list": list,
    "dict": dict,
    "tuple": tuple,
    "set": set,
    "str": str,
    "int": int,
    "float": float,
    "bool": bool,
    "abs": abs,
    "isinstance": isinstance,
    "True": True,
    "False": False,
    "None": None,
}


def _strip_import_lines(code: str) -> str:
    """Remove import lines; pd, np, plt, sns, df, tables are injected by the sandbox."""
    cleaned: list[str] = []
    for line in code.splitlines():
        stripped = line.strip()
        if stripped.startswith("import ") or stripped.startswith("from "):
            continue
        cleaned.append(line)
    return "\n".join(cleaned).strip()


def contains_dangerous_code(code: str) -> bool:
    """Return True if code contains imports or blocked runtime patterns."""
    try:
        tree = ast.parse(code)
    except SyntaxError:
        return True

    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            return True

    for pattern in RUNTIME_BANNED:
        if pattern in code:
            return True

    return False


def _strip_markdown_fences(code: str) -> str:
    text = code.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:python)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _run_code_sync(
    code: str,
    tables: dict[str, pd.DataFrame],
) -> tuple[str | None, bytes | None]:
    """Execute code in a restricted namespace. Returns (text, png_bytes).

    Injects:
      - ``tables`` — all uploaded DataFrames keyed by filename stem
      - ``df``     — most recently uploaded table (single-table shorthand)
      - ``pd, np, plt, sns``
    """
    code = _strip_import_lines(code)
    if not code:
        return SECURITY_VALIDATION_MSG, None
    if contains_dangerous_code(code):
        return SECURITY_VALIDATION_MSG, None

    df_latest = list(tables.values())[-1] if tables else pd.DataFrame()

    local_vars: dict[str, Any] = {
        "tables": {name: frame.copy() for name, frame in tables.items()},
        "df": df_latest.copy(),
        "pd": pd,
        "np": np,
        "plt": plt,
        "sns": sns,
        "result": None,
        "fig": None,
    }
    restricted_globals = {"__builtins__": SAFE_BUILTINS}

    try:
        exec(code, restricted_globals, local_vars)  # noqa: S102
    except Exception as exc:
        logger.exception("Sandbox execution failed")
        return f"Execution error: {type(exc).__name__}: {exc}", None

    fig = local_vars.get("fig")
    if fig is not None:
        try:
            buf = io.BytesIO()
            fig.savefig(buf, format="png", bbox_inches="tight", dpi=150)
            plt.close(fig)
            buf.seek(0)
            return None, buf.getvalue()
        except Exception as exc:
            logger.exception("Failed to save figure")
            return f"Execution error: {type(exc).__name__}: {exc}", None

    result = local_vars.get("result")
    if result is not None:
        return str(result), None

    plt.close("all")
    return NO_RESULT_MSG, None


async def execute_llm_code(
    code: str,
    tables: dict[str, pd.DataFrame],
) -> tuple[str | None, bytes | None]:
    """Run LLM-generated code in a sandboxed environment."""
    clean_code = _strip_markdown_fences(code)
    return await asyncio.to_thread(_run_code_sync, clean_code, tables)

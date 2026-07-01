"""Generate and run safe pandas/matplotlib code via OpenAI."""

from __future__ import annotations

import ast
import io
import json
import logging
import re
from dataclasses import dataclass
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import seaborn as sns  # noqa: E402
from openai import OpenAI

logger = logging.getLogger(__name__)

FORBIDDEN_PATTERNS = (
    r"\bimport\b",
    r"\bfrom\b",
    r"\bopen\s*\(",
    r"\bexec\s*\(",
    r"\beval\s*\(",
    r"\bcompile\s*\(",
    r"\b__\w+__",
    r"\bos\.",
    r"\bsys\.",
    r"\bsubprocess\b",
    r"\bsocket\b",
    r"\brequests\b",
    r"\bpathlib\b",
    r"\bshutil\b",
    r"\bpickle\b",
    r"\bbuiltins\b",
    r"\bglobals\s*\(",
    r"\blocals\s*\(",
    r"\bgetattr\s*\(",
    r"\bsetattr\s*\(",
    r"\bdelattr\s*\(",
    r"\bbreakpoint\s*\(",
    r"\binput\s*\(",
)

SAFE_BUILTINS: dict[str, Any] = {
    "len": len,
    "range": range,
    "str": str,
    "int": int,
    "float": float,
    "list": list,
    "dict": dict,
    "tuple": tuple,
    "set": set,
    "bool": bool,
    "min": min,
    "max": max,
    "sum": sum,
    "abs": abs,
    "round": round,
    "sorted": sorted,
    "zip": zip,
    "enumerate": enumerate,
    "print": print,
    "isinstance": isinstance,
    "True": True,
    "False": False,
    "None": None,
}

SYSTEM_PROMPT = """You are a senior data analyst helping a business user query a pandas DataFrame named `df`.

You will receive dataset metadata (columns, dtypes, sample rows, row count).

Return ONLY valid JSON with this exact shape:
{
  "kind": "text" or "chart",
  "code": "<python code>",
  "summary": "<1-3 sentence business-friendly explanation>"
}

Rules for `code`:
- Use only: df, pd, np, plt, sns. Do NOT import anything.
- For text answers (`kind` = "text"): compute the answer and assign a string or number to variable `result`.
- For charts (`kind` = "chart"): build a clear chart, then save to BytesIO variable `chart_buffer` using:
  fig, ax = plt.subplots(...)
  ...
  chart_buffer = io.BytesIO()
  fig.savefig(chart_buffer, format='png', bbox_inches='tight', dpi=120)
  plt.close(fig)
- Use only column names that exist in the schema. If the question cannot be answered, set kind to "text" and result to a helpful message explaining what is missing.
- Prefer robust pandas: handle missing values, parse dates when needed, use coalesce-style logic for divisions.
- Keep code short (under 40 lines). No file I/O, no network, no os/sys.
"""


@dataclass
class AnalystResult:
    kind: str  # "text" | "chart"
    summary: str
    text: str | None = None
    chart_png: bytes | None = None
    error: str | None = None


def build_dataset_context(df: pd.DataFrame, sample_rows: int = 5) -> str:
    """Compact schema + sample for the LLM (not the full dataset)."""
    sample = df.head(sample_rows)
    dtypes = df.dtypes.astype(str).to_dict()
    nulls = df.isna().sum().to_dict()
    lines = [
        f"rows: {len(df)}",
        f"columns ({len(df.columns)}): {list(df.columns)}",
        f"dtypes: {dtypes}",
        f"null_counts: {nulls}",
        "sample_rows:",
        sample.to_string(index=False),
    ]
    return "\n".join(lines)


def _validate_code(code: str) -> None:
    for pattern in FORBIDDEN_PATTERNS:
        if re.search(pattern, code, flags=re.IGNORECASE):
            raise ValueError(f"Unsafe code pattern blocked: {pattern}")

    tree = ast.parse(code)
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            raise ValueError("Imports are not allowed in generated code.")


def _run_code(code: str, df: pd.DataFrame) -> tuple[str | None, bytes | None]:
    _validate_code(code)

    namespace: dict[str, Any] = {
        "df": df.copy(),
        "pd": pd,
        "np": np,
        "plt": plt,
        "sns": sns,
        "io": io,
        "result": None,
        "chart_buffer": None,
    }
    safe_globals = {"__builtins__": SAFE_BUILTINS}

    exec(code, safe_globals, namespace)  # noqa: S102 — sandboxed analyst execution

    result = namespace.get("result")
    chart_buffer = namespace.get("chart_buffer")

    text = None if result is None else str(result)

    chart_png = None
    if chart_buffer is not None and hasattr(chart_buffer, "getvalue"):
        chart_buffer.seek(0)
        chart_png = chart_buffer.getvalue()

    if not chart_png:
        fig = plt.gcf()
        if fig.get_axes():
            buf = io.BytesIO()
            fig.savefig(buf, format="png", bbox_inches="tight", dpi=120)
            plt.close(fig)
            chart_png = buf.getvalue()

    plt.close("all")
    return text, chart_png


def _parse_llm_json(content: str) -> dict[str, Any]:
    content = content.strip()
    if content.startswith("```"):
        content = re.sub(r"^```(?:json)?\s*", "", content)
        content = re.sub(r"\s*```$", "", content)
    payload = json.loads(content)
    if not isinstance(payload, dict):
        raise ValueError("LLM response must be a JSON object.")
    return payload


class DataAnalyst:
    def __init__(self, api_key: str, model: str = "gpt-4o-mini") -> None:
        self.client = OpenAI(api_key=api_key)
        self.model = model

    def analyze(self, df: pd.DataFrame, question: str) -> AnalystResult:
        context = build_dataset_context(df)
        user_prompt = f"Dataset:\n{context}\n\nUser question:\n{question}"

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0.1,
            )
            raw = response.choices[0].message.content or "{}"
            payload = _parse_llm_json(raw)
        except Exception as exc:
            logger.exception("OpenAI request failed")
            return AnalystResult(
                kind="text",
                summary="Could not reach the AI service.",
                error=str(exc),
            )

        kind = str(payload.get("kind", "text")).lower()
        code = str(payload.get("code", "")).strip()
        summary = str(payload.get("summary", "Here is the answer."))

        if not code:
            return AnalystResult(
                kind="text",
                summary=summary,
                text="I could not generate analysis code for that question.",
            )

        try:
            text, chart_png = _run_code(code, df)
        except Exception as exc:
            logger.exception("Code execution failed")
            return AnalystResult(
                kind="text",
                summary=summary,
                error=f"Analysis failed: {exc}",
            )

        if kind == "chart":
            if chart_png:
                return AnalystResult(
                    kind="chart",
                    summary=summary,
                    chart_png=chart_png,
                )
            return AnalystResult(
                kind="text",
                summary=summary,
                text=text or "Chart could not be generated. Try rephrasing the question.",
            )

        return AnalystResult(
            kind="text",
            summary=summary,
            text=text or "No numeric or text result was produced.",
        )

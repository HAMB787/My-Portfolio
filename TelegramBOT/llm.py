"""Groq (OpenAI-compatible) prompt building and query execution with retry on code errors."""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import pandas as pd
from openai import AsyncOpenAI

from executor import NO_RESULT_MSG, SECURITY_VALIDATION_MSG, execute_llm_code

logger = logging.getLogger(__name__)

GROQ_BASE_URL = "https://api.groq.com/openai/v1"
DEFAULT_GROQ_MODEL = "llama-3.3-70b-versatile"
FALLBACK_GROQ_MODEL = "llama-3.1-8b-instant"

FAILURE_PREFIXES = (
    "Execution error:",
    SECURITY_VALIDATION_MSG,
    NO_RESULT_MSG,
)

SYSTEM_INSTRUCTIONS = """You are a Python data analyst. You have access to one or more pandas DataFrames and a user question.
Write Python code to answer the question.

Rules:
1. DataFrames are pre-loaded. Do NOT load or read any files.
2. For text answers: store the final answer in a variable called `result` (string or scalar).
3. For charts: use plt or sns, then assign the figure to `fig`. Example:
   fig, ax = plt.subplots(figsize=(10, 6))
   df.groupby("category")["sales"].sum().plot(kind="bar", ax=ax)
   ax.set_title("Sales by category")
4. NEVER write import or from lines. These names already exist: df, tables, pd, np, plt, sns.
5. Do NOT call plt.show().
6. Use ONLY column names exactly as listed in the schema (case-sensitive). Never invent column names.
7. For single-table questions, prefer `df` (most recent table). Use `tables['name']` only when multiple tables are loaded.
8. If the question truly cannot be answered, set result = "I cannot answer that from the available data."
9. Return ONLY executable Python code. No explanation, no markdown fences.

Multi-table access:
- `df`                  — the most recently uploaded single DataFrame (single-table shorthand)
- `tables`              — dict of ALL uploaded DataFrames keyed by filename stem
- `tables['sales']`     — access a specific table by name
- To join: merged = tables['sales'].merge(tables['customers'], on='customer_id')
"""

CHART_KEYWORDS = (
    "chart", "plot", "graph", "bar", "line", "pie",
    "histogram", "visual", "dashboard", "scatter", "heatmap",
)


# ─── DataFrame info builders ─────────────────────────────────────────────────

def _single_table_info(name: str, df: pd.DataFrame, max_rows: int = 3) -> str:
    sample = df.head(max_rows).to_string(max_cols=20)
    dtypes = df.dtypes.to_string()
    nulls = df.isnull().sum().to_string()
    size_note = (
        f"\nNOTE: Large dataset ({df.shape[0]:,} rows). "
        "Prefer aggregations over row-level operations."
        if df.shape[0] > 100_000 else ""
    )
    col_list = ", ".join(f"`{c}`" for c in df.columns)
    return (
        f"Table: `{name}`  ({df.shape[0]:,} rows × {df.shape[1]} columns)\n"
        f"Column names (use exactly): {col_list}\n"
        f"Dtypes:\n{dtypes}\n"
        f"Nulls:\n{nulls}\n"
        f"Sample (first {max_rows} rows):\n{sample}"
        f"{size_note}"
    )


def get_tables_info(tables: dict[str, pd.DataFrame], max_rows: int = 3) -> str:
    """Build compact schema + sample for ALL loaded tables."""
    if not tables:
        return "No DataFrames loaded."

    if len(tables) == 1:
        name, df = next(iter(tables.items()))
        return _single_table_info(name, df, max_rows)

    # Multi-table: show schema for each, detect potential join keys
    sections = [
        f"You have {len(tables)} tables loaded. "
        "Access them via the `tables` dict.\n"
    ]
    for name, df in tables.items():
        sections.append(_single_table_info(name, df, max_rows))

    # Hint about shared column names that could be join keys
    col_sets = [set(df.columns) for df in tables.values()]
    shared = col_sets[0].intersection(*col_sets[1:])
    if shared:
        sections.append(
            f"\nPotential join keys (columns shared across all tables): "
            + ", ".join(f"`{c}`" for c in sorted(shared))
        )

    return "\n\n".join(sections)


# ─── Prompt building ─────────────────────────────────────────────────────────

def _wants_chart(question: str) -> bool:
    return any(kw in question.lower() for kw in CHART_KEYWORDS)


def build_prompt(
    tables_info: str,
    user_question: str,
    error_context: str = "",
) -> str:
    prompt = f"Available Data:\n{tables_info}\n\nUser Question: {user_question}"

    if _wants_chart(user_question):
        prompt += (
            "\n\nThis is a CHART request. Build a plot and assign the matplotlib "
            "figure to variable `fig`. Do not use any import statements."
        )

    if error_context:
        prompt += f"\n\nPrevious attempt failed:\n{error_context}\nFix the code."

    return prompt


# ─── Groq client helpers ─────────────────────────────────────────────────────

def _strip_code_from_response(content: str) -> str:
    text = content.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:python)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _is_execution_failure(text: str | None) -> bool:
    if not text:
        return False
    return any(text.startswith(p) for p in FAILURE_PREFIXES)


def _create_groq_client() -> AsyncOpenAI:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise ValueError("GROQ_API_KEY is not set in .env")
    return AsyncOpenAI(api_key=api_key, base_url=GROQ_BASE_URL)


def _model_chain(preferred: str) -> list[str]:
    chain = [preferred.strip()]
    for name in (FALLBACK_GROQ_MODEL, DEFAULT_GROQ_MODEL):
        if name not in chain:
            chain.append(name)
    return chain


def _is_model_unavailable_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return (
        "model_decommissioned" in msg
        or "decommissioned" in msg
        or ("404" in msg and "model" in msg)
        or ("not found" in msg and "model" in msg)
    )


async def _chat_completion(
    client: AsyncOpenAI,
    model_names: list[str],
    prompt: str,
) -> str:
    last_error: Exception | None = None
    for index, name in enumerate(model_names):
        try:
            response = await client.chat.completions.create(
                model=name,
                messages=[
                    {"role": "system", "content": SYSTEM_INSTRUCTIONS},
                    {"role": "user", "content": prompt},
                ],
                temperature=0,
            )
            return response.choices[0].message.content or ""
        except Exception as exc:
            last_error = exc
            if _is_model_unavailable_error(exc) and index + 1 < len(model_names):
                logger.warning(
                    "Model %s unavailable (%s). Falling back to %s.",
                    name, exc, model_names[index + 1],
                )
                continue
            raise
    raise last_error or RuntimeError("No Groq models available.")


# ─── Public API ──────────────────────────────────────────────────────────────

async def query_with_retry(
    question: str,
    tables: dict[str, pd.DataFrame],
    client: Any | None = None,
    model: str | None = None,
    max_retries: int = 2,
) -> tuple[str | None, bytes | None]:
    """Ask Groq for analysis code, execute in sandbox, retry on execution errors.

    Args:
        question: User's natural-language question.
        tables:   All loaded DataFrames keyed by filename stem.
        client:   Optional pre-built AsyncOpenAI client.
        model:    Override the Groq model name.
        max_retries: Number of code-fix retries on execution failure.

    Returns:
        ``(text_answer, None)`` or ``(None, image_bytes)``.
    """
    if client is None:
        try:
            client = _create_groq_client()
        except ValueError as exc:
            return str(exc), None

    preferred = model or os.getenv("GROQ_MODEL", DEFAULT_GROQ_MODEL)
    model_names = _model_chain(preferred)
    tables_info = get_tables_info(tables)
    error_context = ""

    for attempt in range(max_retries + 1):
        prompt = build_prompt(tables_info, question, error_context)
        try:
            raw = await _chat_completion(client, model_names, prompt)
            code = _strip_code_from_response(raw)
        except Exception as exc:
            logger.exception("Groq API call failed")
            return f"AI service error: {exc}", None

        if not code:
            error_context = "The model returned empty code."
            continue

        text, image = await execute_llm_code(code, tables)

        if image is not None:
            return text, image

        if (
            text is not None
            and not _is_execution_failure(text)
            and text != "I cannot answer that from the available data."
        ):
            return text, None

        if text == SECURITY_VALIDATION_MSG:
            error_context = (
                "Code was blocked: remove ALL import/from lines. "
                "Use only df, tables, pd, np, plt, sns (already available). "
                "For charts, assign the figure to `fig`."
            )
        elif text and text.startswith("Execution error:"):
            col_hint = "; ".join(
                f"{name}: [{', '.join(df.columns)}]"
                for name, df in tables.items()
            )
            error_context = (
                f"{text}\n"
                f"Available columns per table: {col_hint}. "
                "Use `df` for one table. Fix column names to match exactly."
            )
        elif text == "I cannot answer that from the available data.":
            col_hint = "; ".join(
                f"{name}: [{', '.join(df.columns)}]"
                for name, df in tables.items()
            )
            error_context = (
                "Do not give up. Re-read the column names and write code using the correct ones. "
                f"Columns: {col_hint}"
            )
        else:
            error_context = text or "Unknown execution failure."

        logger.warning("Attempt %s failed: %s", attempt + 1, error_context)

    return (
        "Could not process your question after multiple attempts. Try rephrasing.",
        None,
    )
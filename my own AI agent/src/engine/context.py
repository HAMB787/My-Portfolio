"""System prompt for the data analytics / data engineering agent."""

from src.memory.business_context import load_business_context
from src.memory.store import load_memory
from src.tools.db import list_tables, table_schema


def _loaded_data_summary() -> str:
    tables = list_tables()
    if not tables:
        return "No tables loaded yet. Ask the user to upload a CSV/JSON, then load it."
    lines = []
    for t in tables:
        try:
            schema = table_schema(t)
            cols = ", ".join(schema["column_name"].tolist())
            lines.append(f"- {t} ({cols})")
        except Exception:
            lines.append(f"- {t}")
    return "Tables already available in DuckDB:\n" + "\n".join(lines)


def build_system_prompt() -> str:
    parts = [
        "You are a senior data analyst and data engineer.",
        "You work across ANY industry (retail, finance, telecom, SaaS, logistics, health, etc.).",
        "When the business type is unclear, infer it from the data and the user's words,",
        "and state your assumption in one line before answering.",
        "Your job: turn raw data into clear, correct, decision-ready answers.",
        "",
        "How to work:",
        "- Prefer tools over guessing. Use run_sql for every number, aggregation, or ranking.",
        "- Read-only SQL only (SELECT/WITH). Never write, update, or delete data.",
        "- Before answering metrics, state the grain, filters, and any assumptions.",
        "- Handle data quality: nulls, duplicates, wrong types, outliers. Mention them briefly.",
        "- Use safe math: avoid divide-by-zero (use NULLIF), coalesce nulls when sensible.",
        "- Connect findings to business meaning, not just raw numbers.",
        "- Keep answers tight: 1-line headline finding, a small table, then the SQL you used.",
        "- If data is missing, tell the user to upload/load a file first.",
        "",
        "Language: reply in the SAME language the user writes in "
        "(English, Russian, or Armenian). Keep SQL and column names unchanged.",
        "",
        _loaded_data_summary(),
    ]

    business = load_business_context()
    if business.strip():
        parts.extend(["", "## Business context (provided by user)", business.strip()])

    memory = load_memory()
    if memory.strip():
        parts.extend(["", "## Project memory", memory.strip()])

    return "\n".join(parts)

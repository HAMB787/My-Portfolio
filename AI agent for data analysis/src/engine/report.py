"""Auto-generate a data report for a table (profile + agent narrative)."""

from __future__ import annotations

from src.engine.query_loop import run_agent_turn
from src.tools.profiling import classify_columns, profile_table, row_count


def generate_report(table: str) -> str:
    """Produce a markdown report: stats + an LLM narrative with key insights."""
    rows = row_count(table)
    prof = profile_table(table)
    cols = classify_columns(table)

    missing = prof[prof["nulls"] > 0]
    quality_lines = []
    if len(missing):
        for _, r in missing.iterrows():
            quality_lines.append(f"- `{r['column']}`: {r['nulls']} missing ({r['null_%']}%)")
    else:
        quality_lines.append("- No missing values detected.")

    header = [
        f"# Data report — `{table}`",
        "",
        f"**Rows:** {rows:,}  ·  **Columns:** {len(prof)}",
        "",
        "## Column profile",
        prof.to_markdown(index=False),
        "",
        "## Data quality",
        *quality_lines,
        "",
        "## Key insights",
    ]

    prompt = (
        f"Write 4-6 short bullet insights about the '{table}' table for a business reader. "
        f"It has {rows} rows. Numeric columns: {cols['numeric']}. "
        f"Categorical: {cols['categorical']}. Use run_sql to find the most important "
        "facts (top categories, totals, averages, notable patterns). "
        "Return only the bullets."
    )
    narrative = run_agent_turn(prompt, [])

    return "\n".join(header) + "\n" + narrative

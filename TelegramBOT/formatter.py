"""Telegram HTML message formatters for the AI Data Analyst bot."""

from __future__ import annotations

import html
from typing import Any

import pandas as pd


# ─── Helpers ────────────────────────────────────────────────────────────────

def esc(text: Any) -> str:
    """Escape a value for safe HTML rendering in Telegram."""
    return html.escape(str(text))


def _dtype_emoji(dtype_str: str) -> str:
    """Return a small emoji hint for a pandas dtype string."""
    d = dtype_str.lower()
    if "int" in d or "float" in d:
        return "🔢"
    if "datetime" in d or "period" in d:
        return "📅"
    if "bool" in d:
        return "✅"
    return "🔤"


# ─── Start / Help ────────────────────────────────────────────────────────────

def fmt_start() -> str:
    return (
        "👋 <b>AI Data Analyst</b>\n\n"
        "I can analyze your CSV files and answer questions in plain English.\n\n"
        "<b>Getting started:</b>\n"
        "  📂 Upload one or more <code>.csv</code> files\n"
        "  💬 Ask anything — KPIs, trends, comparisons\n"
        "  📊 Request charts — bar, line, pie, histogram…\n\n"
        "<b>Multi-table example:</b>\n"
        "  Upload <code>sales.csv</code> and <code>customers.csv</code>, then ask:\n"
        "  <i>«Join sales and customers on customer_id and show revenue by region»</i>\n\n"
        "<b>Commands:</b>\n"
        "  /tables — list all loaded tables\n"
        "  /clear  — remove all loaded data\n"
        "  /ping   — connection test"
    )


def fmt_ping() -> str:
    return "🟢 <b>Pong!</b> Bot is alive."


# ─── CSV Upload ──────────────────────────────────────────────────────────────

def fmt_csv_loaded(name: str, df: pd.DataFrame) -> str:
    """Summary card shown after a single CSV is loaded."""
    rows, cols = df.shape
    col_lines = "\n".join(
        f"  {_dtype_emoji(str(dtype))} <code>{esc(col)}</code>  "
        f"<i>{esc(dtype)}</i>"
        f"{' — ⚠️ has nulls' if bool(df[col].isnull().any()) else ''}"
        for col, dtype in df.dtypes.items()
    )
    preview = esc(df.head(3).to_string(index=False))
    return (
        f"✅ <b>{esc(name)}</b> loaded\n\n"
        f"📐 <b>Shape:</b> {rows:,} rows × {cols} columns\n\n"
        f"<b>Columns:</b>\n{col_lines}\n\n"
        f"<b>Preview (first 3 rows):</b>\n"
        f"<pre>{preview}</pre>\n\n"
        "💬 Ask me anything about this data."
    )


def fmt_table_added_to_session(name: str, total: int) -> str:
    """Short notification when a table is added to an existing multi-table session."""
    return (
        f"➕ <b>{esc(name)}</b> added  (<b>{total}</b> table{'s' if total > 1 else ''} loaded)\n\n"
        "Use /tables to see all loaded tables, or ask a question that spans them.\n"
        "<i>Example: «Join sales and customers on customer_id»</i>"
    )


# ─── /tables command ─────────────────────────────────────────────────────────

def fmt_tables_overview(tables: dict[str, pd.DataFrame]) -> str:
    """Full summary of all loaded tables."""
    if not tables:
        return "📭 No tables loaded yet. Upload a <code>.csv</code> file to get started."

    lines = [f"📋 <b>{len(tables)} table{'s' if len(tables) > 1 else ''} loaded</b>\n"]
    for i, (name, df) in enumerate(tables.items(), 1):
        rows, cols = df.shape
        col_names = ", ".join(f"<code>{esc(c)}</code>" for c in df.columns[:6])
        if len(df.columns) > 6:
            col_names += f" <i>+{len(df.columns) - 6} more</i>"
        lines.append(
            f"  <b>{i}. {esc(name)}</b>  {rows:,} × {cols}\n"
            f"     {col_names}"
        )

    if len(tables) > 1:
        names = list(tables.keys())
        lines.append(
            f"\n💡 <i>Tip: Ask me to join or compare tables.\n"
            f"Example: «Merge {esc(names[0])} and {esc(names[1])} on a common column»</i>"
        )

    return "\n".join(lines)


# ─── /clear command ──────────────────────────────────────────────────────────

def fmt_cleared() -> str:
    return "🗑️ All loaded tables have been cleared. Upload a new CSV to start fresh."


# ─── Errors & Validation ─────────────────────────────────────────────────────

def fmt_no_data() -> str:
    return (
        "📭 <b>No data loaded.</b>\n\n"
        "Upload a <code>.csv</code> file first, then ask your question."
    )


def fmt_question_too_long(length: int, limit: int) -> str:
    return (
        f"✂️ Your question is too long (<b>{length}</b> chars).\n"
        f"Please keep it under <b>{limit}</b> characters."
    )


def fmt_csv_error(exc: Exception) -> str:
    return f"❌ <b>Could not read CSV:</b>\n<code>{esc(exc)}</code>"


def fmt_wrong_file_type() -> str:
    return "📎 Please upload a <code>.csv</code> file."


# ─── Analysis status / results ───────────────────────────────────────────────

def fmt_analyzing() -> str:
    return "⏳ <i>Analyzing your data…</i>"


def fmt_no_result() -> str:
    return "🤷 No result was returned. Try rephrasing your question."


def fmt_chart_caption(text: str | None) -> str:
    if text:
        return f"📊 {esc(text)}"[:1024]
    return "📊 Here is your chart."
"""FastAPI REST API for the Data AI Agent (wraps existing engine/tools)."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from config.settings import OLLAMA_MODEL, RAW_DIR
from src.engine.query_loop import run_agent_turn
from src.tools.load_dataset import SUPPORTED, load_file_into_table
from src.tools.db import list_tables
from src.tools.profiling import profile_table, row_count

app = FastAPI(
    title="Data AI Agent API",
    description="Local analytics agent — Ollama + DuckDB",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── request / response models ──────────────────────────────────────────────


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    history: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    reply: str


class ColumnProfile(BaseModel):
    column: str
    type: str
    nulls: int
    null_pct: float = Field(alias="null_%")
    distinct: int

    model_config = {"populate_by_name": True}


class TableInfo(BaseModel):
    name: str
    row_count: int
    profile: list[ColumnProfile]


class TablesResponse(BaseModel):
    tables: list[TableInfo]


class UploadResponse(BaseModel):
    filename: str
    table_name: str
    message: str
    success: bool


# ── helpers ────────────────────────────────────────────────────────────────


def _table_name_from_filename(filename: str) -> str:
    stem = Path(filename).stem.lower().replace(" ", "_").replace("-", "_")
    stem = re.sub(r"[^a-z0-9_]", "", stem)
    return stem or "dataset"


def _history_to_dicts(history: list[ChatMessage]) -> list[dict]:
    return [{"role": m.role, "content": m.content} for m in history]


def _profile_to_models(table: str) -> list[ColumnProfile]:
    df = profile_table(table)
    records = df.to_dict(orient="records")
    return [ColumnProfile.model_validate(r) for r in records]


# ── endpoints ──────────────────────────────────────────────────────────────


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok", "model": OLLAMA_MODEL}


@app.post("/api/chat", response_model=ChatResponse)
def chat_endpoint(body: ChatRequest) -> ChatResponse:
    history = _history_to_dicts(body.history)
    reply = run_agent_turn(body.message.strip(), history)
    return ChatResponse(reply=reply)


@app.post("/api/upload", response_model=UploadResponse)
async def upload_endpoint(
    file: UploadFile = File(...),
    table_name: str | None = Form(default=None),
) -> UploadResponse:
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is required")

    suffix = Path(file.filename).suffix.lower()
    if suffix not in SUPPORTED:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported format. Supported: {', '.join(sorted(SUPPORTED))}",
        )

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    dest = RAW_DIR / Path(file.filename).name
    content = await file.read()
    dest.write_bytes(content)

    table = (table_name or _table_name_from_filename(file.filename)).strip()
    result = load_file_into_table(dest.name, table)

    success = not result.startswith("Error") and not result.startswith("Load error")
    if not success:
        raise HTTPException(status_code=422, detail=result)

    return UploadResponse(
        filename=dest.name,
        table_name=table,
        message=result,
        success=True,
    )


@app.get("/api/tables", response_model=TablesResponse)
def tables_endpoint() -> TablesResponse:
    names = list_tables()
    tables: list[TableInfo] = []
    for name in names:
        try:
            tables.append(
                TableInfo(
                    name=name,
                    row_count=row_count(name),
                    profile=_profile_to_models(name),
                )
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to profile table '{name}': {e}",
            ) from e
    return TablesResponse(tables=tables)


@app.delete("/api/tables/{table_name}")
def delete_table_endpoint(table_name: str) -> dict:
    """Drop a table from the DuckDB warehouse."""
    from src.tools.db import get_connection

    names = list_tables()
    if table_name not in names:
        raise HTTPException(status_code=404, detail=f"Table '{table_name}' not found")

    con = get_connection()
    try:
        con.execute(f'DROP TABLE IF EXISTS "{table_name}"')
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete table: {e}") from e
    finally:
        con.close()

    return {"success": True, "message": f"Table '{table_name}' deleted successfully"}


@app.get("/api/tables/{table_name}/charts")
def table_charts_endpoint(table_name: str) -> dict:
    """Return chart-ready data for a specific table."""
    from src.tools.profiling import classify_columns
    from src.tools.db import query_df

    names = list_tables()
    if table_name not in names:
        raise HTTPException(status_code=404, detail=f"Table '{table_name}' not found")

    classes = classify_columns(table_name)
    total = row_count(table_name)

    # Bar charts for categorical columns (top 10 values each)
    bar_charts = []
    for col in classes.get("categorical", [])[:10]:
        try:
            df = query_df(
                f'SELECT "{col}" AS label, COUNT(*) AS value '
                f'FROM "{table_name}" '
                f'WHERE "{col}" IS NOT NULL '
                f'GROUP BY "{col}" ORDER BY value DESC LIMIT 10'
            )
            if not df.empty:
                bar_charts.append({
                    "column": col,
                    "data": df.to_dict(orient="records"),
                })
        except Exception:
            continue

    # Stats for numeric columns
    numeric_stats = []
    for col in classes.get("numeric", [])[:8]:
        try:
            df = query_df(
                f'SELECT '
                f'MIN("{col}") AS min, '
                f'MAX("{col}") AS max, '
                f'ROUND(AVG("{col}"), 2) AS avg, '
                f'ROUND(MEDIAN("{col}"), 2) AS median, '
                f'COUNT("{col}") AS count '
                f'FROM "{table_name}"'
            )
            if not df.empty:
                row = df.iloc[0]
                numeric_stats.append({
                    "column": col,
                    "min": float(row["min"]) if row["min"] is not None else None,
                    "max": float(row["max"]) if row["max"] is not None else None,
                    "avg": float(row["avg"]) if row["avg"] is not None else None,
                    "median": float(row["median"]) if row["median"] is not None else None,
                    "count": int(row["count"]),
                })
        except Exception:
            continue

    # Temporal columns — group by date/month if available
    time_charts = []
    for col in classes.get("temporal", [])[:3]:
        try:
            df = query_df(
                f'SELECT CAST("{col}" AS DATE) AS label, COUNT(*) AS value '
                f'FROM "{table_name}" '
                f'WHERE "{col}" IS NOT NULL '
                f'GROUP BY CAST("{col}" AS DATE) ORDER BY label LIMIT 50'
            )
            if not df.empty:
                # Convert dates to string for JSON
                df["label"] = df["label"].astype(str)
                time_charts.append({
                    "column": col,
                    "data": df.to_dict(orient="records"),
                })
        except Exception:
            continue

    return {
        "table": table_name,
        "row_count": total,
        "bar_charts": bar_charts,
        "numeric_stats": numeric_stats,
        "time_charts": time_charts,
    }


@app.get("/api/relationships")
def relationships_endpoint() -> dict:
    """Detect relationships between all loaded tables by matching column names."""
    from src.tools.profiling import column_types

    names = list_tables()
    if len(names) < 2:
        return {"tables": names, "relationships": []}

    # Build a map of table -> list of column names
    table_columns: dict[str, list[str]] = {}
    for name in names:
        try:
            types = column_types(name)
            table_columns[name] = list(types.keys())
        except Exception:
            continue

    # Detect relationships: matching column names between different tables
    relationships = []
    seen = set()
    table_list = list(table_columns.keys())

    for i, t1 in enumerate(table_list):
        for t2 in table_list[i + 1:]:
            cols1 = set(c.lower() for c in table_columns[t1])
            cols2 = set(c.lower() for c in table_columns[t2])
            shared = cols1 & cols2

            # Filter out very generic columns that are unlikely to be real keys
            generic = {"id", "name", "type", "status", "date", "created_at", "updated_at", "description", "notes"}
            meaningful_shared = shared - generic

            for col_lower in meaningful_shared:
                # Find the original casing in each table
                orig1 = next((c for c in table_columns[t1] if c.lower() == col_lower), col_lower)
                orig2 = next((c for c in table_columns[t2] if c.lower() == col_lower), col_lower)

                key = tuple(sorted([f"{t1}.{orig1}", f"{t2}.{orig2}"]))
                if key not in seen:
                    seen.add(key)
                    relationships.append({
                        "from_table": t1,
                        "from_column": orig1,
                        "to_table": t2,
                        "to_column": orig2,
                        "match_type": "column_name",
                    })

            # Also check for {other_table}_id patterns
            for col in table_columns[t1]:
                col_l = col.lower().replace(" ", "_")
                for other in table_list:
                    if other == t1:
                        continue
                    if col_l == f"{other.lower()}_id" or col_l == f"{other.lower()}id":
                        key2 = tuple(sorted([f"{t1}.{col}", f"{other}.id"]))
                        if key2 not in seen:
                            seen.add(key2)
                            relationships.append({
                                "from_table": t1,
                                "from_column": col,
                                "to_table": other,
                                "to_column": "id (inferred)",
                                "match_type": "foreign_key_pattern",
                            })

    # Build table info for the diagram
    table_info = []
    for name in table_columns:
        table_info.append({
            "name": name,
            "columns": table_columns[name][:15],  # Limit columns for display
            "total_columns": len(table_columns[name]),
        })

    return {
        "tables": table_info,
        "relationships": relationships,
    }


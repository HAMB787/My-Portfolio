"""Shared DuckDB connection and query helpers for data tools."""

from __future__ import annotations

import duckdb
import pandas as pd

from config.settings import DUCKDB_PATH, PROCESSED_DIR


def get_connection() -> duckdb.DuckDBPyConnection:
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    return duckdb.connect(str(DUCKDB_PATH))


def query_df(sql: str) -> pd.DataFrame:
    """Run a query and return a pandas DataFrame. Used by the dashboard UI."""
    con = get_connection()
    try:
        return con.sql(sql).df()
    finally:
        con.close()


def list_tables() -> list[str]:
    con = get_connection()
    try:
        rows = con.execute("SHOW TABLES").fetchall()
        return [r[0] for r in rows]
    except Exception:
        return []
    finally:
        con.close()


def table_schema(table: str) -> pd.DataFrame:
    con = get_connection()
    try:
        return con.execute(f"DESCRIBE {table}").df()
    finally:
        con.close()

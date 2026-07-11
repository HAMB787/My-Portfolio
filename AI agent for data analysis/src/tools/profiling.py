"""Auto data profiling + chart suggestions for the dashboard."""

from __future__ import annotations

import pandas as pd

from src.tools.db import query_df, table_schema

_NUMERIC = {"BIGINT", "INTEGER", "DOUBLE", "FLOAT", "DECIMAL", "HUGEINT", "TINYINT", "SMALLINT"}
_TEMPORAL = {"DATE", "TIMESTAMP", "TIME", "TIMESTAMP_NS"}


def column_types(table: str) -> dict[str, str]:
    schema = table_schema(table)
    return dict(zip(schema["column_name"], schema["column_type"]))


def classify_columns(table: str) -> dict[str, list[str]]:
    types = column_types(table)
    numeric, categorical, temporal = [], [], []
    for col, t in types.items():
        base = t.upper().split("(")[0]
        if base in _NUMERIC:
            numeric.append(col)
        elif base in _TEMPORAL or "DATE" in base or "TIMESTAMP" in base:
            temporal.append(col)
        else:
            categorical.append(col)
    return {"numeric": numeric, "categorical": categorical, "temporal": temporal}


def profile_table(table: str) -> pd.DataFrame:
    """Per-column profile: type, nulls, null %, distinct values."""
    schema = table_schema(table)
    total = int(query_df(f'SELECT COUNT(*) AS n FROM "{table}"')["n"].iloc[0])
    rows = []
    for _, r in schema.iterrows():
        col = r["column_name"]
        nulls = int(
            query_df(f'SELECT COUNT(*) AS n FROM "{table}" WHERE "{col}" IS NULL')["n"].iloc[0]
        )
        distinct = int(
            query_df(f'SELECT COUNT(DISTINCT "{col}") AS n FROM "{table}"')["n"].iloc[0]
        )
        rows.append(
            {
                "column": col,
                "type": r["column_type"],
                "nulls": nulls,
                "null_%": round(100 * nulls / total, 1) if total else 0.0,
                "distinct": distinct,
            }
        )
    return pd.DataFrame(rows)


def row_count(table: str) -> int:
    return int(query_df(f'SELECT COUNT(*) AS n FROM "{table}"')["n"].iloc[0])

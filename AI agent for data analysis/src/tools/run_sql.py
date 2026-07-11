"""Run read-only SQL against the local DuckDB warehouse."""

from __future__ import annotations

from typing import Any

from config.settings import MAX_SQL_ROWS
from src.tools.base import Tool
from src.tools.db import get_connection


class RunSqlTool(Tool):
    name = "run_sql"
    description = (
        "Run a read-only SQL query (SELECT/WITH/EXPLAIN/DESCRIBE/SHOW) "
        "on the local DuckDB database. Returns up to 100 rows."
    )

    def parameters_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "SQL query to execute",
                }
            },
            "required": ["query"],
        }

    def is_read_only(self) -> bool:
        return True

    def run(self, arguments: dict[str, Any]) -> str:
        query = str(arguments.get("query", "")).strip()
        if not query:
            return "Error: empty query"

        con = get_connection()
        try:
            relation = con.sql(query)
            df = relation.limit(MAX_SQL_ROWS).df()
            row_count = len(df)
            preview = df.to_string(index=False)
            return f"Rows returned: {row_count}\n\n{preview}"
        except Exception as e:
            return f"SQL error: {e}"
        finally:
            con.close()

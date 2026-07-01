"""Profile a DuckDB table — column types, nulls, sample values."""

from __future__ import annotations

from typing import Any

from src.tools.base import Tool
from src.tools.db import get_connection


class DescribeDataTool(Tool):
    name = "describe_data"
    description = "Profile a table: columns, types, null counts, and 3 sample rows."

    def parameters_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "table_name": {
                    "type": "string",
                    "description": "DuckDB table to profile",
                }
            },
            "required": ["table_name"],
        }

    def is_read_only(self) -> bool:
        return True

    def run(self, arguments: dict[str, Any]) -> str:
        table = str(arguments.get("table_name", "")).strip()
        if not table:
            return "Error: table_name is required"

        con = get_connection()
        try:
            schema = con.execute(f"DESCRIBE {table}").df()
            sample = con.execute(f"SELECT * FROM {table} LIMIT 3").df()
            total = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

            null_lines: list[str] = []
            for col in schema["column_name"]:
                n = con.execute(
                    f'SELECT COUNT(*) FROM {table} WHERE "{col}" IS NULL'
                ).fetchone()[0]
                null_lines.append(f"  {col}: {n} nulls")

            parts = [
                f"Table: {table} ({total} rows)",
                "Schema:",
                schema.to_string(index=False),
                "",
                "Null counts:",
                *null_lines,
                "",
                "Sample (3 rows):",
                sample.to_string(index=False),
            ]
            return "\n".join(parts)
        except Exception as e:
            return f"Describe error: {e}"
        finally:
            con.close()

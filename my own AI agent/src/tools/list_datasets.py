"""List tables in DuckDB and files in data/raw/."""

from __future__ import annotations

from typing import Any

from config.settings import RAW_DIR
from src.tools.base import Tool
from src.tools.db import get_connection


class ListDatasetsTool(Tool):
    name = "list_datasets"
    description = "List DuckDB tables and available files in data/raw/."

    def parameters_schema(self) -> dict[str, Any]:
        return {"type": "object", "properties": {}, "required": []}

    def is_read_only(self) -> bool:
        return True

    def run(self, arguments: dict[str, Any]) -> str:
        _ = arguments
        lines = ["## Files in data/raw/"]
        RAW_DIR.mkdir(parents=True, exist_ok=True)
        files = sorted(RAW_DIR.glob("*"))
        if files:
            lines.extend(f"  - {f.name}" for f in files if f.is_file())
        else:
            lines.append("  (empty — add CSV files here)")

        con = get_connection()
        try:
            tables = con.execute("SHOW TABLES").df()
            lines.append("")
            lines.append("## DuckDB tables")
            if len(tables):
                lines.append(tables.to_string(index=False))
            else:
                lines.append("  (none — use load_dataset first)")
        except Exception as e:
            lines.append(f"  Error listing tables: {e}")
        finally:
            con.close()

        return "\n".join(lines)

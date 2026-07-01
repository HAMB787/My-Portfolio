"""Load CSV/JSON/Parquet/SQLite/Excel from data/raw into DuckDB as a table."""

from __future__ import annotations

from typing import Any

from config.settings import RAW_DIR
from src.tools.base import Tool
from src.tools.db import get_connection

SUPPORTED = {".csv", ".json", ".ndjson", ".parquet", ".tsv", ".xlsx", ".xls", ".db", ".sqlite", ".sqlite3"}


def load_sqlite_tables(path: str) -> str:
    """Import all tables from a SQLite database into DuckDB."""
    con = get_connection()
    try:
        con.execute("INSTALL sqlite; LOAD sqlite;")
    except Exception:
        pass  # Already installed/loaded

    try:
        # Attach and import all tables
        con.execute(f"CALL sqlite_attach('{path}')")
        tables = con.execute("SHOW TABLES").fetchall()
        table_names = [r[0] for r in tables]

        if not table_names:
            return "No tables found in the SQLite database."

        imported = []
        for tbl in table_names:
            try:
                count = con.execute(f'SELECT COUNT(*) FROM "{tbl}"').fetchone()[0]
                imported.append(f"'{tbl}' ({count} rows)")
            except Exception as e:
                imported.append(f"'{tbl}' (error: {e})")

        return f"Imported {len(imported)} tables from SQLite: {', '.join(imported)}"
    except Exception as e:
        return f"Load error: {e}"
    finally:
        con.close()


def load_file_into_table(filename: str, table_name: str) -> str:
    """Core loader reused by the agent tool and the UI uploader."""
    filename = filename.strip()
    table_name = table_name.strip()
    if not filename or not table_name:
        return "Error: file and table_name are required"

    path = (RAW_DIR / filename).resolve()
    if not path.is_relative_to(RAW_DIR.resolve()):
        return "Error: file must be inside data/raw/"
    if not path.exists():
        return f"Error: file not found: data/raw/{filename}"

    suffix = path.suffix.lower()
    if suffix not in SUPPORTED:
        return f"Error: supported formats are {', '.join(sorted(SUPPORTED))}"

    # SQLite databases: import all tables at once
    if suffix in (".db", ".sqlite", ".sqlite3"):
        return load_sqlite_tables(str(path))

    con = get_connection()
    try:
        if suffix == ".csv":
            reader = "read_csv_auto(?, sample_size=-1)"
        elif suffix == ".tsv":
            reader = "read_csv_auto(?, sample_size=-1, delim='\\t')"
        elif suffix in (".json", ".ndjson"):
            reader = "read_json_auto(?)"
        elif suffix in (".xlsx", ".xls"):
            # Use pandas to read Excel, then insert into DuckDB
            import pandas as pd
            df = pd.read_excel(str(path))
            con.execute(f'CREATE OR REPLACE TABLE "{table_name}" AS SELECT * FROM df')
            count = con.execute(f'SELECT COUNT(*) FROM "{table_name}"').fetchone()[0]
            cols = con.execute(f'DESCRIBE "{table_name}"').df()
            col_list = ", ".join(cols["column_name"].tolist())
            return f"Loaded {count} rows into '{table_name}'. Columns: {col_list}"
        else:
            reader = "read_parquet(?)"

        con.execute(
            f'CREATE OR REPLACE TABLE "{table_name}" AS SELECT * FROM {reader}',
            [str(path)],
        )
        count = con.execute(f'SELECT COUNT(*) FROM "{table_name}"').fetchone()[0]
        cols = con.execute(f'DESCRIBE "{table_name}"').df()
        col_list = ", ".join(cols["column_name"].tolist())
        return f"Loaded {count} rows into '{table_name}'. Columns: {col_list}"
    except Exception as e:
        return f"Load error: {e}"
    finally:
        con.close()


class LoadDatasetTool(Tool):
    name = "load_dataset"
    description = (
        "Load a CSV, JSON, Parquet, Excel, TSV, or SQLite file from data/raw/ into DuckDB as a named "
        "table. Example: file='sales.csv', table_name='sales'"
    )

    def parameters_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "file": {
                    "type": "string",
                    "description": "Filename inside data/raw/ (e.g. sales.csv, events.json, app.db)",
                },
                "table_name": {
                    "type": "string",
                    "description": "DuckDB table name to create",
                },
            },
            "required": ["file", "table_name"],
        }

    def is_destructive(self) -> bool:
        return True

    def run(self, arguments: dict[str, Any]) -> str:
        return load_file_into_table(
            str(arguments.get("file", "")),
            str(arguments.get("table_name", "")),
        )

# Data Agent Memory

- Domain: data analytics, data engineering, data science
- Warehouse: local DuckDB at data/processed/analytics.duckdb
- Raw files: drop CSV/Parquet in data/raw/
- SQL policy: read-only SELECT for the agent; writes only via load_dataset

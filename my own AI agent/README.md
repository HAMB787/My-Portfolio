# Data Agent — Local AI for Analytics & Data Engineering

A **thesis-grade AI agent** for data analysis, data engineering, and data science — **no cloud API keys**.

## What "your own AI" means here

| Layer | What it is | Yours? |
|-------|------------|--------|
| **Brain** | Open-source LLM (Llama, Qwen, Mistral) via **Ollama** on your PC | Local, free, no API |
| **Agent logic** | Python loop: think → use tools → observe | **Your thesis code** |
| **Data tools** | SQL, profiling, file load, pipelines | **Your thesis code** |
| **Memory & safety** | MEMORY.md, SQL permission gate | **Your thesis code** |

You are **not** training GPT from scratch (needs supercomputers). You **are** building a **specialized data agent** on top of an open model — that is a valid and strong thesis.

## Architecture

```text
User question
    │
    ▼
main.py (CLI)
    │
    ▼
query_loop.py ──────────────────────────────┐
    │                                         │
    ├── context.py (data analyst prompt)      │
    ├── memory/store.py                       │
    │                                         │
    ├── llm.py ──► Ollama (localhost)         │  YOUR machine
    │              qwen2.5 / llama3.1         │
    │                                         │
    └── tools/ ◄── permissions/gate.py        │
         ├── load_dataset   (CSV → DuckDB)    │
         ├── run_sql        (SELECT only)     │
         ├── describe_data  (profile table)   │
         └── list_datasets  (what is loaded)  │
                                              │
         data/raw/          raw files         │
         data/processed/    DuckDB database   │
```

## Folder structure

```text
my own AI agent/
├── config/settings.py       # Ollama model, paths, limits
├── src/
│   ├── main.py              # chat CLI
│   ├── engine/
│   │   ├── llm.py           # local Ollama client
│   │   ├── query_loop.py    # agent brain
│   │   └── context.py       # data analyst system prompt
│   ├── tools/
│   │   ├── base.py
│   │   ├── registry.py
│   │   ├── load_dataset.py  # ingest CSV/Parquet
│   │   ├── run_sql.py       # DuckDB queries
│   │   ├── describe_data.py # column stats
│   │   └── list_datasets.py
│   ├── permissions/gate.py  # block DELETE/DROP etc.
│   └── memory/store.py
├── data/
│   ├── raw/                 # drop CSV files here
│   ├── processed/           # analytics.duckdb
│   └── memory/MEMORY.md
├── pipelines/               # (Phase 3) reusable ETL scripts
├── notebooks/               # (Phase 4) thesis experiments
└── tests/
```

## Build phases

| Phase | Goal |
|-------|------|
| **1** | Install Ollama + wire local LLM + `run_sql` on DuckDB |
| **2** | Load CSV, describe tables, permission gate for SQL |
| **3** | ClickHouse / BigQuery connectors, ETL helpers |
| **4** | Evaluation: 20 analytics questions, accuracy & latency |

## Setup

```powershell
# 1. Install Ollama: https://ollama.com/download
ollama pull qwen2.5:7b

# 2. Python deps
pip install -r requirements.txt
copy .env.example .env

# 3. Run agent
python -m src.main
```

## Example questions (Phase 2+)

- "Load `data/raw/sales.csv` and show top 5 products by revenue"
- "How many nulls are in the `customer_id` column?"
- "Write SQL to compute monthly active users"

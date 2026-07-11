"""App configuration — local LLM + data paths."""

from pathlib import Path
import os

from dotenv import load_dotenv

load_dotenv()

ROOT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
DUCKDB_PATH = PROCESSED_DIR / "analytics.duckdb"
MEMORY_FILE = DATA_DIR / "memory" / "MEMORY.md"

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:7b")
MAX_TOOL_ROUNDS = int(os.getenv("MAX_TOOL_ROUNDS", "12"))

# SQL safety: max rows returned to the LLM
MAX_SQL_ROWS = int(os.getenv("MAX_SQL_ROWS", "100"))

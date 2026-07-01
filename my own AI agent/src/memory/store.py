"""Persistent memory file (inspired by memdir/MEMORY.md)."""

from config.settings import MEMORY_FILE


def load_memory() -> str:
    if MEMORY_FILE.exists():
        return MEMORY_FILE.read_text(encoding="utf-8")
    return ""


def save_memory(content: str) -> None:
    MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    MEMORY_FILE.write_text(content, encoding="utf-8")

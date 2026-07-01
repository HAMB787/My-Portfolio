"""Business context store — lets the agent understand the user's domain."""

from __future__ import annotations

from config.settings import DATA_DIR

BUSINESS_FILE = DATA_DIR / "memory" / "business_context.md"


def load_business_context() -> str:
    if BUSINESS_FILE.exists():
        return BUSINESS_FILE.read_text(encoding="utf-8")
    return ""


def save_business_context(text: str) -> None:
    BUSINESS_FILE.parent.mkdir(parents=True, exist_ok=True)
    BUSINESS_FILE.write_text(text, encoding="utf-8")

"""Rules for jobs accessible from Armenia.

Exclude (Spain market):
  - Hybrid or On-site on the LinkedIn job page
  - Full-time / Jornada completa when the page does NOT show Remote

Note: CSV `Work_Type` is always "Remote" for Spain searches — use
`python src/verify_spain_remote_jobs.py` to check live LinkedIn pages.
"""

from __future__ import annotations


def _norm(value: object) -> str:
    return (value or "").strip() if isinstance(value, str) else str(value or "").strip()


def exclusion_reason(
    *,
    market: str,
    work_type: str,
    title: str = "",
    location: str = "",
) -> str | None:
    """Return rejection reason, or None to keep the row."""
    wt = _norm(work_type).lower()
    mkt = _norm(market)

    if mkt == "Spain" and "hybrid" in wt:
        return "Spain Hybrid (not applicable from Armenia)"

    return None


def should_exclude_row(row: dict[str, str], *, market_col: str = "market") -> tuple[bool, str]:
    """Check a CSV row dict; column names differ between fct and dashboard exports."""
    work_type_col = "work_type" if "work_type" in row else "Work_Type"
    title_col = "title" if "title" in row else "Title"
    location_col = "location_text" if "location_text" in row else "Location"

    reason = exclusion_reason(
        market=row.get(market_col, ""),
        work_type=row.get(work_type_col, ""),
        title=row.get(title_col, ""),
        location=row.get(location_col, ""),
    )
    return (reason is not None, reason or "")

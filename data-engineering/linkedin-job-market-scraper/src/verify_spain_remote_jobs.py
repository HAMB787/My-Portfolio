"""Verify Spain jobs on LinkedIn detail pages and remove non-Remote rows.

The scraper labels all Spain search results as Work_Type=Remote, but LinkedIn
often shows Hybrid / On-site / Full-time without Remote on the job page.

Rule (Spain market only):
  Remove if the detail page does NOT confirm Remote (badge or keyword in header).
  Remove if Hybrid or On-site appears in the job header.

Usage (project root):
    python src/verify_spain_remote_jobs.py --dry-run
    python src/verify_spain_remote_jobs.py --apply
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import logging
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from playwright.async_api import Browser, Page, async_playwright

ROOT = Path(__file__).resolve().parent.parent
FCT_CSV = ROOT / "data1" / "fct_job_listing.csv"
COMBINED_CSV = ROOT / "linkedin_dashboard_jobs_combined.csv"
AUDIT_CSV = ROOT / "data" / "processed" / "spain_non_remote_removed.csv"
VERIFY_LOG = ROOT / "data" / "processed" / "spain_remote_verification.csv"

_TOP_MARKERS = (
    "Similar jobs",
    "Empleos similares",
    "People also viewed",
    "Sign in to create job alert",
    "Crear alerta",
    "Get notified about new",
    "Recibe una notificación cuando se publique",
)

_BADGE_RE = re.compile(
    r"^(Remote|Hybrid|On-site|Full-time|Remoto|En remoto|Híbrido|Hibrido|Presencial|"
    r"Jornada completa|Tiempo completo)$",
    re.IGNORECASE,
)
_WORD_REMOTE = re.compile(r"\bremote\b", re.IGNORECASE)
_WORD_HYBRID = re.compile(r"\bhybrid\b", re.IGNORECASE)
_WORD_ONSITE = re.compile(r"\bon-?site\b", re.IGNORECASE)
_WORD_FULLTIME = re.compile(
    r"\b(full-?time|jornada completa|tiempo completo)\b", re.IGNORECASE
)
_EMPLOYMENT_TYPE = re.compile(
    r"(?:Employment type|Tipo de empleo)\s*\n\s*(.+)",
    re.IGNORECASE,
)
_REMOTE_PHRASES = (
    _WORD_REMOTE,
    re.compile(r"\bfully remote\b", re.IGNORECASE),
    re.compile(r"\b100\s*%\s*remote\b", re.IGNORECASE),
    re.compile(r"\bwork from home\b", re.IGNORECASE),
    re.compile(r"\bteletrabajo\b", re.IGNORECASE),
)
_NOT_REMOTE = re.compile(r"\b(not|no)\s+remote\b", re.IGNORECASE)
_HYBRID_PATTERNS = (
    _WORD_HYBRID,
    re.compile(r"\bhíbrido\b", re.IGNORECASE),
    re.compile(r"\bhibrido\b", re.IGNORECASE),
    re.compile(r"\bhíbrida\b", re.IGNORECASE),
    re.compile(r"\bhibrida\b", re.IGNORECASE),
    re.compile(r"\bmodalidad híbrida\b", re.IGNORECASE),
)
_FULL_REMOTE_PATTERNS = (
    re.compile(r"\b100\s*%\s*(remote|remoto|teletrabajo)\b", re.IGNORECASE),
    re.compile(r"\bfully[\s-]remote\b", re.IGNORECASE),
    re.compile(r"\bfull[\s-]remote\b", re.IGNORECASE),
    re.compile(r"\bremote[\s-]first\b", re.IGNORECASE),
    re.compile(r"\bremote worldwide\b", re.IGNORECASE),
    re.compile(r"\bremote\s*[-/]\s*anywhere\b", re.IGNORECASE),
    re.compile(r"\bwork from anywhere\b", re.IGNORECASE),
    # "Open to (full|fully) remote" — common phrasing used by Qonto/SEARADAR
    re.compile(r"\bopen to\s+(?:full\s+|fully\s+)?remote\b", re.IGNORECASE),
    re.compile(r"\b(?:totalmente|completamente)\s+(?:remoto|en remoto)\b", re.IGNORECASE),
)

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("verify_spain_remote")


def _top_section(body: str) -> str:
    end = len(body)
    for marker in _TOP_MARKERS:
        idx = body.find(marker)
        if 0 < idx < end:
            end = idx
    return body[:end]


def _badge_lines(top: str) -> list[str]:
    return [ln.strip() for ln in top.splitlines() if _BADGE_RE.match(ln.strip())]


def _employment_type_line(top: str) -> str:
    m = _EMPLOYMENT_TYPE.search(top)
    return m.group(1).strip() if m else ""


def _is_full_time(badges: list[str], top: str) -> bool:
    if any(b.lower() in {"full-time", "jornada completa", "tiempo completo"} for b in badges):
        return True
    emp = _employment_type_line(top)
    if emp and _WORD_FULLTIME.search(emp):
        return True
    return _has_word(_WORD_FULLTIME, top)


def _city_or_office_location(location: str) -> bool:
    """True when location implies a physical office city, not country-wide remote."""
    loc = location.strip().lower()
    if not loc or loc in {"spain", "españa", "espana"}:
        return False
    if "metropolitan" in loc or ", spain" in loc or ", españa" in loc:
        return True
    return bool(
        re.search(
            r"\b(madrid|barcelona|málaga|malaga|valencia|seville|sevilla|bilbao)\b",
            loc,
            re.I,
        )
    )


def _has_word(pattern: re.Pattern[str], text: str) -> bool:
    if _NOT_REMOTE.search(text):
        return False
    return pattern.search(text) is not None


def _has_hybrid_signal(top: str, badges: list[str]) -> bool:
    if any(b.lower() in {"hybrid", "híbrido", "hibrido"} for b in badges):
        return True
    return any(pat.search(top) for pat in _HYBRID_PATTERNS)


def _has_onsite_signal(top: str, badges: list[str]) -> bool:
    if any(b.lower() in {"on-site", "onsite", "presencial"} for b in badges):
        return True
    if _has_word(_WORD_ONSITE, top[:1200]):
        return True
    return bool(re.search(r"\bpresencial\b", top, re.IGNORECASE))


def _has_explicit_remote(title: str, top: str, badges: list[str]) -> bool:
    """Strong remote signals that should override any later hybrid boilerplate.

    Includes: an explicit Remote/Remoto badge, the word "remote" in the title,
    or any phrase like "open to full remote", "fully remote", "100% remote",
    "work from anywhere", etc. in the job description's top section.
    """
    remote_badges = {"remote", "remoto", "en remoto"}
    if any(b.lower() in remote_badges for b in badges):
        return True
    if _has_word(_WORD_REMOTE, title):
        return True
    if any(pat.search(top) for pat in _FULL_REMOTE_PATTERNS):
        return True
    return False


def _has_remote_signal(title: str, top: str, badges: list[str]) -> bool:
    """Permissive remote check — explicit signals OR a plain "remote" mention
    near the top, unless the page is clearly hybrid.
    """
    if _has_explicit_remote(title, top, badges):
        return True
    # Partial office + teletrabajo (e.g. "Modalidad híbrida … teletrabajo") is not remote.
    if _has_hybrid_signal(top, badges):
        return False
    return _has_word(_WORD_REMOTE, top[:900])


def parse_work_arrangement(body: str, title: str) -> dict[str, Any]:
    top = _top_section(body)
    badges = _badge_lines(top)

    explicit_remote = _has_explicit_remote(title, top, badges)
    hybrid = _has_hybrid_signal(top, badges)
    onsite = _has_onsite_signal(top, badges)
    remote = explicit_remote or _has_remote_signal(title, top, badges)
    full_time = _is_full_time(badges, top)
    blocked = len(body.strip()) < 400

    return {
        "badges": "|".join(badges),
        "remote": remote,
        "explicit_remote": explicit_remote,
        "hybrid": hybrid,
        "onsite": onsite,
        "full_time": full_time,
        "blocked": blocked,
    }


def exclusion_reason_from_page(
    title: str,
    location: str,
    arrangement: dict[str, Any],
) -> str | None:
    if arrangement.get("blocked"):
        return None
    # Strongest signal wins — an explicit "remote" badge or "Open to full remote"
    # / "Fully remote" / "100% remote" phrase at the top overrides any later
    # hybrid/on-site boilerplate (e.g. Qonto, SEARADAR).
    if arrangement.get("explicit_remote"):
        return None
    if arrangement.get("hybrid"):
        return "Spain: Hybrid on LinkedIn (not Remote)"
    if arrangement.get("onsite"):
        return "Spain: On-site on LinkedIn (not Remote)"
    if arrangement.get("remote"):
        return None
    # Country-wide listings (from remote search) — keep unless Hybrid/On-site above.
    if not _city_or_office_location(location) and (location or "").strip().lower() in {
        "spain",
        "españa",
        "espana",
    }:
        return None
    if arrangement.get("full_time"):
        return "Spain: Full-time on LinkedIn, no Remote"
    return None


async def _fetch_page_text(page: Page, url: str) -> str:
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=25_000)
        await page.wait_for_timeout(2_500)
        text = await page.inner_text("body")
        return text or ""
    except Exception as exc:
        log.warning("  fetch failed: %s", exc)
        return ""


def _load_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _write_csv(
    path: Path,
    rows: list[dict[str, str]],
    *,
    quote_nonnumeric: bool,
) -> None:
    if not rows:
        log.warning("No rows to write for %s", path.name)
        return
    quoting = csv.QUOTE_NONNUMERIC if quote_nonnumeric else csv.QUOTE_MINIMAL
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys(), quoting=quoting)
        w.writeheader()
        w.writerows(rows)


async def verify_spain_jobs(
    *,
    limit: int | None,
    apply: bool,
) -> int:
    fct_rows = _load_csv(FCT_CSV)
    combined_rows = _load_csv(COMBINED_CSV)
    if not fct_rows:
        log.error("No rows in %s", FCT_CSV)
        return 1

    spain_rows = [r for r in fct_rows if (r.get("market") or "").strip() == "Spain"]
    if limit:
        spain_rows = spain_rows[:limit]

    log.info("Verifying %d Spain job(s) on LinkedIn detail pages…", len(spain_rows))

    verification_rows: list[dict[str, str]] = []
    remove_urls: set[str] = set()
    remove_reasons: dict[str, str] = {}

    async with async_playwright() as p:
        browser: Browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        for i, row in enumerate(spain_rows, 1):
            url = (row.get("job_url") or "").strip()
            title = row.get("title") or ""
            if not url:
                continue

            body = await _fetch_page_text(page, url)
            arr = parse_work_arrangement(body, title)
            reason = exclusion_reason_from_page(title, row.get("location_text") or "", arr)

            log.info(
                "[%d/%d] %s | remote=%s hybrid=%s | %s",
                i,
                len(spain_rows),
                (row.get("company_name") or "")[:28],
                arr["remote"],
                arr["hybrid"],
                "REMOVE" if reason else "keep",
            )

            verification_rows.append(
                {
                    "linkedin_job_id": str(row.get("linkedin_job_id") or ""),
                    "company_name": row.get("company_name") or "",
                    "title": title,
                    "location_text": row.get("location_text") or "",
                    "csv_work_type": row.get("work_type") or "",
                    "page_badges": arr["badges"],
                    "page_remote": str(arr["remote"]),
                    "page_hybrid": str(arr["hybrid"]),
                    "page_onsite": str(arr["onsite"]),
                    "page_full_time": str(arr["full_time"]),
                    "action": "remove" if reason else "keep",
                    "reason": reason or "",
                    "job_url": url,
                }
            )

            if reason:
                remove_urls.add(url)
                remove_reasons[url] = reason

        await browser.close()

    VERIFY_LOG.parent.mkdir(parents=True, exist_ok=True)
    _write_csv(VERIFY_LOG, verification_rows, quote_nonnumeric=True)
    log.info("Verification log: %s", VERIFY_LOG)
    log.info("Would remove %d / %d Spain jobs", len(remove_urls), len(spain_rows))

    if not apply:
        log.info("Dry-run — no CSV changes. Re-run with --apply to delete.")
        return 0

    if not remove_urls:
        log.info("Nothing to remove.")
        return 0

    fct_kept = [r for r in fct_rows if (r.get("job_url") or "").strip() not in remove_urls]
    comb_kept = [
        r for r in combined_rows if (r.get("Job_URL") or "").strip() not in remove_urls
    ]

    log.info("fct_job_listing:    %d -> %d", len(fct_rows), len(fct_kept))
    log.info("dashboard combined: %d -> %d", len(combined_rows), len(comb_kept))

    _write_csv(FCT_CSV, fct_kept, quote_nonnumeric=True)
    if combined_rows:
        _write_csv(COMBINED_CSV, comb_kept, quote_nonnumeric=False)

    removed_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    audit_fields = [
        "removed_at",
        "exclusion_reason",
        "linkedin_job_id",
        "market",
        "work_type",
        "company_name",
        "title",
        "location_text",
        "page_badges",
        "job_url",
    ]
    need_header = not AUDIT_CSV.exists() or AUDIT_CSV.stat().st_size == 0
    with AUDIT_CSV.open("a", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=audit_fields, quoting=csv.QUOTE_NONNUMERIC)
        if need_header:
            w.writeheader()
        for v in verification_rows:
            if v["action"] != "remove":
                continue
            w.writerow(
                {
                    "removed_at": removed_at,
                    "exclusion_reason": v["reason"],
                    "linkedin_job_id": v["linkedin_job_id"],
                    "market": "Spain",
                    "work_type": v["csv_work_type"],
                    "company_name": v["company_name"],
                    "title": v["title"],
                    "location_text": v["location_text"],
                    "page_badges": v["page_badges"],
                    "job_url": v["job_url"],
                }
            )

    log.info("Removal audit: %s", AUDIT_CSV)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify Spain jobs are Remote on LinkedIn.")
    ap.add_argument("--dry-run", action="store_true", help="Verify only; default mode.")
    ap.add_argument("--apply", action="store_true", help="Remove non-Remote Spain jobs from CSVs.")
    ap.add_argument("--limit", type=int, default=None, help="Process first N Spain rows only.")
    args = ap.parse_args()

    if args.apply and args.dry_run:
        log.error("Use either --dry-run or --apply, not both.")
        return 1

    apply = args.apply
    return asyncio.run(verify_spain_jobs(limit=args.limit, apply=apply))


if __name__ == "__main__":
    raise SystemExit(main())

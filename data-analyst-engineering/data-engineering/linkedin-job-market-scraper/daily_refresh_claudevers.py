"""
LinkedIn Jobs — Daily Refresh Script  (target: ~10 minutes)
==========================================================================
Purpose:
    Lightweight companion to linkedin_scraper_v4_final.py.
    Runs daily, fetching jobs posted in the last 7 DAYS (was 24h) and
    appending NEW ones to linkedin_dashboard_jobs_combined.csv.
    Dedup on Job_URL ensures already-known jobs are not rewritten.
    Runs headless (no browser window) — schedule via Windows Task Scheduler.

Timing math (with 7-day window):
    Spain   : 5 kw × 3 exp × 1 work_type (Remote)                = 15 queries
    Armenia : 5 kw × 3 exp × 3 work_types (Remote/On-site/Hybrid)= 45 queries
    Total                                                         = 60 queries
    60 queries × 3 pages max                                      = 180 page loads
    Per page: 1.5s load-wait + 1.0s scroll + 1.5s between-page    = 4.1s
    Per query: 2.5s between-query gap
    Most Armenia pages still return 0 cards → break early.
    Realistic: ~120–150 actual page loads, ~10–13 min total.
    Network variance + occasional retries → close to 15 min worst case.

How to schedule on Windows (Task Scheduler):
    Action:  Start a Program
    Program: C:\\Users\\...\\AppData\\Local\\Microsoft\\WindowsApps\\python3.13.exe
    Args:    "C:\\Users\\...\\Desktop\\Linkedin Scraper\\linkedin_daily_refresh.py"
    Trigger: Daily at 09:00 AM

Key differences from full scraper:
    • f_TPR=r604800     → 7-day window (vs 60 days). Tune via
                          TIME_WINDOW_SECONDS constant below.
    • MAX_PAGES = 3     → 7-day window often fills page 3
    • 5 keywords only   → most distinct, no redundant overlap
    • headless=True     → runs silently in background
    • Delays halved     → 1.5s between pages, 2.5s between queries
    • Warmup once only  → only on first init, not on every context rotation
    • Timeout = 30s     → faster failure detection (vs 45s)
    • Rotate every 12q  → ~5 rotations per run
"""

from __future__ import annotations

import asyncio
import csv
import logging
import os
import random
import re
import signal
import sys
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from playwright.async_api import BrowserContext, Page, async_playwright
from playwright_stealth import Stealth

# Reuse the same Spain Remote / Hybrid detector used by
# `src/verify_spain_remote_jobs.py` so the scraper rejects Hybrid /
# Spain-only Hybrid postings at scrape time (no need for a post-clean pass).
_SCRIPT_DIR_FOR_IMPORT = Path(__file__).resolve().parent
if str(_SCRIPT_DIR_FOR_IMPORT / "src") not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR_FOR_IMPORT / "src"))
from verify_spain_remote_jobs import (  # type: ignore[import-not-found]  # noqa: E402
    exclusion_reason_from_page,
    parse_work_arrangement,
)

# ---------------------------------------------------------------------------
# Logging — writes to both console AND a daily refresh log file
# ---------------------------------------------------------------------------

_SCRIPT_DIR  = Path(__file__).resolve().parent
_LOG_PATH    = _SCRIPT_DIR / "refresh_log.txt"
_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(),                        # console
        logging.FileHandler(_LOG_PATH, encoding="utf-8"),  # persistent log file
    ],
)
log = logging.getLogger("linkedin_refresh")

# ---------------------------------------------------------------------------
# Shared paths — SAME files the full scraper writes to
# ---------------------------------------------------------------------------

CSV_PATH    = _SCRIPT_DIR / "linkedin_dashboard_jobs_combined.csv"  # daily refresh target
REJECT_PATH = _SCRIPT_DIR / "rejected_jobs_log.csv"

# ---------------------------------------------------------------------------
# Regex Filtering — identical to full scraper
# ---------------------------------------------------------------------------

TARGET_ROOTS = [
    r"data analyst",
    r"data engineer",
    r"analytics engineer",
    r"data analytics",
    r"bi engineer",
    r"bi analyst",
    r"bi developer",
    r"bi data engineer",
    r"business intelligence",
    r"power bi",
    r"looker",
    r"dbt",
    r"sql analyst",
    r"data architect",
]

BLACKLIST_TERMS = [
    r"marketing",
    r"finance",
    r"financial",
    r"sales",
    r"hr",
    r"human[\s\-]resources",
    r"recruiter",
    r"entry[\s\-]level",
    r"intern(?:ship)?",
    r"junior",
    r"apprentice",
    r"us[\s\-]only",
    r"uk[\s\-]only",
    r"clearance[\s\-]required",
    r"us[\s\-]citizen",
    r"work[\s\-]from[\s\-]home[\s\-]not[\s\-]available",
]

POSITIVE_PATTERN = re.compile(rf"\b({'|'.join(TARGET_ROOTS)})\b", re.IGNORECASE)
NEGATIVE_PATTERN = re.compile(rf"\b({'|'.join(BLACKLIST_TERMS)})\b", re.IGNORECASE)

_NEGATIVE_PHRASES = [
    "us only", "u.s. only", "uk only", "u.k. only",
    "must be resident", "must reside in", "must be located in",
    "united states only", "authorized to work in the u",
    "us citizens only", "us-based only",
    "must be authorized to work in", "work permit required",
    "direct hire only", "resident of the us",
    "canada only", "australia only", "germany only",
    "based in the us", "based in the uk", "based in the united states",
    "u.s. based", "us-based", "uk-based", "eu work permit",
    "right to work in the u", "eligible to work in the u",
    "colombia", "quindío", "quindio",
]

_ALLOWED_LOCATION_SIGNALS = [
    "armenia", "yerevan", "gyumri",
    "spain", "madrid", "barcelona", "valencia", "seville", "bilbao",
    "worldwide", "remote", "anywhere", "global",
    "emea", "europe", "work from anywhere", "remote worldwide",
]

# ---------------------------------------------------------------------------
# STRICT 100% REMOTE FILTER  (Spain market is KEPT — only non-remote dropped)
# ---------------------------------------------------------------------------
# A two-step guard runs on every accepted card's detail page:
#   1) Metadata / workplace badge — reject Hybrid / On-site / Presencial / Híbrido.
#   2) Description text scan — reject "fake remote" postings that are tagged
#      Remote but mention office visits, local-residency rules, or hidden-hybrid
#      phrasing (English + Spanish).
#
# We do NOT exclude jobs for being Spanish or in Spain — only for not being
# genuinely 100% remote. A STRONG full-remote signal ("100% remote", "fully
# remote", "teletrabajo", a Remote badge, "remote" in the title, "work from
# anywhere") OVERRIDES the soft red flags so real remote roles are kept. The
# HARD traps below are unambiguous hybrid/relocation phrases and reject even
# when that override is present. Edit these lists freely — no other changes
# are needed.
# ---------------------------------------------------------------------------

# Workplace badges that mean NOT 100% remote (metadata-level hard reject).
_HYBRID_BADGE_WORDS = ("hybrid", "híbrido", "hibrido", "híbrida", "hibrida")
_ONSITE_BADGE_WORDS = ("on-site", "on site", "onsite", "presencial")

# HARD red flags — unambiguous hybrid / relocation traps. Reject even when a
# strong full-remote phrase is also present (these structured phrases win).
_FAKE_REMOTE_HARD: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"work from anywhere for up to", re.I),
     "Fake-remote: 'work from anywhere for up to' (local contract trap)"),
    (re.compile(r"teletrabajo flexible", re.I),
     "Fake-remote: 'teletrabajo flexible' (implies hybrid)"),
    (re.compile(r"(?:modelo|modalidad|formato|esquema)\s+h[ií]brid[oa]", re.I),
     "Fake-remote: 'modelo/modalidad híbrido'"),
    (re.compile(r"hybrid[\s\-]+(?:model|work(?:ing)?|setup|schedule|role|position|remote|approach)", re.I),
     "Fake-remote: 'hybrid model'"),
    (re.compile(r"\b\d+\s+days?\b[^.\n]{0,25}\b(?:in|at|from|to)\s+(?:the\s+)?office", re.I),
     "Fake-remote: 'N days in the office'"),
    (re.compile(r"\bin[\s\-]?office\b[^.\n]{0,15}\b\d+\s+days?", re.I),
     "Fake-remote: 'N days in the office'"),
    (re.compile(r"\d+\s+d[ií]as?\b[^.\n]{0,25}\b(?:en|a)\s+(?:la\s+)?oficina", re.I),
     "Fake-remote: 'X días en la oficina'"),
]

# OFFICE-commitment red flags — a 100% remote role would NOT require these, so
# they reject even when "100% remote" / "fully remote" is also written (NO
# override). A negation guard still spares phrases like "no need to visit the
# office" / "sin ir a la oficina" / "trabajo no presencial".
_FAKE_REMOTE_OFFICE: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"occasional(?:ly)?\s+(?:visit|visits|come|go|travel|trip)", re.I),
     "Fake-remote: 'occasional visits' to office"),
    (re.compile(r"visit(?:s|ing)?\s+(?:to\s+)?the\s+office", re.I),
     "Fake-remote: 'visit the office'"),
    (re.compile(r"(?:come|go(?:ing)?|travel|commut\w*)\s+(?:in)?to\s+the\s+office", re.I),
     "Fake-remote: 'come to the office'"),
    (re.compile(r"come\s+into\s+the\s+office", re.I),
     "Fake-remote: 'come into the office'"),
    (re.compile(r"office\s+(?:attendance|presence|days)", re.I),
     "Fake-remote: office attendance required"),
    (re.compile(r"days?\s+(?:per\s+week\s+|a\s+week\s+)?in\s+the\s+office", re.I),
     "Fake-remote: 'days in the office'"),
    (re.compile(r"d[ií]as en la oficina", re.I),
     "Fake-remote: 'días en la oficina'"),
    (re.compile(r"(?:ir|acudir|venir|asistir)\s+a\s+la\s+oficina", re.I),
     "Fake-remote: office visits (oficina)"),
    (re.compile(r"\boficinas?\b", re.I),
     "Fake-remote: 'oficina' mention"),
    (re.compile(r"\bpresencial(?:idad|mente|es)?\b", re.I),
     "Fake-remote: 'presencial'"),
    (re.compile(r"\bon[\s\-]?site\b", re.I),
     "Fake-remote: 'on-site'"),
]

# SOFT red flags — applied ONLY when no strong full-remote signal is present.
# These can be legitimate for a Spain-based remote role ("must reside in Spain,
# 100% remote"), so a strong remote phrase overrides them.
_FAKE_REMOTE_SOFT: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bh[ií]brid[oa]\b|\bhybrid\b", re.I), "Fake-remote: 'hybrid/híbrido' in text"),
    (re.compile(r"must\s+reside\s+in", re.I), "Fake-remote: 'must reside in'"),
    (re.compile(r"must\s+live\s+in", re.I), "Fake-remote: 'must live in'"),
    (re.compile(r"must\s+be\s+(?:based|located)\s+in", re.I), "Fake-remote: 'must be based/located in'"),
    (re.compile(r"relocat(?:e|ion)\s+(?:to|required|is\s+required|is\s+needed)", re.I),
     "Fake-remote: relocation required"),
    (re.compile(r"residir\s+en", re.I), "Fake-remote: 'residir en' (must reside)"),
    (re.compile(r"vivir\s+en", re.I), "Fake-remote: 'vivir en' (must live)"),
]

# If one of these GENUINE negations appears just BEFORE an office term, the
# office mention is negated ("no need to visit the office", "sin ir a la
# oficina", "trabajo no presencial") and is NOT treated as a red flag.
# NOTE: strong-remote phrases ("100% remote", "fully remote") are deliberately
# NOT here — "100% remote, but occasionally visit the office" IS fake remote.
_OFFICE_NEGATORS = (
    "no ", "no-", "not ", "n't", "sin ", "without", "never", "ni ",
    "fuera de", "no need", "no necesitas", "no requiere", "not required",
    "neither", "free of", "don't", "do not", "doesn't", "does not",
)

# ---------------------------------------------------------------------------
# Refresh-specific configuration — DIFFERENT from full scraper
# ---------------------------------------------------------------------------

GLOBAL_KEYWORDS = 'Remote OR "Work from Anywhere" OR "Remote Worldwide" OR EMEA'

MARKETS: dict[str, dict] = {
    "Armenia": {
        # REMOTE-ONLY by design (Hybrid / On-site rejected globally further down).
        # f_WT=2 (Remote) keeps the LinkedIn search filter aligned with the
        # post-card page check, so we don't waste queries on Hybrid / On-site
        # cards that will be rejected anyway.
        "geo_id": "103030111",
        "work_types": {
            "Remote": ("2", True),
        },
    },
    "Spain": {
        # Re-enabled: global / English-speaking companies (Qonto, SEARADAR, etc.)
        # post their remote EMEA roles to the Spain geo. Spain is country-wide
        # so cards like "Madrid, Spain" or "Barcelona, Spain" are valid; the
        # page-level checks below reject Hybrid / On-site / closed pages, and
        # `Spanish` in TITLE_LOCATION_EXCLUSIONS still blocks language-specific
        # postings ("Spanish-speaking Data Analyst", etc.).
        "geo_id": "105646813",
        "work_types": {
            "Remote": ("2", True),
        },
    },
}

# ---------------------------------------------------------------------------
# Title / Location exclusion list — applied in extract_card() BEFORE
# any expensive detail-page fetch. Case-insensitive substring match against
# `Title | Location`. Edit this list freely; no other code changes needed.
#
# We intentionally DO NOT list "Spain" / "España" here — those are valid
# locations for global remote postings. Only language-specific / Spain-local
# remote phrases are blocked.
# ---------------------------------------------------------------------------

TITLE_LOCATION_EXCLUSIONS: list[str] = [
    # Language-specific roles (require Spanish speaker / Spanish citizenship)
    "Spanish",
    "Spanish-speaking",
    "Spanish speaker",
    "Native Spanish",
    "Castellano",
    # "Remote within Spain only" phrases
    "Remoto (España)",
    "Remote Spain",
]

_TITLE_LOC_EXCLUSION_RE = re.compile(
    "|".join(re.escape(t) for t in TITLE_LOCATION_EXCLUSIONS),
    re.IGNORECASE,
)

EXPERIENCE_LEVELS = {
    "Mid-Senior level": "4",
    "Associate":        "3",
    "Entry level":      "2",
}

SEARCH_KEYWORDS = [
    # 5 most distinct keywords — no redundant overlap between them.
    # "BI Analyst" removed  → fully covered by "Business Intelligence" search.
    # "SQL Analyst" removed → mostly covered by "Data Analyst" + regex gate.
    "Data Analyst",
    "Data Engineer",
    "Business Intelligence",   # catches: BI Analyst, BI Developer, BI Engineer
    "Power BI",                # popular enough to warrant its own search
    "Analytics Engineer",      # distinct enough (dbt, Looker, metrics layer)
]

# --- The 3 key timing values (see docstring math) ---
RESULTS_PER_PAGE                = 25
MAX_PAGES_PER_QUERY             = 3    # 7-day window → page 3 often has hits now
QUERIES_BEFORE_CONTEXT_ROTATION = 12   # 60 total queries → ~5 rotations

# Posting freshness window passed to LinkedIn (f_TPR=r{seconds}).
# Was r86400 (24 hours). Widened to 7 days so jobs posted earlier in the
# week — but missed by previous daily runs — are also picked up.
# Dedup in IncrementalCsvWriter ensures already-seen URLs are skipped,
# so re-running daily with a 7-day window is safe (no duplicates).
TIME_WINDOW_SECONDS = 7 * 24 * 60 * 60  # = 604_800

# ---------------------------------------------------------------------------
# Stealth Configuration — same pools as full scraper
# ---------------------------------------------------------------------------

_USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
]

_LOCALES   = ["en-US", "en-GB", "en"]
_TIMEZONES = [
    "America/New_York", "America/Chicago", "America/Los_Angeles",
    "Europe/London", "Europe/Berlin", "Asia/Jerusalem",
]
_VIEWPORTS = [
    {"width": 1280, "height": 768},
    {"width": 1366, "height": 768},
    {"width": 1440, "height": 900},
    {"width": 1536, "height": 1024},
    {"width": 1920, "height": 1080},
]

_CHROMIUM_ARGS = [
    "--disable-blink-features=AutomationControlled",
    "--disable-features=IsolateOrigins,site-per-process",
    "--disable-infobars",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    "--disable-popup-blocking",
    "--ignore-certificate-errors",
]

# Block detection — split URL vs body (same fix as full scraper)
_BLOCK_URL_SIGNALS = ["authwall", "/login", "checkpoint", "captcha"]
_BLOCK_BODY_SIGNALS = [
    "security verification",
    "unusual activity",
    "let's do a quick security check",
    "verify you're a human",
    "are you a robot",
    "complete the security check",
    "please verify your identity",
]

# Closed-job phrases — LinkedIn shows these on the job detail page when
# the posting has been closed by the employer. The expired-redirect URL
# check (see `is_job_closed`) catches guest-view redirects in addition to
# these banner phrases.
_CLOSED_PHRASES = [
    "no longer accepting applications",
    "this job is no longer accepting",
    "job is no longer available",
    "no longer applicable",
    "ya no acepta solicitudes",
    "esta oferta ya no acepta",
]

# ---------------------------------------------------------------------------
# Salary Parsing — identical to full scraper
# ---------------------------------------------------------------------------

_CURRENCY_TO_USD: dict[str, float] = {
    "$": 1.0,    "usd": 1.0,
    "€": 1.10,   "eur": 1.10,
    "£": 1.28,   "gbp": 1.28,
    "₪": 0.27,   "ils": 0.27,
    "֏": 0.0026, "amd": 0.0026,
}

_SALARY_RE = re.compile(
    r"(?P<cur>[$€£₪֏]|USD|EUR|GBP|ILS|AMD)?\s*"
    r"(?P<n1>[\d,]+(?:\.\d+)?)\s*[Kk]?\s*"
    r"(?:\s*[-–—/to]+\s*"
    r"(?P<cur2>[$€£₪֏]|USD|EUR|GBP|ILS|AMD)?\s*"
    r"(?P<n2>[\d,]+(?:\.\d+)?)\s*[Kk]?)?"
    r"(?:\s*/\s*(?:yr|year|mo|month|hr|hour|annual))?",
    re.IGNORECASE,
)


def _parse_salary_number(s: str) -> float:
    val = float(s.replace(",", ""))
    return val * 1000 if val < 1000 else val


def parse_salary(raw: str) -> tuple[str, str]:
    if not raw or not raw.strip():
        return ("N/A", "N/A")
    raw = raw.strip()
    m = _SALARY_RE.search(raw)
    if not m or not m.group("n1"):
        return (raw, "N/A")
    cur_symbol = (m.group("cur") or m.group("cur2") or "$").lower()
    rate = _CURRENCY_TO_USD.get(cur_symbol, 1.0)
    n1 = _parse_salary_number(m.group("n1"))
    n2 = _parse_salary_number(m.group("n2")) if m.group("n2") else n1
    usd = round(((n1 + n2) / 2.0) * rate, 2)
    return (raw, f"{usd:.0f}")

# ---------------------------------------------------------------------------
# Timing helpers — FAST values tuned for 10-minute target run
# ---------------------------------------------------------------------------

def _human_delay(base: float = 1.5, spread: float = 0.5, minimum: float = 0.4) -> float:
    """Gaussian delay — aggressive minimums, safe for a 60-page headless run."""
    return max(minimum, random.gauss(base, spread))


async def human_wait(page: Page, base: float = 1.5, spread: float = 0.5) -> None:
    await page.wait_for_timeout(int(_human_delay(base, spread) * 1000))


async def human_scroll(page: Page, scrolls: int = 0) -> None:
    """1–2 quick scrolls — enough to trigger lazy-load, not more."""
    if scrolls <= 0:
        scrolls = random.randint(1, 2)
    for _ in range(scrolls):
        await page.mouse.wheel(0, random.randint(200, 450))
        await page.wait_for_timeout(random.randint(200, 500))


async def random_mouse_move(page: Page) -> None:
    vp = page.viewport_size or {"width": 1280, "height": 900}
    await page.mouse.move(
        random.randint(100, vp["width"] - 100),
        random.randint(100, vp["height"] - 100),
        steps=random.randint(3, 7),
    )
    await page.wait_for_timeout(random.randint(60, 200))

# ---------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------


def _is_geo_restricted(title: str, location: str) -> bool:
    combined = f"{title} {location}".lower()
    return any(phrase in combined for phrase in _NEGATIVE_PHRASES)


def _is_accessible(location: str) -> bool:
    loc = (location or "").lower().strip()
    return any(sig in loc for sig in _ALLOWED_LOCATION_SIGNALS)

# ---------------------------------------------------------------------------
# DOM Extraction — identical to full scraper
# ---------------------------------------------------------------------------


async def extract_text(element: Any, selectors: list[str]) -> str:
    for selector in selectors:
        try:
            el = await element.query_selector(selector)
            if el:
                return (await el.inner_text()).strip()
        except Exception:
            continue
    return ""


async def extract_attribute(element: Any, selectors: list[str], attr: str) -> str:
    for selector in selectors:
        try:
            el = await element.query_selector(selector)
            if el:
                val = await el.get_attribute(attr)
                return val.strip() if val else ""
        except Exception:
            continue
    return ""


_TITLE_SELECTORS    = [".base-search-card__title", ".job-card-list__title", ".artdeco-entity-lockup__title"]
_COMPANY_SELECTORS  = [".base-search-card__subtitle", ".job-card-container__primary-description"]
_LOCATION_SELECTORS = [".job-search-card__location", ".job-card-container__metadata-item"]
_URL_SELECTORS      = ["a.base-card__full-link", "a.job-card-container__link"]
_SALARY_SELECTORS   = [".job-search-card__salary-info", ".salary-main-rail__min-max", ".result-benefits__text"]
_TIME_SELECTORS     = ["time"]


async def extract_card(
    card: Any,
    market_name: str,
    search_keyword: str,
    exp_name: str,
    work_type_name: str = "Remote",
) -> dict[str, Any] | None:

    title      = await extract_text(card, _TITLE_SELECTORS)
    company    = await extract_text(card, _COMPANY_SELECTORS)
    location   = await extract_text(card, _LOCATION_SELECTORS)
    salary_raw = await extract_text(card, _SALARY_SELECTORS)
    posted_date = await extract_attribute(card, _TIME_SELECTORS, "datetime")

    raw_url = await extract_attribute(card, _URL_SELECTORS, "href")
    if not raw_url:
        job_id = await extract_attribute(card, ["[data-job-id]"], "data-job-id")
        if job_id:
            raw_url = f"https://www.linkedin.com/jobs/view/{job_id}/"
    job_url = raw_url.split("?")[0] if raw_url else ""

    if not title and not job_url:
        return None

    rejection_reason = ""
    neg_match = NEGATIVE_PATTERN.search(title)
    excl_match = _TITLE_LOC_EXCLUSION_RE.search(f"{title} | {location}")

    if excl_match:
        rejection_reason = (
            f"Excluded keyword in title/location: '{excl_match.group(0)}'"
        )
    elif _is_geo_restricted(title, location):
        rejection_reason = "Geo-restricted phrase in title/location"
    elif neg_match:
        rejection_reason = f"Blacklist word: '{neg_match.group(0)}'"
    elif not POSITIVE_PATTERN.search(title):
        rejection_reason = "Missing target root word"
    elif not _is_accessible(location):
        rejection_reason = f"Location not accessible: '{location}'"

    original_salary, salary_usd = parse_salary(salary_raw)
    current_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    data_row = {
        "Title":            title or "Unknown",
        "Company":          company or "Unknown",
        "Location":         location or "Unknown",
        "Market":           market_name,
        "Work_Type":        work_type_name,
        "Search_Keyword":   search_keyword,
        "Experience_Level": exp_name,
        "Original_Salary":  original_salary,
        "Salary_in_USD":    salary_usd,
        "Job_URL":          job_url,
        "Posted_Date":      posted_date or "Unknown",
        "Scraped_At":       current_time,
    }

    return {
        "status": "rejected" if rejection_reason else "accepted",
        "reason": rejection_reason,
        "data":   data_row,
    }

# ---------------------------------------------------------------------------
# Disk-Safe Writers — identical logic to full scraper
# ---------------------------------------------------------------------------

class BaseDiskSafeWriter:
    def __init__(self, path: Path, fields: list[str]) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._seen_urls: set[str] = set()
        self._count = 0

        need_header = not self.path.exists() or self.path.stat().st_size == 0
        if not need_header:
            self._load_existing_urls()

        self._file   = self.path.open("a", newline="", encoding="utf-8-sig")
        self._writer = csv.DictWriter(self._file, fieldnames=fields, extrasaction="ignore")

        if need_header:
            self._writer.writeheader()
            self._file.flush()
            os.fsync(self._file.fileno())

    def _load_existing_urls(self) -> None:
        with self.path.open("r", encoding="utf-8-sig") as f:
            for row in csv.DictReader(f):
                url = row.get("Job_URL", "").strip()
                if url:
                    self._seen_urls.add(url)
        log.info("Dedup: loaded %d existing URLs from %s", len(self._seen_urls), self.path.name)

    def write_row(self, row: dict[str, str]) -> bool:
        url = row.get("Job_URL", "").strip()
        if url and url in self._seen_urls:
            return False
        if url:
            self._seen_urls.add(url)
        self._writer.writerow(row)
        self._file.flush()
        os.fsync(self._file.fileno())
        self._count += 1
        return True

    def close(self) -> None:
        if not self._file.closed:
            self._file.flush()
            os.fsync(self._file.fileno())
            self._file.close()
            log.info("Closed: %s  (new rows this session: %d)", self.path.name, self._count)

    def __enter__(self) -> "BaseDiskSafeWriter":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        self.close()
        return False


class IncrementalCsvWriter(BaseDiskSafeWriter):
    def __init__(self, path: Path) -> None:
        super().__init__(path, [
            "Title", "Company", "Location", "Market", "Work_Type", "Search_Keyword",
            "Experience_Level", "Original_Salary", "Salary_in_USD",
            "Job_URL", "Posted_Date", "Scraped_At",
        ])


class RejectLogWriter(BaseDiskSafeWriter):
    """No dedup — log every rejection occurrence for audit."""
    def __init__(self, path: Path) -> None:
        super().__init__(path, [
            "Rejection_Reason", "Title", "Company", "Location", "Job_URL", "Scraped_At",
        ])

    def write_row(self, row: dict[str, str]) -> bool:
        self._writer.writerow(row)
        self._file.flush()
        os.fsync(self._file.fileno())
        self._count += 1
        return True

# ---------------------------------------------------------------------------
# Stealth Browser Helpers
# ---------------------------------------------------------------------------


async def new_stealth_context(browser) -> BrowserContext:
    ua     = random.choice(_USER_AGENTS)
    vp     = random.choice(_VIEWPORTS)
    locale = random.choice(_LOCALES)
    tz     = random.choice(_TIMEZONES)
    ctx = await browser.new_context(
        viewport=vp,
        user_agent=ua,
        locale=locale,
        timezone_id=tz,
        color_scheme="light",
        java_script_enabled=True,
        ignore_https_errors=True,
    )
    await Stealth().apply_stealth_async(ctx)
    log.info("New context: UA=…%s  %dx%d  %s  %s", ua[-35:], vp["width"], vp["height"], locale, tz)
    return ctx


async def warmup(page: Page) -> None:
    """
    Organic session start — visit homepage once before the first query only.
    NOT called on context rotations (saves 3s per rotation = 6s total for this run).
    """
    try:
        await page.goto("https://www.linkedin.com/", wait_until="domcontentloaded", timeout=20_000)
    except Exception:
        pass
    await human_wait(page, base=1.5, spread=0.5)
    await human_scroll(page, scrolls=1)
    await random_mouse_move(page)


async def is_blocked(page: Page) -> bool:
    url = page.url.lower()
    if any(sig in url for sig in _BLOCK_URL_SIGNALS):
        return True
    try:
        body = (await page.inner_text("body"))[:3000].lower()
        return any(sig in body for sig in _BLOCK_BODY_SIGNALS)
    except Exception:
        return True


# Static-asset URL patterns blocked on every detail-page fetch.
# Skipping images / fonts / media / analytics on the lightweight guest job
# page roughly halves the load time (~3.5s → ~1.7s per page) without
# affecting the inner_text we actually parse.
_DETAIL_ASSET_BLOCK_RE = re.compile(
    r"\.(?:png|jpe?g|gif|svg|webp|ico|woff2?|ttf|otf|eot|mp4|webm|mp3|css)(?:\?|$)",
    re.IGNORECASE,
)
_DETAIL_HOST_BLOCK = (
    "googletagmanager", "google-analytics", "doubleclick",
    "static.linkedin.com/sc/", "media.licdn.com", "fonts.gstatic",
)


async def _abort_static(route) -> None:
    url = route.request.url
    if _DETAIL_ASSET_BLOCK_RE.search(url) or any(h in url for h in _DETAIL_HOST_BLOCK):
        try:
            await route.abort()
            return
        except Exception:
            pass
    try:
        await route.continue_()
    except Exception:
        pass


async def fetch_job_body(ctx: BrowserContext, job_url: str) -> tuple[str | None, str | None]:
    """
    Fetch the LinkedIn job detail page once per accepted card.

    Returns:
        (body, final_url) — body is inner_text of the detail page, final_url is
                            the URL after any LinkedIn redirect (used to detect
                            expired-job redirects like `trk=expired_jd_redirect`).
        (None, None)      — could not load (no URL, nav error, auth wall).
                            Callers must treat None as "keep the row".

    Speed notes:
      • Static assets (images, fonts, CSS, analytics) are aborted via a route
        handler — the guest job page renders all the text we need without them.
      • Settle wait dropped from 1500 ms → 700 ms; the badge / employment-type
        DOM is already present after domcontentloaded for the guest view.
      • Detail page is opened from the same context as the search loop, so
        cookies / session are reused (no extra auth round-trip).
    """
    if not job_url:
        return (None, None)
    detail_page = await ctx.new_page()
    try:
        try:
            await detail_page.route("**/*", _abort_static)
        except Exception:
            pass
        try:
            await detail_page.goto(job_url, wait_until="domcontentloaded", timeout=20_000)
        except Exception:
            return (None, None)
        final_url = detail_page.url or ""
        if any(sig in final_url.lower() for sig in _BLOCK_URL_SIGNALS):
            return (None, final_url)
        await detail_page.wait_for_timeout(700)
        try:
            body = await detail_page.inner_text("body")
        except Exception:
            return (None, final_url)
        return (body or None, final_url)
    finally:
        try:
            await detail_page.close()
        except Exception:
            pass


def is_job_closed(body: str | None, final_url: str | None) -> bool:
    """
    True when the detail page is clearly closed.

    Two signals — either is enough:
      1) Final URL no longer points at /jobs/view/<id> (LinkedIn redirects
         expired guest pages to /jobs/<keyword>-empleos, often tagged with
         `trk=expired_jd_redirect`).
      2) Body contains a 'no longer accepting applications' phrase.
    """
    if final_url:
        url_low = final_url.lower()
        if "trk=expired_jd_redirect" in url_low:
            return True
        if "/jobs/view/" not in url_low:
            return True
    if not body:
        return False
    head = body[:6000].lower()
    return any(p in head for p in _CLOSED_PHRASES)


def detect_hybrid_or_onsite(body: str | None, title: str) -> str | None:
    """
    Generic Remote-only guard for ANY market.

    Returns rejection reason if the detail page advertises Hybrid or On-site
    (badge in the top section, Spanish `Híbrido` / `Modalidad híbrida`, etc.).
    Returns None when no Hybrid/On-site signal is found, when the body is
    missing, or when the page is blocked — in those cases we keep the row.

    Explicit-remote override: companies like Qonto / SEARADAR sometimes write
    "Open to full remote" / "Fully remote" / "100% remote" at the top of the
    description but still have a boilerplate "hybrid" mention further down
    (e.g. legal text, benefits section, similar-jobs sidebar). We trust the
    strong remote signal and keep the row in that case.
    """
    if not body:
        return None
    arrangement = parse_work_arrangement(body, title or "")
    if arrangement.get("explicit_remote"):
        return None
    if arrangement.get("hybrid"):
        return "Hybrid on LinkedIn (Remote-only scrape)"
    if arrangement.get("onsite"):
        return "On-site on LinkedIn (Remote-only scrape)"
    return None


def spain_inaccessible_reason(
    body: str | None,
    title: str,
    location: str,
) -> str | None:
    """
    Spain-specific extra guard (Full-time + city + no Remote on page).

    Currently the Spain market is disabled in MARKETS, but this is kept as
    a safety net: if Spain is re-enabled, the page-level filter still runs.
    Mirrors `src/verify_spain_remote_jobs.exclusion_reason_from_page`.
    """
    if not body:
        return None
    arrangement = parse_work_arrangement(body, title or "")
    return exclusion_reason_from_page(title or "", location or "", arrangement)


def _office_negated(text: str, idx: int) -> bool:
    """True when an office term at `idx` is preceded by a negation word."""
    window = text[max(0, idx - 35):idx]
    return any(neg in window for neg in _OFFICE_NEGATORS)


def strict_remote_rejection(
    body: str | None,
    title: str,
    location: str,
) -> str | None:
    """
    STRICT 100%-remote guard for ALL markets (Armenia + Spain).

    Two-step filter on the job detail page:
      1) Metadata / workplace badge — reject Hybrid / On-site / Presencial /
         Híbrido outright (no override).
      2) Description text scan — reject "fake remote" postings (office visits,
         local-residency rules, hidden-hybrid phrasing) in English + Spanish.

    A strong full-remote signal ("100% remote", "fully remote", "teletrabajo",
    a Remote badge, "remote" in title, "work from anywhere") OVERRIDES the soft
    red flags so genuinely-remote roles are kept. The HARD traps still reject.

    Returns a rejection reason, or None to KEEP the row. When `body` is None
    (page blocked / nav error / auth wall) we return None — we never drop a row
    just because the page could not be read.
    """
    if not body:
        return None

    arrangement = parse_work_arrangement(body, title or "")
    badges = (arrangement.get("badges") or "").lower()

    # STEP 1 — metadata workplace badge (hard reject, no override).
    if any(w in badges for w in _HYBRID_BADGE_WORDS):
        return "Metadata: Hybrid workplace tag (not 100% remote)"
    if any(w in badges for w in _ONSITE_BADGE_WORDS):
        return "Metadata: On-site workplace tag (not 100% remote)"

    head = body[:8000].lower()

    # STEP 2a — hard description traps (reject even with a strong remote signal).
    for pat, reason in _FAKE_REMOTE_HARD:
        if pat.search(head):
            return reason

    # STEP 2b — office-commitment phrases (no override; negation-guarded). A
    # genuinely 100%-remote role does not ask you to visit / attend an office.
    for pat, reason in _FAKE_REMOTE_OFFICE:
        m = pat.search(head)
        if m and not _office_negated(head, m.start()):
            return reason

    # A strong full-remote signal keeps the row despite the soft flags below.
    if arrangement.get("explicit_remote"):
        return None

    # STEP 2c — soft red flags (only when no strong full-remote signal).
    for pat, reason in _FAKE_REMOTE_SOFT:
        if pat.search(head):
            return reason

    # STEP 2d — require a positive Remote confirmation on a readable page.
    if not arrangement.get("remote") and not arrangement.get("blocked"):
        return "No Remote confirmation on page (strict 100% remote)"

    return None


def build_title_keywords(title: str) -> str:
    tokens = re.findall(r"[a-zA-Z]{2,}", title.lower())
    if not tokens:
        return f'"{title}"'
    if len(tokens) == 1:
        return f'("{title}" OR {tokens[0]})'
    return f'("{title}" OR ({" AND ".join(tokens)}))'


def build_search_url(
    keyword: str,
    market_name: str,
    exp_code: str,
    work_type_code: str = "2",
    include_remote_kw: bool = True,
    start: int = 0,
) -> str:
    title_part = build_title_keywords(keyword)
    keywords   = f'{title_part} AND ({GLOBAL_KEYWORDS})' if include_remote_kw else title_part
    geo_id     = MARKETS[market_name]["geo_id"]
    # f_TPR=r{seconds} → posting freshness filter
    # Currently 7 days (TIME_WINDOW_SECONDS) so jobs posted earlier in the
    # week are also captured. Dedup prevents duplicate writes on re-runs.
    url = (
        f"https://www.linkedin.com/jobs/search/"
        f"?keywords={urllib.parse.quote(keywords)}"
        f"&geoId={geo_id}"
        f"&f_WT={work_type_code}"
        f"&f_E={exp_code}"
        f"&f_TPR=r{TIME_WINDOW_SECONDS}"
    )
    if start > 0:
        url += f"&start={start}"
    return url

# ---------------------------------------------------------------------------
# Daily Summary Reporter
# ---------------------------------------------------------------------------


def _write_daily_summary(
    accepted: int,
    rejected: int,
    total_pages: int,
    duration_seconds: float,
    run_date: str,
) -> None:
    """Appends a one-line summary to refresh_log.txt after every run."""
    summary = (
        f"[{run_date}] "
        f"accepted={accepted:>4}  "
        f"rejected={rejected:>4}  "
        f"pages={total_pages:>4}  "
        f"duration={duration_seconds/60:.1f}min"
    )
    log.info("=" * 60)
    log.info("DAILY REFRESH SUMMARY: %s", summary)
    log.info("=" * 60)

# ---------------------------------------------------------------------------
# Main Refresh Loop
# ---------------------------------------------------------------------------


async def main() -> None:
    run_start = datetime.now(timezone.utc)
    run_date  = run_start.strftime("%Y-%m-%d %H:%M UTC")

    log.info("=" * 60)
    log.info("DAILY REFRESH STARTED — %s", run_date)
    log.info(
        "Time window: last %d days  |  Max pages/query: %d  |  Headless: True",
        TIME_WINDOW_SECONDS // 86_400, MAX_PAGES_PER_QUERY,
    )
    log.info("=" * 60)

    queries = [
        (kw, mkt_name, exp_name, exp_code, wt_name, wt_code, incl_remote_kw)
        for kw                    in SEARCH_KEYWORDS
        for mkt_name, mkt_cfg     in MARKETS.items()
        for exp_name, exp_code    in EXPERIENCE_LEVELS.items()
        for wt_name, (wt_code, incl_remote_kw) in mkt_cfg["work_types"].items()
    ]
    random.shuffle(queries)
    total = len(queries)
    log.info("Total query combinations: %d", total)

    total_page_loads = 0

    with IncrementalCsvWriter(CSV_PATH) as data_writer, \
         RejectLogWriter(REJECT_PATH) as reject_writer:

        def handle_sigterm(signum, frame) -> None:
            log.info("SIGTERM received — flushing CSVs and exiting.")
            data_writer.close()
            reject_writer.close()
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, handle_sigterm)

        try:
            async with async_playwright() as p:
                # headless=True — this is the key difference from the full scraper.
                # The daily refresh runs silently in the background with no browser window.
                browser = await p.chromium.launch(
                    headless=True,
                    args=_CHROMIUM_ARGS,
                )
                ctx  = await new_stealth_context(browser)
                page = await ctx.new_page()
                await warmup(page)

                consecutive_failures = 0
                total_page_loads     = 0

                for idx, (kw, market, exp_name, exp_code, wt_name, wt_code, incl_remote_kw) in enumerate(queries, 1):

                    # Atomic context rotation — warmup intentionally skipped here.
                    # Warmup runs once at startup only. Skipping it on rotations
                    # saves ~3s per rotation × 2 rotations = 6s total.
                    if idx > 1 and (idx - 1) % QUERIES_BEFORE_CONTEXT_ROTATION == 0:
                        old_ctx = ctx
                        try:
                            ctx  = await new_stealth_context(browser)
                            page = await ctx.new_page()
                            await old_ctx.close()
                            consecutive_failures = 0
                            log.info("Context rotated at query %d (no warmup).", idx)
                        except Exception as e:
                            log.warning("Context rotation failed, reusing existing: %s", e)
                            ctx = old_ctx

                    log.info("[%d/%d] %s | %s | %s", idx, total, kw, market, exp_name)

                    for page_num in range(MAX_PAGES_PER_QUERY):

                        url = build_search_url(
                            kw, market, exp_code,
                            work_type_code=wt_code,
                            include_remote_kw=incl_remote_kw,
                            start=page_num * RESULTS_PER_PAGE,
                        )

                        # 3-attempt retry with exponential backoff
                        loaded = False
                        for attempt in range(3):
                            try:
                                await page.goto(url, wait_until="domcontentloaded", timeout=30_000)
                                await human_wait(page, base=1.5, spread=0.5)
                                loaded = True
                                break
                            except Exception as exc:
                                wait_s = 2 ** (attempt + 1) + random.uniform(0, 2)
                                log.warning(
                                    "Navigation failed (attempt %d/3): %s — retrying in %.1fs",
                                    attempt + 1, exc, wait_s,
                                )
                                await page.wait_for_timeout(int(wait_s * 1000))

                        total_page_loads += 1

                        if not loaded:
                            consecutive_failures += 1
                            log.error("Skipping page %d — 3 navigation failures.", page_num + 1)
                            break

                        # Block detection
                        if await is_blocked(page):
                            consecutive_failures += 1
                            backoff = min(60, 5 * 2 ** consecutive_failures) + random.uniform(0, 5)
                            log.warning("BLOCKED — backing off %.0fs.", backoff)
                            # Do not write block screenshots to disk.
                            await page.wait_for_timeout(int(backoff * 1000))
                            break

                        consecutive_failures = 0
                        await random_mouse_move(page)
                        await human_scroll(page)

                        cards = await page.query_selector_all(
                            ".base-card, "
                            ".job-card-container, "
                            "li.jobs-search-results__list-item"
                        )
                        if not cards:
                            log.info("  No cards — end of results at page %d.", page_num + 1)
                            break

                        new_accepted = new_rejected = 0
                        for card in cards:
                            try:
                                result = await extract_card(card, market, kw, exp_name, wt_name)
                                if not result:
                                    continue

                                if result["status"] == "accepted":
                                    # ONE detail-page fetch covers two checks:
                                    #   1) Closed posting — banner text OR
                                    #      `trk=expired_jd_redirect` URL signal.
                                    #   2) STRICT 100%-remote guard (ALL markets):
                                    #      metadata workplace badge + description
                                    #      "fake remote" red-flag scan.
                                    # `body is None` means we couldn't read the page
                                    # (block, nav error, auth wall) — keep the row.
                                    body, final_url = await fetch_job_body(ctx, result["data"]["Job_URL"])

                                    if is_job_closed(body, final_url):
                                        reject_writer.write_row({
                                            "Rejection_Reason": "Closed: no longer accepting applications",
                                            "Title":      result["data"]["Title"],
                                            "Company":    result["data"]["Company"],
                                            "Location":   result["data"]["Location"],
                                            "Job_URL":    result["data"]["Job_URL"],
                                            "Scraped_At": result["data"]["Scraped_At"],
                                        })
                                        new_rejected += 1
                                        continue

                                    remote_reason = strict_remote_rejection(
                                        body,
                                        result["data"]["Title"],
                                        result["data"]["Location"],
                                    )
                                    if remote_reason:
                                        reject_writer.write_row({
                                            "Rejection_Reason": remote_reason,
                                            "Title":      result["data"]["Title"],
                                            "Company":    result["data"]["Company"],
                                            "Location":   result["data"]["Location"],
                                            "Job_URL":    result["data"]["Job_URL"],
                                            "Scraped_At": result["data"]["Scraped_At"],
                                        })
                                        new_rejected += 1
                                        continue

                                    if data_writer.write_row(result["data"]):
                                        new_accepted += 1

                                elif result["status"] == "rejected":
                                    reject_row = {
                                        "Rejection_Reason": result["reason"],
                                        "Title":      result["data"]["Title"],
                                        "Company":    result["data"]["Company"],
                                        "Location":   result["data"]["Location"],
                                        "Job_URL":    result["data"]["Job_URL"],
                                        "Scraped_At": result["data"]["Scraped_At"],
                                    }
                                    reject_writer.write_row(reject_row)
                                    new_rejected += 1

                            except Exception as e:
                                log.debug("Stale card skipped: %s", e)
                                continue

                        log.info(
                            "  Page %d | +%d accepted | +%d rejected",
                            page_num + 1, new_accepted, new_rejected,
                        )

                        # No new rows on this page = LinkedIn exhausted 24h results early
                        if new_accepted == 0 and new_rejected == 0:
                            log.info("  No new rows — moving to next query.")
                            break

                        # Shorter between-page delay (1.5s vs 5s in full scraper)
                        await human_wait(page, base=1.5, spread=0.5)

                    # Shorter between-query delay (2.5s vs 8s in full scraper)
                    await human_wait(page, base=2.5, spread=1.0)

                await browser.close()

        except KeyboardInterrupt:
            log.info("Stopped by user (Ctrl+C) — all written rows are safe on disk.")

    # Final summary
    duration = (datetime.now(timezone.utc) - run_start).total_seconds()
    _write_daily_summary(
        accepted=data_writer._count,
        rejected=reject_writer._count,
        total_pages=total_page_loads,
        duration_seconds=duration,
        run_date=run_date,
    )
    log.info("Accepted CSV : %s", CSV_PATH)
    log.info("Rejected log : %s", REJECT_PATH)
    log.info("Refresh log  : %s", _LOG_PATH)


if __name__ == "__main__":
    asyncio.run(main()) 
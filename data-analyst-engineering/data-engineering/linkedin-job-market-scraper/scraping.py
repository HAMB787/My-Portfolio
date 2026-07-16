"""
LinkedIn Jobs — Ultimate Stealth Scraper & Data Audit Pipeline (FINAL V5 - Optimized)
==========================================================================
Includes:
  - Smart Boolean Search & Strict Regex Gates
  - Split Block Detection to prevent false positives
  - Rejection Logger for Full Audit
  - OPTIMIZED: Batched os.fsync() every 25 rows for high-speed SSD writes
  - OPTIMIZED: RAM-efficient reject logging (no wasted URL caching)
  - OPTIMIZED: MAX_PAGES capped at 15 for realistic Guest UI limits
  - OPTIMIZED: Silent exceptions replaced with active logging
  - Hardcoded Paths & Headless=False retained per user preference
"""

from __future__ import annotations

import asyncio
import csv
import logging
import os
import random
import re
import signal
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from playwright.async_api import BrowserContext, Page, async_playwright  # pyright: ignore[reportMissingImports]
from playwright_stealth import Stealth  # pyright: ignore[reportMissingImports]

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("linkedin_stealth")

# ---------------------------------------------------------------------------
# Regex Filtering Configuration
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

# ---------------------------------------------------------------------------
# Scrape Configuration
# ---------------------------------------------------------------------------

GLOBAL_KEYWORDS = 'Remote OR "Work from Anywhere" OR "Remote Worldwide" OR EMEA'

MARKETS: dict[str, dict] = {
    "Armenia": {
        "geo_id": "103030111",
        "work_types": {
            "Remote": ("2", True),
        },
    },
    "Spain": {
        "geo_id": "105646813",
        "work_types": {
            "Remote": ("2", True),
        },
    },
}

EXPERIENCE_LEVELS = {
    "Mid-Senior level": "4",
    "Associate":        "3",
    "Entry level":      "2",
}

SEARCH_KEYWORDS = [
    "Data Analyst",
    "BI Analyst",
    "Data Engineer",
    "Power BI",
    "SQL Analyst",
    "Business Intelligence",
    "Analytics Engineer",
]

RESULTS_PER_PAGE                = 25
MAX_PAGES_PER_QUERY             = 15   # OPTIMIZED: LinkedIn guests get cut off around here anyway
QUERIES_BEFORE_CONTEXT_ROTATION = 4
PAGES_BEFORE_CONTEXT_ROTATION   = 15

# ---------------------------------------------------------------------------
# Paths — Hardcoded as requested
# ---------------------------------------------------------------------------

BASE_DIR = Path(r"C:\Users\Администратор\OneDrive\Desktop\Linkedin Scraper")
CSV_PATH    = BASE_DIR / "linkedin_dashboard_jobs_combined.csv"
REJECT_PATH = BASE_DIR / "rejected_jobs_log.csv"

# ---------------------------------------------------------------------------
# Location allow-list
# ---------------------------------------------------------------------------

_ALLOWED_LOCATION_SIGNALS = [
    "armenia", "yerevan", "gyumri",
    "spain", "madrid", "barcelona", "valencia", "seville", "bilbao",
    "worldwide", "remote", "anywhere", "global",
    "emea", "europe", "work from anywhere", "remote worldwide",
]

# ---------------------------------------------------------------------------
# Stealth Configuration
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

_LOCALES    = ["en-US", "en-GB", "en"]
_TIMEZONES  = [
    "America/New_York", "America/Chicago", "America/Los_Angeles",
    "Europe/London", "Europe/Berlin", "Asia/Jerusalem",
]
_VIEWPORTS  = [
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

_BLOCK_URL_SIGNALS = ["authwall", "/login", "checkpoint", "captcha"]
_BLOCK_BODY_SIGNALS = [
    "security verification", "unusual activity",
    "let's do a quick security check", "verify you're a human",
    "are you a robot", "complete the security check", "please verify your identity",
]

# ---------------------------------------------------------------------------
# Salary Parsing
# ---------------------------------------------------------------------------

_CURRENCY_TO_USD: dict[str, float] = {
    "$": 1.0,   "usd": 1.0,
    "€": 1.10,  "eur": 1.10,
    "£": 1.28,  "gbp": 1.28,
    "₪": 0.27,  "ils": 0.27,
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
# Timing & Interaction Helpers
# ---------------------------------------------------------------------------

def _human_delay(base: float = 2.0, spread: float = 1.0, minimum: float = 0.8) -> float:
    return max(minimum, random.gauss(base, spread))

async def human_wait(page: Page, base: float = 2.0, spread: float = 1.0) -> None:
    await page.wait_for_timeout(int(_human_delay(base, spread) * 1000))

async def human_scroll(page: Page, scrolls: int = 0) -> None:
    if scrolls <= 0:
        scrolls = random.randint(3, 7)
    for _ in range(scrolls):
        await page.mouse.wheel(0, random.randint(200, 600))
        await page.wait_for_timeout(random.randint(400, 1200))

async def random_mouse_move(page: Page) -> None:
    vp = page.viewport_size or {"width": 1280, "height": 900}
    await page.mouse.move(
        random.randint(100, vp["width"] - 100),
        random.randint(100, vp["height"] - 100),
        steps=random.randint(5, 15),
    )
    await page.wait_for_timeout(random.randint(100, 400))

# ---------------------------------------------------------------------------
# Extraction Logic
# ---------------------------------------------------------------------------

def _is_geo_restricted(title: str, location: str) -> bool:
    combined = f"{title} {location}".lower()
    return any(phrase in combined for phrase in _NEGATIVE_PHRASES)

def _is_accessible(location: str) -> bool:
    loc = (location or "").lower().strip()
    return any(sig in loc for sig in _ALLOWED_LOCATION_SIGNALS)

async def extract_text(element: Any, selectors: list[str]) -> str:
    for selector in selectors:
        try:
            el = await element.query_selector(selector)
            if el:
                return (await el.inner_text()).strip()
        except Exception as e:
            log.debug(f"Selector {selector} failed: {e}")
            continue
    return ""

async def extract_attribute(element: Any, selectors: list[str], attr: str) -> str:
    for selector in selectors:
        try:
            el = await element.query_selector(selector)
            if el:
                val = await el.get_attribute(attr)
                return val.strip() if val else ""
        except Exception as e:
            log.debug(f"Attribute {attr} for {selector} failed: {e}")
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

    if _is_geo_restricted(title, location):
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
# Disk-Safe Writers
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
        log.info("Loaded %d existing URLs for dedup: %s", len(self._seen_urls), self.path.name)

    def write_row(self, row: dict[str, str]) -> bool:
        url = row.get("Job_URL", "").strip()
        if url and url in self._seen_urls:
            return False
        if url:
            self._seen_urls.add(url)
        self._writer.writerow(row)
        self._count += 1
        
        # OPTIMIZED: Batch fsync every 25 rows instead of every single row
        if self._count % 25 == 0:
            self._file.flush()
            os.fsync(self._file.fileno())
            
        return True

    @property
    def count(self):
        return self._count

    def close(self) -> None:
        if not self._file.closed:
            self._file.flush()
            os.fsync(self._file.fileno())
            self._file.close()
            log.info("CSV closed: %s  (rows this session: %d)", self.path.name, self._count)

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
    def __init__(self, path: Path) -> None:
        super().__init__(path, [
            "Rejection_Reason", "Title", "Company", "Location", "Job_URL", "Scraped_At",
        ])

    def _load_existing_urls(self) -> None:
        # OPTIMIZED: RAM saving. We don't dedup rejected URLs, so don't load them.
        pass

    def write_row(self, row: dict[str, str]) -> bool:
        self._writer.writerow(row)
        self._count += 1
        
        # OPTIMIZED: Batch fsync every 25 rows
        if self._count % 25 == 0:
            self._file.flush()
            os.fsync(self._file.fileno())
            
        return True

# ---------------------------------------------------------------------------
# Playwright Flow
# ---------------------------------------------------------------------------

async def new_stealth_context(browser) -> BrowserContext:
    ua       = random.choice(_USER_AGENTS)
    vp       = random.choice(_VIEWPORTS)
    locale   = random.choice(_LOCALES)
    tz       = random.choice(_TIMEZONES)
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
    log.info("Warming up — visiting linkedin.com homepage…")
    try:
        await page.goto("https://www.linkedin.com/", wait_until="domcontentloaded", timeout=30_000)
    except Exception as e:
        log.debug("Warmup navigation ignored: %s", e)
        pass
    await human_wait(page, base=3.0, spread=1.5)
    await human_scroll(page, scrolls=random.randint(1, 3))
    await random_mouse_move(page)

async def is_blocked(page: Page) -> bool:
    url = page.url.lower()
    if any(sig in url for sig in _BLOCK_URL_SIGNALS):
        return True
    try:
        body = (await page.inner_text("body"))[:3000].lower()
        return any(sig in body for sig in _BLOCK_BODY_SIGNALS)
    except Exception as e:
        log.debug("Block detection body read failed (assuming blocked): %s", e)
        return True

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
    if include_remote_kw:
        keywords = f'{title_part} AND ({GLOBAL_KEYWORDS})'
    else:
        keywords = title_part

    geo_id = MARKETS[market_name]["geo_id"]
    url = (
        f"https://www.linkedin.com/jobs/search/"
        f"?keywords={urllib.parse.quote(keywords)}"
        f"&geoId={geo_id}"
        f"&f_WT={work_type_code}"
        f"&f_E={exp_code}"
        f"&f_TPR=r5184000"
    )
    if start > 0:
        url += f"&start={start}"
    return url

async def main() -> None:
    queries = [
        (kw, mkt_name, exp_name, exp_code, wt_name, wt_code, incl_remote_kw)
        for kw                    in SEARCH_KEYWORDS
        for mkt_name, mkt_cfg     in MARKETS.items()
        for exp_name, exp_code    in EXPERIENCE_LEVELS.items()
        for wt_name, (wt_code, incl_remote_kw) in mkt_cfg["work_types"].items()
    ]
    random.shuffle(queries)
    total = len(queries)
    log.info("Total query combinations: %d  (Remote only — Armenia + Spain)", total)

    with IncrementalCsvWriter(CSV_PATH) as data_writer, \
         RejectLogWriter(REJECT_PATH) as reject_writer:

        def handle_sigterm(signum, frame) -> None:
            log.info("SIGTERM received — flushing all CSVs and exiting cleanly.")
            data_writer.close()
            reject_writer.close()
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, handle_sigterm)

        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=False,
                    args=_CHROMIUM_ARGS,
                )
                ctx  = await new_stealth_context(browser)
                page = await ctx.new_page()
                await warmup(page)

                consecutive_failures = 0
                total_page_loads     = 0

                for idx, (kw, market, exp_name, exp_code, wt_name, wt_code, incl_remote_kw) in enumerate(queries, 1):

                    if idx > 1 and (idx - 1) % QUERIES_BEFORE_CONTEXT_ROTATION == 0:
                        old_ctx = ctx
                        try:
                            ctx  = await new_stealth_context(browser)
                            page = await ctx.new_page()
                            await warmup(page)
                            await old_ctx.close()
                            consecutive_failures = 0
                            log.info("Context rotated at query %d.", idx)
                        except Exception as e:
                            log.warning("Context rotation failed, reusing existing: %s", e)
                            ctx = old_ctx

                    log.info("[%d/%d] %s | %s | %s | %s", idx, total, kw, market, wt_name, exp_name)

                    for page_num in range(MAX_PAGES_PER_QUERY):

                        if total_page_loads > 0 and total_page_loads % PAGES_BEFORE_CONTEXT_ROTATION == 0:
                            old_ctx = ctx
                            try:
                                log.info("Page-level context rotation after %d loads.", total_page_loads)
                                ctx  = await new_stealth_context(browser)
                                page = await ctx.new_page()
                                await warmup(page)
                                await old_ctx.close()
                                consecutive_failures = 0
                            except Exception as e:
                                log.warning("Page-level rotation failed: %s", e)
                                ctx = old_ctx

                        url = build_search_url(
                            kw, market, exp_code,
                            work_type_code=wt_code,
                            include_remote_kw=incl_remote_kw,
                            start=page_num * RESULTS_PER_PAGE,
                        )

                        loaded = False
                        for attempt in range(3):
                            try:
                                await page.goto(url, wait_until="domcontentloaded", timeout=45_000)
                                await human_wait(page, base=3.5, spread=1.5)
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

                        if await is_blocked(page):
                            consecutive_failures += 1
                            backoff = min(60, 5 * 2 ** consecutive_failures) + random.uniform(0, 5)
                            log.warning("BLOCKED — saving screenshot, backing off %.0fs.", backoff)
                            try:
                                await page.screenshot(
                                    path=str(BASE_DIR / f"blocked_q{idx}_p{page_num}.png")
                                )
                            except Exception as e:
                                log.debug("Failed to save blocked screenshot: %s", e)
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
                            log.info("No cards found — end of results at page %d.", page_num + 1)
                            break

                        new_accepted = new_rejected = 0
                        for card in cards:
                            try:
                                result = await extract_card(card, market, kw, exp_name, wt_name)
                                if not result:
                                    continue

                                if result["status"] == "accepted":
                                    if data_writer.write_row(result["data"]):
                                        new_accepted += 1

                                elif result["status"] == "rejected":
                                    reject_row = {
                                        "Rejection_Reason": result["reason"],
                                        "Title":    result["data"]["Title"],
                                        "Company":  result["data"]["Company"],
                                        "Location": result["data"]["Location"],
                                        "Job_URL":  result["data"]["Job_URL"],
                                        "Scraped_At": result["data"]["Scraped_At"],
                                    }
                                    reject_writer.write_row(reject_row)
                                    new_rejected += 1

                            except Exception as e:
                                log.debug("Stale/detached card skipped: %s", e)
                                continue

                        log.info(
                            "  Page %d | +%d accepted | +%d rejected | "
                            "Total accepted: %d | Total rejected: %d",
                            page_num + 1, new_accepted, new_rejected,
                            data_writer.count, reject_writer.count,
                        )

                        if new_accepted == 0 and new_rejected == 0:
                            log.info("  No new rows on page %d — moving to next query.", page_num + 1)
                            break

                        await human_wait(page, base=5.0, spread=2.0)

                    await human_wait(page, base=8.0, spread=3.0)

                await browser.close()

        except KeyboardInterrupt:
            log.info("Stopped by user (Ctrl+C) — all written rows are safe on disk.")

    log.info(
        "Session complete. Accepted: %d  |  Rejected/logged: %d",
        data_writer.count, reject_writer.count,
    )
    log.info("Accepted CSV : %s", CSV_PATH)
    log.info("Rejected log : %s", REJECT_PATH)

if __name__ == "__main__":
    asyncio.run(main())
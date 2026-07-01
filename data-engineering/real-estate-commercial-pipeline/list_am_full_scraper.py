"""
list.am Commercial Real Estate Scraper
ETL pipeline: Extract → Transform → Load (CSV, row-by-row append)

Target: Commercial properties for rent in Yerevan
Categories: 1408 (Multifunctional), 1401 (Retail/Commercial), 1410 (Other)
"""

import csv
from contextlib import contextmanager
import logging
import os
import random
import re
import time
from datetime import datetime, timedelta
from typing import Any, Optional

import cloudscraper
from bs4 import BeautifulSoup
from curl_cffi import requests as curl_requests

# ─────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────
START_PAGE     = 1
FILE_NAME      = "Yerevan_CommercialRent_DATABASE.csv"
OVERWRITE_OUTPUT = False       # False = append only new listing IDs; True = rebuild CSV from scratch
LOCK_FILE      = "list_am_full_scrapper.lock"
CATEGORIES     = [1408, 1401, 1410]
AMD_TO_USD     = 400          # Exchange rate fallback; replace with live feed if needed
REQUEST_DELAY  = (0.8, 1.6)   # (min, max) seconds between listing-page requests
DETAIL_DELAY   = (0.4, 0.9)   # seconds between detail-page requests
MAX_RETRIES    = 3             # per-request retry attempts
MAX_BLOCK_RETRIES = 5          # consecutive Cloudflare blocks before abort
TIMEOUT        = 20            # seconds
HOME_URL       = "https://www.list.am/"
BROWSER_IMPERSONATE = "chrome124"

# Yerevan district filter (query param)
YEREVAN_PARAMS = "?n=1%2C2%2C3%2C4%2C5%2C6%2C7%2C8%2C9%2C10%2C13"

FIELDNAMES = [
    "id", "category_id", "date_posted_exact", "date_updated_exact",
    "seller_type", "title", "price_raw", "price_usd", "full_location",
    "district", "street", "area_sqm", "entrance", "street_line",
    "elevator", "furniture", "rental_type", "description", "url",
]

# ─────────────────────────────────────────
#  LOGGING
# ─────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("scraper.log", encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────
#  SCRAPER SESSION FACTORY
# ─────────────────────────────────────────
def apply_browser_headers(session: Any) -> None:
    """Stable browser-like headers — do not rotate UA (breaks TLS fingerprint)."""
    session.headers.update({
        "Accept-Language": "hy-AM,hy;q=0.9,en-US;q=0.8,en;q=0.7",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Referer": HOME_URL,
    })


def is_cloudflare_block(response: Any) -> bool:
    """Detect Cloudflare challenge pages even when status is 200."""
    if response.status_code in {403, 429, 503}:
        return True
    snippet = (response.text or "")[:4000].lower()
    markers = (
        "just a moment",
        "challenge-platform",
        "cf-browser-verification",
        "turnstile",
        "attention required",
    )
    return any(marker in snippet for marker in markers)


def warm_up_session(session: Any) -> bool:
    """Load homepage first so category/detail requests reuse a valid CF session."""
    try:
        resp = session.get(HOME_URL, timeout=TIMEOUT)
        if is_cloudflare_block(resp):
            log.warning("Cloudflare block on homepage warmup (HTTP %s)", resp.status_code)
            return False
        log.info("Session warmed up via homepage (HTTP %s)", resp.status_code)
        return True
    except Exception as exc:
        log.error("Homepage warmup failed: %s", exc)
        return False


def build_scraper(use_curl: bool = True) -> Any:
    """
    Create an HTTP session that can pass Cloudflare.

    Primary: curl_cffi with Chrome TLS fingerprint.
    Fallback: cloudscraper (without HTTPAdapter — that breaks CF bypass).
    """
    if use_curl:
        session = curl_requests.Session(impersonate=BROWSER_IMPERSONATE)
        apply_browser_headers(session)
        if warm_up_session(session):
            return session
        log.warning("curl_cffi warmup failed — falling back to cloudscraper")

    scraper = cloudscraper.create_scraper(
        browser={"browser": "chrome", "platform": "windows", "mobile": False}
    )
    apply_browser_headers(scraper)
    warm_up_session(scraper)
    return scraper


def fetch_page(
    scraper: Any, url: str, block_retries: int = 0
) -> tuple[Any, Any, int]:
    """
    GET with Cloudflare handling. Returns (session, response, new_block_retries).
    Rebuilds session after repeated blocks.
    """
    resp: Any = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = scraper.get(url, timeout=TIMEOUT)
        except Exception as exc:
            log.error("Network error for %s (attempt %d/%d): %s", url, attempt, MAX_RETRIES, exc)
            time.sleep(min(15 * attempt, 45))
            continue

        if not is_cloudflare_block(resp):
            return scraper, resp, 0

        block_retries += 1
        wait = min(30 * block_retries, 120)
        log.warning(
            "Cloudflare block on %s (HTTP %s) — attempt %d/%d, sleep %ds",
            url, resp.status_code, block_retries, MAX_BLOCK_RETRIES, wait,
        )
        if block_retries >= MAX_BLOCK_RETRIES:
            return scraper, resp, block_retries

        time.sleep(wait)
        scraper = build_scraper()

    return scraper, resp, block_retries


# ─────────────────────────────────────────
#  TRANSFORMATION HELPERS
# ─────────────────────────────────────────
def clean_price_to_usd(price_text: str, exchange_rate: int = AMD_TO_USD) -> Optional[int]:
    """
    Parse raw price string → USD integer.
    Handles AMD (֏) and USD ($). Returns None if unparseable (logged by caller).
    """
    if not price_text:
        return None
    normalized = price_text.replace(",", "").replace(" ", "")
    match = re.search(r"\d+", normalized)
    if not match:
        return None
    value = int(match.group())
    return round(value / exchange_rate) if "֏" in normalized else value


def parse_date_field(keyword: str, text: str) -> str:
    """
    Extract a date string by keyword from clean page text.
    Handles: 'Այսօր', 'Երեկ', DD.MM.YYYY, with optional HH:MM.
    Returns ISO-formatted string 'YYYY-MM-DD HH:MM' or '' if not found.
    """
    # Allow flexible whitespace between keyword and value
    pattern = (
        fr"{keyword}"
        r"\s*"
        r"(Այսօր|Երեկ|\d{2}\.\d{2}\.\d{4})"
        r"(?:[,\s]+(\d{2}:\d{2}))?"
    )
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return ""

    raw_date = match.group(1).lower()
    raw_time = match.group(2) or ""
    today = datetime.now()

    if "այսօր" in raw_date:
        base = today.strftime("%Y-%m-%d")
    elif "երեկ" in raw_date:
        base = (today - timedelta(days=1)).strftime("%Y-%m-%d")
    else:
        parts = raw_date.split(".")
        base = f"{parts[2]}-{parts[1]}-{parts[0]}"

    return f"{base} {raw_time}".strip()


def extract_regex_field(pattern: str, text: str, group: int = 1) -> str:
    """Generic regex extractor — returns matched group or ''."""
    match = re.search(pattern, text, re.IGNORECASE)
    return match.group(group).strip() if match else ""


# ─────────────────────────────────────────
#  DETAIL PAGE PARSER
# ─────────────────────────────────────────
def parse_detail_page(
    scraper: Any, item_url: str
) -> tuple[dict, Any]:
    """
    Fetch and parse a single listing detail page.
    Returns a dict of extracted fields; empty strings on failure.
    Never raises — all exceptions are caught and logged.
    """
    defaults = {
        "date_posted_exact": "", "date_updated_exact": "",
        "seller_type": "Սեփականատեր", "area_sqm": "",
        "entrance": "", "street_line": "", "elevator": "",
        "furniture": "", "rental_type": "", "description": "",
    }

    try:
        time.sleep(random.uniform(*DETAIL_DELAY))
        scraper, resp, _ = fetch_page(scraper, item_url)

        if is_cloudflare_block(resp):
            log.warning("Blocked on %s — skipping detail, using defaults", item_url)
            return defaults, scraper
        if resp.status_code != 200:
            log.warning("HTTP %s on %s", resp.status_code, item_url)
            return defaults, scraper

        soup = BeautifulSoup(resp.text, "html.parser")

        # Extract description before stripping disabled elements
        desc_elem = soup.find("div", itemprop="description")
        description = (
            desc_elem.get_text(" ", strip=True).replace("\n", " | ")
            if desc_elem else ""
        )

        # Remove "feature absent" markers so regex doesn't false-match
        for tag in soup.find_all(class_="disabled"):
            tag.decompose()

        text = soup.get_text(" ", strip=True)
        # Collapse multiple spaces for consistent regex matching
        text = re.sub(r"\s+", " ", text)

        area_raw = extract_regex_field(r"Մակերես\s*([\d.,]+)", text)
        area_sqm = area_raw.replace(",", ".") if area_raw else ""

        seller_type = "Սեփականատեր"
        if "Գործակալություն" in text and "Սեփականատեր" not in text:
            seller_type = "Գործակալություն"

        elevator = "Այո" if re.search(r"Վերելակ\s*Առկա է", text, re.IGNORECASE) else ""

        return {
            "date_posted_exact": parse_date_field("Տեղադրված է", text),
            "date_updated_exact": parse_date_field("Թարմացվել է", text),
            "seller_type":  seller_type,
            "area_sqm":     area_sqm,
            # Entry type: street-facing, courtyard, shared entrance, etc.
            "entrance":     extract_regex_field(
                r"Մուտք\s*(Փողոցից|Բակից|Շքամուտքից|Անհատական|Համատեղ)", text
            ),
            # Street-line position (first line = prime retail frontage)
            "street_line":  extract_regex_field(
                r"Գտնվելու վայրը\s*(Առաջին գիծ|Երկրորդ գիծ)", text
            ),
            "elevator":     elevator,
            "furniture":    extract_regex_field(
                r"Կահույք\s*(Կահույքով|Առկա չէ|Մասնակի|Համաձայնությամբ)", text
            ),
            # Rent type: long-term, short-term, etc.
            "rental_type":  extract_regex_field(
                r"Վարձակալության տեսակ\s*([Ա-Ֆա-ֆ\w]+)", text
            ),
            "description":  description,
        }, scraper

    except Exception as exc:
        log.error("Detail parse failed for %s: %s", item_url, exc, exc_info=False)
        return defaults, scraper


# ─────────────────────────────────────────
#  LISTING PAGE PARSER
# ─────────────────────────────────────────
def parse_listing_cards(soup: BeautifulSoup) -> list[dict]:
    """
    Extract card-level data (id, title, price, location) from a category page.
    Returns list of partial row dicts.
    """
    cards = []
    for item in soup.find_all("a", href=re.compile(r"^/item/")):
        href = item.get("href", "")
        # Strip any query parameters from the item ID
        clean_id = href.split("?")[0].replace("/item/", "").strip()
        if not clean_id:
            continue

        title_elem = item.find("div", class_="l")
        price_elem = item.find("div", class_="p")
        at_elem    = item.find("div", class_="at")

        if not (title_elem and price_elem):
            continue

        title        = title_elem.get_text(strip=True)
        raw_price    = price_elem.get_text(strip=True)
        full_location = at_elem.get_text(strip=True) if at_elem else ""

        # Split "Երևան, Կենտրոն, Տերյան փողոց" → district / street
        loc_parts = [p.strip() for p in full_location.split(",")]
        district  = loc_parts[1] if len(loc_parts) > 1 else full_location
        street    = loc_parts[2] if len(loc_parts) > 2 else ""

        cards.append({
            "id":            clean_id,
            "title":         title,
            "price_raw":     raw_price,
            "price_usd":     clean_price_to_usd(raw_price),
            "full_location": full_location,
            "district":      district,
            "street":        street,
        })
    return cards


# ─────────────────────────────────────────
#  CSV HELPERS
# ─────────────────────────────────────────
def init_csv(path: str) -> None:
    """Write header row. Overwrites any existing file."""
    with open(path, "w", newline="", encoding="utf-8") as f:
        csv.DictWriter(f, fieldnames=FIELDNAMES).writeheader()
    log.info("Initialised new CSV: %s", path)


def load_seen_ids(path: str) -> set[str]:
    """Read existing IDs from CSV for resume support."""
    if not os.path.isfile(path):
        return set()
    with open(path, "r", encoding="utf-8-sig") as f:
        return {
            row.get("id", "").strip()
            for row in csv.DictReader(f)
            if row.get("id", "").strip()
        }


def csv_contains_id(path: str, item_id: str) -> bool:
    """Fresh on-disk check so reruns do not append an already saved listing."""
    return item_id in load_seen_ids(path)


def append_row(path: str, row: dict) -> None:
    """Append a single row. File is opened/closed per write for crash safety."""
    with open(path, "a", newline="", encoding="utf-8") as f:
        csv.DictWriter(f, fieldnames=FIELDNAMES).writerow(row)


@contextmanager
def single_run_lock(lock_path: str):
    """
    Prevent two scraper processes from writing to the same CSV at the same time.
    Uses atomic file creation; if the file already exists, another run is active
    or a previous crashed run left a stale lock behind.
    """
    acquired = False
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        acquired = True
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        yield
    except FileExistsError:
        raise RuntimeError(
            f"Lock file '{lock_path}' already exists. "
            "Another scraper is probably running. Stop it first, or delete the lock file "
            "only after confirming no scraper process is active."
        )
    finally:
        if acquired and os.path.exists(lock_path):
            try:
                os.remove(lock_path)
            except OSError:
                log.warning("Could not remove lock file: %s", lock_path)


# ─────────────────────────────────────────
#  MAIN SCRAPE LOOP
# ─────────────────────────────────────────
def scrape_commercial_market() -> None:
    # ── Setup ──
    if OVERWRITE_OUTPUT:
        log.warning("OVERWRITE_OUTPUT=True → overwriting '%s'", FILE_NAME)
        init_csv(FILE_NAME)
        seen_ids: set[str] = set()
    elif os.path.isfile(FILE_NAME):
        seen_ids = load_seen_ids(FILE_NAME)
        log.info(
            "Append mode — %d existing listing IDs loaded from '%s'",
            len(seen_ids),
            FILE_NAME,
        )
    else:
        init_csv(FILE_NAME)
        seen_ids = set()
        log.info("Append mode — created new CSV '%s'", FILE_NAME)

    scraper = build_scraper()
    block_retries = 0

    total_saved = 0

    try:
        for cat_id in CATEGORIES:
            page = START_PAGE
            log.info("═══ Starting category %d ═══", cat_id)

            while True:
                url = f"https://www.list.am/category/{cat_id}/{page}{YEREVAN_PARAMS}"
                log.info("Fetching category %d, page %d", cat_id, page)

                time.sleep(random.uniform(*REQUEST_DELAY))
                scraper, resp, block_retries = fetch_page(scraper, url, block_retries)

                if block_retries >= MAX_BLOCK_RETRIES:
                    log.error(
                        "Too many Cloudflare blocks (%d). Stop and retry later or use a residential proxy.",
                        block_retries,
                    )
                    return

                if is_cloudflare_block(resp):
                    continue
                if resp.status_code != 200:
                    log.error("HTTP %s on %s — skipping page", resp.status_code, url)
                    page += 1
                    continue

                block_retries = 0
                soup  = BeautifulSoup(resp.text, "html.parser")
                cards = parse_listing_cards(soup)

                if not cards:
                    log.info("No items found on page %d — end of category %d", page, cat_id)
                    break

                new_on_page = 0

                for card in cards:
                    item_id = card["id"]

                    if item_id in seen_ids or csv_contains_id(FILE_NAME, item_id):
                        seen_ids.add(item_id)
                        log.info("Skipping %s — already exists in CSV", item_id)
                        continue

                    seen_ids.add(item_id)
                    new_on_page += 1

                    item_url    = f"https://www.list.am/item/{item_id}"
                    detail_data, scraper = parse_detail_page(scraper, item_url)

                    row = {
                        "id":                 item_id,
                        "category_id":        cat_id,
                        "url":                item_url,
                        **card,               # title, price_raw, price_usd, location fields
                        **detail_data,        # dates, seller_type, area, features
                    }
                    # Ensure all schema columns are present (guard against dict key gaps)
                    row = {k: row.get(k, "") for k in FIELDNAMES}

                    if csv_contains_id(FILE_NAME, item_id):
                        log.info("Skipping %s — another run already saved it", item_id)
                        continue

                    append_row(FILE_NAME, row)
                    total_saved += 1

                    log.info(
                        "Saved %s | $%s | %s | line=%s | entrance=%s",
                        item_id,
                        row["price_usd"] or "—",
                        row["district"],
                        row["street_line"] or "—",
                        row["entrance"] or "—",
                    )

                if new_on_page == 0:
                    log.info(
                        "All items on page %d already in DB — "
                        "assuming remaining pages are stale. Stopping category %d.",
                        page, cat_id,
                    )
                    break

                page += 1

    except KeyboardInterrupt:
        log.warning("Manual interrupt received. %d rows saved this session.", total_saved)

    log.info("Done. Total rows saved this session: %d → '%s'", total_saved, FILE_NAME)


# ─────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────
if __name__ == "__main__":
    try:
        with single_run_lock(LOCK_FILE):
            scrape_commercial_market()
    except RuntimeError as exc:
        log.error("%s", exc)
"""
Daily incremental upsert scraper for list.am commercial real estate listings.

Data engineering scope only:
- pandas in-memory database updates
- regex/rule-based parsing
- browser-like HTTP requests with curl_cffi first, cloudscraper fallback
- no ML / NLP

Upsert logic:
1. New listing id -> deep scrape detail page -> insert row
2. Existing id + changed card price -> deep scrape detail page -> overwrite row
3. Existing id + same card price -> skip detail page

The script scans only the first MAX_DEPTH_PAGES per category to catch new and
price-updated listings near the top while avoiding unnecessary detail requests.
"""

from __future__ import annotations

import csv
import logging
import os
import random
import re
import shutil
import time
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Optional

import cloudscraper
import pandas as pd
from bs4 import BeautifulSoup
from curl_cffi import requests as curl_requests


# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
DATABASE_CSV = Path("Yerevan_CommercialRent_DATABASE.csv")
BACKUP_CSV = Path("Yerevan_CommercialRent_DATABASE_before_daily_upsert.csv")
TEMP_CSV = Path("Yerevan_CommercialRent_DATABASE.tmp")
LOCK_FILE = Path("daily_upsert_scraper.lock")

CATEGORIES = [1408, 1401, 1410]
MAX_DEPTH_PAGES = 15
YEREVAN_PARAMS = "?n=1%2C2%2C3%2C4%2C5%2C6%2C7%2C8%2C9%2C10%2C13"

AMD_TO_USD = 400
TIMEOUT = 20
MAX_RETRIES = 3
REQUEST_DELAY = (0.8, 1.6)
DETAIL_DELAY = (0.5, 1.0)
BLOCK_SLEEP_SECONDS = 30

HOME_URL = "https://www.list.am/"
BROWSER_IMPERSONATE = "chrome124"

FIELDNAMES = [
    "id", "category_id", "date_posted_exact", "date_updated_exact",
    "seller_type", "title", "price_raw", "price_usd", "full_location",
    "district", "street", "area_sqm", "entrance", "street_line",
    "elevator", "furniture", "rental_type", "description", "url",
]


# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("daily_upsert_scraper.log", encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# LOCKING
# ---------------------------------------------------------------------------
@contextmanager
def single_run_lock(lock_path: Path):
    """Prevent two daily upsert jobs from writing the same CSV simultaneously."""
    acquired = False
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        acquired = True
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        yield
    except FileExistsError:
        raise RuntimeError(
            f"Lock file '{lock_path}' exists. Another scraper may be running. "
            "Stop it first, or delete the lock only after checking no scraper is active."
        )
    finally:
        if acquired and lock_path.exists():
            lock_path.unlink()


# ---------------------------------------------------------------------------
# HTTP SESSION
# ---------------------------------------------------------------------------
def apply_browser_headers(session: Any) -> None:
    """Use stable browser-like headers; do not rotate UA per request."""
    session.headers.update(
        {
            "Accept-Language": "hy-AM,hy;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Referer": HOME_URL,
        }
    )


def build_cloudscraper() -> cloudscraper.CloudScraper:
    """Fallback session if curl_cffi cannot pass warmup."""
    session = cloudscraper.create_scraper(
        browser={"browser": "chrome", "platform": "windows", "mobile": False}
    )
    apply_browser_headers(session)
    return session


def build_scraper(use_curl: bool = True) -> Any:
    """
    Build a session that can pass list.am's Cloudflare checks.

    Primary: curl_cffi with a Chrome TLS/browser fingerprint.
    Fallback: cloudscraper. Do not mount HTTPAdapter or rotate User-Agent.
    """
    if use_curl:
        session = curl_requests.Session(impersonate=BROWSER_IMPERSONATE)
        apply_browser_headers(session)
        return session

    return build_cloudscraper()


def is_blocked(response: object) -> bool:
    """Detect Cloudflare/rate-limit pages, including 200 challenge pages."""
    status_code = getattr(response, "status_code", None)
    text = (getattr(response, "text", "") or "")[:4000].lower()
    return status_code in {403, 429, 503} or any(
        marker in text
        for marker in (
            "just a moment",
            "challenge-platform",
            "cf-browser-verification",
            "turnstile",
            "attention required",
        )
    )


def warm_up_session(scraper: Any) -> Any:
    """Open homepage once before category/detail requests."""
    resp = scraper.get(HOME_URL, timeout=TIMEOUT)
    if is_blocked(resp):
        log.warning("Cloudflare block during homepage warmup: HTTP %s", resp.status_code)
    else:
        log.info("Session warmed up: HTTP %s", resp.status_code)
    return scraper


def fetch_page(scraper: Any, url: str) -> tuple[Any, object]:
    """GET with retries and session rebuild on anti-bot blocks."""
    last_response: object | None = None

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = scraper.get(url, timeout=TIMEOUT)
            last_response = response
        except Exception as exc:
            log.warning("Network error for %s (attempt %d/%d): %s", url, attempt, MAX_RETRIES, exc)
            time.sleep(min(10 * attempt, 30))
            continue

        if not is_blocked(response):
            return scraper, response

        log.warning(
            "Blocked/rate-limited on %s: HTTP %s (attempt %d/%d)",
            url,
            response.status_code,
            attempt,
            MAX_RETRIES,
        )
        time.sleep(BLOCK_SLEEP_SECONDS)
        scraper = warm_up_session(build_scraper())

    if last_response is None:
        raise RuntimeError(f"Could not fetch {url}")
    return scraper, last_response


# ---------------------------------------------------------------------------
# PARSING HELPERS
# ---------------------------------------------------------------------------
def clean_price_to_usd(price_text: str, exchange_rate: int = AMD_TO_USD) -> Optional[int]:
    """Parse AMD/USD card text into integer USD."""
    if not price_text:
        return None
    normalized = price_text.replace(",", "").replace(" ", "")
    match = re.search(r"\d+", normalized)
    if not match:
        return None
    value = int(match.group())
    return round(value / exchange_rate) if "֏" in normalized else value


def parse_date_field(keyword: str, text: str) -> str:
    """Extract list.am Armenian date labels into ISO-like strings."""
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
        day, month, year = raw_date.split(".")
        base = f"{year}-{month}-{day}"

    return f"{base} {raw_time}".strip()


def extract_regex_field(pattern: str, text: str, group: int = 1) -> str:
    """Return a regex capture group or empty string."""
    match = re.search(pattern, text, re.IGNORECASE)
    return match.group(group).strip() if match else ""


def parse_listing_cards(soup: BeautifulSoup) -> list[dict]:
    """Extract only card-level fields. This is the cheap scan step."""
    cards: list[dict] = []

    for item in soup.find_all("a", href=re.compile(r"^/item/")):
        href = item.get("href", "")
        item_id = href.split("?")[0].replace("/item/", "").strip()
        if not item_id:
            continue

        title_elem = item.find("div", class_="l")
        price_elem = item.find("div", class_="p")
        location_elem = item.find("div", class_="at")
        if not (title_elem and price_elem):
            continue

        title = title_elem.get_text(strip=True)
        price_raw = price_elem.get_text(strip=True)
        full_location = location_elem.get_text(strip=True) if location_elem else ""

        loc_parts = [part.strip() for part in full_location.split(",")]
        district = loc_parts[0] if loc_parts else ""
        street = loc_parts[1] if len(loc_parts) > 1 and "քմ" not in loc_parts[1] else ""

        cards.append(
            {
                "id": item_id,
                "title": title,
                "price_raw": price_raw,
                "price_usd": clean_price_to_usd(price_raw),
                "full_location": full_location,
                "district": district,
                "street": street,
            }
        )

    return cards


def parse_detail_page(scraper: Any, item_url: str) -> tuple[dict, Any]:
    """Deep scrape one detail page only when upsert logic requires it."""
    defaults = {
        "date_posted_exact": "",
        "date_updated_exact": "",
        "seller_type": "Սեփականատեր",
        "area_sqm": "",
        "entrance": "",
        "street_line": "",
        "elevator": "",
        "furniture": "",
        "rental_type": "",
        "description": "",
    }

    time.sleep(random.uniform(*DETAIL_DELAY))
    scraper, response = fetch_page(scraper, item_url)

    if is_blocked(response) or response.status_code != 200:
        log.warning("Detail request failed for %s: HTTP %s", item_url, response.status_code)
        return defaults, scraper

    soup = BeautifulSoup(response.text, "html.parser")
    desc_elem = soup.find("div", itemprop="description")
    description = desc_elem.get_text(" ", strip=True).replace("\n", " | ") if desc_elem else ""

    for tag in soup.find_all(class_="disabled"):
        tag.decompose()

    text = soup.get_text(" ", strip=True)
    text = re.sub(r"\s+", " ", text)

    area_raw = extract_regex_field(r"Մակերես\s*([\d.,]+)", text)
    seller_type = "Գործակալություն" if "Գործակալություն" in text and "Սեփականատեր" not in text else "Սեփականատեր"
    elevator = "Այո" if re.search(r"Վերելակ\s*Առկա է", text, re.IGNORECASE) else ""

    return {
        "date_posted_exact": parse_date_field("Տեղադրված է", text),
        "date_updated_exact": parse_date_field("Թարմացվել է", text),
        "seller_type": seller_type,
        "area_sqm": area_raw.replace(",", ".") if area_raw else "",
        "entrance": extract_regex_field(
            r"Մուտք\s*(Փողոցից|Բակից|Շքամուտքից|Անհատական|Համատեղ)", text
        ),
        "street_line": extract_regex_field(
            r"Գտնվելու վայրը\s*(Առաջին գիծ|Երկրորդ գիծ)", text
        ),
        "elevator": elevator,
        "furniture": extract_regex_field(
            r"Կահույք\s*(Կահույքով|Առկա չէ|Մասնակի|Համաձայնությամբ)", text
        ),
        "rental_type": extract_regex_field(
            r"Վարձակալության տեսակ\s*([Ա-Ֆա-ֆ\w]+)", text
        ),
        "description": description,
    }, scraper


# ---------------------------------------------------------------------------
# PANDAS DATABASE HELPERS
# ---------------------------------------------------------------------------
def load_database(path: Path) -> pd.DataFrame:
    """Load CSV as strings, enforce schema, deduplicate by id."""
    if not path.exists():
        return pd.DataFrame(columns=FIELDNAMES)

    df = pd.read_csv(path, dtype=str, encoding="utf-8-sig").fillna("")

    for column in FIELDNAMES:
        if column not in df.columns:
            df[column] = ""

    df = df[FIELDNAMES].copy()
    df = df[df["id"].astype(str).str.strip().ne("")]
    df = df[df["category_id"].astype(str).isin({"1408", "1401", "1410"})]
    df = df.drop_duplicates(subset=["id"], keep="last").reset_index(drop=True)
    df["price_usd"] = pd.to_numeric(df["price_usd"], errors="coerce")
    return df


def prices_equal(card_price: Optional[int], db_price: object) -> bool:
    """Compare card price against database price with null safety."""
    if card_price is None and pd.isna(db_price):
        return True
    if card_price is None or pd.isna(db_price):
        return False
    return float(card_price) == float(db_price)


def build_row(card: dict, detail: dict, category_id: int) -> dict:
    """Merge card + detail fields into the database schema."""
    row = {
        "id": card["id"],
        "category_id": str(category_id),
        "url": f"https://www.list.am/item/{card['id']}",
        **card,
        **detail,
    }
    return {column: row.get(column, "") for column in FIELDNAMES}


def atomic_write_database(df: pd.DataFrame, output_path: Path) -> None:
    """Backup current file, write temp CSV, then atomically replace the database."""
    if output_path.exists():
        shutil.copy2(output_path, BACKUP_CSV)

    df = df[FIELDNAMES].copy()
    df.to_csv(
        TEMP_CSV,
        index=False,
        encoding="utf-8-sig",
        quoting=csv.QUOTE_MINIMAL,
    )
    os.replace(TEMP_CSV, output_path)


# ---------------------------------------------------------------------------
# UPSERT LOOP
# ---------------------------------------------------------------------------
def run_daily_upsert() -> None:
    df = load_database(DATABASE_CSV)
    df_by_id = {str(row["id"]): idx for idx, row in df.iterrows()}

    scraper = warm_up_session(build_scraper())
    scanned_ids: set[str] = set()

    inserted = 0
    updated = 0
    skipped = 0
    deep_requests = 0
    category_pages_scanned = 0

    log.info("Loaded %d existing unique listings from %s", len(df), DATABASE_CSV)

    for category_id in CATEGORIES:
        log.info("=== Category %d: scanning first %d pages ===", category_id, MAX_DEPTH_PAGES)

        for page in range(1, MAX_DEPTH_PAGES + 1):
            url = f"https://www.list.am/category/{category_id}/{page}{YEREVAN_PARAMS}"
            log.info("Scanning category %d page %d", category_id, page)

            time.sleep(random.uniform(*REQUEST_DELAY))
            scraper, response = fetch_page(scraper, url)

            if is_blocked(response) or response.status_code != 200:
                log.warning("Skipping category %d page %d: HTTP %s", category_id, page, response.status_code)
                continue

            soup = BeautifulSoup(response.text, "html.parser")
            cards = parse_listing_cards(soup)
            category_pages_scanned += 1

            if not cards:
                log.info("No cards found for category %d page %d; moving to next category", category_id, page)
                break

            for card in cards:
                item_id = str(card["id"])
                if item_id in scanned_ids:
                    continue
                scanned_ids.add(item_id)

                existing_idx = df_by_id.get(item_id)
                card_price = card.get("price_usd")

                if existing_idx is not None:
                    db_price = df.at[existing_idx, "price_usd"]
                    if prices_equal(card_price, db_price):
                        skipped += 1
                        log.info("SKIP %s: unchanged price %s", item_id, card_price)
                        continue

                    log.info("UPDATE %s: price changed %s -> %s", item_id, db_price, card_price)
                    detail, scraper = parse_detail_page(scraper, f"https://www.list.am/item/{item_id}")
                    deep_requests += 1
                    row = build_row(card, detail, category_id)

                    for column, value in row.items():
                        df.at[existing_idx, column] = value
                    updated += 1
                    continue

                log.info("INSERT %s: new listing", item_id)
                detail, scraper = parse_detail_page(scraper, f"https://www.list.am/item/{item_id}")
                deep_requests += 1
                row = build_row(card, detail, category_id)

                df.loc[len(df)] = row
                df_by_id[item_id] = len(df) - 1
                inserted += 1

    df["price_usd"] = pd.to_numeric(df["price_usd"], errors="coerce")
    atomic_write_database(df, DATABASE_CSV)

    log.info(
        "Daily upsert complete: inserted=%d, updated=%d, skipped=%d, "
        "deep_requests=%d, pages_scanned=%d, final_rows=%d",
        inserted,
        updated,
        skipped,
        deep_requests,
        category_pages_scanned,
        len(df),
    )
    log.info("Database overwritten safely: %s (backup: %s)", DATABASE_CSV, BACKUP_CSV)


def main() -> None:
    with single_run_lock(LOCK_FILE):
        run_daily_upsert()


if __name__ == "__main__":
    main()

"""Remove jobs that are 'No longer accepting applications' from both CSVs.

Visits each Job_URL with Playwright and checks the detail page body for
LinkedIn closed-job phrases. URLs that are clearly closed are removed
from `data1/fct_job_listing.csv` and `linkedin_dashboard_jobs_combined.csv`,
and recorded in `data/processed/closed_jobs_pruned.csv` for audit.

Usage (from project root):
    python src/prune_closed_jobs.py --dry-run                # preview only (default)
    python src/prune_closed_jobs.py --apply                  # actually delete
    python src/prune_closed_jobs.py --apply --limit 50       # process first 50 URLs
    python src/prune_closed_jobs.py --apply --market Spain   # only one market
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import logging
from datetime import datetime, timezone
from pathlib import Path

from playwright.async_api import Browser, Page, async_playwright

ROOT = Path(__file__).resolve().parent.parent
FCT_CSV = ROOT / "data1" / "fct_job_listing.csv"
COMBINED_CSV = ROOT / "linkedin_dashboard_jobs_combined.csv"
AUDIT_CSV = ROOT / "data" / "processed" / "closed_jobs_pruned.csv"
SCAN_LOG = ROOT / "data" / "processed" / "closed_jobs_scan.csv"

# Same phrases the scraper uses (`daily_refresh_claudevers._CLOSED_PHRASES`).
_CLOSED_PHRASES = (
    "no longer accepting applications",
    "this job is no longer accepting",
    "job is no longer available",
    # Spanish equivalents seen on es.linkedin.com pages
    "ya no acepta solicitudes",
    "esta oferta ya no acepta",
)

_BLOCK_URL_SIGNALS = ("authwall", "/login", "checkpoint", "captcha")

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("prune_closed")


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
        log.warning("No rows to write for %s — skipping.", path.name)
        return
    quoting = csv.QUOTE_NONNUMERIC if quote_nonnumeric else csv.QUOTE_MINIMAL
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys(), quoting=quoting)
        w.writeheader()
        w.writerows(rows)


async def _is_closed(page: Page, url: str) -> bool | None:
    """
    True  → page clearly states the job is closed (banner or expired redirect)
    False → page loaded as a normal job detail page, no closed phrase
    None  → could not determine (block, nav error, empty body) — keep the row

    LinkedIn closes a guest job page two ways:
      1) Banner on the detail page: "No longer accepting applications".
      2) Redirect away from /jobs/view/<id> to /jobs/<keyword>-empleos
         with `trk=expired_jd_redirect` in the query string.
    """
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=25_000)
    except Exception as exc:
        log.warning("  nav error: %s", exc)
        return None

    final_url = (page.url or "").lower()
    if any(sig in final_url for sig in _BLOCK_URL_SIGNALS):
        return None

    # Strongest signal: LinkedIn tagged the redirect itself as expired.
    if "trk=expired_jd_redirect" in final_url:
        return True
    # Redirected off the job detail entirely (jobs/<keyword>-empleos, /jobs/search, …)
    if "/jobs/view/" not in final_url:
        return True

    await page.wait_for_timeout(1_500)
    try:
        body = await page.inner_text("body")
    except Exception:
        return None
    if not body or len(body.strip()) < 400:
        return None
    head = body[:8000].lower()
    return any(p in head for p in _CLOSED_PHRASES)


async def scan_and_prune(
    *,
    market_filter: str | None,
    limit: int | None,
    apply: bool,
) -> int:
    fct_rows = _load_csv(FCT_CSV)
    combined_rows = _load_csv(COMBINED_CSV)
    if not fct_rows:
        log.error("No rows in %s", FCT_CSV)
        return 1

    candidates = fct_rows
    if market_filter:
        candidates = [r for r in candidates if (r.get("market") or "").strip() == market_filter]
    if limit:
        candidates = candidates[:limit]

    log.info(
        "Scanning %d job(s) for closed-job phrases (market_filter=%s, limit=%s)…",
        len(candidates),
        market_filter or "ALL",
        limit or "ALL",
    )

    scan_rows: list[dict[str, str]] = []
    remove_urls: set[str] = set()

    async with async_playwright() as p:
        browser: Browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        for i, row in enumerate(candidates, 1):
            url = (row.get("job_url") or "").strip()
            if not url:
                continue

            closed = await _is_closed(page, url)
            verdict = "closed" if closed is True else ("open" if closed is False else "unknown")

            log.info(
                "[%d/%d] %s | %s | %s",
                i,
                len(candidates),
                (row.get("company_name") or "")[:28],
                verdict,
                (row.get("title") or "")[:50],
            )

            scan_rows.append(
                {
                    "linkedin_job_id": str(row.get("linkedin_job_id") or ""),
                    "market": row.get("market") or "",
                    "company_name": row.get("company_name") or "",
                    "title": row.get("title") or "",
                    "location_text": row.get("location_text") or "",
                    "verdict": verdict,
                    "action": "remove" if closed is True else "keep",
                    "job_url": url,
                }
            )
            if closed is True:
                remove_urls.add(url)

        await browser.close()

    SCAN_LOG.parent.mkdir(parents=True, exist_ok=True)
    _write_csv(SCAN_LOG, scan_rows, quote_nonnumeric=True)
    log.info("Scan log: %s", SCAN_LOG)
    log.info("Would remove %d / %d job(s)", len(remove_urls), len(candidates))

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
        "company_name",
        "title",
        "location_text",
        "job_url",
    ]
    need_header = not AUDIT_CSV.exists() or AUDIT_CSV.stat().st_size == 0
    with AUDIT_CSV.open("a", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=audit_fields, quoting=csv.QUOTE_NONNUMERIC)
        if need_header:
            w.writeheader()
        for s in scan_rows:
            if s["action"] != "remove":
                continue
            w.writerow(
                {
                    "removed_at": removed_at,
                    "exclusion_reason": "Closed: no longer accepting applications",
                    "linkedin_job_id": s["linkedin_job_id"],
                    "market": s["market"],
                    "company_name": s["company_name"],
                    "title": s["title"],
                    "location_text": s["location_text"],
                    "job_url": s["job_url"],
                }
            )

    log.info("Removal audit: %s", AUDIT_CSV)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Remove closed LinkedIn jobs from both CSVs.")
    ap.add_argument("--dry-run", action="store_true", help="Preview only (default).")
    ap.add_argument("--apply", action="store_true", help="Delete closed jobs from both CSVs.")
    ap.add_argument("--market", type=str, default=None, help="Restrict scan to one market (e.g. Spain).")
    ap.add_argument("--limit", type=int, default=None, help="Scan only the first N rows.")
    args = ap.parse_args()

    if args.apply and args.dry_run:
        log.error("Use either --dry-run or --apply, not both.")
        return 1

    return asyncio.run(
        scan_and_prune(
            market_filter=args.market,
            limit=args.limit,
            apply=args.apply,
        )
    )


if __name__ == "__main__":
    raise SystemExit(main())

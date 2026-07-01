"""Build dimensional fact CSV from linkedin_dashboard_jobs_combined.csv.

Grain: one row per Job_URL (latest Scraped_At wins).

Input:  PROJECT_ROOT / linkedin_dashboard_jobs_combined.csv
Output: PROJECT_ROOT / data1 / fct_job_listing.csv

Run from project root:
    python src/build_fct_job_listing.py
"""

from __future__ import annotations

import csv
import hashlib
import logging
import re
import sys
from pathlib import Path
from typing import cast

import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("build_fct")

ROOT = Path(__file__).resolve().parent.parent
COMBINED_CSV = ROOT / "linkedin_dashboard_jobs_combined.csv"
FCT_OUTPUT = ROOT / "data1" / "fct_job_listing.csv"

_RE_JOB_ID = re.compile(r"-(\d+)/?(?:\?.*)?$")


def fct_surrogate_key(job_url: object) -> str:
    """Stable 16-char hex surrogate from canonical URL."""
    url = job_url.strip() if isinstance(job_url, str) else ""
    return hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]


def linkedin_numeric_id(job_url: object) -> int | None:
    if not isinstance(job_url, str):
        return None
    m = _RE_JOB_ID.search(job_url.strip())
    return int(m.group(1)) if m else None


def _to_date_key(series: pd.Series) -> pd.Series:
    """YYYYMMDD string; blank if unparsable."""
    dt = pd.to_datetime(series, errors="coerce")
    out = dt.dt.strftime("%Y%m%d").where(dt.notna(), "")
    return out.astype(str)


def build_fct(
    *,
    combined_path: Path = COMBINED_CSV,
) -> pd.DataFrame:
    if not combined_path.exists():
        log.error("Input not found: %s", combined_path)
        return pd.DataFrame()

    raw = pd.read_csv(combined_path, encoding="utf-8-sig")
    col_map = {
        "Title": "title",
        "Company": "company_name",
        "Location": "location_text",
        "Market": "market",
        "Work_Type": "work_type",
        "Search_Keyword": "search_keyword",
        "Experience_Level": "experience_level",
        "Original_Salary": "original_salary_text",
        "Salary_in_USD": "salary_in_usd_raw",
        "Job_URL": "job_url",
        "Posted_Date": "posted_date",
        "Scraped_At": "scraped_at",
    }
    df = raw.rename(columns={k: v for k, v in col_map.items() if k in raw.columns})

    if "job_url" not in df.columns:
        log.error("Column Job_URL missing in %s", combined_path.name)
        return pd.DataFrame()

    df["_scraped_ts"] = pd.to_datetime(df["scraped_at"], errors="coerce")
    df = df.sort_values("_scraped_ts", ascending=False).drop_duplicates(
        subset=["job_url"], keep="first"
    )

    if "salary_in_usd_raw" in df.columns:
        salary_num = cast(
            pd.Series,
            pd.to_numeric(df["salary_in_usd_raw"], errors="coerce"),
        )
    else:
        salary_num = pd.Series([float("nan")] * len(df), index=df.index, dtype=float)

    scrape_ts = cast(pd.Series, pd.to_datetime(df["scraped_at"], errors="coerce"))
    scrape_day = cast(pd.Series, scrape_ts.dt.normalize())

    def col_str(name: str) -> pd.Series:
        if name not in df.columns:
            return pd.Series([""] * len(df), index=df.index, dtype=str)
        return cast(pd.Series, df[name]).fillna("").astype(str)

    work_type = col_str("work_type").str.strip()
    original_salary = col_str("original_salary_text")

    out = pd.DataFrame(
        {
            "fct_job_listing_key": df["job_url"].map(fct_surrogate_key),
            "linkedin_job_id": pd.array(
                [linkedin_numeric_id(u) for u in df["job_url"].tolist()],
                dtype="Int64",
            ),
            "date_key_posted": _to_date_key(cast(pd.Series, df["posted_date"]))
            if "posted_date" in df.columns
            else pd.Series([""] * len(df), index=df.index, dtype=str),
            "date_key_scrape": _to_date_key(scrape_day),
            "market": col_str("market"),
            "search_keyword": col_str("search_keyword"),
            "experience_level": col_str("experience_level"),
            "company_name": col_str("company_name"),
            "title": col_str("title"),
            "location_text": col_str("location_text"),
            "work_type": work_type,
            "has_salary_usd": (salary_num.notna() & (salary_num > 0)).astype(int),
            "salary_amount_usd": salary_num,
            "original_salary_text": original_salary,
            "job_url": df["job_url"].astype(str),
            "scraped_at": cast(
                pd.Series,
                scrape_ts.dt.strftime("%Y-%m-%d %H:%M:%S").where(scrape_ts.notna(), ""),
            ),
        }
    )

    col_order = [
        "fct_job_listing_key",
        "linkedin_job_id",
        "date_key_posted",
        "date_key_scrape",
        "market",
        "search_keyword",
        "experience_level",
        "company_name",
        "title",
        "location_text",
        "work_type",
        "has_salary_usd",
        "salary_amount_usd",
        "original_salary_text",
        "scraped_at",
        "job_url",  # last column: Excel hyperlinks stay clean when URL is final field
    ]
    return cast(pd.DataFrame, out[col_order])


def main() -> int:
    fct = build_fct()
    if fct.empty:
        return 1
    FCT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fct.to_csv(
        FCT_OUTPUT,
        index=False,
        encoding="utf-8-sig",
        quoting=csv.QUOTE_NONNUMERIC,
    )
    log.info("Wrote %d rows → %s", len(fct), FCT_OUTPUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())

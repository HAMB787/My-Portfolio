"""
Build a BI-ready fact table from scraped list.am commercial real estate data.

Scope:
- pandas + regex only
- no ML / NLP models
- rule-based cleaning and feature engineering

Input:
    Yerevan_CommercialRent_DATABASE.csv

Output:
    Fact_CommercialRealEstate.csv
"""

from __future__ import annotations

import re
from pathlib import Path

import pandas as pd


RAW_CSV = Path("Yerevan_CommercialRent_DATABASE.csv")
OUTPUT_CSV = Path("Fact_CommercialRealEstate.csv")

TEXT_DEFAULT = "N/A"

# Yerevan district names commonly seen on list.am.
# Keep this dictionary explicit: it is fast, transparent, and easy to maintain.
DISTRICT_PATTERNS: dict[str, str] = {
    "Կենտրոն": r"կենտրոն(?:ում)?",
    "Արաբկիր": r"արաբկիր(?:ում)?",
    "Աջափնյակ": r"աջափնյակ(?:ում)?",
    "Ավան": r"ավան(?:ում)?",
    "Դավթաշեն": r"դավթաշեն(?:ում)?",
    "Էրեբունի": r"էրեբունի(?:ում)?",
    "Քանաքեռ-Զեյթուն": r"քանաքեռ[-\s]?զեյթուն(?:ում)?",
    "Մալաթիա-Սեբաստիա": r"մալաթիա[-\s]?սեբաստիա(?:յում)?",
    "Նոր Նորք": r"նոր\s+նորք(?:ում)?",
    "Նորք-Մարաշ": r"նորք[-\s]?մարաշ(?:ում)?",
    "Նուբարաշեն": r"նուբարաշեն(?:ում)?",
    "Շենգավիթ": r"շենգավիթ(?:ում)?",
}

BUSINESS_TYPE_PATTERNS: dict[str, list[str]] = {
    "Cosmetology / Aesthetics": [
        r"կոսմետոլոգ",
        r"էսթետիկ",
        r"մազահեռացում",
        r"լազերային",
        r"դիմահարդար",
    ],
    "Hair Salon / Barbershop": [
        r"վարսավիր",
        r"գեղեցկության\s+սրահ",
        r"բարբեր",
    ],
    "Manicure / Pedicure": [
        r"մատնահարդար",
        r"պեդիկյուր",
        r"նեյլ",
        r"մանիկյուր",
    ],
    "Medical / Dental": [
        r"ատամնաբուժ",
        r"ստոմատոլոգ",
        r"բժշկական",
        r"կլինիկա",
        r"դեղատուն",
    ],
    "SPA / Massage": [
        r"սպա",
        r"մերսում",
        r"\bspa\b",
        r"массаж",
    ],
    "Office / Workspace": [
        r"գրասենյակ",
        r"օֆիս",
        r"\bit\b",
        r"աշխատասենյակ",
    ],
    "Food / Restaurant": [
        r"ռեստորան",
        r"սրճարան",
        r"խոհանոց",
        r"արագ\s+սնունդ",
        r"\bfood\b",
    ],
    "Retail / Store": [
        r"խանութ",
        r"առևտրային",
        r"շոուրում",
    ],
}

STREET_LINE_PATTERNS: dict[str, list[str]] = {
    "Առաջին գիծ": [
        r"առաջին\s+գիծ",
        r"1[-\s]*(?:ին|ին)?\s+գիծ",
        r"1\s*գիծ",
        r"առաջնագիծ",
        r"փողոցի\s+առաջին\s+գիծ",
        r"first\s+line",
        r"первая\s+линия",
        r"первой\s+линии",
    ],
    "Երկրորդ գիծ": [
        r"երկրորդ\s+գիծ",
        r"2[-\s]*(?:րդ|րդ)?\s+գիծ",
        r"2\s*գիծ",
        r"second\s+line",
        r"вторая\s+линия",
        r"второй\s+линии",
    ],
}


def normalize_text(value: object) -> str:
    """Convert nulls to empty text and remove unusual line terminators."""
    if pd.isna(value):
        return ""
    text = str(value)
    text = text.replace("\u2028", " ").replace("\u2029", " ")
    return re.sub(r"\s+", " ", text).strip()


def extract_area_sqm(*values: object) -> float | None:
    """
    Extract numeric area from fields like:
    - "15 քմ"
    - "15 ք/մ"
    - "15 քառակուսի"
    - "450 sqm"

    The first valid match wins, using field priority from the caller.
    """
    area_pattern = re.compile(
        r"(?<!\d)(\d+(?:[.,]\d+)?)\s*(?:քմ|ք/մ|ք\.մ|քառակուսի|sqm|sq\.?\s*m)",
        flags=re.IGNORECASE,
    )

    for value in values:
        text = normalize_text(value)
        if not text:
            continue
        match = area_pattern.search(text)
        if match:
            return float(match.group(1).replace(",", "."))

    return None


def is_area_like(value: object) -> bool:
    """Detect bad district values such as '15 քմ'."""
    return extract_area_sqm(value) is not None


def extract_district_from_text(*values: object) -> str:
    """Find a known Yerevan district in full_location, title, or current district."""
    for value in values:
        text = normalize_text(value).lower()
        if not text:
            continue
        for district, pattern in DISTRICT_PATTERNS.items():
            if re.search(pattern, text, flags=re.IGNORECASE):
                return district
    return TEXT_DEFAULT


def clean_district(row: pd.Series) -> str:
    """
    Return a district name only.

    Priority:
    1. Existing district if it is not an area value.
    2. First part of full_location if it is a known district.
    3. Known district found in full_location/title text.
    """
    current = normalize_text(row.get("district", ""))
    full_location = normalize_text(row.get("full_location", ""))
    title = normalize_text(row.get("title", ""))

    if current and not is_area_like(current):
        found = extract_district_from_text(current)
        if found != TEXT_DEFAULT:
            return found

    if full_location:
        first_part = full_location.split(",")[0].strip()
        found = extract_district_from_text(first_part)
        if found != TEXT_DEFAULT:
            return found

    return extract_district_from_text(full_location, title, current)


def infer_business_type(row: pd.Series) -> str:
    """
    Infer target usage from title + description with transparent regex rules.
    Multiple matches are joined so BI users can filter multi-use properties.
    """
    search_text = " ".join(
        [
            normalize_text(row.get("title", "")),
            normalize_text(row.get("description", "")),
        ]
    ).lower()

    matches: list[str] = []
    for business_type, patterns in BUSINESS_TYPE_PATTERNS.items():
        if any(re.search(pattern, search_text, flags=re.IGNORECASE) for pattern in patterns):
            matches.append(business_type)

    return ", ".join(matches) if matches else "General Commercial"


def infer_street_line(row: pd.Series) -> str:
    """
    Infer street-line position from existing field, title, full_location, and description.

    Rule:
    - If source already has a valid street_line value, keep it.
    - Else search text with Armenian/Russian/English regex patterns.
    """
    current = normalize_text(row.get("street_line", ""))
    if current and current != TEXT_DEFAULT:
        if re.search(r"առաջին|first|пер", current, flags=re.IGNORECASE):
            return "Առաջին գիծ"
        if re.search(r"երկրորդ|second|втор", current, flags=re.IGNORECASE):
            return "Երկրորդ գիծ"

    search_text = " ".join(
        [
            normalize_text(row.get("title", "")),
            normalize_text(row.get("full_location", "")),
            normalize_text(row.get("description", "")),
        ]
    ).lower()

    for street_line, patterns in STREET_LINE_PATTERNS.items():
        if any(re.search(pattern, search_text, flags=re.IGNORECASE) for pattern in patterns):
            return street_line

    return ""


def standardize_dates(df: pd.DataFrame) -> pd.DataFrame:
    """Convert date fields to BI-friendly datetimes."""
    for column in ["date_posted_exact", "date_updated_exact"]:
        df[column] = pd.to_datetime(df[column], errors="coerce")

    # Keep datetime dtype for analysis and also add date-only field for calendar joins.
    df["date_posted"] = df["date_posted_exact"].dt.date
    df["date_updated"] = df["date_updated_exact"].dt.date
    return df


def optimize_types(df: pd.DataFrame) -> pd.DataFrame:
    """Set numeric/text types suitable for BI import."""
    df["id"] = pd.to_numeric(df["id"], errors="coerce").astype("Int64")
    df["category_id"] = pd.to_numeric(df["category_id"], errors="coerce").astype("Int64")
    df["price_usd"] = pd.to_numeric(df["price_usd"], errors="coerce")
    df["area_sqm"] = pd.to_numeric(df["area_sqm"], errors="coerce")

    text_columns = df.select_dtypes(include=["object", "string"]).columns
    df[text_columns] = df[text_columns].fillna(TEXT_DEFAULT)
    df[text_columns] = df[text_columns].map(normalize_text)
    df[text_columns] = df[text_columns].replace("", TEXT_DEFAULT)
    return df


def build_fact_table(raw_path: Path = RAW_CSV, output_path: Path = OUTPUT_CSV) -> pd.DataFrame:
    """Load raw CSV, transform it, export the fact table, and return the dataframe."""
    df = pd.read_csv(raw_path, dtype=str, encoding="utf-8")

    # Remove broken scraped rows and duplicate listings before BI export.
    df = df[df["category_id"].isin(["1408", "1401", "1410"])].copy()
    df = df.drop_duplicates(subset=["id"], keep="last")

    # Clean raw text early so regex and BI tools see stable strings.
    for column in df.columns:
        df[column] = df[column].map(normalize_text)

    # Fix area/district anomalies.
    df["area_sqm"] = df.apply(
        lambda row: extract_area_sqm(
            row.get("area_sqm", ""),
            row.get("full_location", ""),
            row.get("title", ""),
            row.get("description", ""),
        ),
        axis=1,
    )
    df["district"] = df.apply(clean_district, axis=1)
    df["street_line"] = df.apply(infer_street_line, axis=1)

    # Business rule feature engineering.
    df["business_type"] = df.apply(infer_business_type, axis=1)

    df = standardize_dates(df)
    df = optimize_types(df)

    # Put BI-critical columns first; keep original columns for traceability.
    first_columns = [
        "id",
        "category_id",
        "date_posted_exact",
        "date_updated_exact",
        "date_posted",
        "date_updated",
        "district",
        "street",
        "area_sqm",
        "price_usd",
        "business_type",
        "seller_type",
        "title",
        "price_raw",
        "full_location",
        "entrance",
        "street_line",
        "elevator",
        "furniture",
        "rental_type",
        "description",
        "url",
    ]
    df = df[[column for column in first_columns if column in df.columns]]

    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    return df


def main() -> None:
    fact = build_fact_table()
    print(f"Exported {len(fact):,} clean listings to {OUTPUT_CSV}")
    print("Business type counts:")
    print(fact["business_type"].value_counts(dropna=False).head(20))


if __name__ == "__main__":
    main()

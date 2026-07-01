import csv
import os
import re
from decimal import Decimal, InvalidOperation


FILE_NAME = "Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv"

AREA_PATTERN = re.compile(r"(\d+(?:[.,]\d+)?)\s*քմ", re.IGNORECASE)
ADDRESS_TRIGGERS = ("շենքում", "բնակարան")


def normalize_number(value: str) -> str:
    if value is None:
        return ""

    cleaned = str(value).strip().replace(",", ".")
    if not cleaned:
        return ""

    try:
        number = Decimal(cleaned)
    except InvalidOperation:
        return cleaned

    normalized = format(number.normalize(), "f")
    if "." in normalized:
        normalized = normalized.rstrip("0").rstrip(".")
    return normalized


def extract_area(title: str) -> str:
    if not title:
        return ""

    match = AREA_PATTERN.search(title)
    if not match:
        return ""

    return normalize_number(match.group(1))


def extract_address(title: str) -> str:
    if not title:
        return ""

    area_match = AREA_PATTERN.search(title)
    if not area_match:
        return ""

    before_area = title[: area_match.start()].rstrip(" ,")
    best_start = -1
    best_trigger = ""

    for trigger in ADDRESS_TRIGGERS:
        idx = before_area.rfind(trigger)
        if idx > best_start:
            best_start = idx
            best_trigger = trigger

    if best_start >= 0:
        address = before_area[best_start + len(best_trigger) :].strip(" ,")
    else:
        address = before_area.strip(" ,")

    return re.sub(r"\s+", " ", address)


def clean_csv_in_place(file_name: str) -> None:
    if not os.path.isfile(file_name):
        raise FileNotFoundError(f"CSV file not found: {file_name}")

    with open(file_name, "r", encoding="utf-8", newline="") as source_file:
        reader = csv.DictReader(source_file)
        fieldnames = list(reader.fieldnames or [])

        if not fieldnames:
            raise ValueError("CSV file is missing a header row.")
        if "title" not in fieldnames:
            raise ValueError("CSV file does not contain a 'title' column.")
        if "area_sqm" not in fieldnames:
            raise ValueError("CSV file does not contain an 'area_sqm' column.")

        if "address" not in fieldnames:
            fieldnames.append("address")

        rows = []
        stats = {
            "rows_total": 0,
            "area_updated": 0,
            "address_filled": 0,
            "area_not_matched": 0,
            "address_not_matched": 0,
            "row_errors": 0,
        }

        for row_number, row in enumerate(reader, start=2):
            stats["rows_total"] += 1

            try:
                title = (row.get("title") or "").strip()
                extracted_area = extract_area(title)
                extracted_address = extract_address(title)

                current_area = normalize_number(row.get("area_sqm", ""))
                if extracted_area:
                    if current_area != extracted_area:
                        row["area_sqm"] = extracted_area
                        stats["area_updated"] += 1
                else:
                    stats["area_not_matched"] += 1

                row["address"] = extracted_address
                if extracted_address:
                    stats["address_filled"] += 1
                else:
                    stats["address_not_matched"] += 1

                rows.append(row)
            except Exception as exc:
                stats["row_errors"] += 1
                print(f"Row {row_number}: failed to parse title. Error: {exc}")
                row.setdefault("address", "")
                rows.append(row)

    with open(file_name, "w", encoding="utf-8", newline="") as target_file:
        writer = csv.DictWriter(target_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Updated file in place: {file_name}")
    print(f"Rows processed: {stats['rows_total']}")
    print(f"area_sqm updated: {stats['area_updated']}")
    print(f"address filled: {stats['address_filled']}")
    print(f"Titles without area match: {stats['area_not_matched']}")
    print(f"Titles without address match: {stats['address_not_matched']}")
    print(f"Row-level errors: {stats['row_errors']}")


if __name__ == "__main__":
    clean_csv_in_place(FILE_NAME)

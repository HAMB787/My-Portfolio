import csv
import sys
from pathlib import Path

import clickhouse_connect


def get_client():
    return clickhouse_connect.get_client(
        host="localhost",
        port=8123,
        username="default",
        password="my_password",
    )


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    client = get_client()
    query = """
        SELECT
            date_posted_exact,
            tags,
            seller_type
        FROM listam_real_estate
        ORDER BY date_posted_exact DESC
        LIMIT 100
    """

    rows = client.query(query).result_rows

    print("date_posted_exact,tags,seller_type")
    for row in rows:
        print(",".join(f'"{str(value)}"' for value in row))

    output_path = Path(__file__).resolve().parent.parent / "csv files" / "ch_selected_fields.csv"
    with output_path.open("w", newline="", encoding="utf-8-sig") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["date_posted_exact", "tags", "seller_type"])
        writer.writerows(rows)

    print(f"\nSaved: {output_path}")


if __name__ == "__main__":
    main()

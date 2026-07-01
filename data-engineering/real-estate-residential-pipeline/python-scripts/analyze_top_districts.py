import sys

from safe_query import run_safe_query


TOP_DISTRICTS_QUERY = """
SELECT
    district,
    round(avg(price_usd), 2) AS avg_price_usd,
    count() AS listing_count
FROM default.clean_listam_data
WHERE district IS NOT NULL
  AND district != ''
  AND price_usd IS NOT NULL
  AND price_usd > 0
GROUP BY district
ORDER BY avg_price_usd DESC
LIMIT 5
"""


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    result = run_safe_query(TOP_DISTRICTS_QUERY)

    if isinstance(result, str):
        print(result)
        return

    if result.empty:
        print("No district data found in default.clean_listam_data.")
        return

    print("Top 5 most expensive Yerevan districts by average price_usd:")
    print(result.to_string(index=False))


if __name__ == "__main__":
    main()

import sys

from safe_query import run_safe_query


ANOMALIES_QUERY = """
WITH base_data AS (
    SELECT
        id,
        title,
        district,
        price_usd,
        toFloat64OrNull(area_sqm) AS area_sqm_value
    FROM default.clean_listam_data
    WHERE district IS NOT NULL
      AND district != ''
      AND price_usd IS NOT NULL
      AND price_usd > 0
      AND toFloat64OrNull(area_sqm) IS NOT NULL
      AND toFloat64OrNull(area_sqm) > 0
),
district_averages AS (
    SELECT
        district,
        avg(price_usd / area_sqm_value) AS avg_price_per_sqm
    FROM base_data
    GROUP BY district
)
SELECT DISTINCT
    b.id,
    b.title,
    b.district,
    b.price_usd,
    b.area_sqm_value AS area_sqm,
    round(b.price_usd / b.area_sqm_value, 2) AS listing_price_per_sqm,
    round(d.avg_price_per_sqm, 2) AS district_avg_price_per_sqm,
    round((1 - ((b.price_usd / b.area_sqm_value) / d.avg_price_per_sqm)) * 100, 2) AS discount_vs_district_pct
FROM base_data AS b
INNER JOIN district_averages AS d
    ON b.district = d.district
WHERE (b.price_usd / b.area_sqm_value) <= d.avg_price_per_sqm * 0.6
ORDER BY discount_vs_district_pct DESC, b.price_usd ASC
LIMIT 10
"""


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    result = run_safe_query(ANOMALIES_QUERY)

    if isinstance(result, str):
        print(result)
        return

    if result.empty:
        print("No suspiciously cheap apartments found in default.clean_listam_data.")
        return

    print("Top 10 suspiciously cheap apartments in Yerevan:")
    print(result.to_string(index=False))


if __name__ == "__main__":
    main()

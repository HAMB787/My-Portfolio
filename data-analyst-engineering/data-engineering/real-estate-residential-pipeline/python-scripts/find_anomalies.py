# -*- coding: utf-8 -*-
import sys
from pathlib import Path

# Add the parent directory to the system path to allow module imports
sys.path.append(str(Path(__file__).parent))

try:
    from safe_query import run_safe_query
except ImportError:
    print("Fatal Error: Could not import 'run_safe_query' from 'safe_query.py'.")
    print("Please ensure 'safe_query.py' exists in the 'python codes' directory.")
    sys.exit(1)

def find_suspiciously_cheap_apartments():
    """
    Finds top 10 'suspiciously cheap' apartments in Yerevan by comparing
    their price per square meter to the district average.
    """
    print("Searching for suspiciously cheap apartments in Yerevan...")

    # This query calculates the average price per square meter for each district,
    # then finds apartments in that district where the price per sq meter is at least
    # 40% lower than the average. It's designed to handle Armenian characters (UTF-8).
    query = """
    WITH DistrictAvg AS (
        -- Step 1: Calculate the average price/sq_m for each district in Yerevan.
        SELECT
            district,
            avg(price / NULLIF(sq_m, 0)) AS district_avg_price_per_sqm
        FROM
            default.clean_listam_data
        WHERE
            city = 'Yerevan' AND sq_m > 0 AND price > 1000 -- Basic filtering for valid entries
        GROUP BY
            district
        HAVING 
            district_avg_price_per_sqm IS NOT NULL
    )
    -- Step 2: Join the main table with the district averages.
    SELECT
        t.url,
        t.district,
        t.price,
        t.sq_m,
        round(t.price / t.sq_m, 2) AS price_per_sqm,
        round(da.district_avg_price_per_sqm, 2) AS district_avg_price_per_sqm,
        -- Calculate how much cheaper the apartment is as a percentage
        round(((da.district_avg_price_per_sqm - (t.price / t.sq_m)) / da.district_avg_price_per_sqm) * 100, 2) AS deviation_percentage
    FROM
        default.clean_listam_data AS t
    JOIN
        DistrictAvg AS da ON t.district = da.district
    WHERE
        t.city = 'Yerevan' AND sq_m > 0 AND price > 0
        -- Step 3: Filter for apartments that are at least 40% cheaper than the average.
        AND (t.price / t.sq_m) <= (da.district_avg_price_per_sqm * 0.6)
    ORDER BY
        deviation_percentage DESC
    LIMIT 10;
    """

    anomalies_df = run_safe_query(query)

    if not anomalies_df.empty:
        print("\n--- Top 10 'Suspiciously Cheap' Apartments Found ---")
        # Use to_string() for clean, aligned console output
        print(anomalies_df.to_string(index=False))
        print("\n----------------------------------------------------")
    else:
        print("No suspiciously cheap apartments found matching the criteria (>=40% cheaper than district average).")

if __name__ == "__main__":
    # The script is designed to be run directly from the command line.
    find_suspiciously_cheap_apartments()

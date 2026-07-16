# 🏢 Commercial Real Estate Pipeline

An automated data pipeline that scrapes commercial real estate listings from list.am, cleans the data into a BI-ready fact table, and serves an interactive Streamlit dashboard.

## 🛠️ Architecture & Tech Stack
- **Web Scraping:** Python, BeautifulSoup4 (Full scraping + Daily Incremental Upserts)
- **Data Transformation (ETL):** Pandas (Deduplication, price normalization, area extraction)
- **Visualization:** Streamlit

## 📂 Key Files
- `list_am_full_scraper.py`: Full historical data scraper.
- `daily_upsert_scraper.py`: Daily incremental scraper that detects new listings and updates price changes.
- `build_fact_commercial_real_estate.py`: The ETL script that transforms the raw database into a cleaned `Fact_CommercialRealEstate.csv`.
- `streamlit_dashboard.py`: Interactive analytical dashboard.

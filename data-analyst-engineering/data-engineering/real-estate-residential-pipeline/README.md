# 🏠 Residential Real Estate Pipeline

A comprehensive, production-ready data engineering pipeline for residential real estate data. It extracts data from list.am, cleans it, loads it into a high-performance ClickHouse database, and transforms it using dbt.

## 🛠️ Architecture & Tech Stack
- **Data Extraction:** Python Scrapers (`getdata.py`, `daily_refresh.py`)
- **Data Cleaning & Anomaly Detection:** Pandas (`clean_real_estate_csv.py`, `find_anomalies_root.py`)
- **Data Warehouse:** ClickHouse
- **Analytics Engineering:** dbt (Data Build Tool)
- **BI / Visualization:** Power BI

## 📂 Project Structure
- `python-scripts/`: Contains the extraction, cleaning, duplicate-checking, and database upload scripts.
- `dbt-models/`: The dbt project containing data models, tests, and macros.
- `bi-dashboard/`: The final Power BI dashboards (`listam_analysis.pbix`, `clickhouse_data.pbix`).

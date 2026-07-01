# ⚙️ Data Engineering Projects

This directory contains my core Data Engineering portfolio, showcasing end-to-end data pipelines, ETL processes, web scraping, and database management.

## 📂 Projects

### 1. [Commercial Real Estate Pipeline](./real-estate-commercial-pipeline/)
End-to-end pipeline scraping commercial real estate listings from list.am. Cleans data into a BI-ready fact table and serves it via a Streamlit dashboard.

### 2. [Residential Real Estate Pipeline](./real-estate-residential-pipeline/)
Robust residential real estate pipeline. Features a daily upsert scraper, data cleaning logic, uploading to a ClickHouse database, and dbt models for analytics.

### 3. [dbt Analytics Warehouse](./dbt-analytics-warehouse/)
A full dbt project modeling data across staging, marts, looker, and reporting layers. Demonstrates best practices in analytics engineering.

### 4. [LinkedIn Job Market Scraper](./linkedin-job-market-scraper/)
An advanced stealth scraper built with Playwright to extract and analyze job postings. Includes regex filtering, salary parsing, and a Streamlit analytics UI.

### 5. [Manufacturing ERP System](./manufacturing-erp-system/)
A full-stack ERP system built for manufacturing. Features a MySQL database with complex schemas (BOM, triggers), a FastAPI backend, and a Streamlit frontend.

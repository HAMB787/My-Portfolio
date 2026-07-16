# 💼 LinkedIn Job Market Scraper

An advanced, stealthy data extraction pipeline that scrapes LinkedIn job postings, applies strict regex filtering, normalizes salaries, and displays the data via a Streamlit dashboard.

## ✨ Key Features
- **Stealth Browsing:** Uses `playwright-stealth` to bypass automated bot detection mechanisms.
- **Smart Filtering:** Built-in regex gates (`POSITIVE_PATTERN`, `NEGATIVE_PATTERN`) to instantly reject irrelevant roles (e.g., rejecting "US only" or "Sales" roles).
- **Salary Parsing:** Automatically parses complex salary ranges and normalizes them into USD.
- **Deduplication:** Efficient disk-safe writers that deduplicate URLs on the fly to prevent scraping the same job twice.
- **Analytics UI:** A Streamlit app to explore the scraped job market data.

## 📂 Project Structure
- `scraping.py`: The core asynchronous Playwright scraper.
- `daily_refresh_claudevers.py`: The daily refresh script for updating the job list.
- `src/`: Core logic modules (accessibility checking, pruning closed jobs, etc.).
- `streamlit_app/`: The Streamlit dashboard application.

## 🛠️ Tech Stack
- **Python (asyncio)**
- **Playwright** & **Playwright Stealth**
- **Streamlit**

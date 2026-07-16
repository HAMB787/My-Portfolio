# 🏢 dbt Analytics Warehouse

A robust data transformation project using **dbt (Data Build Tool)**. It demonstrates analytics engineering best practices by organizing data into layered models.

## 🛠️ Architecture Layers
- **Staging:** Raw data cleaning and type casting. Built as views.
- **Marts:** Business-level entities and facts. Built as tables.
- **Looker Views:** Pre-aggregated models optimized for BI tools like Looker.
- **Reporting:** Final, highly aggregated reporting tables.

## 📂 Project Structure
- `models/`: The SQL transformation models, separated into staging, marts, looker, and reporting.
- `macros/`: Custom Jinja macros for reusable SQL logic.
- `tests/`: Data quality tests.
- `seeds/`: Static mapping CSVs.

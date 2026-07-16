# 🏭 Manufacturing ERP System

A custom, full-stack Enterprise Resource Planning (ERP) system designed for manufacturing businesses. It manages inventory, tracks Bill of Materials (BOM), and handles sales orders.

## 🛠️ Architecture & Tech Stack
- **Database:** MySQL (Triggers, Stored Procedures, Transactions)
- **Backend API:** FastAPI (Pydantic, Connection Pooling)
- **Frontend / UI:** Streamlit

## ✨ Key Features
- **Bill of Materials (BOM) Logic:** Stored procedures that automatically deduct raw materials when a finished product is manufactured.
- **Inventory Protection:** Database triggers (`trg_after_order_detail_insert`) that prevent sales if stock is insufficient.
- **Transaction Safety:** Ensures that multi-table updates (e.g., during manufacturing or sales) either succeed completely or roll back.
- **Interactive UI:** Streamlit interface for employees to manage actions, view stock, and serve customers.

## 📂 Project Files
- `backend.py`: The FastAPI backend application.
- `frontend.py`: The main Streamlit frontend application.
- `pages/`: Streamlit sub-pages (Actions, Employees, Customers).
- `erp_schema.sql`: The database schema definition.
- `erp_seed_data.sql`: Initial seed data (products, materials, BOM).

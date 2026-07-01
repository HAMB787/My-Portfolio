import os
from fastapi import FastAPI, HTTPException, Depends
from mysql.connector import pooling, Error
from pydantic import BaseModel
from typing import Any, List

app = FastAPI(title="ERP Premium Backend")

# --- 1. Connection Pool ---
db_config: dict[str, Any] = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "2005"),
    "database": os.getenv("DB_NAME", "manufacturing_erp"),
}

pool: pooling.MySQLConnectionPool | None = None
try:
    pool = pooling.MySQLConnectionPool(pool_name="erp_pool", pool_size=10, **db_config)
except Error as e:
    print(f"Error creating pool: {e}")

def get_db():
    if pool is None:
        raise HTTPException(status_code=500, detail="Database pool is not initialized.")
    conn = pool.get_connection()
    try:
        yield conn
    finally:
        conn.close()

# --- 2. Pydantic Մոդելներ ---
class ProductResponse(BaseModel):
    product_id: int
    product_name: str
    stock_quantity: int
    price: float

class SaleRequest(BaseModel):
    product_id: int
    customer_id: int
    employee_id: int
    quantity: int

class ManufactureRequest(BaseModel):
    product_id: int
    quantity: int

class RestockRequest(BaseModel):
    material_id: int
    quantity: int

# --- 3. API Endpoints ---

@app.get("/products", response_model=List[ProductResponse])
def get_products(db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT product_id, product_name, stock_quantity, price FROM products")
    return cursor.fetchall()

@app.post("/sell")
def make_sale(data: SaleRequest, db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    try:
        db.start_transaction()
        cursor.execute(
            "INSERT INTO orders (customer_id, employee_id, order_date) VALUES (%s, %s, NOW())",
            (data.customer_id, data.employee_id)
        )
        order_id = cursor.lastrowid
        cursor.execute("SELECT price FROM products WHERE product_id = %s", (data.product_id,))
        product = cursor.fetchone()
        if not product:
            raise HTTPException(status_code=404, detail="Ապրանքը չի գտնվել")
        cursor.execute(
            "INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (%s, %s, %s, %s)",
            (order_id, data.product_id, data.quantity, product["price"])
        )
        db.commit()
        return {"status": "success", "order_id": order_id}
    except Error as err:
        db.rollback()
        if err.errno == 1644: raise HTTPException(status_code=400, detail=err.msg)
        raise HTTPException(status_code=500, detail=f"Database error: {err}")

@app.post("/manufacture")
def manufacture(data: ManufactureRequest, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.callproc("manufacture_product", [data.product_id, data.quantity])
        db.commit()
        return {"status": "success"}
    except Error as err:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Արտադրության սխալ: {err.msg}")

# 🟢 ՈՒՂՂՎԱԾ: Հումքի (raw_materials) ցանկը
@app.get("/materials")
def get_materials(db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    # Օգտագործում ենք ճիշտ անունները՝ raw_materials և stock_quantity
    cursor.execute("SELECT material_id, material_name, stock_quantity FROM raw_materials")
    return {"materials": cursor.fetchall()}

# 🟢 ՈՒՂՂՎԱԾ: Հումքի համալրում
@app.post("/restock")
def restock_material(data: RestockRequest, db=Depends(get_db)):
    cursor = db.cursor()
    try:
        cursor.execute(
            "UPDATE raw_materials SET stock_quantity = stock_quantity + %s WHERE material_id = %s",
            (data.quantity, data.material_id)
        )
        db.commit()
        return {"status": "success"}
    except Error as err:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {err}")

@app.get("/customers")
def get_customers(db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT customer_id, company_name FROM customers")
    return {"customers": cursor.fetchall()}

@app.get("/employees")
def get_employees(db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT employee_id, first_name, last_name FROM employees")
    return {"employees": cursor.fetchall()}

@app.get("/analytics")
def get_analytics(db=Depends(get_db)):
    cursor = db.cursor(dictionary=True)
    query = """
        SELECT DATE(o.order_date) as date, p.product_name, od.quantity,
               (od.quantity * od.unit_price) as revenue,
               CONCAT(e.first_name, ' ', e.last_name) as manager
        FROM orders o
        JOIN order_details od ON o.order_id = od.order_id
        JOIN products p ON od.product_id = p.product_id
        JOIN employees e ON o.employee_id = e.employee_id
        ORDER BY o.order_date ASC
    """
    try:
        cursor.execute(query)
        return cursor.fetchall()
    except Error: return []
Create database manufacturing_erp;


-- Նախ ընտրում ենք մեր ստեղծած բազան
USE manufacturing_erp;

-- ==========================================
-- ՄԱՍ 1. ՄԱՐԴԿԱՅԻՆ ՌԵՍՈՒՐՍՆԵՐ ԵՎ ՀԱՃԱԽՈՐԴՆԵՐ
-- ==========================================

CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(50),
    hire_date DATE
);

CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20)
);

-- ==========================================
-- ՄԱՍ 2. ՊԱՀԵՍՏ ԵՎ ԱՐՏԱԴՐՈՒԹՅՈՒՆ (BOM)
-- ==========================================

CREATE TABLE raw_materials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_name VARCHAR(100) NOT NULL,
    stock_quantity INT DEFAULT 0
);

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    stock_quantity INT DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE bill_of_materials (
    bom_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    material_id INT,
    quantity_needed INT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES raw_materials(material_id) ON DELETE CASCADE
);

-- ==========================================
-- ՄԱՍ 3. ՎԱՃԱՌՔ (SALES)
-- ==========================================

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    employee_id INT,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE TABLE order_details (
    detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
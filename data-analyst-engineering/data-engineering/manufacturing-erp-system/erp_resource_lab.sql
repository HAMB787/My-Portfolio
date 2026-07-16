CREATE DATABASE BankDB;
GO

USE BankDB;
GO

CREATE TABLE Customer (
    customer_id INT PRIMARY KEY IDENTITY(1,1),
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    passport_no NVARCHAR(20) UNIQUE,
    birth_date DATE,
    phone NVARCHAR(20),
    email NVARCHAR(100),
    address NVARCHAR(200),
    registration_date DATE DEFAULT GETDATE()
);

CREATE TABLE Branch (
    branch_id INT PRIMARY KEY IDENTITY(1,1),
    name NVARCHAR(100),
    city NVARCHAR(50),
    address NVARCHAR(200),
    phone NVARCHAR(20)
);

CREATE TABLE Employee (
    employee_id INT PRIMARY KEY IDENTITY(1,1),
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    position NVARCHAR(50),
    salary DECIMAL(10,2),
    hire_date DATE,
    phone NVARCHAR(20),
    branch_id INT,
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE Account (
    account_id INT PRIMARY KEY IDENTITY(1,1),
    account_number NVARCHAR(30) UNIQUE,
    account_type NVARCHAR(30),
    currency NVARCHAR(10),
    balance DECIMAL(18,2),
    open_date DATE,
    status NVARCHAR(20),
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

CREATE TABLE Card (
    card_id INT PRIMARY KEY IDENTITY(1,1),
    card_number NVARCHAR(20) UNIQUE,
    card_type NVARCHAR(30),
    expire_date DATE,
    cvv NVARCHAR(5),
    status NVARCHAR(20),
    account_id INT,
    FOREIGN KEY (account_id) REFERENCES Account(account_id)
);

CREATE TABLE Loan (
    loan_id INT PRIMARY KEY IDENTITY(1,1),
    loan_type NVARCHAR(50),
    amount DECIMAL(18,2),
    interest_rate DECIMAL(5,2),
    start_date DATE,
    end_date DATE,
    monthly_payment DECIMAL(18,2),
    status NVARCHAR(20),
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

CREATE TABLE Deposit (
    deposit_id INT PRIMARY KEY IDENTITY(1,1),
    deposit_type NVARCHAR(50),
    amount DECIMAL(18,2),
    interest_rate DECIMAL(5,2),
    start_date DATE,
    end_date DATE,
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

CREATE TABLE ATM (
    atm_id INT PRIMARY KEY IDENTITY(1,1),
    location NVARCHAR(200),
    cash_balance DECIMAL(18,2),
    status NVARCHAR(20),
    branch_id INT,
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE Payment (
    payment_id INT PRIMARY KEY IDENTITY(1,1),
    payment_type NVARCHAR(50),
    amount DECIMAL(18,2),
    payment_date DATE,
    receiver NVARCHAR(100),
    account_id INT,
    FOREIGN KEY (account_id) REFERENCES Account(account_id)
);

CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY IDENTITY(1,1),
    transaction_type NVARCHAR(50),
    amount DECIMAL(18,2),
    transaction_date DATETIME DEFAULT GETDATE(),
    description NVARCHAR(200),
    status NVARCHAR(20),
    account_id INT,
    employee_id INT,
    FOREIGN KEY (account_id) REFERENCES Account(account_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);
  
USE BankDB;
GO

-- Branch
INSERT INTO Branch (name, city, address, phone) VALUES
('Kentron Branch', 'Yerevan', '1 Abovyan St', '+37410111222'),
('Arabkir Branch', 'Yerevan', '25 Komitas Ave', '+37410333444'),
('Gyumri Branch', 'Gyumri', '10 Shiraz St', '+37431222333');

-- Customer
INSERT INTO Customer (first_name, last_name, passport_no, birth_date, phone, email, address)
VALUES
('Arsen', 'Sargsyan', 'AR123456', '2003-05-14', '+37494111222', 'arsen@gmail.com', 'Yerevan'),
('Anna', 'Hakobyan', 'AR654321', '1998-09-22', '+37493123456', 'anna@gmail.com', 'Gyumri'),
('David', 'Mkrtchyan', 'AR987654', '1989-12-10', '+37499123456', 'david@gmail.com', 'Vanadzor'),
('Mariam', 'Petrosyan', 'AR456789', '1995-03-08', '+37477111222', 'mariam@gmail.com', 'Yerevan');

-- Employee
INSERT INTO Employee (first_name, last_name, position, salary, hire_date, phone, branch_id)
VALUES
('Karen', 'Avetisyan', 'Manager', 850000, '2020-02-15', '+37455111111', 1),
('Lilit', 'Harutyunyan', 'Cashier', 420000, '2022-06-01', '+37455222222', 1),
('Gor', 'Manukyan', 'Loan Specialist', 600000, '2021-09-12', '+37455333333', 2),
('Sona', 'Melkonyan', 'Operator', 380000, '2023-01-20', '+37455444444', 3);

-- Account
INSERT INTO Account (account_number, account_type, currency, balance, open_date, status, customer_id)
VALUES
('220100000001', 'Savings', 'AMD', 1250000, '2024-01-10', 'Active', 1),
('220100000002', 'Checking', 'USD', 5400, '2024-02-15', 'Active', 2),
('220100000003', 'Savings', 'EUR', 7800, '2023-11-02', 'Active', 3),
('220100000004', 'Checking', 'AMD', 320000, '2024-03-05', 'Active', 4);

-- Card
INSERT INTO Card (card_number, card_type, expire_date, cvv, status, account_id)
VALUES
('4578123412341111', 'Visa Gold', '2028-05-01', '421', 'Active', 1),
('5212345678901111', 'MasterCard', '2027-10-01', '663', 'Active', 2),
('4578999911112222', 'Visa Classic', '2029-01-01', '114', 'Active', 3),
('5488776655443322', 'MasterCard Gold', '2028-07-01', '552', 'Blocked', 4);

-- Loan
INSERT INTO Loan (loan_type, amount, interest_rate, start_date, end_date, monthly_payment, status, customer_id)
VALUES
('Mortgage', 25000000, 11.5, '2024-01-01', '2044-01-01', 268000, 'Active', 1),
('Car Loan', 4200000, 13.0, '2025-03-01', '2030-03-01', 95500, 'Active', 3);

-- Deposit
INSERT INTO Deposit (deposit_type, amount, interest_rate, start_date, end_date, customer_id)
VALUES
('Fixed Deposit', 5000000, 8.5, '2025-01-01', '2026-01-01', 2),
('Premium Deposit', 2500000, 9.2, '2025-02-15', '2026-02-15', 4);

-- ATM
INSERT INTO ATM (location, cash_balance, status, branch_id)
VALUES
('Northern Avenue ATM', 12000000, 'Active', 1),
('Komitas ATM', 8500000, 'Active', 2),
('Gyumri Center ATM', 6700000, 'Maintenance', 3);

-- Payment
INSERT INTO Payment (payment_type, amount, payment_date, receiver, account_id)
VALUES
('Utility', 28500, '2026-04-02', 'Veolia Water', 1),
('Internet', 12000, '2026-04-05', 'Ucom', 1),
('Mobile', 8500, '2026-04-06', 'Team Telecom Armenia', 2),
('Shopping', 145000, '2026-04-10', 'Zara Armenia', 4);

-- Transactions
INSERT INTO Transactions (transaction_type, amount, description, status, account_id, employee_id)
VALUES
('Deposit', 500000, 'Cash deposit at branch', 'Completed', 1, 2),
('Withdrawal', 100000, 'ATM withdrawal', 'Completed', 1, 2),
('Transfer', 250000, 'Transfer to another client', 'Completed', 2, 1),
('Loan Payment', 95500, 'Monthly car loan payment', 'Completed', 3, 3),
('Card Purchase', 45000, 'Supermarket purchase', 'Completed', 4, 4);
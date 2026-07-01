WITH 

invoices AS (SELECT * FROM {{ ref('fct_invoices') }}),
members AS (SELECT * FROM {{ ref('dim_member') }}),

invoices_month AS (

  SELECT DISTINCT DATE(I.created_at)  AS purchase_date,
    I.customer_id,
    COALESCE(I.product_name, 'Unknown') AS product_name,
    COALESCE(M.expert_full_name, 'Unknown')  AS expert_name,
  FROM invoices AS I
  LEFT JOIN members AS M ON I.customer_uuid = M.uuid 
  WHERE I.invoice_total > 0  

),

cohorts AS (
  SELECT 
    customer_id,
    product_name,
    expert_name,
    MIN(DATE_TRUNC(purchase_date, MONTH)) as cohort
  FROM invoices_month
  GROUP BY customer_id, product_name, expert_name
),

retention AS (
  SELECT 
    c.customer_id,
    c.product_name,
    c.expert_name,
    c.cohort,
    TIMESTAMP_DIFF(p.purchase_date, c.cohort, MONTH) as months_since_first_purchase
  FROM invoices_month AS p
  INNER JOIN cohorts AS c 
  ON p.customer_id = c.customer_id
     AND p.product_name = c.product_name
     AND p.expert_name = c.expert_name
),

retention_summary AS (
  SELECT 
    cohort,
    product_name,
    expert_name,
    months_since_first_purchase,
    COUNT(DISTINCT customer_id) as retained_customers
  FROM retention
  GROUP BY cohort, product_name, expert_name, months_since_first_purchase
)

SELECT 
  cohort,
  product_name,
  expert_name,
  MAX(IF(months_since_first_purchase = 0, retained_customers, 0)) AS Month_0,
  MAX(IF(months_since_first_purchase = 1, retained_customers, 0)) AS Month_1,
  MAX(IF(months_since_first_purchase = 2, retained_customers, 0)) AS Month_2,
  MAX(IF(months_since_first_purchase = 3, retained_customers, 0)) AS Month_3,
  MAX(IF(months_since_first_purchase = 4, retained_customers, 0)) AS Month_4,
  MAX(IF(months_since_first_purchase = 5, retained_customers, 0)) AS Month_5,
  MAX(IF(months_since_first_purchase = 6, retained_customers, 0)) AS Month_6,
  MAX(IF(months_since_first_purchase = 7, retained_customers, 0)) AS Month_7,
  MAX(IF(months_since_first_purchase = 8, retained_customers, 0)) AS Month_8,
  MAX(IF(months_since_first_purchase = 9, retained_customers, 0)) AS Month_9,
  MAX(IF(months_since_first_purchase = 10, retained_customers, 0)) AS Month_10,
  MAX(IF(months_since_first_purchase = 11, retained_customers, 0)) AS Month_11,
  MAX(IF(months_since_first_purchase = 12, retained_customers, 0)) AS Month_12
FROM retention_summary
GROUP BY cohort, product_name, expert_name
ORDER BY cohort, product_name, expert_name
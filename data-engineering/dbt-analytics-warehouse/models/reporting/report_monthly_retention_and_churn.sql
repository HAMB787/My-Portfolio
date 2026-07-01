WITH 

invoices AS (SELECT * FROM {{ ref('fct_invoices') }}),
members AS (SELECT * FROM {{ ref('dim_member') }}),

montly_subs AS (

  SELECT
    LAST_DAY(DATE(I.created_at)) AS month,
    COALESCE(I.product_name, 'Unknown') AS product_name,
    COALESCE(M.expert_full_name, 'Unknown')  AS expert_name,
    COUNT(DISTINCT CASE WHEN I.customer_tier_type IN ('4', '5') THEN I.customer_id END) AS total_primary_members,
    COUNT(DISTINCT CASE WHEN I.customer_tier_type NOT IN ('4', '5') THEN I.customer_id END) AS total_non_primary_members,
    COUNT(DISTINCT I.customer_id) AS total_subscribers,
    COUNT(DISTINCT CASE WHEN I.billing_reason = 'subscription_create' THEN I.customer_id END) AS new_subscribers,
    COUNT(DISTINCT CASE WHEN I.billing_reason IN ('subscription_cycle', 'subscription_update') THEN I.customer_id END) AS renewed_subscribers,
    SUM(I.invoice_total / 100) AS total_revenue
  FROM invoices AS I
  LEFT JOIN members AS M ON I.customer_uuid = M.uuid 
  WHERE I.invoice_total > 0
  GROUP BY 1, 2, 3

),

montly_churns AS (

  SELECT
    LAST_DAY(DATE(I.subscription_canceled_at)) AS month,
    COALESCE(I.product_name, 'Unknown') AS product_name,
    COALESCE(M.expert_full_name, 'Unknown')  AS expert_name,    
    COUNT(DISTINCT I.customer_id) AS total_churn,
    COUNT(DISTINCT CASE WHEN DATE_TRUNC(I.subscription_created_at, MONTH) <> DATE_TRUNC(I.subscription_canceled_at, MONTH) THEN I.customer_id END) AS existing_churn,
    COUNT(DISTINCT CASE WHEN DATE_TRUNC(I.subscription_created_at, MONTH) = DATE_TRUNC(I.subscription_canceled_at, MONTH) THEN I.customer_id END) AS new_churn
  FROM invoices AS I
  LEFT JOIN members AS M ON I.customer_uuid = M.uuid 
  WHERE I.invoice_total > 0
    AND subscription_canceled_at IS NOT NULL
  GROUP BY 1, 2, 3

),

montly_retentions AS (

  SELECT 
    LAST_DAY(DATE(I.created_at)) AS month,
    COALESCE(I.product_name, 'Unknown') AS product_name,
    COALESCE(M.expert_full_name, 'Unknown')  AS expert_name,       
    COUNT(DISTINCT I.customer_id) AS total_retention,
    COUNT(DISTINCT CASE WHEN DATE_TRUNC(I.subscription_created_at, MONTH) <> DATE_TRUNC(I.created_at, MONTH) THEN I.customer_id END) AS existing_retention,
    COUNT(DISTINCT CASE WHEN DATE_TRUNC(I.subscription_created_at, MONTH) = DATE_TRUNC(I.created_at, MONTH) THEN I.customer_id END) AS new_retention
  FROM invoices AS I
  LEFT JOIN members AS M ON I.customer_uuid = M.uuid 
  WHERE I.invoice_total > 0
    AND subscription_canceled_at IS NULL
  GROUP BY 1, 2, 3

),

final AS (

    SELECT S.month,
    S.product_name,
    S.expert_name,
    LEAD(S.total_subscribers, 1) OVER(PARTITION BY S.product_name, S.expert_name ORDER BY S.month DESC) AS total_subs_start_of_the_period,
    S.new_subscribers,
    S.renewed_subscribers,
    S.total_subscribers AS total_subs_end_of_the_period,
    S.total_revenue AS total_revenue_end_of_the_period,
    S.total_primary_members * 2 + S.total_non_primary_members AS total_members,
    COALESCE(R.total_retention, 0) AS total_retention,
    COALESCE(R.existing_retention, 0) AS existing_retention,
    COALESCE(R.new_retention, 0) AS new_retention,
    COALESCE(C.total_churn, 0) AS total_churn,
    COALESCE(C.existing_churn, 0) AS existing_churn,
    COALESCE(C.new_churn, 0) AS new_churn
    FROM montly_subs AS S
    LEFT JOIN montly_churns AS C ON S.month = C.month
        AND S.product_name = C.product_name
        AND S.expert_name = C.expert_name
    LEFT JOIN montly_retentions AS R ON S.month = R.month
        AND S.product_name = R.product_name
        AND S.expert_name = R.expert_name

)

SELECT * FROM final
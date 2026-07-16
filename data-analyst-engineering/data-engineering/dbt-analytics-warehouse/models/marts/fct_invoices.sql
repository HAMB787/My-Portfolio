{{ config(
    materialized='table'
)}}

WITH

members AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
webapp_account AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_account') }}),
webapp_plan AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_plan') }}),
invoices AS (SELECT * FROM {{ ref('stg_stripe__invoice') }}),
customers AS (SELECT * FROM {{ ref('stg_stripe__customer') }}),
charges AS (SELECT * FROM {{ ref('stg_stripe__charge') }}),
subscriptions_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY id, latest_invoice_id ORDER BY fivetran_end_at DESC) AS rnk
    FROM {{ ref('stg_stripe__subscription_history') }}
),
subscriptions_ranked_without_invoice AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_end_at DESC) AS rnk
    FROM {{ ref('stg_stripe__subscription_history') }}
),
plans AS (
    SELECT *
    FROM {{ ref('stg_stripe__plan') }}
),
subscription_items AS (
    SELECT * FROM {{ ref('stg_stripe__subscription_item') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY subscription_id ORDER BY created_at DESC) = 1
),
products AS (SELECT * FROM {{ ref('stg_stripe__product') }}),
coupon AS (SELECT * FROM {{ ref('stg_stripe__coupon') }}),
promotion_code AS (SELECT * FROM {{ ref('stg_stripe__promotion_code') }}),
refunds_raw AS (SELECT * FROM {{ ref('stg_stripe__refund') }}),
disputes_raw AS (SELECT * FROM {{ ref('stg_stripe__dispute') }}),
disputes AS 
(
    SELECT 
        charge_id,                                
        currency,                          
        description,                       
        failure_reason,                            
        reason,                            
        status,                            
        SUM(amount) AS amount,                            
        MIN(created_at) AS created_at,
        MIN(id) AS id                               
    FROM refunds_raw
    WHERE status = 'lost'
    GROUP BY 1,2,3,4,5,6
),

subscriptions AS (SELECT * FROM subscriptions_ranked WHERE rnk = 1),
subscriptions_without_invoice AS (SELECT * FROM subscriptions_ranked_without_invoice WHERE rnk = 1),
refunds AS 
(
    SELECT 
        charge_id,                                
        currency,                          
        description,                       
        failure_reason,                            
        reason,                            
        status,                            
        SUM(amount) AS amount,                            
        MIN(created_at) AS created_at,
        MIN(id) AS id                               
    FROM refunds_raw
    WHERE status = 'succeeded'
    GROUP BY 1,2,3,4,5,6
),

all_joined_added_retention_cohort AS (

    SELECT
        I.id,
        I.customer_id,
        I.charge_id,
        I.subscription_id,
        I.billing,
        I.billing_reason,
        I.currency,
        I.number                            AS invoice_number,
        I.status                            AS invoice_status,
        I.amount_due                        AS invoice_amount_due,
        I.amount_paid                       AS invoice_amount_paid,
        I.amount_remaining                  AS invoice_amount_remaining,
        I.subtotal                          AS invoice_subtotal,
        I.total                             AS invoice_total,
        I.is_attempted,
        I.is_auto_advance,
        I.is_deleted,
        I.is_livemode,
        I.is_paid,
        I.total = 0                         AS is_test,
        I.created_at,
        I.invoiced_at,
        I.fivetran_synced_at                AS last_updated_at,
        CASE
            WHEN C.email <> M.email AND M.email IS NOT NULL
            THEN M.email
            ELSE C.email
        END                                 AS customer_email, -- as a base taking the email in backend
        C.name                              AS customer_name,
        C.uuid                              AS customer_uuid,
        C.funnel                            AS customer_funnel,
        C.funnel_start                      AS customer_funnel_start,
        C.funnel_id                         AS customer_funnel_id,
        COALESCE(CPN2.name, CPN.name, C.coupon)        AS customer_coupon,
        C.rfsn                              AS customer_rfsn,
        C.rfsn_v4_aid                       AS customer_rfsn_v4_aid,
        C.rfsn_v4_cs                        AS customer_rfsn_v4_cs,
        C.rfsn_v4_id                        AS customer_rfsn_v4_id,
        C.tier_type                         AS customer_tier_type,
        C.utm_campaign                      AS customer_utm_campaign,
        C.utm_content                       AS customer_utm_content,
        C.utm_medium                        AS customer_utm_medium,
        C.utm_source                        AS customer_utm_source,
        C.order_id                          AS customer_order_id,
        C.is_deleted                        AS customer_is_deleted,
        CH.billing_detail_address_country   AS charge_billing_country,    
        CH.description                      AS charge_description,
        CH.failure_code                     AS charge_failure_code,  
        CH.failure_message                  AS charge_failure_message,
        CH.outcome_network_status           AS charge_outcome_network_status,
        CH.outcome_seller_message           AS charge_outcome_seller_message,
        CH.status                           AS charge_status,
        CH.amount                           AS charge_amount,
        CH.amount_refunded                  AS charge_amount_refunded,
        CH.is_captured                      AS charge_is_captured,
        CH.is_livemode                      AS charge_is_livemode,
        CH.is_paid                          AS charge_is_paid,
        S2.created_at                       AS subscription_created_at,
        S.trial_start_at                    AS subscription_trial_started_at,
        S.trial_end_at                      AS subscription_trial_ended_at,
        S.start_date_at                     AS subscription_started_at,
        COALESCE(S.current_period_start_at, I.period_start_at)           AS subscription_current_period_start_at,
        COALESCE(S.current_period_end_at, I.period_end_at)             AS subscription_current_period_end_at,
        S.status                            AS subscription_status,
        S.canceled_at                       AS subscription_canceled_at,
        S.cancel_at                         AS subscription_expired_at,
        S.is_cancel_at_period_end           AS subscription_is_expired_at_period_end,
        S.ended_at                          AS subscription_ended_at,
        S.pause_collection_behavior         AS subscription_pause_collection_behavior,
        S.pause_collection_resumes_at       AS subscription_pause_collection_resumes_at,
        PL.id   AS plan_id,
        PL.plan_duration,
        MP.plan_name                        AS member_plan_name,
        MP.plan_month_length                AS member_plan_duration,
        MAX(CONCAT(CAST(PL.interval_count AS STRING), ' ', PL.`interval`)) OVER(PARTITION BY I.customer_id, I.subscription_id) AS stripe_plan_duration,
        SI.id AS item_id,
        PL.nickname                         AS plan_name,
        PL.trial_period_days                AS plan_trial_period_days,
        PL.is_active                        AS plan_is_active,
        P.name                              AS product_name,
        P.description                       AS product_description,
        P.is_active                         AS product_is_active,
        CASE
            WHEN ROW_NUMBER() OVER(PARTITION BY C.id ORDER BY I.created_at ASC) = 1 THEN TRUE
            ELSE FALSE
        END                                 AS is_first_invoice,
        DATE(DATE_TRUNC(I.created_at, MONTH))     AS invoice_month, -- can we made flexible in the future
        DATE(DATE_TRUNC(MIN(I.created_at) OVER(PARTITION BY I.customer_id), MONTH)) AS cohort,  -- can we made flexible in the future
        R.id                                AS refund_id,
        R.currency                          AS refund_currency,
        R.description                       AS refund_description,
        R.failure_reason                    AS refund_failure_reason,        
        R.reason                            AS refund_reason,  
        R.status                            AS refund_status,      
        R.amount                            AS refund_amount,
        R.created_at                        AS refund_initiated_at,
        R.amount IS NOT NULL                AS charge_is_refunded,        
        CASE
            WHEN R.amount IS NOT NULL AND R.amount < I.total THEN 'Partial'
            WHEN R.amount IS NOT NULL AND R.amount >= I.total THEN  'Full'
        END                                 AS refund_type,
        D.id                                AS dispute_id,
        D.currency                          AS dispute_currency,
        D.reason                            AS dispute_reason,
        D.status                            AS dispute_status,
        D.amount                            AS dispute_amount,
        D.created_at                        AS dispute_created_at
    FROM invoices AS I
    LEFT JOIN customers AS C ON I.customer_id = C.id
    LEFT JOIN charges AS CH ON I.charge_id = CH.id
    LEFT JOIN subscriptions AS S ON I.subscription_id = S.id
        AND I.id = S.latest_invoice_id -- capturing SCD changes, for complex updatable fields
    LEFT JOIN subscriptions_without_invoice AS S2 ON I.subscription_id = S2.id -- for fixed fields
    LEFT JOIN subscription_items AS SI ON S.id = SI.subscription_id
    LEFT JOIN plans AS PL ON SI.plan_id = PL.id
    LEFT JOIN products AS P ON PL.product_id = P.id
    LEFT JOIN refunds AS R ON CH.id = R.charge_id
    LEFT JOIN disputes AS D ON CH.id = D.charge_id
    LEFT JOIN members AS M ON C.uuid = M.uuid
    LEFT JOIN webapp_account AS A ON M.account_id = A.id
    LEFT JOIN webapp_plan AS MP ON A.member_plan_id = MP.id
    LEFT JOIN coupon AS CPN ON C.coupon = CPN.id
    LEFT JOIN promotion_code AS PMC ON C.coupon = PMC.id
    LEFT JOIN coupon AS CPN2 ON PMC.coupon_id = CPN2.id    

),


final AS (

    SELECT *,
        CASE
            WHEN charge_failure_code IS NULL
                AND invoice_total > 0 
                AND charge_is_refunded = FALSE
                AND charge_is_paid = TRUE
                AND charge_amount_refunded = 0
            THEN TRUE
            ELSE FALSE
        END                                        AS is_invoice_paid_not_refunded,
        DATE_DIFF(invoice_month, cohort, MONTH)    AS retention_distance_month
    FROM all_joined_added_retention_cohort
    WHERE (customer_email NOT LIKE '%@heyritual.com%' OR customer_email NOT LIKE '%test%' OR customer_email NOT LIKE '%+rm%') -- excluding tests in prod data
    
)

SELECT * FROM final
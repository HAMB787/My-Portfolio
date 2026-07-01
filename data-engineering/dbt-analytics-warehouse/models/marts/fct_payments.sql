{{ config(
    materialized='table'
)}}

WITH

charges AS (SELECT * FROM {{ ref('stg_stripe__charge') }} WHERE status = 'succeeded'),
invoices AS (SELECT * FROM {{ ref('stg_stripe__invoice') }}),
current_subscriptions AS (
    SELECT *
    FROM {{ ref('stg_stripe__subscription_history') }}
    QUALIFY
        ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_end_at DESC) = 1
),
customer AS (SELECT * FROM {{ ref('stg_stripe__customer') }}),
refund AS (
    SELECT charge_id,
        MIN(created_at) AS refund_date,
        SUM(amount) AS refund_amount,
        string_agg(reason, ',') AS refund_reason
    FROM {{ ref('stg_stripe__refund') }}
    WHERE status = 'succeeded'
    GROUP BY charge_id
),
plans AS (SELECT * FROM {{ ref('stg_stripe__plan') }}),
coupon AS (SELECT * FROM {{ ref('stg_stripe__coupon') }}),
products AS (SELECT * FROM {{ ref('stg_stripe__product') }}),
renewals AS (
    SELECT DISTINCT id
    FROM invoices
    WHERE billing_reason = 'subscription_cycle'
),
subscription_items AS (
    SELECT * FROM {{ ref('stg_stripe__subscription_item') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY subscription_id ORDER BY created_at DESC) = 1
),
payment_method AS (SELECT * FROM {{ ref('stg_stripe__payment_method') }}),
webapp_member AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),


final AS (

    SELECT 
        CH.id,
        CH.invoice_id,
        S.id AS subscription_id,
        CH.customer_id,
        CH.description,
        C.uuid AS customer_uuid,
        M.id AS member_id,
        M.primary_member_id AS partner_member_id,
        CONCAT(CAST(PL.interval_count AS STRING), ' ', PL.`interval`) AS plan_duration,
        P.name AS subscription_type,
        S.created_at AS subscription_start_date,
        S.ended_at AS subscription_end_date,
        S.canceled_at AS cancellation_date,
        S.status = 'active' AS is_active_subscription,
        RN.id IS NOT NULL AS is_renewed,
        R.charge_id IS NOT NULL AS is_refunded,
        R.refund_date,
        R.refund_amount,
        R.refund_reason,
        CASE 
            WHEN DATE_DIFF(S.created_at, S.canceled_at, DAY) <= 14 THEN TRUE
            ELSE FALSE
        END AS eligible_for_full_refund,
        SAFE_DIVIDE(R.refund_amount, CH.amount) AS refund_ratio,
        CH.currency,
        CH.amount,
        CH.payment_method_id,
        CASE
            WHEN CH.card_id IS NOT NULL THEN 'CARD'
            ELSE PM.type
        END AS payment_method,
        COALESCE(CPN.name, C.coupon)        AS discount_code,  
        COALESCE(CPN.amount_off,0)          AS discount_amount,
        COALESCE(CPN.percent_off,0)         AS discount_percent,
        CPN.duration                        AS discount_duration,   
        CASE
            WHEN CPN.amount_off IS NOT NULL THEN CPN.amount_off
            ELSE CH.amount * COALESCE(CPN.percent_off,0) / 100
        END                                 AS discount_amount_final,   
        I.period_start_at AS billing_period_start_date,
        I.period_end_at AS billing_period_end_date,
        CASE
            WHEN S.pause_collection_resumes_at IS NOT NULL THEN fivetran_start_at
            ELSE NULL
        END AS pause_start_date,
        S.pause_collection_resumes_at AS pause_end_date,
        CH.invoice_id IS NULL AS is_non_invoiced_payment,
        CH.invoice_id IS NOT NULL AND I.subscription_id IS NULL AS is_non_sub_invoice,
        CH.created_at,
        CH.fivetran_synced_at AS updated_at
    FROM charges AS CH
    LEFT JOIN invoices AS I ON CH.invoice_id = I.id
    LEFT JOIN current_subscriptions AS S ON I.subscription_id = S.id
    LEFT JOIN customer AS C ON CH.customer_id = C.id
    LEFT JOIN renewals AS RN ON CH.invoice_id = RN.id
    LEFT JOIN refund AS R ON CH.id = R.charge_id
    LEFT JOIN subscription_items AS SI ON S.id = SI.subscription_id
    LEFT JOIN plans AS PL ON SI.plan_id = PL.id
    LEFT JOIN products AS P ON PL.product_id = P.id
    LEFT JOIN payment_method AS PM ON CH.payment_method_id = PM.id
    LEFT JOIN webapp_member AS M ON C.uuid = M.uuid
    LEFT JOIN coupon AS CPN ON C.coupon = CPN.id    

)

SELECT * FROM final
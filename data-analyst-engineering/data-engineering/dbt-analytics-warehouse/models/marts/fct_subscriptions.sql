{{ config(
    materialized='table'
)}}

WITH

subscriptions AS (SELECT * FROM {{ ref('stg_stripe__subscription_history') }} WHERE is_fivetran_active = TRUE),
plans AS (SELECT * FROM {{ ref('stg_stripe__plan') }}),
customers AS (SELECT * FROM {{ ref('stg_stripe__customer') }}),
subscription_items AS (
    SELECT * FROM {{ ref('stg_stripe__subscription_item') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY subscription_id ORDER BY created_at DESC) = 1
),
products AS (SELECT * FROM {{ ref('stg_stripe__product') }}),

final AS (

    SELECT 
        SI.subscription_id,
        SI.id                                AS subscription_item_id,
        SI.plan_id,
        PL.product_id,
        S.customer_id,
        S.created_at                        AS subscription_created_at,
        S.trial_start_at                    AS subscription_trial_started_at,
        S.trial_end_at                      AS subscription_trial_ended_at,
        S.start_date_at                     AS subscription_started_at,
        S.current_period_start_at           AS subscription_current_period_start_at,
        S.current_period_end_at             AS subscription_current_period_end_at,
        S.status                            AS subscription_status,
        S.canceled_at                       AS subscription_canceled_at,
        S.cancel_at                         AS subscription_expired_at,
        S.is_cancel_at_period_end           AS subscription_is_expired_at_period_end,
        S.ended_at                          AS subscription_ended_at,
        C.email                             AS customer_email,
        C.name                              AS customer_name,
        C.uuid                              AS customer_uuid,
        C.funnel                            AS customer_funnel,
        C.funnel_start                      AS customer_funnel_start,
        C.funnel_id                         AS customer_funnel_id,
        C.coupon                            AS customer_coupon,
        C.rfsn                              AS customer_rfsn,
        C.rfsn_v4_aid                       AS customer_rfsn_v4_aid,
        C.rfsn_v4_cs                        AS customer_rfsn_v4_cs,
        C.rfsn_v4_id                        AS customer_rfsn_v4_id,
        C.tier_type                         AS customer_tier_type,
        C.utm_campaign                      AS customer_utm_campaign,
        C.utm_content                       AS customer_utm_content,
        C.utm_medium                        AS customer_utm_medium,
        C.utm_source                        AS customer_utm_source,
        C.is_deleted                        AS customer_is_deleted,
        CONCAT(CAST(PL.interval_count AS STRING), ' ', PL.`interval`) AS plan_duration,        
        PL.nickname                         AS plan_name,
        PL.trial_period_days                AS plan_trial_period_days,
        PL.is_active                        AS plan_is_active,
        P.name                              AS product_name,
        P.description                       AS product_description,
        P.is_active                         AS product_is_active,
        CASE
            WHEN ROW_NUMBER() OVER(PARTITION BY C.id ORDER BY S.created_at ASC) = 1 THEN TRUE
            ELSE FALSE
        END                                 AS is_first_subscription
    FROM subscription_items AS SI
    LEFT JOIN subscriptions AS S ON SI.subscription_id = S.id
    LEFT JOIN customers AS C ON S.customer_id = C.id
    LEFT JOIN plans AS PL ON SI.plan_id = PL.id
    LEFT JOIN products AS P ON PL.product_id = P.id

)

SELECT * FROM final
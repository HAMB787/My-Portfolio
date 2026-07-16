WITH

ad_spend AS (SELECT * FROM {{ ref('fct_daily_ad_spend') }} ),
subscriptions AS (SELECT * FROM {{ ref('fct_subscriptions') }} ),

subs_aggregated AS (

    SELECT DATE(subscription_created_at)    AS date,
        customer_utm_source,
        customer_utm_campaign,
        customer_utm_medium,
        'N/A'   AS device,
        COUNT(CASE WHEN is_first_subscription = TRUE THEN subscription_id END)  AS new_subscriptions,   
        COUNT(CASE WHEN is_first_subscription = FALSE THEN subscription_id END)  AS recurring_subscriptions   
    FROM subscriptions
    GROUP BY 1,2,3,4,5

),

final AS (

    SELECT
        COALESCE(A.date, S.date) AS date,
        COALESCE(A.utm_source, S.customer_utm_source) AS utm_source,
        COALESCE(A.utm_campaign, S.customer_utm_campaign) AS utm_campaign,
        COALESCE(A.utm_medium, S.customer_utm_medium) AS utm_medium,
        COALESCE(A.device, S.device) AS device,
        SUM(COALESCE(A.total_cost, 0)) AS total_ad_spend,
        SUM(COALESCE(S.new_subscriptions, 0)) AS total_new_subscriptions,
        SUM(COALESCE(S.recurring_subscriptions, 0)) AS total_recurring_subscriptions
    FROM ad_spend AS A
    FULL JOIN subs_aggregated AS S ON A.date = S.date
        AND A.utm_source = S.customer_utm_source
        AND A.utm_campaign = S.customer_utm_campaign
        AND A.utm_medium = S.customer_utm_medium
    GROUP BY 1,2,3,4,5

)

SELECT * FROM final
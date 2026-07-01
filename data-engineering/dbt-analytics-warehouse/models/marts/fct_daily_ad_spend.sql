WITH

google_ad_spend AS (SELECT * FROM {{ ref('stg_google_ads__campaign_stats') }} ),
google_campaigns AS (
    SELECT * 
    FROM {{ ref('stg_google_ads__campaign_history') }} 
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1
),
facebook_ad_spend AS (SELECT * FROM {{ ref('stg_facebook_ads__basic_ad_set') }} ),
impact_ad_spend_old AS (SELECT * FROM {{ ref('stg_impact__action') }} ),
impact_ad_spend_new AS (SELECT * FROM {{ ref('stg_impact__action_event') }} ),
affiliate_ad_spend AS (SELECT * FROM {{ ref('affiliate_ad_spend') }} ),
bing_ad_spend AS (SELECT * FROM {{ ref('stg_bingads__account_performance_daily_report') }} ),
smart_revover_ad_spend AS (
    SELECT  * 
    FROM    {{ ref('stg_pubsub__events') }}    
    WHERE   1=1
            AND JSON_EXTRACT_SCALAR(payload, '$.coupon') = 'JADE50'
            AND event_name = 'registration_checkout_complete'
            AND utm_source = 'smart_recover'),

impact_ad_spend_without_dedup AS (

    SELECT
        id, 
        creation_date,
        campaign_id,
        campaign_name,
        media_partner_name,
        payout,
        fivetran_synced_at
    FROM impact_ad_spend_old

    UNION ALL

    SELECT 
        id,
        creation_date,
        campaign_id,
        campaign_name,
        media_partner_name,
        payout,
        fivetran_synced_at
    FROM impact_ad_spend_new


),

impact_ad_spend AS (

    SELECT * FROM impact_ad_spend_without_dedup
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1
),

google_added_params AS (

    SELECT 
        DATE(A.date) AS date,
        'Google'                                                     AS utm_source,
        A.id                                                         AS utm_campaign_id,
        C.name                                                       AS utm_campaign,
        C.advertising_channel_type                                   AS utm_medium,
        A.device,
        SUM(A.cost)                                                    AS total_cost
    FROM google_ad_spend AS A
    LEFT JOIN google_campaigns AS C ON A.id = C.id
    GROUP BY 1,2,3,4,5,6

),

facebook_added_params AS (

    SELECT 
        DATE(reported_at) AS date,
        'Facebook'                                                     AS utm_source,
        campaign_id                                                    AS utm_campaign_id,
        campaign_name                                                  AS utm_campaign,
        'Social'                                                       AS utm_medium,
        CAST(NULL AS STRING)                                           AS device,
        SUM(spend)                                                     AS total_cost
    FROM facebook_ad_spend
    GROUP BY 1,2,3,4,5

),

impact_added_params AS (

    SELECT 
        DATE(creation_date) AS date,
        'Impact'                                                       AS utm_source,
        campaign_id                                                    AS utm_campaign_id,
        media_partner_name                                             AS utm_campaign,
        'Affiliate'                                                    AS utm_medium,
        CAST(NULL AS STRING)                                           AS device,
        SUM(payout)                                                    AS total_cost
    FROM impact_ad_spend
    GROUP BY 1,2,3,4,5

),

affiliate_added_params AS (

    SELECT 
        DATE(date) AS date,
        'Affiliate'                                                    AS utm_source,
        'Affiliate'                                                    AS utm_campaign_id,
        'Affiliate'                                                    AS utm_campaign,
        'Affiliate'                                                    AS utm_medium,
        CAST(NULL AS STRING)                                           AS device,
        SUM(total_cost)                                                AS total_cost
    FROM affiliate_ad_spend
    GROUP BY 1,2,3,4,5

),

bing_added_params AS (

    SELECT 
        DATE(date) AS date,
        'Bing'                                                         AS utm_source,
        network                                                        AS utm_campaign_id,
        network                                                        AS utm_campaign,
        ad_distribution                                                AS utm_medium,
        device_type                                                    AS device,
        SUM(spend)                                                    AS total_cost
    FROM bing_ad_spend
    GROUP BY 1,2,3,4,5,6

),

smart_recover_added_params AS (
    SELECT    
        Date(created_at)                                                    AS date,
        'Smart Recover'                                                     AS utm_source,
        'JADE50'                                                            AS utm_campaign_id,
        'Lead Nurture'                                                      AS utm_campaign,
        'SMS'                                                               AS utm_medium,
        device_type                                                         AS device,
        SUM(CAST(JSON_EXTRACT_SCALAR(payload, '$.amount') AS FLOAT64) * 0.25) AS total_cost
    FROM smart_revover_ad_spend
    GROUP BY 1,2,3,4,5,6
),

all_unioned AS (

    SELECT * FROM google_added_params

    UNION ALL

    SELECT * FROM facebook_added_params

    UNION ALL

    SELECT * FROM impact_added_params

    UNION ALL

    SELECT * FROM affiliate_added_params

    UNION ALL

    SELECT * FROM bing_added_params

    UNION ALL

    SELECT * FROM smart_recover_added_params

),

final AS (

    SELECT
        TO_HEX(MD5(CAST(date AS STRING) || utm_source || utm_campaign || utm_medium || CAST(COALESCE(device, '') AS STRING))) as unique_id,
        *
    FROM all_unioned

)

SELECT * FROM final
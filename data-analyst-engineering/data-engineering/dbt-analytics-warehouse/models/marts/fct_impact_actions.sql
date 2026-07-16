WITH

impact_actions_old AS (SELECT * FROM {{ ref('stg_impact__action') }} ),
impact_actions_new AS (SELECT * FROM {{ ref('stg_impact__action_event') }} ),
impact_ads AS (SELECT * FROM {{ ref('stg_impact__ads') }} ),

impact_actions_without_dedup AS (
    
    SELECT
        id,
        event_date,
        creation_date,
        locking_date,
        referring_date,
        customer_id,
        customer_country,
        campaign_id,
        campaign_name,
        ad_id,
        action_tracker_name, 
        referring_type,
        media_partner_name,  
        referring_domain,
        state,               
        promo_code,
        amount,              
        payout,
        fivetran_synced_at              
    FROM impact_actions_old

    UNION ALL

    SELECT
        id,
        event_date,
        creation_date,
        locking_date,
        referring_date,
        customer_id,
        customer_country,
        campaign_id,
        campaign_name,
        ad_id,
        action_tracker_name, 
        referring_type,
        media_partner_name,  
        referring_domain,
        state,               
        promo_code,
        amount,              
        payout,
        fivetran_synced_at    
    FROM impact_actions_new
),

impact_actions AS (

    SELECT * FROM impact_actions_without_dedup
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1
),

final AS (

    SELECT 
        AC.id,
        AC.event_date,
        AC.creation_date,
        AC.locking_date,
        AC.referring_date,
        AC.customer_id,
        AC.customer_country,
        AC.campaign_id,
        AC.campaign_name,
        AC.ad_id,
        AD.name                     AS ad_name,
        AD.ad_type,
        AC.action_tracker_name      AS action_type,
        AC.referring_type,
        AC.media_partner_name       AS partner_name,
        AC.referring_domain,
        AC.state                    AS action_state,
        AC.promo_code,
        AC.amount                   AS expected_income,
        AC.payout                   AS partnership_cost
    FROM impact_actions AS AC
    LEFT JOIN impact_ads AS AD ON AC.ad_id = AD.id

)

SELECT *
FROM final
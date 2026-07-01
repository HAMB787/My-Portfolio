{{ config(
    materialized='table'
)}}


WITH 

webapp_member AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
webapp_expert AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_expert') }}),
webapp_account AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_account') }}),
webapp_plan AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_plan') }}),
all_events AS (SELECT * FROM {{ ref('fct_product_events') }}),
subscriptions AS (SELECT * FROM {{ ref('fct_subscriptions') }}),
activated_members AS (SELECT * FROM {{ ref('intermediate_activated_members') }}),
dim_member_snapshot AS (Select * FROM {{ ref('dim_member_snapshot') }})


frozen_primary AS (
    SELECT
        id,
        FIRST_VALUE(primary_member_id IS NULL) OVER (PARTITION BY id ORDER BY dbt_valid_from ) AS frozen_is_primary
    FROM  dim_member_snapshot
),




first_subscriptions AS (
    SELECT * FROM subscriptions
    QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_uuid ORDER BY subscription_created_at ASC) = 1
),

max_subcription_created AS (

    SELECT customer_uuid,
        MAX(subscription_created_at) AS subscription_created_at
    FROM subscriptions
    GROUP BY 1

),

all_events_filtered AS (

    SELECT
        *
    FROM all_events
    WHERE user_id IS NOT NULL
        AND (
            (utm_campaign IS NOT NULL AND utm_campaign <> 'NA') OR
            (utm_medium IS NOT NULL AND utm_medium <> 'NA') OR
            (utm_source IS NOT NULL AND utm_source <> 'NA')
        )
),

first_subscriptions_filtered AS (

    SELECT
        *
    FROM first_subscriptions
    WHERE customer_uuid IS NOT NULL
        AND (
            (customer_utm_campaign IS NOT NULL AND customer_utm_campaign <> 'NA') OR
            (customer_utm_content IS NOT NULL AND customer_utm_content <> 'NA') OR
            (customer_utm_medium IS NOT NULL AND customer_utm_medium <> 'NA') OR
            (customer_utm_source IS NOT NULL AND customer_utm_source <> 'NA')
        )
),

top_five_utm_param_rows AS (

    SELECT
        user_id,
        utm_campaign,
        utm_medium,
        utm_source
    FROM all_events_filtered
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at ASC) <= 5

),

utm_source_grouped AS (

    SELECT 
        user_id, 
        utm_source
    FROM
        (
            SELECT user_id,
                utm_source,
                count(*) AS total
            FROM top_five_utm_param_rows
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

),

utm_campaign_grouped AS (

    SELECT 
        user_id, 
        utm_campaign
    FROM
        (
            SELECT user_id,
                utm_campaign,
                count(*) AS total
            FROM top_five_utm_param_rows
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

),

utm_medium_grouped AS (

    SELECT 
        user_id, 
        utm_medium
    FROM
        (
            SELECT user_id,
                utm_medium,
                count(*) AS total
            FROM top_five_utm_param_rows
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

),

initial_utm_params AS (

    SELECT S.user_id,
        S.utm_source,
        C.utm_campaign,
        M.utm_medium
    FROM utm_source_grouped AS S
    INNER JOIN utm_campaign_grouped AS C ON S.user_id = C.user_id
    INNER JOIN utm_medium_grouped AS M ON S.user_id = M.user_id

),

all_events_filtered_attribution AS (

    SELECT
        *
    FROM all_events
    WHERE user_id IS NOT NULL
        AND utm_source IS NOT NULL 
        AND utm_source <> 'NA' 
        AND utm_source NOT IN ('cio', 'customerio', 'smart_recover')
        -- AND JSON_EXTRACT_SCALAR(payload, '$.coupon') IS NOT NULL
        AND utm_source <> 'organic'
        

),

initial_attribution_params AS (

    SELECT
        user_id,
        utm_campaign AS attribution_campaign,
        utm_medium AS attribution_medium,
        utm_source AS attribution_source
    FROM all_events_filtered_attribution
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at DESC) = 1

),

crm_events_filtered AS (

    SELECT
        *
    FROM all_events
    WHERE user_id IS NOT NULL
        AND (
            (crm_campaign IS NOT NULL AND crm_campaign <> 'NA') OR
            (crm_medium IS NOT NULL AND crm_medium <> 'NA') OR
            (crm_content IS NOT NULL AND crm_content <> 'NA') OR
            (crm_source IS NOT NULL AND crm_source <> 'NA')
        )
),

last_crm_params AS (

    SELECT
        user_id,
        crm_campaign,
        crm_medium,
        crm_content,
        crm_source
    FROM crm_events_filtered
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at DESC) = 1

),

-- top_five_utm_param_rows_attribution AS (

--     SELECT
--         user_id,
--         utm_campaign,
--         utm_medium,
--         utm_source
--     FROM all_events_filtered_attribution
--     QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at ASC) <= 5

-- ),

-- initial_attribution_source AS (

--     SELECT 
--         user_id, 
--         utm_source AS attribution_source
--     FROM
--         (
--             SELECT user_id,
--                 utm_source,
--                 count(*) AS total
--             FROM top_five_utm_param_rows_attribution
--             group by 1, 2
--         )
--     QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

-- ),

-- initial_attribution_campaign AS (

--     SELECT 
--         user_id, 
--         utm_campaign AS attribution_campaign
--     FROM
--         (
--             SELECT user_id,
--                 utm_campaign,
--                 count(*) AS total
--             FROM top_five_utm_param_rows_attribution
--             group by 1, 2
--         )
--     QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

-- ),

-- initial_attribution_medium AS (

--     SELECT 
--         user_id, 
--         utm_medium AS attribution_medium
--     FROM
--         (
--             SELECT user_id,
--                 utm_medium,
--                 count(*) AS total
--             FROM top_five_utm_param_rows_attribution
--             group by 1, 2
--         )
--     QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY total DESC) = 1

-- ),

-- initial_attribution_params AS (

--     SELECT S.user_id,
--         S.attribution_source,
--         C.attribution_campaign,
--         M.attribution_medium
--     FROM initial_attribution_source AS S
--     INNER JOIN initial_attribution_campaign AS C ON S.user_id = C.user_id
--     INNER JOIN initial_attribution_medium AS M ON S.user_id = M.user_id

-- ),


until_subscription_utm_params AS (

    SELECT
        E.user_id,
        COALESCE(E.utm_campaign, S.customer_utm_campaign)                       AS utm_campaign,
        COALESCE(E.utm_medium, S.customer_utm_medium)                           AS utm_medium,
        COALESCE(E.utm_source, S.customer_utm_source)                           AS utm_source,
        DATE_DIFF(E.created_at, S.subscription_created_at, SECOND)              AS diff
    FROM all_events_filtered AS E
    INNER JOIN first_subscriptions_filtered AS S ON E.user_id = S.customer_uuid
    WHERE E.created_at <= S.subscription_created_at

),

last_utm_params_before_subscription AS (

    SELECT *
    FROM until_subscription_utm_params
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY diff DESC) = 1

),



final AS (

    SELECT M.id,
        M.uuid,
        M.first_name,
        M.last_name,
        CONCAT(M.first_name, ' ', M.last_name)  AS full_name,
        M.gender,
        M.email,
        M.phone_number,
        E.id AS expert_id,
        E.first_name AS expert_first_name,
        E.last_name AS expert_last_name,
        CONCAT(E.first_name, ' ', E.last_name)  AS expert_full_name,        
        CASE M.status
            WHEN 1 THEN 'Active'
            WHEN 2 THEN 'Inactive'
            WHEN 3 THEN 'Blocked'
            WHEN 4 THEN 'Unverified'
            WHEN 5 THEN 'Verified'
            WHEN 6 THEN 'Verification Pending'
            WHEN 7 THEN 'Disabled'
        END AS member_status,        
        CASE M.app_status
            WHEN 1 THEN 'Inactive'
            WHEN 2 THEN 'Onboarding'
            WHEN 3 THEN 'Active'
        END AS member_app_status,
        CASE M.funnel
            WHEN 1 THEN 'Tiers_v1'
            WHEN 2 THEN 'Church'
        END AS member_funnel,
        CASE M.push_notifications_status
            WHEN 1 THEN 'Unknown'
            WHEN 2 THEN 'Denied'
            WHEN 3 THEN 'Accepted'
        END AS member_push_notification_status,
        CASE M.tier_type
            WHEN 1 THEN 'Digital First'
            WHEN 2 THEN 'Hybrid'
            WHEN 3 THEN 'Expert-led Journey'
            WHEN 4 THEN 'Couples'
            WHEN 5 THEN 'Couples biweekly'
        END AS member_tier,
        M.primary_member_id,    
        COALESCE(fp.frozen_is_primary, M.primary_member_id IS NULL) AS is_primary,
        M2.email                                                    AS primary_member_email,
        CONCAT(M2.first_name, ' ', M2.last_name)                    AS primary_member_full_name,
        M2.uuid                                                     AS primary_member_uuid,
        M2.created_at                                               AS primary_member_joined_at,
        CONCAT(E2.first_name, ' ', E2.last_name)                    AS primary_member_expert_full_name,          
        M.module_id,
        M.account_id,
        CASE A.status
            WHEN 1 THEN 'Active'
            WHEN 2 THEN 'Inactive'
            WHEN 3 THEN 'Paused'
            WHEN 4 THEN 'Reactivation Requested'
            ELSE 'Inactive'
        END AS account_status,          
        CASE
            WHEN A.status = 3 THEN 'Paused'
            WHEN M.status IN (1, 5) THEN 'Active'
            ELSE 'Canceled'
        END                                                     AS subscription_status, -- not very reliable
        A.updated_at                                            AS subscription_account_updated_at,
        P.plan_name                                             AS member_plan,
        P.plan_month_length                                     AS member_plan_duration,
        M.timezone AS member_timezone,
        M.geo_country AS member_country,
        M.geo_state AS member_state,
        MAX(MS.subscription_created_at) OVER(PARTITION BY CASE WHEN M.primary_member_id IS NULL THEN M.id ELSE M.primary_member_id END) AS subscription_created_at,  -- forward filling all values for primary member partition      
        CASE
            WHEN P.billing_cycle_type = 1 THEN '28-day'
            ELSE 'Monthly'
        END                                                     AS subscription_billing_type,
        IP.utm_campaign AS initial_utm_campaign,
        IP.utm_medium AS initial_utm_medium,
        IP.utm_source AS initial_utm_source,
        LCP.crm_campaign AS last_crm_campaign,
        LCP.crm_medium AS last_crm_medium,
        LCP.crm_content AS last_crm_content,
        LCP.crm_source AS last_crm_source,
        IA.attribution_campaign,        
        IA.attribution_medium,
        IA.attribution_source,
        COALESCE(LP.utm_campaign, S.customer_utm_campaign, IP.utm_campaign) AS utm_campaign,
        COALESCE(LP.utm_medium, S.customer_utm_medium, IP.utm_medium) AS utm_medium,
        COALESCE(LP.utm_source, S.customer_utm_source, IP.utm_source) AS utm_source,
        COALESCE(AM.is_activated, FALSE) AS is_activated,
        AM.activated_at AS activated_at,
        M.created_at,
        M.updated_at,
        M.is_deleted,
        M.fivetran_synced_at        
    FROM webapp_member AS M     
    LEFT JOIN frozen_primary fp ON M.id = fp.id
    LEFT JOIN webapp_expert AS E ON M.expert_id = E.id
    LEFT JOIN webapp_account AS A ON M.account_id = A.id
    LEFT JOIN webapp_plan AS P ON A.member_plan_id = P.id
    LEFT JOIN initial_utm_params AS IP ON M.uuid = IP.user_id
    LEFT JOIN last_crm_params AS LCP ON M.uuid = LCP.user_id
    LEFT JOIN initial_attribution_params AS IA ON M.uuid = IA.user_id
    LEFT JOIN last_utm_params_before_subscription AS LP ON M.uuid = LP.user_id
    LEFT JOIN first_subscriptions_filtered AS S ON M.uuid = S.customer_uuid
    LEFT JOIN max_subcription_created AS MS ON M.uuid = MS.customer_uuid
    LEFT JOIN webapp_member AS M2 ON M.primary_member_id = M2.id
    LEFT JOIN webapp_expert AS E2 ON M2.expert_id = E2.id
    LEFT JOIN activated_members AS AM ON M.uuid = AM.uuid

)

SELECT * FROM final
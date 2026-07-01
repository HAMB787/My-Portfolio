{{ config(
    materialized='table',
    partition_by={
        'field': 'created_at',
        'data_type': 'timestamp',
        "granularity": "day"
    },
    cluster_by=['event_name', 'user_id'],
    partition_expiration_days = 9999
) }}


WITH

old_flow_events AS (SELECT * FROM {{ ref('fct_platform_events_old') }}),
new_flow_events AS (SELECT * FROM {{ ref('fct_platform_events_new') }}),
expert_list AS (

    SELECT DISTINCT email FROM {{ ref('stg_postgre_rds__webapp_expert') }}
    WHERE schedule_link LIKE '%https://calendly.com/ritual-schedule/%'
        AND email NOT IN ('efrat.aran@ourritual.com', 'noah@heyritual.com')

),

unioned AS (

    SELECT 
        id,
        created_at,        
        user_id,
        anonymous_id,
        event_name,
        user_email,
        source_platform,
        source_version,
        device_user_agent,
        device_type,
        device_os,
        device_version,
        geo_country,
        geo_state,
        geo_iso_code,
        geo_ip,
        geo_locale,
        geo_timezone,
        utm_source,
        utm_medium,
        utm_campaign,
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,        
        TO_JSON_STRING(payload) AS payload,
        device_uuid 
    FROM new_flow_events AS E
    WHERE created_at >= '{{ var('no_code_switch') }}'

    UNION ALL 

    SELECT 
        id,
        created_at,        
        user_id,
        anonymous_id,
        event_name,
        user_email,
        source_platform,
        source_version,
        device_user_agent,
        device_type,
        device_os,
        device_version,
        geo_country,
        geo_state,
        geo_iso_code,
        geo_ip,
        geo_locale,
        geo_timezone,
        utm_source,
        utm_medium,
        utm_campaign,
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,        
        payload,
        device_uuid   
    FROM old_flow_events
    WHERE created_at < '{{ var('no_code_switch') }}'

),

final_test_filtered AS ( -- filtering test data

    SELECT * FROM unioned
    WHERE user_email IS NULL
        OR (
            user_email IS NOT NULL
            AND user_email NOT LIKE '%heyritual.com%'
            AND user_email NOT LIKE '%ourritual.com%'
        )
        OR (
            user_email IN (SELECT email FROM expert_list)
        )

),


unioned_after_test_filter AS (

    SELECT 
        id,
        created_at,        
        MAX(user_id) OVER(PARTITION BY anonymous_id) AS user_id,
        anonymous_id,
        event_name,
        user_email,
        source_platform,
        source_version,
        device_user_agent,
        device_type,
        device_os,
        device_version,
        geo_country,
        geo_state,
        geo_iso_code,
        geo_ip,
        geo_locale,
        geo_timezone,
        CASE 
            WHEN utm_source IS NULL OR utm_source IN ('', 'NA') THEN 'organic'
            ELSE utm_source
        END AS utm_source,
        CASE 
            WHEN utm_medium IS NULL OR utm_medium IN ('', 'NA') THEN 'organic'
            ELSE utm_medium
        END AS utm_medium,
        CASE 
            WHEN utm_campaign IS NULL OR utm_campaign IN ('', 'NA') THEN 'organic'
            ELSE utm_campaign
        END AS utm_campaign,
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,        
        payload,
        device_uuid    
    FROM final_test_filtered
    WHERE anonymous_id IS NOT NULL

    UNION ALL 

    SELECT 
        id,
        created_at,        
        user_id,
        anonymous_id,
        event_name,
        user_email,
        source_platform,
        source_version,
        device_user_agent,
        device_type,
        device_os,
        device_version,
        geo_country,
        geo_state,
        geo_iso_code,
        geo_ip,
        geo_locale,
        geo_timezone,
        CASE 
            WHEN utm_source IS NULL OR utm_source IN ('', 'NA') THEN 'organic'
            ELSE utm_source
        END AS utm_source,
        CASE 
            WHEN utm_medium IS NULL OR utm_medium IN ('', 'NA') THEN 'organic'
            ELSE utm_medium
        END AS utm_medium,
        CASE 
            WHEN utm_campaign IS NULL OR utm_campaign IN ('', 'NA') THEN 'organic'
            ELSE utm_campaign
        END AS utm_campaign,
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,        
        payload,
        device_uuid    
    FROM final_test_filtered
    WHERE anonymous_id IS NULL    


),

all_events_filtered_attribution AS (

    SELECT
        *
    FROM unioned_after_test_filter
    WHERE anonymous_id IS NOT NULL
        AND utm_source IS NOT NULL 
        AND utm_source <> 'NA' 
        AND utm_source NOT IN ('cio', 'customerio', 'smart_recover')

),

top_five_utm_param_rows_attribution AS (

    SELECT
        anonymous_id,
        utm_campaign,
        utm_medium,
        utm_source
    FROM all_events_filtered_attribution
    WHERE anonymous_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER(PARTITION BY anonymous_id ORDER BY created_at ASC) <= 5

),
    
initial_attribution_source AS (

    SELECT 
        anonymous_id, 
        utm_source AS attribution_source
    FROM
        (
            SELECT anonymous_id,
                utm_source,
                count(*) AS total
            FROM top_five_utm_param_rows_attribution
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY anonymous_id ORDER BY total DESC) = 1

),

initial_attribution_campaign AS (

    SELECT 
        anonymous_id, 
        utm_campaign AS attribution_campaign
    FROM
        (
            SELECT anonymous_id,
                utm_campaign,
                count(*) AS total
            FROM top_five_utm_param_rows_attribution
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY anonymous_id ORDER BY total DESC) = 1

),

initial_attribution_medium AS (

    SELECT 
        anonymous_id, 
        utm_medium AS attribution_medium
    FROM
        (
            SELECT anonymous_id,
                utm_medium,
                count(*) AS total
            FROM top_five_utm_param_rows_attribution
            group by 1, 2
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY anonymous_id ORDER BY total DESC) = 1

),

initial_attribution_params AS (

    SELECT S.anonymous_id,
        S.attribution_source,
        C.attribution_campaign,
        M.attribution_medium
    FROM initial_attribution_source AS S
    INNER JOIN initial_attribution_campaign AS C ON S.anonymous_id = C.anonymous_id
    INNER JOIN initial_attribution_medium AS M ON S.anonymous_id = M.anonymous_id

)

,

final AS (

    SELECT A.*,
        B.attribution_source,
        B.attribution_medium,
        B.attribution_campaign
    FROM unioned_after_test_filter AS A
    LEFT JOIN initial_attribution_params AS B ON A.anonymous_id = B.anonymous_id


)

SELECT * FROM final
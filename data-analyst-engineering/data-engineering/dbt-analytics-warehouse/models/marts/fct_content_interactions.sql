{{ config(
    materialized='table'
)}}


WITH 

content_interaction_events_old AS (
    SELECT 
        id,
        created_at,
        user_id,
        CASE 
            WHEN event_name = 'member_content_clicked' AND JSON_EXTRACT_SCALAR(payload, '$.place') = 'homepage' THEN 'banner_monthlytopic_clicked'
            ELSE event_name
        END AS event_name,
        payload
    FROM {{ ref('stg_pubsub__events_historical') }}
    WHERE event_name IN 
            (
            'banner_monthlytopic_clicked',                
            'banner_monthlytopic_closed',
            'member_content_clicked',
            'member_content_closed',
            'member_content_completed'
            )
        AND created_at < '{{ var('no_code_switch') }}'
),

content_interaction_events AS (
    SELECT 
        id,
        created_at,
        user_id,
        CASE 
            WHEN event_name = 'member_content_clicked' AND JSON_EXTRACT_SCALAR(payload, '$.place') = 'homepage' THEN 'banner_monthlytopic_clicked'
            ELSE event_name
        END AS event_name,
        payload    
    FROM {{ ref('stg_pubsub__events') }}
    WHERE event_name IN 
            (
            'banner_monthlytopic_clicked',
            'banner_monthlytopic_closed',
            'member_content_clicked',
            'member_content_closed',
            'member_content_completed'
            )
        AND created_at >= '{{ var('no_code_switch') }}'
),

final AS (

    SELECT 
        id,
        created_at,
        user_id,
        event_name,
        JSON_EXTRACT_SCALAR(payload, '$.topic_id')              AS topic_id,
        JSON_EXTRACT_SCALAR(payload, '$.topic_title')           AS topic_title,
        JSON_EXTRACT_SCALAR(payload, '$.content_id')            AS content_id,
        JSON_EXTRACT_SCALAR(payload, '$.content_title')         AS content_title
    FROM content_interaction_events_old

    UNION ALL

    SELECT 
        id,
        created_at,
        user_id,
        event_name,
        JSON_EXTRACT_SCALAR(payload, '$.topic_id')              AS topic_id,
        JSON_EXTRACT_SCALAR(payload, '$.topic_title')           AS topic_title,
        JSON_EXTRACT_SCALAR(payload, '$.content_id')            AS content_id,
        JSON_EXTRACT_SCALAR(payload, '$.content_title')         AS content_title
    FROM content_interaction_events

)

SELECT * FROM final
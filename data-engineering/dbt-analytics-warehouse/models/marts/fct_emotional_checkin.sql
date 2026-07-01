WITH

emotional_checkin_started AS (
    SELECT * ,
        ROW_NUMBER() OVER(PARTITION BY checkin_id ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_segment_native_app__member_emotional_checkin_started') }}
    WHERE checkin_id IS NOT NULL
        AND created_at < '{{ var('no_code_switch') }}'
),

emotional_checkin_selected AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY checkin_id ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_segment_native_app__member_emotional_checkin_selection') }}
    WHERE checkin_id IS NOT NULL
        AND created_at < '{{ var('no_code_switch') }}'   
),

emotional_checkin_completed AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY checkin_id ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_segment_native_app__member_emotional_checkin_completed') }}
    WHERE checkin_id IS NOT NULL
        AND created_at < '{{ var('no_code_switch') }}'  
),

emotional_checkin_started_new AS (

    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY JSON_EXTRACT_SCALAR(payload, '$.checkin_id') ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_pubsub__events') }}
    WHERE event_name = 'member_emotional_checkin_started'
        AND created_at >= '{{ var('no_code_switch') }}'

),


emotional_checkin_selection_new AS (

    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY JSON_EXTRACT_SCALAR(payload, '$.checkin_id') ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_pubsub__events') }}
    WHERE event_name = 'member_emotional_checkin_selection'
        AND created_at >= '{{ var('no_code_switch') }}'

),


emotional_checkin_completed_new AS (

    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY JSON_EXTRACT_SCALAR(payload, '$.checkin_id') ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_pubsub__events') }}
    WHERE event_name = 'member_emotional_checkin_completed'
        AND created_at >= '{{ var('no_code_switch') }}'

),

checkin_started_transformed AS (

    SELECT 
        S.checkin_id,
        S.user_id,
        S.created_at                                        AS started_at,
        S.location                                          AS app_location,
        SPLIT(locale, '-')[OFFSET(1)]                       AS country,
        S.os_name                                           AS device_os,
        S.os_version                                        AS device_version
    FROM emotional_checkin_started AS S
    WHERE S.rnk = 1

    UNION ALL

    SELECT
        JSON_EXTRACT_SCALAR(S.payload, '$.checkin_id')        AS checkin_id,
        S.user_id,
        S.created_at                                          AS started_at,
        JSON_EXTRACT_SCALAR(S.payload, '$.location')          AS app_location,
        S.geo_country                                         AS country,
        S.device_os,
        S.device_version
    FROM emotional_checkin_started_new AS S
    WHERE rnk = 1

),

checkin_selection_transformed AS (

    SELECT
        SL.checkin_id,
        SL.created_at                                           AS selected_at,
        REPLACE(SPLIT(REPLACE(REPLACE(SL.suggested_emotions, '[', ''), ']', ''), ',')[SAFE_OFFSET(0)], '"', '') AS suggested_emotion_1,
        REPLACE(SPLIT(REPLACE(REPLACE(SL.suggested_emotions, '[', ''), ']', ''), ',')[SAFE_OFFSET(1)], '"', '') AS suggested_emotion_2,
        REPLACE(SPLIT(REPLACE(REPLACE(SL.suggested_emotions, '[', ''), ']', ''), ',')[SAFE_OFFSET(2)], '"', '') AS suggested_emotion_3,
        REPLACE(SPLIT(REPLACE(REPLACE(SL.suggested_emotions, '[', ''), ']', ''), ',')[SAFE_OFFSET(3)], '"', '') AS suggested_emotion_4,
        REPLACE(SPLIT(REPLACE(REPLACE(SL.suggested_emotions, '[', ''), ']', ''), ',')[SAFE_OFFSET(4)], '"', '') AS suggested_emotion_5,

        -- Extract names
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(REPLACE(REPLACE(SL.selected_emotions, '[', ''), ']', ''), r'},\{', '}\n{'))[SAFE_OFFSET(0)], r'"name":"([^"]+)"') AS selected_emotion_name_1,
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(REPLACE(REPLACE(SL.selected_emotions, '[', ''), ']', ''), r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"name":"([^"]+)"') AS selected_emotion_name_2,
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(REPLACE(REPLACE(SL.selected_emotions, '[', ''), ']', ''), r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"name":"([^"]+)"') AS selected_emotion_name_3,

        -- Extract types - here we take from 1 to 4 index because name and type are getting splitted
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(SL.selected_emotions, r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"type"\s*:\s*"([^"]+)"') AS selected_emotion_type_1,
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(SL.selected_emotions, r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"type"\s*:\s*"([^"]+)"') AS selected_emotion_type_2,
        REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(SL.selected_emotions, r'},\{', '}\n{'))[SAFE_OFFSET(3)], r'"type"\s*:\s*"([^"]+)"') AS selected_emotion_type_3 
    FROM emotional_checkin_selected AS SL
    WHERE SL.rnk = 1

    UNION ALL

    SELECT 
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.checkin_id') AS STRING)                                AS checkin_id,
        SL.created_at                                                                                  AS selected_at,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.suggested_emotions[0]') AS STRING)                     AS suggested_emotion_1,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.suggested_emotions[1]') AS STRING)                     AS suggested_emotion_2,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.suggested_emotions[2]') AS STRING)                     AS suggested_emotion_3,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.suggested_emotions[3]') AS STRING)                     AS suggested_emotion_4,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.suggested_emotions[4]') AS STRING)                     AS suggested_emotion_5,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[0].name') AS STRING)                 AS selected_emotion_name_1,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[1].name') AS STRING)                 AS selected_emotion_name_2,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[2].name') AS STRING)                 AS selected_emotion_name_3,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[0].type') AS STRING)                 AS selected_emotion_type_1,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[1].type') AS STRING)                 AS selected_emotion_type_2,
        CAST(JSON_EXTRACT_SCALAR(SL.payload, '$.selected_emotions[2].type') AS STRING)                 AS selected_emotion_type_3             
    FROM emotional_checkin_selection_new AS SL
    WHERE SL.rnk = 1

),

checkin_completed_transformed AS (

    SELECT 
        C.checkin_id,
        C.created_at                                                        AS completed_at,
        CASE
            WHEN
            COALESCE(
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"key"\s*:\s*"([^"]+)"'),
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"key"\s*:\s*"([^"]+)"')
            ) = 'shared_expert'
            OR
            COALESCE(
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"key"\s*:\s*"([^"]+)"'),
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"key"\s*:\s*"([^"]+)"')
            ) = 'shared_expert'            
            THEN TRUE
            ELSE FALSE
        END                                                                                                             AS is_shared_with_expert,
        CASE
            WHEN
            COALESCE(
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"key"\s*:\s*"([^"]+)"'),
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"key"\s*:\s*"([^"]+)"')
            ) = 'shared_member'
            OR
            COALESCE(
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(2)], r'"key"\s*:\s*"([^"]+)"'),
                REGEXP_EXTRACT(SPLIT(REGEXP_REPLACE(C.sharing_details, r'},\{', '}\n{'))[SAFE_OFFSET(1)], r'"key"\s*:\s*"([^"]+)"')
            ) = 'shared_member'            
            THEN TRUE
            ELSE FALSE
        END                                                                                                             AS is_shared_with_member
    FROM emotional_checkin_completed AS C
    WHERE C.rnk = 1

    UNION ALL

    SELECT 
        CAST(JSON_EXTRACT_SCALAR(C.payload, '$.checkin_id') AS STRING)                  AS checkin_id,
        C.created_at                                                                    AS completed_at,
        CASE
            WHEN
            COALESCE(
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[0].key'),
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[1].key')
            ) = 'shared_expert'
            OR
            COALESCE(
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[1].key'),
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[0].key')
            ) = 'shared_expert'            
            THEN TRUE
            ELSE FALSE
        END                                                                                                             AS is_shared_with_expert,
        CASE
            WHEN
            COALESCE(
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[0].key'),
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[1].key')
            ) = 'shared_member'
            OR
            COALESCE(
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[1].key'),
                JSON_EXTRACT_SCALAR(C.payload, '$.sharing_details[0].key')
            ) = 'shared_member'            
            THEN TRUE
            ELSE FALSE
        END                                                                                                             AS is_shared_with_member
    FROM emotional_checkin_completed_new AS C
    WHERE C.rnk = 1    

),

final AS (

    SELECT 
        ST.checkin_id,
        ST.user_id,
        ST.started_at,
        ST.app_location,
        ST.country,
        ST.device_os,
        ST.device_version,
        SL.selected_at,
        SL.suggested_emotion_1,
        SL.suggested_emotion_2,
        SL.suggested_emotion_3,
        SL.suggested_emotion_4,
        SL.suggested_emotion_5,
        SL.selected_emotion_name_1,
        SL.selected_emotion_name_2,
        SL.selected_emotion_name_3,
        SL.selected_emotion_type_1,
        SL.selected_emotion_type_2,
        SL.selected_emotion_type_3,
        C.completed_at,
        C.is_shared_with_expert,
        C.is_shared_with_member
    FROM checkin_started_transformed AS ST
    LEFT JOIN checkin_selection_transformed AS SL ON ST.checkin_id = SL.checkin_id
    LEFT JOIN checkin_completed_transformed AS C ON SL.checkin_id = C.checkin_id

)


SELECT * FROM final
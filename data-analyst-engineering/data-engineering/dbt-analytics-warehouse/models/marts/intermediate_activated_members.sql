{{ config(
    materialized='table'
)}}


/*

Business logic & Formula of "Activated Member"

A - 14 days passers
B - 1 session complete
C - schedule 2nd session
D - significant app users
E - partner inviters
F - complete 2 sessions

(A or F) & B & (C or D) & E


*/

WITH 

webapp_member AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
webapp_session AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_session') }}),
subscriptions AS (SELECT * FROM {{ ref('stg_stripe__subscription_history') }} WHERE is_fivetran_active = TRUE),
customers AS (SELECT * FROM {{ ref('stg_stripe__customer') }}),
all_events AS (SELECT * FROM {{ ref('stg_pubsub__events') }}),
plans AS (SELECT * FROM {{ ref('stg_stripe__plan') }}),
products AS (SELECT * FROM {{ ref('stg_stripe__product') }}),
subscription_items AS (
    SELECT * FROM {{ ref('stg_stripe__subscription_item') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY subscription_id ORDER BY created_at DESC) = 1
),

matching_customers AS (

    SELECT DISTINCT C.id
    FROM subscription_items AS SI
    INNER JOIN subscriptions AS S ON SI.subscription_id = S.id
    INNER JOIN customers AS C ON S.customer_id = C.id
    INNER JOIN plans AS PL ON SI.plan_id = PL.id
    INNER JOIN products AS P ON PL.product_id = P.id
    WHERE P.name = 'Matching session'

),

couple_plan_customers AS (

    SELECT DISTINCT C.id
    FROM subscription_items AS SI
    INNER JOIN subscriptions AS S ON SI.subscription_id = S.id
    INNER JOIN customers AS C ON S.customer_id = C.id
    INNER JOIN plans AS PL ON SI.plan_id = PL.id
    INNER JOIN products AS P ON PL.product_id = P.id
    WHERE CASE
       WHEN P.name = 'Ritual Membership' THEN 'Couples'
       WHEN P.name = 'Ritual - Expert Led Journey' THEN 'Individuals'
       WHEN P.name = 'Ritual - Expert Led For Couples' THEN 'Couples'
       WHEN P.name = 'Matching session' THEN 'Matching'
       WHEN P.name = 'Ritual Hybrid Experience' THEN 'Individuals'
       WHEN P.name = 'Ritual Subscription' THEN 'Couples'
       WHEN P.name = 'Ritual - Digital First' THEN 'Individuals'
       WHEN P.name LIKE '%Couple%' THEN 'Couples'
       WHEN P.name LIKE '%Individual%' THEN 'Individuals'
       ELSE 'Other'
     END = 'Couples'

),

mbg_passers AS (

SELECT 
    C.uuid,
    DATE_ADD(S.created_at, INTERVAL 14 DAY) AS mbg_passed_at
FROM subscriptions AS S
INNER JOIN customers AS C ON S.customer_id = C.id
WHERE 1=1
    AND ((S.status = 'active' AND DATE_DIFF(CURRENT_TIMESTAMP, S.created_at, DAY) >= 14) OR (status = 'canceled' AND DATE_DIFF(S.canceled_at, S.created_at, DAY) >= 14))
    AND S.customer_id IS NOT NULL
    AND C.id NOT IN (SELECT id FROM matching_customers)

),

-- 1 session schedulers

first_sessions_completers AS (

SELECT 
    M.uuid,
    S.created_at AS first_session_completed_at
FROM webapp_session AS S
INNER JOIN webapp_member AS M ON S.member_id = M.id
WHERE S.status = 2
QUALIFY
    ROW_NUMBER() OVER(PARTITION BY M.uuid ORDER BY S.created_at) = 1

),

second_sessions_completers AS (

SELECT 
    M.uuid,
    S.created_at AS second_session_completed_at
FROM webapp_session AS S
INNER JOIN webapp_member AS M ON S.member_id = M.id
WHERE S.status = 2
QUALIFY
    ROW_NUMBER() OVER(PARTITION BY M.uuid ORDER BY S.created_at) = 2

),

second_sessions_schedulers AS (

SELECT 
    M.uuid,
    S.created_at AS second_session_scheduled_at
FROM webapp_session AS S
INNER JOIN webapp_member AS M ON S.member_id = M.id
WHERE S.status = 3
QUALIFY
    ROW_NUMBER() OVER(PARTITION BY M.uuid ORDER BY S.created_at) = 2

),

partner_inviters AS (

SELECT user_id AS uuid,
    MIN(created_at) AS partner_invited_at
FROM all_events
WHERE event_name IN ('invite_partner_complete', 'partner_form_filled')
    AND user_id IS NOT NULL
GROUP BY ALL

),

significant_activity_doers AS (

    SELECT A.uuid,
        MIN(A.activity_ts) AS activity_done_at
    FROM 
    (
    -- Wistia (exclude Expert Onboarding)
    SELECT M.uuid,
            received_at AS activity_ts
    FROM {{ ref('stg_wistia__event_list') }} AS E
    INNER JOIN {{ ref('stg_postgre_rds__webapp_member') }} AS M ON LOWER(E.email) = LOWER(M.email)

    UNION ALL
    -- Questionnaire
    SELECT uuid,
            survey_started_at AS activity_ts
    FROM {{ ref('fct_questionnaire_answers') }}
    WHERE uuid IS NOT NULL

    UNION ALL
    -- Journaling
    SELECT dm.uuid,
            vj.updated_at AS activity_ts
    FROM  {{ ref('stg_postgre_rds__webapp_membergrowthwork_videoask') }} vj
    INNER JOIN {{ ref('stg_postgre_rds__webapp_member') }} dm ON dm.id = vj.member_id

    UNION ALL
    -- Topic of month historical
    SELECT user_id AS uuid,
            created_at AS activity_ts
        FROM {{ ref('stg_pubsub__events_historical') }}
        WHERE event_name = 'member_content_completed'
            AND created_at < '{{ var('no_code_switch') }}'

    UNION ALL
    -- Topic of month current
    SELECT user_id AS uuid,
            created_at AS activity_ts
        FROM {{ ref('stg_pubsub__events') }}
        WHERE event_name = 'member_content_completed'
            AND created_at >= '{{ var('no_code_switch') }}'

    UNION ALL
    -- app events
    SELECT user_id AS uuid,
            created_at AS activity_ts
        FROM {{ ref('stg_pubsub__events') }}
        WHERE created_at >= '{{ var('no_code_switch') }}'
            AND (
                event_name LIKE '%member_sent_message%' OR 
                event_name LIKE '%member_message_sent%' OR
                (event_name LIKE '%member_content_clicked%' AND JSON_EXTRACT_SCALAR(payload, '$.expertrec') = 'true') OR
                event_name LIKE '%message_read%' OR
                event_name IN ('member_emotional_checkin_completed', 'member_content_completed')
            )
    ) A
    GROUP BY 1

),

member_flags AS (
    SELECT
        M.uuid,

        -- Raw timestamps from each segment
        A.mbg_passed_at,                    -- A: 14 days passers
        B.first_session_completed_at,       -- B: 1st session complete
        C.second_session_scheduled_at,      -- C: 2nd session scheduled
        D.activity_done_at,                 -- D: significant app activity
        E.partner_invited_at,               -- E: partner invited
        F.second_session_completed_at,      -- F: 2nd session complete

        -- MBG timestamp: first time MBG condition was true (A ∪ F)
        LEAST(
            A.mbg_passed_at,
            F.second_session_completed_at
        ) AS mbg_ts,

        -- Engagement timestamp: first time engagement condition was true (C ∪ D)
        LEAST(
            C.second_session_scheduled_at,
            D.activity_done_at
        ) AS engagement_ts,

        -- Activation flag: (A OR F) & B & (C OR D) & E
        CASE
            WHEN
                -- (A OR F)
                (A.mbg_passed_at IS NOT NULL OR F.second_session_completed_at IS NOT NULL)
                -- & B
                AND B.first_session_completed_at IS NOT NULL
                -- & (C OR D)
                AND (C.second_session_scheduled_at IS NOT NULL OR D.activity_done_at IS NOT NULL)
                -- & E
                AND (E.partner_invited_at IS NOT NULL OR E1.id IS NULL)
            THEN TRUE ELSE FALSE
        END AS is_activated
    FROM webapp_member AS M
    LEFT JOIN mbg_passers                AS A ON M.uuid = A.uuid
    LEFT JOIN first_sessions_completers  AS B ON M.uuid = B.uuid
    LEFT JOIN second_sessions_schedulers AS C ON M.uuid = C.uuid
    LEFT JOIN significant_activity_doers AS D ON M.uuid = D.uuid
    LEFT JOIN partner_inviters           AS E ON M.uuid = E.uuid
    LEFT JOIN couple_plan_customers      AS E1 ON M.uuid = E1.id -- couple plan case
    LEFT JOIN second_sessions_completers AS F ON M.uuid = F.uuid
),

dedup AS (

    SELECT uuid,
        MIN(mbg_passed_at) AS mbg_passed_at,
        MIN(first_session_completed_at) AS first_session_completed_at,
        MIN(second_session_scheduled_at) AS second_session_scheduled_at,
        MIN(second_session_completed_at) AS second_session_completed_at,
        MIN(partner_invited_at) AS partner_invited_at,
        MIN(activity_done_at) AS activity_done_at,
        MIN(mbg_ts) AS mbg_ts,
        MIN(engagement_ts) AS engagement_ts,
        MAX(is_activated) AS is_activated
    FROM member_flags
    GROUP BY 1

),

final AS (
    SELECT
        uuid,
        mbg_passed_at,
        first_session_completed_at,
        second_session_scheduled_at,
        second_session_completed_at,
        partner_invited_at,
        activity_done_at,
        is_activated,
        CASE
            WHEN is_activated = TRUE THEN
                -- Moment when ALL conditions are satisfied:
                -- (A or F), B, (C or D), E
                GREATEST(
                    COALESCE(mbg_ts, '1900-01-01 00:00:00'),
                    COALESCE(first_session_completed_at, '1900-01-01 00:00:00'),
                    COALESCE(engagement_ts, '1900-01-01 00:00:00'),
                    COALESCE(partner_invited_at, '1900-01-01 00:00:00')
                )
            ELSE NULL
        END AS activated_at
    FROM dedup
)

SELECT * from final
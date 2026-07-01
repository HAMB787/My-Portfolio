{{ config(
    materialized='incremental',
    unique_key='unique_sk',
    incremental_strategy='merge'
)}}


WITH

current_day_info AS (
    SELECT
        CURRENT_DATE() AS today,
        EXTRACT(DAYOFWEEK FROM CURRENT_DATE()) AS today_dow  -- 1 (Sunday) to 7 (Saturday)
),
weekdays AS (
    SELECT
        LOWER(FORMAT_DATE('%A', d)) AS weekday,
        EXTRACT(DAYOFWEEK FROM d) AS dow,
        d AS date
    FROM UNNEST(GENERATE_DATE_ARRAY(CURRENT_DATE(), DATE_ADD(CURRENT_DATE(), INTERVAL 39 DAY))) AS d
),
time_slots AS (
    SELECT
        FORMAT('%02d:%02d', hour, minute) AS slot_start,
        FORMAT('%02d:%02d',
            CASE
                WHEN hour = 23 AND minute = 55 THEN 23
                WHEN minute + 5 >= 60 THEN MOD(hour + 1, 24)
                ELSE hour
            END,
            CASE
                WHEN hour = 23 AND minute = 55 THEN 59
                ELSE MOD(minute + 5, 60)
            END
        ) AS slot_end
    FROM (
        SELECT
            hour,
            minute
        FROM
            UNNEST(GENERATE_ARRAY(0, 23)) AS hour,
            UNNEST(GENERATE_ARRAY(0, 55, 5)) AS minute
    )
),
current_availability AS (
    SELECT *
    FROM {{ ref('stg_calendly__user_availability_schedules') }} 
    WHERE rnk = 1
        AND type = 'wday' 
        AND name = 'Working hours'
),
users AS (
    SELECT * FROM {{ ref('stg_calendly__users') }} 
),
events AS (
    SELECT *,
      DATE(start_time) AS start_date_part,
      FORMAT_TIMESTAMP('%H:%M', start_time) AS start_time_part,
      DATE(
        CASE 
          WHEN EXTRACT(HOUR FROM end_time) = 0 
               AND EXTRACT(MINUTE FROM end_time) = 0 
               AND EXTRACT(SECOND FROM end_time) = 0
          THEN TIMESTAMP_SUB(end_time, INTERVAL 1 SECOND)
          ELSE end_time
        END
      ) AS end_date_part,
      
      FORMAT_TIMESTAMP('%H:%M',
        CASE 
          WHEN EXTRACT(HOUR FROM end_time) = 0 
               AND EXTRACT(MINUTE FROM end_time) = 0 
               AND EXTRACT(SECOND FROM end_time) = 0
          THEN TIMESTAMP_SUB(end_time, INTERVAL 1 SECOND)
          ELSE end_time
        END
      ) AS end_time_part
      
    FROM {{ ref('stg_calendly__events') }} 
),
busy_times AS (
    SELECT *,
      DATE(start_time) AS start_date_part,
      FORMAT_TIMESTAMP('%H:%M', start_time) AS start_time_part,
      DATE(end_time) AS end_date_part,
      FORMAT_TIMESTAMP('%H:%M', end_time) AS end_time_part
    FROM {{ ref('stg_calendly__user_busy_times') }} 
    WHERE 
        type = 'external'
),

experts AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_expert') }}),

main AS (

SELECT
    u.id AS user_id,
    u.name,
    u.email,
    u.timezone,
    w.weekday,
    w.date,
    t.slot_start,
    t.slot_end
FROM
    users AS u
CROSS JOIN
    weekdays AS w
CROSS JOIN
    time_slots AS t
CROSS JOIN
    current_day_info AS c
ORDER BY
    u.id,
    date,
    t.slot_start

),

calculated AS (

    SELECT 
        DATE(CURRENT_DATE) AS created_at,
        M.user_id,
        M.name,
        M.email,
        EX.uuid,
        M.timezone,
        M.weekday,
        M.date,
        M.slot_start,
        M.slot_end,
        CASE
            WHEN MAX(CA.id) IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                         AS is_working_hour,
        CASE
            WHEN MAX(E.id) IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                         AS is_meeting_scheduled,
        MAX(E.name)                                                 AS meeting_title,
        MAX(E.status)                                               AS meeting_status,
        CASE
            WHEN MAX(B.user_id) IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                         AS is_time_off
    FROM main AS M
    LEFT JOIN current_availability AS CA ON M.user_id = CA.user_id
        AND M.weekday = CA.wday
        AND (M.slot_start >= CA.available_from AND M.slot_end <= CA.available_to)
    LEFT JOIN events AS E ON M.user_id = E.user_id
        AND M.date = E.start_date_part
        AND (M.slot_start >= E.start_time_part AND M.slot_end <= E.end_time_part)
    LEFT JOIN busy_times AS B ON M.user_id = B.user_id
        AND M.date = B.start_date_part
        AND (M.slot_start >= B.start_time_part AND M.slot_end <= B.end_time_part)
    LEFT JOIN experts AS EX ON M.email = EX.email
    GROUP BY 1,2,3,4,5,6,7,8,9,10

),

added_flags AS (

    SELECT *,
        CASE
            WHEN is_meeting_scheduled THEN 'in_meeting'
            WHEN NOT is_working_hour THEN 'off_hours'
            WHEN is_time_off THEN 'on_leave'
            WHEN is_working_hour AND NOT is_time_off AND NOT is_meeting_scheduled THEN 'available'
        END AS availability_status
    FROM calculated

),

slots_calculated_grouped AS (

SELECT created_at,
    user_id,
    uuid,
    name,
    email,
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) = 0 AND is_working_hour AND NOT is_time_off THEN 1 ELSE 0 END) AS total_slots_current_day,
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) = 0 AND availability_status = 'available' THEN 1 ELSE 0 END) AS total_available_slots_current_day, 
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) <= 6 AND is_working_hour AND NOT is_time_off THEN 1 ELSE 0 END) AS total_slots_forward_week,
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) <= 6 AND availability_status = 'available' THEN 1 ELSE 0 END) AS total_available_slots_forward_week, 
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) <= 30 AND is_working_hour AND NOT is_time_off THEN 1 ELSE 0 END) AS total_slots_forward_month,
    SUM(CASE WHEN DATE_DIFF(date, created_at, DAY) <= 30 AND availability_status = 'available' THEN 1 ELSE 0 END) AS total_available_slots_forward_month
FROM added_flags
GROUP BY 1,2,3,4,5

),

final AS (

SELECT 
    SHA256(CONCAT(created_at, user_id)) AS unique_sk,
    created_at,
    user_id,
    uuid,
    name,
    email,
    total_slots_current_day,
    total_available_slots_current_day,
    total_slots_forward_week,
    total_available_slots_forward_week,
    total_slots_forward_month,
    total_available_slots_forward_month,
    SAFE_DIVIDE(total_available_slots_current_day, total_slots_current_day)   AS availability_ratio_current_day,
    SAFE_DIVIDE(total_available_slots_forward_week, total_slots_forward_week)   AS availability_ratio_forward_week,
    SAFE_DIVIDE(total_available_slots_forward_month, total_slots_forward_month)   AS availability_ratio_forward_month
FROM slots_calculated_grouped

)

SELECT * FROM final
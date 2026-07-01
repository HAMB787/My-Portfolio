{{ config(
    materialized='table'
)}}


WITH

current_day_info AS (
    SELECT
        CURRENT_DATE() AS today,
        EXTRACT(DAYOFWEEK FROM CURRENT_DATE()) AS today_dow  -- 1 (Sunday) to 7 (Saturday)
),
weekdays AS (
    SELECT
        weekday,
        dow
    FROM UNNEST([
        STRUCT('sunday'    AS  weekday,  1   AS dow),
        STRUCT('monday'    AS  weekday,  2   AS dow),
        STRUCT('tuesday'   AS  weekday,  3   AS dow),
        STRUCT('wednesday' AS  weekday,  4   AS dow),
        STRUCT('thursday'  AS  weekday,  5   AS dow),
        STRUCT('friday'    AS  weekday,  6   AS dow),
        STRUCT('saturday'  AS  weekday,  7   AS dow)
    ])
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
        -- AND user_id = 'https://api.calendly.com/users/bc30483b-1ddd-42e3-9c4c-6f27b8e71318'
),
users AS (
    SELECT * FROM {{ ref('stg_calendly__users') }} 
    -- WHERE id = 'https://api.calendly.com/users/bc30483b-1ddd-42e3-9c4c-6f27b8e71318'
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
        -- user_id = 'https://api.calendly.com/users/bc30483b-1ddd-42e3-9c4c-6f27b8e71318'
        -- AND 
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
    DATE_ADD(c.today, INTERVAL MOD(w.dow - c.today_dow + 7, 7) DAY) AS date,
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

        -- For debugging

        -- CA.available_from,
        -- CA.available_to,
        -- E.start_time_part AS meeting_start_time,
        -- E.end_time_part AS meeting_end_time,
        -- B.start_time_part AS busy_start_time,
        -- B.end_time_part AS busy_end_time,

        --


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
        MAX(E.guest_email)                                          AS meeting_guest_email,
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

final AS (

    SELECT *,
        CASE
            WHEN is_meeting_scheduled THEN 'in_meeting'
            WHEN NOT is_working_hour THEN 'off_hours'
            WHEN is_time_off THEN 'on_leave'
            WHEN is_working_hour AND NOT is_time_off AND NOT is_meeting_scheduled THEN 'available'
        END AS availability_status
    FROM calculated

)

SELECT * FROM final
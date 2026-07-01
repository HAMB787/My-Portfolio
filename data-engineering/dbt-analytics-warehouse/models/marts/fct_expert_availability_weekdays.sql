{{ config(
    materialized='table'
)}}


WITH

time_slots AS (
    SELECT
        FORMAT('%02d:%02d', hour, minute) AS slot_start
    FROM
        UNNEST(GENERATE_ARRAY(0, 23)) AS hour,
        UNNEST(GENERATE_ARRAY(0, 30, 10)) AS minute
),
current_availability AS (SELECT * FROM {{ ref('stg_calendly__user_availability_schedules') }} WHERE rnk = 1 AND type = 'wday'),
users AS (SELECT * FROM {{ ref('stg_calendly__users') }}),

availabilty_enriched AS (

    SELECT 
        A.id,
        A.user_id                                       AS expert_calendly_id,
        A.name                                          AS schedule_name,
        A.timezone,
        A.wday                                          AS weekday,
        A.available_from,
        A.available_to,
        U.name                                          AS expert_name,
        U.email                                         AS expert_email,
        A.databricks_synced_at                          AS last_updated_at
    FROM current_availability AS A
    LEFT JOIN users AS U ON A.user_id = U.id

),

final AS (
    SELECT
        expert_calendly_id,
        timezone,
        expert_email,
        expert_name,
        weekday,
        available_from,
        available_to,
        slot_start AS available_slot,
        last_updated_at
    FROM time_slots AS T
    INNER JOIN availabilty_enriched AS A ON T.slot_start >= A.available_from
        AND T.slot_start < A.available_to
)

SELECT * FROM final

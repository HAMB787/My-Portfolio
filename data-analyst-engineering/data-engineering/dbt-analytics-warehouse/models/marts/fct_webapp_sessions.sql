{{ config(
    materialized='table'
)}}


WITH 

-- not joined with session links for time being

webapp_sessions AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_session') }}),

final AS (

    SELECT id,
        uuid,
        member_id,
        expert_id,
        parent_session_id,
        CASE status
            WHEN 1 THEN 'Ongoing'
            WHEN 2 THEN 'Ended'
            WHEN 3 THEN 'Scheduled'
            WHEN 4 THEN 'Canceled'
            WHEN 5 THEN 'Rescheduled'
        END AS session_status,
        CASE type
            WHEN 1 THEN 'Chat'
            WHEN 2 THEN 'Habit Tracking'
            WHEN 3 THEN 'Checkin'
            WHEN 4 THEN 'Welcome'
            WHEN 5 THEN 'Individual'
            WHEN 6 THEN 'Group'
            WHEN 7 THEN 'Supervisor'
            WHEN 8 THEN 'Supervised'
        END AS session_type,
        -- session_link,
        -- join_session_link, -- commenting out for time being
        session_ended_at,
        next_session_at,
        next_session_event_id,
        next_session_invitee_id,
        created_at,
        updated_at,
        is_deleted,
        fivetran_synced_at          
    FROM webapp_sessions

)

SELECT * FROM final
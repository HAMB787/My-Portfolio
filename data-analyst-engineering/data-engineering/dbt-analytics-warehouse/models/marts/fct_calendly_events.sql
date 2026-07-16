WITH

event AS (SELECT * FROM {{ ref('stg_calendly__event') }}),
event_user_mapping AS (SELECT * FROM {{ ref('stg_calendly__event_membership') }}),
event_type AS (SELECT * FROM {{ ref('stg_calendly__event_type') }}),
users AS (SELECT * FROM {{ ref('stg_calendly__users') }}),

final AS (

    SELECT
        MD5(COALESCE(E.id,'') || COALESCE(EU.user_id,''))   AS unique_id,
        E.id                                                AS event_id,
        E.name                                              AS event_name,    
        E.status,    
        E.location_type,    
        E.started_at,
        E.ended_at,
        EU.user_id                                          AS expert_calendly_id,
        U.name                                              AS expert_name,
        U.email                                             AS expert_email,
        U.timezone                                          AS expert_timezone,    
        E.event_type_id,            
        ET.booking_method,          
        ET.name                                             AS event_type_name,
        ET.profile_name,
        ET.profile_type,
        E.cancel_reason,
        E.canceled_by,
        E.canceler_type,
        E.is_deleted,
        E.created_at,
        E.updated_at,
        E.fivetran_synced_at
    FROM event_user_mapping AS EU
    LEFT JOIN event AS E ON EU.event_id = E.id
    LEFT JOIN event_type AS ET ON E.event_type_id = ET.id
    LEFT JOIN users AS U ON EU.user_id = U.id

)

SELECT * FROM final
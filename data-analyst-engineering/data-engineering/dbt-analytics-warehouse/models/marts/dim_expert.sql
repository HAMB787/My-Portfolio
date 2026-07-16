{{ config(
    materialized='table'
)}}


WITH 

webapp_expert AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_expert') }}),
contract_details AS (SELECT * FROM {{ ref('stg_postgre_rds__accounting_contractdetails') }} WHERE NOT is_fivetran_deleted),

final AS (

    SELECT E.id,
        E.uuid,
        E.assigned_supervisor_id,
        E2.email AS assigned_supervisor_email,
        
        E.first_name,
        E.last_name,
        CONCAT(E.first_name, ' ', E.last_name)  AS full_name,        
        E.email,
        E.phone_number,
        E.schedule_link,
        CASE E.type
            WHEN 1 THEN 'Human'
            WHEN 2 THEN 'Bot'
        END    AS expert_type,
        CD.hourly_rate,
        CD.multiplier,
        CD.onboarding_hours,
        CD.pathway_rate,
        CD.supervisee_rate,
        CD.supervisor_rate,
        CD.currency,
        CASE CD.status
            WHEN 1 THEN 'Active'
            WHEN 2 THEN 'Inactive'
        END AS contract_status,
        E.created_at,
        E.updated_at,
        E.is_deleted,
        E.fivetran_synced_at
    FROM webapp_expert AS E
    LEFT JOIN webapp_expert AS E2 ON E.assigned_supervisor_id = E2.id
    LEFT JOIN contract_details AS CD ON E.id = CD.expert_id

)

SELECT * FROM final
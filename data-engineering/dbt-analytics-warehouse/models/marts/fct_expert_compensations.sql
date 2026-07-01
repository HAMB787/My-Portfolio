{{ config(
    materialized='table'
)}}


WITH 

experts AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_expert') }}),
compensations AS (SELECT * FROM {{ ref('stg_postgre_rds__accounting_monthlyreport') }}),

final AS (

SELECT
    C.id,
    C.year_month,
    C.expert_id,
    CONCAT(E.first_name, ' ', E.last_name)              AS full_name,        
    C.uuid,
    CASE C.status
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Approved'
        WHEN 3 THEN 'Invalid'
        WHEN 4 THEN 'Processed'
    END                                                 AS report_status,
    C.total_compensation,
    C.total_compensation_with_overhead,
    C.is_deleted,
    C.is_deleted_by_cascade,
    C.created_at,
    C.updated_at,
    C.deleted_at,
    C.fivetran_synced_at
FROM compensations AS C
LEFT JOIN experts AS E ON C.expert_id = E.id

)

SELECT * FROM final
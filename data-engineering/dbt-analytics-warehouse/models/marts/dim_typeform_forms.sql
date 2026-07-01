{{ config(
    materialized='table'
)}}


WITH 

form_history AS (SELECT * FROM {{ ref('stg_typeform__form_history') }} WHERE is_active = TRUE),
workspace AS (SELECT * FROM {{ ref('stg_typeform__workspace') }}),
theme AS (SELECT * FROM {{ ref('stg_typeform__theme') }}),

final AS (

    SELECT 
        F.id,
        F.title AS form_title,
        W.name AS workspace_name,
        T.name AS theme_name,
        F.type AS form_type,
        F.last_updated_at
    FROM form_history AS F
    LEFT JOIN workspace AS W ON F.workspace_id = W.id
    LEFT JOIN theme AS T ON F.theme_id = T.id

)

SELECT * FROM final
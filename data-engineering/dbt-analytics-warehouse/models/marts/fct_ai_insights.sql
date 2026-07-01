WITH

insights AS (SELECT * FROM {{ ref('stg_postgre_rds__insights_insight') }}),
webapp_sessions AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_session') }}),


final AS (

    SELECT I.*,
        S.member_id 
    FROM insights AS I
    LEFT JOIN webapp_sessions AS S ON I.external_id = S.id
)

SELECT * FROM final
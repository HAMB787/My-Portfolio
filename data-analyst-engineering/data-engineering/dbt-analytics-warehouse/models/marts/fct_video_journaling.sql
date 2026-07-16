{{ config(
    materialized='table'
)}}


WITH 

videoask_events AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_membergrowthwork_videoask') }}),

final AS (

    SELECT
        id,
        action_id,
        expert_id,
        gw_cms_id,
        member_id,
        uuid,
        url,
        url_hash,
        growthwork_type,
        CASE status
            WHEN 1 then 'generating'
            WHEN 2 then 'created'
            WHEN 3 then 'completed'
            WHEN 4 then 'reviewed'
            WHEN 5 then 'expired'
        END                                         AS status,
        question_media_duration,
        answer_type,
        answer_media_duration,
        is_fivetran_deleted,
        is_deleted,
        created_at,
        deleted_at,
        updated_at,
        fivetran_synced_at
    FROM 
        videoask_events    

)

SELECT * FROM final
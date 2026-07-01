{{ config(
    materialized='table'
)}}


WITH 

strapi_gw_module_relations AS (SELECT * FROM {{ ref('stg_strapi__gw_module_relations') }}),

final AS (

    SELECT
        id,
        gw_id                                                                        AS growthwork_id,
        gw_order                                                                     AS growthwork_order,
        growthwork_short_title                                                       AS growthwork_title,
        growthwork_description                                                       AS growthwork_description,
        growthwork_platform                                                          AS growthwork_type,
        growthwork_baselink                                                          AS growthwork_url,
        REGEXP_EXTRACT(REGEXP_EXTRACT(growthwork_baselink, r'[^/]+$'), r'^[^?]+')    AS growthwork_source_id,
        part_id,
        part_order,
        part_description,
        part_goal,    
        module_id                                                                    AS pathway_id,
        module_name                                                                  AS pathway_name,
        module_description                                                           AS pathway_description,
        module_goal                                                                  AS pathway_goal,
        module_weeks_length                                                          AS pathway_length_weeks,
        created_at,
        updated_at,
        databricks_synced_at      
    FROM strapi_gw_module_relations

)

SELECT * FROM final
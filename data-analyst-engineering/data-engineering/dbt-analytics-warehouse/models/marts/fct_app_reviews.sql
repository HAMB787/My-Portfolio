{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'id'
  )
}}

WITH 

appstore_reviews AS (
    SELECT *
    FROM {{ ref('stg_appstore__app_store_review') }} 
    {% if is_incremental() %}
    WHERE fivetran_synced_at > (SELECT MAX(last_updated_at) FROM {{ this }})
    {% endif %} 
),
google_play_reviews AS (
    SELECT *
    FROM 
    {{ ref('stg_google_play__reviews') }} 
    WHERE rnk = 1
        {% if is_incremental() %}
        AND review_last_update_at > (SELECT MAX(last_updated_at) FROM {{ this }})
        {% endif %} 
    ),

final AS (

    SELECT MD5(id)                                      AS id,
        created_at,
        fivetran_synced_at                              AS last_updated_at,
        rating,
        title,
        body                                            AS content,
        territory                                       AS country_code,
        CAST(NULL AS STRING)                            AS app_version_string,
        'Appstore'                                      AS platform
    FROM appstore_reviews

    UNION ALL 

    SELECT id,
        created_at,
        review_last_update_at                           AS last_updated_at,
        star_rating                                     AS rating,
        NULL                                            AS title,
        NULL                                            AS content,
        NULL                                            AS country_code,
        CAST(NULL AS STRING)                            AS app_version_string,        
        'Google Play'                                   AS platform
    FROM google_play_reviews

)

SELECT * FROM final
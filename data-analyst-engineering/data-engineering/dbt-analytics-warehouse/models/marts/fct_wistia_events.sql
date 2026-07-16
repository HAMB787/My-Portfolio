WITH

event_list AS (SELECT * FROM {{ ref('stg_wistia__event_list') }}),
members AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
medias AS (SELECT * FROM {{ ref('stg_wistia__medias') }}),

final AS (

    SELECT E.*,
        M.uuid,
        MD.duration                                                 AS media_duration,
        MD.project_name,
        MD.created_at                                               AS media_created_at,
        E.percent_viewed * MD.duration                              AS actual_duration_viewed
    FROM event_list AS E
    LEFT JOIN members AS M ON LOWER(E.email) = LOWER(M.email)
    LEFT JOIN medias AS MD ON E.media_id = MD.hashed_id

)

SELECT * FROM final
WITH

-- Not final yet, needs discussion with Gilad

page_view AS (SELECT * FROM {{ ref('stg_segment_javascript__pages') }}),

final AS (

    SELECT 
        user_id,
        MAX(CASE
            WHEN
                LOWER(page_search) LIKE '%skip=all%'
            THEN TRUE
            WHEN
                LOWER(url) = 'https://heyritual.com/?skip=all'
            THEN TRUE
            WHEN 
                LOWER(referrer) LIKE '%gtm%' OR
                LOWER(referrer) LIKE '%vwo%' OR
                LOWER(referrer) LIKE '%refersion%' OR
                LOWER(referrer) LIKE '%dev%' OR
                LOWER(referrer) LIKE '%localhost%' OR
                LOWER(referrer) LIKE '%test%'
            THEN TRUE
            WHEN
                LOWER(campaign_ial_utm_source) LIKE '%test%'
            THEN TRUE
        ELSE FALSE
        END) AS is_test
    FROM page_view
    GROUP BY 1

)

SELECT * FROM final
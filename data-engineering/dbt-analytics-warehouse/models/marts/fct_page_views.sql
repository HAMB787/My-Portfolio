{{ config(
    materialized='table'
)}}

WITH

page_view AS (SELECT * FROM {{ ref('stg_segment_javascript__pages') }}),

anonymous_id_user_id_mapping AS (

    SELECT
        anonymous_id,
        user_id,
        COUNT(*) as total_events
    FROM page_view
    WHERE user_id IS NOT NULL
    GROUP BY 1, 2

),

anonymous_id_user_id_mapping_ranking AS (

    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY anonymous_id, user_id ORDER BY total_events DESC)    AS rnk_
    FROM anonymous_id_user_id_mapping

),

final_mapping AS (

    SELECT anonymous_id,
        user_id
    FROM anonymous_id_user_id_mapping_ranking
    WHERE rnk_ = 1

),

page_view_transformed AS (

    SELECT
        P.id,
        P.created_at,
        COALESCE(P.user_id, M.user_id)                                           AS user_id,
        P.event_name                                                               AS original_event_name,
        CASE
            WHEN
                (
                LOWER(P.url) LIKE '%https://heyritual.com%' OR
                LOWER(P.url) LIKE '%https://www.heyritual.com%' OR
                LOWER(P.url) LIKE '%https://heyritual.church%' OR
                LOWER(P.url) LIKE '%http://www.heyritual.%') AND
                LOWER(P.url) NOT LIKE '%/add-partner%' AND
                LOWER(P.path) NOT IN ('/add-partner', '//add-partner') AND
                LOWER(P.path) IN ('/', '//') THEN 'landing_page_view'
            WHEN
                LOWER(P.url) LIKE '%https://blog.heyritual.com%' THEN 'blog_page_view'
            WHEN
                LOWER(P.url) LIKE '%https://heyritual.com/evaluate-your-relationship%' THEN 'evaluate_relationship_page_view'
            ELSE 'general_page_view'
        END AS event_name,
        TRUE                                                                     AS is_activity,
        COALESCE(P.user_id, M.user_id) IS NULL                                   AS is_visitor,
        P.page_path,
        P.page_title,
        P.page_referrer,
        P.url,
        COALESCE(P.campaign_source, P.campaign_utm_source, P.campaign_3butm_source, P.campaign_ial_utm_source)       AS utm_source,
        COALESCE(P.campaign_name, P.campaign_utm_campaign, P.campaign_3butm_campaign, P.campaign_ial_utm_campaign)   AS utm_campaign,
        COALESCE(P.campaign_term, P.campaign_utm_term, P.campaign_3butm_campaign)                                  AS utm_term,
        COALESCE(P.campaign_content, P.campaign_utm_content, P.campaign_ial_utm_content)                           AS utm_content,
        COALESCE(P.campaign_medium, P.campaign_utm_medium, P.campaign_3butm_medium, P.campaign_ial_utm_medium)       AS utm_medium,
        P.anonymous_id,
        COALESCE(P.funnelid, P.traits_funnelid)                                                                  AS funnel_id,
        COALESCE(P.typeform_id, P.traits_typeform_id)                                                            AS typeform_id,
        COALESCE(P.subid, P.traits_subid)                                                                        AS sub_id,
        P.ttclid                                                                                               AS ttcl_id,
        P.actions_amplitude_session_id,
        P.user_agent,                         
        P.user_agent_data_platform  AS platform,                         
        P.user_agent_data_mobile    AS is_mobile              
    FROM page_view AS P
    LEFT JOIN final_mapping AS M ON P.anonymous_id = M.anonymous_id

),

final AS (

    SELECT * FROM page_view_transformed

)

-- SELECT anonymous_id,
--     SUM(CASE WHEN is_visitor = TRUE THEN 1 ELSE 0 END)              AS visitor_views,
--     SUM(CASE WHEN is_visitor = FALSE THEN 1 ELSE 0 END)              AS user_views
-- FROM final
-- GROUP BY 1

SELECT * FROM final

-- empty user ids after backfill went 288K ==> 253K
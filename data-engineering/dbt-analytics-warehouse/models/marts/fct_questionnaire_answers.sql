{{ config(
    materialized='table'
)}}

-- later we need to include CMS data as well to have respective pathways


WITH 

forms AS (
    SELECT * FROM {{ ref('stg_typeform__form_history') }}
    -- WHERE is_active = TRUE
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1
),
fields AS (
    SELECT * FROM {{ ref('stg_typeform__form_field_history') }}
    -- WHERE is_active = TRUE
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1    
),
workspaces AS (SELECT * FROM {{ ref('stg_typeform__workspace') }}),
-- themes AS (SELECT * FROM {{ ref('stg_typeform__theme') }}),
responses AS (SELECT * FROM {{ ref('stg_typeform__response') }}),
answers AS (SELECT * FROM {{ ref('stg_typeform__response_answer') }}),
choice_answers AS (SELECT * FROM {{ ref('stg_typeform__response_answer_choice') }}),
choice_fields AS (
    SELECT * FROM {{ ref('stg_typeform__form_field_choice_history') }}
    -- WHERE is_active = TRUE
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY fivetran_synced_at DESC) = 1      
),
members AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
response_cms_id_mapping AS (SELECT typeform_response_id, gw_cms_id, MIN(member_id) AS member_id FROM {{ ref('stg_postgre_rds__webapp_membergrowthwork_typeform') }} GROUP BY 1,2),

choice_answers_enriched AS (

    SELECT 
        -- CHA.choice_id,
        CHA.field_id,
        CHA.response_id,
        STRING_AGG(CHA.choice_text, ',')   AS choice_texts,
        STRING_AGG(CHF.label, ',')   AS choice_answers
    FROM choice_answers AS CHA
    LEFT JOIN choice_fields AS CHF ON CHA.choice_id = CHF.id
        AND CHA.field_id = CHF.field_id
    GROUP BY 1,2

),

anon_user_mapping AS (

    SELECT 
        anonymous_id,
        user_id
    FROM {{ ref('stg_pubsub__events') }}
    WHERE anonymous_id IS NOT NULL
        AND user_id IS NOT NULL
    QUALIFY
        ROW_NUMBER() OVER(PARTITION BY anonymous_id ORDER BY created_at DESC) = 1

),


final AS (

    SELECT 
        MD5(R.id || A.field_id)                                         AS unique_sk,
        R.landed_at                                                     AS survey_started_at,
        R.submitted_at                                                  AS surver_submitted_at,
        R.email                                                         AS participant_email,    
        A.field_id,
        A.form_id,
        F.title                                                         AS form_title,
        F.type                                                          AS form_type,
        W.name                                                          AS workspace_name,
        FL.title                                                        AS question_title,
        FL.type                                                         AS question_type,
        A.response_id,
        A.type                                                          AS answer_type,
        CASE A.type
            WHEN 'date' THEN CAST(A.date AS STRING)
            WHEN 'text' THEN CAST(A.text AS STRING)
            WHEN 'number' THEN CAST(A.number AS STRING)
            WHEN 'url' THEN CAST(A.url AS STRING)
            WHEN 'email' THEN CAST(A.email AS STRING)
            WHEN 'boolean' THEN CAST(A.boolean AS STRING)
            WHEN 'phone_number' THEN CAST(A.phone_number AS STRING)
            WHEN 'file_url' THEN CAST(A.file_url AS STRING)
            WHEN 'choice' THEN CAST(CHA.choice_answers AS STRING)
            WHEN 'choices' THEN CAST(CHA.choice_answers AS STRING)
        END                                                              AS generalized_answer,
        A.date                                                           AS date_answer,    
        A.text                                                           AS text_answer,
        A.number                                                         AS number_answer,
        A.boolean                                                        AS true_false_answer,
        A.phone_number                                                   AS phone_number_answer,
        A.email                                                          AS email_answer,
        A.url                                                            AS url_answer,
        A.file_url                                                       AS file_url_answer,
        CHA.choice_texts,
        CHA.choice_answers,
        R.aid,
        R.expert_id,
        R.fbclid,
        R.funnelid,
        R.gclid,
        R.partner_uuid,
        R.primary_member_id,
        R.prolific_pid,
        R.random_uuid,
        R.rfsn_v_4_aid,
        R.rfsn_v_4_id,
        R.session_id,
        R.study_id,
        R.ttclid,
        R.uuid,
        R.metadata_network_id,
        R.affiliate,
        R.church,
        R.coupon,
        R.current_rfsn_lsts,
        R.email,
        R.ending,
        R.expert,
        R.expert_email,
        R.expert_name,
        COALESCE(R.first_name, R.firstname)                                     AS first_name,
        R.funnel_mode,
        R.funnel_start,
        COALESCE(R.last_name, R.lastname)                                       AS last_name,
        R.lead_variation,
        R.manager,
        R.matching,
        R.member_funnel,
        R.name,
        R.native_app_form_os,
        R.original_params,
        R.partner_email,
        R.partner_first_name,
        R.partner_last_name,
        R.partnerrefer,
        R.personal_email,
        R.phone,
        R.price,
        R.program,
        R.quick_survey_funnel,
        R.rfsn,
        R.rfsn_src,
        R.rfsn_v_4_cart_type,
        R.rfsn_v_4_cs,
        R.show_onboarding_app,
        R.skip,
        R.source,
        R.tier_type,
        R.utm_campaign,
        R.utm_content,
        R.utm_medium,
        R.utm_source,
        R.utm_term,
        R.version,
        R.welcome_session_done,
        R.metadata_browser,
        R.metadata_platform,
        R.metadata_referer,
        R.metadata_user_agent,
        R.token,
        R.jump_to,
        R.calculated_score,
        R.bark_lead,
        COALESCE(M.uuid, AM.user_id)                                                      AS member_uuid,
        RCM.gw_cms_id,
        RCM.member_id
    FROM answers AS A
    LEFT JOIN forms AS F ON A.form_id = F.id
    LEFT JOIN workspaces AS W ON F.workspace_id = W.id
    LEFT JOIN fields AS FL ON A.field_id = FL.id
    LEFT JOIN responses AS R ON A.response_id = R.id
    LEFT JOIN choice_answers_enriched AS CHA ON R.id = CHA.response_id
        AND FL.id = CHA.field_id
    LEFT JOIN members AS M ON R.email = M.email
    LEFT JOIN response_cms_id_mapping AS RCM ON R.id = RCM.typeform_response_id
    LEFT JOIN anon_user_mapping AS AM ON R.uuid = AM.anonymous_id

)

SELECT * FROM final
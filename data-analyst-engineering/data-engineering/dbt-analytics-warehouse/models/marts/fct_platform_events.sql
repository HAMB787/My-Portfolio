{{ config(
    materialized='table',
    partition_by={
        'field': 'created_at',
        'data_type': 'timestamp',
        "granularity": "day"
    },
    cluster_by=['event_name', 'user_id'],
    partition_expiration_days = 9999
) }}



WITH 

scheduled_sessions AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__scheduled_session') }}),
canceled_meeting AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__canceled_meeting') }}),
onboarding_session_show AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__onboarding_session_show') }}),
onboarding_session_noshow AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__onboarding_session_noshow') }}),
first_subscription_activation AS (SELECT * FROM {{ ref('stg_segment_serverless_prod__first_subscription_activation') }}),
lead_qualified AS (SELECT * FROM {{ ref('stg_segment_serverless_prod__lead_qualified') }}),
lead_acquired AS (SELECT * FROM {{ ref('stg_segment_serverless_prod__lead_acquired') }}),
customer_subscription_created AS (SELECT * FROM {{ ref('stg_segment_serverless_prod__customer_subscription_created') }}),
webapp_clicks AS (SELECT * FROM {{ ref('stg_segment_javascript__member_webapp_clicked') }}),
get_started_button_clicks AS (SELECT * FROM {{ ref('stg_segment_javascript__get_started_button_clicked') }}),
pricing_page_clicked AS (SELECT * FROM {{ ref('stg_segment_javascript__pricing_page_clicked') }}),
typeform_question_passed AS (SELECT * FROM {{ ref('stg_segment_javascript__typeform_question_passed') }}),
typeform_submitted AS (SELECT * FROM {{ ref('stg_segment_javascript__typeform_submitted') }}),
app_message_displays AS (SELECT * FROM {{ ref('stg_segment_native_app__app_message_displayed') }}),
nativeapp_clicks AS (SELECT * FROM {{ ref('stg_segment_native_app__member_nativeapp_clicked') }}),
message_reads AS (SELECT * FROM {{ ref('stg_segment_native_app__message_read') }}),
emotional_checkin_started AS (SELECT * FROM {{ ref('stg_segment_native_app__member_emotional_checkin_started') }}),
emotional_checkin_completed AS (SELECT * FROM {{ ref('stg_segment_native_app__member_emotional_checkin_completed') }}),
emotion_tab_click AS (SELECT * FROM {{ ref('stg_segment_native_app__member_emotion_tab_click') }}),
emotional_checkin_selection AS (SELECT * FROM {{ ref('stg_segment_native_app__member_emotional_checkin_selection') }}),
application_installed AS (SELECT * FROM {{ ref('stg_segment_native_app__application_installed') }}),
application_opened AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY id ORDER BY created_at DESC)  AS rnk
    FROM {{ ref('stg_segment_native_app__application_opened') }}
),
application_backgrounded AS (SELECT * FROM {{ ref('stg_segment_native_app__application_backgrounded') }}),
matching_popup_opened AS (SELECT * FROM {{ ref('stg_segment_javascript__matching_popup_opened') }}),
matching_continue_clicked AS (SELECT * FROM {{ ref('stg_segment_javascript__matching_continue_clicked') }}),
page_view AS (SELECT * FROM {{ ref('stg_segment_javascript__pages') }}),
click_events_mapping AS (SELECT * FROM {{ ref('stg_lookup_tables__click_events_mapping') }}),
module_part_assigned AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__module_part_assigned') }}),
module_growthwork_complete AS (SELECT * FROM {{ ref('stg_segment_backend_experts_prod__module_growthwork_complete') }}),
session_created AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_session') }}),
webapp_members AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
assigned_primary_member AS (SELECT * FROM {{ ref('stg_segment_backend_members_prod__assigned_primary_member') }}),
member_partnerrequest_sent AS (SELECT * FROM {{ ref('stg_segment_native_app__member_partnerrequest_sent') }}),
customerio_push_sent AS (SELECT * FROM {{ ref('stg_customerio__push_sent') }}),
customerio_sms_delivered AS (SELECT * FROM {{ ref('stg_customerio__sms_delivered') }}),
member_ritualrating_closed AS (SELECT * FROM {{ ref('stg_segment_native_app__member_ritualrating_closed') }}),
member_ritualrating_freetype AS (SELECT * FROM {{ ref('stg_segment_native_app__member_ritualrating_freetype') }}),
member_ritualrating_invited AS (SELECT * FROM {{ ref('stg_segment_native_app__member_ritualrating_invited') }}),
member_ritualrating_submitted AS (SELECT * FROM {{ ref('stg_segment_native_app__member_ritualrating_submitted') }}),
member_apprating_invite AS (SELECT * FROM {{ ref('stg_segment_native_app__member_apprating_invite') }}),

scheduled_sessions_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,
        event_timestamp                                                       AS created_at,
        user_id,
        email,
        event_name                                                               AS original_event_name,
        CASE
            WHEN meeting_type = 'matching' THEN 'matchingsession_scheduled'
            ELSE LOWER(event_name)
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM scheduled_sessions

),

canceled_meeting_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN rescheduled = 'True' THEN 'matchingsession_rescheduled'
            ELSE 'matchingsession_cancelled'
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM canceled_meeting
    WHERE meeting_type = 'matching'

),

onboarding_session_show_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN meeting_type = 'matching' THEN 'matchingsession_completed'
            ELSE LOWER(event_name)
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM onboarding_session_show

),

onboarding_session_noshow_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN meeting_type = 'matching' THEN 'matchingsession_noshow'
            ELSE LOWER(event_name)
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM onboarding_session_noshow

),

first_subscription_activation_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        utm_source                                                               AS utm_source,
        utm_campaign                                                             AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        utm_content                                                              AS utm_content,
        utm_medium                                                               AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile        
    FROM first_subscription_activation

),

lead_qualified_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        utm_source                                                               AS utm_source,
        utm_campaign                                                             AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        utm_content                                                              AS utm_content,
        utm_medium                                                               AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile                      
    FROM lead_qualified

),

lead_acquired_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        utm_source                                                               AS utm_source,
        utm_campaign                                                             AS utm_campaign,
        utm_term                                                                 AS utm_term,
        utm_content                                                              AS utm_content,
        utm_medium                                                               AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile                      
    FROM lead_acquired

),

customer_subscription_created_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        'matching_session_purchased'                                             AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        member_utm_source                                                        AS utm_source,
        member_utm_campaign                                                      AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        member_utm_content                                                       AS utm_content,
        member_utm_medium                                                        AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile                      
    FROM customer_subscription_created
    WHERE plan_category = 'matching'

),

webapp_clicks_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        W.event_name                                                             AS original_event_name,
        CASE
            WHEN W.click_id IN (
                'pricing_matchingsessionupgrade_subscription_clicked',
                'pricing_matchingsessionupgrade_banned_clicker',
                'pricing_matchingsessionupgrade_profile_clicked'
            )
            THEN 'planupgrade_matchingsession_viewed'
            ELSE LOWER(COALESCE(EM.event_name, W.event_name))
        END                                                                      AS event_name,
        CASE
            WHEN EM.event_name IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                                      AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,
        COALESCE(campaign_source, campaign_ial_utm_source)                          AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign, campaign_ial_utm_campaign)   AS utm_campaign,
        campaign_term                                                               AS utm_term,
        COALESCE(campaign_content, campaign_utm_content, campaign_ial_utm_content)  AS utm_content,
        COALESCE(campaign_medium, campaign_utm_medium, campaign_ial_utm_medium)     AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                    AS platform,                         
        user_agent_data_mobile                                                      AS is_mobile           
    FROM webapp_clicks AS W
    LEFT JOIN click_events_mapping AS EM ON W.click_id = EM.click_id


),

get_started_button_clicks_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,       
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        'funnel_getstartedbutton_click'                                          AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,
        COALESCE(campaign_source, campaign_ial_utm_source)                       AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign)                           AS utm_campaign,
        campaign_term                                                            AS utm_term,
        COALESCE(campaign_content, campaign_utm_content)                         AS utm_content,
        COALESCE(campaign_medium, campaign_utm_medium, campaign_medium9)         AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                    AS platform,                         
        user_agent_data_mobile                                                      AS is_mobile                         
    FROM get_started_button_clicks

),

matching_popup_opened_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,       
        -- user_id,
        email,        
        event_name                                                               AS original_event_name,
        'matching_popup_opened'                                                  AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        user_agent,                         
        user_agent_platform                                                         AS platform,                         
        user_agent_mobile                                                           AS is_mobile                         
    FROM matching_popup_opened

),

matching_continue_clicked_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        -- LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,       
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        FALSE                                                                    AS is_activity,
        TRUE                                                                     AS is_visitor,
        page_path,
        page_title,
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        user_agent,                         
        user_agent_platform                                                         AS platform,                         
        user_agent_mobile                                                           AS is_mobile                         
    FROM matching_continue_clicked

),

page_view_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,       
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN url LIKE '%matching=true%' AND path = '/plans' THEN 'planupgrade_matchingsession_viewed'
            WHEN url LIKE '%matching=true%' AND url NOT LIKE '%mode=payment%' AND title = 'Checkout Complete' THEN 'planupgrade_matchingsession_purchased'
            ELSE 'page_view'      -- need to update no code flow as well when it will be approved                                                
        END                                                                      AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,
        COALESCE(campaign_source, campaign_utm_source, campaign_3butm_source, campaign_ial_utm_source)       AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign, campaign_3butm_campaign, campaign_ial_utm_campaign)   AS utm_campaign,
        COALESCE(campaign_term, campaign_utm_term, campaign_3butm_campaign)                                  AS utm_term,
        COALESCE(campaign_content, campaign_utm_content, campaign_ial_utm_content)                           AS utm_content,
        COALESCE(campaign_medium, campaign_utm_medium, campaign_3butm_medium, campaign_ial_utm_medium)       AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                         AS platform,                         
        user_agent_data_mobile                                                           AS is_mobile                             
    FROM page_view

),

pricing_page_clicked_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,        
        COALESCE(campaign_source, campaign_utm_source, campaign_ial_utm_source)     AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign, campaign_ial_utm_campaign)   AS utm_campaign,
        campaign_term                                                               AS utm_term,
        COALESCE(campaign_content, campaign_utm_content, campaign_ial_utm_content)  AS utm_content,
        COALESCE(campaign_medium, campaign_utm_medium, campaign_ial_utm_medium)     AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                    AS platform,                         
        user_agent_data_mobile                                                      AS is_mobile                       
    FROM pricing_page_clicked
    WHERE click_id = 'stepper_continue_button' -- filtering only this clicks for funnel data

),

typeform_question_passed_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,     
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE typeformquestionid
            WHEN '87965444-1f39-4df5-9c4b-54bc89dd619b' THEN 'typeform_question_passed_first_level'
            WHEN 'c390183a-e025-46b7-90c9-ddfadb66f809' THEN 'typeform_question_passed_second_level'
            WHEN 'a4c8ad7e-a422-4234-8178-a4f5d8823375' THEN 'typeform_question_passed_third_level'
            ELSE 'typeform_question_passed_general'
        END                                                                      AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,        
        COALESCE(campaign_source, campaign_ial_utm_source)                                            AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign, campaign_ial_utm_campaign)                     AS utm_campaign,
        campaign_term                                                                                 AS utm_term,
        COALESCE(campaign_content, campaign_utm_content, campaign_ial_utm_content)                    AS utm_content,
        COALESCE(campaign_medium, campaign_medium9, campaign_utm_medium, campaign_ial_utm_medium)     AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                    AS platform,                         
        user_agent_data_mobile                                                      AS is_mobile                          
    FROM typeform_question_passed

),

typeform_submitted_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        'questionnaire_complete'                                                 AS event_name,
        FALSE                                                                    AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        page_path,
        page_title,        
        COALESCE(campaign_source, campaign_ial_utm_source)                          AS utm_source,
        COALESCE(campaign_name, campaign_utm_campaign, campaign_ial_utm_campaign)   AS utm_campaign,
        campaign_term                                                               AS utm_term,
        COALESCE(campaign_content, campaign_utm_content, campaign_ial_utm_content)  AS utm_content,
        COALESCE(campaign_medium, campaign_utm_medium, campaign_ial_utm_medium)     AS utm_medium,
        user_agent,                         
        user_agent_data_platform                                                    AS platform,                         
        user_agent_data_mobile                                                      AS is_mobile                          
    FROM typeform_submitted

),

nativeapp_clicks_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        W.event_name                                                             AS original_event_name,
        LOWER(COALESCE(EM.event_name, W.event_name))                             AS event_name,
        CASE
            WHEN EM.event_name IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                                                      AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                               
    FROM nativeapp_clicks AS W
    LEFT JOIN click_events_mapping AS EM ON W.click_id = EM.click_id    

),

app_message_displays_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                       
    FROM app_message_displays

),

message_reads_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM message_reads

),

emotional_checkin_started_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM emotional_checkin_started

),


emotional_checkin_completed_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM emotional_checkin_completed

),

emotion_tab_click_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM emotion_tab_click

),

emotional_checkin_selection_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM emotional_checkin_selection

),

application_installed_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM application_installed

),

application_opened_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM application_opened
    WHERE rnk = 1

),

application_backgrounded_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        LAST_VALUE(user_id IGNORE NULLS) OVER (PARTITION BY anonymous_id ORDER BY created_at DESC ROWS UNBOUNDED PRECEDING) AS user_id,        
        -- user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        LOWER(event_name)                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,         
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent, -- can be later changed
        CAST(NULL AS STRING)                                                     AS platform, -- can be later changed
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile -- can be later changed                                 
    FROM application_backgrounded

),

module_part_assigned_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM module_part_assigned

),

module_growthwork_complete_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        user_id IS NULL                                                          AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM module_growthwork_complete

),

session_created_transformed AS (

    SELECT S.id,
        CAST(NULL AS STRING) AS anonymous_id,    
        S.created_at,
        M.uuid                                                                   AS user_id,
        CAST(NULL AS STRING) AS email,        
        'session_created'                                                        AS original_event_name,
        'session_created'                                                        AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM session_created AS S
    LEFT JOIN webapp_members AS M ON S.member_id = M.id

),

assigned_primary_member_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        email,        
        event_name                                                               AS original_event_name,
        'member_partnerrequest_completed'                                        AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM assigned_primary_member

),

member_partnerrequest_sent_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_partnerrequest_sent

),

customerio_push_sent_transformed AS (

    SELECT id,
        CAST(NULL AS STRING) AS anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN campaign_id = '256' AND action_id = '5644' THEN 'content_push_sent_variation_A'
            WHEN campaign_id = '256' AND action_id = '5645' THEN 'content_push_sent_variation_B'
            ELSE event_name                                                               
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        'customerio'                                                             AS utm_source,
        campaign_id                                                              AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM customerio_push_sent

),

customerio_sms_delivered_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        CASE
            WHEN campaign_id = '256' AND action_id = '5697' THEN 'content_sms_delivered_variation_A'
            WHEN campaign_id = '256' AND action_id = '5698' THEN 'content_sms_delivered_variation_B'
            ELSE event_name                                                               
        END                                                                      AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        'customerio'                                                             AS utm_source,
        campaign_id                                                              AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM customerio_sms_delivered

),

member_ritualrating_closed_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_ritualrating_closed

),

member_ritualrating_freetype_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_ritualrating_freetype

),

member_ritualrating_invited_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_ritualrating_invited

),

member_ritualrating_submitted_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_ritualrating_submitted

),

member_apprating_invite_transformed AS (

    SELECT id,
        anonymous_id,    
        created_at,
        user_id,
        CAST(NULL AS STRING) AS email,        
        event_name                                                               AS original_event_name,
        event_name                                                               AS event_name,
        TRUE                                                                     AS is_activity,
        FALSE                                                                    AS is_visitor,
        CAST(NULL AS STRING)                                                     AS page_path,        
        CAST(NULL AS STRING)                                                     AS page_title,        
        CAST(NULL AS STRING)                                                     AS utm_source,
        CAST(NULL AS STRING)                                                     AS utm_campaign,
        CAST(NULL AS STRING)                                                     AS utm_term,
        CAST(NULL AS STRING)                                                     AS utm_content,
        CAST(NULL AS STRING)                                                     AS utm_medium,
        CAST(NULL AS STRING)                                                     AS user_agent,
        CAST(NULL AS STRING)                                                     AS platform,
        CAST(NULL AS BOOLEAN)                                                    AS is_mobile
    FROM member_apprating_invite

),

unioned AS (

    SELECT * FROM scheduled_sessions_transformed

    UNION ALL

    SELECT * FROM canceled_meeting_transformed

    UNION ALL

    SELECT * FROM onboarding_session_show_transformed

    UNION ALL

    SELECT * FROM onboarding_session_noshow_transformed

    UNION ALL

    SELECT * FROM first_subscription_activation_transformed

    UNION ALL

    SELECT * FROM lead_qualified_transformed

    UNION ALL

    SELECT * FROM lead_acquired_transformed

    UNION ALL

    SELECT * FROM customer_subscription_created_transformed

    UNION ALL

    SELECT * FROM webapp_clicks_transformed

    UNION ALL

    SELECT * FROM get_started_button_clicks_transformed

    UNION ALL

    SELECT * FROM matching_popup_opened_transformed

    UNION ALL

    SELECT * FROM matching_continue_clicked_transformed

    UNION ALL

    SELECT * FROM page_view_transformed

    UNION ALL

    SELECT * FROM pricing_page_clicked_transformed

    UNION ALL

    SELECT * FROM typeform_question_passed_transformed

    UNION ALL

    SELECT * FROM typeform_submitted_transformed

    UNION ALL

    SELECT * FROM nativeapp_clicks_transformed

    UNION ALL

    SELECT * FROM app_message_displays_transformed

    UNION ALL

    SELECT * FROM message_reads_transformed

    UNION ALL

    SELECT * FROM emotional_checkin_started_transformed

    UNION ALL

    SELECT * FROM emotional_checkin_completed_transformed

    UNION ALL

    SELECT * FROM emotion_tab_click_transformed

    UNION ALL

    SELECT * FROM emotional_checkin_selection_transformed

    UNION ALL

    SELECT * FROM application_installed_transformed

    UNION ALL

    SELECT * FROM application_opened_transformed

    UNION ALL

    SELECT * FROM application_backgrounded_transformed

    UNION ALL

    SELECT * FROM module_part_assigned_transformed

    UNION ALL

    SELECT * FROM module_growthwork_complete_transformed

    UNION ALL

    SELECT * FROM session_created_transformed

    UNION ALL

    SELECT * FROM assigned_primary_member_transformed

    UNION ALL

    SELECT * FROM member_partnerrequest_sent_transformed

    UNION ALL

    SELECT * FROM customerio_push_sent_transformed

    UNION ALL

    SELECT * FROM customerio_sms_delivered_transformed

    UNION ALL

    SELECT * FROM member_ritualrating_closed_transformed

    UNION ALL

    SELECT * FROM member_ritualrating_freetype_transformed

    UNION ALL

    SELECT * FROM member_ritualrating_invited_transformed

    UNION ALL

    SELECT * FROM member_ritualrating_submitted_transformed

    UNION ALL

    SELECT * FROM member_apprating_invite_transformed

),

unioned_filtered AS (

    SELECT * FROM unioned
    WHERE   
        (utm_campaign IS NOT NULL AND utm_campaign <> 'NA') OR
        (utm_content IS NOT NULL AND utm_content <> 'NA') OR
        (utm_medium IS NOT NULL AND utm_medium <> 'NA') OR
        (utm_source IS NOT NULL AND utm_source <> 'NA')
),

calculated_initial_utm_params AS (

    SELECT
        user_id,
        utm_campaign,
        utm_content,
        utm_medium,
        utm_source,
        utm_term
    FROM unioned_filtered
    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at ASC) = 1

),

final AS (

    SELECT 
        U.id,
        U.anonymous_id,        
        U.created_at,
        U.user_id,
        U.email,
        U.original_event_name,
        U.event_name,
        U.is_activity,
        U.is_visitor,
        U.page_path,        
        U.page_title,         
        COALESCE(U.utm_source, IP.utm_source)                                               AS utm_source,
        COALESCE(U.utm_campaign, IP.utm_campaign)                                           AS utm_campaign,
        COALESCE(U.utm_term, IP.utm_term)                                                   AS utm_term,
        COALESCE(U.utm_content, IP.utm_content)                                             AS utm_content,
        COALESCE(U.utm_medium, IP.utm_medium)                                               AS utm_medium,
        U.user_agent,
        U.platform, 
        U.is_mobile 
    FROM unioned AS U
    LEFT JOIN calculated_initial_utm_params AS IP ON U.user_id = IP.user_id

)

SELECT * FROM final
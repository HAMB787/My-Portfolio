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

feature_events AS (SELECT * FROM {{ ref('stg_pubsub__events') }}),

final_before_naming_conv AS (

SELECT
    id,
    created_at,
    user_id,
    anonymous_id,

-- ================================================== all the custom event logic is going here ================================

    CASE
        WHEN event_name = 'scheduled_session'
            AND JSON_EXTRACT_SCALAR(payload, '$.meeting_type') = 'matching'
            THEN 'matchingsession_scheduled' -- When a scheduled session event occurs and it's for a 'matching' type, it is classified as 'matchingsession_scheduled'.
        WHEN event_name = 'canceled_meeting'
            AND JSON_EXTRACT_SCALAR(payload, '$.meeting_type') = 'matching'
            AND JSON_EXTRACT_SCALAR(payload, '$.rescheduled') = 'True'
            THEN 'matchingsession_rescheduled' -- If a canceled meeting event occurs and it's for a 'matching' type and is rescheduled, it is classified as 'matchingsession_rescheduled'.
        WHEN event_name = 'canceled_meeting'
            AND JSON_EXTRACT_SCALAR(payload, '$.meeting_type') = 'matching'
            AND NOT JSON_EXTRACT_SCALAR(payload, '$.rescheduled') = 'True'
            THEN 'matchingsession_cancelled' -- If a canceled meeting event occurs, it's for a 'matching' type, but is not rescheduled, it is classified as 'matchingsession_cancelled'.
        WHEN event_name = 'onboarding_session_show'
            AND JSON_EXTRACT_SCALAR(payload, '$.meeting_type') = 'matching'
            THEN 'matchingsession_completed' -- When an onboarding session show event occurs and it's for a 'matching' type, it is classified as 'matchingsession_completed'.
        WHEN event_name = 'onboarding_session_noshow'
            AND JSON_EXTRACT_SCALAR(payload, '$.meeting_type') = 'matching'
            THEN 'matchingsession_noshow' -- When an onboarding session no-show event occurs and it's for a 'matching' type, it is classified as 'matchingsession_noshow'.
        WHEN event_name = 'customer_subscription_created'
            AND JSON_EXTRACT_SCALAR(payload, '$.plan_category') = 'matching'
            THEN 'matching_session_purchased' -- When a customer creates a subscription and it's for a 'matching' type session, it is classified as 'matching_session_purchased'.
        WHEN event_name = 'typeform_question_passed'
            AND JSON_EXTRACT_SCALAR(payload, '$.typeformquestionid') = '87965444-1f39-4df5-9c4b-54bc89dd619b'
            THEN 'typeform_question_passed_first_level' -- first important question checkpoint passed
        WHEN event_name = 'typeform_question_passed'
            AND JSON_EXTRACT_SCALAR(payload, '$.typeformquestionid') = 'c390183a-e025-46b7-90c9-ddfadb66f809'
            THEN 'typeform_question_passed_second_level'
        WHEN event_name = 'typeform_question_passed' -- second important question checkpoint passed
            AND JSON_EXTRACT_SCALAR(payload, '$.typeformquestionid') = 'a4c8ad7e-a422-4234-8178-a4f5d8823375'
            THEN 'typeform_question_passed_third_level' -- third important question checkpoint passed
        WHEN event_name = 'page_view'
            AND JSON_EXTRACT_SCALAR(payload, '$.url') LIKE '%matching=true%'
            AND JSON_EXTRACT_SCALAR(payload, '$.path') = '/plans'
            THEN 'planupgrade_matchingsession_viewed'
        WHEN event_name = 'page_view'
            AND JSON_EXTRACT_SCALAR(payload, '$.url') LIKE '%matching=true%'
            AND JSON_EXTRACT_SCALAR(payload, '$.url') NOT LIKE '%mode=payment%'
            AND JSON_EXTRACT_SCALAR(payload, '$.url') LIKE '%checkout-complete%'
            THEN 'planupgrade_matchingsession_purchased'
        WHEN event_name = 'member_webapp_clicked'
            AND JSON_EXTRACT_SCALAR(payload, '$.click_id') IN (
                'pricing_matchingsessionupgrade_subscription_clicked',
                'pricing_matchingsessionupgrade_banned_clicker',
                'pricing_matchingsessionupgrade_profile_clicked'
            )
            THEN 'planupgrade_matchingsession_viewed'                                              
        WHEN event_name = 'get_started_button_clicked' -- this is a case when events are appearing with different names in BQ and Amplitude
            THEN 'funnel_getstartedbutton_click'             
        WHEN event_name = 'assigned_primary_member' -- requested by product/task to do this renaming
            THEN 'member_partnerrequest_completed'             
        WHEN event_name = 'typeform_submitted'
            THEN 'questionnaire_complete'             
        WHEN event_name = 'Application Backgrounded' -- renaming
            THEN 'application_backgrounded'             
        WHEN event_name = 'Application Installed' -- renaming
            THEN 'application_installed'             
        WHEN event_name = 'Application Opened' -- renaming
            THEN 'application_opened'             
        WHEN event_name = 'matchingContinueClicked' -- renaming
            THEN 'matching_continue_clicked'             
        WHEN event_name = 'matchingPopupOpened' -- renaming
            THEN 'matching_popup_opened'             
        ELSE event_name
    END                                                                                 AS event_name,

--------========================================================================================================================

    user_email,
    LOWER(source_platform)                                                              AS source_platform,
    LOWER(source_version)                                                               AS source_version,
    LOWER(device_user_agent)                                                            AS device_user_agent,
    LOWER(device_type)                                                                  AS device_type,
    LOWER(device_os)                                                                    AS device_os,
    LOWER(device_version)                                                               AS device_version,
    LOWER(geo_country)                                                                  AS geo_country,
    LOWER(geo_state)                                                                    AS geo_state,
    LOWER(geo_iso_code)                                                                 AS geo_iso_code,
    LOWER(geo_ip)                                                                       AS geo_ip,
    LOWER(geo_locale)                                                                   AS geo_locale,
    LOWER(geo_timezone)                                                                 AS geo_timezone,
    utm_source,
    utm_medium,
    utm_campaign,
    crm_source,
    crm_medium,
    crm_campaign,
    crm_content,    
    payload,
    device_uuid
FROM feature_events

),

final AS (

    SELECT
        id,
        created_at,
        user_id,
        anonymous_id,
        -- event naming conventions we apply
        CASE event_name
            -- WHEN 'typeform_question_passed' THEN 'member_typeform_question_passed'
            -- WHEN 'application_opened' THEN 'member_application_opened'
            -- WHEN 'member_homescreen_view' THEN 'member_homescreen_viewed'
            -- WHEN 'application_backgrounded' THEN 'member_application_backgrounded'
            -- WHEN 'user_properties_updated' THEN 'member_properties_updated'
            -- WHEN 'invoice_finalized' THEN 'customer_invoice_finalized'
            -- WHEN 'growthwork_started' THEN 'member_growthwork_started'
            -- WHEN 'member_login' THEN 'member_login_succeeded'
            -- WHEN 'login_authorized' THEN 'system_login_authorized'
            -- WHEN 'growthwork_completed' THEN 'member_growthwork_completed'
            -- WHEN 'typeform_viewed' THEN 'member_funnel_typeform_viewed'
            -- WHEN 'member_emotion_checkin_answer' THEN 'member_emotion_checkin_answered'
            -- WHEN 'scheduled_session' THEN 'system_scheduled_session'
            -- WHEN 'message_read' THEN 'member_message_read'
            -- WHEN 'identify' THEN 'system_identification_sent'
            -- WHEN 'module_part_assigned' THEN 'system_module_part_assigned'
            -- WHEN 'program_complete_session' THEN 'system_session_completed'
            -- WHEN 'begin_typeform' THEN 'member_funnel_typeform_started'
            -- WHEN 'member_emotion_tab_click' THEN 'member_emotion_tab_clicked'
            -- WHEN 'member_groupmessage_received' THEN 'member_group_message_received'
            -- WHEN 'signup_page_clicked' THEN 'member_signup_page_clicked'
            -- WHEN 'typeform_question_passed_first_level' THEN 'member_funnel_typeform_first_level_question_passed'
            -- WHEN 'notify_member_on_new_message' THEN 'system_new_message_notification_sent'
            -- WHEN 'module_growthwork_complete' THEN 'member_module_growthwork_completed'
            -- WHEN 'member_part_unlocked' THEN 'system_part_unlocked'
            -- WHEN 'typeform_question_passed_third_level' THEN 'member_funnel_typeform_third_level_question_passed'
            -- WHEN 'questionnaire_complete' THEN 'member_funnel_questionnaire_completed'
            -- WHEN 'member_emotional_start' THEN 'system_emotional_checkin_started'
            -- WHEN 'expert_sent_message_individualchat' THEN 'expert_individual_chat_message_sent'
            -- WHEN 'member_sent_message' THEN 'member_message_sent'
            -- WHEN 'member_individualmessage_received' THEN 'member_individual_message_received'
            -- WHEN 'funnel_getstartedbutton_click' THEN 'member_funnel_get_started_button_clicked'
            -- WHEN 'pricing_page_clicked' THEN 'member_pricing_page_clicked'
            -- WHEN 'member_sent_message_individualchat' THEN 'member_individual_message_sent'
            -- WHEN 'member_emotional_checkin_selection' THEN 'member_emotional_checkin_selected'
            -- WHEN 'registration_signup_page_open' THEN 'member_registration_signup_page_opened'
            -- WHEN 'expert_join_session' THEN 'expert_session_joined'
            -- WHEN 'transition_mobile_qr_open' THEN 'member_transition_mobile_qr_opened'
            -- WHEN 'typeform_question_passed_second_level' THEN 'member_funnel_typeform_second_level_question_passed'
            -- WHEN 'canceled_meeting' THEN 'system_meeting_canceled'
            -- WHEN 'expert_sent_message_groupchat' THEN 'expert_groupchat_message_sent'
            -- WHEN 'lead_acquired' THEN 'system_lead_acquired'
            -- WHEN 'module_part_submitted' THEN 'member_module_part_submitted'
            -- WHEN 'member_updated_personal_details' THEN 'system_member_personal_details_updated'
            -- WHEN 'member_sent_message_groupchat' THEN 'member_groupchat_message_sent'
            -- WHEN 'module_part_started' THEN 'system_module_part_started'
            -- WHEN 'charge_succeeded' THEN 'customer_charge_succeeded'
            -- WHEN 'expert_changed' THEN 'system_expert_changed'
            WHEN 'member_pathway_unlocked' THEN 'system_pathway_unlocked' -- POC
            -- WHEN 'new_checkout' THEN 'customer_new_checkout'
            -- WHEN 'registration_declaration_page_open' THEN 'member_registration_declaration_page_opened'
            -- WHEN 'registration_pricing_page1_open' THEN 'member_registration_pricing_page1_opened'
            -- WHEN 'registration_pricing_page2_open' THEN 'member_registration_pricing_page2_opened'
            -- WHEN 'registration_signup_continue_click' THEN 'member_registration_signup_continue_clicked'
            -- WHEN 'registration_declaration_submit_active' THEN 'member_registration_declaration_submitted'
            -- WHEN 'member_account_status_changed' THEN 'system_account_status_changed'
            -- WHEN 'registration_declaration_submit_click' THEN 'member_registration_declaration_submitted'
            -- WHEN 'expert_nopathway_selected' THEN 'expert_no_pathway_selected'
            -- WHEN 'application_installed' THEN 'member_application_installed'
            -- WHEN 'member_created' THEN 'system_member_created'
            -- WHEN 'registration_signup_complete' THEN 'member_registration_signup_completed'
            -- WHEN 'member_app_pushprompt_show' THEN 'member_app_pushprompt_shown'
            -- WHEN 'registration_view_checkout' THEN 'member_registration_checkout_viewed'
            -- WHEN 'emotion_feedback_requested' THEN 'member_emotion_feedback_requested'
            -- WHEN 'push_notification_enabled_status_changed' THEN 'system_push_notification_enabled_status_changed'
            -- WHEN 'onboarding_session_show' THEN 'system_onboarding_session_shown'
            -- WHEN 'first_subscription_activation' THEN 'customer_first_subscription_activated'
            -- WHEN 'account_verification_complete' THEN 'member_account_verification_completed'
            -- WHEN 'welcome_session_schedule_start' THEN 'member_welcome_session_schedule_started'
            WHEN 'registration_notification_checkbox_click' THEN 'member_registration_notification_checkbox_clicked' -- POC
            WHEN 'member_popup_native2_show' THEN 'member_popup_native2_shown' -- POC
            -- WHEN 'first_subscription_payment' THEN 'customer_first_subscription_paid'
            WHEN 'login_button_clicked' THEN 'member_login_button_clicked' -- POC
            -- WHEN 'onboarding_app_completed' THEN 'member_onboarding_app_completed'
            -- WHEN 'member_onboarding_redirect' THEN 'member_onboarding_redirected'
            -- WHEN 'member_system_pushpermission_show' THEN 'member_system_push_permission_shown'
            -- WHEN 'member_app_pushprompt_later' THEN 'member_app_pushprompt_later_clicked'
            -- WHEN 'invite_partner_page_open' THEN 'member_invite_partner_page_opened'
            -- WHEN 'member_ritualrating_invited' THEN 'member_ritual_rating_invited'
            -- WHEN 'member_partnerrequest_completed' THEN 'member_partner_request_completed'
            -- WHEN 'member_checkout_payment_attempt_creation' THEN 'member_checkout_payment_attempt_created'
            -- WHEN 'member-payment-confirmation-prod' THEN 'customer_payment_confirmed'
            -- WHEN 'welcome_session_schedule_complete' THEN 'member_welcome_session_schedule_completed'
            -- WHEN 'checkout_completed' THEN 'member_checkout_completed'
            -- WHEN 'total_revenue' THEN 'customer_total_revenue'
            -- WHEN 'account_verification_start' THEN 'system_account_verification_started'
            -- WHEN 'charge_failed' THEN 'customer_charge_failed'
            -- WHEN 'matching_popup_opened' THEN 'member_matching_popup_opened'
            -- WHEN 'invite_partner_complete' THEN 'member_invite_partner_completed'
            -- WHEN 'member_creation' THEN 'system_member_created'
            -- WHEN 'copied_active_session' THEN 'member_active_session_copied'
            -- WHEN 'failed_login' THEN 'member_login_failed'
            -- WHEN 'partner_filled_form' THEN 'partner_form_filled'
            -- WHEN 'lead_unqualified' THEN 'member_lead_unqualified'
            WHEN 'registration_pricing_page_open' THEN 'member_registration_pricing_page_opened' -- POC
            -- WHEN 'registration_login_click' THEN 'member_registration_login_clicked'
            -- WHEN 'welcome_session_schedule_later_click' THEN 'member_welcome_session_schedule_later_clicked'
            -- WHEN 'charge_refunded' THEN 'customer_charge_refunded'
            -- WHEN 'customer_update_payment_details' THEN 'customer_payment_details_updated'
            -- WHEN 'invite_partner_skip_click' THEN 'member_invite_partner_skip_clicked'
            -- WHEN 'monthly_reports_generated' THEN 'member_monthly_reports_generated'
            -- WHEN 'survey_opened' THEN 'member_survey_opened'
            -- WHEN 'report_published' THEN 'system_report_published'
            -- WHEN 'report_approved' THEN 'expert_report_approved'
            -- WHEN 'invoice_submitted' THEN 'expert_invoice_submitted'
            -- WHEN 'member_ritualrating_closed' THEN 'member_ritual_rating_closed'
            -- WHEN 'member_schedulingissue_inquired' THEN 'member_scheduling_issue_inquired'
            -- WHEN 'member_apprating_invite' THEN 'member_app_rating_invited'
            -- WHEN 'member_ritualrating_submitted' THEN 'member_ritual_rating_submitted'
            -- WHEN 'report_processed' THEN 'system_report_processed'
            -- WHEN 'invoice_approved' THEN 'system_expert_invoice_approved'
            -- WHEN 'planupgrade_matchingsession_viewed' THEN 'member_plan_upgrade_matching_session_viewed'
            -- WHEN 'data_upload_feedback' THEN 'member_data_feedback_uploaded'
            -- WHEN 'emotion_feedback_submitted' THEN 'member_emotion_feedback_submitted'
            -- WHEN 'onboarding_session_noshow' THEN 'member_onboarding_session_noshow'
            -- WHEN 'member_matching_upgrade_option_status' THEN 'system_matching_upgrade_option_status_changed'
            -- WHEN 'member_partnerrequest_sent' THEN 'member_partner_request_sent'
            -- WHEN 'matching_session_purchased' THEN 'member_matching_session_purchased'
            -- WHEN 'session_scheduled_missed_param' THEN 'system_session_scheduled_missed_param'
            -- WHEN 'session_end' THEN 'system_session_ended'
            -- WHEN 'matchingsession_completed' THEN 'member_matching_session_completed'
            -- WHEN 'pick_up_where_you_left_off_continue_clicked' THEN 'member_pick_up_where_you_left_off_continue_clicked'
            -- WHEN 'matching_continue_clicked' THEN 'member_matching_continue_clicked'
            -- WHEN 'matchingsession_scheduled' THEN 'member_matching_session_scheduled'
            -- WHEN 'member_schedulingissue_contactsupport' THEN 'member_scheduling_issue_contact_support_pressed'
            -- WHEN 'partnerdetail_duplicate_rejected' THEN 'member_partner_details_duplicate_rejected'
            -- WHEN 'member_schedulingissue_submitted' THEN 'member_scheduling_issue_submitted'
            -- WHEN 'charge_dispute_created' THEN 'customer_charge_dispute_created'
            -- WHEN 'planupgrade_matchingsession_purchased' THEN 'member_planupgrade_matching_session_purchased'
            -- WHEN 'member_system_pushpermission_declined' THEN 'member_system_push_permission_declined'
            -- WHEN 'popup_reactivatemembership_confirmed' THEN 'member_popup_reactivate_membership_confirmed'
            -- WHEN 'expert_login' THEN 'expert_login_succeded'
            -- WHEN 'invoice_invalidated' THEN 'customer_invoice_invalidated'
            -- WHEN 'data_upload_request' THEN 'member_data_upload_requested'
            -- WHEN 'matchingsession_rescheduled' THEN 'member_matching_session_rescheduled'
            -- WHEN 'charge_dispute_updated' THEN 'customer_charge_dispute_updated'
            -- WHEN 'charge_dispute_closed' THEN 'customer_charge_dispute_closed'
            -- WHEN 'member_ritualrating_freetype' THEN 'member_ritual_rating_freetype_answered'
            -- WHEN 'member_PreQ4_submitted' THEN 'member_FIT_preQ4_submitted'
            -- WHEN 'member_FITpre_completed' THEN 'member_FIT_pre_completed'
            -- WHEN 'member_PreQ2_submitted' THEN 'member_FIT_preQ2_submitted'
            -- WHEN 'member_PreQ3_submitted' THEN 'member_FIT_preQ3_submitted'
            -- WHEN 'member_expertchange_requested' THEN 'member_expert_change_requested'
            -- WHEN 'login_with_errors' THEN 'member_login_with_errors'
            -- WHEN 'matchingsession_cancelled' THEN 'member_matching_session_canceled'
            -- WHEN 'member_FITpre_requested' THEN 'member_FIT_pre_requested'
            -- WHEN 'member_PreQ1_submitted' THEN 'member_FIT_preQ1_submitted'
            -- WHEN 'rx_member_chat_tab_clicked' THEN 'expert_member_chat_tab_clicked'
            -- WHEN 'rx_members_clicked' THEN 'expert_members_clicked'
            -- WHEN 'rx_member_emotion_tab_clicked' THEN 'expert_member_emotion_tab_clicked'
            -- WHEN 'rx_expert_growthwork_reviewed' THEN 'expert_expert_growthwork_reviewed'
            -- WHEN 'rx_expert_clicked_start_session' THEN 'expert_expert_clicked_start_session'
            -- WHEN 'rx_support_clicked' THEN 'expert_support_clicked'
            WHEN 'rx_reports_clicked' THEN 'expert_reports_clicked' -- POC
            -- WHEN 'rx_content for members_clicked' THEN 'expert_content for members_clicked'
            -- WHEN 'rx_expert_message_sent' THEN 'expert_message_sent'
            -- WHEN 'rx_thread_open' THEN 'expert_thread_opened'
            -- WHEN 'expert_FITgoals_selected' THEN 'expert_FIT_goals_selected'
            -- WHEN 'support_sent_message' THEN 'expert_support_sent_message'
            -- WHEN 'rx_member_selected' THEN 'expert_member_selected'
            -- WHEN 'rx_new_note_created' THEN 'expert_new_note_created'
            WHEN 'rx_member_growthwork_tab_clicked' THEN 'expert_member_growthwork_tab_clicked' -- POC
            -- WHEN 'rx_expert_logged_out' THEN 'expert_logged_out'
            -- WHEN 'rx_expert_respond_click' THEN 'expert_respond_clicked'
            -- WHEN 'rx_message_click' THEN 'expert_message_clicked'
            WHEN 'rx_home_clicked' THEN 'expert_home_clicked' -- POC
            -- WHEN 'member_contentpush_sent' THEN 'expert_member_contentpush_sent'
            -- WHEN 'handover_requested' THEN 'expert_handover_requested'
            -- WHEN 'rx_expert_message_closed' THEN 'expert_message_closed'
            -- WHEN 'rx_sessions_clicked' THEN 'expert_sessions_clicked'
            ELSE event_name
        END AS event_name,
        user_email,
        source_platform,
        source_version,
        device_user_agent,
        device_type,
        device_os,
        device_version,
        geo_country,
        geo_state,
        geo_iso_code,
        geo_ip,
        geo_locale,
        geo_timezone,
        utm_source,
        utm_medium,
        utm_campaign,
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,        
        payload,
        device_uuid
    FROM final_before_naming_conv

)

SELECT * FROM final
{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'form_id',
    'landing_id',
    'hidden_aid',
    'hidden_expert_id',
    'hidden_fbclid',
    'hidden_form_id',
    'hidden_funnelid',
    'hidden_gclid',
    'hidden_partner_uuid',
    'hidden_primary_member_id',
    'hidden_prolific_pid',
    'hidden_random_uuid',
    'hidden_rfsn_v_4_aid',
    'hidden_rfsn_v_4_id',
    'hidden_session_id',
    'hidden_study_id',
    'hidden_ttclid',
    'hidden_uuid',
    'metadata_network_id'                                        
] %}
{% set strings = [
    'hidden_affiliate',
    'hidden_church',
    'hidden_coupon',
    'hidden_current_rfsn_lsts',
    'hidden_email',
    'hidden_ending',
    'hidden_expert',
    'hidden_expert_email',
    'hidden_expert_name',
    'hidden_first_name',
    'hidden_firstname',
    'hidden_funnel_mode',
    'hidden_funnel_start',
    'hidden_get_partner_details_form',
    'hidden_has_scheduled_welcome_session',
    'hidden_hash',
    'hidden_last_name',
    'hidden_lastname',
    'hidden_lead_variation',
    'hidden_manager',
    'hidden_matching',
    'hidden_member_funnel',
    'hidden_name',
    'hidden_native_app_form_os',
    'hidden_original_params',
    'hidden_partner_email',
    'hidden_partner_first_name',
    'hidden_partner_last_name',
    'hidden_partnerrefer',
    'hidden_personal_email',
    'hidden_phone',
    'hidden_price',
    'hidden_program',
    'hidden_quick_survey_funnel',
    'hidden_rfsn',
    'hidden_rfsn_src',
    'hidden_rfsn_v_4_cart_type',
    'hidden_rfsn_v_4_cs',
    'hidden_show_onboarding_app',
    'hidden_skip',
    'hidden_source',
    'hidden_tier_type',
    'hidden_utm_campaign',
    'hidden_utm_content',
    'hidden_utm_medium',
    'hidden_utm_source',
    'hidden_utm_term',
    'hidden_version',
    'hidden_welcome_session_done',
    'metadata_browser',
    'metadata_platform',
    'metadata_referer',
    'metadata_user_agent',
    'token',
    'hidden_jump_to'
] %}
{% set floats = [
    'calculated_score'
] %}
{% set booleans = [
    'hidden_bark_lead',
] %}
{% set timestamps = [
    '_fivetran_synced',
    'landed_at',
    'submitted_at'
] %}


with
base_source as (select * from {{ source('typeform', 'response') }}),

-- Cast variables for declaring the right data type for each column in compiler
cast_variables as (

    select

        {% for i in ids %}
            cast({{i}} as string) as {{i}},
        {% endfor %}

        {% for s in strings %}
            cast({{s}} as string) as {{s}},
        {% endfor %}

        {% for n in integers %}
            cast({{n}} as int64) as {{n}},
        {% endfor %}

        {% for f in floats %}
            cast({{f}} as float64) as {{f}},
        {% endfor %}

        {% for b in booleans %}
            cast({{b}} as boolean) as {{b}},
        {% endfor %}

        {% for arr in arrays %}
            ARRAY(SELECT SAFE_CAST(num AS STRING) 
            FROM UNNEST(SPLIT(substr({{arr}}, 2 , LENGTH({{arr}}) - 2))) AS num
            ) as {{arr}},
        {% endfor %}

        {% for t in timestamps %}
            cast({{t}} as timestamp) as {{t}}{% if not loop.last %},{% endif %}
        {% endfor %}  

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        form_id,
        landing_id,
        hidden_aid AS aid,
        hidden_expert_id AS expert_id,
        hidden_fbclid AS fbclid,
        hidden_form_id AS hidden_form_id,
        hidden_funnelid AS funnelid,
        hidden_gclid AS gclid,
        hidden_partner_uuid AS partner_uuid,
        hidden_primary_member_id AS primary_member_id,
        hidden_prolific_pid AS prolific_pid,
        hidden_random_uuid AS random_uuid,
        hidden_rfsn_v_4_aid AS rfsn_v_4_aid,
        hidden_rfsn_v_4_id AS rfsn_v_4_id,
        hidden_session_id AS session_id,
        hidden_study_id AS study_id,
        hidden_ttclid AS ttclid,
        hidden_uuid AS uuid,
        metadata_network_id,
        hidden_affiliate AS affiliate,
        hidden_church AS church,
        hidden_coupon AS coupon,
        hidden_current_rfsn_lsts AS current_rfsn_lsts,
        hidden_email AS email,
        hidden_ending AS ending,
        hidden_expert AS expert,
        hidden_expert_email AS expert_email,
        hidden_expert_name AS expert_name,
        hidden_first_name AS first_name,
        hidden_firstname AS firstname,
        hidden_funnel_mode AS funnel_mode,
        hidden_funnel_start AS funnel_start,
        hidden_get_partner_details_form AS get_partner_details_form,
        hidden_has_scheduled_welcome_session AS has_scheduled_welcome_session,
        hidden_hash AS `hash`,
        hidden_last_name AS last_name,
        hidden_lastname AS lastname,
        hidden_lead_variation AS lead_variation,
        hidden_manager AS manager,
        hidden_matching AS matching,
        hidden_member_funnel AS member_funnel,
        hidden_name AS name,
        hidden_native_app_form_os AS native_app_form_os,
        hidden_original_params AS original_params,
        hidden_partner_email AS partner_email,
        hidden_partner_first_name AS partner_first_name,
        hidden_partner_last_name AS partner_last_name,
        hidden_partnerrefer AS partnerrefer,
        hidden_personal_email AS personal_email,
        hidden_phone AS phone,
        hidden_price AS price,
        hidden_program AS program,
        hidden_quick_survey_funnel AS quick_survey_funnel,
        hidden_rfsn AS rfsn,
        hidden_rfsn_src AS rfsn_src,
        hidden_rfsn_v_4_cart_type AS rfsn_v_4_cart_type,
        hidden_rfsn_v_4_cs AS rfsn_v_4_cs,
        hidden_show_onboarding_app AS show_onboarding_app,
        hidden_skip AS skip,
        hidden_source AS source,
        hidden_tier_type AS tier_type,
        hidden_utm_campaign AS utm_campaign,
        hidden_utm_content AS utm_content,
        hidden_utm_medium AS utm_medium,
        hidden_utm_source AS utm_source,
        hidden_utm_term AS utm_term,
        hidden_version AS version,
        hidden_welcome_session_done AS welcome_session_done,
        metadata_browser,
        metadata_platform,
        metadata_referer,
        metadata_user_agent,
        token,
        hidden_jump_to AS jump_to,
        calculated_score,
        hidden_bark_lead AS bark_lead,
        _fivetran_synced AS fivetran_synced_at,
        landed_at AS landed_at,
        submitted_at AS submitted_at
    FROM
        cast_variables
)

select * from adapt_variables_names
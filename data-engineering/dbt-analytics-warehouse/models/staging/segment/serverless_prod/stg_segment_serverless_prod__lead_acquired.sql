{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'user_id',
    'platform_ids_rfsn_v4_id',
    'identifiers_uuid',
    'platform_ids_rfsn_v4_aid',
    'platform_ids_fbclid',
    'platform_ids_ttclid',
    'extra_primary_member_id',
    'extra_aid',
    'extra_form_id',
    'extra_uuid',    
    'extra_funnelid',    
] %}
{% set strings = [
    'context_library_name',
    'context_library_version',
    'event',
    'event_text',
    'extra_ending',
    'extra_matching',
    'extra_matching_questionnaire',
    'extra_qualified',
    'extra_quick_survey_funnel',
    'extra_show_onboarding_app',
    'identifiers_email',
    'platform_ids_rfsn',
    'extra_coupon',
    'extra_funnel_start',
    'extra_partnerrefer',
    'identifiers_phone_number',
    'platform_ids_affiliate',
    'platform_ids_rfsn_v4_cart_type',
    'platform_ids_rfsn_v4_cs',
    'utm_params_utm_campaign',
    'utm_params_utm_content',
    'utm_params_utm_medium',
    'utm_params_utm_source',
    'platform_ids_gclid',
    'extra_price',
    'extra_skip',
    'extra_tier_type',
    'extra_member_funnel',
    'extra_church',
    'extra_current_rfsn_lsts',
    'extra_funnel_mode',
    'extra_phone',
    'extra_version',
    'platform_ids_rfsn_src',
    'extra_lead_variation',
    'identifiers_first_name',
    'identifiers_last_name',
    'identifiers_name',
    'utm_params_utm_term',
    'original_timestamp'  
] %} -- Note: original_timestamp Classified as STRING due to only <nil> values
{% set integers = [] %}
{% set floats = [] %}
{% set booleans = [] %}
{% set arrays = [] %}
{% set timestamps = [
    'loaded_at',
    'received_at',
    'sent_at',
    'timestamp',
    'uuid_ts'
] %}

with
base_source as (select * from {{ source('segment_serverless_prod', 'lead_acquired') }}),

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
        user_id,
        platform_ids_rfsn_v4_id AS rfsn_v4_id,
        identifiers_uuid AS uuid,
        platform_ids_rfsn_v4_aid AS rfsn_v4_aid,
        platform_ids_fbclid AS fbclid,
        platform_ids_ttclid AS ttclid,
        extra_primary_member_id AS primary_member_id,
        context_library_name AS library_name,
        context_library_version AS library_version,
        event AS event_name,
        event_text AS event_text,
        extra_aid AS aid,
        extra_ending AS ending,
        extra_form_id AS form_id,
        extra_matching AS matching,
        extra_matching_questionnaire AS matching_questionnaire,
        extra_qualified AS qualified,
        extra_quick_survey_funnel AS quick_survey_funnel,
        extra_show_onboarding_app AS show_onboarding_app,
        extra_uuid AS extra_uuid,
        identifiers_email AS email,
        platform_ids_rfsn AS rfsn,
        extra_coupon AS coupon,
        extra_funnel_start AS funnel_start,
        extra_funnelid AS funnelid,
        extra_partnerrefer AS partnerrefer,
        identifiers_phone_number AS phone_number,
        platform_ids_affiliate AS affiliate,
        platform_ids_rfsn_v4_cart_type AS rfsn_v4_cart_type,
        platform_ids_rfsn_v4_cs AS rfsn_v4_cs,
        utm_params_utm_campaign AS utm_campaign,
        utm_params_utm_content AS utm_content,
        utm_params_utm_medium AS utm_medium,
        utm_params_utm_source AS utm_source,
        platform_ids_gclid AS gclid,
        extra_price AS price,
        extra_skip AS skip,
        extra_tier_type AS tier_type,
        extra_member_funnel AS member_funnel,
        extra_church AS church,
        extra_current_rfsn_lsts AS current_rfsn_lsts,
        extra_funnel_mode AS funnel_mode,
        extra_phone AS phone,
        extra_version AS version,
        platform_ids_rfsn_src AS rfsn_src,
        extra_lead_variation AS lead_variation,
        identifiers_first_name AS first_name,
        identifiers_last_name AS last_name,
        identifiers_name AS name,
        utm_params_utm_term AS utm_term,
        original_timestamp,
        loaded_at,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts
    FROM 
        cast_variables
)

select * from adapt_variables_names
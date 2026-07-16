{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'anonymous_id',
    'om_campaign_id',
    'user_id'
] %}
{% set strings = [
    'context_campaign_source',
    'context_ip',
    'context_library_name',
    'context_library_version',
    'context_locale',
    'context_page_path',
    'context_page_referrer',
    'context_page_search',
    'context_page_title',
    'context_page_url',
    'context_timezone',
    'context_user_agent',
    'context_user_agent_data_brands',
    'context_user_agent_data_platform',
    'email',
    'event',
    'event_text',
    'om_campaign_name'
] %}
{% set booleans = [
    'context_user_agent_data_mobile'
] %}
{% set integers = [
    'context_actions_amplitude_session_id'
] %}
{% set timestamps = [
    'loaded_at',
    'original_timestamp',
    'received_at',
    'sent_at',
    'timestamp',
    'uuid_ts'
] %}


with
base_source as (select * from {{ source('segment_javascript', 'matching_popup_opened') }}),

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
        anonymous_id,
        om_campaign_id,
        user_id,
        context_campaign_source AS campaign_source,
        context_ip AS ip,
        context_library_name AS library_name,
        context_library_version AS library_version,
        context_locale AS locale,
        context_page_path AS page_path,
        context_page_referrer AS page_referrer,
        context_page_search AS page_search,
        context_page_title AS page_title,
        context_page_url AS page_url,
        context_timezone AS timezone,
        context_user_agent AS user_agent,
        context_user_agent_data_brands AS user_agent_brands,
        context_user_agent_data_platform AS user_agent_platform,
        email,
        event AS event_name,
        event_text,
        om_campaign_name AS campaign_name,
        context_user_agent_data_mobile AS user_agent_mobile,
        context_actions_amplitude_session_id AS amplitude_session_id,
        loaded_at,
        original_timestamp,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts
    FROM
        cast_variables
)

select * from adapt_variables_names
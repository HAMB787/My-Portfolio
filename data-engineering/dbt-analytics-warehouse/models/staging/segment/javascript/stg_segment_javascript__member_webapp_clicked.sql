{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids        = [
    'anonymous_id',
    'id',
    'user_id',
    'click_id',
    'context_actions_amplitude_session_id'
] %}
{% set strings    = [
    'context_ip',
    'context_library_name',
    'context_library_version',
    'context_locale',
    'context_page_path',
    'context_page_referrer',
    'context_page_search',
    'context_page_title',
    'context_page_url',
    'context_user_agent',
    'event',
    'event_text',
    'path',
    'referrer',
    'text',
    'context_campaign_content',
    'context_campaign_medium',
    'context_campaign_name',
    'context_campaign_source',
    'context_campaign_term',
    'context_user_agent_data_brands',
    'context_user_agent_data_platform',
    'context_campaign_utm_campaign',
    'context_campaign_utm_content',
    'context_campaign_utm_medium',
    'context_campaign_ial_utm_medium',
    'context_campaign_ial_utm_source',
    'context_campaign_ial_utm_campaign',
    'context_campaign_ial_utm_content',
    'context_timezone'
] %}
{% set integers   = [] %}
{% set floats     = [] %}
{% set booleans   = ['context_user_agent_data_mobile'] %}
{% set arrays     = [] %}
{% set timestamps = ['loaded_at', 'original_timestamp', 'received_at', 'sent_at', 'timestamp', 'uuid_ts'] %}

with
base_source as (select * from {{ source('segment_javascript', 'member_webapp_clicked') }} WHERE context_library_name = 'analytics.js'), -- filtering errornous rows

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
        anonymous_id,
        context_actions_amplitude_session_id AS amplitude_session_id,
        context_ip AS ip,
        context_library_name AS library_name,
        context_library_version AS library_version,
        context_locale AS locale,
        context_page_path AS page_path,
        context_page_referrer AS page_referrer,
        context_page_search AS page_search,
        context_page_title AS page_title,
        context_page_url AS page_url,
        context_user_agent AS user_agent,
        event AS event_name,
        event_text,
        id,
        loaded_at,
        original_timestamp AS original_created_at,
        path,
        received_at,
        referrer,
        sent_at,
        text,
        timestamp AS created_at,
        user_id,
        uuid_ts,
        click_id,
        context_campaign_content AS campaign_content,
        context_campaign_medium AS campaign_medium,
        context_campaign_name AS campaign_name,
        context_campaign_source AS campaign_source,
        context_campaign_term AS campaign_term,
        context_user_agent_data_brands AS user_agent_data_brands,
        context_user_agent_data_mobile AS user_agent_data_mobile,
        context_user_agent_data_platform AS user_agent_data_platform,
        context_campaign_utm_campaign AS campaign_utm_campaign,
        context_campaign_utm_content AS campaign_utm_content,
        context_campaign_utm_medium AS campaign_utm_medium,
        context_campaign_ial_utm_medium AS campaign_ial_utm_medium,
        context_campaign_ial_utm_source AS campaign_ial_utm_source,
        context_campaign_ial_utm_campaign AS campaign_ial_utm_campaign,
        context_campaign_ial_utm_content AS campaign_ial_utm_content,
        context_timezone AS timezone,
        ROW_NUMBER() OVER(PARTITION by id ORDER BY sent_at ASC)                                 AS rnk
    FROM 
        cast_variables
),

final AS (

    SELECT *
    FROM adapt_variables_names
    WHERE rnk = 1 -- deduplicating

)

select * from final
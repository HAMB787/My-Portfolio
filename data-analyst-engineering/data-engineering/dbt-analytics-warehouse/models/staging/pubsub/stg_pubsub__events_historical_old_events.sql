{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'user_id',
    'anonymous_id'
] %}
{% set strings = [
    'event_name',
    'user_email',
    'source_platform',
    'source_version',
    'device_user_agent',
    'device_type',
    'device_os',
    'device_version',
    'geo_country',
    'geo_state',
    'geo_iso_code',
    'geo_ip',
    'geo_locale',
    'geo_timezone',
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'device_uuid'
] %}
{% set jsons = [
    'payload'
] %}
{% set timestamps = [
    'created_at'
] %}


with
base_source_before_dedup as (
    select 
        id,
        user_id,
        anonymous_id,
        CASE
            WHEN event_name IS NULL AND ARRAY_LENGTH(JSON_KEYS(PARSE_JSON(payload))) = 76 AND SAFE.PARSE_JSON(payload) IS NOT NULL
            THEN 'page_view'
            ELSE 'other'
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
        payload,
        created_at,
        device_uuid    
    from {{ source('pubsub', 'segment_events_historical_data_old_events') }}
    WHERE created_at IS NOT NULL
        AND SAFE.PARSE_JSON(payload) IS NOT NULL
    
    UNION ALL

    select 
        id,
        user_id,
        anonymous_id,
        event_name,
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
        payload,
        created_at,
        device_uuid    
    from {{ source('pubsub', 'segment_events_historical_data_old_events') }}
    WHERE created_at IS NOT NULL
        AND event_name IS NOT NULL

),

base_source as (
    select 
        id,
        user_id,
        anonymous_id,
        event_name,
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
        payload,
        created_at,
        device_uuid    
    from base_source_before_dedup
    WHERE event_name <> 'other'
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id, event_name ORDER BY created_at DESC, LENGTH(payload) DESC) = 1
),

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
            cast({{t}} as timestamp) as {{t}}{% if not loop.last %},{% endif %},
        {% endfor %}

        payload

    from base_source
),

-- all without banner_monthlytopic_clicked
adapt_variables_names_without_banner_monthlytopic_clicked as (
    SELECT
        id,
        user_id,
        anonymous_id,
        REPLACE(event_name, '.', '_') AS event_name,
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
        payload,
        created_at,
        device_uuid
    FROM
        cast_variables
    WHERE
        event_name <> 'banner_monthlytopic_clicked'
),

adapt_variables_names_banner_monthlytopic_clicked as (
    SELECT
        id,
        user_id,
        anonymous_id,
        'member_content_clicked' AS event_name,
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
        TO_JSON_STRING(JSON_OBJECT(
            'anonymous_id', JSON_EXTRACT_SCALAR(payload, '$.anonymous_id'),
            'context_app_build', JSON_EXTRACT_SCALAR(payload, '$.context_app_build'),
            'context_app_name', JSON_EXTRACT_SCALAR(payload, '$.context_app_name'),
            'context_app_namespace', JSON_EXTRACT_SCALAR(payload, '$.context_app_namespace'),
            'context_app_version', JSON_EXTRACT_SCALAR(payload, '$.context_app_version'),
            'context_device_id', JSON_EXTRACT_SCALAR(payload, '$.context_device_id'),
            'context_device_manufacturer', JSON_EXTRACT_SCALAR(payload, '$.context_device_manufacturer'),
            'context_device_model', JSON_EXTRACT_SCALAR(payload, '$.context_device_model'),
            'context_device_name', JSON_EXTRACT_SCALAR(payload, '$.context_device_name'),
            'context_device_type', JSON_EXTRACT_SCALAR(payload, '$.context_device_type'),
            'context_instance_id', JSON_EXTRACT_SCALAR(payload, '$.context_instance_id'),
            'context_ip', JSON_EXTRACT_SCALAR(payload, '$.context_ip'),
            'context_library_name', JSON_EXTRACT_SCALAR(payload, '$.context_library_name'),
            'context_library_version', JSON_EXTRACT_SCALAR(payload, '$.context_library_version'),
            'context_locale', JSON_EXTRACT_SCALAR(payload, '$.context_locale'),
            'context_network_cellular', JSON_EXTRACT_SCALAR(payload, '$.context_network_cellular'),
            'context_network_wifi', JSON_EXTRACT_SCALAR(payload, '$.context_network_wifi'),
            'context_os_name', JSON_EXTRACT_SCALAR(payload, '$.context_os_name'),
            'context_os_version', JSON_EXTRACT_SCALAR(payload, '$.context_os_version'),
            'context_screen_height', JSON_EXTRACT_SCALAR(payload, '$.context_screen_height'),
            'context_screen_width', JSON_EXTRACT_SCALAR(payload, '$.context_screen_width'),
            'context_timezone', JSON_EXTRACT_SCALAR(payload, '$.context_timezone'),
            'event', JSON_EXTRACT_SCALAR(payload, '$.event'),
            'event_text', JSON_EXTRACT_SCALAR(payload, '$.event_text'),
            'id', JSON_EXTRACT_SCALAR(payload, '$.id'),
            'loaded_at', JSON_EXTRACT_SCALAR(payload, '$.loaded_at'),
            'original_timestamp', JSON_EXTRACT_SCALAR(payload, '$.original_timestamp'),
            'received_at', JSON_EXTRACT_SCALAR(payload, '$.received_at'),
            'sent_at', JSON_EXTRACT_SCALAR(payload, '$.sent_at'),
            'timestamp', JSON_EXTRACT_SCALAR(payload, '$.timestamp'),
            'topic_id', JSON_EXTRACT_SCALAR(payload, '$.topic_id'),
            'topic_title', JSON_EXTRACT_SCALAR(payload, '$.topic_title'),
            'user_id', JSON_EXTRACT_SCALAR(payload, '$.user_id'),
            'uuid_ts', JSON_EXTRACT_SCALAR(payload, '$.uuid_ts'),
            'context_screen_density', JSON_EXTRACT_SCALAR(payload, '$.context_screen_density'),
            'place', 'homepage' -- added the key
        )) AS payload,
        created_at,
        device_uuid
    FROM
        cast_variables
    WHERE
        event_name = 'banner_monthlytopic_clicked'       
),

final AS (

    SELECT * FROM adapt_variables_names_without_banner_monthlytopic_clicked

    UNION ALL

    SELECT * FROM adapt_variables_names_banner_monthlytopic_clicked

)

SELECT * FROM final
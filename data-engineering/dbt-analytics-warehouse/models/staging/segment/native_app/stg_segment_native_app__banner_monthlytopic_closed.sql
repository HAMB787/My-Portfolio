{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'anonymous_id',
    'context_instance_id',
    'topic_id',
    'user_id'
] %}
{% set strings = [
    'context_app_build',
    'context_app_name',
    'context_app_namespace',
    'context_app_version',
    'context_device_id',
    'context_device_manufacturer',
    'context_device_model',
    'context_device_name',
    'context_device_type',
    'context_ip',
    'context_library_name',
    'context_library_version',
    'context_locale',
    'context_os_name',
    'context_os_version',
    'context_timezone',
    'event',
    'event_text',
    'topic_title'
] %}
{% set booleans = [
    'context_network_cellular',
    'context_network_wifi'
] %}
{% set integers = [
    'context_screen_height',
    'context_screen_width'
] %}
{% set floats = [
    'context_screen_density'
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
base_source as (select * from {{ source('segment_native_app', 'banner_monthlytopic_closed') }}),

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
        context_instance_id AS instance_id,
        topic_id,
        user_id,
        context_app_build AS app_build,
        context_app_name AS app_name,
        context_app_namespace AS app_namespace,
        context_app_version AS app_version,
        context_device_id AS device_id,
        context_device_manufacturer AS device_manufacturer,
        context_device_model AS device_model,
        context_device_name AS device_name,
        context_device_type AS device_type,
        context_ip AS ip,
        context_library_name AS library_name,
        context_library_version AS library_version,
        context_locale AS locale,
        context_os_name AS os_name,
        context_os_version AS os_version,
        context_timezone AS timezone,
        event AS event_name,
        event_text,
        topic_title,
        context_network_cellular AS network_cellular,
        context_network_wifi AS network_wifi,
        context_screen_height AS screen_height,
        context_screen_width AS screen_width,
        context_screen_density AS screen_density,
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
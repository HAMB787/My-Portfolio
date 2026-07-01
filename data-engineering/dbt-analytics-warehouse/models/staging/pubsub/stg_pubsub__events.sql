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
    'crm_source',
    'crm_medium',
    'crm_campaign',
    'crm_content',
    'device_uuid'
] %}
{% set jsons = [
    'payload'
] %}
{% set timestamps = [
    'created_at'
] %}


with
base_source as (
    select * from {{ source('pubsub', 'events') }}
    QUALIFY ROW_NUMBER() OVER(PARTITION BY id, event_name ORDER BY created_at DESC) = 1
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

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
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
        crm_source,
        crm_medium,
        crm_campaign,
        crm_content,
        payload,
        created_at,
        device_uuid
    FROM
        cast_variables
)

select * from adapt_variables_names
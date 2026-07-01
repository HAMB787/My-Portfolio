{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'user_id',
    'ttclid'
] %}
{% set strings = [
    'context_library_name',
    'context_library_version',
    'coupon',
    'email',
    'event',
    'event_text',
    'matching',
    'original_timestamp',
    'rfsn',
    'utm_campaign',
    'utm_content',
    'utm_medium',
    'utm_source'
] %} -- only <nil> value for original_timestamp
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
base_source as (select * from {{ source('segment_serverless_prod', 'lead_qualified') }}),

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
        ttclid,
        context_library_name AS library_name,
        context_library_version AS library_version,
        coupon,
        email,
        event AS event_name,
        event_text,
        matching,
        original_timestamp AS original_created_at,
        rfsn,
        utm_campaign,
        utm_content,
        utm_medium,
        utm_source,
        loaded_at,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts,
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
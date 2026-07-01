{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'uri',
    'user_uri'
] %}
{% set strings = [
    'name',
    'timezone',
    'type',
    'wday',
    'date',
    '`from`',
    '`to`'
] %}
{% set floats = [] %}
{% set booleans = [] %}
{% set integers = [] %}
{% set timestamps = [
    '_databricks_synced_at'
] %}


with
base_source as (select * from {{ source('calendly_databricks', 'user_availability_schedules') }}),

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
        uri AS id,
        user_uri AS user_id,
        name,
        timezone,
        type,
        wday,
        date,
        `from` AS available_from,
        `to` AS available_to,
        _databricks_synced_at AS databricks_synced_at,
        RANK() OVER (PARTITION BY user_uri ORDER BY _databricks_synced_at DESC) AS rnk
    FROM 
        cast_variables
)

select * from adapt_variables_names
{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'user_uri',
    'event_uri'
] %}
{% set strings = [
    'type'
] %}
{% set timestamps = [
    '_databricks_synced_at',
    'period_start',
    'period_end',
    'start_time',
    'end_time',
    'buffered_start_time',
    'buffered_end_time'
] %}


with
base_source as (select * from {{ source('calendly_databricks', 'user_busy_times') }}),

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
        -- IDs
        user_uri AS user_id,
        event_uri AS event_id,
        
        -- Strings
        type,

        -- Timestamps

        period_start AS period_started_at,
        period_end AS period_ended_at,
        start_time,
        end_time,
        buffered_start_time,
        buffered_end_time,
        _databricks_synced_at AS databricks_synced_at

    FROM 
        cast_variables
)

select * from adapt_variables_names
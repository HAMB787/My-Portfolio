{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'user_uri'
] %}
{% set strings = [
    'user_avatar_url',
    'organization',
    'user_email',
    'user_name',
    'user_scheduling_url',
    'user_slug',
    'user_timezone'
] %}
{% set floats = [] %}
{% set booleans = [
] %}
{% set integers = [] %}
{% set timestamps = [
    '_databricks_synced_at',
    'membership_created_at',
    'membership_updated_at'
] %}


with
base_source as (select * from {{ source('calendly_databricks', 'users') }}),

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

-- user_name the columns based on naming and fields conventions
adapt_variables_user_names as (
    SELECT
        user_uri AS id,
        user_avatar_url AS avatar_url,
        organization AS current_organization,
        user_email AS email,
        user_name AS name,
        user_scheduling_url AS scheduling_url,
        user_slug AS slug,
        user_timezone AS timezone,
        membership_created_at AS created_at,
        membership_updated_at AS updated_at,
        _databricks_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_user_names
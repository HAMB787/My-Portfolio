{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'uri',
    'profile_name'    
] %}
{% set strings = [
    'booking_method',
    'color',
    'description_html',
    'description_plain',
    'internal_note',
    'kind',
    'name',
    'pooling_type',
    'profile_owner',
    'profile_type',
    'scheduling_url',
    'slug',
    'type'
] %}
{% set floats = [] %}
{% set booleans = [
    '_fivetran_deleted',
    'active',
    'secret'
] %}
{% set integers = [
    'duration'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created_at',
    'updated_at'
] %}


with
base_source as (select * from {{ source('calendly', 'event_type') }}),

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
        profile_owner AS user_id,
        booking_method,
        color,
        description_html,
        description_plain,
        internal_note,
        kind,
        name,
        pooling_type,
        profile_name,
        profile_type,
        scheduling_url,
        slug,
        type,
        _fivetran_deleted AS is_deleted,
        active AS is_active,
        secret AS is_secret,
        duration,
        _fivetran_synced AS fivetran_synced_at,
        created_at,
        updated_at
    FROM 
        cast_variables
)

select * from adapt_variables_names
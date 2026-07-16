{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'external_id',
    'prompt_id',
    'reflection_id'
] %}
{% set strings = [
    'uuid',
    'text',
    'rephrase_text',
    'status',
    'decline_reason',
    'external_type'
] %}
{% set timestamps = [
    'created',
    'updated',
    'deleted',
    '_fivetran_synced'
] %}
{% set booleans = [
    'active',
    'deleted_by_cascade',
    '_fivetran_deleted'
] %}

with
base_source as (select * from {{ source('postgre_rds', 'insights_insight') }}),

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
        deleted,
        deleted_by_cascade,
        created,
        updated,
        uuid,
        active,
        text,
        rephrase_text,
        status,
        decline_reason,
        external_id,
        external_type,
        prompt_id,
        reflection_id,
        _fivetran_deleted,
        _fivetran_synced
    FROM 
        cast_variables
)

select * from adapt_variables_names
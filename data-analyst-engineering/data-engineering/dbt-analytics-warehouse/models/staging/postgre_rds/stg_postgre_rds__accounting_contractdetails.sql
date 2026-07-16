{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'expert_id',
    'uuid'
] %}
{% set strings = [
    'currency'
] %}
{% set integers = [
    'hourly_rate',
    'onboarding_hours',
    'pathway_rate',
    'status',
    'supervisee_rate',
    'supervisor_rate'
] %}
{% set floats = [
    'multiplier'
] %}
{% set booleans = [
    '_fivetran_deleted',
    'deleted_by_cascade'
] %}
{% set arrays = [] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'deleted',
    'updated'
] %}

with
base_source as (select * from {{ source('postgre_rds', 'accounting_contractdetails') }}),

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
        _fivetran_deleted   AS is_fivetran_deleted,
        _fivetran_synced    AS fivetran_synced_at,
        created AS created_at,
        currency,
        deleted AS deleted_at,
        deleted_by_cascade AS is_deleted,
        expert_id,
        hourly_rate,
        multiplier,
        onboarding_hours,
        pathway_rate,
        status,
        supervisee_rate,
        supervisor_rate,
        updated AS updated_at,
        uuid
    FROM 
        cast_variables
)

select * from adapt_variables_names
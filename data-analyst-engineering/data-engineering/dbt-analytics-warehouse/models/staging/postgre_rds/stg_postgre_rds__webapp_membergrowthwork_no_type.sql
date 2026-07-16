{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'action_id',
    'expert_id',
    'gw_cms_id',
    'member_id',
    'uuid'
] %}
{% set strings = [
    'url',
    'url_hash'
] %}
{% set integers = [
    'status'
] %}
{% set floats = [] %}
{% set booleans = [
    ' _fivetran_deleted',
    'deleted_by_cascade'
] %}
{% set arrays = [] %}
{% set timestamps = [
    'created',
    'deleted',
    'updated',
    '_fivetran_synced'
] %}



with
base_source as (
    SELECT *
    from {{ source('postgre_rds', 'webapp_membergrowthwork') }}
    where JSON_EXTRACT(result, '$.metadata.type') IS NULL 
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
            cast({{t}} as timestamp) as {{t}}{% if not loop.last %},{% endif %}
        {% endfor %}

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        action_id,
        expert_id,
        gw_cms_id,
        member_id,
        uuid,    
        url,
        url_hash,
        status,
         _fivetran_deleted AS is_fivetran_deleted,
        deleted AS is_deleted,
        created AS created_at,
        deleted AS deleted_at,
        updated AS updated_at,
        _fivetran_synced AS fivetran_synced_at
    FROM 
        cast_variables
)

select * from adapt_variables_names
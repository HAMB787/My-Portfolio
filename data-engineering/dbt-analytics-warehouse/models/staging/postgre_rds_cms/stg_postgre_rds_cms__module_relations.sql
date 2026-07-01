{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'created_by_id',
    'updated_by_id'
] %}
{% set integers = [
    'gw_order',
    'part_order'
] %}
{% set booleans = [
    '_fivetran_deleted'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created_at',
    'published_at',
    'updated_at'
] %}


with
base_source as (select * from {{ source('postgre_rds_cms', 'module_relations') }}),

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
        created_by_id,
        updated_by_id,
        gw_order,
        part_order,
        _fivetran_deleted AS is_deleted,
        _fivetran_synced AS fivetran_synced_at,
        created_at,
        published_at,
        updated_at
    FROM
        cast_variables
)

select * from adapt_variables_names
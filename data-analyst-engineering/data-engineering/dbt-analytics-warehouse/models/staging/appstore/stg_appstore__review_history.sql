{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'app_id',
    'id',
    'dbt_scd_id'
] %}
{% set strings = [
    'app_version_string',
    'content',
    'country_code',
    'nickname',
    'title'
] %}
{% set integers = [
    'helpful_views',
    'rating',
    'total_views'
] %}
{% set booleans = [
    'edited',
    'is_editable',
    'is_required'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'last_modified',
    'dbt_updated_at',
    'dbt_valid_from',
    'dbt_valid_to'
] %}


with
base_source as (select * from {{ ref('appstore_review_snapshot') }}),

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
        app_id,
        id,
        dbt_scd_id,
        _fivetran_synced AS fivetran_synced_at,
        app_version_string,
        content,
        country_code,
        edited,
        helpful_views,
        is_editable,
        is_required,
        last_modified AS last_modified_at,
        nickname,
        rating,
        title,
        total_views,
        dbt_updated_at,
        dbt_valid_from,
        dbt_valid_to,
        MIN(last_modified) OVER (PARTITION BY id)    AS created_at,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY dbt_updated_at DESC)    AS rnk
    FROM
        cast_variables
)

select * from adapt_variables_names
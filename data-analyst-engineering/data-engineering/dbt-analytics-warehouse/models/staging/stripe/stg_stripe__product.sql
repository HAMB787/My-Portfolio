{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id'
] %}
{% set strings = [
    'caption',
    'description',
    'metadata',
    'name',
    'statement_descriptor',
    'type',
    'unit_label',
    'url'
] %}
{% set floats = [
    'package_dimensions_height',
    'package_dimensions_length',
    'package_dimensions_weight',
    'package_dimensions_width'
] %}
{% set booleans = [
    'active',
    'is_deleted',
    'livemode',
    'shippable'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'updated'
] %}

with
base_source as (select * from {{ source('stripe', 'product') }}),

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
        _fivetran_synced AS fivetran_synced_at,
        active AS is_active,
        caption,
        created AS created_at,
        description,
        is_deleted,
        livemode AS is_livemode,
        metadata,
        name,
        package_dimensions_height,
        package_dimensions_length,
        package_dimensions_weight,
        package_dimensions_width,
        shippable AS is_shippable,
        statement_descriptor,
        type,
        unit_label,
        updated AS updated_at,
        url
    FROM
        cast_variables

)
select * from adapt_variables_names
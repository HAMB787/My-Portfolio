{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'field_id',
    'form_id',
    'ref'
] %}
{% set strings = [
    'attachment_href',
    'attachment_property_description',
    'attachment_type',
    'label'
] %}
{% set booleans = [
    '_fivetran_active'
] %}
{% set timestamps = [
    '_fivetran_start',
    '_fivetran_end',
    '_fivetran_synced'
] %}



with
base_source as (select * from {{ source('typeform', 'form_field_choice_history') }}),

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
        field_id,
        form_id,
        ref AS ref_id,
        attachment_href,
        attachment_property_description,
        attachment_type,
        label,
        _fivetran_active AS is_active,
        _fivetran_start AS fivetran_start_at,
        _fivetran_end AS fivetran_end_at,
        _fivetran_synced AS fivetran_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names
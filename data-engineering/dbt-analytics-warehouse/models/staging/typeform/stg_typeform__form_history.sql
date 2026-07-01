{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'theme_id',
    'workspace_id'
] %}
{% set strings = [
    '_language',
    'cui_setting_avatar',
    'cui_setting_typing_emulation_speed',
    'title',
    'type'
] %}
{% set floats = [
    'variable_price'
] %}
{% set integers = [
    'variable_score'
] %}
{% set booleans = [
    '_fivetran_active',
    'cui_setting_is_typing_emulation_disabled'
] %}
{% set timestamps = [
    '_fivetran_start',
    '_fivetran_end',
    '_fivetran_synced',
    'last_updated_at'
] %}


with
base_source as (select * from {{ source('typeform', 'form_history') }}),

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
        theme_id,
        workspace_id,
        _language AS language,
        cui_setting_avatar AS avatar,
        cui_setting_typing_emulation_speed AS emulation_speed,
        title,
        type,
        variable_price,
        variable_score,
        _fivetran_active AS is_active,
        cui_setting_is_typing_emulation_disabled AS is_typing_emulation_disabled,
        _fivetran_start AS fivetran_start,
        _fivetran_end AS fivetran_end,
        _fivetran_synced AS fivetran_synced_at,
        last_updated_at
    FROM
        cast_variables
)

select * from adapt_variables_names
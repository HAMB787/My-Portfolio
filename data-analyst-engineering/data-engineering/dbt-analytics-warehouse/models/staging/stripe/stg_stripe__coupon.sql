{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id'
] %}
{% set strings = [
    'currency',
    'duration',
    'metadata',
    'name'
] %}
{% set integers = [
    'amount_off',
    'duration_in_months',
    'max_redemptions',
    'times_redeemed'
] %}
{% set floats = [
    'percent_off'
] %}
{% set booleans = [
    'is_deleted',
    'livemode',
    'valid'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'redeem_by'
] %}


with
base_source as (select * from {{ source('stripe', 'coupon') }}),

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
        -- IDs
        id,

        -- Strings
        currency,
        duration,
        metadata,
        name,

        -- Integers
        amount_off,
        duration_in_months,
        max_redemptions,
        times_redeemed,

        -- Floats
        percent_off,

        -- Booleans
        is_deleted,
        livemode,
        valid,

        -- Timestamps
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at,
        redeem_by AS redeem_by_at

    FROM
        cast_variables

)
select * from adapt_variables_names
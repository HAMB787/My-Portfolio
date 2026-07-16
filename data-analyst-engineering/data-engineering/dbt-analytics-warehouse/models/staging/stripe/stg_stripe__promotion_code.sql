{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'coupon_id',
    'customer_id'
] %}
{% set strings = [
    'code',
    'metadata',
    'minimum_amount_currency'
] %}
{% set integers = [
    'max_redemptions',
    'minimum_amount',
    'times_redeemed'
] %}
{% set booleans = [
    'active',
    'first_time_transaction',
    'livemode'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'expires_at'
] %}


with
base_source as (select * from {{ source('stripe', 'promotion_code') }}),

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
        coupon_id,
        customer_id,
        code,
        metadata,
        minimum_amount_currency,
        max_redemptions,
        minimum_amount,
        times_redeemed,
        active,
        first_time_transaction,
        livemode,
        created,
        expires_at,
        _fivetran_synced        
    FROM
        cast_variables

)
select * from adapt_variables_names
{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'subscription_id',
    'plan_id'
] %}
{% set strings = [] %}
{% set integers = [
    'billing_thresholds_amount_gte',
    'quantity'
] %}
{% set booleans = [
    'billing_thresholds_reset_billing_cycle_anchor'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created'
] %}


with
base_source as (select * from {{ source('stripe', 'subscription_item') }}),

-- Cast variables for declaring the right data type for each column in compiler
cast_variables as (

    select

        {% for i in ids %}
            cast({{i}} as string) as {{i}},
        {% endfor %}

        {% for s in strings %}
            upper(cast({{s}} as string)) as {{s}},
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
        {% endfor %},

        metadata

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        subscription_id,
        plan_id,
        metadata,
        billing_thresholds_amount_gte,
        quantity,
        billing_thresholds_reset_billing_cycle_anchor AS is_billing_thresholds_reset,
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at
    FROM
        cast_variables

)
select * from adapt_variables_names
{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'product_id'
] %}
{% set strings = [
    'aggregate_usage',
    'billing_scheme',
    'currency',
    'nickname',
    'tiers_mode',
    'transform_usage_round',
    'usage_type'
] %}
{% set integers = [
    'amount',
    'interval_count',
    'transform_usage_divide_by',
    'trial_period_days'
] %}
{% set booleans = [
    'active',
    'is_deleted',
    'livemode'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created'
] %}



with
base_source as (select * from {{ source('stripe', 'plan') }}),

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

        metadata,
        `interval`

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        product_id,
        aggregate_usage,
        billing_scheme,
        currency,
        `interval`    AS plan_duration,
        metadata,
        nickname,
        tiers_mode,
        transform_usage_round,
        usage_type,
        amount,
        `interval`,
        interval_count,
        transform_usage_divide_by,
        trial_period_days,
        active AS is_active,
        is_deleted,
        livemode AS is_livemode,
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at
    FROM
        cast_variables

)
select * from adapt_variables_names
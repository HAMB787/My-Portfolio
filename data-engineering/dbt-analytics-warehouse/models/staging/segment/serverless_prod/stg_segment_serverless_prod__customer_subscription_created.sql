{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'member_uuid',
    'stripe_customer_id',
    'stripe_price_id',
    'stripe_product_id',
    'stripe_subscription_id',
    'user_id'
] %}
{% set strings = [
    'context_library_name',
    'context_library_version',
    'event',
    'event_source',
    'event_text',
    'member_email',
    'member_first_name',
    'member_last_name',
    'member_phone',
    'object',
    'original_timestamp',
    'stripe_subscription_price',
    'stripe_subscription_status',
    'stripe_subscription_status_previous',
    'stripe_subscription_tier',
    'member_utm_campaign',
    'member_utm_content',
    'member_utm_medium',
    'member_utm_source',
    'member_ttclid',
    'stripe_subscription_paused_until_pretty',
    'plan_category',
    'checkout_variation'
] %}
{% set integers = [
    'stripe_subscription_paused_until'
] %}
{% set timestamps = [
    'loaded_at',
    'received_at',
    'sent_at',
    'timestamp',
    'uuid_ts'
] %}

with
base_source as (select * from {{ source('segment_serverless_prod', 'customer_subscription_created') }}),

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
        member_uuid,
        stripe_customer_id,
        stripe_price_id,
        stripe_product_id,
        stripe_subscription_id,
        user_id,
        context_library_name,
        context_library_version,
        event AS event_name,
        event_source,
        event_text,
        member_email,
        member_first_name,
        member_last_name,
        member_phone,
        object,
        original_timestamp,
        stripe_subscription_price,
        stripe_subscription_status,
        stripe_subscription_status_previous,
        stripe_subscription_tier,
        member_utm_campaign,
        member_utm_content,
        member_utm_medium,
        member_utm_source,
        member_ttclid,
        stripe_subscription_paused_until_pretty,
        plan_category,
        checkout_variation,
        stripe_subscription_paused_until,
        loaded_at,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts
    FROM
        cast_variables
)

select * from adapt_variables_names
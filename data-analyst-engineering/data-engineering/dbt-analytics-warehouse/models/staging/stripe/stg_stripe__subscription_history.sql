{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'customer_id',
    'default_payment_method_id',
    'default_source_id',
    'latest_invoice_id',
    'pending_setup_intent_id'
] %}
{% set strings = [
    'billing',
    'collection_method',
    'metadata',
    'pause_collection_behavior',
    'status'
] %}
{% set integers = [
    'billing_threshold_amount_gte',
    'days_until_due',
    'quantity'
] %}
{% set floats = [
    'application_fee_percent',
    'tax_percent'
] %}
{% set booleans = [
    '_fivetran_active',
    'billing_threshold_reset_billing_cycle_anchor',
    'cancel_at_period_end',
    'livemode'
] %}
{% set timestamps = [
    '_fivetran_start',
    '_fivetran_end',
    '_fivetran_synced',
    'billing_cycle_anchor',
    'cancel_at',
    'canceled_at',
    'created',
    'current_period_end',
    'current_period_start',
    'ended_at',
    'pause_collection_resumes_at',
    'start',
    'start_date',
    'trial_end',
    'trial_start'
] %}


with
base_source as (select * from {{ source('stripe', 'subscription_history') }}),

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
        _fivetran_start AS fivetran_start_at,
        _fivetran_active AS is_fivetran_active,
        _fivetran_end AS fivetran_end_at,
        _fivetran_synced AS fivetran_synced_at,
        application_fee_percent,
        billing,
        billing_cycle_anchor AS billing_cycle_anchor_at,
        billing_threshold_amount_gte,
        billing_threshold_reset_billing_cycle_anchor AS is_billing_threshold_reset,
        cancel_at AS cancel_at,
        cancel_at_period_end AS is_cancel_at_period_end,
        canceled_at AS canceled_at,
        collection_method,
        created AS created_at,
        current_period_end AS current_period_end_at,
        current_period_start AS current_period_start_at,
        customer_id,
        days_until_due,
        default_payment_method_id,
        default_source_id,
        ended_at AS ended_at,
        latest_invoice_id,
        livemode AS is_livemode,
        metadata,
        pause_collection_behavior,
        pause_collection_resumes_at AS pause_collection_resumes_at,
        pending_setup_intent_id,
        quantity,
        start AS start_at,
        start_date AS start_date_at,
        status,
        tax_percent,
        trial_end AS trial_end_at,
        trial_start AS trial_start_at
    FROM
        cast_variables

)
select * from adapt_variables_names
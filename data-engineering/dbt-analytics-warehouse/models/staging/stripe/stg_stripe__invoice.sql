{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'customer_id',
    'charge_id',
    'default_payment_method_id',
    'default_source_id',
    'payment_intent_id',
    'subscription_id'
] %}
{% set strings = [
    'billing',
    'billing_reason',
    'collection_method',
    'currency',
    'description',
    'footer',
    'hosted_invoice_url',
    'invoice_pdf',
    'metadata',
    'number',
    'receipt_number',
    'statement_descriptor',
    'status'
] %}
{% set integers = [
    'amount_due',
    'amount_paid',
    'amount_remaining',
    'application_fee_amount',
    'attempt_count',
    'ending_balance',
    'post_payment_credit_notes_amount',
    'pre_payment_credit_notes_amount',
    'starting_balance',
    'subtotal',
    'tax',
    'threshold_reason_amount_gte',
    'total',
    'subscription_proration_date'
] %}
{% set floats = [
    'tax_percent'
] %}
{% set booleans = [
    'attempted',
    'auto_advance',
    'is_deleted',
    'livemode',
    'paid'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'date',
    'due_date',
    'finalized_at',
    'next_payment_attempt',
    'period_end',
    'period_start',
    'status_transitions_finalized_at',
    'status_transitions_marked_uncollectible_at',
    'status_transitions_paid_at',
    'status_transitions_voided_at',
    'webhooks_delivered_at'
] %}

with
base_source as (select * from {{ source('stripe', 'invoice') }}),

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
        customer_id,
        charge_id,
        default_payment_method_id,
        default_source_id,
        payment_intent_id,
        subscription_id,
        billing,
        billing_reason,
        collection_method,
        currency,
        description,
        footer,
        hosted_invoice_url,
        invoice_pdf,
        metadata,
        number,
        receipt_number,
        statement_descriptor,
        status,
        subscription_proration_date,
        amount_due,
        amount_paid,
        amount_remaining,
        application_fee_amount,
        attempt_count,
        ending_balance,
        post_payment_credit_notes_amount,
        pre_payment_credit_notes_amount,
        starting_balance,
        subtotal,
        tax,
        tax_percent,
        threshold_reason_amount_gte,
        total,
        attempted AS is_attempted,
        auto_advance AS is_auto_advance,
        is_deleted,
        livemode AS is_livemode,
        paid AS is_paid,
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at,
        date AS invoiced_at,
        due_date AS invoice_due_at,
        finalized_at,
        next_payment_attempt AS next_payment_attempt_at,
        period_end AS period_end_at,
        period_start AS period_start_at,
        status_transitions_finalized_at,
        status_transitions_marked_uncollectible_at,
        status_transitions_paid_at,
        status_transitions_voided_at,
        webhooks_delivered_at
    FROM
        cast_variables

)
select * from adapt_variables_names
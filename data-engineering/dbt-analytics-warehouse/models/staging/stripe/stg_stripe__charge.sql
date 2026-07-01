{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'customer_id',
    'payment_intent_id',
    'balance_transaction_id',
    'bank_account_id',
    'card_id',
    'connected_account_id',
    'invoice_id',
    'payment_method_id',
    'source_id',
    'transfer_id'
] %}
{% set strings = [
    'application',
    'billing_detail_address_city',
    'billing_detail_address_country',
    'billing_detail_address_line_1',
    'billing_detail_address_line_2',
    'billing_detail_address_postal_code',
    'billing_detail_address_state',
    'billing_detail_email',
    'billing_detail_name',
    'billing_detail_phone',
    'calculated_statement_descriptor',
    'currency',
    'description',
    'destination',
    'failure_code',
    'failure_message',
    'fraud_details_stripe_report',
    'fraud_details_user_report',
    'metadata',
    'on_behalf_of',
    'outcome_network_status',
    'outcome_reason',
    'outcome_risk_level',
    'outcome_seller_message',
    'outcome_type',
    'receipt_email',
    'receipt_number',
    'receipt_url',
    'shipping_address_city',
    'shipping_address_country',
    'shipping_address_line_1',
    'shipping_address_line_2',
    'shipping_address_postal_code',
    'shipping_address_state',
    'shipping_carrier',
    'shipping_name',
    'shipping_phone',
    'shipping_tracking_number',
    'source_transfer',
    'statement_descriptor',
    'status',
    'transfer_data_destination',
    'transfer_group',
    'rule_rule'
] %}
{% set integers = [
    'amount',
    'amount_refunded',
    'application_fee_amount',
    'outcome_risk_score'
] %}
{% set floats = [] %}
{% set booleans = [
    'captured',
    'livemode',
    'paid',
    'refunded'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created'
] %}

with
base_source as (select * from {{ source('stripe', 'charge') }}),

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
        payment_intent_id,
        balance_transaction_id,
        bank_account_id,
        card_id,
        connected_account_id,
        invoice_id,
        payment_method_id,
        source_id,
        transfer_id,
        application,
        billing_detail_address_city,
        billing_detail_address_country,
        billing_detail_address_line_1,
        billing_detail_address_line_2,
        billing_detail_address_postal_code,
        billing_detail_address_state,
        billing_detail_email,
        billing_detail_name,
        billing_detail_phone,
        calculated_statement_descriptor,
        currency,
        description,
        destination,
        failure_code,
        failure_message,
        fraud_details_stripe_report,
        fraud_details_user_report,
        metadata,
        on_behalf_of,
        outcome_network_status,
        outcome_reason,
        outcome_risk_level,
        outcome_seller_message,
        outcome_type,
        receipt_email,
        receipt_number,
        receipt_url,
        shipping_address_city,
        shipping_address_country,
        shipping_address_line_1,
        shipping_address_line_2,
        shipping_address_postal_code,
        shipping_address_state,
        shipping_carrier,
        shipping_name,
        shipping_phone,
        shipping_tracking_number,
        source_transfer,
        statement_descriptor,
        status,
        transfer_data_destination,
        transfer_group,
        rule_rule,
        amount,
        amount_refunded,
        application_fee_amount,
        outcome_risk_score,
        captured AS is_captured,
        livemode AS is_livemode,
        paid AS is_paid,
        refunded AS is_refunded,
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at
    FROM
        cast_variables

)
select * from adapt_variables_names
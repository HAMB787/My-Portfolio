{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'balance_transaction',
    'charge_id',
    'connected_account_id',
    'evidence_duplicate_charge_id'
] %}
{% set strings = [
    'currency',
    'evidence_access_activity_log',
    'evidence_billing_address',
    'evidence_cancellation_policy',
    'evidence_cancellation_policy_disclosure',
    'evidence_cancellation_rebuttal',
    'evidence_customer_communication',
    'evidence_customer_email_address',
    'evidence_customer_name',
    'evidence_customer_purchase_ip',
    'evidence_customer_signature',
    'evidence_duplicate_charge_documentation',
    'evidence_duplicate_charge_explanation',
    'evidence_product_description',
    'evidence_receipt',
    'evidence_refund_policy',
    'evidence_refund_policy_disclosure',
    'evidence_refund_refusal_explanation',
    'evidence_service_date',
    'evidence_service_documentation',
    'evidence_shipping_address',
    'evidence_shipping_carrier',
    'evidence_shipping_date',
    'evidence_shipping_documentation',
    'evidence_shipping_tracking_number',
    'evidence_uncategorized_file',
    'evidence_uncategorized_text',
    'metadata',
    'reason',
    'status'
] %}
{% set integers = [
    'amount',
    'evidence_details_submission_count'
] %}
{% set booleans = [
    'evidence_details_has_evidence',
    'evidence_details_past_due',
    'is_charge_refundable',
    'livemode'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'evidence_details_due_by'
] %}



with
base_source as (select * from {{ source('stripe', 'dispute') }}),

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
        balance_transaction,
        charge_id,
        connected_account_id,
        evidence_duplicate_charge_id AS duplicate_charge_id,
        currency,
        evidence_access_activity_log AS access_activity_log,
        evidence_billing_address AS billing_address,
        evidence_cancellation_policy AS cancellation_policy,
        evidence_cancellation_policy_disclosure AS cancellation_policy_disclosure,
        evidence_cancellation_rebuttal AS cancellation_rebuttal,
        evidence_customer_communication AS customer_communication,
        evidence_customer_email_address AS customer_email_address,
        evidence_customer_name AS customer_name,
        evidence_customer_purchase_ip AS customer_purchase_ip,
        evidence_customer_signature AS customer_signature,
        evidence_duplicate_charge_documentation AS duplicate_charge_documentation,
        evidence_duplicate_charge_explanation AS duplicate_charge_explanation,
        evidence_product_description AS product_description,
        evidence_receipt AS receipt,
        evidence_refund_policy AS refund_policy,
        evidence_refund_policy_disclosure AS refund_policy_disclosure,
        evidence_refund_refusal_explanation AS refund_refusal_explanation,
        evidence_service_date AS service_date,
        evidence_service_documentation AS service_documentation,
        evidence_shipping_address AS shipping_address,
        evidence_shipping_carrier AS shipping_carrier,
        evidence_shipping_date AS shipping_date,
        evidence_shipping_documentation AS shipping_documentation,
        evidence_shipping_tracking_number AS shipping_tracking_number,
        evidence_uncategorized_file AS uncategorized_file,
        evidence_uncategorized_text AS uncategorized_text,
        metadata,
        reason,
        status,
        amount,
        evidence_details_submission_count AS details_submission_count,
        evidence_details_has_evidence AS details_has_evidence,
        evidence_details_past_due AS details_past_due,
        is_charge_refundable,
        livemode,
        _fivetran_synced AS fivetran_synced_at,
        created AS created_at,
        evidence_details_due_by AS evidence_due_by
    FROM
        cast_variables

)
select * from adapt_variables_names
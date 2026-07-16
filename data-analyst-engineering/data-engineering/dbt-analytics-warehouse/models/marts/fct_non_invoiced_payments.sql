{{ config(
    materialized='table'
)}}

WITH

invoices AS (SELECT * FROM {{ ref('stg_stripe__invoice') }}),
charges AS (SELECT * FROM {{ ref('stg_stripe__charge') }}),

non_invoiced_charges AS (

    SELECT id FROM charges WHERE invoice_id IS NULL

    EXCEPT DISTINCT

    SELECT charge_id FROM invoices
),

final AS (

    SELECT C.created_at,
        C.id,
        C.customer_id,
        C.billing_detail_address_country,
        C.billing_detail_email,
        C.billing_detail_name,
        C.currency,
        C.description,
        C.outcome_network_status,
        C.outcome_seller_message,
        C.status,
        C.amount / 100 AS payment_amount,
        C.amount_refunded / 100 AS payment_amount_refunded,
        C.is_paid,
        C.is_refunded,
        CASE
            WHEN is_refunded = TRUE AND C.amount = C.amount_refunded THEN 'Full'
            WHEN is_refunded = TRUE AND C.amount <> C.amount_refunded THEN 'Partial'
        END AS refund_type
    FROM charges AS C
    INNER JOIN non_invoiced_charges AS N ON C.id = N.id

)

SELECT * FROM final
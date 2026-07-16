{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'bank_account_id',
    'default_card_id',
    'source_id'
] %}
{% set strings = [
    'address_city',
    'address_country',
    'address_line_1',
    'address_line_2',
    'address_postal_code',
    'address_state',
    'currency',
    'description',
    'email',
    'invoice_prefix',
    'invoice_settings_default_payment_method',
    'invoice_settings_footer',
    'name',
    'phone',
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
    'tax_exempt',
    'tax_info_tax_id',
    'tax_info_type',
    'tax_info_verification_status',
    'tax_info_verification_verified_name'
] %}
{% set integers = [
    'account_balance',
    'balance'
] %}
{% set booleans = [
    'delinquent',
    'is_deleted',
    'livemode'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'created'
] %} -- removing metadata to not corrupt the data types


with
base_source as (select * from {{ source('stripe', 'customer') }}),

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
        {% endfor %},

        metadata -- specifying explicitly to not corrupt the data

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        _fivetran_synced AS fivetran_synced_at,
        account_balance,
        address_city,
        address_country,
        address_line_1,
        address_line_2,
        address_postal_code,
        address_state,
        balance,
        bank_account_id,
        created AS created_at,
        currency,
        default_card_id,
        delinquent AS is_delinquent,
        description,
        email,
        invoice_prefix,
        invoice_settings_default_payment_method,
        invoice_settings_footer,
        is_deleted,
        livemode AS is_livemode,
        metadata,
        JSON_EXTRACT_SCALAR(metadata, '$.uuid') AS uuid,
        JSON_EXTRACT_SCALAR(metadata, '$.funnel') AS funnel,
        JSON_EXTRACT_SCALAR(metadata, '$.funnel_start') AS funnel_start,
        JSON_EXTRACT_SCALAR(metadata, '$.funnelid') AS funnel_id,        
        JSON_EXTRACT_SCALAR(metadata, '$.coupon') AS coupon,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn') AS rfsn,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_aid') AS rfsn_v4_aid,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_cs') AS rfsn_v4_cs,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_id') AS rfsn_v4_id,
        JSON_EXTRACT_SCALAR(metadata, '$.tier_type') AS tier_type,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_campaign') AS utm_campaign,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_content') AS utm_content,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_medium') AS utm_medium,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_source') AS utm_source,
        JSON_EXTRACT_SCALAR(metadata, '$.order_id') AS order_id,
        name,
        phone,
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
        source_id,
        tax_exempt,
        tax_info_tax_id,
        tax_info_type,
        tax_info_verification_status,
        tax_info_verification_verified_name
    FROM
        cast_variables

)
select * from adapt_variables_names